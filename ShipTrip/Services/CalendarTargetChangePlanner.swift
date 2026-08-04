//
//  CalendarTargetChangePlanner.swift
//  ShipTrip
//

import Foundation

/// Entscheidet, wie auf eine im Zielkalender-Picker geänderte Auswahl reagiert wird.
enum CalendarTargetChangePlanner {

    // MARK: - Entscheidung

    enum Decision: Equatable {
        /// Auswahl unverändert oder leer – nichts zu tun.
        case ignore
        /// Auswahl direkt übernehmen und synchronisieren.
        case apply
        /// Bestehende Termine müssen umgezogen werden – erst nach Bestätigung.
        case confirmMigration
    }

    /// - Parameters:
    ///   - current: Bisher gespeicherter Zielkalender.
    ///   - selected: Im Picker gewählter Kalender.
    ///   - isSyncEnabled: Ob die Kalender-Spiegelung aktiv ist.
    ///   - hasManagedEvents: Ob ShipTrip bereits Termine verwaltet.
    static func decide(
        current: String,
        selected: String,
        isSyncEnabled: Bool,
        hasManagedEvents: Bool
    ) -> Decision {
        guard !selected.isEmpty, selected != current else { return .ignore }
        guard isSyncEnabled, hasManagedEvents else { return .apply }
        return .confirmMigration
    }
}
