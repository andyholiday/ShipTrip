//
//  CalendarMigrationCoordinatorTests.swift
//  ShipTripTests
//

import EventKit
import Foundation
import Testing
@testable import ShipTrip

/// Der Rollback beim Kalenderwechsel ist die einzige Absicherung gegen
/// Datenverlust und war bis 1.8.7 ungetestet. Läuft gegen den echten
/// EventStore des Simulators; die Kalenderrechte erteilt der Test-Runner vorab
/// (`xcrun simctl privacy <udid> grant calendar com.andre.ShipTrip`).
@Suite("Kalenderwechsel — Rollback", .serialized)
@MainActor
struct CalendarMigrationCoordinatorTests {

    @Test("Erfolgreicher Wechsel meldet die übertragenen Einträge")
    func successfulMigrationReportsCount() throws {
        let fixture = try MigrationFixture(name: #function)
        defer { fixture.tearDown() }
        try fixture.syncIntoOldCalendar()

        let outcome = makeCoordinator(fixture: fixture)
            .migrate(to: fixture.newCalendar.calendarIdentifier, cruises: [fixture.cruise])

        guard case .migrated(let count) = outcome else {
            Issue.record("Erwartet: .migrated, erhalten: \(outcome)")
            return
        }
        #expect(count == 1)
        #expect(targetIdentifier(of: fixture) == fixture.newCalendar.calendarIdentifier)
        #expect(fixture.eventCount(in: fixture.newCalendar) == 1)
    }

    @Test("Gescheiterter Umzug stellt Zielkalender und Termine wieder her")
    func failedMigrationRollsBack() throws {
        let fixture = try MigrationFixture(name: #function)
        defer { fixture.tearDown() }
        try fixture.syncIntoOldCalendar()

        let outcome = makeCoordinator(fixture: fixture)
            .migrate(to: "kalender-existiert-nicht", cruises: [fixture.cruise])

        guard case .rolledBack = outcome else {
            Issue.record("Erwartet: .rolledBack, erhalten: \(outcome)")
            return
        }
        #expect(
            targetIdentifier(of: fixture) == fixture.oldCalendar.calendarIdentifier,
            "Nach dem Rollback steht der Zielkalender nicht wieder auf dem bisherigen"
        )
        #expect(
            fixture.eventCount(in: fixture.oldCalendar) == 1,
            "Nach dem Rollback fehlt der Termin im bisherigen Kalender"
        )
        #expect(fixture.managedIdentifiers.count == 1)
    }

    @Test("Scheitert auch die Wiederherstellung, meldet der Ablauf beide Fehler")
    func failedRollbackIsReported() throws {
        let fixture = try MigrationFixture(name: #function)
        defer { fixture.tearDown() }
        try fixture.syncIntoOldCalendar()

        // Derselbe Store, nur schreibunfähig: das Anlegen im Ziel scheitert und
        // damit auch die Wiederherstellung im bisherigen Kalender.
        let double = CalendarEventStoreDouble(store: fixture.store)
        double.failSave = true
        let coordinator = CalendarMigrationCoordinator(
            service: fixture.makeService(store: double),
            defaults: fixture.defaults
        )

        let outcome = coordinator
            .migrate(to: fixture.newCalendar.calendarIdentifier, cruises: [fixture.cruise])

        guard case .rollbackFailed = outcome else {
            Issue.record("Erwartet: .rollbackFailed, erhalten: \(outcome)")
            return
        }
        #expect(
            targetIdentifier(of: fixture) == fixture.oldCalendar.calendarIdentifier,
            "Auch bei gescheiterter Wiederherstellung bleibt der bisherige Kalender eingestellt"
        )
        #expect(
            double.saveCount >= 2,
            "Es wurde kein zweiter Anlauf zur Wiederherstellung unternommen"
        )
    }

    private func makeCoordinator(fixture: MigrationFixture) -> CalendarMigrationCoordinator {
        CalendarMigrationCoordinator(service: fixture.service, defaults: fixture.defaults)
    }

    /// Der aktuell eingestellte Zielkalender aus der isolierten Test-Suite.
    private func targetIdentifier(of fixture: MigrationFixture) -> String {
        CalendarSyncPreferences.calendarIdentifier(in: fixture.defaults)
    }
}
