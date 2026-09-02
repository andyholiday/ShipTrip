//
//  CalendarScopeAvailabilityTests.swift
//  ShipTripTests
//

import Testing
@testable import ShipTrip

/// Die Umfangs-Schalter dürfen erst schreiben, wenn die Bestands-Migration
/// entschieden hat: Ein früher Tipp setzt `calendarSyncMode`, die Migration
/// liest den gesetzten Schlüssel als bewusste Wahl und der Ganzreise-Termin
/// eines Bestandsnutzers verschwände beim nächsten Sync.
@Suite("Kalender-Umfang: Bedienbarkeit", .serialized)
@MainActor
struct CalendarScopeAvailabilityTests {

    @Test("Ohne gesetzten Umfang und ohne entschiedene Migration bleiben die Schalter gesperrt")
    func scopeStaysLockedUntilMigrationSettled() throws {
        let suite = try DefaultsSuite(name: #function)
        defer { suite.tearDown() }

        // Kein Kalenderzugriff: Die Migration kann den Bestand nicht prüfen
        // und bleibt offen.
        CalendarSyncModeMigration.run(
            in: suite.defaults,
            hasCalendarAccess: false,
            hasLiveTripEvent: false
        )

        #expect(suite.defaults.string(forKey: CalendarSyncPreferences.modeKey) == nil)
        let availability = CalendarScopeAvailability(
            isMigrationSettled: CalendarSyncModeMigration.isSettled(in: suite.defaults),
            hasCalendarAccess: false,
            isWorking: false
        )

        #expect(!availability.isEditable)
    }

    @Test("Nach der entschiedenen Bestands-Migration sind die Schalter frei")
    func scopeUnlocksOnceMigrationSettled() throws {
        let suite = try DefaultsSuite(name: #function)
        defer { suite.tearDown() }

        // Mit Zugriff fällt die Entscheidung: Der Bestand ist geprüft.
        CalendarSyncModeMigration.run(
            in: suite.defaults,
            hasCalendarAccess: true,
            hasLiveTripEvent: true
        )

        let availability = CalendarScopeAvailability(
            isMigrationSettled: CalendarSyncModeMigration.isSettled(in: suite.defaults),
            hasCalendarAccess: true,
            isWorking: false
        )

        #expect(availability.isEditable)
    }

    @Test("Ein laufender Sync sperrt die Schalter weiterhin")
    func runningSyncKeepsScopeLocked() {
        let availability = CalendarScopeAvailability(
            isMigrationSettled: true,
            hasCalendarAccess: true,
            isWorking: true
        )

        #expect(!availability.isEditable)
    }
}
