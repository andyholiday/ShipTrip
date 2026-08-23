//
//  NotificationReconciler.swift
//  ShipTrip
//

import Foundation
import SwiftData
import UserNotifications
import OSLog

private let logger = Logger(subsystem: "com.andre.ShipTrip", category: "notifications")

// MARK: - Identifier

/// Art der Reise-Erinnerung. Der Rohwert ist Teil des Notification-Identifiers.
enum ReminderKind: String, CaseIterable, Sendable {
    case before
    case departure
}

/// Bildet die Identifier für Reise-Erinnerungen.
///
/// **Warum ein eigener Schlüssel:** Bis 1.7.0 stammte der Identifier aus
/// `String(describing: cruise.persistentModelID)`. Diese ID ist nicht stabil – sie ist vor
/// dem Save temporär und danach permanent, und sie unterscheidet sich nach CloudKit-Mirroring
/// bzw. Migration erneut. iOS ersetzt eine Pending Request aber nur bei **identischem**
/// Identifier; jedes Speichern legte deshalb eine weitere Request mit gleichem Trigger an →
/// mehrere Pushes gleichzeitig. Schlüssel ist daher die stabile `Cruise.id` (ADR-002).
enum ReminderIdentifier {

    /// Prefix aller Identifier des aktuellen Schemas.
    static let identifierPrefix = "reminder."

    /// Prefix des alten, instabilen Schemas – wird beim App-Start abgeräumt.
    static let legacyPrefix = "cruise-"

    /// Stabiler Reise-Schlüssel für alle Erinnerungs-Identifier.
    static func key(for cruise: Cruise) -> String {
        cruise.id.uuidString
    }

    /// Reiner Identifier-Bau: `reminder.<key>.before` bzw. `reminder.<key>.departure`.
    static func make(cruiseKey: String, kind: ReminderKind) -> String {
        "\(identifierPrefix)\(cruiseKey).\(kind.rawValue)"
    }

    /// Gemeinsames Prefix aller Identifier einer einzelnen Reise.
    static func prefix(forCruiseKey cruiseKey: String) -> String {
        "\(identifierPrefix)\(cruiseKey)."
    }

    /// Ob ein Pending-Identifier von ShipTrip verwaltet wird (aktuelles oder altes Schema).
    /// Fremde Identifier bleiben beim Abgleich unangetastet.
    static func isManaged(_ identifier: String) -> Bool {
        identifier.hasPrefix(identifierPrefix) || identifier.hasPrefix(legacyPrefix)
    }
}

// MARK: - Werttypen

/// Reine Wertdaten einer Reise für die Erinnerungsplanung (kein @Model über Aktorgrenzen).
struct CruiseReminderInput: Sendable, Equatable {
    let key: String
    let title: String
    let startDate: Date
}

/// Reine Beschreibung einer geplanten Erinnerung. Sendable, damit der Abgleich ohne die
/// nicht-Sendable `UNNotificationRequest` über Aktorgrenzen laufen kann.
struct ReminderRequest: Sendable, Equatable {
    let identifier: String
    let title: String
    let body: String
    let categoryIdentifier: String
    let fireDate: Date
}

/// Erinnerungs-Einstellungen des Nutzers – gleiche Keys und Defaults wie in
/// `NotificationSettingsView` bzw. `NotificationService.scheduleAllReminders`.
struct ReminderSettings: Sendable, Equatable {
    let notifyBefore: Bool
    let notifyOnDay: Bool
    let daysBefore: Int

    static func current(defaults: UserDefaults = .standard) -> ReminderSettings {
        ReminderSettings(
            notifyBefore: defaults.object(forKey: "notifyBeforeCruise") as? Bool ?? true,
            notifyOnDay: defaults.object(forKey: "notifyOnCruiseDay") as? Bool ?? true,
            daysBefore: defaults.object(forKey: "reminderDaysBefore") as? Int ?? 7
        )
    }
}

// MARK: - Planner (rein)

/// Reine Planungslogik für Reise-Erinnerungen – ohne `UNUserNotificationCenter`, damit sie
/// vollständig unit-testbar bleibt.
enum ReminderPlanner {

    /// Soll-Menge aller Requests, indiziert über den Identifier. Requests, deren tatsächlicher
    /// Auslösezeitpunkt bereits vergangen ist, entstehen gar nicht erst.
    static func desiredRequests(
        for cruises: [CruiseReminderInput],
        settings: ReminderSettings,
        now: Date,
        calendar: Calendar = .current
    ) -> [String: ReminderRequest] {
        var result: [String: ReminderRequest] = [:]
        for cruise in cruises {
            if settings.notifyBefore,
               let request = beforeRequest(
                   for: cruise,
                   daysBefore: settings.daysBefore,
                   now: now,
                   calendar: calendar
               ) {
                result[request.identifier] = request
            }
            if settings.notifyOnDay,
               let request = departureRequest(for: cruise, now: now, calendar: calendar) {
                result[request.identifier] = request
            }
        }
        return result
    }

    /// Erinnerung `daysBefore` Tage vor Reisebeginn.
    static func beforeRequest(
        for cruise: CruiseReminderInput,
        daysBefore: Int,
        now: Date,
        calendar: Calendar = .current
    ) -> ReminderRequest? {
        let start = cruise.startDate
        guard let fireDate = calendar.date(byAdding: .day, value: -daysBefore, to: start),
              fireDate > now else { return nil }

        let startText = cruise.startDate.formatted(date: .abbreviated, time: .omitted)
        return ReminderRequest(
            identifier: ReminderIdentifier.make(cruiseKey: cruise.key, kind: .before),
            title: "Kreuzfahrt in \(daysBefore) Tagen! 🚢",
            body: "\(cruise.title) startet am \(startText)",
            categoryIdentifier: "CRUISE_REMINDER",
            fireDate: fireDate
        )
    }

    /// Erinnerung am Abreisetag um 8 Uhr morgens.
    static func departureRequest(
        for cruise: CruiseReminderInput,
        now: Date,
        calendar: Calendar = .current
    ) -> ReminderRequest? {
        var components = calendar.dateComponents([.year, .month, .day], from: cruise.startDate)
        components.hour = 8
        components.minute = 0

        guard let fireDate = calendar.date(from: components), fireDate > now else { return nil }

        return ReminderRequest(
            identifier: ReminderIdentifier.make(cruiseKey: cruise.key, kind: .departure),
            title: "Heute geht's los! ⚓️",
            body: "Deine Kreuzfahrt \"\(cruise.title)\" beginnt heute. Gute Reise!",
            categoryIdentifier: "CRUISE_DEPARTURE",
            fireDate: fireDate
        )
    }

    /// Reiner Abgleich Ist ↔ Soll. Nur von ShipTrip verwaltete Identifier werden entfernt;
    /// Legacy-Requests (`cruise-…`) sind nie Teil des Solls und fallen damit automatisch weg.
    ///
    /// **Replace statt Diff:** `add` enthält immer das komplette Soll, nicht nur die fehlenden
    /// Identifier. `UNUserNotificationCenter.add` ersetzt eine Pending Request mit gleichem
    /// Identifier, damit werden auch veraltete Trigger überschrieben – etwa wenn Startdatum
    /// oder `daysBefore` sich auf einem Zweitgerät geändert haben und per CloudKit ankommen.
    /// Ein Identifier-Vergleich allein würde solche Requests unangetastet stehen lassen.
    /// Der Abgleich bleibt idempotent: ein zweiter Lauf schreibt dieselben Requests erneut
    /// und entfernt nichts.
    static func plan(
        existing: Set<String>,
        desired: [String: ReminderRequest]
    ) -> (remove: [String], add: [ReminderRequest]) {
        let managed: Set<String> = existing.filter(ReminderIdentifier.isManaged)
        let remove = managed.subtracting(desired.keys).sorted()
        let add = desired.values.sorted { $0.identifier < $1.identifier }
        return (remove, add)
    }
}

// MARK: - Seam über UNUserNotificationCenter

/// Minimale Sicht auf `UNUserNotificationCenter` – nur die drei Operationen, die der Abgleich
/// braucht, damit er ohne echtes Notification-Center testbar ist.
protocol NotificationScheduling: Sendable {
    func pendingIdentifiers() async -> [String]
    func add(_ request: ReminderRequest) async throws
    func removePending(identifiers: [String]) async
}

/// Default-Implementierung auf dem echten System-Center.
struct SystemNotificationCenter: NotificationScheduling {

    func pendingIdentifiers() async -> [String] {
        let pending = await UNUserNotificationCenter.current().pendingNotificationRequests()
        return pending.map { $0.identifier }
    }

    func add(_ request: ReminderRequest) async throws {
        try await UNUserNotificationCenter.current().add(Self.makeSystemRequest(request))
    }

    func removePending(identifiers: [String]) async {
        UNUserNotificationCenter.current()
            .removePendingNotificationRequests(withIdentifiers: identifiers)
    }

    /// Übersetzt die reinen Wertdaten in eine `UNNotificationRequest`.
    static func makeSystemRequest(_ request: ReminderRequest) -> UNNotificationRequest {
        let content = UNMutableNotificationContent()
        content.title = request.title
        content.body = request.body
        content.sound = .default
        content.categoryIdentifier = request.categoryIdentifier

        let components = Calendar.current.dateComponents(
            [.year, .month, .day, .hour, .minute],
            from: request.fireDate
        )
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)

        return UNNotificationRequest(
            identifier: request.identifier,
            content: content,
            trigger: trigger
        )
    }
}

// MARK: - Reconcile beim App-Start

/// Gleicht die geplanten Erinnerungen beim App-Start gegen den Soll-Zustand ab: räumt
/// Altlasten aus dem instabilen Legacy-Schema ab und stellt sicher, dass pro Reise und Art
/// genau eine Pending Request existiert. Läuft bei jedem Start, ist idempotent und braucht
/// deshalb kein Migrationsflag.
enum NotificationReconciler {

    /// Einstiegspunkt aus der View: liest die Reisen synchron auf dem MainActor und gleicht
    /// danach über reine Wertdaten ab.
    @MainActor
    static func run(
        context: ModelContext,
        center: any NotificationScheduling = SystemNotificationCenter(),
        now: Date = Date()
    ) async {
        let cruises: [Cruise]
        do {
            cruises = try context.fetch(FetchDescriptor<Cruise>())
        } catch {
            let reason = error.localizedDescription
            logger.error("Reconcile: Fetch fehlgeschlagen – \(reason, privacy: .private)")
            return
        }

        // Demo-Reisen sind Attrappen und bekommen keine echten Pushes.
        let inputs = cruises
            .filter { !$0.isDemo }
            .map {
                CruiseReminderInput(
                    key: ReminderIdentifier.key(for: $0),
                    title: $0.title,
                    startDate: $0.startDate
                )
            }

        let isAuthorized = await NotificationService.shared.isAuthorized()
        await reconcile(
            cruises: inputs,
            settings: .current(),
            isAuthorized: isAuthorized,
            now: now,
            center: center
        )
    }

    /// Reiner Ablauf über den Seam – ohne SwiftData, für Tests direkt aufrufbar.
    /// Ohne Berechtigung ist das Soll leer: alles Verwaltete wird entfernt, nichts geplant.
    static func reconcile(
        cruises: [CruiseReminderInput],
        settings: ReminderSettings,
        isAuthorized: Bool,
        now: Date,
        center: any NotificationScheduling
    ) async {
        let existing = Set(await center.pendingIdentifiers())
        let desired: [String: ReminderRequest] = isAuthorized
            ? ReminderPlanner.desiredRequests(for: cruises, settings: settings, now: now)
            : [:]
        let plan = ReminderPlanner.plan(existing: existing, desired: desired)

        // Erst anlegen, dann entfernen: schlägt ein `add` fehl, ist die bestehende Erinnerung
        // noch da. Umgekehrt stünde der Nutzer nach einem Fehler ganz ohne Erinnerung da.
        for request in plan.add {
            do {
                try await center.add(request)
            } catch {
                logAddFailure(identifier: request.identifier, error: error)
            }
        }

        if !plan.remove.isEmpty {
            await center.removePending(identifiers: plan.remove)
        }
    }

    /// Fehlgeschlagene Requests werden geloggt, nicht verschluckt.
    private static func logAddFailure(identifier: String, error: Error) {
        let reason = error.localizedDescription
        logger.error("Reconcile: \(identifier, privacy: .public) – \(reason, privacy: .private)")
    }
}
