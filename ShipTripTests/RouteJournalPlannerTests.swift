//
//  RouteJournalPlannerTests.swift
//  ShipTripTests
//
//  Tests fuer `RouteJournalPlanner` — Zuordnung Eintrag → Stopp inkl. aller
//  Randfaelle aus Contract J3neu (a).
//

import Testing
import Foundation
@testable import ShipTrip

// MARK: - Zuordnung

@Suite("RouteJournalPlanner.assign — Zuordnung Eintrag → Stopp (J3neu (a))")
struct RouteJournalPlannerAssignmentTests {

    @Test("Regel 1: Hafen-Bezug hat Vorrang vor dem Datum (umdatierter Eintrag)")
    func portReferenceBeatsDate() {
        let bergen = makeRouteStop(sortOrder: 0, arrival: routeLocalDate(2026, 6, 1))
        let tromsoe = makeRouteStop(sortOrder: 1, arrival: routeLocalDate(2026, 6, 2))
        // Eintrag traegt Bergen, ist aber auf den Tromsoe-Tag umdatiert.
        let entry = makeRouteEntry(portID: bergen.id, entryDate: routeEntryDay(2026, 6, 2))

        let result = RouteJournalPlanner.assign(
            entries: [entry], stops: [bergen, tromsoe], calendar: routeTestCalendar
        )

        #expect(result.entryIDs(forStopID: bergen.id) == [entry.id])
        #expect(result.entryIDs(forStopID: tromsoe.id).isEmpty)
        #expect(result.unassignedEntryIDs.isEmpty)
    }

    @Test("Regel 2: Hafenloser Eintrag landet beim Stopp mit passendem arrival-Tag")
    func portlessEntryMatchesArrivalDay() {
        let bergen = makeRouteStop(sortOrder: 0, arrival: routeLocalDate(2026, 6, 1))
        let tromsoe = makeRouteStop(sortOrder: 1, arrival: routeLocalDate(2026, 6, 2))
        let entry = makeRouteEntry(entryDate: routeEntryDay(2026, 6, 2))

        let result = RouteJournalPlanner.assign(
            entries: [entry], stops: [bergen, tromsoe], calendar: routeTestCalendar
        )

        #expect(result.entryIDs(forStopID: tromsoe.id) == [entry.id])
        #expect(result.entryIDs(forStopID: bergen.id).isEmpty)
    }

    @Test("Regel 3: bei zwei Stopps am selben Tag sammelt der erste (niedrigster sortOrder)")
    func portlessEntryGoesToFirstStopOfDay() {
        let sameDay = routeLocalDate(2026, 6, 3)
        // Absichtlich in verkehrter Reihenfolge uebergeben — sortOrder regiert, nicht die Liste.
        let second = makeRouteStop(sortOrder: 5, arrival: sameDay)
        let first = makeRouteStop(sortOrder: 4, arrival: sameDay)
        let entry = makeRouteEntry(entryDate: routeEntryDay(2026, 6, 3))

        let result = RouteJournalPlanner.assign(
            entries: [entry], stops: [second, first], calendar: routeTestCalendar
        )

        #expect(result.entryIDs(forStopID: first.id) == [entry.id])
        #expect(result.entryIDs(forStopID: second.id).isEmpty)
    }

    @Test("Regel 3: mit Hafen-Bezug landet der Eintrag am zweiten Stopp des Tages")
    func portReferenceWinsOnMultiStopDay() {
        let sameDay = routeLocalDate(2026, 6, 3)
        let first = makeRouteStop(sortOrder: 4, arrival: sameDay)
        let second = makeRouteStop(sortOrder: 5, arrival: sameDay)
        let entry = makeRouteEntry(portID: second.id, entryDate: routeEntryDay(2026, 6, 3))

        let result = RouteJournalPlanner.assign(
            entries: [entry], stops: [first, second], calendar: routeTestCalendar
        )

        #expect(result.entryIDs(forStopID: second.id) == [entry.id])
        #expect(result.entryIDs(forStopID: first.id).isEmpty)
    }

    @Test("Regel 2: Seetage sind normale Traeger — hafenloser Eintrag landet dort")
    func seaDayCarriesPortlessEntry() {
        // Seetage unterscheiden sich fuer die Zuordnung nicht von Haefen: sie sind
        // Route-Stopps und kommen als `RouteStopInput` genauso an.
        let seaDay = makeRouteStop(sortOrder: 1, arrival: routeLocalDate(2026, 6, 2))
        let harbour = makeRouteStop(sortOrder: 0, arrival: routeLocalDate(2026, 6, 1))
        let entry = makeRouteEntry(entryDate: routeEntryDay(2026, 6, 2))

        let result = RouteJournalPlanner.assign(
            entries: [entry], stops: [harbour, seaDay], calendar: routeTestCalendar
        )

        #expect(result.entryIDs(forStopID: seaDay.id) == [entry.id])
    }

    @Test("Regel 4: Tag ohne Route-Stopp → Sammelblock, keine synthetische Zeile")
    func dayWithoutStopGoesToCollector() {
        let bergen = makeRouteStop(sortOrder: 0, arrival: routeLocalDate(2026, 6, 1))
        let entry = makeRouteEntry(entryDate: routeEntryDay(2026, 6, 9))

        let result = RouteJournalPlanner.assign(
            entries: [entry], stops: [bergen], calendar: routeTestCalendar
        )

        #expect(result.unassignedEntryIDs == [entry.id])
        #expect(result.entryIDsByStopID.isEmpty)
    }

    @Test("Regel 4: leere Route → alle Eintraege im Sammelblock")
    func emptyRoutePutsEverythingIntoCollector() {
        let early = makeRouteEntry(entryDate: routeEntryDay(2026, 6, 1))
        let late = makeRouteEntry(entryDate: routeEntryDay(2026, 6, 4))

        let result = RouteJournalPlanner.assign(
            entries: [late, early], stops: [], calendar: routeTestCalendar
        )

        #expect(result.unassignedEntryIDs == [early.id, late.id])
        #expect(result.entryIDsByStopID.isEmpty)
    }

    @Test("Sammelblock bleibt leer, wenn jeder Eintrag einen Traeger hat")
    func collectorStaysEmptyWhenEverythingIsAssigned() {
        let bergen = makeRouteStop(sortOrder: 0, arrival: routeLocalDate(2026, 6, 1))
        let entry = makeRouteEntry(entryDate: routeEntryDay(2026, 6, 1))

        let result = RouteJournalPlanner.assign(
            entries: [entry], stops: [bergen], calendar: routeTestCalendar
        )

        #expect(result.unassignedEntryIDs.isEmpty)
    }

    @Test("Verwaiste portID (kein Stopp der Route) faellt auf die Datumsregel zurueck")
    func danglingPortIDFallsBackToDateRule() {
        let bergen = makeRouteStop(sortOrder: 0, arrival: routeLocalDate(2026, 6, 1))
        let entry = makeRouteEntry(portID: UUID(), entryDate: routeEntryDay(2026, 6, 1))

        let result = RouteJournalPlanner.assign(
            entries: [entry], stops: [bergen], calendar: routeTestCalendar
        )

        #expect(result.entryIDs(forStopID: bergen.id) == [entry.id])
    }

    @Test("Stopp ohne Eintraege taucht nicht im Ergebnis auf (kein leerer Abschnitt)")
    func stopWithoutEntriesIsAbsent() {
        let bergen = makeRouteStop(sortOrder: 0, arrival: routeLocalDate(2026, 6, 1))
        let leerer = makeRouteStop(sortOrder: 1, arrival: routeLocalDate(2026, 6, 2))
        let entry = makeRouteEntry(entryDate: routeEntryDay(2026, 6, 1))

        let result = RouteJournalPlanner.assign(
            entries: [entry], stops: [bergen, leerer], calendar: routeTestCalendar
        )

        #expect(result.entryIDsByStopID[leerer.id] == nil)
        #expect(result.entryIDs(forStopID: leerer.id).isEmpty)
    }
}

// MARK: - Sortierung

@Suite("RouteJournalPlanner.assign — Sortierung (J3neu (a))")
struct RouteJournalPlannerSortingTests {

    @Test("Innerhalb eines Stopps: entryDate aufsteigend, dann createdAt aufsteigend")
    func sortsByEntryDateThenCreatedAt() {
        let bergen = makeRouteStop(sortOrder: 0, arrival: routeLocalDate(2026, 6, 1))
        let base = Date(timeIntervalSince1970: 1_780_000_000)
        // Alle drei haengen per Hafen-Bezug am selben Stopp, aber an zwei Tagen.
        let day2Late = makeRouteEntry(
            portID: bergen.id, entryDate: routeEntryDay(2026, 6, 2), createdAt: base + 300
        )
        let day1 = makeRouteEntry(
            portID: bergen.id, entryDate: routeEntryDay(2026, 6, 1), createdAt: base + 900
        )
        let day2Early = makeRouteEntry(
            portID: bergen.id, entryDate: routeEntryDay(2026, 6, 2), createdAt: base + 100
        )

        let result = RouteJournalPlanner.assign(
            entries: [day2Late, day1, day2Early], stops: [bergen], calendar: routeTestCalendar
        )

        #expect(result.entryIDs(forStopID: bergen.id) == [day1.id, day2Early.id, day2Late.id])
    }

    @Test("Sammelblock nutzt dieselbe Sortierung")
    func collectorUsesSameSorting() {
        let base = Date(timeIntervalSince1970: 1_780_000_000)
        let late = makeRouteEntry(entryDate: routeEntryDay(2026, 6, 5), createdAt: base + 10)
        let earlySecond = makeRouteEntry(entryDate: routeEntryDay(2026, 6, 4), createdAt: base + 50)
        let earlyFirst = makeRouteEntry(entryDate: routeEntryDay(2026, 6, 4), createdAt: base + 20)

        let result = RouteJournalPlanner.assign(
            entries: [late, earlySecond, earlyFirst], stops: [], calendar: routeTestCalendar
        )

        #expect(result.unassignedEntryIDs == [earlyFirst.id, earlySecond.id, late.id])
    }

    @Test("Gleiches entryDate und createdAt: Reihenfolge ist deterministisch (id-Tiebreak)")
    func equalKeysAreOrderedDeterministically() {
        let base = Date(timeIntervalSince1970: 1_780_000_000)
        let a = makeRouteEntry(entryDate: routeEntryDay(2026, 6, 4), createdAt: base)
        let b = makeRouteEntry(entryDate: routeEntryDay(2026, 6, 4), createdAt: base)

        let forward = RouteJournalPlanner.assign(
            entries: [a, b], stops: [], calendar: routeTestCalendar
        )
        let reversed = RouteJournalPlanner.assign(
            entries: [b, a], stops: [], calendar: routeTestCalendar
        )

        #expect(forward.unassignedEntryIDs == reversed.unassignedEntryIDs)
    }
}

// MARK: - Zeitzonen-Vertrag

@Suite("RouteJournalPlanner.assign — Zeitzonen-Vertrag (ADR-003)")
struct RouteJournalPlannerTimeZoneTests {

    /// `entryDate` = 12:00 UTC. In Kiritimati (UTC+14) ist das bereits 02:00 des
    /// **Folgetags** — wuerde der Tag lokal statt ueber den UTC-Kalender extrahiert,
    /// landete der Eintrag beim falschen Stopp.
    @Test("Extremzeitzone UTC+14: entryDate-Tag wird ueber den UTC-Kalender gelesen")
    func farEasternTimeZoneKeepsEntryDay() throws {
        var kiritimati = Calendar(identifier: .gregorian)
        kiritimati.timeZone = try #require(TimeZone(identifier: "Pacific/Kiritimati"))

        let stopOn10th = makeRouteStop(
            sortOrder: 0, arrival: routeLocalDate(2026, 6, 10, hour: 9, calendar: kiritimati)
        )
        let stopOn11th = makeRouteStop(
            sortOrder: 1, arrival: routeLocalDate(2026, 6, 11, hour: 9, calendar: kiritimati)
        )
        let entry = makeRouteEntry(entryDate: routeEntryDay(2026, 6, 10))

        let result = RouteJournalPlanner.assign(
            entries: [entry], stops: [stopOn10th, stopOn11th], calendar: kiritimati
        )

        #expect(result.entryIDs(forStopID: stopOn10th.id) == [entry.id])
        #expect(result.entryIDs(forStopID: stopOn11th.id).isEmpty)
    }

    /// Gegenprobe am Westrand: Midway liegt bei UTC-11.
    @Test("Extremzeitzone UTC-11: Zuordnung bleibt am korrekten Tag")
    func farWesternTimeZoneKeepsEntryDay() throws {
        var midway = Calendar(identifier: .gregorian)
        midway.timeZone = try #require(TimeZone(identifier: "Pacific/Midway"))

        let stopOn10th = makeRouteStop(
            sortOrder: 0, arrival: routeLocalDate(2026, 6, 10, hour: 20, calendar: midway)
        )
        let stopOn11th = makeRouteStop(
            sortOrder: 1, arrival: routeLocalDate(2026, 6, 11, hour: 20, calendar: midway)
        )
        let entry = makeRouteEntry(entryDate: routeEntryDay(2026, 6, 11))

        let result = RouteJournalPlanner.assign(
            entries: [entry], stops: [stopOn10th, stopOn11th], calendar: midway
        )

        #expect(result.entryIDs(forStopID: stopOn11th.id) == [entry.id])
        #expect(result.entryIDs(forStopID: stopOn10th.id).isEmpty)
    }

    /// Ein nicht-gregorianischer Geraete-Kalender darf das Tripel nicht in seine
    /// eigene Aera verschieben (siehe `JournalDay.gregorianCalendar(zonedLike:)`).
    @Test("Nicht-gregorianischer Geraete-Kalender verschiebt die Zuordnung nicht")
    func nonGregorianDeviceCalendarStillMatches() throws {
        var buddhist = Calendar(identifier: .buddhist)
        buddhist.timeZone = try #require(TimeZone(identifier: "Asia/Bangkok"))

        let stop = makeRouteStop(
            sortOrder: 0, arrival: routeLocalDate(2026, 6, 10, hour: 9, calendar: routeTestCalendar)
        )
        let entry = makeRouteEntry(entryDate: routeEntryDay(2026, 6, 10))

        let result = RouteJournalPlanner.assign(
            entries: [entry], stops: [stop], calendar: buddhist
        )

        #expect(result.entryIDs(forStopID: stop.id) == [entry.id])
    }
}
