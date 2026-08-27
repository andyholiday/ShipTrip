//
//  JournalEditorDefaultsTests.swift
//  ShipTripTests
//
//  Tests fuer die Default-Regeln von Schritt 2 „Eckdaten"
//  (ADR-003, Contract J2 / J3neu (d)).
//

import Testing
import Foundation
@testable import ShipTrip

/// Geraete-Kalender bei UTC+14 — dort faellt 12:00 UTC bereits auf den
/// **naechsten** lokalen Tag. Genau der Fall, an dem eine lokale Tag-Extraktion
/// den Eintrag um einen Tag verschoebe.
private let farEastCalendar: Calendar = {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(identifier: "Pacific/Kiritimati") ?? .gmt
    return calendar
}()

// MARK: - Tag-Default

@Suite("JournalEditorDefaults.localDay — Datums-Default (J2 Schritt 2)")
struct JournalEditorDefaultsLocalDayTests {

    private let start = routeLocalDate(2026, 6, 1, hour: 18)
    private let end = routeLocalDate(2026, 6, 8, hour: 9)

    @Test("Vorbelegter Stopp-Tag schlaegt den heutigen Tag")
    func prefillWins() {
        let stopDay = routeLocalDate(2026, 6, 4, hour: 7)
        let today = routeLocalDate(2026, 6, 6, hour: 20)

        let result = JournalEditorDefaults.localDay(
            prefill: stopDay, today: today,
            cruiseStart: start, cruiseEnd: end, calendar: routeTestCalendar
        )

        #expect(RouteDayKey.localDay(result, calendar: routeTestCalendar)
                == RouteDayKey.localDay(stopDay, calendar: routeTestCalendar))
    }

    @Test("Ohne Vorbelegung gilt heute, wenn es im Reisezeitraum liegt")
    func todayInsideRange() {
        let today = routeLocalDate(2026, 6, 6, hour: 20)

        let result = JournalEditorDefaults.localDay(
            prefill: nil, today: today,
            cruiseStart: start, cruiseEnd: end, calendar: routeTestCalendar
        )

        #expect(result == today)
    }

    @Test("Vor der Reise wird auf den Starttag geklemmt")
    func clampsBeforeStart() {
        let today = routeLocalDate(2026, 5, 20)

        let result = JournalEditorDefaults.localDay(
            prefill: nil, today: today,
            cruiseStart: start, cruiseEnd: end, calendar: routeTestCalendar
        )

        #expect(result == start)
    }

    @Test("Nach der Reise wird auf den Endtag geklemmt")
    func clampsAfterEnd() {
        let today = routeLocalDate(2026, 7, 1)

        let result = JournalEditorDefaults.localDay(
            prefill: nil, today: today,
            cruiseStart: start, cruiseEnd: end, calendar: routeTestCalendar
        )

        #expect(result == end)
    }

    @Test("Der spaete Abend des Starttags gilt als im Zeitraum (Tag-Tripel, nicht Zeitstempel)")
    func lateEveningOfStartDayCounts() {
        let today = routeLocalDate(2026, 6, 1, hour: 23)

        let result = JournalEditorDefaults.localDay(
            prefill: nil, today: today,
            cruiseStart: start, cruiseEnd: end, calendar: routeTestCalendar
        )

        #expect(result == today)
    }

    @Test("Widerspruechliche Reisedaten (Ende vor Beginn) fallen auf den Starttag")
    func brokenRangeFallsBackToStart() {
        let result = JournalEditorDefaults.localDay(
            prefill: nil, today: routeLocalDate(2026, 6, 5),
            cruiseStart: start, cruiseEnd: routeLocalDate(2026, 5, 1),
            calendar: routeTestCalendar
        )

        #expect(result == start)
    }
}

// MARK: - Rueckweg fuer den Picker

@Suite("JournalEditorDefaults.localDay(ofEntryDate:) — Rueckweg des Zeitzonen-Vertrags")
struct JournalEditorDefaultsEntryDateRoundtripTests {

    @Test("Bei UTC+14 bleibt der gespeicherte Tag beim Durchwinken erhalten")
    func roundtripSurvivesFarEastOffset() {
        let stored = routeEntryDay(2026, 6, 1)

        let pickerValue = JournalEditorDefaults
            .localDay(ofEntryDate: stored, calendar: farEastCalendar)
        let resaved = JournalDay
            .normalizedEntryDate(forLocalDay: pickerValue, calendar: farEastCalendar)

        #expect(RouteDayKey.localDay(pickerValue, calendar: farEastCalendar)
                == RouteDayKey.entryDay(stored))
        #expect(resaved == stored)
    }

    @Test("Im Geraete-Kalender der Tests ist der Rueckweg ebenfalls verlustfrei")
    func roundtripInDeviceCalendar() {
        let stored = routeEntryDay(2026, 6, 4)

        let pickerValue = JournalEditorDefaults
            .localDay(ofEntryDate: stored, calendar: routeTestCalendar)
        let resaved = JournalDay
            .normalizedEntryDate(forLocalDay: pickerValue, calendar: routeTestCalendar)

        #expect(resaved == stored)
    }
}

// MARK: - Auswahlbereich

@Suite("JournalEditorDefaults.dayRange — Grenzen des Datums-Pickers")
struct JournalEditorDefaultsDayRangeTests {

    @Test("Start- und Endtag liegen vollstaendig im Bereich")
    func rangeCoversBothEdgeDays() {
        let start = routeLocalDate(2026, 6, 1, hour: 18)
        let end = routeLocalDate(2026, 6, 8, hour: 9)

        let range = JournalEditorDefaults.dayRange(
            cruiseStart: start, cruiseEnd: end, calendar: routeTestCalendar
        )

        #expect(range.contains(routeLocalDate(2026, 6, 1, hour: 0)))
        #expect(range.contains(routeLocalDate(2026, 6, 8, hour: 23)))
        #expect(!range.contains(routeLocalDate(2026, 5, 31, hour: 23)))
        #expect(!range.contains(routeLocalDate(2026, 6, 9, hour: 0)))
    }

    @Test("Widerspruechliche Reisedaten ergeben einen gueltigen (entarteten) Bereich")
    func brokenRangeStaysValid() {
        let range = JournalEditorDefaults.dayRange(
            cruiseStart: routeLocalDate(2026, 6, 8),
            cruiseEnd: routeLocalDate(2026, 6, 1),
            calendar: routeTestCalendar
        )

        #expect(range.lowerBound <= range.upperBound)
    }
}

// MARK: - Hafen-Default

@Suite("JournalEditorDefaults.portID — Hafen-Default (J2 Schritt 2)")
struct JournalEditorDefaultsPortTests {

    @Test("Erster Stopp des Tages nach sortOrder, nicht nach Listenreihenfolge")
    func firstStopOfDayWins() {
        let day = routeLocalDate(2026, 6, 3, hour: 8)
        let second = makeRouteStop(sortOrder: 5, arrival: routeLocalDate(2026, 6, 3, hour: 14))
        let first = makeRouteStop(sortOrder: 4, arrival: routeLocalDate(2026, 6, 3, hour: 7))

        let result = JournalEditorDefaults.portID(
            forLocalDay: day, stops: [second, first], calendar: routeTestCalendar
        )

        #expect(result == first.id)
    }

    @Test("Seetage sind normale Stopps und werden vorbelegt")
    func seaDayIsSelectable() {
        let seaDay = makeRouteStop(sortOrder: 2, arrival: routeLocalDate(2026, 6, 5, hour: 0))

        let result = JournalEditorDefaults.portID(
            forLocalDay: routeLocalDate(2026, 6, 5, hour: 19),
            stops: [seaDay],
            calendar: routeTestCalendar
        )

        #expect(result == seaDay.id)
    }

    @Test("Tag ohne Route-Stopp ergibt keinen Hafen")
    func dayWithoutStop() {
        let stop = makeRouteStop(sortOrder: 0, arrival: routeLocalDate(2026, 6, 1))

        let result = JournalEditorDefaults.portID(
            forLocalDay: routeLocalDate(2026, 6, 2), stops: [stop], calendar: routeTestCalendar
        )

        #expect(result == nil)
    }
}
