//
//  RouteJournalRowPresentationTests.swift
//  ShipTripTests
//
//  Reine Anzeige-Logik der Eintragszeile (T8b): Stimmungs-Abbildung nach J4 inkl.
//  Unknown-Preservation, Datums-Sichtbarkeit und GMT-feste Datums-Formatierung
//  nach dem Zeitzonen-Vertrag. Die Zuordnungs- und Klapp-Semantik selbst deckt
//  T8a ab (RouteJournalPlannerTests / RouteCollapsePlannerTests).
//

import Testing
import Foundation
@testable import ShipTrip

// MARK: - RouteJournalMood (Contract J4 + moodRaw-Stabilitätsvertrag)

@Suite("RouteJournalMood")
struct RouteJournalMoodTests {

    @Test("Die fünf bekannten Rohwerte bilden auf ihr J4-Emoji ab")
    func knownRawValuesMapToEmoji() {
        let expected: [(String, String)] = [
            ("great", "🤩"), ("good", "🙂"), ("okay", "😐"), ("bad", "🙁"), ("awful", "😢")
        ]
        for (rawValue, emoji) in expected {
            #expect(RouteJournalMood.known(rawValue: rawValue)?.emoji == emoji)
        }
    }

    @Test("Jede Stimmung hat ein nicht-leeres Label für VoiceOver")
    func everyMoodHasALabel() {
        let emptyLabels = RouteJournalMood.allCases.filter { $0.label.isEmpty }
        #expect(emptyLabels.isEmpty)
    }

    @Test("Leerer Rohwert heißt „keine Stimmung“ — kein Emoji")
    func emptyRawValueHasNoMood() {
        #expect(RouteJournalMood.known(rawValue: "") == nil)
    }

    @Test("Unknown-Preservation: unbekannter Rohwert zeigt keine Stimmung, kein Fallback-Emoji")
    func unknownRawValueHasNoMood() {
        #expect(RouteJournalMood.known(rawValue: "ecstatic") == nil)
        #expect(RouteJournalMood.known(rawValue: "GREAT") == nil)
    }
}

// MARK: - Datums-Sichtbarkeit und -Formatierung (Contract J3neu (c))

@Suite("RouteJournalEntryRow")
@MainActor
struct RouteJournalEntryRowTests {

    @Test("Eintrag am Ankunftstag des Stopps: kein redundantes Datum in der Zeile")
    func hidesDateOnStopArrivalDay() {
        let showsDate = RouteJournalEntryRow.showsDate(
            entryDate: routeEntryDay(2026, 8, 14),
            stopArrival: routeLocalDate(2026, 8, 14),
            calendar: routeTestCalendar
        )
        #expect(showsDate == false)
    }

    @Test("Umdatierter Eintrag mit Hafen-Bezug: Zeile zeigt ihr eigenes Datum")
    func showsDateWhenEntryDayDiffersFromStop() {
        let showsDate = RouteJournalEntryRow.showsDate(
            entryDate: routeEntryDay(2026, 8, 16),
            stopArrival: routeLocalDate(2026, 8, 14),
            calendar: routeTestCalendar
        )
        #expect(showsDate == true)
    }

    @Test("Tag-Tripel-Vergleich: späte Ankunft am selben Kalendertag zeigt kein Datum")
    func lateArrivalOnSameDayStillCountsAsSameDay() {
        let showsDate = RouteJournalEntryRow.showsDate(
            entryDate: routeEntryDay(2026, 8, 14),
            stopArrival: routeLocalDate(2026, 8, 14, hour: 23),
            calendar: routeTestCalendar
        )
        #expect(showsDate == false)
    }

    @Test("Datums-Text liest den Date-only-Wert in GMT — nicht in der Gerätezone")
    func dayTextUsesUTCDayOfEntryDate() {
        // 12:00 UTC am 14.08. ist in Kiritimati (UTC+14) bereits der 15.08.;
        // die Zeile muss trotzdem den gespeicherten Tag zeigen.
        let text = RouteJournalEntryRow.dayText(
            for: routeEntryDay(2026, 8, 14),
            locale: Locale(identifier: "de_DE")
        )
        #expect(text.contains("14"))
        #expect(text.contains("2026"))
    }
}
