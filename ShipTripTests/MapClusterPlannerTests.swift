//
//  MapClusterPlannerTests.swift
//  ShipTripTests
//
//  Tests für `MapClusterPlanner` (Design-Politur Welle C, F4 — Overlap-Clustering im
//  `.route`-Zoom-Bucket).
//

import Testing
import Foundation
import CoreGraphics
import CoreLocation
@testable import ShipTrip

@Suite("MapClusterPlanner.clusters")
struct MapClusterPlannerTests {

    @Test("Ein einzelner Punkt bleibt eine eigene Gruppe ohne Unterdrückte")
    func singlePointIsOwnGroup() {
        let id = UUID()
        let points = [MapClusterPoint(id: id, stopNumber: 1, screenPoint: CGPoint(x: 0, y: 0))]

        let groups = MapClusterPlanner.clusters(points: points, collisionDistance: 28)

        #expect(groups.count == 1)
        #expect(groups[0].primaryID == id)
        #expect(groups[0].suppressedIDs.isEmpty)
    }

    @Test("Zwei weit entfernte Punkte bleiben unclustered (jeweils eigenes Badge)")
    func farApartPointsStayUnclustered() {
        let a = UUID()
        let b = UUID()
        let points = [
            MapClusterPoint(id: a, stopNumber: 1, screenPoint: CGPoint(x: 0, y: 0)),
            MapClusterPoint(id: b, stopNumber: 2, screenPoint: CGPoint(x: 200, y: 200)),
        ]

        let groups = MapClusterPlanner.clusters(points: points, collisionDistance: 28)

        #expect(groups.count == 2)
        #expect(groups.allSatisfy { $0.suppressedIDs.isEmpty })
    }

    @Test("Zwei Punkte näher als die Kollisionsdistanz clustern zu einer Gruppe, niedrigste Stop-Nummer wird Primary")
    func closePointsClusterWithLowestStopNumberAsPrimary() {
        let a = UUID()
        let b = UUID()
        // 10pt Abstand, deutlich unter 28pt.
        let points = [
            MapClusterPoint(id: a, stopNumber: 5, screenPoint: CGPoint(x: 0, y: 0)),
            MapClusterPoint(id: b, stopNumber: 2, screenPoint: CGPoint(x: 10, y: 0)),
        ]

        let groups = MapClusterPlanner.clusters(points: points, collisionDistance: 28)

        #expect(groups.count == 1)
        #expect(groups[0].primaryID == b)
        #expect(groups[0].suppressedIDs == [a])
    }

    @Test("Ergebnis ist unabhängig von der Eingabe-Reihenfolge der Punkte")
    func resultIsOrderIndependent() {
        let a = UUID()
        let b = UUID()
        let pointA = MapClusterPoint(id: a, stopNumber: 5, screenPoint: CGPoint(x: 0, y: 0))
        let pointB = MapClusterPoint(id: b, stopNumber: 2, screenPoint: CGPoint(x: 10, y: 0))

        // Gruppierung selbst ist reihenfolgeunabhängig — die Ergebnis-*Array*-Reihenfolge kommt
        // aus einer Dictionary-Iteration und ist es nicht, daher vor dem Vergleich sortieren.
        let forward = MapClusterPlanner.clusters(points: [pointA, pointB], collisionDistance: 28)
            .sorted { $0.primaryID.uuidString < $1.primaryID.uuidString }
        let reversed = MapClusterPlanner.clusters(points: [pointB, pointA], collisionDistance: 28)
            .sorted { $0.primaryID.uuidString < $1.primaryID.uuidString }

        #expect(forward == reversed)
    }

    @Test("Nicht aufeinanderfolgende Stop-Nummern clustern trotzdem (Rundreise-/Kreuzungsfall)")
    func nonConsecutiveStopNumbersStillCluster() {
        // Stop 2 und Stop 5 liegen geografisch nah beieinander (Rundreise-Fall aus dem
        // Design-Spec, z. B. Mallorca → Ibiza → Mallorca-Region erneut), Stops 3/4 liegen
        // dazwischen weit entfernt.
        let stop2 = UUID()
        let stop3 = UUID()
        let stop4 = UUID()
        let stop5 = UUID()
        let points = [
            MapClusterPoint(id: stop2, stopNumber: 2, screenPoint: CGPoint(x: 0, y: 0)),
            MapClusterPoint(id: stop3, stopNumber: 3, screenPoint: CGPoint(x: 300, y: 0)),
            MapClusterPoint(id: stop4, stopNumber: 4, screenPoint: CGPoint(x: 600, y: 0)),
            MapClusterPoint(id: stop5, stopNumber: 5, screenPoint: CGPoint(x: 5, y: 5)),
        ]

        let groups = MapClusterPlanner.clusters(points: points, collisionDistance: 28)

        let clusterGroup = groups.first { $0.primaryID == stop2 }
        #expect(clusterGroup != nil)
        #expect(clusterGroup?.suppressedIDs == [stop5])
        #expect(groups.count == 3) // {stop2, stop5}, {stop3}, {stop4}
    }

    @Test("Drei Punkte in einer Kette (A–B kollidiert, B–C kollidiert, A–C direkt nicht) werden transitiv gruppiert")
    func transitiveChainGroupsAllThree() {
        let a = UUID()
        let b = UUID()
        let c = UUID()
        // A–B: 20pt (< 28, kollidiert). B–C: 20pt (< 28, kollidiert). A–C: √(20²+20²) ≈ 28.3pt
        // (≥ 28, kollidiert NICHT direkt) — A und C landen trotzdem in derselben Gruppe, weil
        // Union-Find transitiv über B verbindet.
        let points = [
            MapClusterPoint(id: a, stopNumber: 1, screenPoint: CGPoint(x: 0, y: 0)),
            MapClusterPoint(id: b, stopNumber: 2, screenPoint: CGPoint(x: 20, y: 0)),
            MapClusterPoint(id: c, stopNumber: 3, screenPoint: CGPoint(x: 20, y: 20)),
        ]

        let groups = MapClusterPlanner.clusters(points: points, collisionDistance: 28)

        #expect(groups.count == 1)
        #expect(groups[0].primaryID == a)
        #expect(Set(groups[0].suppressedIDs) == [b, c])
    }

    @Test("Punkt exakt an der Kollisionsdistanz (nicht kleiner) clustert nicht — knapp drunter schon")
    func exactlyAtCollisionDistanceDoesNotCluster() {
        let a = UUID()
        let b = UUID()
        let atThreshold = [
            MapClusterPoint(id: a, stopNumber: 1, screenPoint: CGPoint(x: 0, y: 0)),
            MapClusterPoint(id: b, stopNumber: 2, screenPoint: CGPoint(x: 28, y: 0)),
        ]
        let belowThreshold = [
            MapClusterPoint(id: a, stopNumber: 1, screenPoint: CGPoint(x: 0, y: 0)),
            MapClusterPoint(id: b, stopNumber: 2, screenPoint: CGPoint(x: 27.9, y: 0)),
        ]

        let atGroups = MapClusterPlanner.clusters(points: atThreshold, collisionDistance: 28)
        let belowGroups = MapClusterPlanner.clusters(points: belowThreshold, collisionDistance: 28)

        #expect(atGroups.count == 2)
        #expect(belowGroups.count == 1)
    }
}

// MARK: - MapClusterPlanner.tapOutcome (Fix-Runde 1, F01)

@Suite("MapClusterPlanner.tapOutcome")
struct MapClusterPlannerTapOutcomeTests {

    @Test("Tap auf einen Cluster-Primary (≥2 Mitglieder) liefert zoomToCluster mit allen Mitglieder-Koordinaten")
    func clusterPrimaryZoomsToAllMembers() {
        let primary = UUID()
        let coordinateA = CLLocationCoordinate2D(latitude: 41.38, longitude: 2.17)
        let coordinateB = CLLocationCoordinate2D(latitude: 41.40, longitude: 2.20)
        let memberCoordinates: [UUID: [CLLocationCoordinate2D]] = [primary: [coordinateA, coordinateB]]

        let outcome = MapClusterPlanner.tapOutcome(for: primary, clusterMemberCoordinates: memberCoordinates)

        guard case .zoomToCluster(let coordinates) = outcome else {
            Issue.record("Erwartet .zoomToCluster, bekommen \(outcome)")
            return
        }
        #expect(coordinates.count == 2)
        #expect(coordinates.contains { $0.latitude == coordinateA.latitude && $0.longitude == coordinateA.longitude })
        #expect(coordinates.contains { $0.latitude == coordinateB.latitude && $0.longitude == coordinateB.longitude })
    }

    @Test("Tap auf einen Stop ohne Cluster-Eintrag liefert selectStop (Einzel-Tap-Selektion unverändert)")
    func stopWithoutClusterEntrySelectsNormally() {
        let portID = UUID()
        let outcome = MapClusterPlanner.tapOutcome(for: portID, clusterMemberCoordinates: [:])

        guard case .selectStop = outcome else {
            Issue.record("Erwartet .selectStop, bekommen \(outcome)")
            return
        }
    }

    @Test("Ein Cluster-Eintrag mit nur einem Mitglied (defensiver Fall) liefert selectStop, nicht zoomToCluster")
    func singleMemberClusterEntrySelectsNormally() {
        let portID = UUID()
        let memberCoordinates: [UUID: [CLLocationCoordinate2D]] = [
            portID: [CLLocationCoordinate2D(latitude: 41.38, longitude: 2.17)],
        ]

        let outcome = MapClusterPlanner.tapOutcome(for: portID, clusterMemberCoordinates: memberCoordinates)

        guard case .selectStop = outcome else {
            Issue.record("Erwartet .selectStop, bekommen \(outcome)")
            return
        }
    }

    @Test("Tap auf einen anderen Stop derselben Cluster-Map (nicht der Primary) liefert selectStop")
    func nonPrimaryStopInSameMapSelectsNormally() {
        let primary = UUID()
        let otherStop = UUID()
        let memberCoordinates: [UUID: [CLLocationCoordinate2D]] = [
            primary: [
                CLLocationCoordinate2D(latitude: 41.38, longitude: 2.17),
                CLLocationCoordinate2D(latitude: 41.40, longitude: 2.20),
            ],
        ]

        // `otherStop` ist kein Key in `memberCoordinates` (Suppressed-Stops werden nicht mehr
        // gerendert und tauchen daher nie als Tap-Ziel auf) — Regressions-Guard, dass ein
        // unbekannter Stop nicht versehentlich als Cluster-Primary behandelt wird.
        let outcome = MapClusterPlanner.tapOutcome(for: otherStop, clusterMemberCoordinates: memberCoordinates)

        guard case .selectStop = outcome else {
            Issue.record("Erwartet .selectStop, bekommen \(outcome)")
            return
        }
    }

    // MARK: - Auflösbarkeit (Fix-Runde 2, F01b)

    @Test("Koinzidente Koordinaten (derselbe Hafen zweimal, z. B. Rundreise) liefern selectStop statt eines wirkungslosen Zooms")
    func coincidentCoordinatesFallBackToSelectStop() {
        let primary = UUID()
        let sameCoordinate = CLLocationCoordinate2D(latitude: 41.38, longitude: 2.17)
        let memberCoordinates: [UUID: [CLLocationCoordinate2D]] = [primary: [sameCoordinate, sameCoordinate]]

        let outcome = MapClusterPlanner.tapOutcome(for: primary, clusterMemberCoordinates: memberCoordinates)

        guard case .selectStop = outcome else {
            Issue.record("Erwartet .selectStop (unauflösbar), bekommen \(outcome)")
            return
        }
    }

    @Test("Geografisch sehr nahe, aber nicht identische Koordinaten unter der Auflösbarkeits-Schwelle liefern ebenfalls selectStop")
    func belowResolvabilityThresholdFallsBackToSelectStop() {
        let primary = UUID()
        // Delta 0.001° < unresolvableClusterSpanThreshold (0.005°) — selbst der engste
        // Cluster-Zoom würde die beiden Punkte nicht über die Bildschirm-Kollisionsdistanz
        // hinaus trennen.
        let memberCoordinates: [UUID: [CLLocationCoordinate2D]] = [
            primary: [
                CLLocationCoordinate2D(latitude: 41.3800, longitude: 2.1700),
                CLLocationCoordinate2D(latitude: 41.3810, longitude: 2.1700),
            ],
        ]

        let outcome = MapClusterPlanner.tapOutcome(for: primary, clusterMemberCoordinates: memberCoordinates)

        guard case .selectStop = outcome else {
            Issue.record("Erwartet .selectStop (unter Auflösbarkeits-Schwelle), bekommen \(outcome)")
            return
        }
    }

    @Test("Geografisch nahe, aber auflösbare Koordinaten (über der Schwelle) liefern zoomToCluster")
    func aboveResolvabilityThresholdZoomsToCluster() {
        let primary = UUID()
        // Delta 0.01° > unresolvableClusterSpanThreshold (0.005°) — mit dem engeren
        // Cluster-Zoom (minimumSpan 0.05°) tatsächlich trennbar, obwohl beide Stops beim
        // Cluster-bildenden Bildschirm-Abstand (28pt) noch kollidiert haben.
        let coordinateA = CLLocationCoordinate2D(latitude: 41.380, longitude: 2.170)
        let coordinateB = CLLocationCoordinate2D(latitude: 41.390, longitude: 2.170)
        let memberCoordinates: [UUID: [CLLocationCoordinate2D]] = [primary: [coordinateA, coordinateB]]

        let outcome = MapClusterPlanner.tapOutcome(for: primary, clusterMemberCoordinates: memberCoordinates)

        guard case .zoomToCluster(let coordinates) = outcome else {
            Issue.record("Erwartet .zoomToCluster (auflösbar), bekommen \(outcome)")
            return
        }
        #expect(coordinates.count == 2)
    }
}
