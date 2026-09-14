//
//  CalendarMigrationCoordinator.swift
//  ShipTrip
//

import Foundation

/// Ergebnis eines Kalenderwechsels mit Umzug der bestehenden Termine.
enum CalendarMigrationOutcome {
    /// Umzug erfolgreich, `count` Einträge liegen im neuen Kalender.
    case migrated(Int)
    /// Der Kalenderzugriff fehlt; der bisherige Zielkalender steht wieder.
    case accessDenied
    /// Umzug gescheitert, der Bestand im bisherigen Kalender ist wiederhergestellt.
    case rolledBack(any Error)
    /// Umzug gescheitert **und** der Bestand ließ sich nicht wiederherstellen.
    case rollbackFailed(migration: any Error, rollback: any Error)
}

/// Führt den Wechsel des Zielkalenders inklusive Rollback aus.
///
/// Eigener Typ statt View-Logik: Der Rollback ist die einzige Absicherung
/// gegen Datenverlust beim Kalenderwechsel und muss ohne SwiftUI prüfbar sein.
/// Der Aufrufer bekommt das Ergebnis als Fall zurück und entscheidet, was er
/// dem Nutzer zeigt — ein gescheiterter Rollback bleibt so nicht stumm.
@MainActor
struct CalendarMigrationCoordinator {

    private let service: CalendarSyncService
    private let defaults: UserDefaults

    init(service: CalendarSyncService = .shared, defaults: UserDefaults = .standard) {
        self.service = service
        self.defaults = defaults
    }

    /// Stellt den Zielkalender um und überträgt die verwalteten Termine.
    ///
    /// Scheitert die Übertragung, wird der bisherige Kalender wieder
    /// eingestellt und der Bestand aktiv neu synchronisiert: `calendarIdentifier`
    /// ist nach dem Rollback netto unverändert, `CalendarSyncObserver` feuert
    /// deshalb nicht von selbst.
    func migrate(to identifier: String, cruises: [Cruise]) -> CalendarMigrationOutcome {
        let previousIdentifier = CalendarSyncPreferences.calendarIdentifier(in: defaults)
        setCalendarIdentifier(identifier)

        do {
            let count = try service.migrateManagedEvents(cruises: cruises)
            return .migrated(count)
        } catch CalendarSyncError.accessDenied {
            // Ohne Zugriff gibt es nichts wiederherzustellen — der Aufrufer
            // schickt den Nutzer in die Systemeinstellungen.
            setCalendarIdentifier(previousIdentifier)
            return .accessDenied
        } catch {
            setCalendarIdentifier(previousIdentifier)
            do {
                try service.synchronize(cruises: cruises)
                return .rolledBack(error)
            } catch let rollbackError {
                return .rollbackFailed(migration: error, rollback: rollbackError)
            }
        }
    }

    private func setCalendarIdentifier(_ identifier: String) {
        defaults.set(identifier, forKey: CalendarSyncPreferences.calendarIdentifierKey)
    }
}
