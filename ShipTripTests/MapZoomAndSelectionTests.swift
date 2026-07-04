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

@Suite("MapZoomBucketPlanner.bucket")
struct MapZoomBucketPlannerTests {

    @Test("Deutlich kleiner Span (Einzelreise) ergibt Reise-Zoom")
    func clearRouteZoom() {
        let span = MKCoordinateSpan(latitudeDelta: 3, longitudeDelta: 4)
        #expect(MapZoomBucketPlanner.bucket(for: span) == .route)
    }

    @Test("Deutlich großer Span (mehrere Reisen weltweit) ergibt Welt-Zoom")
    func clearWorldZoom() {
        let span = MKCoordinateSpan(latitudeDelta: 40, longitudeDelta: 60)
        #expect(MapZoomBucketPlanner.bucket(for: span) == .world)
    }

    @Test("Span knapp unter der Schwelle bleibt Reise-Zoom")
    func justUnderThresholdStaysRoute() {
        let span = MKCoordinateSpan(latitudeDelta: 9.9, longitudeDelta: 5)
        #expect(MapZoomBucketPlanner.bucket(for: span) == .route)
    }

    @Test("Span knapp über der Schwelle wechselt zu Welt-Zoom")
    func justOverThresholdSwitchesToWorld() {
        let span = MKCoordinateSpan(latitudeDelta: 10.1, longitudeDelta: 5)
        #expect(MapZoomBucketPlanner.bucket(for: span) == .world)
    }

    @Test("Maßgeblich ist der größere der beiden Span-Werte (Breiten- oder Längengrad)")
    func usesMaxOfLatAndLonDelta() {
        let latDominant = MKCoordinateSpan(latitudeDelta: 15, longitudeDelta: 2)
        let lonDominant = MKCoordinateSpan(latitudeDelta: 2, longitudeDelta: 15)

        #expect(MapZoomBucketPlanner.bucket(for: latDominant) == .world)
        #expect(MapZoomBucketPlanner.bucket(for: lonDominant) == .world)
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
