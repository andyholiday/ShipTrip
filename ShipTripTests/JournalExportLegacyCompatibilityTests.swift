//
//  JournalExportLegacyCompatibilityTests.swift
//  ShipTripTests
//
//  Contract-Fixture (a) aus ADR-003 → „Export- und Teilen-Integration": Dateien aus 1.8.0
//  kennen weder `journalEntries` noch `caption`. Beide Türen — ZIP-Backup und
//  `.shiptrip`-Teilen — müssen sie fehlerfrei importieren: leeres Journal, `caption == ""`.
//

import Testing
import Foundation
import SwiftData
@testable import ShipTrip

/// Minimales gültiges PNG (1×1 weißes Pixel) — der Import validiert Bilddaten über ImageIO.
let journalFixturePNGBase64 =
    "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8/5+hHgAHggJ/PchI6QAAAABJRU5ErkJggg=="

// Fixture-Literal im Test: die Konstante ist gültiges Base64.
let journalFixturePNG = Data(base64Encoded: journalFixturePNGBase64)!

let legacy180CruiseID = "3C1D2E3F-4A5B-4C6D-8E7F-0A1B2C3D4E5F"
let legacy180PhotoID = "9A8B7C6D-5E4F-4A3B-8C2D-1E0F9A8B7C6D"

/// **Herkunft:** Feldsatz und Schlüsselnamen sind der 1.8.0-Envelope (Release-Tag `92d19e1`),
/// erzeugt von `buildArchive`/`buildExportCruises` im damaligen Stand — also mit `formatVersion`
/// 2, Foto-Objekten mit stabiler `id`, aber **ohne** `journalEntries` und **ohne** `caption`.
/// `share` wird nur für die Teilen-Variante ergänzt.
private func legacy180JSON(photoReference: String, includeShareBlock: Bool) -> String {
    let share = includeShareBlock ? """
    ,
      "share" : {
        "appVersion" : "1.8.0",
        "contentFingerprint" : "0f1e2d3c4b5a69788796a5b4c3d2e1f00f1e2d3c4b5a69788796a5b4c3d2e1f0",
        "sharedAt" : "2026-08-25T12:00:00.000Z",
        "shareFormatVersion" : 1
      }
    """ : ""

    return """
    {
      "cruises" : [
        {
          "endDate" : "2025-06-10",
          "expenses" : [

          ],
          "id" : "\(legacy180CruiseID)",
          "photos" : [
            {
              "id" : "\(legacy180PhotoID)",
              "ref" : "\(photoReference)"
            }
          ],
          "rating" : 4.5,
          "route" : [
            {
              "arrival" : "2025-06-02T08:00:00",
              "country" : "Norwegen",
              "departure" : "2025-06-02T18:00:00",
              "excursions" : [

              ],
              "id" : "11111111-2222-4333-8444-555555555555",
              "isSeaDay" : false,
              "lat" : "60.39130000",
              "lng" : "5.32210000",
              "name" : "Bergen"
            }
          ],
          "ship" : "AIDAnova",
          "shippingLine" : "AIDA",
          "startDate" : "2025-06-01",
          "title" : "Nordland"
        }
      ],
      "customShippingLines" : [

      ],
      "customShips" : [

      ],
      "deals" : [

      ],
      "formatVersion" : 2,
      "hiddenCatalogItems" : [

      ]\(share)
    }
    """
}

@Suite("Journal-Export: 1.8.0-Dateien ohne Journal-Felder")
@MainActor
struct JournalExportLegacyCompatibilityTests {

    @Test("1.8.0-ZIP ohne journalEntries/caption importiert mit leerem Journal und caption \"\"")
    func legacy180ZipImportsWithEmptyJournal() throws {
        let photoEntryName = "images/\(legacy180CruiseID)/0"
        let zipData = try ZipArchiveWriter.build(entries: [
            ("data.json", Data(legacy180JSON(
                photoReference: photoEntryName, includeShareBlock: false
            ).utf8)),
            (photoEntryName, journalFixturePNG)
        ])
        let url = try writeRawFile(zipData, fileName: "backup-1.8.0.zip")
        defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }

        let container = try makeJournalContainer()
        let context = container.mainContext

        let result = try ExportImportService.shared.importFromZip(url: url, modelContext: context)
        #expect(result.imported == 1)
        #expect(result.skippedInvalid == 0)
        #expect(result.invalidMedia == 0)

        let cruise = try #require(try context.fetch(FetchDescriptor<Cruise>()).first)
        #expect(cruise.journalEntries.isEmpty)
        #expect(try context.fetch(FetchDescriptor<JournalEntry>()).isEmpty)

        let photo = try #require(cruise.photos.first)
        #expect(photo.caption == "")
        #expect(photo.id == UUID(uuidString: legacy180PhotoID))
        #expect(photo.journalEntry == nil)
        #expect(cruise.route.count == 1)
    }

    @Test("1.8.0-.shiptrip ohne journalEntries/caption importiert über den Share-Einstieg")
    func legacy180ShareFileImportsWithEmptyJournal() async throws {
        let photoEntryName = "images/\(legacy180CruiseID)/0"
        let url = try writeShareFile(
            dataJSON: Data(legacy180JSON(
                photoReference: photoEntryName, includeShareBlock: true
            ).utf8),
            extraEntries: [(name: photoEntryName, data: journalFixturePNG)],
            fileName: "nordland.shiptrip"
        )
        defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }

        let container = try makeJournalContainer()
        let context = ModelContext(container)

        let result = try await ExportImportService.shared.importSharedCruise(
            from: url, modelContext: context
        )
        #expect(result.base.imported == 1)
        #expect(result.base.invalidMedia == 0)
        #expect(result.versionConflict == false)

        let cruise = try #require(try context.fetch(FetchDescriptor<Cruise>()).first)
        #expect(cruise.journalEntries.isEmpty)
        #expect(cruise.photos.first?.caption == "")
        #expect(cruise.shareContentFingerprint?.isEmpty == false)
    }

    /// Gegenprobe zur Asymmetrie-Zusage: eine Reise ohne Journal und ohne Captions schreibt die
    /// neuen Schlüssel gar nicht erst — die Datei bleibt für 1.8.0-Leser exakt wie bisher.
    @Test("Reise ohne Journal/Captions schreibt weder journalEntries noch caption")
    func exportWithoutJournalOmitsNewKeys() throws {
        let container = try makeJournalContainer()
        let context = container.mainContext
        let cruise = makeJournalCruise(context)
        let photo = Photo(imageData: journalFixturePNG, sortOrder: 0)
        photo.cruise = cruise
        context.insert(photo)
        try context.save()

        let url = try ExportImportService.shared.exportToJSON(cruises: [cruise])
        defer { try? FileManager.default.removeItem(at: url) }
        let json = try String(contentsOf: url, encoding: .utf8)

        #expect(!json.contains("journalEntries"))
        #expect(!json.contains("caption"))
    }
}
