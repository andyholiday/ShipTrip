//
//  CalendarSyncPlannerTests.swift
//  ShipTripTests
//

import Testing
import Foundation
@testable import ShipTrip

@Suite("Kalender-Synchronisation")
@MainActor
struct CalendarSyncPlannerTests {

    private var utcCalendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        return calendar
    }

    private func date(_ year: Int, _ month: Int, _ day: Int, _ hour: Int = 0) -> Date {
        utcCalendar.date(from: DateComponents(
            timeZone: utcCalendar.timeZone,
            year: year,
            month: month,
            day: day,
            hour: hour
        ))!
    }

    @Test("Nur-Reise-Modus erzeugt genau einen inklusiven Ganztagstermin")
    func tripOnlyCreatesOneAllDayEvent() throws {
        let cruise = Cruise(
            title: "Mittelmeer",
            startDate: date(2026, 8, 1),
            endDate: date(2026, 8, 7),
            shippingLine: "AIDA Cruises",
            ship: "AIDAstella"
        )

        let drafts = CalendarEventPlanner.makeDrafts(
            for: cruise,
            mode: .tripOnly,
            calendar: utcCalendar
        )

        let event = try #require(drafts.only)
        #expect(event.isAllDay)
        #expect(event.startDate == date(2026, 8, 1))
        #expect(event.endDate == date(2026, 8, 8))
        #expect(event.title.contains("Mittelmeer"))
        #expect(event.stableKey == "cruise/\(cruise.id.uuidString)/trip")
    }

    @Test("Detailmodus ergänzt Häfen und benennt Seetage mit den Nachbarhäfen")
    func itineraryModeCreatesRouteEvents() throws {
        let cruise = Cruise(
            title: "Inselhopping",
            startDate: date(2026, 9, 1),
            endDate: date(2026, 9, 4),
            shippingLine: "MSC",
            ship: "MSC World Europa"
        )

        let barcelona = Port(name: "Barcelona", country: "Spanien", latitude: 41.4, longitude: 2.2)
        barcelona.arrival = date(2026, 9, 1, 8)
        barcelona.departure = date(2026, 9, 1, 18)
        barcelona.sortOrder = 0

        let seaDay = Port(name: "Seetag", country: "", latitude: 0, longitude: 0)
        seaDay.arrival = date(2026, 9, 2)
        seaDay.departure = date(2026, 9, 2)
        seaDay.sortOrder = 1
        seaDay.isSeaDay = true

        let palma = Port(name: "Palma", country: "Spanien", latitude: 39.6, longitude: 2.6)
        palma.arrival = date(2026, 9, 3, 7)
        palma.departure = date(2026, 9, 3, 16)
        palma.sortOrder = 2

        cruise.route = [barcelona, seaDay, palma]

        let drafts = CalendarEventPlanner.makeDrafts(
            for: cruise,
            mode: .tripAndItinerary,
            calendar: utcCalendar
        )

        #expect(drafts.count == 4)
        #expect(Set(drafts.map(\.stableKey)).count == drafts.count)

        let seaDayEvent = try #require(
            drafts.first { $0.stableKey == "cruise/\(cruise.id.uuidString)/route/\(seaDay.id.uuidString)" }
        )
        #expect(seaDayEvent.isAllDay)
        #expect(seaDayEvent.title.contains("Barcelona"))
        #expect(seaDayEvent.title.contains("Palma"))

        let portEvent = try #require(
            drafts.first { $0.stableKey == "cruise/\(cruise.id.uuidString)/route/\(barcelona.id.uuidString)" }
        )
        #expect(!portEvent.isAllDay)
        #expect(portEvent.location == "Barcelona, Spanien")
        #expect(portEvent.startDate == date(2026, 9, 1, 8))
        #expect(portEvent.endDate == date(2026, 9, 1, 18))
    }

    // MARK: - Umfang (1.8.7)

    @Test("Nur-Stopps-Modus lässt den Ganzreise-Termin weg")
    func itineraryOnlyOmitsTripDraft() {
        let cruise = sampleCruise()

        let drafts = CalendarEventPlanner.makeDrafts(
            for: cruise,
            mode: .itineraryOnly,
            calendar: utcCalendar
        )

        #expect(drafts.count == cruise.route.count)
        #expect(!drafts.contains { $0.stableKey.hasSuffix("/trip") })
    }

    @Test("Ohne beide Schalter entsteht kein einziger Termin")
    func noneCreatesNoDrafts() {
        let drafts = CalendarEventPlanner.makeDrafts(
            for: sampleCruise(),
            mode: .none,
            calendar: utcCalendar
        )

        #expect(drafts.isEmpty)
    }

    // MARK: - Anklickbarer Ort (1.8.7)

    @Test("Nur Häfen mit gepflegten Koordinaten tragen eine Koordinate")
    func coordinateIsSetOnlyForPortsWithCoordinates() throws {
        let cruise = sampleCruise()
        let route = cruise.route.sorted { $0.sortOrder < $1.sortOrder }

        let drafts = CalendarEventPlanner.makeDrafts(
            for: cruise,
            mode: .tripAndItinerary,
            calendar: utcCalendar
        )

        let portDraft = try #require(draft(drafts, for: route[0]))
        let coordinate = try #require(portDraft.coordinate)
        #expect(coordinate.latitude == 38.7)
        #expect(coordinate.longitude == -9.1)

        let seaDayDraft = try #require(draft(drafts, for: route[1]))
        #expect(seaDayDraft.coordinate == nil)

        // Null-Insel: Hafen ohne gepflegte Koordinaten fällt auf den Text zurück.
        let nullIslandDraft = try #require(draft(drafts, for: route[2]))
        #expect(nullIslandDraft.coordinate == nil)
        #expect(nullIslandDraft.location == "Privathafen, Bahamas")

        let tripDraft = try #require(drafts.first { $0.stableKey.hasSuffix("/trip") })
        #expect(tripDraft.coordinate == nil)
    }

    // MARK: - Hilfen

    /// Reise mit einem Hafen mit Koordinaten, einem Seetag und einem Hafen
    /// ohne gepflegte Koordinaten.
    private func sampleCruise() -> Cruise {
        let cruise = Cruise(
            title: "Atlantik",
            startDate: date(2026, 10, 1),
            endDate: date(2026, 10, 3),
            shippingLine: "TUI Cruises",
            ship: "Mein Schiff 7"
        )

        let lisbon = Port(name: "Lissabon", country: "Portugal", latitude: 38.7, longitude: -9.1)
        lisbon.arrival = date(2026, 10, 1, 8)
        lisbon.departure = date(2026, 10, 1, 18)
        lisbon.sortOrder = 0

        let seaDay = Port(name: "Seetag", country: "", latitude: 0, longitude: 0)
        seaDay.arrival = date(2026, 10, 2)
        seaDay.departure = date(2026, 10, 2)
        seaDay.sortOrder = 1
        seaDay.isSeaDay = true

        let unknown = Port(name: "Privathafen", country: "Bahamas", latitude: 0, longitude: 0)
        unknown.arrival = date(2026, 10, 3, 9)
        unknown.departure = date(2026, 10, 3, 17)
        unknown.sortOrder = 2

        cruise.route = [lisbon, seaDay, unknown]
        return cruise
    }

    private func draft(_ drafts: [CalendarEventDraft], for port: Port) -> CalendarEventDraft? {
        drafts.first { $0.stableKey.hasSuffix("/route/\(port.id.uuidString)") }
    }
}

private extension Array {
    var only: Element? {
        count == 1 ? self[0] : nil
    }
}
