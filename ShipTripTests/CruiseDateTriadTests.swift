//
//  CruiseDateTriadTests.swift
//  ShipTripTests
//

import Testing
import Foundation
@testable import ShipTrip

@Suite("Reisedauer — Kopplung von Start, Ende und Nächten")
struct CruiseDateTriadTests {

    /// Fester Kalender mit fester Zeitzone — Europe/Berlin, damit der
    /// Sommerzeitwechsel überhaupt geprüft werden kann.
    private var berlin: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Europe/Berlin")!
        return calendar
    }

    private func date(_ year: Int, _ month: Int, _ day: Int, _ hour: Int = 12) -> Date {
        berlin.date(from: DateComponents(
            timeZone: berlin.timeZone, year: year, month: month, day: day, hour: hour
        ))!
    }

    private func triad(_ start: Date, _ end: Date, stored: Int = 0) -> CruiseDateTriad {
        CruiseDateTriad(start: start, end: end, storedNights: stored, calendar: berlin)
    }

    @Test("Repro: Start um 3 Tage verschieben nimmt Ende und Nächte mit")
    func startShiftKeepsNightsAndMovesEnd() {
        let week = triad(date(2026, 8, 1), date(2026, 8, 8))
        #expect(week.nights == 7) // Backfill aus Start/Ende

        let moved = week.changingStart(to: date(2026, 8, 4), choice: .keepNights, calendar: berlin)
        #expect(moved.end == date(2026, 8, 11))
        #expect(moved.nights == 7)
    }

    @Test("Backfill: Nächte kommen immer aus Start und Ende")
    func backfillEnforcesInvariant() {
        // Unpassender gespeicherter Wert wird von der Invariante überschrieben.
        #expect(triad(date(2026, 8, 1), date(2026, 8, 8), stored: 3).nights == 7)
        // Ende vor Start ergibt nie negative Nächte.
        #expect(triad(date(2026, 8, 8), date(2026, 8, 1), stored: 5).nights == 0)
    }

    @Test("Start verschieben mit „Enddatum bleibt“ rechnet die Nächte neu")
    func startShiftKeepingEndRecalculatesNights() {
        let week = triad(date(2026, 8, 1), date(2026, 8, 8))
        let later = week.changingStart(to: date(2026, 8, 4), choice: .keepEnd, calendar: berlin)
        #expect(later.end == date(2026, 8, 8))
        #expect(later.nights == 4)

        // Neuer Start hinter dem Ende: Ende rutscht auf den Start, 0 Nächte.
        let beyond = week.changingStart(to: date(2026, 8, 10), choice: .keepEnd, calendar: berlin)
        #expect(beyond.end == date(2026, 8, 10))
        #expect(beyond.nights == 0)
    }

    @Test("Ende ändern zieht die Nächte ohne Rückfrage nach")
    func endChangeUpdatesNights() {
        let week = triad(date(2026, 8, 1), date(2026, 8, 8))
        #expect(week.changingEnd(to: date(2026, 8, 12), calendar: berlin).nights == 11)
        #expect(week.changingEnd(to: date(2026, 7, 30), calendar: berlin).nights == 0)
    }

    @Test("Nächte ändern verschiebt wahlweise Start oder Ende")
    func nightsChangeMovesChosenEdge() {
        let week = triad(date(2026, 8, 1), date(2026, 8, 8))
        let movedEnd = week.changingNights(to: 10, choice: .moveEnd, calendar: berlin)
        #expect(movedEnd.start == date(2026, 8, 1))
        #expect(movedEnd.end == date(2026, 8, 11))
        #expect(movedEnd.nights == 10)

        let movedStart = week.changingNights(to: 3, choice: .moveStart, calendar: berlin)
        #expect(movedStart.start == date(2026, 8, 5))
        #expect(movedStart.end == date(2026, 8, 8))
        #expect(movedStart.nights == 3)

        let clamped = week.changingNights(to: -2, choice: .moveEnd, calendar: berlin)
        #expect(clamped.end == date(2026, 8, 1))
        #expect(clamped.nights == 0)
    }

    @Test("Sommerzeitwechsel: Verschieben erhält die Uhrzeit, nicht die Stundenzahl")
    func daylightSavingShiftKeepsWallClockTime() {
        // 29.03.2026 ist der Beginn der Sommerzeit in Europe/Berlin.
        let before = date(2026, 3, 28, 8)
        let after = CruiseDateTriad.shifted(before, byDays: 2, calendar: berlin)
        #expect(after == date(2026, 3, 30, 8))
        #expect(after.timeIntervalSince(before) == 47 * 3600) // eine Stunde kürzer

        let stretched = triad(date(2026, 3, 27), date(2026, 3, 28))
            .changingNights(to: 4, choice: .moveEnd, calendar: berlin)
        #expect(stretched.end == date(2026, 3, 31))
        #expect(stretched.nights == 4)
    }

    @Test("Tagesspanne zählt Kalendertage, auch rückwärts")
    func dayShiftCountsCalendarDays() {
        let back = CruiseDateTriad.dayShift(
            from: date(2026, 8, 4), to: date(2026, 8, 1), calendar: berlin
        )
        #expect(back == -3)
        // Nur die Uhrzeit ändert sich — keine Verschiebung.
        let sameDay = CruiseDateTriad.dayShift(
            from: date(2026, 8, 4, 6), to: date(2026, 8, 4, 23), calendar: berlin
        )
        #expect(sameDay == 0)
    }

    @Test("Hafen-Dialog nur bei gefüllter Route und echter Verschiebung")
    func routePromptOnlyWhenSomethingChanges() {
        #expect(CruiseDateTriad.needsRouteShiftPrompt(routeIsEmpty: false, dayShift: 3))
        #expect(CruiseDateTriad.needsRouteShiftPrompt(routeIsEmpty: false, dayShift: -2))
        #expect(!CruiseDateTriad.needsRouteShiftPrompt(routeIsEmpty: false, dayShift: 0))
        #expect(!CruiseDateTriad.needsRouteShiftPrompt(routeIsEmpty: true, dayShift: 3))
    }
}
