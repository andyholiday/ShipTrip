//
//  AppReset.swift
//  ShipTrip
//
//  Die Aufraeumschritte von „App zurücksetzen" (Einstellungen → Daten
//  verwalten), die ausserhalb des SwiftData-Stores liegen. Bewusst als eigene,
//  UI-freie Stelle: damit die Reihenfolge dieser Schritte pruefbar ist und
//  nicht im Lösch-Pfad einer View versteckt liegt.
//

import Foundation

/// „App zurücksetzen" jenseits des Stores.
@MainActor
enum AppReset {

    /// Setzt die Nutzer-Präferenzen zurück (`AppPreferencesReset`).
    ///
    /// `calendarSync` ist der Zugang zu den im Nutzer-Kalender gespiegelten
    /// Terminen — abgeräumt werden sie hier **nicht**; genau das hält der
    /// Repro-Test fest.
    static func run(calendarSync: CalendarSyncService, defaults: UserDefaults) {
        AppPreferencesReset.run(in: defaults)
    }
}
