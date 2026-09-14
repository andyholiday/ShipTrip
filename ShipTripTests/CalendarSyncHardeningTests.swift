//
//  CalendarSyncHardeningTests.swift
//  ShipTripTests
//

import EventKit
import Foundation
import Testing
@testable import ShipTrip

/// Die drei Datenverlust- und Duplikat-Pfade des Kalender-Syncs, gefahren
/// gegen den echten EventStore des Simulators. Die Kalenderrechte erteilt der
/// Test-Runner vorab (`xcrun simctl privacy <udid> grant calendar
/// com.andre.ShipTrip`).
@Suite("Kalender-Sync Härtung", .serialized)
@MainActor
struct CalendarSyncHardeningTests {

    /// F03: Nach Restore oder Neuinstallation ist das Mapping weg. Der Termin
    /// steht aber noch im Kalender — und zwar in dem, der vorher Ziel war.
    /// Ohne breite Marker-Suche legt der Sync daneben einen zweiten an.
    @Test("Verlorenes Mapping erzeugt keinen zweiten Termin")
    func lostMappingDoesNotDuplicateEvent() throws {
        let fixture = try MigrationFixture(name: #function)
        defer { fixture.tearDown() }
        try fixture.syncIntoOldCalendar()

        fixture.clearMapping()
        fixture.setPreferences(calendarIdentifier: fixture.newCalendar.calendarIdentifier)
        _ = try fixture.service.synchronize(cruises: [fixture.cruise])

        #expect(
            fixture.eventCount(in: fixture.oldCalendar) == 0,
            "Der alte Termin steht noch im bisherigen Kalender — es gibt ihn jetzt doppelt"
        )
        #expect(fixture.eventCount(in: fixture.newCalendar) == 1)
        #expect(fixture.managedIdentifiers.count == 1)
    }

    /// F01-Rest: Der Kalenderwechsel darf nicht loeschen, bevor im Ziel etwas
    /// angekommen ist. Scheitert das Anlegen, bleibt der Bestand unangetastet.
    @Test("Fehlschlagendes Anlegen im Ziel laesst die alten Termine stehen")
    func failedCreateKeepsPreviousEvents() throws {
        let fixture = try MigrationFixture(name: #function)
        defer { fixture.tearDown() }
        try fixture.syncIntoOldCalendar()

        let double = CalendarEventStoreDouble(store: fixture.store)
        double.failSave = true
        let service = fixture.makeService(store: double)
        fixture.setPreferences(calendarIdentifier: fixture.newCalendar.calendarIdentifier)

        #expect(throws: (any Error).self) {
            try service.migrateManagedEvents(cruises: [fixture.cruise])
        }
        #expect(
            fixture.eventCount(in: fixture.oldCalendar) == 1,
            "Der Termin wurde geloescht, obwohl im Zielkalender nichts angekommen ist"
        )
        #expect(fixture.eventCount(in: fixture.newCalendar) == 0)
        #expect(fixture.managedIdentifiers.count == 1)
    }

    /// Bricht der Ablauf zwischen „neu angelegt" und „alt geloescht" ab, steht
    /// der alte Termin verwaist im Kalender. Der naechste Service-Start muss
    /// das Journal abarbeiten.
    @Test("Abbruch vor dem Loeschen wird beim naechsten Start nachgeraeumt")
    func pendingRemovalsAreDrainedOnNextStart() throws {
        let fixture = try MigrationFixture(name: #function)
        defer { fixture.tearDown() }
        try fixture.syncIntoOldCalendar()
        let identifier = try #require(fixture.managedIdentifiers.values.first)

        fixture.writeJournal([identifier])
        _ = fixture.makeService(store: fixture.store)

        #expect(
            fixture.eventCount(in: fixture.oldCalendar) == 0,
            "Der verwaiste Termin steht noch im Kalender des Nutzers"
        )
        #expect(fixture.journal.isEmpty)
    }
}
