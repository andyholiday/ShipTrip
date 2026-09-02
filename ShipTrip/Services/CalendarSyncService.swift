//
//  CalendarSyncService.swift
//  ShipTrip
//

import CoreLocation
import EventKit
import Foundation
import OSLog

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
    private static let pendingRemovalKey = "calendarSyncPendingRemovalIdentifiers"
    private let eventStore: any CalendarEventStoring
    private let defaults: UserDefaults
    private let logger = Logger(subsystem: "com.andre.ShipTrip", category: "CalendarSync")

    init(
        eventStore: any CalendarEventStoring = EKEventStore(),
        defaults: UserDefaults = .standard
    ) {
        self.eventStore = eventStore
        self.defaults = defaults
        drainPendingRemovals()
    }

    var authorizationStatus: EKAuthorizationStatus {
        eventStore.authorizationStatus
    }

    /// Ob ShipTrip Termine verwaltet, die im Kalender noch existieren.
    ///
    /// Ein veraltetes Mapping (Termine in der Kalender-App gelöscht) zählt
    /// bewusst nicht: Sonst erschiene beim Kalenderwechsel ein Umzugsdialog,
    /// obwohl es nichts zu übertragen gibt.
    var hasManagedEvents: Bool {
        migrateSyncModeIfNeeded()
        return managedEventIdentifiers.values.contains {
            eventStore.event(withIdentifier: $0) != nil
        }
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
        let configuredIdentifier = targetCalendarIdentifier
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
        try synchronize(cruises: cruises, allowMarkerSearch: true)
    }

    /// - Parameter allowMarkerSearch: Erlaubt die breite Marker-Suche über
    ///   alle beschreibbaren Kalender für Entwürfe ohne Mapping-Eintrag. Sie
    ///   fängt den Mapping-Verlust nach Restore oder Neuinstallation ab. Beim
    ///   Kalenderwechsel ist sie unerwünscht: Dort ist das Mapping die
    ///   Wahrheit, und ein früher genutzter Kalender darf nicht wieder als
    ///   Fundgrube dienen.
    private func synchronize(cruises: [Cruise], allowMarkerSearch: Bool) throws -> Int {
        migrateSyncModeIfNeeded()
        guard CalendarSyncPreferences.isEnabled(in: defaults) else { return 0 }
        guard authorizationStatus == .fullAccess else { throw CalendarSyncError.accessDenied }
        guard let targetCalendar = calendar(withIdentifier: targetCalendarIdentifier) else {
            throw CalendarSyncError.calendarMissing
        }

        let drafts = cruises
            .filter { !$0.isDemo }
            .flatMap {
                CalendarEventPlanner.makeDrafts(
                    for: $0,
                    mode: CalendarSyncPreferences.mode(in: defaults)
                )
            }
        let desiredKeys = Set(drafts.map(\.stableKey))
        var identifiers = managedEventIdentifiers
        var replaced: [String] = []

        do {
            for draft in drafts {
                let resolved = resolveEvent(
                    for: draft,
                    mappedIdentifier: identifiers[draft.stableKey],
                    target: targetCalendar,
                    allowMarkerSearch: allowMarkerSearch
                )
                if let identifier = resolved.replaced {
                    replaced.append(identifier)
                }
                apply(draft, to: resolved.event)

                try eventStore.save(resolved.event, span: .thisEvent, commit: false)
                if let identifier = resolved.event.eventIdentifier {
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

        // Erst nach dem Commit verlieren die ersetzten Termine ihren Platz:
        // Journal schreiben, dann das Mapping ohne sie, dann löschen. Bricht
        // es dazwischen ab, räumt der nächste Start das Journal nach.
        if !replaced.isEmpty {
            pendingRemovalIdentifiers += replaced
        }
        managedEventIdentifiers = identifiers
        drainPendingRemovals()
        return drafts.count
    }

    /// Sucht den Termin für einen Entwurf und meldet, welcher alte Identifier
    /// dadurch ersetzt wird.
    ///
    /// Termine werden nie umgehängt: Liegt der zugeordnete Termin in einem
    /// anderen Kalender, entsteht ein neuer im Ziel, und der alte wandert ins
    /// Lösch-Journal. Ein Wechsel über Source-Grenzen (iCloud → lokal →
    /// Google) ist für gespeicherte Termine nicht dokumentiert zugesichert.
    private func resolveEvent(
        for draft: CalendarEventDraft,
        mappedIdentifier: String?,
        target: EKCalendar,
        allowMarkerSearch: Bool
    ) -> (event: EKEvent, replaced: String?) {
        let mapped = mappedIdentifier.flatMap(eventStore.event(withIdentifier:))
        if let mapped, mapped.calendar?.calendarIdentifier == target.calendarIdentifier {
            return (mapped, nil)
        }
        if let existing = markerEvent(for: draft, in: [target]) {
            return (existing, mapped?.eventIdentifier)
        }

        let foreignIdentifier: String? = allowMarkerSearch && mappedIdentifier == nil
            ? markerEvent(for: draft, in: writableCalendars(besides: target))?.eventIdentifier
            : nil
        let created = eventStore.makeEvent()
        created.calendar = target
        return (created, mapped?.eventIdentifier ?? foreignIdentifier)
    }

    private func apply(_ draft: CalendarEventDraft, to event: EKEvent) {
        event.title = draft.title
        event.startDate = draft.startDate
        event.endDate = draft.endDate
        event.isAllDay = draft.isAllDay
        applyLocation(draft, to: event)
        event.notes = draft.notes
        event.url = draft.markerURL
    }

    /// Setzt den Ort. Mit Koordinate wird er strukturiert hinterlegt, damit
    /// der Kalender ihn anklickbar macht und Karte bzw. Navigation öffnet;
    /// ohne Koordinate bleibt es beim reinen Text.
    ///
    /// Der Weg über `structuredLocation` ist auch der Aufräumpfad: Verliert
    /// ein Hafen seine Koordinate, überschreibt `event.location` den alten
    /// strukturierten Ort mitsamt Geo-Position.
    private func applyLocation(_ draft: CalendarEventDraft, to event: EKEvent) {
        guard let title = draft.location else {
            event.structuredLocation = nil
            return
        }
        guard let coordinate = draft.coordinate else {
            event.location = title
            return
        }
        let structured = EKStructuredLocation(title: title)
        structured.geoLocation = CLLocation(
            latitude: coordinate.latitude,
            longitude: coordinate.longitude
        )
        event.structuredLocation = structured
    }

    /// Schreibt den Bestand einmalig auf einen ausdrücklichen Umfang fest,
    /// bevor irgendetwas synchronisiert wird (siehe `CalendarSyncModeMigration`).
    ///
    /// Die Vorabfrage spart den Bestands-Scan: Nach der einmaligen
    /// Entscheidung kostet der Aufruf nur noch eine Defaults-Lesung.
    private func migrateSyncModeIfNeeded() {
        guard !CalendarSyncModeMigration.isSettled(in: defaults) else { return }
        CalendarSyncModeMigration.run(
            in: defaults,
            hasCalendarAccess: authorizationStatus == .fullAccess,
            hasLiveTripEvent: hasLiveTripEvent
        )
    }

    /// Ob zu einem Mapping-Schlüssel mit Suffix `/trip` noch ein Termin im
    /// Kalender steht — der Bestandsnachweis der Modus-Migration.
    private var hasLiveTripEvent: Bool {
        managedEventIdentifiers.contains { stableKey, identifier in
            stableKey.hasSuffix("/trip") && eventStore.event(withIdentifier: identifier) != nil
        }
    }

    /// Arbeitet das Lösch-Journal ab: Termine, die bereits durch neue ersetzt
    /// wurden. Idempotent — ein Identifier ohne Termin gilt als erledigt.
    private func drainPendingRemovals() {
        let pending = pendingRemovalIdentifiers
        guard !pending.isEmpty, authorizationStatus == .fullAccess else { return }

        do {
            for identifier in pending {
                guard let event = eventStore.event(withIdentifier: identifier) else { continue }
                try eventStore.remove(event, span: .thisEvent, commit: false)
            }
            try eventStore.commit()
        } catch {
            eventStore.reset()
            logger.error("Nachlauf des Lösch-Journals fehlgeschlagen: \(error, privacy: .private)")
            return
        }

        let removed = Set(pending)
        managedEventIdentifiers = managedEventIdentifiers.filter { !removed.contains($0.value) }
        pendingRemovalIdentifiers = []
    }

    /// Überträgt alle verwalteten Termine in den inzwischen eingestellten
    /// Zielkalender: Die Einträge entstehen im neuen Kalender neu, erst danach
    /// verschwinden die alten.
    ///
    /// Anlegen und Löschen sind zwei getrennte EventKit-Commits. Die
    /// Reihenfolge ist deshalb verbindlich „erst anlegen, dann löschen":
    /// Scheitert das Anlegen, bleibt der Bestand des Nutzers unangetastet und
    /// der Fehler wird durchgereicht. Den Rest erledigt das Lösch-Journal.
    @discardableResult
    func migrateManagedEvents(cruises: [Cruise]) throws -> Int {
        guard CalendarSyncPreferences.isEnabled(in: defaults) else { return 0 }
        guard authorizationStatus == .fullAccess else { throw CalendarSyncError.accessDenied }
        guard calendar(withIdentifier: targetCalendarIdentifier) != nil else {
            throw CalendarSyncError.calendarMissing
        }

        return try synchronize(cruises: cruises, allowMarkerSearch: false)
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

    private var targetCalendarIdentifier: String {
        CalendarSyncPreferences.calendarIdentifier(in: defaults)
    }

    private func calendar(withIdentifier identifier: String) -> EKCalendar? {
        guard !identifier.isEmpty else { return nil }
        return eventStore.calendar(withIdentifier: identifier)
            .flatMap { $0.allowsContentModifications ? $0 : nil }
    }

    /// Sucht den Termin mit der Marker-URL des Entwurfs in den übergebenen
    /// Kalendern.
    private func markerEvent(for draft: CalendarEventDraft, in calendars: [EKCalendar]) -> EKEvent? {
        guard !calendars.isEmpty else { return nil }
        let searchStart = Calendar.current.date(byAdding: .day, value: -1, to: draft.startDate) ?? draft.startDate
        let searchEnd = Calendar.current.date(byAdding: .day, value: 1, to: draft.endDate) ?? draft.endDate
        let predicate = eventStore.predicateForEvents(
            withStart: searchStart,
            end: searchEnd,
            calendars: calendars
        )
        return eventStore.events(matching: predicate).first { $0.url == draft.markerURL }
    }

    private func writableCalendars(besides calendar: EKCalendar) -> [EKCalendar] {
        eventStore.calendars(for: .event).filter {
            $0.allowsContentModifications && $0.calendarIdentifier != calendar.calendarIdentifier
        }
    }

    /// Termine, die durch neue ersetzt wurden und noch gelöscht werden müssen.
    private var pendingRemovalIdentifiers: [String] {
        get { defaults.stringArray(forKey: Self.pendingRemovalKey) ?? [] }
        set {
            if newValue.isEmpty {
                defaults.removeObject(forKey: Self.pendingRemovalKey)
            } else {
                defaults.set(newValue, forKey: Self.pendingRemovalKey)
            }
        }
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
