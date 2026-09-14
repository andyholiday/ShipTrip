//
//  CalendarSyncPreferences.swift
//  ShipTrip
//

import Foundation

/// Die Präferenz-Schlüssel der Kalender-Spiegelung und ihre Defaults.
///
/// Eigene Datei, seit der Sync-Umfang einen Default hat, den mehrere Stellen
/// lesen (Service, `CalendarSyncObserver`, Einstellungen): Der Default steht
/// damit an genau einem Ort und nicht als Literal an jedem `@AppStorage`.
enum CalendarSyncPreferences {
    static let enabledKey = "calendarSyncEnabled"
    static let calendarIdentifierKey = "calendarSyncCalendarIdentifier"
    static let modeKey = "calendarSyncMode"

    static func isEnabled(in defaults: UserDefaults) -> Bool {
        defaults.bool(forKey: enabledKey)
    }

    static func calendarIdentifier(in defaults: UserDefaults) -> String {
        defaults.string(forKey: calendarIdentifierKey) ?? ""
    }

    /// Der **einzige** Ort, an dem der Default des Sync-Umfangs steht.
    /// Alles andere (Einstellungen, `CalendarSyncObserver`) liest hierüber.
    static func mode(in defaults: UserDefaults) -> CalendarSyncMode {
        CalendarSyncMode(rawValue: defaults.string(forKey: modeKey) ?? "") ?? .itineraryOnly
    }

    static var isEnabled: Bool { isEnabled(in: .standard) }

    static var calendarIdentifier: String { calendarIdentifier(in: .standard) }

    static var mode: CalendarSyncMode { mode(in: .standard) }
}
