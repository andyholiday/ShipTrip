//
//  DemoDataServiceTests.swift
//  ShipTripTests
//
//  Verifiziert, dass DemoDataService keine künstlichen Fotos einhängt.
//  Ohne ausgewähltes Foto soll die UI die schiffsspezifischen Cover-Assets nutzen.
//

#if DEBUG
import Testing
import SwiftData
import Foundation
@testable import ShipTrip

// Disambiguate ShipTrip.Port from any system Port
private typealias CruisePort = ShipTrip.Port

@Suite("DemoDataService")
struct DemoDataServiceTests {

    private func makeInMemoryContainer() throws -> ModelContainer {
        let schema = Schema([Cruise.self, CruisePort.self, Expense.self, Deal.self, Photo.self])
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        return try ModelContainer(for: schema, configurations: config)
    }

    // MARK: - Basis-Seeding

    @Test("loadDemoData seeds exactly three cruises")
    @MainActor
    func loadsSeedCruiseCount() throws {
        let container = try makeInMemoryContainer()
        let context = container.mainContext

        DemoDataService.loadDemoData(into: context)

        let cruises = try context.fetch(FetchDescriptor<Cruise>())
        #expect(cruises.count == 3)
    }

    @Test("Norwegische Fjorde cruise uses ship cover fallback without seeded photo")
    @MainActor
    func norwegenCruiseUsesShipCoverFallback() throws {
        let container = try makeInMemoryContainer()
        let context = container.mainContext

        DemoDataService.loadDemoData(into: context)

        let cruises = try context.fetch(FetchDescriptor<Cruise>())
        let norwegen = cruises.first { $0.title == "Norwegische Fjorde" }
        #expect(norwegen != nil, "Norwegen-Kreuzfahrt muss vorhanden sein")

        guard let cruise = norwegen else { return }

        #expect(cruise.sortedPhotos.isEmpty, "Demo-Reisen ohne ausgewähltes Foto sollen kein künstliches Photo speichern")
        #expect(ShippingLine.coverAssetCandidates(
            shippingLine: cruise.shippingLine,
            ship: cruise.ship
        ).first == "cover_ship_aidanova")
    }

    @Test("Demo data does not seed cruise photos")
    @MainActor
    func doesNotSeedCruisePhotos() throws {
        let container = try makeInMemoryContainer()
        let context = container.mainContext

        DemoDataService.loadDemoData(into: context)

        let photos = try context.fetch(FetchDescriptor<Photo>())
        #expect(photos.isEmpty)
    }

    @Test("Demo data seeds curated port moments for release screenshots")
    @MainActor
    func seedsCuratedPortMoments() throws {
        let container = try makeInMemoryContainer()
        let context = container.mainContext

        DemoDataService.loadDemoData(into: context)

        let ports = try context.fetch(FetchDescriptor<CruisePort>())
        let barcelona = ports.first { $0.name == "Barcelona" }

        #expect(barcelona?.excursions == ["Altstadt-Spaziergang", "Gaudí-Tour"])
        #expect(barcelona?.imageData?.isEmpty == false)
    }

    @Test("loadDemoData removes stale demo photos so cover fallback can render")
    @MainActor
    func loadDemoDataRemovesStaleDemoPhotos() throws {
        let container = try makeInMemoryContainer()
        let context = container.mainContext

        DemoDataService.loadDemoData(into: context)
        let cruises = try context.fetch(FetchDescriptor<Cruise>())
        guard let norwegen = cruises.first(where: { $0.title == "Norwegische Fjorde" }) else {
            #expect(Bool(false), "Norwegen-Kreuzfahrt muss vorhanden sein")
            return
        }

        let stalePhoto = Photo(imageData: Data([0x89, 0x50, 0x4E, 0x47]), sortOrder: 0)
        stalePhoto.cruise = norwegen
        norwegen.photos.append(stalePhoto)
        context.insert(stalePhoto)
        try context.save()

        #expect(!norwegen.sortedPhotos.isEmpty, "Test-Setup braucht ein altes gespeichertes Demo-Foto")

        DemoDataService.loadDemoData(into: context)

        let photos = try context.fetch(FetchDescriptor<Photo>())
        #expect(photos.isEmpty, "Alte künstliche Demo-Fotos müssen entfernt werden, damit der Cover-Fallback greift")
        #expect(norwegen.sortedPhotos.isEmpty)
    }

    // MARK: - Idempotenz

    @Test("loadDemoData is idempotent: calling twice does not duplicate cruises")
    @MainActor
    func loadIsTwiceIdempotent() throws {
        let container = try makeInMemoryContainer()
        let context = container.mainContext

        DemoDataService.loadDemoData(into: context)
        DemoDataService.loadDemoData(into: context) // zweiter Aufruf muss kein doppeltes Seeding machen

        let cruises = try context.fetch(FetchDescriptor<Cruise>())
        #expect(cruises.count == 3, "Zweifaches Laden darf keine Duplikate erzeugen")
    }

    // MARK: - Remove → Reload (Stale-Data-Scenario)

    @Test("remove then reload keeps demo photos empty")
    @MainActor
    func removeAndReloadKeepsDemoPhotosEmpty() throws {
        let container = try makeInMemoryContainer()
        let context = container.mainContext

        // Erstes Laden
        DemoDataService.loadDemoData(into: context)
        #expect(DemoDataService.hasDemoData(in: context))

        // Entfernen
        DemoDataService.removeDemoData(from: context)
        #expect(!DemoDataService.hasDemoData(in: context))

        // Fotos müssen durch Cascade-Delete weg sein
        let photosAfterRemove = try context.fetch(FetchDescriptor<Photo>())
        #expect(photosAfterRemove.isEmpty, "Fotos müssen nach removeDemoData weg sein (Cascade)")

        // Erneutes Laden
        DemoDataService.loadDemoData(into: context)

        let cruises = try context.fetch(FetchDescriptor<Cruise>())
        #expect(cruises.allSatisfy { $0.sortedPhotos.isEmpty }, "Nach remove+reload dürfen keine künstlichen Demo-Fotos entstehen")
    }

    // MARK: - Hero-Card Cover-Fallback Path

    /// Repliziert exakt die Hero-Auswahl-Logik der CruiseListView
    /// (@Query sort: startDate desc → filter isUpcoming → min startDate)
    /// und verifiziert, dass das gewählte Hero-Cruise den schiffsspezifischen Cover-Fallback nutzt.
    @Test("heroCruiseUsesShipCoverFallbackFromDemoData")
    @MainActor
    func heroCruiseUsesShipCoverFallbackFromDemoData() throws {
        let container = try makeInMemoryContainer()
        let context = container.mainContext

        DemoDataService.loadDemoData(into: context)
        try context.save()

        // Repliziert @Query(sort: \Cruise.startDate, order: .reverse)
        let descriptor = FetchDescriptor<Cruise>(sortBy: [SortDescriptor(\Cruise.startDate, order: .reverse)])
        let cruises = try context.fetch(descriptor)

        // Repliziert CruiseListView.heroCruise (keine Textsuche / Filter aktiv)
        let hero = cruises.first { $0.isOngoing }
            ?? cruises.filter { $0.isUpcoming }.min { $0.startDate < $1.startDate }

        // --- Ground-truth values werden in den Failure-Messages sichtbar ---

        let heroTitle = hero?.title ?? "<nil>"
        let photoCount = hero?.sortedPhotos.count ?? -1
        let coverCandidates = hero.map {
            ShippingLine.coverAssetCandidates(shippingLine: $0.shippingLine, ship: $0.ship)
        } ?? []

        // 1. Hero muss existieren
        #expect(hero != nil, "hero muss nicht nil sein (title=\(heroTitle))")

        // 2. Hero hat kein künstliches Foto
        #expect(photoCount == 0,
            "hero '\(heroTitle)' hat \(photoCount) Fotos – erwartet 0, damit der Cover-Fallback greift")

        // 3. Das vorhandene exakte Schiffs-Cover ist der erste Kandidat
        #expect(coverCandidates.first == "cover_ship_aidanova",
            "hero '\(heroTitle)' nutzt unerwartete Cover-Kandidaten: \(coverCandidates)")
    }

    /// Sanity-Test: zeigt welche Demo-Cruises isUpcoming sind und ob keine Fotos tragen.
    @Test("sanity – which demo cruises are upcoming and have no photos")
    @MainActor
    func demoDataSanityUpcomingAndPhotoOwners() throws {
        let container = try makeInMemoryContainer()
        let context = container.mainContext

        DemoDataService.loadDemoData(into: context)
        try context.save()

        let cruises = try context.fetch(FetchDescriptor<Cruise>())

        var upcomingTitles: [String] = []
        var photoOwners: [(title: String, count: Int)] = []

        for cruise in cruises {
            if cruise.isUpcoming { upcomingTitles.append(cruise.title) }
            let count = cruise.sortedPhotos.count
            if count > 0 { photoOwners.append((cruise.title, count)) }
        }

        // Wir erwarten genau 1 upcoming (Norwegen, +21 Tage)
        #expect(upcomingTitles.count >= 1,
            "Erwartet ≥ 1 upcoming Demo-Cruise, gefunden: \(upcomingTitles)")

        #expect(photoOwners.isEmpty,
            "Demo-Cruises sollen keine künstlichen Fotos tragen; Foto-Träger: \(photoOwners.map { "\($0.title)=\($0.count)" })")
    }

    // MARK: - hasDemoData / removeDemoData

    @Test("hasDemoData returns false on empty context")
    @MainActor
    func hasDemoDataFalseWhenEmpty() throws {
        let container = try makeInMemoryContainer()
        let context = container.mainContext

        #expect(!DemoDataService.hasDemoData(in: context))
    }

    @Test("removeDemoData is idempotent on empty context")
    @MainActor
    func removeDemoDataIdempotentOnEmpty() throws {
        let container = try makeInMemoryContainer()
        let context = container.mainContext

        // Kein Crash bei leerem Store
        DemoDataService.removeDemoData(from: context)
        #expect(!DemoDataService.hasDemoData(in: context))
    }

    @Test("all seeded cruises and deals are tagged isDemo")
    @MainActor
    func allSeededObjectsAreTaggedIsDemo() throws {
        let container = try makeInMemoryContainer()
        let context = container.mainContext

        DemoDataService.loadDemoData(into: context)

        let cruises = try context.fetch(FetchDescriptor<Cruise>())
        let deals = try context.fetch(FetchDescriptor<Deal>())

        #expect(cruises.allSatisfy { $0.isDemo }, "Alle Demo-Kreuzfahrten müssen isDemo == true haben")
        #expect(deals.allSatisfy { $0.isDemo }, "Alle Demo-Angebote müssen isDemo == true haben")
    }

    /// Kernversprechen der Beispielreise im Release: Ein-Klick-Entfernen räumt
    /// ausschließlich die Demo-Objekte ab und lässt echte Nutzerdaten stehen.
    @Test("removeDemoData deletes only isDemo objects and keeps user data")
    @MainActor
    func removeDemoDataKeepsUserData() throws {
        let container = try makeInMemoryContainer()
        let context = container.mainContext

        let userCruise = Cruise(title: "Eigene Reise", startDate: Date(),
                                endDate: Date().addingTimeInterval(86_400),
                                shippingLine: "AIDA Cruises", ship: "AIDAnova")
        context.insert(userCruise)
        let userPort = CruisePort(name: "Kiel", country: "DE", latitude: 54.32, longitude: 10.14)
        userPort.cruise = userCruise
        context.insert(userPort)
        userCruise.route.append(userPort)
        context.insert(Deal(title: "Eigenes Angebot"))

        let userExpense = Expense(category: .onboard, amount: 42.50, description: "Eigene Ausgabe")
        userExpense.cruise = userCruise
        context.insert(userExpense)
        userCruise.expenses.append(userExpense)

        let userPhoto = Photo(imageData: Data([0x01, 0x02, 0x03]))
        userPhoto.cruise = userCruise
        context.insert(userPhoto)
        userCruise.photos.append(userPhoto)

        DemoDataService.loadDemoData(into: context)
        DemoDataService.removeDemoData(from: context)

        let cruises = try context.fetch(FetchDescriptor<Cruise>())
        let deals = try context.fetch(FetchDescriptor<Deal>())
        let ports = try context.fetch(FetchDescriptor<CruisePort>())
        let expenses = try context.fetch(FetchDescriptor<Expense>())
        let photos = try context.fetch(FetchDescriptor<Photo>())

        #expect(cruises.map(\.title) == ["Eigene Reise"], "Nur die Nutzer-Reise darf übrig bleiben")
        #expect(deals.map(\.title) == ["Eigenes Angebot"], "Nur das Nutzer-Angebot bleibt übrig")
        #expect(ports.map(\.name) == ["Kiel"], "Demo-Häfen weg (Cascade), Nutzer-Hafen bleibt")
        #expect(
            expenses.map(\.descriptionText) == ["Eigene Ausgabe"],
            "Demo-Ausgaben weg (Cascade), Nutzer-Ausgabe bleibt"
        )
        #expect(photos.count == 1, "Demo-Fotos weg, Nutzer-Foto bleibt")
        #expect(photos.first?.cruise?.title == "Eigene Reise", "Nutzer-Foto bleibt an der Reise")
    }
}
#endif
