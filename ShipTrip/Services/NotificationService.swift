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
        let notifyBefore = UserDefaults.standard.object(forKey: "notifyBeforeCruise") as? Bool ?? true
        let notifyOnDay = UserDefaults.standard.object(forKey: "notifyOnCruiseDay") as? Bool ?? true
        return notifyBefore || notifyOnDay
    }

    // MARK: - Cruise Reminders

    /// Plant Erinnerung anhand reiner Wertdaten (kein @Model-Objekt über Aktorgrenzen)
    func scheduleCruiseReminder(cruiseID: String, title: String, startDate: Date, daysBefore: Int) async {
        guard await isAuthorized() else { return }

        // Berechne Erinnerungsdatum
        let reminderDate = Calendar.current.date(
            byAdding: .day,
            value: -daysBefore,
            to: startDate
        )

        guard let date = reminderDate, date > Date() else { return }

        let content = UNMutableNotificationContent()
        content.title = "Kreuzfahrt in \(daysBefore) Tagen! 🚢"
        content.body = "\(title) startet am \(startDate.formatted(date: .abbreviated, time: .omitted))"
        content.sound = .default
        content.categoryIdentifier = "CRUISE_REMINDER"

        // Erstelle Trigger für das Datum
        let components = Calendar.current.dateComponents(
            [.year, .month, .day, .hour, .minute],
            from: date
        )
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)

        // Eindeutige ID pro Kreuzfahrt und Erinnerungstyp
        let identifier = "cruise-\(cruiseID)-\(daysBefore)days"

        let request = UNNotificationRequest(
            identifier: identifier,
            content: content,
            trigger: trigger
        )

        do {
            try await UNUserNotificationCenter.current().add(request)
            logger.info("Scheduled reminder for \(title, privacy: .private) on \(date, privacy: .private)")
        } catch {
            logger.error("Failed to schedule notification: \(error, privacy: .private)")
        }
    }

    /// Plant Erinnerung am Abreisetag anhand reiner Wertdaten
    func scheduleDepartureReminder(cruiseID: String, title: String, startDate: Date) async {
        guard await isAuthorized() else { return }
        guard startDate > Date() else { return }

        let content = UNMutableNotificationContent()
        content.title = "Heute geht's los! ⚓️"
        content.body = "Deine Kreuzfahrt \"\(title)\" beginnt heute. Gute Reise!"
        content.sound = .default
        content.categoryIdentifier = "CRUISE_DEPARTURE"

        // 8 Uhr morgens am Abreisetag
        var components = Calendar.current.dateComponents(
            [.year, .month, .day],
            from: startDate
        )
        components.hour = 8
        components.minute = 0

        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
        let identifier = "cruise-\(cruiseID)-departure"

        let request = UNNotificationRequest(
            identifier: identifier,
            content: content,
            trigger: trigger
        )

        do {
            try await UNUserNotificationCenter.current().add(request)
        } catch {
            logger.error("Failed to schedule departure notification: \(error, privacy: .private)")
        }
    }

    /// Entfernt alle Erinnerungen für eine Kreuzfahrt (prefix-basiert, nur Sendable-Werte)
    func removeReminders(cruiseID: String) async {
        let prefix = "cruise-\(cruiseID)-"
        let pending = await UNUserNotificationCenter.current().pendingNotificationRequests()
        let toRemove = pending.map { $0.identifier }.filter { $0.hasPrefix(prefix) }
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: toRemove)
    }

    /// Plant Erinnerungen gemäß Nutzer-Einstellungen aus UserDefaults (nur Sendable-Werte)
    func scheduleAllReminders(cruiseID: String, title: String, startDate: Date) async {
        let notifyBefore = UserDefaults.standard.object(forKey: "notifyBeforeCruise") as? Bool ?? true
        let notifyOnDay = UserDefaults.standard.object(forKey: "notifyOnCruiseDay") as? Bool ?? true
        let daysBefore = UserDefaults.standard.object(forKey: "reminderDaysBefore") as? Int ?? 7

        if notifyBefore {
            await scheduleCruiseReminder(cruiseID: cruiseID, title: title, startDate: startDate, daysBefore: daysBefore)
        }
        if notifyOnDay {
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
