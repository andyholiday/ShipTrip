//
//  ExportImportService.swift
//  ShipTrip
//
//  Created by ShipTrip on 19.12.25.
//

import Foundation
import SwiftData
import UniformTypeIdentifiers
import Compression

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
            .appendingPathComponent("kreuzfahrten-export.json")
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

        let zipData = try buildZip(entries: zipEntries)

        let zipPath = FileManager.default.temporaryDirectory
            .appendingPathComponent("kreuzfahrten-export.zip")
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

        try unzipFile(at: url, to: tempDir)

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
                   let imagePath = try? resolveSafePath(imageUrlString, in: imagesDir) {
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
                          let imagePath = try? resolveSafePath(photoRef, in: imagesDir) {
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

    // MARK: - ZIP Writer (Method 0 / STORED, kein Deflate)

    /// Baut ein ZIP-Archiv aus einer Liste von (Name, Daten)-Einträgen.
    ///
    /// Format: Compression Method 0 (STORED). Jeder Eintrag enthält:
    /// - Local File Header (30 Bytes + Name)
    /// - Datei-Daten (unkomprimiert)
    ///
    /// Nach allen Einträgen folgen:
    /// - Central Directory (46 Bytes + Name pro Eintrag)
    /// - End of Central Directory (22 Bytes)
    ///
    /// CRC-32 wird nach dem IEEE 802.3-Polynom (0xEDB88320, reflected) berechnet.
    ///
    /// ANNAHME (Größenbeschränkung): Alle Größen und Offsets passen in UInt32 (<4 GB).
    /// Für Kreuzfahrt-Exporte realistisch; kein ZIP64-Support.
    /// Gecachte Metadaten eines ZIP-Eintrags nach dem ersten Durchlauf.
    private struct ZipEntryMeta {
        let nameData: Data
        let crc: UInt32
        let size: UInt32
        let localHeaderOffset: UInt32
    }

    private func buildZip(entries: [(name: String, data: Data)]) throws -> Data {
        // ZIP-Überlaufschutz: UInt16 begrenzt die Eintragsanzahl, UInt32 die Einzelgröße.
        // Lieber explizit werfen als still truncaten — das ist ein Backup-Feature.
        guard entries.count <= Int(UInt16.max) else {
            throw ZipWriterError.tooManyEntries(entries.count)
        }
        for (name, data) in entries where data.count > Int(UInt32.max) {
            throw ZipWriterError.entryTooLarge(name: name, size: data.count)
        }

        var archive = Data()

        // Modifiziertes Datum/Zeit für alle Einträge (aktuell, DOS-Format)
        let (dosDate, dosTime) = currentDosDateTime()

        // Erster Durchlauf: Local File Headers schreiben und Metadaten cachen.
        // CRC-32 und Größe werden hier EINMALIG berechnet und im Cache gehalten,
        // damit der Central-Directory-Durchlauf dieselben Werte verwendet —
        // keine zweite Berechnung, kein möglicher Widerspruch.
        var metas: [ZipEntryMeta] = []
        metas.reserveCapacity(entries.count)

        for (name, fileData) in entries {
            guard let nameData = name.data(using: .utf8) else {
                throw ZipWriterError.invalidEntryName(name)
            }

            let crc = crc32(fileData)
            let size = UInt32(fileData.count)
            guard archive.count <= Int(UInt32.max) else {
                throw ZipWriterError.archiveTooLarge(archive.count)
            }
            let localHeaderOffset = UInt32(archive.count)

            metas.append(ZipEntryMeta(
                nameData: nameData,
                crc: crc,
                size: size,
                localHeaderOffset: localHeaderOffset
            ))

            // Local File Header
            // Offset  Länge  Bedeutung
            //  0       4     Signatur 0x04034B50
            //  4       2     Version needed (20 = 2.0)
            //  6       2     General purpose bit flag
            //  8       2     Compression method (0 = STORED)
            // 10       2     Last mod file time (DOS)
            // 12       2     Last mod file date (DOS)
            // 14       4     CRC-32
            // 18       4     Compressed size
            // 22       4     Uncompressed size
            // 26       2     File name length
            // 28       2     Extra field length
            // 30       n     File name
            // 30+n     m     Extra field (leer)
            // 30+n+m   s     File data
            archive.append(contentsOf: [0x50, 0x4B, 0x03, 0x04])          // Signatur
            archive.appendUInt16LE(20)                                      // Version needed
            archive.appendUInt16LE(0)                                       // Bit flag
            archive.appendUInt16LE(0)                                       // Compression: STORED
            archive.appendUInt16LE(dosTime)                                 // Mod time
            archive.appendUInt16LE(dosDate)                                 // Mod date
            archive.appendUInt32LE(crc)                                     // CRC-32
            archive.appendUInt32LE(size)                                    // Compressed size
            archive.appendUInt32LE(size)                                    // Uncompressed size
            archive.appendUInt16LE(UInt16(nameData.count))                  // Name length
            archive.appendUInt16LE(0)                                       // Extra field length
            archive.append(nameData)                                        // File name
            archive.append(fileData)                                        // File data
        }

        guard archive.count <= Int(UInt32.max) else {
            throw ZipWriterError.archiveTooLarge(archive.count)
        }
        let centralDirOffset = archive.count

        // Zweiter Durchlauf: Central Directory aus dem Cache schreiben.
        // Kein erneuter Zugriff auf fileData; alle Werte kommen aus ZipEntryMeta.
        for meta in metas {
            let nameData = meta.nameData
            let crc = meta.crc
            let size = meta.size
            let localOffset = meta.localHeaderOffset
            // Central Directory File Header
            // Offset  Länge  Bedeutung
            //  0       4     Signatur 0x02014B50
            //  4       2     Version made by (20)
            //  6       2     Version needed (20)
            //  8       2     General purpose bit flag
            // 10       2     Compression method
            // 12       2     Last mod file time
            // 14       2     Last mod file date
            // 16       4     CRC-32
            // 20       4     Compressed size
            // 24       4     Uncompressed size
            // 28       2     File name length
            // 30       2     Extra field length
            // 32       2     File comment length
            // 34       2     Disk number start
            // 36       2     Internal file attributes
            // 38       4     External file attributes
            // 42       4     Relative offset of local header
            // 46       n     File name
            archive.append(contentsOf: [0x50, 0x4B, 0x01, 0x02])          // Signatur
            archive.appendUInt16LE(20)                                      // Version made by
            archive.appendUInt16LE(20)                                      // Version needed
            archive.appendUInt16LE(0)                                       // Bit flag
            archive.appendUInt16LE(0)                                       // Compression: STORED
            archive.appendUInt16LE(dosTime)                                 // Mod time
            archive.appendUInt16LE(dosDate)                                 // Mod date
            archive.appendUInt32LE(crc)                                     // CRC-32
            archive.appendUInt32LE(size)                                    // Compressed size
            archive.appendUInt32LE(size)                                    // Uncompressed size
            archive.appendUInt16LE(UInt16(nameData.count))                  // Name length
            archive.appendUInt16LE(0)                                       // Extra field length
            archive.appendUInt16LE(0)                                       // Comment length
            archive.appendUInt16LE(0)                                       // Disk number start
            archive.appendUInt16LE(0)                                       // Internal attributes
            archive.appendUInt32LE(0)                                       // External attributes
            archive.appendUInt32LE(localOffset)                             // Local header offset
            archive.append(nameData)                                        // File name
        }

        let centralDirSize = archive.count - centralDirOffset
        guard centralDirSize <= Int(UInt32.max) else {
            throw ZipWriterError.archiveTooLarge(archive.count)
        }
        let numEntries = UInt16(entries.count)

        // End of Central Directory (EOCD)
        // Offset  Länge  Bedeutung
        //  0       4     Signatur 0x06054B50
        //  4       2     Disk number
        //  6       2     Disk with start of central directory
        //  8       2     Number of entries on this disk
        // 10       2     Total number of entries
        // 12       4     Size of central directory
        // 16       4     Offset of central directory
        // 20       2     Comment length
        archive.append(contentsOf: [0x50, 0x4B, 0x05, 0x06])              // Signatur
        archive.appendUInt16LE(0)                                           // Disk number
        archive.appendUInt16LE(0)                                           // Start disk
        archive.appendUInt16LE(numEntries)                                  // Entries on disk
        archive.appendUInt16LE(numEntries)                                  // Total entries
        archive.appendUInt32LE(UInt32(centralDirSize))                      // CD size
        archive.appendUInt32LE(UInt32(centralDirOffset))                    // CD offset
        archive.appendUInt16LE(0)                                           // Comment length

        return archive
    }

    enum ZipWriterError: LocalizedError {
        case invalidEntryName(String)
        /// ZIP-Format unterstützt maximal 65.535 Einträge (UInt16).
        case tooManyEntries(Int)
        /// Ein einzelner Eintrag überschreitet die UInt32-Größenbeschränkung (kein ZIP64-Support).
        case entryTooLarge(name: String, size: Int)
        /// Das kumulierte Archiv überschreitet 4 GB; ZIP32-Offsets würden überlaufen (kein ZIP64-Support).
        case archiveTooLarge(Int)

        var errorDescription: String? {
            switch self {
            case .invalidEntryName(let name):
                return "ZIP-Eintragsname konnte nicht als UTF-8 kodiert werden: \(name)"
            case .tooManyEntries(let count):
                return "Zu viele ZIP-Einträge (\(count)); Maximum ist \(UInt16.max)"
            case .entryTooLarge(let name, let size):
                return "ZIP-Eintrag '\(name)' ist zu groß (\(size) Bytes); Maximum ohne ZIP64 ist \(UInt32.max) Bytes"
            case .archiveTooLarge(let size):
                return "ZIP-Archiv zu groß (\(size) Bytes); Maximum ohne ZIP64 ist \(UInt32.max) Bytes"
            }
        }
    }

    // MARK: - CRC-32 (IEEE 802.3, Polynom 0xEDB88320, reflected)

    /// CRC-32-Lookup-Tabelle (einmalig berechnet).
    private static let crc32Table: [UInt32] = {
        (0..<256).map { n -> UInt32 in
            var c = UInt32(n)
            for _ in 0..<8 {
                if c & 1 == 1 {
                    c = 0xEDB88320 ^ (c >> 1)
                } else {
                    c = c >> 1
                }
            }
            return c
        }
    }()

    /// Berechnet CRC-32 eines Data-Objekts.
    private func crc32(_ data: Data) -> UInt32 {
        var crc: UInt32 = 0xFFFFFFFF
        for byte in data {
            let index = Int((crc ^ UInt32(byte)) & 0xFF)
            crc = (crc >> 8) ^ ExportImportService.crc32Table[index]
        }
        return crc ^ 0xFFFFFFFF
    }

    // MARK: - DOS-Datum/Zeit-Konvertierung

    /// Gibt das aktuelle Datum und die aktuelle Zeit im DOS-Format zurück.
    ///
    /// DOS-Zeit (Bits 15-11: Stunden, 10-5: Minuten, 4-0: Sekunden/2)
    /// DOS-Datum (Bits 15-9: Jahr-1980, 8-5: Monat, 4-0: Tag)
    private func currentDosDateTime() -> (date: UInt16, time: UInt16) {
        let now = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute, .second], from: Date())
        let year = UInt16(max(0, (now.year ?? 1980) - 1980))
        let month = UInt16(now.month ?? 1)
        let day = UInt16(now.day ?? 1)
        let hour = UInt16(now.hour ?? 0)
        let minute = UInt16(now.minute ?? 0)
        let second = UInt16((now.second ?? 0) / 2)

        let dosDate = (year << 9) | (month << 5) | day
        let dosTime = (hour << 11) | (minute << 5) | second
        return (dosDate, dosTime)
    }

    // MARK: - ZIP Extraction

    /// Maximale unkomprimierte Größe eines einzelnen ZIP-Eintrags (Dekompressionsbomben-Schutz).
    private static let maxEntryUncompressedSize = 50 * 1024 * 1024

    /// Maximale kumulierte unkomprimierte Größe aller Einträge eines Archivs.
    private static let maxTotalUncompressedSize = 500 * 1024 * 1024

    /// Maximale Größe der ZIP-Datei selbst (konsistent zum 500-MB-Gesamtlimit + Overhead).
    /// Wird geprüft, BEVOR das Archiv überhaupt in den Speicher gelesen wird.
    private static let maxArchiveFileSize = 550 * 1024 * 1024

    /// Löst einen aus dem Archiv bzw. aus `data.json` stammenden, nicht vertrauenswürdigen
    /// relativen Pfad sicher gegen ein Basisverzeichnis auf (Zip-Slip-Schutz).
    /// Lehnt leere/absolute Pfade sowie jede Auflösung außerhalb von `baseURL` ab.
    private func resolveSafePath(_ relativePath: String, in baseURL: URL) throws -> URL {
        guard !relativePath.isEmpty, !relativePath.hasPrefix("/"), !relativePath.hasPrefix("~") else {
            throw ImportError.unsafePath(relativePath)
        }
        guard !relativePath.contains("\\") else {
            throw ImportError.unsafePath(relativePath)
        }

        // Rohe POSIX-Komponenten VOR jeder Standardisierung prüfen: Traversal-Aliase wie
        // "foo/../data.json" dürfen nicht erst NACH dem Normalisieren erkannt werden, weil das
        // Ergebnis rein zufällig wieder innerhalb von baseURL landen kann. Ein einzelner
        // Trailing-Slash markiert ein Verzeichnis (ZIP-Konvention) und wird vorher entfernt.
        let trimmed = relativePath.hasSuffix("/") ? String(relativePath.dropLast()) : relativePath
        guard !trimmed.isEmpty else {
            throw ImportError.unsafePath(relativePath)
        }
        for component in trimmed.split(separator: "/", omittingEmptySubsequences: false) {
            guard !component.isEmpty, component != ".", component != ".." else {
                throw ImportError.unsafePath(relativePath)
            }
        }

        // Defense-in-Depth: zusätzlich sicherstellen, dass die standardisierte Auflösung
        // innerhalb von baseURL bleibt.
        let base = baseURL.standardizedFileURL
        let candidate = base.appendingPathComponent(relativePath).standardizedFileURL

        let baseComponents = base.pathComponents
        let candidateComponents = candidate.pathComponents
        guard candidateComponents.count > baseComponents.count,
              Array(candidateComponents.prefix(baseComponents.count)) == baseComponents else {
            throw ImportError.unsafePath(relativePath)
        }

        return candidate
    }

    private func unzipFile(at sourceURL: URL, to destinationURL: URL) throws {
        // Archiv-Dateigröße prüfen, BEVOR irgendetwas in den Speicher gelesen wird (die Datei wird
        // sonst zweimal komplett als Data eingelesen, bevor der Central-Directory-Check greift).
        let attributes = try FileManager.default.attributesOfItem(atPath: sourceURL.path)
        let fileSize = attributes[.size] as? Int ?? 0
        guard fileSize <= ExportImportService.maxArchiveFileSize else {
            throw ImportError.archiveTooLarge(fileSize)
        }

        let zipData = try Data(contentsOf: sourceURL)
        let tempZipPath = destinationURL.appendingPathComponent("temp.zip")
        try zipData.write(to: tempZipPath)

        try parseAndExtractZip(from: tempZipPath, to: destinationURL)

        try? FileManager.default.removeItem(at: tempZipPath)
    }

    private func parseAndExtractZip(from zipURL: URL, to destURL: URL) throws {
        guard let data = try? Data(contentsOf: zipURL) else {
            throw ImportError.invalidFormat
        }

        guard data.count > 22 else { throw ImportError.invalidFormat }

        var eocdOffset: Int?
        for i in stride(from: data.count - 22, through: Swift.max(0, data.count - 65557), by: -1) {
            if data[i] == 0x50 && data[i+1] == 0x4B && data[i+2] == 0x05 && data[i+3] == 0x06 {
                eocdOffset = i
                break
            }
        }

        guard let eocd = eocdOffset else { throw ImportError.invalidFormat }

        let cdOffset = Int(data[eocd + 16]) | (Int(data[eocd + 17]) << 8) | (Int(data[eocd + 18]) << 16) | (Int(data[eocd + 19]) << 24)
        let numEntries = Int(data[eocd + 10]) | (Int(data[eocd + 11]) << 8)

        var offset = cdOffset
        var cumulativeUncompressedSize = 0
        var cumulativeCompressedSize = 0
        for _ in 0..<numEntries {
            guard offset + 46 <= data.count else { break }

            guard data[offset] == 0x50 && data[offset+1] == 0x4B && data[offset+2] == 0x01 && data[offset+3] == 0x02 else { break }

            let compressionMethod = Int(data[offset + 10]) | (Int(data[offset + 11]) << 8)
            let compressedSize = Int(data[offset + 20]) | (Int(data[offset + 21]) << 8) | (Int(data[offset + 22]) << 16) | (Int(data[offset + 23]) << 24)
            let uncompressedSize = Int(data[offset + 24]) | (Int(data[offset + 25]) << 8) | (Int(data[offset + 26]) << 16) | (Int(data[offset + 27]) << 24)
            let nameLength = Int(data[offset + 28]) | (Int(data[offset + 29]) << 8)
            let extraLength = Int(data[offset + 30]) | (Int(data[offset + 31]) << 8)
            let commentLength = Int(data[offset + 32]) | (Int(data[offset + 33]) << 8)
            let localHeaderOffset = Int(data[offset + 42]) | (Int(data[offset + 43]) << 8) | (Int(data[offset + 44]) << 16) | (Int(data[offset + 45]) << 24)

            guard offset + 46 + nameLength <= data.count else { break }

            let nameData = data[offset + 46 ..< offset + 46 + nameLength]
            let name = String(data: nameData, encoding: .utf8) ?? ""

            // Größen-Limits: aus dem Header geprüft, bevor irgendetwas dekomprimiert/allokiert/kopiert wird.
            // WICHTIG: die Extraktion liest tatsächlich `compressedSize` Bytes (Data-Kopie) und schreibt
            // sie bei STORED direkt weg — ein Header mit kleinem uncompressedSize, aber großem
            // compressedSize, würde die Limits sonst umgehen. Deshalb wird compressedSize genauso geprüft.
            guard uncompressedSize <= ExportImportService.maxEntryUncompressedSize else {
                throw ImportError.entryTooLarge(name: name, size: uncompressedSize)
            }
            guard compressedSize <= ExportImportService.maxEntryUncompressedSize else {
                throw ImportError.entryTooLarge(name: name, size: compressedSize)
            }
            if compressionMethod == 0 {
                // STORED: unkomprimiert, compressedSize muss zwingend uncompressedSize entsprechen.
                guard compressedSize == uncompressedSize else {
                    throw ImportError.sizeMismatch(name: name)
                }
            }
            cumulativeUncompressedSize += uncompressedSize
            guard cumulativeUncompressedSize <= ExportImportService.maxTotalUncompressedSize else {
                throw ImportError.archiveTooLarge(cumulativeUncompressedSize)
            }
            cumulativeCompressedSize += compressedSize
            guard cumulativeCompressedSize <= ExportImportService.maxTotalUncompressedSize else {
                throw ImportError.archiveTooLarge(cumulativeCompressedSize)
            }

            let isDirectory = name.hasSuffix("/")
            let destinationPath = try resolveSafePath(name, in: destURL)

            if isDirectory {
                try FileManager.default.createDirectory(at: destinationPath, withIntermediateDirectories: true)
            } else {
                try FileManager.default.createDirectory(at: destinationPath.deletingLastPathComponent(), withIntermediateDirectories: true)

                guard localHeaderOffset + 30 <= data.count else { continue }
                let localNameLength = Int(data[localHeaderOffset + 26]) | (Int(data[localHeaderOffset + 27]) << 8)
                let localExtraLength = Int(data[localHeaderOffset + 28]) | (Int(data[localHeaderOffset + 29]) << 8)

                let dataOffset = localHeaderOffset + 30 + localNameLength + localExtraLength

                if dataOffset + compressedSize <= data.count {
                    let compressedData = Data(data[dataOffset ..< dataOffset + compressedSize])

                    var fileData: Data?
                    if compressionMethod == 0 {
                        fileData = compressedData
                    } else if compressionMethod == 8 {
                        fileData = decompressDeflate(compressedData, uncompressedSize: uncompressedSize)
                    }

                    if let fileData = fileData {
                        try fileData.write(to: destinationPath)
                    }
                }
            }

            offset += 46 + nameLength + extraLength + commentLength
        }
    }

    private func decompressDeflate(_ data: Data, uncompressedSize: Int) -> Data? {
        // Verteidigung in der Tiefe: der Aufrufer prüft uncompressedSize bereits gegen
        // maxEntryUncompressedSize, bevor allokiert wird — diese Funktion darf aber nie
        // mit einer untrusted Größe über dem Limit aufgerufen werden.
        guard uncompressedSize > 0, uncompressedSize <= ExportImportService.maxEntryUncompressedSize else { return nil }

        let destBuffer = UnsafeMutablePointer<UInt8>.allocate(capacity: uncompressedSize)
        defer { destBuffer.deallocate() }

        let decodedSize = data.withUnsafeBytes { (srcPtr: UnsafeRawBufferPointer) -> Int in
            guard let baseAddress = srcPtr.baseAddress else { return 0 }
            return compression_decode_buffer(
                destBuffer,
                uncompressedSize,
                baseAddress.assumingMemoryBound(to: UInt8.self),
                data.count,
                nil,
                COMPRESSION_ZLIB
            )
        }

        guard decodedSize > 0 else { return nil }
        return Data(bytes: destBuffer, count: decodedSize)
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
                return "ZIP-Eintrag '\(name)' überschreitet das Größenlimit (\(size) Bytes; Maximum \(ExportImportService.maxEntryUncompressedSize) Bytes)"
            case .archiveTooLarge(let size):
                return "ZIP-Archiv überschreitet das kumulierte Größenlimit (\(size) Bytes; Maximum \(ExportImportService.maxTotalUncompressedSize) Bytes)"
            case .sizeMismatch(let name):
                return "ZIP-Eintrag '\(name)': compressedSize stimmt nicht mit uncompressedSize überein (Methode STORED erfordert Gleichheit)"
            }
        }
    }
}

// MARK: - Data Helpers (Little-Endian Append)

private extension Data {
    mutating func appendUInt16LE(_ value: UInt16) {
        append(UInt8(value & 0xFF))
        append(UInt8((value >> 8) & 0xFF))
    }

    mutating func appendUInt32LE(_ value: UInt32) {
        append(UInt8(value & 0xFF))
        append(UInt8((value >> 8) & 0xFF))
        append(UInt8((value >> 16) & 0xFF))
        append(UInt8((value >> 24) & 0xFF))
    }
}
