//
//  ExportImportService.swift
//  ShipTrip
//
//  Created by ShipTrip on 19.12.25.
//

import Foundation
import SwiftData
import UniformTypeIdentifiers

// MARK: - Export/Import Data Structures

/// Exportierbare Kreuzfahrt-Daten (kompatibel mit Web-App)
struct ExportCruise: Codable {
    let id: String
    let title: String
    let startDate: String
    let endDate: String
    let shippingLine: String
    let ship: String
    let cabinType: String?
    let cabinNumber: String?
    let bookingNumber: String?
    let notes: String?
    let rating: Int
    let route: [ExportPort]
    let photos: [String]
    let expenses: [ExportExpense]
}

struct ExportPort: Codable {
    let id: String
    let name: String
    let country: String?
    let lat: String?
    let lng: String?
    let arrival: String
    let departure: String
    let imageUrl: String?
    let excursions: [String]
}

struct ExportExpense: Codable {
    let id: String
    let cruiseId: String
    let category: String
    let description: String?
    let amount: Double
    let expenseDate: String?
    let createdAt: String
}

// MARK: - Import Result

struct ImportResult {
    let imported: Int
    let skippedDuplicates: Int
    let skippedInvalid: Int
}

// MARK: - Export/Import Service

class ExportImportService {
    static let shared = ExportImportService()

    private let dateFormatter: DateFormatter = {
        let df = DateFormatter()
        df.locale = Locale(identifier: "en_US_POSIX")
        df.dateFormat = "yyyy-MM-dd"
        return df
    }()

    private let dateTimeFormatter: DateFormatter = {
        let df = DateFormatter()
        df.locale = Locale(identifier: "en_US_POSIX")
        df.dateFormat = "yyyy-MM-dd'T'HH:mm:ss"
        return df
    }()

    private let isoFormatter: ISO8601DateFormatter = {
        let df = ISO8601DateFormatter()
        df.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return df
    }()

    // MARK: - Export (JSON, stablie IDs)

    /// Exportiert alle Kreuzfahrten als JSON-Datei mit stabilen IDs (kein frisches UUID())
    func exportToJSON(cruises: [Cruise]) throws -> URL {
        let exportCruises = buildExportCruises(cruises: cruises, photoEncoder: { cruise, _ in
            // Base64-kodierte Fotos (legacy-Format)
            cruise.photos.sorted { $0.sortOrder < $1.sortOrder }.map { photo in
                let base64 = photo.imageData.base64EncodedString()
                return "data:image/png;base64,\(base64)"
            }
        })

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let jsonData = try encoder.encode(exportCruises)

        let jsonPath = FileManager.default.temporaryDirectory
            .appendingPathComponent("kreuzfahrten-export-\(UUID().uuidString).json")
        try jsonData.write(to: jsonPath)

        return jsonPath
    }

    /// Exportiert alle Kreuzfahrten als ZIP-Archiv mit externalen Bilddateien.
    ///
    /// ZIP-Inhalt:
    /// - `data.json` – strukturierte Daten; Fotos als Pfadreferenzen `images/<cruiseId>/<index>`
    /// - `images/<cruiseId>/<index>` – Rohdaten aus `Photo.imageData` (verlustfrei, kein Re-Encoding)
    ///
    /// Das ZIP wird mit Compression Method 0 (STORED) geschrieben; kein Deflate.
    /// CRC-32 wird korrekt berechnet (IEEE 802.3 Polynom).
    func exportToZip(cruises: [Cruise]) throws -> URL {
        // Baue ZIP-Einträge: name -> data
        var zipEntries: [(name: String, data: Data)] = []

        // Baue JSON mit Pfadreferenzen (Dateiname ohne Extension; Erweiterung ist kosmetisch)
        let exportCruises = buildExportCruises(
            cruises: cruises,
            photoEncoder: { cruise, sortedPhotos in
                sortedPhotos.enumerated().map { index, _ in
                    "images/\(cruise.id.uuidString)/\(index)"
                }
            },
            portImageURL: { cruise, port, index in
                port.imageData != nil ? "images/\(cruise.id.uuidString)/ports/\(index)" : nil
            }
        )

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let jsonData = try encoder.encode(exportCruises)
        zipEntries.append(("data.json", jsonData))

        // Füge Bilddateien als Rohdaten ein (verlustfrei, kein UIImage-Re-Encoding)
        for cruise in cruises {
            let sortedRoute = cruise.route.sorted { $0.sortOrder < $1.sortOrder }
            for (index, port) in sortedRoute.enumerated() {
                if let imageData = port.imageData {
                    let entryName = "images/\(cruise.id.uuidString)/ports/\(index)"
                    zipEntries.append((entryName, imageData))
                }
            }

            let sortedPhotos = cruise.photos.sorted { $0.sortOrder < $1.sortOrder }
            for (index, photo) in sortedPhotos.enumerated() {
                let entryName = "images/\(cruise.id.uuidString)/\(index)"
                zipEntries.append((entryName, photo.imageData))
            }
        }

        let zipData = try ZipArchiveWriter.build(entries: zipEntries)

        let zipPath = FileManager.default.temporaryDirectory
            .appendingPathComponent("kreuzfahrten-export-\(UUID().uuidString).zip")
        try zipData.write(to: zipPath)

        return zipPath
    }

    /// Gemeinsame Logik zum Aufbau des ExportCruise-Arrays.
    /// `photoEncoder` gibt pro Kreuzfahrt die Foto-Strings zurück (Base64 oder Pfadreferenzen).
    /// `portImageURL` gibt pro Hafen die Bild-Pfadreferenz zurück (nil im Legacy-JSON-Format).
    private func buildExportCruises(
        cruises: [Cruise],
        photoEncoder: (Cruise, [Photo]) -> [String],
        portImageURL: (Cruise, Port, Int) -> String? = { _, _, _ in nil }
    ) -> [ExportCruise] {
        var result: [ExportCruise] = []

        for cruise in cruises {
            let sortedRoute = cruise.route.sorted { $0.sortOrder < $1.sortOrder }

            let exportPorts = sortedRoute.enumerated().map { index, port in
                ExportPort(
                    id: port.id.uuidString,
                    name: port.isSeaDay ? "Seetag" : port.name,
                    country: port.isSeaDay ? nil : port.country,
                    lat: port.isSeaDay ? nil : String(format: "%.8f", locale: Locale(identifier: "en_US_POSIX"), port.latitude),
                    lng: port.isSeaDay ? nil : String(format: "%.8f", locale: Locale(identifier: "en_US_POSIX"), port.longitude),
                    arrival: dateTimeFormatter.string(from: port.arrival),
                    departure: dateTimeFormatter.string(from: port.departure),
                    imageUrl: portImageURL(cruise, port, index),
                    excursions: port.excursions
                )
            }

            let exportExpenses = cruise.expenses.map { expense in
                ExportExpense(
                    id: expense.id.uuidString,
                    cruiseId: cruise.id.uuidString,
                    category: expense.category.rawValue.lowercased(),
                    description: expense.descriptionText,
                    amount: expense.amount,
                    expenseDate: expense.expenseDate != nil ? dateFormatter.string(from: expense.expenseDate!) : nil,
                    createdAt: isoFormatter.string(from: expense.createdAt)
                )
            }

            let sortedPhotos = cruise.photos.sorted { $0.sortOrder < $1.sortOrder }
            let photoStrings = photoEncoder(cruise, sortedPhotos)

            let exportCruise = ExportCruise(
                id: cruise.id.uuidString,
                title: cruise.title,
                startDate: dateFormatter.string(from: cruise.startDate),
                endDate: dateFormatter.string(from: cruise.endDate),
                shippingLine: cruise.shippingLine,
                ship: cruise.ship,
                cabinType: cruise.cabinType.isEmpty ? nil : cruise.cabinType,
                cabinNumber: cruise.cabinNumber.isEmpty ? nil : cruise.cabinNumber,
                bookingNumber: cruise.bookingNumber.isEmpty ? nil : cruise.bookingNumber,
                notes: cruise.notes.isEmpty ? nil : cruise.notes,
                rating: Int(cruise.rating),
                route: exportPorts,
                photos: photoStrings,
                expenses: exportExpenses
            )
            result.append(exportCruise)
        }

        return result
    }

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
        let decoder = JSONDecoder()
        let exportCruises = try decoder.decode([ExportCruise].self, from: data)

        // Hole existierende Kreuzfahrten für Duplikat-Check
        let descriptor = FetchDescriptor<Cruise>()
        let existingCruises = (try? modelContext.fetch(descriptor)) ?? []

        var importedCount = 0
        var skippedDuplicates = 0
        var skippedInvalid = 0

        // ID-basierte Duplikate INNERHALB derselben Import-Datei (z.B. manipuliertes data.json
        // mit zwei Cruises gleicher id): nur die erste wird importiert.
        var seenCruiseIDs: Set<UUID> = []

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
            cruise.rating = Double(exportCruise.rating)

            modelContext.insert(cruise)

            // ID-basierte Duplikate INNERHALB derselben Cruise (z.B. manipulierte Datei mit zwei
            // Ports gleicher id): nur das erste Vorkommen übernimmt die Datei-ID, jedes weitere
            // behält seine frische Auto-UUID aus dem Init — sonst würde die spätere
            // Edit-Reconciliation (siehe IdBackfill) die Ports auf einen einzigen kollabieren und
            // die Route verstümmeln.
            var seenPortIDs: Set<UUID> = []

            // Häfen importieren
            for (index, exportPort) in exportCruise.route.enumerated() {
                let isSeaDay = exportPort.name.lowercased() == "seetag" ||
                               exportPort.name.lowercased() == "sea day" ||
                               exportPort.lat == nil

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
                if let imagesDir = imagesDir, let imageUrlString = exportPort.imageUrl,
                   let imagePath = try? ZipArchiveReader.resolveSafePath(imageUrlString, in: imagesDir) {
                    if let imageData = try? Data(contentsOf: imagePath) {
                        port.imageData = imageData
                    }
                }

                port.cruise = cruise
                modelContext.insert(port)
            }

            // Fotos importieren (Base64 oder Dateipfad)
            for (index, photoRef) in exportCruise.photos.enumerated() {
                if photoRef.hasPrefix("data:image") {
                    // Legacy Base64-Format
                    if let base64Data = photoRef.components(separatedBy: ",").last,
                       let imageData = Data(base64Encoded: base64Data) {
                        let photo = Photo(imageData: imageData, sortOrder: index)
                        photo.thumbnailData = ImageDownsampler.thumbnail(from: imageData)
                        photo.cruise = cruise
                        modelContext.insert(photo)
                    }
                    // Fehlendes Bild: Photo-Objekt wird übersprungen, Cruise wird trotzdem importiert
                } else if let imagesDir = imagesDir,
                          let imagePath = try? ZipArchiveReader.resolveSafePath(photoRef, in: imagesDir) {
                    // ZIP-Pfadreferenz: fehlende Datei tolerieren (nur Photo überspringen);
                    // ../-Traversal/absolute Pfade werden von resolveSafePath abgelehnt
                    if let imageData = try? Data(contentsOf: imagePath) {
                        let photo = Photo(imageData: imageData, sortOrder: index)
                        photo.thumbnailData = ImageDownsampler.thumbnail(from: imageData)
                        photo.cruise = cruise
                        modelContext.insert(photo)
                    }
                    // Fehlende Bilddatei: Photo wird übersprungen, Cruise bleibt erhalten
                }
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

        do {
            try modelContext.save()
        } catch {
            // Save fehlgeschlagen: bereits gestagte Import-Objekte (Cruises/Ports/Photos/Expenses)
            // dürfen nicht im Context verbleiben — Rollback, dann Fehler weiterreichen.
            modelContext.rollback()
            throw error
        }
        return ImportResult(imported: importedCount, skippedDuplicates: skippedDuplicates, skippedInvalid: skippedInvalid)
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

    enum ImportError: LocalizedError {
        case noDataFile
        case invalidFormat
        /// Ein Pfad (ZIP-Eintrag oder Bildreferenz aus data.json) liegt außerhalb des Zielverzeichnisses
        /// oder ist absolut (Zip-Slip-Schutz).
        case unsafePath(String)
        /// Ein einzelner ZIP-Eintrag überschreitet das Größenlimit (Dekompressionsbomben-Schutz),
        /// geprüft anhand von uncompressedSize UND compressedSize.
        case entryTooLarge(name: String, size: Int)
        /// Die kumulierte (un-)komprimierte Größe aller Einträge oder die Archiv-Dateigröße selbst
        /// überschreitet das Limit.
        case archiveTooLarge(Int)
        /// STORED-Eintrag (Methode 0), dessen compressedSize nicht mit uncompressedSize übereinstimmt.
        case sizeMismatch(name: String)

        var errorDescription: String? {
            switch self {
            case .noDataFile:
                return "Keine data.json in der ZIP-Datei gefunden"
            case .invalidFormat:
                return "Ungültiges Dateiformat"
            case .unsafePath(let path):
                return "Unsicherer Pfad im Archiv abgelehnt: \(path)"
            case .entryTooLarge(let name, let size):
                return "ZIP-Eintrag '\(name)' überschreitet das Größenlimit (\(size) Bytes; Maximum \(ZipArchiveReader.maxEntryUncompressedSize) Bytes)"
            case .archiveTooLarge(let size):
                return "ZIP-Archiv überschreitet das kumulierte Größenlimit (\(size) Bytes; Maximum \(ZipArchiveReader.maxTotalUncompressedSize) Bytes)"
            case .sizeMismatch(let name):
                return "ZIP-Eintrag '\(name)': compressedSize stimmt nicht mit uncompressedSize überein (Methode STORED erfordert Gleichheit)"
            }
        }
    }
}
