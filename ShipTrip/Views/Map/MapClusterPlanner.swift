//
//  MapClusterPlanner.swift
//  ShipTrip
//
//  Leichtes Overlap-Clustering für den `.route`-Zoom-Bucket (Design-Politur Welle C, F4):
//  paarweiser Bildschirm-Abstandsvergleich über ALLE Stops einer Route, nicht auf
//  Routenreihenfolge-Nachbarschaft beschränkt — deckt Rundreise-/Kreuzungsfälle ab (z. B.
//  Mallorca → Ibiza → Mallorca-Region erneut), bei denen geografisch nahe, aber
//  routenreihenfolge-ferne Stops sonst unclustered überlappen würden (Design-Spec F4,
//  Gate #5b-Korrektur). Reine, SwiftUI-freie Logik (Muster `MapSelectionPlanner`,
//  `MapRouteVisibilityPlanner`), isoliert testbar.
//

import Foundation
import CoreGraphics
import CoreLocation

/// Eingabe eines einzelnen Stops für das Overlap-Clustering: Bildschirm-Projektion + Stop-
/// Nummer. Die Stop-Nummer entscheidet, welcher Stop bei einer Kollision als Primary gezeigt
/// wird (niedrigste Nummer gewinnt) — ein reiner `[UUID: CGPoint]`-Dictionary (wie im
/// Design-Deck skizziert) reicht dafür nicht aus, da Dictionary-Iteration in Swift nicht
/// deterministisch geordnet ist.
struct MapClusterPoint {
    let id: UUID
    let stopNumber: Int
    let screenPoint: CGPoint
}

/// Ergebnis der Cluster-Berechnung: `primaryID` wird normal als Badge gezeigt, `suppressedIDs`
/// werden zu einem gemeinsamen „+N"-Pill am Primary zusammengefasst (kein eigenes Badge mehr).
struct MapClusterGroup: Equatable {
    let primaryID: UUID
    let suppressedIDs: [UUID]
}

enum MapClusterPlanner {
    /// Gruppiert `points` per Union-Find: zwei Stops landen in derselben Gruppe, sobald ihr
    /// Bildschirmabstand `collisionDistance` unterschreitet — transitiv, d. h. auch A–C werden
    /// gruppiert, wenn A–B und B–C beide kollidieren, selbst wenn A–C selbst weiter auseinander
    /// liegen. Ergebnis ist unabhängig von der Reihenfolge in `points`.
    static func clusters(points: [MapClusterPoint], collisionDistance: CGFloat) -> [MapClusterGroup] {
        guard points.count > 1 else {
            return points.map { MapClusterGroup(primaryID: $0.id, suppressedIDs: []) }
        }

        var parent = Dictionary(uniqueKeysWithValues: points.map { ($0.id, $0.id) })

        func find(_ id: UUID) -> UUID {
            var current = id
            while let next = parent[current], next != current {
                current = next
            }
            return current
        }

        func union(_ a: UUID, _ b: UUID) {
            let rootA = find(a)
            let rootB = find(b)
            guard rootA != rootB else { return }
            parent[rootA] = rootB
        }

        for i in 0..<points.count {
            for j in (i + 1)..<points.count {
                let dx = points[i].screenPoint.x - points[j].screenPoint.x
                let dy = points[i].screenPoint.y - points[j].screenPoint.y
                if hypot(dx, dy) < collisionDistance {
                    union(points[i].id, points[j].id)
                }
            }
        }

        let byID = Dictionary(uniqueKeysWithValues: points.map { ($0.id, $0) })
        var membersByRoot: [UUID: [UUID]] = [:]
        for point in points {
            membersByRoot[find(point.id), default: []].append(point.id)
        }

        return membersByRoot.values.map { memberIDs in
            let sorted = memberIDs.sorted { byID[$0]!.stopNumber < byID[$1]!.stopNumber }
            return MapClusterGroup(primaryID: sorted[0], suppressedIDs: Array(sorted.dropFirst()))
        }
    }

    // MARK: - Tap-Entscheidung (Fix-Runde 1, F01 / Fix-Runde 2, F01a+b)

    /// Minimaler Kamera-Span für den Cluster-Auflöse-Zoom (`zoomTo(coordinates:minimumSpan:)`) —
    /// Hafen-Level statt des generischen 2°-Floors von `MKCoordinateRegion(coordinates:)`. Der
    /// alte 2°-Floor hätte geografisch sehr nahe Cluster-Mitglieder nach dem Zoom weiterhin
    /// innerhalb der Bildschirm-Kollisionsdistanz belassen — der Cluster wäre bestehen
    /// geblieben, ein erneuter Tap hätte dieselbe (wirkungslose) Region erneut angefordert
    /// (Endlos-Loop ohne Nutzerwert, Fix-Runde 2, F01a).
    static let clusterZoomMinimumSpan: Double = 0.05

    /// Geografischer Auflösbarkeits-Schwellenwert (Fix-Runde 2, F01b) — unterhalb dieses
    /// Koordinaten-Spans (max. Breiten-/Längengrad-Delta unter den Cluster-Mitgliedern) würde
    /// selbst der engste Zoom (`clusterZoomMinimumSpan`) die Mitglieder auf dem Bildschirm nicht
    /// über die Kollisionsdistanz (28pt, siehe `clusters(...)`) hinaus trennen — der Cluster
    /// bliebe bestehen. Herleitung (konservativ, ohne echte Bildschirm-Projektion, wie vom Fix
    /// gefordert „rein geometrisch"): Trennung in Bildschirm-Punkten ≈ (Koordinaten-Delta /
    /// `clusterZoomMinimumSpan`) × Bildschirmbreite. Für Trennung > 28pt bei einer konservativ
    /// schmal angenommenen Bildschirmbreite von 320pt (kleinstes real relevantes iPhone-Portrait-
    /// Maß) muss das Koordinaten-Delta > 28 × 0.05 / 320 ≈ 0.00438° sein; aufgerundet auf 0.005°
    /// für zusätzliche Sicherheitsmarge. Darunter (inkl. exakt identischer Koordinaten, z. B.
    /// derselbe Hafen zweimal in einer Rundreise) gilt der Cluster als unauflösbar — Fallback
    /// `.selectStop` (Callout/Sheet zeigen den Inhalt dann direkt, statt eines wirkungslosen
    /// Zooms).
    static let unresolvableClusterSpanThreshold: Double = 0.005

    /// Ergebnis eines Tap auf einen Stop im `.route`-Bucket: ein Cluster-Primary (≥2 Mitglieder
    /// in `clusterMemberCoordinates`), dessen Mitglieder geografisch auflösbar sind, zoomt/
    /// rezentriert auf die Mitglieder-Koordinaten statt Callout+Sheet zu öffnen — „kein
    /// separater Callout im geclusterten Zustand" (Design-Spec F4). Ein Cluster, dessen
    /// Mitglieder auch beim engsten Zoom nicht trennbar wären (`isResolvable` == false, siehe
    /// `unresolvableClusterSpanThreshold`), fällt bewusst auf `.selectStop` zurück — sonst
    /// bliebe ein Tap dort wirkungslos und der Cluster damit eine Sackgasse. Jeder andere Stop
    /// (kein Eintrag oder nur 1 Mitglied — sollte durch `clusters(...)` nie mit einem einzelnen
    /// Mitglied im Dictionary landen, aber defensiv geprüft) selektiert normal. Reine
    /// Entscheidungslogik ohne SwiftUI-Abhängigkeit — die eigentliche Kamera-Aktion
    /// (`zoomTo(coordinates:minimumSpan:)`) bzw. Selektion bleibt in
    /// `MapView+RouteInteraction.swift`.
    enum TapOutcome {
        case zoomToCluster(coordinates: [CLLocationCoordinate2D])
        case selectStop
    }

    static func tapOutcome(
        for portID: UUID,
        clusterMemberCoordinates: [UUID: [CLLocationCoordinate2D]]
    ) -> TapOutcome {
        guard let members = clusterMemberCoordinates[portID], members.count > 1 else {
            return .selectStop
        }
        guard isResolvable(members) else {
            return .selectStop
        }
        return .zoomToCluster(coordinates: members)
    }

    /// `true`, wenn der geografische Bounding-Span von `coordinates` groß genug ist, dass der
    /// engste Cluster-Zoom (`clusterZoomMinimumSpan`) die Mitglieder sichtbar trennen kann
    /// (siehe Herleitung an `unresolvableClusterSpanThreshold`).
    private static func isResolvable(_ coordinates: [CLLocationCoordinate2D]) -> Bool {
        let lats = coordinates.map(\.latitude)
        let lons = coordinates.map(\.longitude)
        guard let minLat = lats.min(), let maxLat = lats.max(),
              let minLon = lons.min(), let maxLon = lons.max() else {
            return false
        }
        let span = max(maxLat - minLat, maxLon - minLon)
        return span >= unresolvableClusterSpanThreshold
    }
}
