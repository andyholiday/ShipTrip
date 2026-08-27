//
//  JournalAggregateRegressionTests.swift
//  ShipTripTests
//
//  Regression zu ADR-003: Fotos in Journal-Einträgen bleiben Kinder der Reise —
//  Galerie, Statistik-Aggregate und die Export-Nutzlast dürfen sich durch
//  Journal-Daten im Store nicht verändern.
//

import Testing
import Foundation
import SwiftData
@testable import ShipTrip

private typealias CruisePort = ShipTrip.Port

/// Momentaufnahme aller Werte, die Statistik und Export aus einer Reise ziehen.
private struct AggregateSnapshot: Equatable {
    let photoCount: Int
    let sortedPhotoIDs: [UUID]
    let totalExpenses: Double
    let countriesVisited: Set<String>
    let duration: Int
    let uniqueCountryCount: Int
    let totalSeaDays: Int
    let totalPortStops: Int
    let uniquePortCount: Int
    let totalTravelDays: Int

    @MainActor
    init(_ cruise: Cruise) {
        photoCount = cruise.photos.count
        sortedPhotoIDs = cruise.sortedPhotos.map(\.id)
        totalExpenses = cruise.totalExpenses
        countriesVisited = cruise.countriesVisited
        duration = cruise.duration
        uniqueCountryCount = [cruise].uniqueCountryCount
        totalSeaDays = [cruise].totalSeaDays
        totalPortStops = [cruise].totalPortStops
        uniquePortCount = [cruise].uniquePortCount
        totalTravelDays = [cruise].totalTravelDays
    }
}

@MainActor
private func makePopulatedCruise(_ context: ModelContext) -> Cruise {
    let cruise = makeJournalCruise(context, title: "Aggregat-Regression")

    let bergen = makeJournalPort(context, cruise: cruise, name: "Bergen")
    bergen.sortOrder = 0

    let seaDay = CruisePort(name: "Seetag", country: "", latitude: 0, longitude: 0)
    seaDay.isSeaDay = true
    seaDay.sortOrder = 1
    seaDay.cruise = cruise
    context.insert(seaDay)

    let expense = Expense(category: .excursion, amount: 42.5, description: "Fjord-Tour")
    expense.cruise = cruise
    context.insert(expense)

    for index in 0..<3 {
        _ = makeJournalPhoto(context, cruise: cruise, sortOrder: index)
    }

    return cruise
}

@Suite("Journal-Daten lassen Aggregate und Export unverändert")
struct JournalAggregateRegressionTests {

    @Test("Statistik-Aggregate sind mit und ohne Journal-Daten identisch")
    @MainActor
    func aggregatesAreUnchangedByJournalData() throws {
        let context = try makeJournalContainer().mainContext
        let cruise = makePopulatedCruise(context)
        try context.save()

        let before = AggregateSnapshot(cruise)

        // Journal-Nutzlast hinzufügen: zwei Einträge, ein angehängtes Foto, eine Caption.
        let entry = JournalEntry(text: "Bergen bei Regen", moodRaw: "good")
        entry.cruise = cruise
        context.insert(entry)
        entry.setPort(cruise.route.first)
        let attached = try #require(cruise.sortedPhotos.first)
        entry.attach(attached)
        attached.setCaption("Bryggen im Nieselregen")

        let seaDayEntry = JournalEntry(text: "Ruhiger Seetag")
        seaDayEntry.cruise = cruise
        context.insert(seaDayEntry)
        try context.save()

        #expect(cruise.journalEntries.count == 2)
        #expect(
            AggregateSnapshot(cruise) == before,
            "Journal-Daten dürfen keine Aggregate verschieben"
        )
        #expect(attached.cruise?.id == cruise.id, "Ein angehängtes Foto bleibt Kind der Reise")
    }

    @Test("Die Export-Nutzlast der Reise bleibt mit Journal-Daten identisch")
    @MainActor
    func exportPayloadIsUnchangedByJournalData() throws {
        let context = try makeJournalContainer().mainContext
        let cruise = makePopulatedCruise(context)
        try context.save()

        let before = try exportedCruise(cruise)

        let entry = JournalEntry(text: "Erinnerung im Export-Store")
        entry.cruise = cruise
        context.insert(entry)
        let attached = try #require(cruise.sortedPhotos.first)
        entry.attach(attached)
        try context.save()

        let after = try exportedCruise(cruise)

        #expect(after.id == before.id)
        #expect(after.title == before.title)
        #expect(after.rating == before.rating)
        #expect(
            after.photos.map(\.id) == before.photos.map(\.id),
            "Galerie-Reihenfolge unverändert"
        )
        #expect(after.route.map(\.name) == before.route.map(\.name))
        #expect(after.expenses.map(\.amount) == before.expenses.map(\.amount))
    }

    /// Exportiert eine Reise als JSON und liefert die dekodierte Reise-Nutzlast zurück.
    @MainActor
    private func exportedCruise(_ cruise: Cruise) throws -> ExportCruise {
        let url = try ExportImportService.shared.exportToJSON(cruises: [cruise])
        defer { try? FileManager.default.removeItem(at: url) }

        let archive = try JSONDecoder().decode(ExportArchive.self, from: Data(contentsOf: url))
        return try #require(archive.cruises.first)
    }
}
