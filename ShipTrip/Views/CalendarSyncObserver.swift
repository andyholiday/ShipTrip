//
//  CalendarSyncObserver.swift
//  ShipTrip
//

import SwiftData
import SwiftUI

/// Hält die optional aktivierte Kalender-Spiegelung bei App-Start und nach
/// Reiseänderungen aktuell. Fehler werden in der Einstellungsansicht erklärt.
struct CalendarSyncObserver: View {
    @Query(sort: \Cruise.startDate) private var cruises: [Cruise]
    @AppStorage(CalendarSyncPreferences.enabledKey) private var isEnabled = false
    @AppStorage(CalendarSyncPreferences.calendarIdentifierKey) private var calendarIdentifier = ""
    /// Nur Auslöser für den Neulauf, kein Leseort des Umfangs: Der Default
    /// steht ausschließlich in `CalendarSyncPreferences.mode(in:)`, hier
    /// bedeutet der leere Wert schlicht „noch nichts gespeichert".
    @AppStorage(CalendarSyncPreferences.modeKey) private var modeRawValue = ""
    @Environment(\.scenePhase) private var scenePhase

    private var syncToken: String {
        let cruiseToken = cruises.map {
            "\($0.id.uuidString):\($0.updatedAt.timeIntervalSince1970)"
        }.joined(separator: "|")
        return "\(isEnabled):\(calendarIdentifier):\(modeRawValue):\(scenePhase):\(cruiseToken)"
    }

    var body: some View {
        Color.clear
            .frame(width: 0, height: 0)
            .accessibilityHidden(true)
            .task(id: syncToken) {
                guard isEnabled, scenePhase == .active else { return }
                _ = try? CalendarSyncService.shared.synchronize(cruises: cruises)
            }
    }
}
