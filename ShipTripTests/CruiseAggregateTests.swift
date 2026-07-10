//
//  CruiseAggregateTests.swift
//  ShipTripTests
//
//  Tests für Array<Cruise>-Aggregat-Helfer (uniqueCountryCount, totalSeaDays, totalPortStops)
//  und Hero-Auswahl-Priorität (laufend > nächste bevorstehende > zuletzt vergangene).
//

import Testing
import Foundation
import SwiftData
import UIKit
@testable import ShipTrip

private typealias CruisePort = ShipTrip.Port

// MARK: - Fixture-Helfer

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

// MARK: - Cruise.countriesVisited

@Suite("Cruise.countriesVisited")
struct CruiseCountriesVisitedTests {

    @Test("Häfen mit leerem Land (z. B. ohne erfasstes Land oder Seetage) zählen nicht mit")
    @MainActor
    func excludesEmptyCountry() throws {
        let container = try makeInMemoryContainer()
        let context = container.mainContext

        let cruise = Cruise(
            title: "Test",
            startDate: makeDate("2025-06-01"),
            endDate: makeDate("2025-06-10"),
            shippingLine: "MSC",
            ship: "Bellissima"
        )
        context.insert(cruise)

        let portES = CruisePort(name: "Barcelona", country: "Spanien", latitude: 41.3, longitude: 2.1)
        portES.cruise = cruise
        context.insert(portES)

        let portUnknown = CruisePort(name: "Testhafen", country: "", latitude: 0, longitude: 0)
        portUnknown.cruise = cruise
        context.insert(portUnknown)

        try context.save()

        #expect(cruise.countriesVisited.count == 1)
    }
}

// MARK: - Array<Cruise> Aggregat-Tests

@Suite("Array<Cruise> Aggregate")
struct CruiseAggregateTests {

    // MARK: uniqueCountryCount

    @Test("uniqueCountryCount schließt leere Länder (Seetage) aus")
    @MainActor
    func uniqueCountryCountExcludesEmptyCountries() throws {
        let container = try makeInMemoryContainer()
        let context = container.mainContext

        let cruise = Cruise(
            title: "Test",
            startDate: makeDate("2025-01-01"),
            endDate: makeDate("2025-01-10"),
            shippingLine: "MSC",
            ship: "Bellissima"
        )
        context.insert(cruise)

        // 2 echte Länder + 1 Seetag (leeres Land)
        let portDE = CruisePort(name: "Hamburg", country: "Deutschland", latitude: 53.5, longitude: 9.9)
        portDE.isSeaDay = false
        portDE.cruise = cruise
        context.insert(portDE)

        let portES = CruisePort(name: "Barcelona", country: "Spanien", latitude: 41.3, longitude: 2.1)
        portES.isSeaDay = false
        portES.cruise = cruise
        context.insert(portES)

        let seaDay = CruisePort(name: "Seetag", country: "", latitude: 0, longitude: 0)
        seaDay.isSeaDay = true
        seaDay.cruise = cruise
        context.insert(seaDay)

        try context.save()

        let cruises = [cruise]
        #expect(cruises.uniqueCountryCount == 2)
    }

    @Test("uniqueCountryCount mit einem leeren Cruise-Array ist 0")
    func uniqueCountryCountEmptyArray() {
        let cruises: [Cruise] = []
        #expect(cruises.uniqueCountryCount == 0)
    }

    // MARK: totalSeaDays

    @Test("totalSeaDays zählt nur isSeaDay-Ports")
    @MainActor
    func totalSeaDaysCountsOnlySeaDayPorts() throws {
        let container = try makeInMemoryContainer()
        let context = container.mainContext

        let cruise = Cruise(
            title: "Test",
            startDate: makeDate("2025-02-01"),
            endDate: makeDate("2025-02-14"),
            shippingLine: "AIDA",
            ship: "AIDAmar"
        )
        context.insert(cruise)

        let port1 = CruisePort(name: "Bergen", country: "Norwegen", latitude: 60.4, longitude: 5.3)
        port1.isSeaDay = false
        port1.cruise = cruise
        context.insert(port1)

        let sea1 = CruisePort(name: "Seetag 1", country: "", latitude: 0, longitude: 0)
        sea1.isSeaDay = true
        sea1.cruise = cruise
        context.insert(sea1)

        let sea2 = CruisePort(name: "Seetag 2", country: "", latitude: 0, longitude: 0)
        sea2.isSeaDay = true
        sea2.cruise = cruise
        context.insert(sea2)

        try context.save()

        let cruises = [cruise]
        #expect(cruises.totalSeaDays == 2)
    }

    // MARK: totalPortStops

    @Test("totalPortStops zählt nur Nicht-Seetag-Ports")
    @MainActor
    func totalPortStopsCountsOnlyNonSeaDayPorts() throws {
        let container = try makeInMemoryContainer()
        let context = container.mainContext

        let cruise = Cruise(
            title: "Test",
            startDate: makeDate("2025-03-01"),
            endDate: makeDate("2025-03-10"),
            shippingLine: "TUI",
            ship: "Mein Schiff 4"
        )
        context.insert(cruise)

        let port1 = CruisePort(name: "Malaga", country: "Spanien", latitude: 36.7, longitude: -4.4)
        port1.isSeaDay = false
        port1.cruise = cruise
        context.insert(port1)

        let port2 = CruisePort(name: "Teneriffa", country: "Spanien", latitude: 28.4, longitude: -16.2)
        port2.isSeaDay = false
        port2.cruise = cruise
        context.insert(port2)

        let sea1 = CruisePort(name: "Seetag", country: "", latitude: 0, longitude: 0)
        sea1.isSeaDay = true
        sea1.cruise = cruise
        context.insert(sea1)

        try context.save()

        let cruises = [cruise]
        #expect(cruises.totalPortStops == 2)
    }

    // MARK: totalTravelDays

    @Test("totalTravelDays summiert duration aller Kreuzfahrten")
    @MainActor
    func totalTravelDaysSumsDuration() throws {
        let container = try makeInMemoryContainer()
        let context = container.mainContext

        // 1.–7. Januar → duration = 7
        let cruise1 = Cruise(
            title: "Test1",
            startDate: makeDate("2025-01-01"),
            endDate: makeDate("2025-01-07"),
            shippingLine: "MSC",
            ship: "Seashore"
        )
        context.insert(cruise1)

        // 1.–3. März → duration = 3
        let cruise2 = Cruise(
            title: "Test2",
            startDate: makeDate("2025-03-01"),
            endDate: makeDate("2025-03-03"),
            shippingLine: "AIDA",
            ship: "AIDAmar"
        )
        context.insert(cruise2)

        try context.save()

        let cruises = [cruise1, cruise2]
        #expect(cruises.totalTravelDays == 10)
    }

    @Test("totalTravelDays mit leerem Array ist 0")
    func totalTravelDaysEmptyArray() {
        let cruises: [Cruise] = []
        #expect(cruises.totalTravelDays == 0)
    }

    @Test("totalSeaDays und totalPortStops über mehrere Kreuzfahrten summieren korrekt")
    @MainActor
    func aggregatesAcrossMultipleCruises() throws {
        let container = try makeInMemoryContainer()
        let context = container.mainContext

        let cruise1 = Cruise(
            title: "Mittelmeer",
            startDate: makeDate("2025-04-01"),
            endDate: makeDate("2025-04-08"),
            shippingLine: "MSC",
            ship: "Seashore"
        )
        context.insert(cruise1)

        let cruise2 = Cruise(
            title: "Norwegen",
            startDate: makeDate("2025-05-01"),
            endDate: makeDate("2025-05-10"),
            shippingLine: "AIDA",
            ship: "AIDAprima"
        )
        context.insert(cruise2)

        // cruise1: 1 Hafen, 2 Seetage
        let p1 = CruisePort(name: "Palma", country: "Spanien", latitude: 39.5, longitude: 2.6)
        p1.isSeaDay = false; p1.cruise = cruise1; context.insert(p1)
        let s1 = CruisePort(name: "See", country: "", latitude: 0, longitude: 0)
        s1.isSeaDay = true; s1.cruise = cruise1; context.insert(s1)
        let s2 = CruisePort(name: "See", country: "", latitude: 0, longitude: 0)
        s2.isSeaDay = true; s2.cruise = cruise1; context.insert(s2)

        // cruise2: 3 Häfen, 1 Seetag
        let p2 = CruisePort(name: "Bergen", country: "Norwegen", latitude: 60.4, longitude: 5.3)
        p2.isSeaDay = false; p2.cruise = cruise2; context.insert(p2)
        let p3 = CruisePort(name: "Flåm", country: "Norwegen", latitude: 60.9, longitude: 7.1)
        p3.isSeaDay = false; p3.cruise = cruise2; context.insert(p3)
        let p4 = CruisePort(name: "Stavanger", country: "Norwegen", latitude: 58.9, longitude: 5.7)
        p4.isSeaDay = false; p4.cruise = cruise2; context.insert(p4)
        let s3 = CruisePort(name: "See", country: "", latitude: 0, longitude: 0)
        s3.isSeaDay = true; s3.cruise = cruise2; context.insert(s3)

        try context.save()

        let cruises = [cruise1, cruise2]
        #expect(cruises.totalPortStops == 4)
        #expect(cruises.totalSeaDays == 3)
    }
}

// MARK: - Hero-Auswahl-Tests

/// Repliziert die heroCruise-Logik aus CruiseListView.
private func selectHero(from cruises: [Cruise]) -> Cruise? {
    cruises.first { $0.isOngoing }
        ?? cruises.filter { $0.isUpcoming }.min { $0.startDate < $1.startDate }
}

@Suite("Hero-Auswahl-Priorität")
struct HeroSelectionTests {

    /// Fixture mit einer laufenden, einer bevorstehenden und einer vergangenen Kreuzfahrt.
    /// Erwartet: die laufende wird gewählt.
    @Test("laufende Reise wird vor bevorstehender und vergangener bevorzugt")
    func ongoingBeatsUpcomingAndPast() {
        let now = Date()

        // Laufende Reise: gestern–morgen
        let ongoing = Cruise(
            title: "Laufend",
            startDate: now.addingTimeInterval(-86400),
            endDate: now.addingTimeInterval(86400),
            shippingLine: "MSC",
            ship: "Seashore"
        )

        // Nächste bevorstehende: in 10 Tagen
        let upcoming = Cruise(
            title: "Bevorstehend",
            startDate: now.addingTimeInterval(10 * 86400),
            endDate: now.addingTimeInterval(17 * 86400),
            shippingLine: "AIDA",
            ship: "AIDAmar"
        )

        // Vergangene: vor 30 Tagen
        let past = Cruise(
            title: "Vergangen",
            startDate: now.addingTimeInterval(-30 * 86400),
            endDate: now.addingTimeInterval(-23 * 86400),
            shippingLine: "TUI",
            ship: "Mein Schiff 4"
        )

        let hero = selectHero(from: [past, upcoming, ongoing])
        #expect(hero?.title == "Laufend",
                "Hero muss die laufende Reise sein, gefunden: \(hero?.title ?? "<nil>")")
    }

    @Test("ohne laufende Reise wird die nächstgelegene bevorstehende bevorzugt")
    func nearestUpcomingWhenNoOngoing() {
        let now = Date()

        // Zwei bevorstehende: in 5 und in 30 Tagen
        let soon = Cruise(
            title: "Bald",
            startDate: now.addingTimeInterval(5 * 86400),
            endDate: now.addingTimeInterval(12 * 86400),
            shippingLine: "MSC",
            ship: "Seashore"
        )
        let later = Cruise(
            title: "Später",
            startDate: now.addingTimeInterval(30 * 86400),
            endDate: now.addingTimeInterval(37 * 86400),
            shippingLine: "AIDA",
            ship: "AIDAmar"
        )
        let past = Cruise(
            title: "Vergangen",
            startDate: now.addingTimeInterval(-30 * 86400),
            endDate: now.addingTimeInterval(-23 * 86400),
            shippingLine: "TUI",
            ship: "Mein Schiff 4"
        )

        let hero = selectHero(from: [later, past, soon])
        #expect(hero?.title == "Bald",
                "Hero muss die nächste bevorstehende sein, gefunden: \(hero?.title ?? "<nil>")")
    }

    @Test("ohne laufende oder bevorstehende Reisen bleibt Hero leer")
    func noHeroWhenOnlyPastTrips() {
        let now = Date()

        let past1 = Cruise(
            title: "Vergangen1",
            startDate: now.addingTimeInterval(-60 * 86400),
            endDate: now.addingTimeInterval(-53 * 86400),
            shippingLine: "MSC",
            ship: "Seashore"
        )
        let past2 = Cruise(
            title: "Vergangen2",
            startDate: now.addingTimeInterval(-20 * 86400),
            endDate: now.addingTimeInterval(-13 * 86400),
            shippingLine: "AIDA",
            ship: "AIDAmar"
        )

        let hero = selectHero(from: [past1, past2])
        #expect(hero == nil, "Vergangene Reisen sollen im Jahres-Logbuch bleiben, gefunden: \(hero?.title ?? "<nil>")")
    }
}

@Suite("Cruise-Cover-Fallback")
struct CruiseCoverFallbackTests {

    @Test("Cover-Kandidaten priorisieren stabilen Reederei-Pool vor Legacy-Covern")
    func coverCandidatesPreferStableLinePoolThenLegacyCovers() {
        let candidates = ShippingLine.coverAssetCandidates(
            shippingLine: "AIDA Cruises",
            ship: "AIDAnova"
        )

        #expect(candidates.first?.hasPrefix("cover_line_aida_") == true)
        #expect(candidates.contains("cover_line_aida"))
        #expect(candidates.contains("cover_ship_aidanova"))
        #expect(candidates.last == "cover_ocean_route")
    }

    @Test("Cover-Pool-Zuordnung ist pro Schiff stabil")
    func coverPoolAssignmentIsStablePerShip() {
        let first = ShippingLine.coverAssetCandidates(
            shippingLine: "MSC Cruises",
            ship: "MSC Seaside"
        ).first
        let second = ShippingLine.coverAssetCandidates(
            shippingLine: "MSC Cruises",
            ship: "MSC Seaside"
        ).first

        #expect(first == second)
        #expect(first?.hasPrefix("cover_line_msc_") == true)
    }

    @Test("AIDAnova Hero-Cover-Kandidat ist aus Assets ladbar")
    func aidaHeroCoverCandidateLoadsFromAssetCatalog() {
        let candidates = ShippingLine.coverAssetCandidates(
            shippingLine: "AIDA Cruises",
            ship: "AIDAnova"
        )

        #expect(candidates.first == "cover_line_aida_1")
        #expect(candidates.first.flatMap { UIImage(named: $0) } != nil)
    }

    // MARK: - D1: Stock-Cover für eigene Reedereien/Schiffe

    @Test("Eigene Reederei/Schiff bekommen ein Schiffs-Cover vor dem Stock-Cover statt direkt Ocean-Fallback")
    func unknownLineAndShipGetShipCoverThenStockCover() {
        let candidates = ShippingLine.coverAssetCandidates(
            shippingLine: "Meine Fantasie-Reederei",
            ship: "MS Sonnenschein"
        )

        #expect(candidates == ["cover_ship_ms_sonnenschein", "cover_line_msc_3", "cover_ocean_route"])
    }

    @Test("Katalog-nahe, aber nicht treffende Namen priorisieren weiterhin ein existierendes Schiffs-Cover vor dem Stock-Pool (Regression)")
    func nearMissCatalogNamesStillPreferExistingShipCoverOverStock() {
        // "Cunard Line" matcht `find(byName:)` nicht exakt (Katalog-Name ist "Cunard"), und
        // "Queen-Mary 2" matcht `findByShipName` wegen des Bindestrichs nicht (Katalog-Schiff ist
        // "Queen Mary 2") – beide Katalog-Lookups verfehlen also, aber `cover_ship_queen_mary_2`
        // existiert als Asset und muss weiterhin vor dem Stock-Pool gewinnen.
        let candidates = ShippingLine.coverAssetCandidates(shippingLine: "Cunard Line", ship: "Queen-Mary 2")

        #expect(candidates.first == "cover_ship_queen_mary_2")
        #expect(candidates.count == 3)
        #expect(ShippingLine.stockCoverPool.contains(candidates[1]))
        #expect(candidates.last == "cover_ocean_route")
    }

    @Test("Stock-Cover-Zuordnung für eigene Reedereien/Schiffe ist deterministisch")
    func stockCoverAssignmentIsDeterministic() {
        let first = ShippingLine.coverAssetCandidates(shippingLine: "Meine Fantasie-Reederei", ship: "MS Sonnenschein")
        let second = ShippingLine.coverAssetCandidates(shippingLine: "Meine Fantasie-Reederei", ship: "MS Sonnenschein")

        #expect(first == second)
    }

    @Test("Verschiedene eigene Namenspaare streuen auf verschiedene Stock-Cover")
    func stockCoverSpreadsAcrossDifferentCustomNamePairs() {
        let candidatesA = ShippingLine.coverAssetCandidates(shippingLine: "Meine Fantasie-Reederei", ship: "MS Sonnenschein")
        let candidatesB = ShippingLine.coverAssetCandidates(shippingLine: "Nordlicht Flotten GmbH", ship: "Polarstern Under Ice")

        let stockA = candidatesA.first { ShippingLine.stockCoverPool.contains($0) }
        let stockB = candidatesB.first { ShippingLine.stockCoverPool.contains($0) }

        #expect(stockA != nil)
        #expect(stockB != nil)
        #expect(stockA != stockB)
    }

    @Test("Katalog-Reederei mit unbekanntem Schiff bleibt beim Reederei-Pool (Regression)")
    func catalogLineWithUnknownShipStaysOnLinePool() {
        let candidates = ShippingLine.coverAssetCandidates(shippingLine: "AIDA Cruises", ship: "Unbekanntes Schiff XYZ")
        #expect(candidates.first?.hasPrefix("cover_line_aida_") == true)
    }

    @Test("Unbekannte Reederei mit bekanntem Katalog-Schiff bleibt bei bisheriger Zuordnung (Regression)")
    func unknownLineWithKnownCatalogShipStaysOnPreviousMatch() {
        let expected = ShippingLine.coverAssetCandidates(shippingLine: "AIDA Cruises", ship: "AIDAnova")
        let actual = ShippingLine.coverAssetCandidates(shippingLine: "Unbekannte Reederei", ship: "AIDAnova")
        #expect(actual == expected)
    }

    @Test("Leere Reederei und leeres Schiff liefern nur den Ocean-Fallback")
    func emptyLineAndShipYieldOnlyOceanFallback() {
        let candidates = ShippingLine.coverAssetCandidates(shippingLine: "", ship: "")
        #expect(candidates == ["cover_ocean_route"])
    }

    @Test("Genau ein leerer Name (Reederei oder Schiff) liefert trotzdem einen Stock-Kandidaten")
    func onlyOneEmptyNameStillYieldsStockCandidate() {
        let emptyLine = ShippingLine.coverAssetCandidates(shippingLine: "", ship: "Sonnenschein Schiff")
        #expect(emptyLine.contains { ShippingLine.stockCoverPool.contains($0) })
        #expect(emptyLine.last == "cover_ocean_route")

        let emptyShip = ShippingLine.coverAssetCandidates(shippingLine: "Sonnenschein Reederei", ship: "")
        #expect(emptyShip.contains { ShippingLine.stockCoverPool.contains($0) })
        #expect(emptyShip.last == "cover_ocean_route")
    }

    @Test("Alle 70 Stock-Cover-Pool-Assets sind eindeutig und aus dem Asset-Katalog ladbar")
    func allStockCoverPoolAssetsAreUniqueAndLoadable() {
        #expect(ShippingLine.stockCoverPool.count == 70)
        #expect(Set(ShippingLine.stockCoverPool).count == ShippingLine.stockCoverPool.count, "Pool enthält Duplikate")
        for assetName in ShippingLine.stockCoverPool {
            #expect(UIImage(named: assetName) != nil, "Asset \(assetName) nicht ladbar")
        }
    }

    @Test("Zwei Namenspaare sind als Frozen-Hash-Spotcheck fest verdrahtet")
    func frozenStockCoverHashSpotChecks() {
        let candidatesA = ShippingLine.coverAssetCandidates(shippingLine: "Meine Fantasie-Reederei", ship: "MS Sonnenschein")
        #expect(candidatesA.contains("cover_line_msc_3"))

        let candidatesB = ShippingLine.coverAssetCandidates(shippingLine: "Nordlicht Flotten GmbH", ship: "Polarstern Under Ice")
        #expect(candidatesB.contains("cover_line_carnival_2"))
    }
}
