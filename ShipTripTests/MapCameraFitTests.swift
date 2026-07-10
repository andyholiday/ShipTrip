//
//  MapCameraFitTests.swift
//  ShipTripTests
//
//  Tests für `MKCoordinateRegion(coordinates:)` (MapView.swift) — die Fit-Logik hinter
//  `zoomTo(routes:)`. Regressions-Guard für F1 (TestFlight-Feedback Build 16): nach
//  „Alle ausblenden" → „Alle Reisen anzeigen" muss die berechnete Region alle sichtbaren
//  Routen-Koordinaten tatsächlich umfassen und darf nie leer/NaN sein.
//

import Testing
import Foundation
import MapKit
@testable import ShipTrip

@Suite("MKCoordinateRegion(coordinates:) Fit-Logik")
struct MapCameraFitTests {

    @Test("Leere Koordinaten ergeben eine Default-Region ohne NaN")
    func emptyCoordinatesYieldsDefaultRegion() {
        let region = MKCoordinateRegion(coordinates: [])
        #expect(region.span.latitudeDelta.isFinite)
        #expect(region.span.longitudeDelta.isFinite)
    }

    @Test("Mehrere weit auseinanderliegende Routen (Welt-Zoom-Szenario) ergeben eine gültige, alle Punkte umfassende Region")
    func multipleWorldwideRoutesProduceValidBoundingRegion() {
        // Nachgestellt aus dem Feedback-Repro: mehrere Reisen von Norwegen bis Doha/Oman.
        let coordinates = [
            CLLocationCoordinate2D(latitude: 60.39, longitude: 5.32),   // Bergen
            CLLocationCoordinate2D(latitude: 54.32, longitude: 10.14),  // Kiel
            CLLocationCoordinate2D(latitude: 28.10, longitude: -15.41), // Gran Canaria
            CLLocationCoordinate2D(latitude: 25.29, longitude: 51.53),  // Doha
        ]

        let region = MKCoordinateRegion(coordinates: coordinates)

        #expect(region.center.latitude.isFinite)
        #expect(region.center.longitude.isFinite)
        #expect(region.span.latitudeDelta.isFinite && region.span.latitudeDelta > 0)
        #expect(region.span.longitudeDelta.isFinite && region.span.longitudeDelta > 0)

        // Jede Koordinate muss innerhalb der berechneten Region liegen (kein leerer/zu enger Fit,
        // der die Karte auf einen weißen Fleck ohne sichtbare Routen zoomen würde).
        let latRange = (region.center.latitude - region.span.latitudeDelta / 2)...(region.center.latitude + region.span.latitudeDelta / 2)
        let lonRange = (region.center.longitude - region.span.longitudeDelta / 2)...(region.center.longitude + region.span.longitudeDelta / 2)
        for coordinate in coordinates {
            #expect(latRange.contains(coordinate.latitude))
            #expect(lonRange.contains(coordinate.longitude))
        }
    }

    @Test("Alle ausblenden gefolgt von Alle einblenden liefert wieder alle routbaren IDs und eine gültige Fit-Region (F1-Regression)")
    func hideThenShowAllYieldsFullFitRegion() {
        let routableIDs: Set<UUID> = [UUID(), UUID()]

        // 1. Alle ausblenden: aktive Menge muss leer sein.
        let hidden = MapRouteVisibilityPlanner.hidingAll(selectedRouteIDs: [])
        #expect(MapRouteVisibilityPlanner.activeRouteIDs(
            selectedRouteIDs: hidden.selectedRouteIDs,
            allRoutesHidden: hidden.allRoutesHidden,
            routableCruiseIDs: routableIDs
        ).isEmpty)

        // 2. Alle wieder einblenden: aktive Menge muss wieder ALLE routbaren Reisen sein, damit
        //    `zoomTo(routes: routableCruises)` mit den vollständigen Koordinaten aufgerufen wird.
        let shown = MapRouteVisibilityPlanner.showingAll()
        let active = MapRouteVisibilityPlanner.activeRouteIDs(
            selectedRouteIDs: shown.selectedRouteIDs,
            allRoutesHidden: shown.allRoutesHidden,
            routableCruiseIDs: routableIDs
        )
        #expect(active == routableIDs)

        // 3. Die daraus resultierende Fit-Region über die (simulierten) Koordinaten aller
        //    routbaren Reisen ist gültig — keine leere/weiße Karte.
        let coordinates = [
            CLLocationCoordinate2D(latitude: 60.39, longitude: 5.32),
            CLLocationCoordinate2D(latitude: 25.29, longitude: 51.53),
        ]
        let region = MKCoordinateRegion(coordinates: coordinates)
        #expect(region.span.latitudeDelta > 0)
        #expect(region.span.longitudeDelta > 0)
    }

    // MARK: - minimumSpan-Parameter (Fix-Runde 2, F01a)

    @Test("minimumSpan erlaubt einen deutlich engeren Floor als den Default — Cluster-Auflöse-Zoom")
    func minimumSpanAllowsTighterFloorThanDefault() {
        // Zwei geografisch nahe, aber unterscheidbare Häfen — deutlich über
        // `MapClusterPlanner.unresolvableClusterSpanThreshold` (0.005°), aber weit unter dem
        // alten festen 2°-Default-Floor. Rohes Delta (0.01°) × 1.5 Padding = 0.015°, das liegt
        // unter dem 0.05°-Cluster-Floor UND unter dem 2°-Default-Floor — beide klemmen also auf
        // ihren jeweiligen Minimalwert, was genau den Unterschied zeigt, den F01a beheben sollte.
        let coordinates = [
            CLLocationCoordinate2D(latitude: 41.380, longitude: 2.170),
            CLLocationCoordinate2D(latitude: 41.390, longitude: 2.180),
        ]

        let tightRegion = MKCoordinateRegion(coordinates: coordinates, minimumSpan: 0.05)
        let defaultRegion = MKCoordinateRegion(coordinates: coordinates)

        #expect(tightRegion.span.latitudeDelta == 0.05)
        #expect(tightRegion.span.longitudeDelta == 0.05)
        #expect(defaultRegion.span.latitudeDelta == 2.0)
        #expect(defaultRegion.span.longitudeDelta == 2.0)
        #expect(tightRegion.span.latitudeDelta < defaultRegion.span.latitudeDelta)
    }

    @Test("Bestehende Aufrufer ohne minimumSpan-Argument verhalten sich unverändert (Default 2.0)")
    func omittingMinimumSpanKeepsPreviousDefaultBehavior() {
        let coordinates = [CLLocationCoordinate2D(latitude: 41.38, longitude: 2.17)]
        let region = MKCoordinateRegion(coordinates: coordinates)
        #expect(region.span.latitudeDelta == 2.0)
        #expect(region.span.longitudeDelta == 2.0)
    }
}
