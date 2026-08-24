//
//  ExportLegacyCompatibilityTests.swift
//  ShipTripTests
//
//  Rückwärtskompatibilität: Backups aus Version 1.7 müssen mit dem 1.8-Importer lesbar
//  bleiben — als JSON-Datei wie als ZIP-Archiv.
//

import Testing
import Foundation
import SwiftData
@testable import ShipTrip

private typealias CruisePort = ShipTrip.Port

private func makeFullContainer() throws -> ModelContainer {
    let schema = Schema([
        Cruise.self, CruisePort.self, Expense.self, Deal.self, Photo.self,
        CustomShippingLine.self, CustomShip.self, HiddenCatalogItem.self
    ])
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    return try ModelContainer(for: schema, configurations: config)
}

/// Minimales gültiges PNG (1×1 weißes Pixel).
private let onePixelPNGBase64 =
    "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8/5+hHgAHggJ/PchI6QAAAABJRU5ErkJggg=="

// Fixture-Literal im Test: die Konstante ist gültiges Base64.
private let onePixelPNG = Data(base64Encoded: onePixelPNGBase64)!

private let legacyCruiseID = "6E8B1F52-2C4D-4C2F-9E3B-1A2B3C4D5E6F"

/// **Herkunft des Fixtures:** Feldsatz, Schlüsselnamen und Werteformate sind 1:1 aus dem
/// 1.7-Exporter übernommen (`ExportImportService.buildExportCruises` im Release-Stand 1.7.1,
/// Commit 751f6ce): Top-Level ein nacktes `[ExportCruise]`-Array ohne Envelope, `rating` als
/// Ganzzahl, `photos` als nackte String-Referenzen, Seetage ohne `country`/`lat`/`lng`, Datums-
/// formate `yyyy-MM-dd` bzw. `yyyy-MM-dd'T'HH:mm:ss` und ISO-8601 mit Millisekunden für
/// `createdAt`. Nil-Optionals fehlen als Schlüssel, weil Swifts Codable-Synthese sie auslässt.
/// Auch die Ausgaben-Kategorie ist original: 1.7 schrieb `expense.category.rawValue.lowercased()`,
/// und die rawValues von `ExpenseCategory` sind deutsch — im Backup steht deshalb `"ausflug"`,
/// nicht `"excursion"`.
/// Das Fixture wurde aus diesem Stand nachgebaut (in der Test-Lane steht kein 1.7-Binary zur
/// Verfügung); der ZIP-Container darum herum entsteht im ZIP-Test mit dem unveränderten
/// `ZipArchiveWriter`, der in 1.7 und 1.8 identisch ist.
private func legacy17JSON(photoReference: String) -> String {
    """
    [
      {
        "bookingNumber" : "AIDA-4711",
        "cabinNumber" : "8042",
        "cabinType" : "Balkonkabine",
        "endDate" : "2025-06-10",
        "expenses" : [
          {
            "amount" : 89.9,
            "category" : "ausflug",
            "createdAt" : "2025-06-03T10:15:00.000Z",
            "cruiseId" : "\(legacyCruiseID)",
            "description" : "Stadtrundfahrt Bergen",
            "expenseDate" : "2025-06-03",
            "id" : "BBBBBBBB-CCCC-4DDD-8EEE-FFFFFFFFFFFF"
          }
        ],
        "id" : "\(legacyCruiseID)",
        "notes" : "Erste Nordlandreise",
        "photos" : [
          "\(photoReference)"
        ],
        "rating" : 4,
        "route" : [
          {
            "arrival" : "2025-06-02T08:00:00",
            "country" : "Norwegen",
            "departure" : "2025-06-02T18:00:00",
            "excursions" : [
              "Fløibahn"
            ],
            "id" : "11111111-2222-4333-8444-555555555555",
            "isSeaDay" : false,
            "lat" : "60.39130000",
            "lng" : "5.32210000",
            "name" : "Bergen"
          },
          {
            "arrival" : "2025-06-03T00:00:00",
            "departure" : "2025-06-03T23:59:59",
            "excursions" : [

            ],
            "id" : "66666666-7777-4888-8999-AAAAAAAAAAAA",
            "isSeaDay" : true,
            "name" : "Seetag"
          }
        ],
        "ship" : "AIDAnova",
        "shippingLine" : "AIDA",
        "startDate" : "2025-06-01",
        "title" : "Nordland"
      }
    ]
    """
}

// MARK: - 1.7-JSON

@Suite("Rückwärtskompatibilität: 1.7-Backups")
struct ExportLegacyCompatibilityTests {

    @Test("1.7-JSON-Export (Top-Level-Array, Base64-Fotos, rating als Ganzzahl) bleibt importierbar")
    @MainActor
    func legacy17JSONStaysImportable() throws {
        let json = legacy17JSON(photoReference: "data:image/png;base64,\(onePixelPNGBase64)")
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("legacy17-\(UUID().uuidString).json")
        try Data(json.utf8).write(to: url)
        defer { try? FileManager.default.removeItem(at: url) }

        let container = try makeFullContainer()
        let context = container.mainContext

        let result = try ExportImportService.shared.importFromJSON(url: url, modelContext: context)
        #expect(result.imported == 1)
        #expect(result.skippedInvalid == 0)
        #expect(result.invalidMedia == 0)

        let cruise = try #require(try context.fetch(FetchDescriptor<Cruise>()).first)
        #expect(cruise.id == UUID(uuidString: legacyCruiseID))
        #expect(cruise.title == "Nordland")
        #expect(cruise.rating == 4)
        #expect(cruise.cabinNumber == "8042")

        let ports = try context.fetch(FetchDescriptor<CruisePort>()).sorted { $0.sortOrder < $1.sortOrder }
        #expect(ports.count == 2)
        #expect(ports.first?.name == "Bergen")
        #expect(ports.first?.latitude == 60.3913)
        #expect(ports.first?.excursions == ["Fløibahn"])
        #expect(ports.last?.isSeaDay == true)

        let expenses = try context.fetch(FetchDescriptor<Expense>())
        #expect(expenses.count == 1)
        #expect(expenses.first?.amount == 89.9)
        // Ist-Verhalten festgeschrieben: der deutsche 1.7-rawValue "ausflug" wird von
        // `mapCategory` auf `.excursion` abgebildet — die Kategorie überlebt das Alt-Format.
        #expect(expenses.first?.category == .excursion)

        // Legacy-Foto-Referenz ohne Photo.id: importierbar, id wird frisch vergeben.
        let photos = try context.fetch(FetchDescriptor<Photo>())
        #expect(photos.count == 1)
        #expect(photos.first?.imageData == onePixelPNG)

        // Re-Export schreibt das 1.8-Format inklusive Foto-Identität.
        let reExportURL = try ExportImportService.shared.exportToJSON(cruises: [cruise])
        defer { try? FileManager.default.removeItem(at: reExportURL) }
        let reExported = try ExportArchive.decode(from: Data(contentsOf: reExportURL))
        #expect(reExported.formatVersion == ExportArchive.currentFormatVersion)
        #expect(reExported.cruises.first?.photos.first?.id == photos.first?.id.uuidString)
    }

    @Test("1.7-ZIP-Export (data.json im Alt-Format + images/<cruiseId>/<index>) bleibt importierbar")
    @MainActor
    func legacy17ZipStaysImportable() throws {
        let photoEntryName = "images/\(legacyCruiseID)/0"
        let json = legacy17JSON(photoReference: photoEntryName)
        let zipData = try ZipArchiveWriter.build(entries: [
            ("data.json", Data(json.utf8)),
            (photoEntryName, onePixelPNG)
        ])

        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("legacy17-\(UUID().uuidString).zip")
        try zipData.write(to: url)
        defer { try? FileManager.default.removeItem(at: url) }

        let container = try makeFullContainer()
        let context = container.mainContext

        let result = try ExportImportService.shared.importFromZip(url: url, modelContext: context)
        #expect(result.imported == 1)
        #expect(result.invalidMedia == 0)

        let cruise = try #require(try context.fetch(FetchDescriptor<Cruise>()).first)
        #expect(cruise.rating == 4)
        #expect(try context.fetch(FetchDescriptor<CruisePort>()).count == 2)

        let photos = try context.fetch(FetchDescriptor<Photo>())
        #expect(photos.count == 1)
        #expect(photos.first?.imageData == onePixelPNG)
        #expect(photos.first?.thumbnailData != nil)
    }

    /// Grenzfall der Kompat-Matrix: ein 1.7-Backup einer leeren Datenbank ist ein nacktes `[]`.
    /// Das muss als „nichts importiert" durchlaufen — kein Fehler, keine Objekte.
    @Test("Leeres 1.7-Top-Level-Array importiert fehlerfrei als „nichts“")
    @MainActor
    func emptyLegacyArrayImportsAsNothing() throws {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("legacy17-empty-\(UUID().uuidString).json")
        try Data("[]".utf8).write(to: url)
        defer { try? FileManager.default.removeItem(at: url) }

        let container = try makeFullContainer()
        let context = container.mainContext

        let result = try ExportImportService.shared.importFromJSON(url: url, modelContext: context)
        #expect(result.imported == 0)
        #expect(result.skippedDuplicates == 0)
        #expect(result.skippedInvalid == 0)
        #expect(result.invalidMedia == 0)
        #expect(try context.fetch(FetchDescriptor<Cruise>()).isEmpty)
        #expect(try context.fetch(FetchDescriptor<Deal>()).isEmpty)
    }
}
