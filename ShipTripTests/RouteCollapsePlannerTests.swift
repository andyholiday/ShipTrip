//
//  RouteCollapsePlannerTests.swift
//  ShipTripTests
//
//  Tests fuer die Klapp-Zustandsmaschine des Route-Abschnitts (Contract J3neu (b)):
//  Reisephase, Automatik-Defaults inkl. Fallback und manuelle Uebersteuerung.
//

import Testing
import Foundation
@testable import ShipTrip

/// Reise 10.–14.06.2026 mit einem Stopp pro Tag.
private struct CruiseFixture {
    let startDate = routeLocalDate(2026, 6, 10)
    let endDate = routeLocalDate(2026, 6, 14)
    let stops: [RouteStopInput] = (10...14).enumerated().map { index, day in
        makeRouteStop(sortOrder: index, arrival: routeLocalDate(2026, 6, day))
    }

    func defaults(today: Date) -> RouteCollapseDefaults {
        RouteCollapseDefaults.make(
            stops: stops,
            today: today,
            startDate: startDate,
            endDate: endDate,
            calendar: routeTestCalendar
        )
    }

    func stop(day: Int) -> RouteStopInput {
        stops[day - 10]
    }
}

// MARK: - Reisephase

@Suite("CruisePhase.phase — Reisephase als Tag-Tripel (J3neu (b))")
struct CruisePhaseTests {

    private let fixture = CruiseFixture()

    @Test("Tag vor dem Starttag ist „vor Reisebeginn“")
    func beforeStart() {
        let phase = CruisePhase.phase(
            today: routeLocalDate(2026, 6, 9),
            startDate: fixture.startDate,
            endDate: fixture.endDate,
            calendar: routeTestCalendar
        )
        #expect(phase == .beforeStart)
    }

    @Test("Der Starttag selbst ist bereits „aktiv“ (Grenze inklusive)")
    func startDayIsActive() {
        let phase = CruisePhase.phase(
            today: routeLocalDate(2026, 6, 10, hour: 23),
            startDate: fixture.startDate,
            endDate: fixture.endDate,
            calendar: routeTestCalendar
        )
        #expect(phase == .active)
    }

    @Test("Der Endtag selbst ist noch „aktiv“ (Grenze inklusive)")
    func endDayIsActive() {
        let phase = CruisePhase.phase(
            today: routeLocalDate(2026, 6, 14, hour: 1),
            startDate: fixture.startDate,
            endDate: fixture.endDate,
            calendar: routeTestCalendar
        )
        #expect(phase == .active)
    }

    @Test("Tag nach dem Endtag ist „nach Reiseende“")
    func afterEnd() {
        let phase = CruisePhase.phase(
            today: routeLocalDate(2026, 6, 15),
            startDate: fixture.startDate,
            endDate: fixture.endDate,
            calendar: routeTestCalendar
        )
        #expect(phase == .afterEnd)
    }

    @Test("Die Uhrzeit spielt keine Rolle — nur das Tag-Tripel zaehlt")
    func timeOfDayIsIrrelevant() {
        let earlyMorning = CruisePhase.phase(
            today: routeLocalDate(2026, 6, 10, hour: 0),
            startDate: fixture.startDate,
            endDate: fixture.endDate,
            calendar: routeTestCalendar
        )
        #expect(earlyMorning == .active)
    }
}

// MARK: - Automatik-Defaults

@Suite("RouteCollapseDefaults.make — Automatik-Defaults (J3neu (b))")
struct RouteCollapseDefaultsTests {

    private let fixture = CruiseFixture()

    @Test("Vor Reisebeginn sind alle Stopps aufgeklappt")
    func allExpandedBeforeStart() {
        let defaults = fixture.defaults(today: routeLocalDate(2026, 6, 1))
        #expect(defaults.phase == .beforeStart)
        #expect(defaults.expandedStopIDs == Set(fixture.stops.map(\.id)))
    }

    @Test("Nach Reiseende sind alle Stopps aufgeklappt")
    func allExpandedAfterEnd() {
        let defaults = fixture.defaults(today: routeLocalDate(2026, 7, 1))
        #expect(defaults.phase == .afterEnd)
        #expect(defaults.expandedStopIDs == Set(fixture.stops.map(\.id)))
    }

    @Test("Aktiv: nur der Stopp des heutigen Tages ist aufgeklappt")
    func onlyTodayExpandedWhileActive() {
        let defaults = fixture.defaults(today: routeLocalDate(2026, 6, 12, hour: 15))
        #expect(defaults.phase == .active)
        #expect(defaults.expandedStopIDs == [fixture.stop(day: 12).id])
        #expect(defaults.isExpandedByDefault(stopID: fixture.stop(day: 12).id))
        #expect(!defaults.isExpandedByDefault(stopID: fixture.stop(day: 11).id))
        #expect(!defaults.isExpandedByDefault(stopID: fixture.stop(day: 13).id))
    }

    @Test("Aktiv: liegen zwei Stopps auf dem heutigen Tag, sind beide aufgeklappt")
    func bothStopsOfTodayExpanded() {
        let today = routeLocalDate(2026, 6, 12)
        let morning = makeRouteStop(sortOrder: 0, arrival: routeLocalDate(2026, 6, 12, hour: 8))
        let evening = makeRouteStop(sortOrder: 1, arrival: routeLocalDate(2026, 6, 12, hour: 18))
        let other = makeRouteStop(sortOrder: 2, arrival: routeLocalDate(2026, 6, 13))

        let defaults = RouteCollapseDefaults.make(
            stops: [morning, evening, other],
            today: today,
            startDate: routeLocalDate(2026, 6, 10),
            endDate: routeLocalDate(2026, 6, 14),
            calendar: routeTestCalendar
        )

        #expect(defaults.expandedStopIDs == [morning.id, evening.id])
    }

    @Test("Fallback: aktiver Tag ohne Route-Stopp laesst alles zugeklappt")
    func activeDayWithoutStopKeepsEverythingCollapsed() {
        // Luecke in der Route: der 12. hat keinen Stopp.
        let stops = [
            makeRouteStop(sortOrder: 0, arrival: routeLocalDate(2026, 6, 10)),
            makeRouteStop(sortOrder: 1, arrival: routeLocalDate(2026, 6, 11)),
            makeRouteStop(sortOrder: 2, arrival: routeLocalDate(2026, 6, 13))
        ]
        let defaults = RouteCollapseDefaults.make(
            stops: stops,
            today: routeLocalDate(2026, 6, 12),
            startDate: routeLocalDate(2026, 6, 10),
            endDate: routeLocalDate(2026, 6, 14),
            calendar: routeTestCalendar
        )

        #expect(defaults.phase == .active)
        #expect(defaults.expandedStopIDs.isEmpty)
        for stop in stops {
            #expect(!defaults.isExpandedByDefault(stopID: stop.id))
        }
    }

    @Test("Leere Route liefert leere Defaults in jeder Phase")
    func emptyRouteHasEmptyDefaults() {
        for today in [routeLocalDate(2026, 6, 1), routeLocalDate(2026, 6, 12), routeLocalDate(2026, 7, 1)] {
            let defaults = RouteCollapseDefaults.make(
                stops: [],
                today: today,
                startDate: routeLocalDate(2026, 6, 10),
                endDate: routeLocalDate(2026, 6, 14),
                calendar: routeTestCalendar
            )
            #expect(defaults.expandedStopIDs.isEmpty)
        }
    }

    @Test("Tageswechsel: neu berechnete Defaults oeffnen den neuen aktiven Tag")
    func defaultsFollowTheDayChange() {
        let before = fixture.defaults(today: routeLocalDate(2026, 6, 12, hour: 23))
        let after = fixture.defaults(today: routeLocalDate(2026, 6, 13, hour: 0))

        #expect(before.expandedStopIDs == [fixture.stop(day: 12).id])
        #expect(after.expandedStopIDs == [fixture.stop(day: 13).id])
    }
}

// MARK: - Manuelle Uebersteuerung

@Suite("RouteCollapseState — manuelle Uebersteuerung (J3neu (b))")
struct RouteCollapseStateTests {

    private let fixture = CruiseFixture()

    @Test("Ohne Uebersteuerung gilt der Automatik-Default")
    func fallsBackToDefault() {
        let defaults = fixture.defaults(today: routeLocalDate(2026, 6, 12))
        let state = RouteCollapseState()

        #expect(state.isExpanded(stopID: fixture.stop(day: 12).id, defaults: defaults))
        #expect(!state.isExpanded(stopID: fixture.stop(day: 11).id, defaults: defaults))
    }

    @Test("Tippen negiert den effektiven Zustand — zugeklappter Stopp geht auf")
    func toggleOpensCollapsedStop() {
        let defaults = fixture.defaults(today: routeLocalDate(2026, 6, 12))
        var state = RouteCollapseState()
        let yesterday = fixture.stop(day: 11).id

        state.toggle(stopID: yesterday, defaults: defaults)

        #expect(state.isExpanded(stopID: yesterday, defaults: defaults))
    }

    @Test("Tippen negiert den effektiven Zustand — heutiger Stopp geht zu")
    func toggleClosesExpandedStop() {
        let defaults = fixture.defaults(today: routeLocalDate(2026, 6, 12))
        var state = RouteCollapseState()
        let today = fixture.stop(day: 12).id

        state.toggle(stopID: today, defaults: defaults)

        #expect(!state.isExpanded(stopID: today, defaults: defaults))
    }

    @Test("Zweimal tippen fuehrt zurueck zum Ausgangszustand")
    func doubleToggleReturnsToStart() {
        let defaults = fixture.defaults(today: routeLocalDate(2026, 6, 12))
        var state = RouteCollapseState()
        let stopID = fixture.stop(day: 11).id

        state.toggle(stopID: stopID, defaults: defaults)
        state.toggle(stopID: stopID, defaults: defaults)

        #expect(state.isExpanded(stopID: stopID, defaults: defaults) == false)
    }

    @Test("Eine Uebersteuerung wirkt nur auf ihren eigenen Stopp")
    func toggleIsScopedToOneStop() {
        let defaults = fixture.defaults(today: routeLocalDate(2026, 6, 12))
        var state = RouteCollapseState()

        state.toggle(stopID: fixture.stop(day: 11).id, defaults: defaults)

        #expect(!state.isExpanded(stopID: fixture.stop(day: 13).id, defaults: defaults))
        #expect(state.isExpanded(stopID: fixture.stop(day: 12).id, defaults: defaults))
    }

    @Test("„Alle aufklappen“ oeffnet auch in der aktiven Phase jeden Stopp")
    func expandAllOpensEveryStop() {
        let defaults = fixture.defaults(today: routeLocalDate(2026, 6, 12))
        var state = RouteCollapseState()

        state.expandAll(stopIDs: fixture.stops.map(\.id))

        for stop in fixture.stops {
            #expect(state.isExpanded(stopID: stop.id, defaults: defaults))
        }
    }

    @Test("„Alle zuklappen“ schliesst auch den heutigen Stopp")
    func collapseAllClosesEveryStop() {
        let defaults = fixture.defaults(today: routeLocalDate(2026, 6, 12))
        var state = RouteCollapseState()

        state.collapseAll(stopIDs: fixture.stops.map(\.id))

        for stop in fixture.stops {
            #expect(!state.isExpanded(stopID: stop.id, defaults: defaults))
        }
    }

    @Test("Tageswechsel loescht alle Uebersteuerungen — der neue aktive Tag geht auf")
    func dayChangeClearsOverrides() {
        var state = RouteCollapseState()
        let yesterdayDefaults = fixture.defaults(today: routeLocalDate(2026, 6, 12, hour: 23))

        // Gestern hat der User den 13. zugeklappt gehalten bzw. alles zugeklappt.
        state.collapseAll(stopIDs: fixture.stops.map(\.id))
        #expect(!state.isExpanded(stopID: fixture.stop(day: 12).id, defaults: yesterdayDefaults))

        state.resetForDayChange()
        let todayDefaults = fixture.defaults(today: routeLocalDate(2026, 6, 13, hour: 0))

        #expect(state.isExpanded(stopID: fixture.stop(day: 13).id, defaults: todayDefaults))
        #expect(!state.isExpanded(stopID: fixture.stop(day: 12).id, defaults: todayDefaults))
    }

    @Test("Ein frischer Zustand ist gleich einem zurueckgesetzten Zustand")
    func resetEqualsFreshState() {
        var state = RouteCollapseState()
        state.expandAll(stopIDs: fixture.stops.map(\.id))
        state.resetForDayChange()

        #expect(state == RouteCollapseState())
    }
}
