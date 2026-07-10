//
//  MKCoordinateRegion+Fit.swift
//  ShipTrip
//
//  Ausgelagert aus MapView.swift (F01, swift-standards Datei-Größenlimit) — reine
//  Verschiebung, keine Verhaltensänderung. Treibt `zoomTo(coordinates:)` in MapView.swift.
//

import MapKit
import CoreLocation

extension MKCoordinateRegion {
    /// `minimumSpan` ist konfigurierbar (Fix-Runde 2, F01a): der Default `2.0` bleibt für alle
    /// bestehenden Call-Sites unverändert (Routen-Übersicht, Einzel-Stopp-Zoom vom Sheet).
    /// `zoomTo(coordinates:minimumSpan:)` in `MapView.swift` nutzt für den Cluster-Auflöse-Zoom
    /// einen deutlich kleineren Wert (Hafen-Level, siehe `MapClusterPlanner.clusterZoomMinimumSpan`)
    /// — der bisherige feste 2°-Floor hätte geografisch sehr nahe Cluster-Mitglieder nie weit
    /// genug getrennt, wodurch der Cluster nach dem Zoom bestehen blieb (Endlos-Tap-Loop ohne
    /// sichtbaren Effekt).
    init(coordinates: [CLLocationCoordinate2D], minimumSpan: Double = 2.0) {
        guard !coordinates.isEmpty else {
            self = MKCoordinateRegion()
            return
        }

        let minLat = coordinates.map(\.latitude).min()!
        let maxLat = coordinates.map(\.latitude).max()!
        let minLon = coordinates.map(\.longitude).min()!
        let maxLon = coordinates.map(\.longitude).max()!

        let center = CLLocationCoordinate2D(
            latitude: (minLat + maxLat) / 2,
            longitude: (minLon + maxLon) / 2
        )

        // Berechne Span mit Padding und Minimum
        var latDelta = (maxLat - minLat) * 1.5
        var lonDelta = (maxLon - minLon) * 1.5

        // Minimum Span für einzelne Punkte oder sehr kleine Regionen
        latDelta = max(latDelta, minimumSpan)
        lonDelta = max(lonDelta, minimumSpan)

        // Maximum nur grob begrenzen, damit die Default-Karte mehrere Reisen weltweit zeigen kann.
        latDelta = min(latDelta, 120.0)
        lonDelta = min(lonDelta, 320.0)

        let span = MKCoordinateSpan(
            latitudeDelta: latDelta,
            longitudeDelta: lonDelta
        )

        self = MKCoordinateRegion(center: center, span: span)
    }
}
