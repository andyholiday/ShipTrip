//
//  MapZoomAndSelectionTests.swift
//  ShipTripTests
//
//  Tests für die B4.3b-Helfer in MapView.swift: Zoom-Bucket-Zuordnung
//  (MKCoordinateRegion.span → Welt-/Reise-Zoom) und die reine Stopp-Auswahl-Toggle-Logik.
//

import Testing
import Foundation
import MapKit
@testable import ShipTrip

// MARK: - MapZoomBucketPlanner

@Suite("MapZoomBucketPlanner.bucket(for:centerLatitude:)")
struct MapZoomBucketPlannerTests {

    @Test("Deutlich kleiner Span (Einzelreise) ergibt Reise-Zoom (Äquatornähe, keine Korrektur)")
    func clearRouteZoom() {
        let span = MKCoordinateSpan(latitudeDelta: 3, longitudeDelta: 4)
        #expect(MapZoomBucketPlanner.bucket(for: span, centerLatitude: 0) == .route)
    }

    @Test("Deutlich großer Span (mehrere Reisen weltweit) ergibt Welt-Zoom (Äquatornähe)")
    func clearWorldZoom() {
        let span = MKCoordinateSpan(latitudeDelta: 40, longitudeDelta: 60)
        #expect(MapZoomBucketPlanner.bucket(for: span, centerLatitude: 0) == .world)
    }

    @Test("Span knapp unter der 20°-Schwelle bleibt Reise-Zoom (Design-Politur Welle C, F4)")
    func justUnderThresholdStaysRoute() {
        let span = MKCoordinateSpan(latitudeDelta: 19.9, longitudeDelta: 5)
        #expect(MapZoomBucketPlanner.bucket(for: span, centerLatitude: 0) == .route)
    }

    @Test("Span knapp über der 20°-Schwelle wechselt zu Welt-Zoom")
    func justOverThresholdSwitchesToWorld() {
        let span = MKCoordinateSpan(latitudeDelta: 20.1, longitudeDelta: 5)
        #expect(MapZoomBucketPlanner.bucket(for: span, centerLatitude: 0) == .world)
    }

    @Test("Maßgeblich ist der größere der beiden (breitengrad-korrigierten) Span-Werte")
    func usesMaxOfLatAndCorrectedLonDelta() {
        let latDominant = MKCoordinateSpan(latitudeDelta: 25, longitudeDelta: 2)
        let lonDominant = MKCoordinateSpan(latitudeDelta: 2, longitudeDelta: 25)

        #expect(MapZoomBucketPlanner.bucket(for: latDominant, centerLatitude: 0) == .world)
        #expect(MapZoomBucketPlanner.bucket(for: lonDominant, centerLatitude: 0) == .world)
    }

    @Test("Kanaren/Madeira/Marokko-Regressionsfall (Screenshot 04): Span 10–20° zeigt jetzt Reise-Zoom statt Welt-Zoom")
    func canaryMadeiraRegressionStaysRoute() {
        let span = MKCoordinateSpan(latitudeDelta: 15, longitudeDelta: 15)
        #expect(MapZoomBucketPlanner.bucket(for: span, centerLatitude: 28) == .route)
    }

    @Test("Norwegen-Route (hohe Breite, ~65°N): latitude-korrigierter Längengrad-Span verhindert vorzeitigen Welt-Zoom")
    func highLatitudeNorwayCorrectionPreventsPrematureWorldZoom() {
        // cos(65°) ≈ 0.4226 → effektiver Lon-Span 25° * 0.4226 ≈ 10.6°, klar unter der
        // 20°-Schwelle. Unkorrigiert (centerLatitude 0) wäre derselbe Span ein Welt-Zoom.
        let span = MKCoordinateSpan(latitudeDelta: 5, longitudeDelta: 25)
        #expect(MapZoomBucketPlanner.bucket(for: span, centerLatitude: 65) == .route)
        #expect(MapZoomBucketPlanner.bucket(for: span, centerLatitude: 0) == .world)
    }
}

// MARK: - MapSelectionPlanner

@Suite("MapSelectionPlanner.toggled")
struct MapSelectionPlannerTests {

    @Test("Tap auf einen Stopp ohne bestehende Auswahl selektiert ihn")
    func selectsWhenNoneSelected() {
        let id = UUID()
        #expect(MapSelectionPlanner.toggled(current: nil, tapped: id) == id)
    }

    @Test("Erneuter Tap auf den bereits ausgewählten Stopp hebt die Auswahl auf")
    func deselectsSameStop() {
        let id = UUID()
        #expect(MapSelectionPlanner.toggled(current: id, tapped: id) == nil)
    }

    @Test("Tap auf einen anderen Stopp wechselt die Auswahl, statt zu deselektieren")
    func switchesToOtherStop() {
        let a = UUID()
        let b = UUID()
        #expect(MapSelectionPlanner.toggled(current: a, tapped: b) == b)
    }
}

// MARK: - MapSelectionPlanner.selection(_:afterBucketChangeTo:)

@Suite("MapSelectionPlanner.selection(afterBucketChangeTo:)")
struct MapSelectionPlannerBucketChangeTests {

    @Test("Wechsel in den Welt-Zoom verwirft eine bestehende Auswahl (kein Callout auf Dots)")
    func worldZoomClearsSelection() {
        let selected = UUID()
        #expect(MapSelectionPlanner.selection(selected, afterBucketChangeTo: .world) == nil)
    }

    @Test("Keine Auswahl bleibt beim Wechsel in den Welt-Zoom weiterhin nil")
    func worldZoomKeepsNilSelectionNil() {
        #expect(MapSelectionPlanner.selection(nil, afterBucketChangeTo: .world) == nil)
    }

    @Test("Wechsel in den Reise-Zoom lässt eine bestehende Auswahl unangetastet")
    func routeZoomKeepsExistingSelection() {
        let selected = UUID()
        #expect(MapSelectionPlanner.selection(selected, afterBucketChangeTo: .route) == selected)
    }

    @Test("Wechsel in den Reise-Zoom ohne bestehende Auswahl bleibt nil")
    func routeZoomKeepsNilSelectionNil() {
        #expect(MapSelectionPlanner.selection(nil, afterBucketChangeTo: .route) == nil)
    }
}

// MARK: - MapSelectionPlanner.selection(afterClusteringWith:clusterMemberCoordinates:suppressCleanup:)

@Suite("MapSelectionPlanner.selection(afterClusteringWith:) — Fix-Runde 2, F02")
struct MapSelectionPlannerClusteringCleanupTests {

    @Test("Selektierter Stop, der jetzt suppressed ist, wird auf nil zurückgesetzt (kein Guard)")
    func suppressedSelectionIsCleared() {
        let selected = UUID()
        let result = MapSelectionPlanner.selection(
            selected,
            afterClusteringWith: [selected],
            clusterMemberCoordinates: [:],
            suppressCleanup: false
        )
        #expect(result == nil)
    }

    @Test("Selektierter Stop, der jetzt selbst Cluster-Primary ist, wird auf nil zurückgesetzt (kein Guard)")
    func clusterPrimarySelectionIsCleared() {
        let selected = UUID()
        let memberCoordinates: [UUID: [CLLocationCoordinate2D]] = [
            selected: [
                CLLocationCoordinate2D(latitude: 41.38, longitude: 2.17),
                CLLocationCoordinate2D(latitude: 41.40, longitude: 2.20),
            ],
        ]
        let result = MapSelectionPlanner.selection(
            selected,
            afterClusteringWith: [],
            clusterMemberCoordinates: memberCoordinates,
            suppressCleanup: false
        )
        #expect(result == nil)
    }

    @Test("Selektierter Stop ohne jede Cluster-Beteiligung bleibt unangetastet (kein Guard)")
    func unrelatedSelectionIsUnchanged() {
        let selected = UUID()
        let otherPrimary = UUID()
        let memberCoordinates: [UUID: [CLLocationCoordinate2D]] = [
            otherPrimary: [
                CLLocationCoordinate2D(latitude: 41.38, longitude: 2.17),
                CLLocationCoordinate2D(latitude: 41.40, longitude: 2.20),
            ],
        ]
        let result = MapSelectionPlanner.selection(
            selected,
            afterClusteringWith: [],
            clusterMemberCoordinates: memberCoordinates,
            suppressCleanup: false
        )
        #expect(result == selected)
    }

    @Test("Keine Auswahl (nil) bleibt nil, unabhängig vom Clustering-Zustand (kein Guard)")
    func nilSelectionStaysNil() {
        let result = MapSelectionPlanner.selection(
            nil,
            afterClusteringWith: [UUID()],
            clusterMemberCoordinates: [:],
            suppressCleanup: false
        )
        #expect(result == nil)
    }

    @Test("Ein Cluster-Eintrag mit nur einem Mitglied (defensiver Fall) zählt nicht als geclustert (kein Guard)")
    func singleMemberClusterEntryDoesNotClearSelection() {
        let selected = UUID()
        let memberCoordinates: [UUID: [CLLocationCoordinate2D]] = [
            selected: [CLLocationCoordinate2D(latitude: 41.38, longitude: 2.17)],
        ]
        let result = MapSelectionPlanner.selection(
            selected,
            afterClusteringWith: [],
            clusterMemberCoordinates: memberCoordinates,
            suppressCleanup: false
        )
        #expect(result == selected)
    }

    // MARK: - suppressCleanup-Guard (Fix-Runde 3, P1)

    @Test("(i) Frische Nutzer-Selektion + Cluster-Ergebnis, das sie sonst räumen würde → Selektion bleibt bei aktivem Guard")
    func freshSelectionSurvivesCleanupWhileGuardIsActive() {
        let selected = UUID()
        // Stop wäre ohne Guard eindeutig „geclustert" (suppressed) — genau der Regressionsfall
        // aus Fix-Runde 3: Sheet-Row-Tap zoomt, Nachbar-Stop rutscht dadurch mit ins Bild,
        // Recompute würde die gerade erst getroffene Auswahl sonst sofort wieder löschen.
        let result = MapSelectionPlanner.selection(
            selected,
            afterClusteringWith: [selected],
            clusterMemberCoordinates: [:],
            suppressCleanup: true
        )
        #expect(result == selected)
    }

    @Test("(ii) Derselbe Zustand OHNE Guard räumt die Selektion wie bisher (Fix-Runde 2-Verhalten bleibt bestehen)")
    func sameStateWithoutGuardStillClearsSelection() {
        let selected = UUID()
        let result = MapSelectionPlanner.selection(
            selected,
            afterClusteringWith: [selected],
            clusterMemberCoordinates: [:],
            suppressCleanup: false
        )
        #expect(result == nil)
    }

    @Test("(iii) Guard schützt auch den Cluster-Primary-Fall (nicht nur suppressed)")
    func guardAlsoProtectsClusterPrimaryCase() {
        let selected = UUID()
        let memberCoordinates: [UUID: [CLLocationCoordinate2D]] = [
            selected: [
                CLLocationCoordinate2D(latitude: 41.38, longitude: 2.17),
                CLLocationCoordinate2D(latitude: 41.40, longitude: 2.20),
            ],
        ]
        let result = MapSelectionPlanner.selection(
            selected,
            afterClusteringWith: [],
            clusterMemberCoordinates: memberCoordinates,
            suppressCleanup: true
        )
        #expect(result == selected)
    }

    @Test("Guard bei nil-Selektion bleibt nil (harmlos, kein neuer Fall)")
    func guardWithNilSelectionStaysNil() {
        let result = MapSelectionPlanner.selection(
            nil,
            afterClusteringWith: [UUID()],
            clusterMemberCoordinates: [:],
            suppressCleanup: true
        )
        #expect(result == nil)
    }

    @Test("(iii) Zwei aufeinanderfolgende Aufrufe (Guard aktiv, dann inaktiv) zeigen das One-Shot-Verhalten auf Logik-Ebene")
    func consecutiveCallsShowOneShotBehavior() {
        // Simuliert zwei aufeinanderfolgende `recomputeClusters`-Durchläufe: der erste direkt
        // nach der frischen Nutzer-Selektion (Guard aktiv → übersteht den Cleanup), der zweite
        // NACH dem `defer`-Reset in `MapView+RouteInteraction.swift` (Guard wieder inaktiv →
        // eine inzwischen echt stale gewordene Selektion wird jetzt ganz normal geräumt). Das
        // eigentliche Zurücksetzen des `@State`-Flags selbst ist ein reiner `defer`-Sprachgarant
        // (läuft bei jedem Funktionsaustritt genau einmal) und wird hier bewusst nicht erneut
        // getestet — nur die aus dem Guard-Zustand resultierende Entscheidungslogik.
        let selected = UUID()
        let suppressed: Set<UUID> = [selected]

        let firstResult = MapSelectionPlanner.selection(
            selected,
            afterClusteringWith: suppressed,
            clusterMemberCoordinates: [:],
            suppressCleanup: true
        )
        #expect(firstResult == selected)

        let secondResult = MapSelectionPlanner.selection(
            firstResult,
            afterClusteringWith: suppressed,
            clusterMemberCoordinates: [:],
            suppressCleanup: false
        )
        #expect(secondResult == nil)
    }
}
