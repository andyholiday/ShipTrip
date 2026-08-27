//
//  JournalEntryDayDisplayTests.swift
//  ShipTripTests
//
//  Tests fuer Reisetag-Nummer und Datums-Text der Detailansicht
//  (ADR-003 Zeitzonen-Vertrag, Contract J1/J3neu (c)).
//

import Testing
import Foundation
@testable import ShipTrip

@Suite("JournalEntryDayDisplay.tripDayNumber — Reisetag-Nummer (J1)")
struct JournalEntryDayDisplayTripDayTests {

    @Test("Der Starttag ist Tag 1")
    func startDayIsDayOne() {
        let result = JournalEntryDayDisplay.tripDayNumber(
            entryDate: routeEntryDay(2026, 6, 1),
            cruiseStart: routeLocalDate(2026, 6, 1, hour: 18),
            calendar: routeTestCalendar
        )

        #expect(result == 1)
    }

    @Test("Zwei Kalendertage spaeter ist Tag 3")
    func twoDaysLaterIsDayThree() {
        let result = JournalEntryDayDisplay.tripDayNumber(
            entryDate: routeEntryDay(2026, 6, 3),
            cruiseStart: routeLocalDate(2026, 6, 1, hour: 18),
            calendar: routeTestCalendar
        )

        #expect(result == 3)
    }

    @Test("Spaeter Start-Zeitstempel verschiebt nichts (Tag-Tripel statt Differenz)")
    func lateStartTimestampDoesNotShift() {
        // Abfahrt 23:30 lokal, Eintrag am Folgetag: rohe Date-Differenz waere
        // unter 24 h und ergaebe faelschlich Tag 1.
        let result = JournalEntryDayDisplay.tripDayNumber(
            entryDate: routeEntryDay(2026, 6, 2),
            cruiseStart: routeLocalDate(2026, 6, 1, hour: 23),
            calendar: routeTestCalendar
        )

        #expect(result == 2)
    }

    @Test("Ueber den Monatswechsel hinweg zaehlt der Kalender, nicht die Stundenzahl")
    func countsAcrossMonthBoundary() {
        let result = JournalEntryDayDisplay.tripDayNumber(
            entryDate: routeEntryDay(2026, 7, 2),
            cruiseStart: routeLocalDate(2026, 6, 28, hour: 16),
            calendar: routeTestCalendar
        )

        #expect(result == 5)
    }

    @Test("Ein Eintrag vor dem Starttag hat keinen Reisetag")
    func beforeStartHasNoNumber() {
        let result = JournalEntryDayDisplay.tripDayNumber(
            entryDate: routeEntryDay(2026, 5, 30),
            cruiseStart: routeLocalDate(2026, 6, 1),
            calendar: routeTestCalendar
        )

        #expect(result == nil)
    }
}

@Suite("JournalEntryDayDisplay.dayText — Datums-Text (Zeitzonen-Vertrag)")
struct JournalEntryDayDisplayDayTextTests {

    @Test("Der Text nennt den gespeicherten UTC-Tag, nicht den lokalen Nachbartag")
    func rendersStoredDayNotFarEastNeighbour() {
        let stored = routeEntryDay(2026, 6, 1)
        let farEastZone = TimeZone(secondsFromGMT: 14 * 3600) ?? .gmt
        // Bei UTC+14 liegt 12:00 UTC schon am 2. Juni — eine Anzeige in dieser
        // Zone muesste sich vom Vertrags-Text unterscheiden.
        let farEastText = stored.formatted(
            Date.FormatStyle(date: .numeric, time: .omitted, timeZone: farEastZone)
        )

        let text = JournalEntryDayDisplay.dayText(for: stored, style: .numeric)

        #expect(text != farEastText)
        #expect(!text.isEmpty)
    }
}
