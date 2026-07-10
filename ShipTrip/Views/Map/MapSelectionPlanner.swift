//
//  MapSelectionPlanner.swift
//  ShipTrip
//
//  Ausgelagert aus MapView.swift (F01, swift-standards Datei-Größenlimit) — reine
//  Verschiebung, keine Verhaltensänderung.
//

import Foundation
import CoreLocation

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

    /// Räumt die Stopp-Auswahl auf, wenn der aktuell selektierte Stop Teil eines Overlap-
    /// Clusters geworden ist (Fix-Runde 2, F02). Zwei Fälle zählen als „geclustert": der Stop
    /// ist jetzt `suppressed` (aus dem `ForEach` gefiltert — für ihn wird gar kein Marker mehr
    /// gerendert, ein Callout dafür wäre ein unsichtbares Phantom, aber `selectedStopID` bliebe
    /// sonst hängen), oder der Stop ist selbst ein Cluster-Primary mit ≥2 Mitgliedern (sein
    /// Tap-Ziel ist jetzt „Cluster auflösen" statt Callout/Sheet, ein stehender Callout wäre
    /// inhaltlich falsch — siehe `MapClusterPlanner.tapOutcome`). Beide Fälle sind unabhängig
    /// vom Kamera-`position`-State, ein Aufräumen hier löst also keinen erneuten
    /// `.onMapCameraChange`-Durchlauf aus (kein Loop-Risiko).
    ///
    /// `suppressCleanup` (Fix-Runde 3, P1): eine FRISCHE, vom Nutzer gerade eben getroffene
    /// Selektion über den Sheet-Row-Tap (`onStopTap` → `zoomTo`) darf vom NÄCHSTEN
    /// `.onMapCameraChange(.onEnd)`-Recompute nicht sofort wieder weggeräumt werden — nur weil
    /// der frisch gewählte Stop dabei zufällig als suppressed/Primary erkannt wird (z. B. weil
    /// der Default-2°-Zoom vom Sheet-Row-Tap einen Nachbar-Stop mit ins Bild holt). Der
    /// Aufrufer setzt dafür ein One-Shot-Flag, das GENAU EINEN Recompute überspringt; danach
    /// greift die Bereinigung wieder normal für echte Stale-Fälle (Kamera manuell bewegt, Stop
    /// rutscht nachträglich in einen Cluster). Ein regulärer Marker-Tap (inkl. Unresolvable-
    /// Cluster-Fallback) setzt dieses Flag NICHT — er löst keinen Kamera-Move aus und braucht
    /// den Schutz daher nicht (Fix-Runde 4, Codex-Auflage).
    static func selection(
        _ current: UUID?,
        afterClusteringWith suppressedStopIDs: Set<UUID>,
        clusterMemberCoordinates: [UUID: [CLLocationCoordinate2D]],
        suppressCleanup: Bool
    ) -> UUID? {
        guard !suppressCleanup else { return current }
        guard let current else { return nil }
        if suppressedStopIDs.contains(current) { return nil }
        if let members = clusterMemberCoordinates[current], members.count > 1 { return nil }
        return current
    }
}
