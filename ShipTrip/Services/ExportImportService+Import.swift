//
//  ExportImportService+Import.swift
//  ShipTrip
//
//  Import-Pfad des Backup-Formats: ZIP/JSON einlesen, Kreuzfahrten mit Route, Fotos und
//  Ausgaben anlegen. Wunschreisen und Katalog-Overlay liegen in
//  `ExportImportService+CatalogImport.swift`.
//

import Foundation
import ImageIO
import SwiftData


extension ExportImportService {

    // MARK: - Import

    /// Importiert Kreuzfahrten aus einer ZIP-Datei (neues Format oder Web-App-Format)
    func importFromZip(url: URL, modelContext: ModelContext) throws -> ImportResult {
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("shiptrip-import-\(UUID().uuidString)")

        defer {
            try? FileManager.default.removeItem(at: tempDir)
        }

        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)

        try ZipArchiveReader.extract(from: url, to: tempDir)

        // data.json suchen (im Root oder in einem Unterordner)
        var dataJsonPath = tempDir.appendingPathComponent("data.json")
        var imagesDir = tempDir

        if !FileManager.default.fileExists(atPath: dataJsonPath.path) {
            let contents = try FileManager.default.contentsOfDirectory(at: tempDir, includingPropertiesForKeys: nil)
            for item in contents {
                var isDir: ObjCBool = false
                if FileManager.default.fileExists(atPath: item.path, isDirectory: &isDir), isDir.boolValue {
                    let nestedPath = item.appendingPathComponent("data.json")
                    if FileManager.default.fileExists(atPath: nestedPath.path) {
                        dataJsonPath = nestedPath
                        imagesDir = item
                        break
                    }
                }
            }
        }

        guard FileManager.default.fileExists(atPath: dataJsonPath.path) else {
            throw ImportError.noDataFile
        }

        let jsonData = try Data(contentsOf: dataJsonPath)
        return try importFromJSONData(data: jsonData, imagesDir: imagesDir, modelContext: modelContext)
    }

    /// Importiert Kreuzfahrten aus einer JSON-Datei (Base64-Legacy-Format)
    func importFromJSON(url: URL, modelContext: ModelContext) throws -> ImportResult {
        let jsonData = try Data(contentsOf: url)
        return try importFromJSONData(data: jsonData, imagesDir: nil, modelContext: modelContext)
    }

    private func importFromJSONData(data: Data, imagesDir: URL?, modelContext: ModelContext) throws -> ImportResult {
        // Dual-Decoder: 1.8-Envelope oder 1.7-Top-Level-Array (siehe ExportArchive.decode)
        let archive = try ExportArchive.decode(from: data)
        let exportCruises = archive.cruises

        // Hole existierende Kreuzfahrten für Duplikat-Check
        let descriptor = FetchDescriptor<Cruise>()
        let existingCruises = (try? modelContext.fetch(descriptor)) ?? []

        var importedCount = 0
        var skippedDuplicates = 0
        var skippedInvalid = 0
        var invalidMediaCount = 0

        // ID-basierte Duplikate INNERHALB derselben Import-Datei (z.B. manipuliertes data.json
        // mit zwei Cruises gleicher id): nur die erste wird importiert.
        var seenCruiseIDs: Set<UUID> = []

        // Foto-IDs müssen ARCHIVWEIT eindeutig bleiben, nicht nur pro Kreuzfahrt: dieselbe id in
        // zwei Reisen derselben Datei — oder eine id, die schon an einem Foto in der Datenbank
        // hängt — erzeugte sonst zwei Photo-Objekte mit identischer stabiler ID, über die der
        // CloudKit-Dedup läuft (ADR-002). Deshalb ist das Set mit den bestehenden Foto-IDs
        // vorbelegt. Bei Kollision wird der Import NICHT abgebrochen: das Foto behält die frische
        // UUID aus dem Init und wird ganz normal importiert — nur seine Datei-Identität geht
        // verloren, was harmloser ist als ein verworfenes Foto oder ein Duplikat-Konflikt.
        let existingPhotos = (try? modelContext.fetch(FetchDescriptor<Photo>())) ?? []
        var seenPhotoIDs: Set<UUID> = Set(existingPhotos.map(\.id))

        for exportCruise in exportCruises {
            // Datumsvalidierung
            guard let startDate = dateFormatter.date(from: exportCruise.startDate),
                  let endDate = dateFormatter.date(from: exportCruise.endDate) else {
                skippedInvalid += 1
                continue
            }

            guard endDate >= startDate else {
                skippedInvalid += 1
                continue
            }

            // Duplikat-Check: primär via stabiler ID, Fallback via Titel+Datum+Schiff
            let exportUUID = UUID(uuidString: exportCruise.id)
            let isDuplicate: Bool
            if let exportUUID = exportUUID {
                // Primär: ID-basierter Vergleich (stabile IDs, ZIP-Format) + Duplikate im selben Import
                isDuplicate = existingCruises.contains { $0.id == exportUUID } || seenCruiseIDs.contains(exportUUID)
            } else {
                // Fallback für Legacy-Exporte ohne gültige UUID
                isDuplicate = existingCruises.contains { existing in
                    existing.title == exportCruise.title &&
                    Calendar.current.isDate(existing.startDate, inSameDayAs: startDate) &&
                    existing.ship.lowercased() == exportCruise.ship.lowercased()
                }
            }

            if isDuplicate {
                skippedDuplicates += 1
                continue
            }

            // Kreuzfahrt anlegen; stabile ID aus Export übernehmen (idempotenter Re-Import)
            let cruise = Cruise(
                title: exportCruise.title,
                startDate: startDate,
                endDate: endDate,
                shippingLine: exportCruise.shippingLine,
                ship: exportCruise.ship
            )
            if let exportUUID = exportUUID {
                cruise.id = exportUUID
                seenCruiseIDs.insert(exportUUID)
            }
            cruise.cabinType = exportCruise.cabinType ?? ""
            cruise.cabinNumber = exportCruise.cabinNumber ?? ""
            cruise.bookingNumber = exportCruise.bookingNumber ?? ""
            cruise.notes = exportCruise.notes ?? ""
            cruise.rating = exportCruise.rating

            modelContext.insert(cruise)

            // ID-basierte Duplikate INNERHALB derselben Cruise (z.B. manipulierte Datei mit zwei
            // Ports gleicher id): nur das erste Vorkommen übernimmt die Datei-ID, jedes weitere
            // behält seine frische Auto-UUID aus dem Init — sonst würde die spätere
            // Edit-Reconciliation (siehe IdBackfill) die Ports auf einen einzigen kollabieren und
            // die Route verstümmeln.
            var seenPortIDs: Set<UUID> = []

            // Häfen importieren
            for (index, exportPort) in exportCruise.route.enumerated() {
                // H3-Fix: explizites Flag hat Vorrang; nur Alt-Formate ohne das Feld (exportPort.isSeaDay
                // == nil) fallen auf die Namens-Heuristik zurück. `lat == nil` klassifiziert nicht mehr
                // als Seetag — ein benannter Hafen ohne (noch) aufgelöste Koordinaten bleibt ein Hafen.
                let isSeaDay = exportPort.isSeaDay ?? (
                    exportPort.name.lowercased() == "seetag" ||
                    exportPort.name.lowercased() == "sea day"
                )

                let lat = Double(exportPort.lat ?? "0") ?? 0
                let lng = Double(exportPort.lng ?? "0") ?? 0

                let port = Port(
                    name: exportPort.name,
                    country: exportPort.country ?? "",
                    latitude: lat,
                    longitude: lng
                )

                if let arrivalDate = dateTimeFormatter.date(from: exportPort.arrival) ?? dateFormatter.date(from: exportPort.arrival) {
                    port.arrival = arrivalDate
                }
                if let departureDate = dateTimeFormatter.date(from: exportPort.departure) ?? dateFormatter.date(from: exportPort.departure) {
                    port.departure = departureDate
                }

                port.sortOrder = index
                port.isSeaDay = isSeaDay
                port.excursions = exportPort.excursions

                // Stabiele Port-ID übernehmen — nur beim ersten Vorkommen dieser ID in der Cruise
                if let portUUID = UUID(uuidString: exportPort.id), !seenPortIDs.contains(portUUID) {
                    port.id = portUUID
                    seenPortIDs.insert(portUUID)
                }

                // Hafen-Bild importieren (Pfadreferenz aus data.json: ../-Traversal/absolute Pfade abgelehnt)
                if let imagesDir = imagesDir, let imageUrlString = exportPort.imageUrl {
                    if let imagePath = try? ZipArchiveReader.resolveSafePath(imageUrlString, in: imagesDir),
                       let imageData = try? Data(contentsOf: imagePath),
                       isValidImageData(imageData) {
                        port.imageData = imageData
                    } else {
                        // Referenzierte Bilddatei fehlt im Archiv, ist unlesbar, inhaltlich kein
                        // gültiges Bild, oder der Pfad wurde abgelehnt: Hafen bleibt erhalten, nur das
                        // Bild fehlt (H8).
                        invalidMediaCount += 1
                    }
                }

                port.cruise = cruise
                modelContext.insert(port)
            }

            // Fotos importieren (Base64 oder Dateipfad).
            // Gleiches ID-Duplikat-Muster wie bei Ports, aber archivweit statt pro Cruise —
            // `seenPhotoIDs` ist oben deklariert und mit den bestehenden DB-Foto-IDs vorbelegt.
            for (index, exportPhoto) in exportCruise.photos.enumerated() {
                guard let imageData = resolvePhotoData(exportPhoto.ref, imagesDir: imagesDir) else {
                    // Referenz nicht auflösbar oder inhaltlich kein gültiges Bild: Photo wird
                    // übersprungen, Cruise bleibt erhalten (H8).
                    invalidMediaCount += 1
                    continue
                }

                let photo = Photo(imageData: imageData, sortOrder: index)
                photo.thumbnailData = ImageDownsampler.thumbnail(from: imageData)
                // Stabile Foto-ID übernehmen; 1.7-Dateien tragen keine id, dort bleibt die
                // frische UUID aus dem Init.
                if let photoUUID = exportPhoto.id.flatMap({ UUID(uuidString: $0) }),
                   !seenPhotoIDs.contains(photoUUID) {
                    photo.id = photoUUID
                    seenPhotoIDs.insert(photoUUID)
                }
                photo.cruise = cruise
                modelContext.insert(photo)
            }

            // Ausgaben importieren
            // Gleiches Duplikat-Muster wie bei Ports: nur das erste Vorkommen einer id in dieser
            // Cruise übernimmt die Datei-ID, jedes weitere behält seine frische Auto-UUID.
            var seenExpenseIDs: Set<UUID> = []
            for exportExpense in exportCruise.expenses {
                let category = mapCategory(exportExpense.category)
                let expense = Expense(
                    category: category,
                    amount: exportExpense.amount,
                    description: exportExpense.description ?? ""
                )
                if let dateString = exportExpense.expenseDate,
                   let date = dateFormatter.date(from: dateString) {
                    expense.expenseDate = date
                }
                // Stabile Expense-ID übernehmen — nur beim ersten Vorkommen dieser ID in der Cruise
                if let expenseUUID = UUID(uuidString: exportExpense.id), !seenExpenseIDs.contains(expenseUUID) {
                    expense.id = expenseUUID
                    seenExpenseIDs.insert(expenseUUID)
                }
                expense.cruise = cruise
                modelContext.insert(expense)
            }

            importedCount += 1
        }

        importDeals(archive.deals, modelContext: modelContext)
        importCatalogOverlay(archive, modelContext: modelContext)

        do {
            try modelContext.save()
        } catch {
            // Save fehlgeschlagen: bereits gestagte Import-Objekte (Cruises/Ports/Photos/Expenses)
            // dürfen nicht im Context verbleiben — Rollback, dann Fehler weiterreichen.
            modelContext.rollback()
            throw error
        }
        return ImportResult(imported: importedCount, skippedDuplicates: skippedDuplicates, skippedInvalid: skippedInvalid, invalidMedia: invalidMediaCount)
    }

    /// Löst eine Foto-Referenz zu validierten Bilddaten auf: Base64-Data-URL (Legacy- und
    /// JSON-Format) oder Pfadreferenz in das entpackte ZIP. `../`-Traversal und absolute Pfade
    /// werden von `resolveSafePath` abgelehnt. `nil` = nicht auflösbar oder kein gültiges Bild.
    private func resolvePhotoData(_ reference: String, imagesDir: URL?) -> Data? {
        if reference.hasPrefix("data:image") {
            guard let base64 = reference.components(separatedBy: ",").last,
                  let imageData = Data(base64Encoded: base64),
                  isValidImageData(imageData) else { return nil }
            return imageData
        }

        // Ohne ZIP-Kontext (JSON-Import ohne Bilder) ist eine Pfadreferenz nicht auflösbar.
        guard let imagesDir,
              let imagePath = try? ZipArchiveReader.resolveSafePath(reference, in: imagesDir),
              let imageData = try? Data(contentsOf: imagePath),
              isValidImageData(imageData) else { return nil }
        return imageData
    }

    /// Prüft, ob `data` von ImageIO als Bild dekodiert werden kann (Signatur-/Struktur-Check ohne
    /// vollständiges Decodieren). Verhindert, dass beliebige Bytes mit `.png`/`.jpg`-Namen (z. B. eine
    /// Textdatei) unvalidiert als Foto/Hafenbild übernommen werden.
    /// WICHTIG: `CGImageSourceCreateWithData` allein validiert nichts — die Quelle wird lazy erzeugt
    /// und ist auch für Nicht-Bild-Daten non-nil. Erst `CGImageSourceGetCount` liest die Bytes
    /// tatsächlich und liefert 0, wenn kein Bild erkannt wurde.
    private func isValidImageData(_ data: Data) -> Bool {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil) else {
            return false
        }
        return CGImageSourceGetCount(source) > 0
    }

    private func mapCategory(_ rawCategory: String) -> ExpenseCategory {
        switch rawCategory.lowercased() {
        case "excursion", "ausflug": return .excursion
        case "cruise", "kreuzfahrt": return .cruise
        case "flight", "flug": return .flight
        case "hotel": return .hotel
        case "onboard", "an bord": return .onboard
        default: return .other
        }
    }
}
