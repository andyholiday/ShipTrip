//
//  PortFormViewTests.swift
//  ShipTripTests
//
//  Tests für die A5.1/A5.3-Ergänzungen aus PortFormView.swift und CruiseFormView.swift:
//  Auto-Datum für neue Häfen (`defaultArrivalDateForNewPort`, `defaultArrivalDate`), die
//  Ausflug-Sanitisierung (`sanitizedExcursionEntry`) sowie ein SwiftData-Roundtrip für
//  Hafenbild + Ausflüge über dieselbe Feld-Zuweisung wie PortFormView.savePort().
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

private let utc: Calendar = {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(identifier: "UTC")!
    return calendar
}()

// MARK: - defaultArrivalDateForNewPort (PortFormView, Cruise.route)

@Suite("defaultArrivalDateForNewPort")
struct DefaultArrivalDateForNewPortTests {

    @Test("Ohne Route: fällt auf das Startdatum der Kreuzfahrt zurück")
    @MainActor
    func fallsBackToCruiseStartDate() throws {
        let container = try makeInMemoryContainer()
        let context = container.mainContext

        let start = makeDate("2026-03-01")
        let cruise = Cruise(title: "Test", startDate: start, endDate: makeDate("2026-03-10"), shippingLine: "MSC", ship: "Bellissima")
        context.insert(cruise)
        try context.save()

        #expect(defaultArrivalDateForNewPort(in: cruise, calendar: utc) == start)
    }

    @Test("Mit Route: Folgetag des letzten Stopps nach sortOrder, nicht nach Einfüge-Reihenfolge")
    @MainActor
    func usesSortOrderNotInsertionOrder() throws {
        let container = try makeInMemoryContainer()
        let context = container.mainContext

        let cruise = Cruise(title: "Test", startDate: makeDate("2026-03-01"), endDate: makeDate("2026-03-10"), shippingLine: "AIDA", ship: "AIDAmar")
        context.insert(cruise)

        // Bewusst in der "falschen" Reihenfolge angelegt (letzter Stopp zuerst inserted),
        // damit ein Bug, der sich auf die Relationship-Iterationsreihenfolge statt auf
        // sortOrder verlässt, hier auffliegen würde.
        let last = CruisePort(name: "Kopenhagen", country: "Dänemark", latitude: 55.6, longitude: 12.5)
        last.arrival = makeDate("2026-03-05")
        last.sortOrder = 1
        last.cruise = cruise
        context.insert(last)

        let first = CruisePort(name: "Hamburg", country: "Deutschland", latitude: 53.5, longitude: 9.9)
        first.arrival = makeDate("2026-03-03")
        first.sortOrder = 0
        first.cruise = cruise
        context.insert(first)

        try context.save()

        let expected = utc.date(byAdding: .day, value: 1, to: makeDate("2026-03-05"))!
        #expect(defaultArrivalDateForNewPort(in: cruise, calendar: utc) == expected)
    }
}

// MARK: - defaultArrivalDate(afterLastOf:fallback:) (TempPortFormSheet, tempPorts-Array)

@Suite("defaultArrivalDate(afterLastOf:fallback:)")
struct DefaultArrivalDateAfterLastOfTests {

    @Test("Leere Liste: fällt auf den übergebenen Fallback zurück")
    func fallsBackWhenEmpty() {
        let fallback = makeDate("2026-05-01")
        #expect(defaultArrivalDate(afterLastOf: [], fallback: fallback, calendar: utc) == fallback)
    }

    @Test("Nicht-leere Liste: Folgetag des letzten Array-Eintrags")
    func usesLastArrayEntry() {
        let ports = [
            TempPort(name: "A", country: "Land A", arrival: makeDate("2026-05-02"), departure: makeDate("2026-05-02")),
            TempPort(name: "B", country: "Land B", arrival: makeDate("2026-05-04"), departure: makeDate("2026-05-04"))
        ]
        let expected = utc.date(byAdding: .day, value: 1, to: makeDate("2026-05-04"))!
        #expect(defaultArrivalDate(afterLastOf: ports, fallback: makeDate("2026-05-01"), calendar: utc) == expected)
    }
}

// MARK: - sanitizedExcursionEntry

@Suite("sanitizedExcursionEntry")
struct SanitizedExcursionEntryTests {

    @Test("Trimmt Leerzeichen/Zeilenumbrüche")
    func trimsWhitespace() {
        #expect(sanitizedExcursionEntry("  Stadtrundfahrt  \n") == "Stadtrundfahrt")
    }

    @Test("Entfernt Kommas (Format-Trenner von excursionsRaw)")
    func stripsCommas() {
        #expect(sanitizedExcursionEntry("Altstadt, Hafenrundfahrt") == "Altstadt Hafenrundfahrt")
    }

    @Test("Leere oder nur aus Whitespace bestehende Eingaben ergeben nil")
    func emptyOrWhitespaceOnlyYieldsNil() {
        #expect(sanitizedExcursionEntry("") == nil)
        #expect(sanitizedExcursionEntry("   ") == nil)
        #expect(sanitizedExcursionEntry(",") == nil)
    }
}

// MARK: - SwiftData-Roundtrip: Hafenbild + Ausflüge

@Suite("Port Hafenbild/Ausflüge Roundtrip")
struct PortImageExcursionsRoundtripTests {

    @Test("Neuer Hafen: dieselbe Feld-Zuweisung wie PortFormView.savePort() persistiert Bild + Ausflüge")
    @MainActor
    func newPortPersistsImageAndExcursions() throws {
        let container = try makeInMemoryContainer()
        let context = container.mainContext

        let cruise = Cruise(title: "Test", startDate: makeDate("2026-03-01"), endDate: makeDate("2026-03-10"), shippingLine: "MSC", ship: "Bellissima")
        context.insert(cruise)
        try context.save()

        // Spiegelt PortFormView.savePort() im Create-Pfad.
        let imageData = Data([0xAA, 0xBB, 0xCC])
        let excursions = ["Stadtrundfahrt", "Hafenrundfahrt"]

        let newPort = CruisePort(name: "Hamburg", country: "Deutschland", latitude: 53.5, longitude: 9.9)
        newPort.arrival = makeDate("2026-03-02")
        newPort.departure = makeDate("2026-03-02")
        newPort.sortOrder = cruise.route.count
        newPort.imageData = imageData
        newPort.excursions = excursions
        newPort.cruise = cruise
        context.insert(newPort)
        try context.save()

        let fetched = try #require(try context.fetch(FetchDescriptor<CruisePort>()).first)
        #expect(fetched.imageData == imageData)
        #expect(fetched.excursions == excursions)
        #expect(fetched.excursionsRaw == "Stadtrundfahrt, Hafenrundfahrt")
    }

    @Test("Bestehender Hafen: Bearbeiten überschreibt Bild + Ausflüge wie im Formular")
    @MainActor
    func editingPortOverwritesImageAndExcursions() throws {
        let container = try makeInMemoryContainer()
        let context = container.mainContext

        let cruise = Cruise(title: "Test", startDate: makeDate("2026-03-01"), endDate: makeDate("2026-03-10"), shippingLine: "MSC", ship: "Bellissima")
        context.insert(cruise)

        let port = CruisePort(name: "Hamburg", country: "Deutschland", latitude: 53.5, longitude: 9.9)
        port.excursionsRaw = "Alter Ausflug"
        port.imageData = Data([0x01])
        port.cruise = cruise
        context.insert(port)
        try context.save()

        // Spiegelt PortFormView.savePort() im Edit-Pfad.
        let newImageData = Data([0xFF, 0xEE])
        port.imageData = newImageData
        port.excursions = ["Neuer Ausflug"]
        try context.save()

        let fetched = try #require(try context.fetch(FetchDescriptor<CruisePort>()).first)
        #expect(fetched.imageData == newImageData)
        #expect(fetched.excursions == ["Neuer Ausflug"])
    }

    @Test("Entfernen: Bild auf nil und Ausflüge auf leer setzen löscht beide Felder")
    @MainActor
    func removingImageAndExcursionsClearsFields() throws {
        let container = try makeInMemoryContainer()
        let context = container.mainContext

        let cruise = Cruise(title: "Test", startDate: makeDate("2026-03-01"), endDate: makeDate("2026-03-10"), shippingLine: "MSC", ship: "Bellissima")
        context.insert(cruise)

        let port = CruisePort(name: "Hamburg", country: "Deutschland", latitude: 53.5, longitude: 9.9)
        port.excursionsRaw = "Stadtrundfahrt"
        port.imageData = Data([0x01])
        port.cruise = cruise
        context.insert(port)
        try context.save()

        port.imageData = nil
        port.excursions = []
        try context.save()

        let fetched = try #require(try context.fetch(FetchDescriptor<CruisePort>()).first)
        #expect(fetched.imageData == nil)
        #expect(fetched.excursions.isEmpty)
        #expect(fetched.excursionsRaw == "")
    }
}
