//
//  RouteJournalRowPresentationTests.swift
//  ShipTripTests
//
//  Reine Anzeige-Logik der Eintragszeile (T8b): Datums-Sichtbarkeit nach dem
//  Zeitzonen-Vertrag. Die Zuordnungs- und Klapp-Semantik deckt T8a ab
//  (RouteJournalPlannerTests / RouteCollapsePlannerTests); die Stimmungs-
//  Abbildung nach J4 und der GMT-feste Datums-Text sind seit T8d-1 nur noch
//  einmal da und liegen in JournalMoodTests bzw. JournalEntryDayDisplayTests.
//

import Testing
import Foundation
@testable import ShipTrip

// MARK: - Datums-Sichtbarkeit (Contract J3neu (c))

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
}
