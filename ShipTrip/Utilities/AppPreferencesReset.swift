//
//  AppPreferencesReset.swift
//  ShipTrip
//
//  Der UserDefaults-Anteil von „App zurücksetzen" (Einstellungen →
//  Daten verwalten). Bewusst als eigene, UI-freie Stelle: die Liste der
//  Präferenz-Schlüssel liegt damit an einem Ort und nicht verteilt im
//  Lösch-Pfad einer View.
//

import Foundation

/// Setzt die Nutzer-Präferenzen auf den Auslieferungszustand zurück.
enum AppPreferencesReset {

    /// Alle Präferenz-Schlüssel, die „App zurücksetzen" entfernt. Die Literale
    /// spiegeln die `@AppStorage`-Schlüssel aus `SettingsView`, `MainTabView`
    /// und `CruiseFormView`; alles mit eigener Konstante wird von dort bezogen.
    ///
    /// Bewusst **nicht** enthalten: die versionierten Migrations-Flags
    /// (`IdBackfill`, `ShippingLineCatalogDedup`) und die Zuordnung bereits
    /// angelegter Kalendertermine — das ist Buchhaltung, keine Einstellung.
    static let removableKeys: [String] = [
        "colorScheme",
        "notifyBeforeCruise",
        "notifyOnCruiseDay",
        "reminderDaysBefore",
        "hasShownNotificationDeniedHint",
        CalendarSyncPreferences.enabledKey,
        CalendarSyncPreferences.calendarIdentifierKey,
        CalendarSyncPreferences.modeKey
    ]

    /// Entfernt die Präferenzen und stellt den Erststart-Schalter zurück.
    ///
    /// Der Onboarding-Schlüssel wird bewusst auf `false` **gesetzt** statt
    /// entfernt: ein fehlender Schlüssel gilt als Bestandsinstallation und
    /// würde beim nächsten Start still abgehakt (siehe `OnboardingPresentation`).
    static func run(in defaults: UserDefaults) {
        for key in removableKeys {
            defaults.removeObject(forKey: key)
        }
        OnboardingPresentation.requestReplay(in: defaults)
    }
}
