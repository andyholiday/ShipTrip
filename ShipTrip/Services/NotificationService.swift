//
//  NotificationService.swift
//  ShipTrip
//
//  Created by ShipTrip on 18.12.25.
//

import Foundation
import UserNotifications
import OSLog

private let logger = Logger(subsystem: "com.andre.ShipTrip", category: "notifications")

/// Service für lokale Push-Benachrichtigungen
final class NotificationService: Sendable {
    
    static let shared = NotificationService()
    
    private init() {}
    
    // MARK: - Permission
    
    /// Fragt Benachrichtigungs-Berechtigung an
    func requestAuthorization() async -> Bool {
        do {
            let granted = try await UNUserNotificationCenter.current()
                .requestAuthorization(options: [.alert, .badge, .sound])
            return granted
        } catch {
            logger.error("Notification authorization error: \(error, privacy: .private)")
            return false
        }
    }
    
    /// Prüft ob Benachrichtigungen erlaubt sind (inkl. provisional/ephemeral – dort dürfen
    /// Notifications ebenfalls zugestellt werden, nur .denied/.notDetermined blocken)
    func isAuthorized() async -> Bool {
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        switch settings.authorizationStatus {
        case .authorized, .provisional, .ephemeral:
            return true
        default:
            return false
        }
    }

    /// Aktueller System-Berechtigungsstatus (für kontextuelle Anfrage vor dem nativen Prompt)
    func authorizationStatus() async -> UNAuthorizationStatus {
        await UNUserNotificationCenter.current().notificationSettings().authorizationStatus
    }

    /// Ob der Nutzer Erinnerungen überhaupt möchte (Settings-Toggles), unabhängig von der
    /// System-Berechtigung. Gleiche Defaults/Keys wie `scheduleAllReminders`.
    var remindersEnabledInSettings: Bool {
        let settings = ReminderSettings.current()
        return settings.notifyBefore || settings.notifyOnDay
    }

    // MARK: - Cruise Reminders

    /// Plant Erinnerung anhand reiner Wertdaten (kein @Model-Objekt über Aktorgrenzen).
    /// `cruiseID` ist der stabile Reise-Schlüssel aus `ReminderIdentifier.key(for:)`.
    func scheduleCruiseReminder(cruiseID: String, title: String, startDate: Date, daysBefore: Int) async {
        guard await isAuthorized() else { return }

        let input = CruiseReminderInput(key: cruiseID, title: title, startDate: startDate)
        guard let request = ReminderPlanner.beforeRequest(
            for: input,
            daysBefore: daysBefore,
            now: Date()
        ) else { return }

        await add(request)
    }

    /// Plant Erinnerung am Abreisetag anhand reiner Wertdaten
    func scheduleDepartureReminder(cruiseID: String, title: String, startDate: Date) async {
        guard await isAuthorized() else { return }

        let input = CruiseReminderInput(key: cruiseID, title: title, startDate: startDate)
        guard let request = ReminderPlanner.departureRequest(for: input, now: Date()) else {
            return
        }

        await add(request)
    }

    /// Übergibt eine geplante Erinnerung an das System-Center; Fehler werden geloggt.
    private func add(_ request: ReminderRequest) async {
        do {
            try await SystemNotificationCenter().add(request)
            logger.info("Scheduled reminder \(request.identifier, privacy: .public)")
        } catch {
            logger.error("Failed to schedule notification: \(error, privacy: .private)")
        }
    }

    /// Entfernt alle Erinnerungen für eine Kreuzfahrt (prefix-basiert, nur Sendable-Werte)
    func removeReminders(cruiseID: String) async {
        let prefix = ReminderIdentifier.prefix(forCruiseKey: cruiseID)
        let pending = await UNUserNotificationCenter.current().pendingNotificationRequests()
        let toRemove = pending.map { $0.identifier }.filter { $0.hasPrefix(prefix) }
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: toRemove)
    }

    /// Plant Erinnerungen gemäß Nutzer-Einstellungen aus UserDefaults (nur Sendable-Werte)
    func scheduleAllReminders(cruiseID: String, title: String, startDate: Date) async {
        let settings = ReminderSettings.current()

        if settings.notifyBefore {
            await scheduleCruiseReminder(
                cruiseID: cruiseID,
                title: title,
                startDate: startDate,
                daysBefore: settings.daysBefore
            )
        }
        if settings.notifyOnDay {
            await scheduleDepartureReminder(cruiseID: cruiseID, title: title, startDate: startDate)
        }
    }
    
    // MARK: - Management
    
    /// Entfernt alle geplanten Benachrichtigungen
    func removeAllPendingNotifications() {
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
    }
    
    /// Gibt alle geplanten Benachrichtigungen zurück
    func getPendingNotifications() async -> [UNNotificationRequest] {
        await UNUserNotificationCenter.current().pendingNotificationRequests()
    }
}
