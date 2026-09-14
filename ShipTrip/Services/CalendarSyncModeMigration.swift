//
//  CalendarSyncModeMigration.swift
//  ShipTrip
//

import Foundation

/// Einmalige Bestands-Migration des Sync-Umfangs auf die neue Auswahl (1.8.7).
///
/// Bis 1.8.6 gab es nur `tripOnly` (stiller Default) und `tripAndItinerary`.
/// Ab 1.8.7 ist `itineraryOnly` der Default. Ohne Migration verlöre ein
/// Bestandsnutzer, der den Umfang nie angefasst hat, beim ersten Sync nach dem
/// Update seinen Ganzreise-Termin — nichts soll ungefragt aus dem Kalender
/// verschwinden.
///
/// Der Bestandsnachweis läuft bewusst **nur** über das persistierte Mapping:
/// EventKit-Predicates sind auf vier Jahre gekappt und würden ältere Reisen
/// übersehen.
enum CalendarSyncModeMigration {

    /// Merker, dass die Entscheidung gefallen ist.
    ///
    /// Bewusst kein Präferenz-Schlüssel: „App zurücksetzen" lässt versionierte
    /// Migrations-Flags stehen (siehe `AppPreferencesReset`).
    static let markerKey = "calendarSyncModeMigratedV2"

    /// Ob die Entscheidung schon gefallen ist. Billige Vorabfrage, damit sich
    /// Aufrufer den Bestands-Scan sparen können.
    static func isSettled(in defaults: UserDefaults) -> Bool {
        defaults.bool(forKey: markerKey)
    }

    /// Idempotent — darf vor jedem Sync und vor jedem Öffnen der
    /// Einstellungen laufen.
    ///
    /// - Parameters:
    ///   - defaults: Präferenz-Speicher des Nutzers.
    ///   - hasCalendarAccess: Ohne Zugriff lässt sich der Bestand nicht
    ///     prüfen. Dann fällt keine Entscheidung und der Merker bleibt aus,
    ///     damit der nächste Lauf es nachholt.
    ///   - hasLiveTripEvent: Ob zu einem Mapping-Schlüssel mit Suffix `/trip`
    ///     noch ein Termin im Kalender steht.
    static func run(
        in defaults: UserDefaults,
        hasCalendarAccess: Bool,
        hasLiveTripEvent: Bool
    ) {
        guard !isSettled(in: defaults) else { return }

        // Wer den Umfang schon einmal bewusst gewählt hat, behält ihn.
        guard defaults.string(forKey: CalendarSyncPreferences.modeKey) == nil else {
            defaults.set(true, forKey: markerKey)
            return
        }
        guard hasCalendarAccess else { return }

        let mode: CalendarSyncMode = hasLiveTripEvent ? .tripOnly : .itineraryOnly
        defaults.set(mode.rawValue, forKey: CalendarSyncPreferences.modeKey)
        defaults.set(true, forKey: markerKey)
    }
}
