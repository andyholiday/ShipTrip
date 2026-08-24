//
//  ExportRoundtripTests.swift
//  ShipTripTests
//
//  Roundtrip-Tests für den Backup-Export (1.8): Repro-Tests für die drei Datenverlust-Bugs
//  (halbe Sterne, Foto-Identität, Seetag-Nullung), die neuen Sammlungen (Deals, eigene
//  Reedereien/Schiffe, Ausblendungen) und die Rückwärtskompatibilität zu 1.7-Exporten.
//

import Testing
import Foundation
import SwiftData
@testable import ShipTrip

private typealias CruisePort = ShipTrip.Port

// MARK: - Fixture-Helfer

private func makeDate(_ string: String) -> Date {
    let df = DateFormatter()
    df.dateFormat = "yyyy-MM-dd"
    df.timeZone = TimeZone(identifier: "UTC")
    // Fixture-Literal im Test: das Format ist hier konstant und passt immer.
    return df.date(from: string)!
}

/// Container mit dem vollständigen Schema — inklusive der Katalog-Overlay-Modelle (ADR-006),
/// die der 1.8-Export mitschreibt.
private func makeFullContainer() throws -> ModelContainer {
    let schema = Schema([
        Cruise.self, CruisePort.self, Expense.self, Deal.self, Photo.self,
        CustomShippingLine.self, CustomShip.self, HiddenCatalogItem.self
    ])
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    return try ModelContainer(for: schema, configurations: config)
}

/// Minimales gültiges PNG (1×1 weißes Pixel). Der Import validiert Bilddaten inhaltlich via
/// ImageIO — beliebige Bytes würden verworfen.
private let onePixelPNG = Data(base64Encoded:
    "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8/5+hHgAHggJ/PchI6QAAAABJRU5ErkJggg=="
)!

private func makeCruise(title: String, in context: ModelContext) -> Cruise {
    let cruise = Cruise(
        title: title,
        startDate: makeDate("2026-05-01"),
        endDate: makeDate("2026-05-08"),
        shippingLine: "AIDA",
        ship: "AIDAnova"
    )
    context.insert(cruise)
    return cruise
}

// MARK: - Datenverlust-Repros

@Suite("Export-Roundtrip: Datenverlust-Repros")
struct ExportRoundtripDataLossTests {

    /// REPRO (rot vor dem Fix): `ExportCruise.rating` war `Int`, der Export trunkierte
    /// `Int(cruise.rating)` — aus 4,5 Sternen wurden 4.
    @Test("Halbe Sterne überleben den Roundtrip: 4,5 bleibt 4,5")
    @MainActor
    func halfStarRatingSurvivesRoundtrip() throws {
        let source = try makeFullContainer()
        let cruise = makeCruise(title: "Halbe Sterne", in: source.mainContext)
        cruise.rating = 4.5
        try source.mainContext.save()

        let url = try ExportImportService.shared.exportToJSON(cruises: [cruise])
        defer { try? FileManager.default.removeItem(at: url) }

        let target = try makeFullContainer()
        _ = try ExportImportService.shared.importFromJSON(url: url, modelContext: target.mainContext)

        let imported = try target.mainContext.fetch(FetchDescriptor<Cruise>())
        #expect(imported.count == 1)
        #expect(imported.first?.rating == 4.5)
    }

    /// REPRO (rot vor dem Fix): Fotos wurden als nackte Referenz-Strings exportiert, `Photo.id`
    /// ging verloren. Der Import vergab eine frische UUID — zwei Geräte, die dasselbe Backup
    /// einspielen, erzeugten damit unterschiedliche Identitäten (CloudKit-Dedup läuft über die
    /// stabile `id`, siehe ADR-002).
    @Test("Foto-Identität überlebt den Roundtrip: Photo.id bleibt stabil")
    @MainActor
    func photoIdentitySurvivesRoundtrip() throws {
        let source = try makeFullContainer()
        let cruise = makeCruise(title: "Foto-Identität", in: source.mainContext)
        let photo = Photo(imageData: onePixelPNG, sortOrder: 0)
        photo.cruise = cruise
        source.mainContext.insert(photo)
        try source.mainContext.save()

        let originalPhotoID = photo.id

        let url = try ExportImportService.shared.exportToJSON(cruises: [cruise])
        defer { try? FileManager.default.removeItem(at: url) }

        let target = try makeFullContainer()
        _ = try ExportImportService.shared.importFromJSON(url: url, modelContext: target.mainContext)

        let importedPhotos = try target.mainContext.fetch(FetchDescriptor<Photo>())
        #expect(importedPhotos.count == 1)
        #expect(importedPhotos.first?.id == originalPhotoID)
        #expect(importedPhotos.first?.imageData == onePixelPNG)
    }

    /// REPRO (rot vor dem Fix): der Export nullte für Seetage Land und Koordinaten
    /// (`port.isSeaDay ? nil : …`) — ein Seetag mit erfassten Koordinaten kam mit 0/0 zurück
    /// und riss die Routenlinie auf der Karte auf.
    @Test("Seetag behält Land und Koordinaten über den Roundtrip")
    @MainActor
    func seaDayKeepsCountryAndCoordinates() throws {
        let source = try makeFullContainer()
        let cruise = makeCruise(title: "Seetag-Koordinaten", in: source.mainContext)

        let seaDay = CruisePort(name: "Seetag", country: "Atlantik", latitude: 44.5, longitude: -6.25)
        seaDay.isSeaDay = true
        seaDay.cruise = cruise
        source.mainContext.insert(seaDay)
        try source.mainContext.save()

        let url = try ExportImportService.shared.exportToJSON(cruises: [cruise])
        defer { try? FileManager.default.removeItem(at: url) }

        let target = try makeFullContainer()
        _ = try ExportImportService.shared.importFromJSON(url: url, modelContext: target.mainContext)

        let importedPorts = try target.mainContext.fetch(FetchDescriptor<CruisePort>())
        #expect(importedPorts.count == 1)
        #expect(importedPorts.first?.isSeaDay == true)
        #expect(importedPorts.first?.country == "Atlantik")
        #expect(importedPorts.first?.latitude == 44.5)
        #expect(importedPorts.first?.longitude == -6.25)
    }
}

// MARK: - Wunschreisen & Katalog-Overlay

@Suite("Export-Roundtrip: Wunschreisen und Katalog-Overlay")
struct ExportRoundtripCatalogTests {

    @Test("Deals, eigene Reedereien/Schiffe und Ausblendungen überleben den ZIP-Roundtrip; Re-Import bleibt idempotent")
    @MainActor
    func catalogAndDealsSurviveZipRoundtrip() throws {
        let source = try makeFullContainer()
        let context = source.mainContext

        let cruise = makeCruise(title: "Mit Katalog-Daten", in: context)

        let deal = Deal(title: "Karibik 2027")
        deal.shippingLine = "MSC"
        deal.ship = "MSC World Europa"
        deal.destination = "Karibik"
        deal.price = 1299
        deal.originalPrice = 1799
        deal.startDate = makeDate("2027-01-10")
        deal.endDate = makeDate("2027-01-20")
        deal.url = "https://example.com/deal"
        deal.notes = "Balkon noch frei"
        context.insert(deal)

        let line = CustomShippingLine(name: "Andrés Reederei", logo: "⚓️")
        context.insert(line)
        let ship = CustomShip(name: "Andrés Schiff", lineOptionID: "custom:\(line.id.uuidString)")
        context.insert(ship)
        let hiddenLine = HiddenCatalogItem(lineID: "aida")
        context.insert(hiddenLine)
        let hiddenShip = HiddenCatalogItem(
            lineID: "tui", shipKey: ShippingLine.normalizedShipKey("Mein Schiff 1")
        )
        context.insert(hiddenShip)
        try context.save()

        let url = try ExportImportService.shared.exportToZip(
            cruises: [cruise],
            deals: [deal],
            customLines: [line],
            customShips: [ship],
            hiddenCatalogItems: [hiddenLine, hiddenShip]
        )
        defer { try? FileManager.default.removeItem(at: url) }

        let target = try makeFullContainer()
        _ = try ExportImportService.shared.importFromZip(url: url, modelContext: target.mainContext)

        let importedDeals = try target.mainContext.fetch(FetchDescriptor<Deal>())
        #expect(importedDeals.count == 1)
        let importedDeal = try #require(importedDeals.first)
        #expect(importedDeal.id == deal.id)
        #expect(importedDeal.price == 1299)
        #expect(importedDeal.originalPrice == 1799)
        #expect(importedDeal.ship == "MSC World Europa")
        #expect(importedDeal.destination == "Karibik")
        #expect(importedDeal.url == "https://example.com/deal")
        #expect(importedDeal.startDate.map {
            Calendar.current.isDate($0, inSameDayAs: makeDate("2027-01-10"))
        } == true)

        let importedLines = try target.mainContext.fetch(FetchDescriptor<CustomShippingLine>())
        #expect(importedLines.count == 1)
        let importedLine = try #require(importedLines.first)
        // Die UUID muss stabil bleiben, sonst zeigt lineOptionID ins Leere.
        #expect(importedLine.id == line.id)
        #expect(importedLine.name == "Andrés Reederei")
        #expect(importedLine.logo == "⚓️")

        let importedShips = try target.mainContext.fetch(FetchDescriptor<CustomShip>())
        #expect(importedShips.count == 1)
        let importedShip = try #require(importedShips.first)
        #expect(importedShip.id == ship.id)
        // Das Schiff hängt nach dem Import an genau der importierten Reederei — kein Waisenkind.
        #expect(importedShip.lineOptionID == "custom:\(importedLine.id.uuidString)")

        let importedHidden = try target.mainContext.fetch(FetchDescriptor<HiddenCatalogItem>())
        #expect(importedHidden.count == 2)
        #expect(importedHidden.contains { $0.lineID == "aida" && $0.shipKey == nil })
        #expect(importedHidden.contains { $0.lineID == "tui" && $0.shipKey != nil })

        // Re-Import derselben Datei: keine Dubletten.
        _ = try ExportImportService.shared.importFromZip(url: url, modelContext: target.mainContext)
        #expect(try target.mainContext.fetch(FetchDescriptor<Deal>()).count == 1)
        #expect(try target.mainContext.fetch(FetchDescriptor<CustomShippingLine>()).count == 1)
        #expect(try target.mainContext.fetch(FetchDescriptor<CustomShip>()).count == 1)
        #expect(try target.mainContext.fetch(FetchDescriptor<HiddenCatalogItem>()).count == 2)
    }

    @Test("Eigenes Schiff ohne auflösbare eigene Reederei wird nicht importiert (keine Waisen)")
    @MainActor
    func orphanedCustomShipIsSkipped() throws {
        let orphan = ExportCustomShip(
            id: UUID().uuidString,
            name: "Waisenschiff",
            lineOptionID: "custom:\(UUID().uuidString)",
            createdAt: nil,
            updatedAt: nil
        )
        // Katalog-Reedereien sind hartkodiert und damit immer auflösbar.
        let catalogShip = ExportCustomShip(
            id: UUID().uuidString,
            name: "Eigene AIDA-Yacht",
            lineOptionID: "aida",
            createdAt: nil,
            updatedAt: nil
        )

        let archive = ExportArchive(customShips: [orphan, catalogShip])
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("orphan-\(UUID().uuidString).json")
        try JSONEncoder().encode(archive).write(to: url)
        defer { try? FileManager.default.removeItem(at: url) }

        let target = try makeFullContainer()
        _ = try ExportImportService.shared.importFromJSON(url: url, modelContext: target.mainContext)

        let ships = try target.mainContext.fetch(FetchDescriptor<CustomShip>())
        #expect(ships.count == 1)
        #expect(ships.first?.name == "Eigene AIDA-Yacht")
    }

    @Test("Demo-Kreuzfahrten UND Demo-Wunschreisen werden nicht exportiert")
    @MainActor
    func demoDataIsExcludedFromExport() throws {
        let source = try makeFullContainer()
        let context = source.mainContext

        let realCruise = makeCruise(title: "Echte Reise", in: context)
        let demoCruise = makeCruise(title: "Demo-Reise", in: context)
        demoCruise.isDemo = true

        let realDeal = Deal(title: "Echtes Angebot")
        context.insert(realDeal)
        let demoDeal = Deal(title: "Demo-Angebot")
        demoDeal.isDemo = true
        context.insert(demoDeal)
        try context.save()

        let url = try ExportImportService.shared.exportToZip(
            cruises: [realCruise, demoCruise],
            deals: [realDeal, demoDeal]
        )
        defer { try? FileManager.default.removeItem(at: url) }

        let target = try makeFullContainer()
        let result = try ExportImportService.shared.importFromZip(
            url: url, modelContext: target.mainContext
        )

        #expect(result.imported == 1)
        let cruises = try target.mainContext.fetch(FetchDescriptor<Cruise>())
        #expect(cruises.map(\.title) == ["Echte Reise"])
        let deals = try target.mainContext.fetch(FetchDescriptor<Deal>())
        #expect(deals.map(\.title) == ["Echtes Angebot"])
    }
}
