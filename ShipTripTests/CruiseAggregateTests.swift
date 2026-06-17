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
        ?? cruises.first { !$0.isUpcoming }
        ?? cruises.first
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

    @Test("ohne bevorstehende Reisen wird die zuerst gefundene vergangene bevorzugt")
    func firstNonUpcomingWhenNoOngoingOrUpcoming() {
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

        // selectHero gibt first { !$0.isUpcoming } zurück — also die erste aus der Liste
        let hero = selectHero(from: [past1, past2])
        #expect(hero?.title == "Vergangen1",
                "Hero muss erste vergangene sein, gefunden: \(hero?.title ?? "<nil>")")
    }
}
