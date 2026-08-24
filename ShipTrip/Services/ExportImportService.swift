//
//  ExportImportService.swift
//  ShipTrip
//
//  Created by ShipTrip on 19.12.25.
//

import Foundation
import SwiftData
import UniformTypeIdentifiers

// Die Codable-Datenstrukturen des Backup-Formats liegen in `ExportImportDTOs.swift`.

// MARK: - Import Result

struct ImportResult {
    let imported: Int
    let skippedDuplicates: Int
    let skippedInvalid: Int
    /// Anzahl Foto-/Hafenbild-Referenzen, die nicht aufgelöst werden konnten (Datei fehlt im Archiv,
    /// ungültige Base64-Daten oder abgelehnter Pfad). Die zugehörige Kreuzfahrt/der Hafen wird trotzdem
    /// importiert, nur das Bild fehlt (H8).
    let invalidMedia: Int
}

// MARK: - Export/Import Service

@MainActor
class ExportImportService {
    static let shared = ExportImportService()

    // Die drei Formatter sind bewusst `internal` statt `private`: der Import-Pfad liegt in
    // `ExportImportService+Import.swift` / `+CatalogImport.swift` und braucht exakt dieselben
    // Formate wie der Export.
    let dateFormatter: DateFormatter = {
        let df = DateFormatter()
        df.locale = Locale(identifier: "en_US_POSIX")
        df.dateFormat = "yyyy-MM-dd"
        return df
    }()

    let dateTimeFormatter: DateFormatter = {
        let df = DateFormatter()
        df.locale = Locale(identifier: "en_US_POSIX")
        df.dateFormat = "yyyy-MM-dd'T'HH:mm:ss"
        return df
    }()

    let isoFormatter: ISO8601DateFormatter = {
        let df = ISO8601DateFormatter()
        df.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return df
    }()

    // MARK: - Export (JSON, stabile IDs)

    /// Exportiert Kreuzfahrten samt Wunschreisen und Katalog-Overlay als JSON-Datei mit stabilen
    /// IDs (kein frisches UUID()). Fotos stecken Base64-kodiert inline in der Datei.
    func exportToJSON(
        cruises: [Cruise],
        deals: [Deal] = [],
        customLines: [CustomShippingLine] = [],
        customShips: [CustomShip] = [],
        hiddenCatalogItems: [HiddenCatalogItem] = []
    ) throws -> URL {
        let archive = buildArchive(
            cruises: Self.nonDemo(cruises),
            deals: Self.nonDemo(deals),
            customLines: customLines,
            customShips: customShips,
            hiddenCatalogItems: hiddenCatalogItems,
            photoEncoder: { _, sortedPhotos in
                sortedPhotos.map { photo in
                    let base64 = photo.imageData.base64EncodedString()
                    return ExportPhoto(id: photo.id.uuidString, ref: "data:image/png;base64,\(base64)")
                }
            }
        )

        let jsonData = try encodeArchive(archive)

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
    func exportToZip(
        cruises: [Cruise],
        deals: [Deal] = [],
        customLines: [CustomShippingLine] = [],
        customShips: [CustomShip] = [],
        hiddenCatalogItems: [HiddenCatalogItem] = []
    ) throws -> URL {
        // Baue ZIP-Einträge: name -> data
        var zipEntries: [(name: String, data: Data)] = []

        // Demo-Daten gehören nie in ein Backup. Der Filter liegt bewusst hier im Service und
        // nicht an der Aufrufstelle, damit ihn jeder Export-Pfad zwangsläufig durchläuft.
        let exportableCruises = Self.nonDemo(cruises)

        // Baue JSON mit Pfadreferenzen (Dateiname ohne Extension; Erweiterung ist kosmetisch)
        let archive = buildArchive(
            cruises: exportableCruises,
            deals: Self.nonDemo(deals),
            customLines: customLines,
            customShips: customShips,
            hiddenCatalogItems: hiddenCatalogItems,
            photoEncoder: { cruise, sortedPhotos in
                sortedPhotos.enumerated().map { index, photo in
                    ExportPhoto(id: photo.id.uuidString, ref: "images/\(cruise.id.uuidString)/\(index)")
                }
            },
            portImageURL: { cruise, port, index in
                port.imageData != nil ? "images/\(cruise.id.uuidString)/ports/\(index)" : nil
            }
        )

        let jsonData = try encodeArchive(archive)
        zipEntries.append(("data.json", jsonData))

        // Füge Bilddateien als Rohdaten ein (verlustfrei, kein UIImage-Re-Encoding)
        for cruise in exportableCruises {
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

    /// Kreuzfahrten/Wunschreisen ohne Demo-Daten. Demo-Inhalte (`isDemo`) dürfen nie in einem
    /// Backup landen — weder Kreuzfahrten noch Wunschreisen (`DemoDataService` erzeugt beides).
    private static func nonDemo(_ cruises: [Cruise]) -> [Cruise] {
        cruises.filter { !$0.isDemo }
    }

    private static func nonDemo(_ deals: [Deal]) -> [Deal] {
        deals.filter { !$0.isDemo }
    }

    private func encodeArchive(_ archive: ExportArchive) throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return try encoder.encode(archive)
    }

    /// Baut den Export-Envelope. Erwartet bereits demo-gefilterte Eingaben (siehe `nonDemo`).
    /// `photoEncoder` gibt pro Kreuzfahrt die Foto-Referenzen zurück (Base64 oder ZIP-Pfad).
    /// `portImageURL` gibt pro Hafen die Bild-Pfadreferenz zurück (nil im JSON-Format).
    private func buildArchive(
        cruises: [Cruise],
        deals: [Deal],
        customLines: [CustomShippingLine],
        customShips: [CustomShip],
        hiddenCatalogItems: [HiddenCatalogItem],
        photoEncoder: (Cruise, [Photo]) -> [ExportPhoto],
        portImageURL: (Cruise, Port, Int) -> String? = { _, _, _ in nil }
    ) -> ExportArchive {
        ExportArchive(
            cruises: buildExportCruises(
                cruises: cruises, photoEncoder: photoEncoder, portImageURL: portImageURL
            ),
            deals: deals.map(buildExportDeal),
            customShippingLines: customLines.map { line in
                ExportCustomShippingLine(
                    id: line.id.uuidString,
                    name: line.name,
                    logo: line.logo,
                    createdAt: isoFormatter.string(from: line.createdAt),
                    updatedAt: isoFormatter.string(from: line.updatedAt)
                )
            },
            customShips: customShips.map { ship in
                ExportCustomShip(
                    id: ship.id.uuidString,
                    name: ship.name,
                    lineOptionID: ship.lineOptionID,
                    createdAt: isoFormatter.string(from: ship.createdAt),
                    updatedAt: isoFormatter.string(from: ship.updatedAt)
                )
            },
            hiddenCatalogItems: hiddenCatalogItems.map { item in
                ExportHiddenCatalogItem(
                    id: item.id.uuidString,
                    lineID: item.lineID,
                    shipKey: item.shipKey,
                    createdAt: isoFormatter.string(from: item.createdAt)
                )
            }
        )
    }

    private func buildExportDeal(_ deal: Deal) -> ExportDeal {
        ExportDeal(
            id: deal.id.uuidString,
            title: deal.title,
            shippingLine: deal.shippingLine,
            ship: deal.ship,
            destination: deal.destination,
            price: deal.price,
            originalPrice: deal.originalPrice,
            startDate: deal.startDate.map { dateFormatter.string(from: $0) },
            endDate: deal.endDate.map { dateFormatter.string(from: $0) },
            url: deal.url,
            notes: deal.notes,
            createdAt: isoFormatter.string(from: deal.createdAt),
            updatedAt: isoFormatter.string(from: deal.updatedAt)
        )
    }

    private func buildExportCruises(
        cruises: [Cruise],
        photoEncoder: (Cruise, [Photo]) -> [ExportPhoto],
        portImageURL: (Cruise, Port, Int) -> String? = { _, _, _ in nil }
    ) -> [ExportCruise] {
        var result: [ExportCruise] = []

        for cruise in cruises {
            let sortedRoute = cruise.route.sorted { $0.sortOrder < $1.sortOrder }

            let exportPorts = sortedRoute.enumerated().map { index, port in
                ExportPort(
                    id: port.id.uuidString,
                    // H3-Fix: Name nie durch "Seetag" ersetzen — isSeaDay ist ausschließlich das
                    // Klassifikations-Flag, der echte Name bleibt auch für Seetage erhalten.
                    name: port.name,
                    // Land und Koordinaten werden für Seetage NICHT mehr genullt: `isSeaDay` ist
                    // das alleinige Klassifikations-Flag, und ein Seetag mit erfassten
                    // Koordinaten trägt die Routenlinie auf der Karte.
                    country: port.country,
                    lat: String(format: "%.8f", locale: Locale(identifier: "en_US_POSIX"), port.latitude),
                    lng: String(format: "%.8f", locale: Locale(identifier: "en_US_POSIX"), port.longitude),
                    arrival: dateTimeFormatter.string(from: port.arrival),
                    departure: dateTimeFormatter.string(from: port.departure),
                    imageUrl: portImageURL(cruise, port, index),
                    excursions: port.excursions,
                    isSeaDay: port.isSeaDay
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
            let photoRefs = photoEncoder(cruise, sortedPhotos)

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
                rating: cruise.rating,
                route: exportPorts,
                photos: photoRefs,
                expenses: exportExpenses
            )
            result.append(exportCruise)
        }

        return result
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
        /// STORED-Eintrag (Methode 0), dessen compressedSize nicht mit uncompressedSize übereinstimmt,
        /// oder ein Verzeichnis-Eintrag mit einer von 0/0 abweichenden Größenangabe (H8).
        case sizeMismatch(name: String)
        /// Central Directory ist unvollständig/beschädigt: die EOCD behauptet mehr oder weniger
        /// Einträge, als tatsächlich im Central Directory enthalten sind, oder ein Eintrags-/Local-
        /// Header liegt außerhalb der Datei (H8).
        case truncatedArchive
        /// Der von einem Central-Directory-Eintrag referenzierte Local Header beginnt nicht mit der
        /// erwarteten ZIP-Signatur PK\x03\x04 (H8).
        case invalidLocalHeader(name: String)
        /// Der Dateiname im Local Header weicht vom Namen im Central-Directory-Eintrag ab (H8).
        case nameMismatch(central: String, local: String)
        /// Ein ZIP-Eintrag konnte nicht entpackt werden (nicht unterstützte Kompressionsmethode oder
        /// beschädigter Deflate-Stream).
        case decompressionFailed(name: String)
        /// Die entpackten Bytes eines Eintrags ergeben nicht die im Central-Directory-Eintrag
        /// deklarierte CRC-32-Prüfsumme — der Eintrag ist inhaltlich beschädigt (H8).
        case crcMismatch(name: String)

        var errorDescription: String? {
            switch self {
            case .noDataFile:
                return String(localized: "Keine data.json in der ZIP-Datei gefunden")
            case .invalidFormat:
                return String(localized: "Ungültiges Dateiformat")
            case .unsafePath(let path):
                return String(localized: "Unsicherer Pfad im Archiv abgelehnt: \(path)")
            case .entryTooLarge(let name, let size):
                return String(localized: "ZIP-Eintrag '\(name)' überschreitet das Größenlimit (\(size) Bytes; Maximum \(ZipArchiveReader.maxEntryUncompressedSize) Bytes)")
            case .archiveTooLarge(let size):
                return String(localized: "ZIP-Archiv überschreitet das kumulierte Größenlimit (\(size) Bytes; Maximum \(ZipArchiveReader.maxTotalUncompressedSize) Bytes)")
            case .sizeMismatch(let name):
                return String(localized: "ZIP-Eintrag '\(name)': compressedSize stimmt nicht mit uncompressedSize überein (Methode STORED erfordert Gleichheit)")
            case .truncatedArchive:
                return String(localized: "ZIP-Archiv ist beschädigt oder unvollständig (Central Directory)")
            case .invalidLocalHeader(let name):
                return String(localized: "ZIP-Eintrag '\(name)': ungültige Local-File-Header-Signatur")
            case .nameMismatch(let central, let local):
                return String(localized: "ZIP-Eintrag beschädigt: Name im Local-Header ('\(local)') weicht vom Central-Directory-Eintrag ('\(central)') ab")
            case .decompressionFailed(let name):
                return String(localized: "ZIP-Eintrag '\(name)' konnte nicht entpackt werden")
            case .crcMismatch(let name):
                return String(localized: "ZIP-Eintrag '\(name)': CRC-32-Prüfsumme stimmt nicht überein (Archiv beschädigt)")
            }
        }
    }
}
