//
//  DemoDataServiceTests.swift
//  ShipTripTests
//
//  Verifiziert, dass DemoDataService die Cover-Photo des Norwegen-Cruise
//  korrekt einhängt und dass sortedPhotos.first nach dem Laden nicht nil ist.
//  Deckt gleichzeitig den Stale-Data-Bug ab: removeDemo → loadDemo muss
//  das Foto erneut anlegen (idempotenz in beide Richtungen).
//

#if DEBUG
import Testing
import SwiftData
import UIKit
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

    @Test("Norwegische Fjorde cruise has a cover photo after loadDemoData")
    @MainActor
    func norweigenCruiseHasCoverPhoto() throws {
        let container = try makeInMemoryContainer()
        let context = container.mainContext

        DemoDataService.loadDemoData(into: context)

        let cruises = try context.fetch(FetchDescriptor<Cruise>())
        let norwegen = cruises.first { $0.title == "Norwegische Fjorde" }
        #expect(norwegen != nil, "Norwegen-Kreuzfahrt muss vorhanden sein")

        guard let cruise = norwegen else { return }

        // sortedPhotos.first darf nicht nil sein
        let photo = cruise.sortedPhotos.first
        #expect(photo != nil, "sortedPhotos.first muss nach dem Seeden ein Foto liefern")

        // imageData muss dekodierbar sein
        if let photo {
            let uiImage = UIImage(data: photo.imageData)
            #expect(uiImage != nil, "imageData muss ein gültiges UIImage ergeben")
        }
    }

    @Test("sortOrder of seeded cover photo is 0")
    @MainActor
    func seededPhotoSortOrderIsZero() throws {
        let container = try makeInMemoryContainer()
        let context = container.mainContext

        DemoDataService.loadDemoData(into: context)

        let cruises = try context.fetch(FetchDescriptor<Cruise>())
        let norwegen = cruises.first { $0.title == "Norwegische Fjorde" }
        #expect(norwegen?.sortedPhotos.first?.sortOrder == 0)
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

    @Test("remove then reload produces fresh photo – stale-data scenario")
    @MainActor
    func removeAndReloadProducesFreshPhoto() throws {
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
        let norwegen = cruises.first { $0.title == "Norwegische Fjorde" }
        let photo = norwegen?.sortedPhotos.first
        #expect(photo != nil, "Nach remove+reload muss das Cover-Foto wieder vorhanden sein")
    }

    // MARK: - Hero-Card Photo Path (Arbiter-Test)

    /// Repliziert exakt die Hero-Auswahl-Logik der CruiseListView
    /// (@Query sort: startDate desc → filter isUpcoming → min startDate)
    /// und verifiziert, dass das gewählte Hero-Cruise ein dekodierbares Foto hat.
    @Test("heroCruiseRendersPhotoFromDemoData – hard data on photo path")
    @MainActor
    func heroCruiseRendersPhotoFromDemoData() throws {
        let container = try makeInMemoryContainer()
        let context = container.mainContext

        DemoDataService.loadDemoData(into: context)
        try context.save()

        // Repliziert @Query(sort: \Cruise.startDate, order: .reverse)
        var descriptor = FetchDescriptor<Cruise>(sortBy: [SortDescriptor(\Cruise.startDate, order: .reverse)])
        let cruises = try context.fetch(descriptor)

        // Repliziert CruiseListView.heroCruise (keine Textsuche / Filter aktiv)
        let hero = cruises.filter { $0.isUpcoming }.min { $0.startDate < $1.startDate }
            ?? cruises.first { !$0.isUpcoming }
            ?? cruises.first

        // --- Ground-truth values werden in den Failure-Messages sichtbar ---

        let heroTitle = hero?.title ?? "<nil>"
        let photoCount = hero?.sortedPhotos.count ?? -1
        let firstPhoto = hero?.sortedPhotos.first
        let imageData = firstPhoto.flatMap { ($0.thumbnailData ?? $0.imageData).isEmpty ? nil : ($0.thumbnailData ?? $0.imageData) }
        let uiImageDecoded = imageData.flatMap { UIImage(data: $0) } != nil

        // 1. Hero muss existieren
        #expect(hero != nil, "hero muss nicht nil sein (title=\(heroTitle))")

        // 2. Hero muss mindestens 1 Foto haben
        #expect(photoCount > 0,
            "hero '\(heroTitle)' hat \(photoCount) Fotos – erwartet > 0")

        // 3. Erstes Foto muss nicht nil sein
        #expect(firstPhoto != nil,
            "hero '\(heroTitle)': sortedPhotos.first ist nil (count=\(photoCount))")

        // 4. UIImage muss dekodierbar sein
        #expect(uiImageDecoded,
            "hero '\(heroTitle)': UIImage(data:) schlug fehl für sortedPhotos.first (thumbnailData=\(firstPhoto?.thumbnailData != nil), imageData.count=\(firstPhoto?.imageData.count ?? -1))")
    }

    /// Sanity-Test: zeigt welche Demo-Cruises isUpcoming sind und welche Fotos tragen.
    @Test("sanity – which demo cruises are upcoming and which carry photos")
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

        // Norwegen trägt das Foto
        let norwegenHasPhoto = photoOwners.contains { $0.title == "Norwegische Fjorde" }
        #expect(norwegenHasPhoto,
            "Erwartet Foto auf 'Norwegische Fjorde'; Foto-Träger: \(photoOwners.map { "\($0.title)=\($0.count)" })")

        // Upcoming-Liste und Foto-Träger-Liste müssen sich überschneiden
        // (damit der Hero tatsächlich ein Foto hat)
        let upcomingSet = Set(upcomingTitles)
        let photoOwnerSet = Set(photoOwners.map { $0.title })
        let intersection = upcomingSet.intersection(photoOwnerSet)
        #expect(!intersection.isEmpty,
            "Kein Upcoming-Cruise trägt ein Foto! upcoming=\(upcomingTitles), mit Fotos=\(photoOwners.map { $0.title })")
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
}
#endif
