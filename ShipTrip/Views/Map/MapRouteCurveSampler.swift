//
//  MapRouteCurveSampler.swift
//  ShipTrip
//
//  Kurvige Routendarstellung für das Karten-Redesign v2 „Journal Atlas" (B4.3b-3).
//

import CoreLocation

/// Interpoliert eine flüssige Catmull-Rom-Spline durch die geordneten Hafen-Koordinaten einer
/// Route, damit `MapPolyline` keine geraden Segmente mehr zeichnet. Rein und SwiftUI-frei,
/// isoliert testbar (Muster `MapMarkerPlanner`).
enum RouteCurveSampler {
    /// Liefert eine interpolierte Punktfolge für eine flüssige Kurve durch alle `waypoints`. Die
    /// Kurve läuft garantiert exakt durch jeden Original-Wegpunkt (Catmull-Rom-Eigenschaft) —
    /// wichtig, weil sonst Pins optisch neben statt auf der Linie sitzen würden.
    ///
    /// Randsegmente (Anfang/Ende) verwenden den jeweils ersten/letzten Wegpunkt doppelt als
    /// zusätzlichen Stützpunkt statt eines echten Nachbarn (Standard-Trick für offene
    /// Catmull-Rom-Kurven ohne Endpunkt-Tangente). Bei genau 2 Wegpunkten degeneriert die Formel
    /// dadurch exakt zu einer linearen Interpolation — kein Sonderfall im Code nötig.
    ///
    /// - Parameters:
    ///   - waypoints: geordnete, bereits validierte Koordinaten (siehe `MapMarkerPlanner.validPorts`).
    ///   - pointsPerSegment: Stützpunkte je Segment. Der Aufrufer deckelt dies bereits auf das
    ///     Gesamt-Punktebudget (Spec: `clamp(280 / gesamtSegmente, 6, 24)`); hier zusätzlich
    ///     defensiv auf mindestens 1 begrenzt, damit ein ungültiger Wert nicht zu einer leeren
    ///     Kurve führt.
    /// - Returns: leer bei 0 Wegpunkten, `waypoints` unverändert bei genau 1 Wegpunkt, sonst
    ///   `(waypoints.count - 1) * pointsPerSegment + 1` Punkte ohne doppelte Segment-Übergänge.
    static func curve(
        through waypoints: [CLLocationCoordinate2D],
        pointsPerSegment: Int
    ) -> [CLLocationCoordinate2D] {
        guard waypoints.count > 1 else { return waypoints }

        let steps = max(pointsPerSegment, 1)
        let extended = [waypoints[0]] + waypoints + [waypoints[waypoints.count - 1]]

        var result: [CLLocationCoordinate2D] = []
        result.reserveCapacity((waypoints.count - 1) * steps + 1)

        for segment in 0..<(waypoints.count - 1) {
            let p0 = extended[segment]
            let p1 = extended[segment + 1]
            let p2 = extended[segment + 2]
            let p3 = extended[segment + 3]

            for step in 0..<steps {
                let t = Double(step) / Double(steps)
                result.append(
                    CLLocationCoordinate2D(
                        latitude: catmullRom(p0.latitude, p1.latitude, p2.latitude, p3.latitude, t),
                        longitude: catmullRom(p0.longitude, p1.longitude, p2.longitude, p3.longitude, t)
                    )
                )
            }
        }

        result.append(waypoints[waypoints.count - 1])
        return result
    }

    /// Uniforme Catmull-Rom-Interpolation (Tension 0.5) für eine einzelne Koordinaten-Komponente
    /// (Breiten- oder Längengrad werden unabhängig voneinander interpoliert).
    private static func catmullRom(_ p0: Double, _ p1: Double, _ p2: Double, _ p3: Double, _ t: Double) -> Double {
        let t2 = t * t
        let t3 = t2 * t
        return 0.5 * (
            (2 * p1)
            + (-p0 + p2) * t
            + (2 * p0 - 5 * p1 + 4 * p2 - p3) * t2
            + (-p0 + 3 * p1 - 3 * p2 + p3) * t3
        )
    }
}
