//
//  CalendarSyncService.swift
//  ShipTrip
//

import EventKit
import Foundation
import OSLog

enum CalendarSyncPreferences {
    static let enabledKey = "calendarSyncEnabled"
    static let calendarIdentifierKey = "calendarSyncCalendarIdentifier"
    static let modeKey = "calendarSyncMode"

    static var isEnabled: Bool {
        UserDefaults.standard.bool(forKey: enabledKey)
    }

    static var calendarIdentifier: String {
        UserDefaults.standard.string(forKey: calendarIdentifierKey) ?? ""
    }

    static var mode: CalendarSyncMode {
        CalendarSyncMode(rawValue: UserDefaults.standard.string(forKey: modeKey) ?? "") ?? .tripOnly
    }
}

struct WritableCalendar: Identifiable, Hashable {
    let id: String
    let title: String
    let sourceTitle: String

    var displayName: String {
        sourceTitle.isEmpty ? title : "\(title) · \(sourceTitle)"
    }
}

enum CalendarSyncError: LocalizedError {
    case accessDenied
    case calendarMissing

    var errorDescription: String? {
        switch self {
        case .accessDenied:
            String(localized: "Kalenderzugriff ist nicht erlaubt.")
        case .calendarMissing:
            String(localized: "Der ausgewählte Kalender ist nicht mehr verfügbar.")
        }
    }
}

@MainActor
final class CalendarSyncService {
    static let shared = CalendarSyncService()

    private static let mappingKey = "calendarSyncManagedEventIdentifiers"
    private let eventStore: EKEventStore
    private let defaults: UserDefaults
    private let logger = Logger(subsystem: "com.andre.ShipTrip", category: "CalendarSync")

    init(eventStore: EKEventStore = EKEventStore(), defaults: UserDefaults = .standard) {
        self.eventStore = eventStore
        self.defaults = defaults
    }

    var authorizationStatus: EKAuthorizationStatus {
        EKEventStore.authorizationStatus(for: .event)
    }

    /// Ob ShipTrip Termine verwaltet, die im Kalender noch existieren.
    ///
    /// Ein veraltetes Mapping (Termine in der Kalender-App gelöscht) zählt
    /// bewusst nicht: Sonst erschiene beim Kalenderwechsel ein Umzugsdialog,
    /// obwohl es nichts zu übertragen gibt.
    var hasManagedEvents: Bool {
        managedEventIdentifiers.values.contains { eventStore.event(withIdentifier: $0) != nil }
    }

    func requestAccess() async -> Bool {
        switch authorizationStatus {
        case .fullAccess:
            return true
        case .notDetermined:
            do {
                return try await eventStore.requestFullAccessToEvents()
            } catch {
                logger.error("Kalenderberechtigung fehlgeschlagen: \(error, privacy: .private)")
                return false
            }
        default:
            return false
        }
    }

    func writableCalendars() -> [WritableCalendar] {
        guard authorizationStatus == .fullAccess else { return [] }
        return eventStore.calendars(for: .event)
            .filter(\.allowsContentModifications)
            .map {
                WritableCalendar(
                    id: $0.calendarIdentifier,
                    title: $0.title,
                    sourceTitle: $0.source.title
                )
            }
            .sorted {
                $0.displayName.localizedCaseInsensitiveCompare($1.displayName) == .orderedAscending
            }
    }

    @discardableResult
    func selectDefaultCalendarIfNeeded() -> String? {
        let configuredIdentifier = defaults.string(forKey: CalendarSyncPreferences.calendarIdentifierKey) ?? ""
        if !configuredIdentifier.isEmpty,
           calendar(withIdentifier: configuredIdentifier) != nil {
            return configuredIdentifier
        }

        guard let calendar = eventStore.defaultCalendarForNewEvents,
              calendar.allowsContentModifications else {
            return nil
        }
        defaults.set(calendar.calendarIdentifier, forKey: CalendarSyncPreferences.calendarIdentifierKey)
        return calendar.calendarIdentifier
    }

    @discardableResult
    func synchronize(cruises: [Cruise]) throws -> Int {
        guard CalendarSyncPreferences.isEnabled else { return 0 }
        guard authorizationStatus == .fullAccess else { throw CalendarSyncError.accessDenied }
        guard let targetCalendar = calendar(withIdentifier: CalendarSyncPreferences.calendarIdentifier) else {
            throw CalendarSyncError.calendarMissing
        }

        let drafts = cruises
            .filter { !$0.isDemo }
            .flatMap {
                CalendarEventPlanner.makeDrafts(
                    for: $0,
                    mode: CalendarSyncPreferences.mode
                )
            }
        let desiredKeys = Set(drafts.map(\.stableKey))
        var identifiers = managedEventIdentifiers

        do {
            for draft in drafts {
                let event = identifiers[draft.stableKey]
                    .flatMap(eventStore.event(withIdentifier:))
                    ?? matchingEvent(for: draft, in: targetCalendar)
                    ?? EKEvent(eventStore: eventStore)

                event.calendar = targetCalendar
                event.title = draft.title
                event.startDate = draft.startDate
                event.endDate = draft.endDate
                event.isAllDay = draft.isAllDay
                event.location = draft.location
                event.notes = draft.notes
                event.url = draft.markerURL

                try eventStore.save(event, span: .thisEvent, commit: false)
                if let identifier = event.eventIdentifier {
                    identifiers[draft.stableKey] = identifier
                }
            }

            for stableKey in Array(identifiers.keys) where !desiredKeys.contains(stableKey) {
                if let identifier = identifiers[stableKey],
                   let event = eventStore.event(withIdentifier: identifier) {
                    try eventStore.remove(event, span: .thisEvent, commit: false)
                }
                identifiers.removeValue(forKey: stableKey)
            }

            try eventStore.commit()
        } catch {
            eventStore.reset()
            throw error
        }
        managedEventIdentifiers = identifiers
        return drafts.count
    }

    /// Überträgt alle verwalteten Termine in den inzwischen eingestellten
    /// Zielkalender: Die bestehenden Einträge werden im bisherigen Kalender
    /// gelöscht und im neuen Kalender neu angelegt.
    ///
    /// Bewusst löschen statt umhängen: Beim Kalenderwechsel ändert sich laut
    /// Apple-Doku ohnehin der `eventIdentifier`, und ein Wechsel über
    /// Source-Grenzen (iCloud → lokal → Google) ist für gespeicherte Termine
    /// nicht dokumentiert zugesichert.
    ///
    /// Löschung und Neuanlage sind zwei getrennte EventKit-Commits. Damit die
    /// Termine nicht gelöscht werden, ohne im neuen Kalender anzukommen, prüft
    /// die Migration **vorher** alle Vorbedingungen von `synchronize`.
    @discardableResult
    func migrateManagedEvents(cruises: [Cruise]) throws -> Int {
        guard CalendarSyncPreferences.isEnabled else { return 0 }
        guard authorizationStatus == .fullAccess else { throw CalendarSyncError.accessDenied }
        guard calendar(withIdentifier: CalendarSyncPreferences.calendarIdentifier) != nil else {
            throw CalendarSyncError.calendarMissing
        }

        try removeAllManagedEvents()
        return try synchronize(cruises: cruises)
    }

    func removeAllManagedEvents() throws {
        guard authorizationStatus == .fullAccess else { throw CalendarSyncError.accessDenied }

        do {
            for identifier in managedEventIdentifiers.values {
                guard let event = eventStore.event(withIdentifier: identifier) else { continue }
                try eventStore.remove(event, span: .thisEvent, commit: false)
            }
            try eventStore.commit()
        } catch {
            eventStore.reset()
            throw error
        }
        managedEventIdentifiers = [:]
    }

    private func calendar(withIdentifier identifier: String) -> EKCalendar? {
        guard !identifier.isEmpty else { return nil }
        return eventStore.calendar(withIdentifier: identifier)
            .flatMap { $0.allowsContentModifications ? $0 : nil }
    }

    /// Sucht ausschließlich im Zielkalender: Termine in einem früher genutzten
    /// Kalender dürfen nicht wieder übernommen werden, sonst bliebe ein
    /// Kalenderwechsel wirkungslos.
    private func matchingEvent(for draft: CalendarEventDraft, in calendar: EKCalendar) -> EKEvent? {
        let searchStart = Calendar.current.date(byAdding: .day, value: -1, to: draft.startDate) ?? draft.startDate
        let searchEnd = Calendar.current.date(byAdding: .day, value: 1, to: draft.endDate) ?? draft.endDate
        let predicate = eventStore.predicateForEvents(
            withStart: searchStart,
            end: searchEnd,
            calendars: [calendar]
        )
        return eventStore.events(matching: predicate).first { $0.url == draft.markerURL }
    }

    private var managedEventIdentifiers: [String: String] {
        get {
            guard let data = defaults.data(forKey: Self.mappingKey),
                  let identifiers = try? JSONDecoder().decode([String: String].self, from: data) else {
                return [:]
            }
            return identifiers
        }
        set {
            let data = try? JSONEncoder().encode(newValue)
            defaults.set(data, forKey: Self.mappingKey)
        }
    }
}
