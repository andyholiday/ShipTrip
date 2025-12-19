//
//  NotificationService.swift
//  ShipTrip
//
//  Created by ShipTrip on 18.12.25.
//

import Foundation
import UserNotifications

/// Service für lokale Push-Benachrichtigungen
class NotificationService {
    
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
            print("Notification authorization error: \(error)")
            return false
        }
    }
    
    /// Prüft ob Benachrichtigungen erlaubt sind
    func isAuthorized() async -> Bool {
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        return settings.authorizationStatus == .authorized
    }
    
    // MARK: - Cruise Reminders
    
    /// Plant Erinnerung für eine Kreuzfahrt
    func scheduleCruiseReminder(for cruise: Cruise, daysBefore: Int = 7) async {
        guard await isAuthorized() else { return }
        
        // Berechne Erinnerungsdatum
        let reminderDate = Calendar.current.date(
            byAdding: .day,
            value: -daysBefore,
            to: cruise.startDate
        )
        
        guard let date = reminderDate, date > Date() else { return }
        
        let content = UNMutableNotificationContent()
        content.title = "Kreuzfahrt in \(daysBefore) Tagen! 🚢"
        content.body = "\(cruise.title) startet am \(cruise.startDate.formatted(date: .abbreviated, time: .omitted))"
        content.sound = .default
        content.categoryIdentifier = "CRUISE_REMINDER"
        
        // Erstelle Trigger für das Datum
        let components = Calendar.current.dateComponents(
            [.year, .month, .day, .hour, .minute],
            from: date
        )
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
        
        // Eindeutige ID pro Kreuzfahrt und Erinnerungstyp
        let identifier = "cruise-\(cruise.persistentModelID)-\(daysBefore)days"
        
        let request = UNNotificationRequest(
            identifier: identifier,
            content: content,
            trigger: trigger
        )
        
        do {
            try await UNUserNotificationCenter.current().add(request)
            print("Scheduled reminder for \(cruise.title) on \(date)")
        } catch {
            print("Failed to schedule notification: \(error)")
        }
    }
    
    /// Plant Erinnerung am Abreisetag
    func scheduleDepartureReminder(for cruise: Cruise) async {
        guard await isAuthorized() else { return }
        guard cruise.startDate > Date() else { return }
        
        let content = UNMutableNotificationContent()
        content.title = "Heute geht's los! ⚓️"
        content.body = "Deine Kreuzfahrt \"\(cruise.title)\" beginnt heute. Gute Reise!"
        content.sound = .default
        content.categoryIdentifier = "CRUISE_DEPARTURE"
        
        // 8 Uhr morgens am Abreisetag
        var components = Calendar.current.dateComponents(
            [.year, .month, .day],
            from: cruise.startDate
        )
        components.hour = 8
        components.minute = 0
        
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
        let identifier = "cruise-\(cruise.persistentModelID)-departure"
        
        let request = UNNotificationRequest(
            identifier: identifier,
            content: content,
            trigger: trigger
        )
        
        do {
            try await UNUserNotificationCenter.current().add(request)
        } catch {
            print("Failed to schedule departure notification: \(error)")
        }
    }
    
    /// Entfernt alle Erinnerungen für eine Kreuzfahrt
    func removeReminders(for cruise: Cruise) {
        let identifiers = [
            "cruise-\(cruise.persistentModelID)-7days",
            "cruise-\(cruise.persistentModelID)-1days",
            "cruise-\(cruise.persistentModelID)-departure"
        ]
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: identifiers)
    }
    
    /// Plant alle Standard-Erinnerungen für eine Kreuzfahrt
    func scheduleAllReminders(for cruise: Cruise) async {
        await scheduleCruiseReminder(for: cruise, daysBefore: 7)
        await scheduleCruiseReminder(for: cruise, daysBefore: 1)
        await scheduleDepartureReminder(for: cruise)
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
