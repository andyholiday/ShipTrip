//
//  MapSelectionPlanner.swift
//  ShipTrip
//
//  Ausgelagert aus MapView.swift (F01, swift-standards Datei-Größenlimit) — reine
//  Verschiebung, keine Verhaltensänderung.
//

import Foundation

// MARK: - Stopp-Auswahl

/// Reine Toggle-Logik für `selectedStopID`: Tap auf einen bereits ausgewählten Stopp hebt die
/// Auswahl auf (Callout schließt), Tap auf einen anderen Stopp wechselt die Auswahl.
enum MapSelectionPlanner {
    static func toggled(current: UUID?, tapped: UUID) -> UUID? {
        current == tapped ? nil : tapped
    }

    /// Räumt die Stopp-Auswahl beim Wechsel in den Welt-Zoom auf: Im Welt-Zoom gibt es nur
    /// Dots ohne Callout, eine bestehende Auswahl aus dem Reise-Zoom darf dort nicht als
    /// Phantom-Callout überleben (und würde sonst auch dem späteren B4.3b-2-Sheet einen
    /// Selektionszustand vortäuschen, der auf der Karte gar nicht mehr sichtbar ist).
    static func selection(_ current: UUID?, afterBucketChangeTo bucket: MapZoomBucket) -> UUID? {
        bucket == .world ? nil : current
    }
}
