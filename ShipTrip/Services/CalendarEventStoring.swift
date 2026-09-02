//
//  CalendarEventStoring.swift
//  ShipTrip
//

import EventKit
import Foundation

/// Schmale Fassade um `EKEventStore` — genau die Methoden, die
/// `CalendarSyncService` tatsächlich benutzt.
///
/// Zweck ist die Testnaht: Ein Double kann `save`/`remove`/`commit` gezielt
/// scheitern lassen, ohne EventKit nachzubauen. Deshalb gehört `makeEvent()`
/// ins Protokoll — `EKEvent(eventStore:)` braucht weiterhin einen echten
/// Store, ein Double bleibt also ein Wrapper und keine Attrappe.
@MainActor
protocol CalendarEventStoring: AnyObject {
    var authorizationStatus: EKAuthorizationStatus { get }
    var defaultCalendarForNewEvents: EKCalendar? { get }

    func requestFullAccessToEvents() async throws -> Bool
    func calendars(for entityType: EKEntityType) -> [EKCalendar]
    func calendar(withIdentifier identifier: String) -> EKCalendar?
    func event(withIdentifier identifier: String) -> EKEvent?
    func predicateForEvents(
        withStart startDate: Date,
        end endDate: Date,
        calendars: [EKCalendar]?
    ) -> NSPredicate
    func events(matching predicate: NSPredicate) -> [EKEvent]
    func makeEvent() -> EKEvent
    func save(_ event: EKEvent, span: EKSpan, commit: Bool) throws
    func remove(_ event: EKEvent, span: EKSpan, commit: Bool) throws
    func commit() throws
    func reset()
}

extension EKEventStore: CalendarEventStoring {

    var authorizationStatus: EKAuthorizationStatus {
        EKEventStore.authorizationStatus(for: .event)
    }

    func makeEvent() -> EKEvent {
        EKEvent(eventStore: self)
    }
}
