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

// MARK: - Fixture

/// Zwei frisch angelegte Testkalender, ein isoliertes `UserDefaults`-Suite für
/// die Termin-Zuordnung und gesicherte Sync-Einstellungen.
///
/// Die Einstellungen (`enabled`/`calendarIdentifier`/`mode`) liest der
/// Produktionscode über `CalendarSyncPreferences` aus `UserDefaults.standard` —
/// sie werden hier gesetzt und in `tearDown()` wiederhergestellt.
@MainActor
private final class MigrationFixture {
    enum FixtureError: Error {
        case notAuthorized
        case noWritableSource
    }

    /// Spiegelt den privaten Persistenz-Schlüssel von `CalendarSyncService`.
    private static let mappingKey = "calendarSyncManagedEventIdentifiers"

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
    private let standard = UserDefaults.standard
    private let previousPreferences: [String: Any?]

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
        oldCalendar = try Self.makeCalendar(titled: "ShipTrip Alt \(name)", source: source, store: store)
        newCalendar = try Self.makeCalendar(titled: "ShipTrip Neu \(name)", source: source, store: store)
        service = CalendarSyncService(eventStore: store, defaults: defaults)
        previousPreferences = [
            CalendarSyncPreferences.enabledKey: standard.object(forKey: CalendarSyncPreferences.enabledKey),
            CalendarSyncPreferences.calendarIdentifierKey:
                standard.object(forKey: CalendarSyncPreferences.calendarIdentifierKey),
            CalendarSyncPreferences.modeKey: standard.object(forKey: CalendarSyncPreferences.modeKey)
        ]
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
        for (key, value) in previousPreferences {
            standard.set(value ?? nil, forKey: key)
        }
    }

    func setPreferences(
        enabled: Bool = true,
        calendarIdentifier: String,
        mode: CalendarSyncMode = .tripOnly
    ) {
        standard.set(enabled, forKey: CalendarSyncPreferences.enabledKey)
        standard.set(calendarIdentifier, forKey: CalendarSyncPreferences.calendarIdentifierKey)
        standard.set(mode.rawValue, forKey: CalendarSyncPreferences.modeKey)
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
