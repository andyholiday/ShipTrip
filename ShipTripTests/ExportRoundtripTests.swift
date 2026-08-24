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
