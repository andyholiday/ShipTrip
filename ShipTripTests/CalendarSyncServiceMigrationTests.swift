//
//  CalendarSyncServiceMigrationTests.swift
//  ShipTripTests
//

import EventKit
import Foundation
import Testing
@testable import ShipTrip

/// Verhaltenstests des datenverändernden Migrationspfads gegen den echten
/// EventStore des Simulators. Die Kalenderrechte erteilt der Test-Runner vorab
/// (`xcrun simctl privacy <udid> grant calendar com.andre.ShipTrip`).
@Suite("Kalender-Migration", .serialized)
@MainActor
struct CalendarSyncServiceMigrationTests {

    // MARK: - Migration

    @Test("Bestätigte Migration verschiebt alle Termine in den neuen Kalender")
    func migrationMovesEventsToTargetCalendar() throws {
        let fixture = try MigrationFixture(name: #function)
        defer { fixture.tearDown() }
        try fixture.syncIntoOldCalendar()

        fixture.setPreferences(calendarIdentifier: fixture.newCalendar.calendarIdentifier)
        let migrated = try fixture.service.migrateManagedEvents(cruises: [fixture.cruise])

        #expect(migrated == 1)
        #expect(fixture.eventCount(in: fixture.oldCalendar) == 0)
        #expect(fixture.eventCount(in: fixture.newCalendar) == 1)

        let identifier = try #require(fixture.managedIdentifiers.values.first)
        let event = try #require(fixture.store.event(withIdentifier: identifier))
        #expect(event.calendar.calendarIdentifier == fixture.newCalendar.calendarIdentifier)
    }

    @Test("Fehlender Zielkalender lässt die Termine im bisherigen Kalender stehen")
    func failedMigrationKeepsEventsInPreviousCalendar() throws {
        let fixture = try MigrationFixture(name: #function)
        defer { fixture.tearDown() }
        try fixture.syncIntoOldCalendar()

        fixture.setPreferences(calendarIdentifier: "kalender-existiert-nicht")

        #expect(throws: CalendarSyncError.calendarMissing) {
            try fixture.service.migrateManagedEvents(cruises: [fixture.cruise])
        }
        #expect(fixture.eventCount(in: fixture.oldCalendar) == 1)
        #expect(fixture.managedIdentifiers.count == 1)
    }

    @Test("Migration bei ausgeschaltetem Sync löscht nichts")
    func migrationWithDisabledSyncKeepsEvents() throws {
        let fixture = try MigrationFixture(name: #function)
        defer { fixture.tearDown() }
        try fixture.syncIntoOldCalendar()

        fixture.setPreferences(enabled: false, calendarIdentifier: fixture.newCalendar.calendarIdentifier)
        let migrated = try fixture.service.migrateManagedEvents(cruises: [fixture.cruise])

        #expect(migrated == 0)
        #expect(fixture.eventCount(in: fixture.oldCalendar) == 1)
        #expect(fixture.managedIdentifiers.count == 1)
    }

    // MARK: - Veraltetes Mapping

    @Test("Extern gelöschte Termine gelten nicht mehr als verwaltet")
    func staleMappingIsNotReportedAsManagedEvents() throws {
        let fixture = try MigrationFixture(name: #function)
        defer { fixture.tearDown() }
        try fixture.syncIntoOldCalendar()
        #expect(fixture.service.hasManagedEvents)

        try fixture.deleteAllEvents(in: fixture.oldCalendar)

        #expect(fixture.managedIdentifiers.count == 1, "Das Mapping bleibt bewusst stehen")
        #expect(fixture.service.hasManagedEvents == false)
    }
}

/// Repro (Fix-Runde 2, F01): „App zurücksetzen" verspricht „wie frisch
/// installiert" — dann dürfen auch keine ShipTrip-Termine im Kalender des
/// Nutzers stehen bleiben. Teilt sich die Fixture mit den Migrationstests, weil
/// dieselbe Ausgangslage gebraucht wird: ein echter, gespiegelter Termin.
@Suite("App-Reset — Kalender-Spiegelung", .serialized)
@MainActor
struct AppResetCalendarCleanupTests {

    @Test("Der Reset löscht die gespiegelten Termine und leert die Zuordnung")
    func resetRemovesManagedEvents() throws {
        let fixture = try MigrationFixture(name: #function)
        defer { fixture.tearDown() }
        try fixture.syncIntoOldCalendar()
        #expect(
            fixture.eventCount(in: fixture.oldCalendar) == 1,
            "Ausgangslage fehlt: es steht kein gespiegelter Termin im Kalender"
        )

        AppReset.run(calendarSync: fixture.service, defaults: fixture.defaults)

        #expect(
            fixture.eventCount(in: fixture.oldCalendar) == 0,
            "Nach dem Reset steht der ShipTrip-Termin noch im Kalender des Nutzers"
        )
        #expect(
            fixture.managedIdentifiers.isEmpty,
            "Nach dem Reset ist die Termin-Zuordnung nicht geleert"
        )
    }
}

// MARK: - Fixture

/// Zwei frisch angelegte Testkalender und ein isoliertes `UserDefaults`-Suite
/// für Zuordnung **und** Sync-Einstellungen.
///
/// Bewusst nichts in `UserDefaults.standard`: Der Test-Host teilt sich diese
/// Domain mit allen anderen Suiten, parallele oder abgebrochene Läufe würden
/// sich sonst gegenseitig die Einstellungen umschreiben (F15).
@MainActor
final class MigrationFixture {
    enum FixtureError: Error {
        case notAuthorized
        case noWritableSource
    }

    /// Spiegeln die privaten Persistenz-Schlüssel von `CalendarSyncService`.
    private static let mappingKey = "calendarSyncManagedEventIdentifiers"
    private static let journalKey = "calendarSyncPendingRemovalIdentifiers"

    let store = EKEventStore()
    let defaults: UserDefaults
    let service: CalendarSyncService
    let oldCalendar: EKCalendar
    let newCalendar: EKCalendar
    let cruise = Cruise(
        title: "Migrationstest",
        startDate: Date(timeIntervalSince1970: 1_785_542_400),
        endDate: Date(timeIntervalSince1970: 1_786_060_800),
        shippingLine: "AIDA Cruises",
        ship: "AIDAstella"
    )

    private let suiteName: String

    init(name: String) throws {
        guard EKEventStore.authorizationStatus(for: .event) == .fullAccess else {
            throw FixtureError.notAuthorized
        }
        guard let source = store.defaultCalendarForNewEvents?.source
            ?? store.sources.first(where: { $0.sourceType == .local }) else {
            throw FixtureError.noWritableSource
        }
        suiteName = "CalendarSyncMigrationTests.\(name)"
        guard let defaults = UserDefaults(suiteName: suiteName) else {
            throw FixtureError.noWritableSource
        }
        defaults.removePersistentDomain(forName: suiteName)

        self.defaults = defaults
        let old = try Self.makeCalendar(titled: "ShipTrip Alt \(name)", source: source, store: store)
        do {
            newCalendar = try Self.makeCalendar(titled: "ShipTrip Neu \(name)", source: source, store: store)
        } catch {
            // F16: Der erste Kalender liegt schon im Store — ohne dieses
            // Aufräumen bliebe er nach einem geworfenen Init für immer stehen.
            try? store.removeCalendar(old, commit: true)
            throw error
        }
        oldCalendar = old
        service = CalendarSyncService(eventStore: store, defaults: defaults)
    }

    private static func makeCalendar(
        titled title: String,
        source: EKSource,
        store: EKEventStore
    ) throws -> EKCalendar {
        let calendar = EKCalendar(for: .event, eventStore: store)
        calendar.title = title
        calendar.source = source
        try store.saveCalendar(calendar, commit: true)
        return calendar
    }

    func tearDown() {
        try? store.removeCalendar(oldCalendar, commit: true)
        try? store.removeCalendar(newCalendar, commit: true)
        defaults.removePersistentDomain(forName: suiteName)
    }

    func setPreferences(
        enabled: Bool = true,
        calendarIdentifier: String,
        mode: CalendarSyncMode = .tripOnly
    ) {
        defaults.set(enabled, forKey: CalendarSyncPreferences.enabledKey)
        defaults.set(calendarIdentifier, forKey: CalendarSyncPreferences.calendarIdentifierKey)
        defaults.set(mode.rawValue, forKey: CalendarSyncPreferences.modeKey)
    }

    @discardableResult
    func syncIntoOldCalendar() throws -> Int {
        setPreferences(calendarIdentifier: oldCalendar.calendarIdentifier)
        return try service.synchronize(cruises: [cruise])
    }

    func eventCount(in calendar: EKCalendar) -> Int {
        store.events(matching: predicate(for: calendar)).count
    }

    func deleteAllEvents(in calendar: EKCalendar) throws {
        for event in store.events(matching: predicate(for: calendar)) {
            try store.remove(event, span: .thisEvent, commit: false)
        }
        try store.commit()
    }

    /// Ein anderer Store (z. B. das Double) auf derselben Persistenz — so
    /// sieht ein „nächster Service-Start" genau die Daten des Vorgängers.
    func makeService(store: any CalendarEventStoring) -> CalendarSyncService {
        CalendarSyncService(eventStore: store, defaults: defaults)
    }

    /// Simuliert den Mapping-Verlust nach Restore oder Neuinstallation.
    func clearMapping() {
        defaults.removeObject(forKey: Self.mappingKey)
    }

    var journal: [String] {
        defaults.stringArray(forKey: Self.journalKey) ?? []
    }

    func writeJournal(_ identifiers: [String]) {
        defaults.set(identifiers, forKey: Self.journalKey)
    }

    var managedIdentifiers: [String: String] {
        guard let data = defaults.data(forKey: Self.mappingKey),
              let identifiers = try? JSONDecoder().decode([String: String].self, from: data) else {
            return [:]
        }
        return identifiers
    }

    private func predicate(for calendar: EKCalendar) -> NSPredicate {
        store.predicateForEvents(
            withStart: cruise.startDate.addingTimeInterval(-30 * 86_400),
            end: cruise.endDate.addingTimeInterval(30 * 86_400),
            calendars: [calendar]
        )
    }
}
