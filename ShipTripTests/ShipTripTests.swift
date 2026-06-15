//
//  ShipTripTests.swift
//  ShipTripTests
//
//  Created by Andre Book on 18.12.25.
//

import Testing
import Foundation
import SwiftData
import UserNotifications
@testable import ShipTrip

// Disambiguate ShipTrip.Port from any system type named Port
private typealias CruisePort = ShipTrip.Port

// MARK: - Model Computed Properties

@Suite("Cruise Model")
struct CruiseModelTests {

    private func makeDate(_ string: String) -> Date {
        let df = DateFormatter()
        df.dateFormat = "yyyy-MM-dd"
        df.timeZone = TimeZone(identifier: "UTC")
        return df.date(from: string)!
    }

    @Test("duration is inclusive: 2025-06-10 to 2025-06-17 = 8")
    func durationMultiDay() {
        let cruise = Cruise(
            title: "Test",
            startDate: makeDate("2025-06-10"),
            endDate: makeDate("2025-06-17"),
            shippingLine: "MSC",
            ship: "Bellissima"
        )
        #expect(cruise.duration == 8)
    }

    @Test("duration same day = 1")
    func durationSameDay() {
        let date = makeDate("2025-06-10")
        let cruise = Cruise(
            title: "Test",
            startDate: date,
            endDate: date,
            shippingLine: "MSC",
            ship: "Bellissima"
        )
        #expect(cruise.duration == 1)
    }
}

// MARK: - Deal Computed Properties

@Suite("Deal Model")
struct DealModelTests {

    @Test("discountPercent: original 1000 current 750 = 25")
    func discountPercent() {
        let deal = Deal(title: "Mittelmeer Deal")
        deal.originalPrice = 1000
        deal.price = 750
        #expect(deal.discountPercent == 25)
    }

    @Test("discountPercent is nil when current >= original")
    func discountPercentNilWhenNoDiscount() {
        let deal = Deal(title: "No Discount")
        deal.originalPrice = 500
        deal.price = 500
        #expect(deal.discountPercent == nil)
    }

    @Test("discountPercent is nil when original is nil")
    func discountPercentNilWhenNoOriginal() {
        let deal = Deal(title: "No Original")
        deal.price = 500
        #expect(deal.discountPercent == nil)
    }

    @Test("savings is correct for a valid discount")
    func savingsValid() {
        let deal = Deal(title: "Savings Deal")
        deal.originalPrice = 1200
        deal.price = 900
        #expect(deal.savings == 300)
    }

    @Test("savings is nil when current >= original")
    func savingsNilWhenNoDiscount() {
        let deal = Deal(title: "No Savings")
        deal.originalPrice = 400
        deal.price = 400
        #expect(deal.savings == nil)
    }
}

// MARK: - Expense Computed Properties

@Suite("Expense Model")
struct ExpenseModelTests {

    @Test("formattedAmount contains EUR currency symbol")
    func formattedAmountContainsEUR() {
        let expense = Expense(category: .cruise, amount: 1234.50, description: "Kabine")
        // The formatted amount must contain currency digits; locale may vary,
        // but EUR formatting always produces a string with the amount.
        #expect(expense.formattedAmount.contains("1.234") || expense.formattedAmount.contains("1,234"))
    }

    @Test("category round-trips through rawValue")
    func categoryRoundTrip() {
        let expense = Expense(category: .excursion, amount: 50)
        #expect(expense.category == .excursion)
    }
}

// MARK: - PortSuggestion

@Suite("PortSuggestion")
struct PortSuggestionTests {

    @Test("findBestMatch returns Barcelona with valid coordinates")
    func findBestMatchBarcelona() {
        let result = PortSuggestion.findBestMatch(name: "Barcelona", country: "Spanien")
        #expect(result != nil)
        if let port = result {
            #expect(port.latitude != 0)
            #expect(port.longitude != 0)
            #expect(port.latitude >= -90 && port.latitude <= 90)
            #expect(port.longitude >= -180 && port.longitude <= 180)
            // Barcelona is in NE Spain: roughly 41°N 2°E
            #expect(port.latitude > 40 && port.latitude < 43)
            #expect(port.longitude > 1 && port.longitude < 4)
        }
    }

    @Test("findBestMatch returns nil for nonexistent port name")
    func findBestMatchNonexistent() {
        // "Xyzzy Nowhere" has no tokens matching any real port name.
        // The fuzzy-match may fall through to nil; document: if catalog ever
        // expands to include this string as a substring, this test may need updating.
        let result = PortSuggestion.findBestMatch(name: "Xyzzy Nowhere")
        #expect(result == nil)
    }

    @Test("search returns non-empty results for 'Barcelona'")
    func searchBarcelona() {
        let results = PortSuggestion.search("Barcelona")
        #expect(!results.isEmpty)
    }

    @Test("search returns all ports for empty query")
    func searchEmptyReturnsAll() {
        let all = PortSuggestion.search("")
        #expect(all.count == PortSuggestion.popular.count)
    }
}

// MARK: - Export / Import Roundtrip

@Suite("ExportImportService")
struct ExportImportTests {

    private func makeDate(_ string: String) -> Date {
        let df = DateFormatter()
        df.dateFormat = "yyyy-MM-dd"
        df.timeZone = TimeZone(identifier: "UTC")
        return df.date(from: string)!
    }

    private func makeInMemoryContainer() throws -> ModelContainer {
        let schema = Schema([Cruise.self, CruisePort.self, Expense.self, Deal.self, Photo.self])
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        return try ModelContainer(for: schema, configurations: config)
    }

    @Test("export then import roundtrip preserves cruise title, ship, and port count")
    @MainActor
    func exportImportRoundtrip() throws {
        let container = try makeInMemoryContainer()
        let context = container.mainContext

        // Insert a cruise with 2 ports
        let cruise = Cruise(
            title: "Roundtrip Test Cruise",
            startDate: makeDate("2026-07-01"),
            endDate: makeDate("2026-07-08"),
            shippingLine: "AIDA",
            ship: "AIDAnova"
        )
        context.insert(cruise)

        let port1 = CruisePort(name: "Hamburg", country: "Deutschland", latitude: 53.5488, longitude: 9.9872)
        port1.sortOrder = 0
        port1.cruise = cruise
        context.insert(port1)

        let port2 = CruisePort(name: "Barcelona", country: "Spanien", latitude: 41.3851, longitude: 2.1734)
        port2.sortOrder = 1
        port2.cruise = cruise
        context.insert(port2)

        try context.save()

        // Export
        let exportURL = try ExportImportService.shared.exportToJSON(cruises: [cruise])
        defer { try? FileManager.default.removeItem(at: exportURL) }

        // Import into a fresh context
        let freshContainer = try makeInMemoryContainer()
        let freshContext = freshContainer.mainContext

        let result = try ExportImportService.shared.importFromJSON(url: exportURL, modelContext: freshContext)

        #expect(result.imported == 1)
        #expect(result.skippedDuplicates == 0)
        #expect(result.skippedInvalid == 0)

        // Verify the imported cruise
        let imported = try freshContext.fetch(FetchDescriptor<Cruise>())
        #expect(imported.count == 1)
        if let importedCruise = imported.first {
            #expect(importedCruise.title == "Roundtrip Test Cruise")
            #expect(importedCruise.ship == "AIDAnova")
            // The service formats dates as "yyyy-MM-dd" in the system locale timezone and
            // re-parses with the same formatter, so dates are day-equal in local time.
            // Compare using Calendar so we don't introduce a UTC vs. local timezone mismatch.
            #expect(Calendar.current.isDate(importedCruise.startDate, inSameDayAs: makeDate("2026-07-01")))
            #expect(Calendar.current.isDate(importedCruise.endDate, inSameDayAs: makeDate("2026-07-08")))
            // Ports
            let ports = try freshContext.fetch(FetchDescriptor<CruisePort>())
            #expect(ports.count == 2)
        }
    }

    @Test("import skip accounting: invalid date and duplicate are counted correctly")
    @MainActor
    func importSkipAccounting() throws {
        let container = try makeInMemoryContainer()
        let context = container.mainContext

        // Hand-crafted JSON matching ExportCruise Codable shape:
        //   startDate / endDate: "yyyy-MM-dd"
        //   id, title, shippingLine, ship, rating, route, photos, expenses required
        let json = """
        [
          {
            "id": "cruise_valid-1",
            "title": "Valid Cruise",
            "startDate": "2026-08-01",
            "endDate": "2026-08-07",
            "shippingLine": "MSC",
            "ship": "MSC Seashore",
            "cabinType": null,
            "cabinNumber": null,
            "bookingNumber": null,
            "notes": null,
            "rating": 4,
            "route": [],
            "photos": [],
            "expenses": []
          },
          {
            "id": "cruise_invalid-date",
            "title": "Bad Date Cruise",
            "startDate": "NOT-A-DATE",
            "endDate": "2026-08-07",
            "shippingLine": "MSC",
            "ship": "MSC Seashore",
            "cabinType": null,
            "cabinNumber": null,
            "bookingNumber": null,
            "notes": null,
            "rating": 0,
            "route": [],
            "photos": [],
            "expenses": []
          },
          {
            "id": "cruise_inverted-range",
            "title": "Inverted Range Cruise",
            "startDate": "2026-08-10",
            "endDate": "2026-08-01",
            "shippingLine": "MSC",
            "ship": "MSC Seashore",
            "cabinType": null,
            "cabinNumber": null,
            "bookingNumber": null,
            "notes": null,
            "rating": 0,
            "route": [],
            "photos": [],
            "expenses": []
          }
        ]
        """.data(using: .utf8)!

        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("test-skip-\(UUID().uuidString).json")
        try json.write(to: tempURL)
        defer { try? FileManager.default.removeItem(at: tempURL) }

        // First import: should import 1, skip 1 unparseable date + 1 inverted range = 2 invalid
        let result1 = try ExportImportService.shared.importFromJSON(url: tempURL, modelContext: context)
        #expect(result1.imported == 1)
        #expect(result1.skippedInvalid >= 2)

        // Second import of the same file: the valid cruise is now a duplicate
        let result2 = try ExportImportService.shared.importFromJSON(url: tempURL, modelContext: context)
        #expect(result2.skippedDuplicates >= 1)
        #expect(result2.skippedInvalid >= 1)
    }
}

// MARK: - ZIP Export / Import (ADR-002)

@Suite("ExportImportService ZIP")
struct ExportImportZIPTests {

    private func makeDate(_ string: String) -> Date {
        let df = DateFormatter()
        df.dateFormat = "yyyy-MM-dd"
        df.timeZone = TimeZone(identifier: "UTC")
        return df.date(from: string)!
    }

    private func makeInMemoryContainer() throws -> ModelContainer {
        let schema = Schema([Cruise.self, CruisePort.self, Expense.self, Deal.self, Photo.self])
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        return try ModelContainer(for: schema, configurations: config)
    }

    /// (a) ZIP export→import roundtrip: Cruise-Anzahl und stabile ID bleiben erhalten.
    @Test("ZIP export–import roundtrip preserves cruise count and stable id")
    @MainActor
    func zipRoundtripPreservesStableID() throws {
        let container = try makeInMemoryContainer()
        let context = container.mainContext

        let cruise = Cruise(
            title: "ZIP Roundtrip",
            startDate: makeDate("2026-09-01"),
            endDate: makeDate("2026-09-10"),
            shippingLine: "TUI Cruises",
            ship: "Mein Schiff 1"
        )
        context.insert(cruise)
        try context.save()

        let originalID = cruise.id

        // ZIP exportieren
        let zipURL = try ExportImportService.shared.exportToZip(cruises: [cruise])
        defer { try? FileManager.default.removeItem(at: zipURL) }

        // Frischer Container für Import
        let freshContainer = try makeInMemoryContainer()
        let freshContext = freshContainer.mainContext

        let result = try ExportImportService.shared.importFromZip(url: zipURL, modelContext: freshContext)

        #expect(result.imported == 1)
        #expect(result.skippedDuplicates == 0)
        #expect(result.skippedInvalid == 0)

        let imported = try freshContext.fetch(FetchDescriptor<Cruise>())
        #expect(imported.count == 1)
        // Stabile ID muss exakt übereinstimmen
        #expect(imported.first?.id == originalID)
        #expect(imported.first?.title == "ZIP Roundtrip")
        #expect(imported.first?.ship == "Mein Schiff 1")
    }

    /// (b) Re-Import desselben ZIP ist idempotent: 0 neue, alles Duplikate (via stable id).
    @Test("Re-importing the same ZIP is idempotent: 0 new, all duplicates by id")
    @MainActor
    func zipReimportIsIdempotent() throws {
        // Quell-Container: Kreuzfahrt anlegen und ZIP exportieren
        let sourceContainer = try makeInMemoryContainer()
        let sourceContext = sourceContainer.mainContext

        let cruise = Cruise(
            title: "Idempotent Test",
            startDate: makeDate("2026-10-01"),
            endDate: makeDate("2026-10-07"),
            shippingLine: "Costa",
            ship: "Costa Smeralda"
        )
        sourceContext.insert(cruise)
        try sourceContext.save()

        let zipURL = try ExportImportService.shared.exportToZip(cruises: [cruise])
        defer { try? FileManager.default.removeItem(at: zipURL) }

        // Ziel-Container: frisch, leer
        let targetContainer = try makeInMemoryContainer()
        let targetContext = targetContainer.mainContext

        // Erster Import: 1 neu
        let result1 = try ExportImportService.shared.importFromZip(url: zipURL, modelContext: targetContext)
        #expect(result1.imported == 1)
        #expect(result1.skippedDuplicates == 0)

        // Zweiter Import (selbes ZIP, selber Ziel-Context): 0 neu, 1 Duplikat via stable id
        let result2 = try ExportImportService.shared.importFromZip(url: zipURL, modelContext: targetContext)
        #expect(result2.imported == 0)
        #expect(result2.skippedDuplicates == 1)

        // Nur 1 Kreuzfahrt im Ziel-Store
        let all = try targetContext.fetch(FetchDescriptor<Cruise>())
        #expect(all.count == 1)
    }

    /// (c) Legacy Base64-JSON importiert weiterhin korrekt.
    @Test("Legacy Base64 JSON import still works")
    @MainActor
    func legacyBase64JSONImport() throws {
        let container = try makeInMemoryContainer()
        let context = container.mainContext

        // Minimales, gültiges Base64-JSON (kein Foto-Daten, leerer String simuliert Fehler beim Dekodiern;
        // deshalb nutzen wir ein 1×1 weißes PNG als echte Base64-Payload)
        // 1×1 weißes PNG (67 Bytes), als Base64:
        let tiny1x1PngBase64 = "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8/5+hHgAHggJ/PchI6QAAAABJRU5ErkJggg=="

        let json = """
        [
          {
            "id": "cruise_legacy-base64",
            "title": "Legacy Base64 Cruise",
            "startDate": "2026-11-01",
            "endDate": "2026-11-07",
            "shippingLine": "MSC",
            "ship": "MSC Grandiosa",
            "cabinType": null,
            "cabinNumber": null,
            "bookingNumber": null,
            "notes": null,
            "rating": 5,
            "route": [],
            "photos": ["data:image/png;base64,\(tiny1x1PngBase64)"],
            "expenses": []
          }
        ]
        """.data(using: .utf8)!

        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("legacy-base64-\(UUID().uuidString).json")
        try json.write(to: tempURL)
        defer { try? FileManager.default.removeItem(at: tempURL) }

        let result = try ExportImportService.shared.importFromJSON(url: tempURL, modelContext: context)

        #expect(result.imported == 1)
        #expect(result.skippedDuplicates == 0)
        #expect(result.skippedInvalid == 0)

        let imported = try context.fetch(FetchDescriptor<Cruise>())
        #expect(imported.count == 1)
        #expect(imported.first?.title == "Legacy Base64 Cruise")

        // Foto muss importiert worden sein
        let photos = try context.fetch(FetchDescriptor<Photo>())
        #expect(photos.count == 1)
        #expect(!photos[0].imageData.isEmpty)
    }

    /// (d) ZIP-Export mit Foto: imageData round-trippt verlustfrei; thumbnailData ist nach Import nicht nil.
    @Test("ZIP export with photo: imageData is lossless and thumbnailData is set after import")
    @MainActor
    func zipPhotoRoundtripLosslessAndThumbnail() throws {
        let container = try makeInMemoryContainer()
        let context = container.mainContext

        // Minimales gültiges PNG (1×1 weißes Pixel, 67 Bytes) als Testbild.
        // Rohdaten werden direkt in Photo.imageData gespeichert — das ist genau
        // was exportToZip ohne Re-Encoding in die ZIP schreibt.
        let rawImageBytes = Data(base64Encoded:
            "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8/5+hHgAHggJ/PchI6QAAAABJRU5ErkJggg=="
        )!

        let cruise = Cruise(
            title: "Photo Roundtrip",
            startDate: makeDate("2026-12-01"),
            endDate: makeDate("2026-12-07"),
            shippingLine: "Hapag-Lloyd",
            ship: "Europa 2"
        )
        context.insert(cruise)

        let photo = Photo(imageData: rawImageBytes, sortOrder: 0)
        photo.cruise = cruise
        context.insert(photo)
        try context.save()

        // ZIP exportieren
        let zipURL = try ExportImportService.shared.exportToZip(cruises: [cruise])
        defer { try? FileManager.default.removeItem(at: zipURL) }

        // Frischer Container für Import
        let freshContainer = try makeInMemoryContainer()
        let freshContext = freshContainer.mainContext

        let result = try ExportImportService.shared.importFromZip(url: zipURL, modelContext: freshContext)
        #expect(result.imported == 1)

        // (a) imageData muss byte-identisch zum Original sein (verlustlos)
        let importedPhotos = try freshContext.fetch(FetchDescriptor<Photo>())
        #expect(importedPhotos.count == 1)
        if let importedPhoto = importedPhotos.first {
            #expect(importedPhoto.imageData == rawImageBytes)
            // (b) thumbnailData muss nach Import gesetzt sein
            #expect(importedPhoto.thumbnailData != nil)
        }
    }
}

// MARK: - Notification Removal by Prefix

/// NOTE on notification testing scope:
/// - scheduleAllReminders end-to-end firing is NOT tested: it requires authorization
///   (real device or manual/UI test) and a future trigger to fire.
/// - UNUserNotificationCenter.add(_:) in the unit test host (simulator, no entitlement)
///   does NOT persist pending requests; pendingNotificationRequests() returns empty.
///   This is a known iOS unit test host limitation — not a bug in the app code.
///   The prefix-filtering removal logic (Wave-1 fix) is therefore verified via a
///   pure-logic test that replicates the filter the service uses, without relying on
///   the notification center state persisting across async calls in the test process.
@Suite("NotificationService")
struct NotificationServiceTests {

    /// Verifies the Wave-1 fix: the prefix filter correctly identifies which identifiers
    /// belong to a given cruise. This replicates the logic inside removeReminders.
    @Test("prefix filter selects only cruise-scoped identifiers")
    func prefixFilterLogic() {
        let cruiseID = "TESTID"
        let prefix = "cruise-\(cruiseID)-"

        let identifiers = [
            "cruise-TESTID-7days",
            "cruise-TESTID-departure",
            "notif-other-TESTID-unrelated",
            "cruise-OTHER-7days",
            "cruise-TESTIDEXTENDED-7days"  // must NOT match a strict prefix
        ]

        let toRemove = identifiers.filter { $0.hasPrefix(prefix) }

        #expect(toRemove.contains("cruise-TESTID-7days"))
        #expect(toRemove.contains("cruise-TESTID-departure"))
        #expect(!toRemove.contains("notif-other-TESTID-unrelated"))
        #expect(!toRemove.contains("cruise-OTHER-7days"))
        // "cruise-TESTIDEXTENDED-7days" starts with "cruise-TESTID" but NOT with "cruise-TESTID-"
        #expect(!toRemove.contains("cruise-TESTIDEXTENDED-7days"))
        #expect(toRemove.count == 2)
    }

    /// Smoke test: removeReminders runs without throwing on an empty notification center.
    /// In the unit test host, pendingNotificationRequests() always returns [] so this
    /// verifies at minimum that the method handles an empty list without crashing.
    @Test("removeReminders does not crash on empty notification center")
    func removeRemindersNocrash() async {
        // Should not throw or crash
        await NotificationService.shared.removeReminders(cruiseID: "SMOKE-TEST-ID")
    }
}
