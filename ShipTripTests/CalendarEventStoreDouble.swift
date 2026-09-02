//
//  CalendarEventStoreDouble.swift
//  ShipTripTests
//

import EventKit
import Foundation
@testable import ShipTrip

/// Wrapper um einen **echten** `EKEventStore`: Alle Lesewege und die
/// Objekt-Fabrik (`makeEvent()`) gehen unverändert durch, nur `save`,
/// `remove` und `commit` lassen sich auf Befehl scheitern lassen.
///
/// Bewusst keine EventKit-Attrappe — `EKEvent` braucht einen echten Store,
/// und ein nachgebauter Kalender würde genau die Fehler verstecken, die
/// diese Tests suchen (Identifier-Vergabe, Commit-Semantik).
@MainActor
final class CalendarEventStoreDouble: CalendarEventStoring {

    enum DoubleError: Error {
        case saveFailed
        case removeFailed
        case commitFailed
    }

    var failSave = false
    var failRemove = false
    var failCommit = false

    private(set) var saveCount = 0
    private(set) var removeCount = 0
    private(set) var commitCount = 0

    private let store: EKEventStore

    init(store: EKEventStore) {
        self.store = store
    }

    // MARK: - Lesewege

    var authorizationStatus: EKAuthorizationStatus { store.authorizationStatus }

    var defaultCalendarForNewEvents: EKCalendar? { store.defaultCalendarForNewEvents }

    func requestFullAccessToEvents() async throws -> Bool {
        try await store.requestFullAccessToEvents()
    }

    func calendars(for entityType: EKEntityType) -> [EKCalendar] {
        store.calendars(for: entityType)
    }

    func calendar(withIdentifier identifier: String) -> EKCalendar? {
        store.calendar(withIdentifier: identifier)
    }

    func event(withIdentifier identifier: String) -> EKEvent? {
        store.event(withIdentifier: identifier)
    }

    func predicateForEvents(
        withStart startDate: Date,
        end endDate: Date,
        calendars: [EKCalendar]?
    ) -> NSPredicate {
        store.predicateForEvents(withStart: startDate, end: endDate, calendars: calendars)
    }

    func events(matching predicate: NSPredicate) -> [EKEvent] {
        store.events(matching: predicate)
    }

    func makeEvent() -> EKEvent {
        store.makeEvent()
    }

    // MARK: - Schreibwege

    func save(_ event: EKEvent, span: EKSpan, commit: Bool) throws {
        saveCount += 1
        if failSave { throw DoubleError.saveFailed }
        try store.save(event, span: span, commit: commit)
    }

    func remove(_ event: EKEvent, span: EKSpan, commit: Bool) throws {
        removeCount += 1
        if failRemove { throw DoubleError.removeFailed }
        try store.remove(event, span: span, commit: commit)
    }

    func commit() throws {
        commitCount += 1
        if failCommit { throw DoubleError.commitFailed }
        try store.commit()
    }

    func reset() {
        store.reset()
    }
}
