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

    /// Räumt die im Nutzer-Kalender gespiegelten Termine ab und setzt danach
    /// die Präferenzen zurück (`AppPreferencesReset`).
    ///
    /// Die Reihenfolge ist verbindlich: Der Präferenz-Reset legt den
    /// Sync-Schalter um, und danach räumt niemand die Termine mehr weg — sie
    /// blieben dauerhaft im Kalender des Nutzers stehen.
    ///
    /// Das Löschen ist bewusst „best effort" (`try?`): Ohne Kalenderzugriff
    /// gibt es nichts abzuräumen, und ein fehlender Zugriff darf den Reset
    /// nicht blockieren.
    static func run(calendarSync: CalendarSyncService, defaults: UserDefaults) {
        try? calendarSync.removeAllManagedEvents()
        AppPreferencesReset.run(in: defaults)
    }
}
