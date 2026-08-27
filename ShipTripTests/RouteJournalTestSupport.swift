//
//  RouteJournalTestSupport.swift
//  ShipTripTests
//
//  Gemeinsame Fixture-Helfer der Route-Journal-Tests (ADR-003, Contract J3neu, T8a).
//

import Foundation
@testable import ShipTrip

/// Geraete-Kalender der Tests: fest auf Europe/Berlin, damit die Tag-Vergleiche
/// unabhaengig von der Umgebung des Testlaeufers reproduzierbar sind.
let routeTestCalendar: Calendar = {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(identifier: "Europe/Berlin") ?? .gmt
    return calendar
}()

/// Lokaler Ereignis-Zeitstempel (wie `port.arrival`, `cruise.startDate`).
func routeLocalDate(
    _ year: Int, _ month: Int, _ day: Int,
    hour: Int = 9,
    calendar: Calendar = routeTestCalendar
) -> Date {
    var components = DateComponents()
    components.year = year
    components.month = month
    components.day = day
    components.hour = hour
    return calendar.date(from: components) ?? Date(timeIntervalSince1970: 0)
}

/// `entryDate` in kanonischer Kodierung: 12:00 UTC des Tag-Tripels.
func routeEntryDay(_ year: Int, _ month: Int, _ day: Int) -> Date {
    var components = DateComponents()
    components.year = year
    components.month = month
    components.day = day
    return JournalDay.entryDate(fromDayComponents: components) ?? Date(timeIntervalSince1970: 0)
}

func makeRouteStop(sortOrder: Int, arrival: Date, id: UUID = UUID()) -> RouteStopInput {
    RouteStopInput(id: id, sortOrder: sortOrder, arrival: arrival)
}

func makeRouteEntry(
    portID: UUID? = nil,
    entryDate: Date,
    createdAt: Date = Date(timeIntervalSince1970: 1_780_000_000),
    id: UUID = UUID()
) -> JournalEntryInput {
    JournalEntryInput(id: id, portID: portID, entryDate: entryDate, createdAt: createdAt)
}
