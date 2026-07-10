//
//  MapRouteCurveSamplerTests.swift
//  ShipTripTests
//
//  Tests für `RouteCurveSampler` (Karten-Redesign v2 „Journal Atlas", B4.3b-3): Catmull-Rom-
//  Interpolation durch die Hafen-Wegpunkte einer Route.
//

import Testing
import Foundation
import CoreLocation
@testable import ShipTrip

@Suite("RouteCurveSampler.curve")
struct RouteCurveSamplerTests {

    // MARK: - Degenerierte Fälle

    @Test("0 Wegpunkte ergeben eine leere Kurve, kein Crash")
    func zeroWaypointsYieldEmptyResult() {
        let result = RouteCurveSampler.curve(through: [], pointsPerSegment: 12)
        #expect(result.isEmpty)
    }

    @Test("1 Wegpunkt ergibt genau diesen einen Punkt, keine Spline-Berechnung")
    func singleWaypointYieldsItselfUnchanged() {
        let point = CLLocationCoordinate2D(latitude: 53.55, longitude: 9.99)
        let result = RouteCurveSampler.curve(through: [point], pointsPerSegment: 12)

        #expect(result.count == 1)
        #expect(result[0].latitude == point.latitude)
        #expect(result[0].longitude == point.longitude)
    }

    @Test("2 Wegpunkte ergeben eine Kurve, die exakt durch beide Punkte läuft (linearer Grenzfall)")
    func twoWaypointsProduceLineThroughBothPoints() {
        let a = CLLocationCoordinate2D(latitude: 40.0, longitude: 0.0)
        let b = CLLocationCoordinate2D(latitude: 50.0, longitude: 10.0)

        let result = RouteCurveSampler.curve(through: [a, b], pointsPerSegment: 8)

        #expect(result.count == 8 + 1)
        #expect(result.first!.latitude == a.latitude && result.first!.longitude == a.longitude)
        #expect(result.last!.latitude == b.latitude && result.last!.longitude == b.longitude)

        // Bei 2 Wegpunkten degeneriert die duplizierte-Endpunkt-Catmull-Rom-Formel exakt zu einer
        // linearen Interpolation — der Mittelpunkt der Kurve muss dem geometrischen Mittelpunkt
        // von a/b entsprechen.
        let midpoint = result[result.count / 2]
        #expect(abs(midpoint.latitude - 45.0) < 0.001)
        #expect(abs(midpoint.longitude - 5.0) < 0.001)
    }

    @Test("3 Wegpunkte ergeben eine crash-freie Kurve ohne Fehler")
    func threeWaypointsProduceValidCurve() {
        let points = [
            CLLocationCoordinate2D(latitude: 41.38, longitude: 2.17),
            CLLocationCoordinate2D(latitude: 43.30, longitude: 5.37),
            CLLocationCoordinate2D(latitude: 44.41, longitude: 8.93),
        ]

        let result = RouteCurveSampler.curve(through: points, pointsPerSegment: 10)

        #expect(result.count == 2 * 10 + 1)
        for coordinate in result {
            #expect(coordinate.latitude.isFinite)
            #expect(coordinate.longitude.isFinite)
        }
    }

    // MARK: - Läuft exakt durch die Original-Wegpunkte

    @Test("Kurve läuft exakt durch jeden Original-Wegpunkt (Catmull-Rom-Eigenschaft)")
    func curvePassesThroughOriginalWaypoints() {
        let points = [
            CLLocationCoordinate2D(latitude: 53.55, longitude: 9.99),
            CLLocationCoordinate2D(latitude: 50.90, longitude: -1.40),
            CLLocationCoordinate2D(latitude: 51.92, longitude: 4.48),
            CLLocationCoordinate2D(latitude: 55.68, longitude: 12.57),
        ]
        let pointsPerSegment = 6

        let result = RouteCurveSampler.curve(through: points, pointsPerSegment: pointsPerSegment)

        // Jeder Original-Wegpunkt liegt exakt am Beginn seines Segments (Index = segment * steps),
        // der letzte Wegpunkt wird separat als Abschlusspunkt angehängt.
        for (index, waypoint) in points.enumerated() {
            let resultIndex = index == points.count - 1 ? result.count - 1 : index * pointsPerSegment
            let sampled = result[resultIndex]
            #expect(abs(sampled.latitude - waypoint.latitude) < 1e-9)
            #expect(abs(sampled.longitude - waypoint.longitude) < 1e-9)
        }
    }

    // MARK: - Punkte-Budget-Deckel

    @Test("Punktezahl entspricht (Wegpunkte - 1) * pointsPerSegment + 1")
    func pointCountMatchesBudget() {
        let points = (0..<5).map { CLLocationCoordinate2D(latitude: Double($0) * 2, longitude: Double($0) * 3) }
        let result = RouteCurveSampler.curve(through: points, pointsPerSegment: 7)

        #expect(result.count == (points.count - 1) * 7 + 1)
    }

    @Test("pointsPerSegment 0 wird defensiv auf mindestens 1 gedeckelt statt eine leere Kurve zu ergeben")
    func zeroPointsPerSegmentIsClampedToOne() {
        let points = [
            CLLocationCoordinate2D(latitude: 0, longitude: 0),
            CLLocationCoordinate2D(latitude: 10, longitude: 10),
        ]
        let result = RouteCurveSampler.curve(through: points, pointsPerSegment: 0)

        #expect(result.count == 1 * 1 + 1)
    }

    // MARK: - Keine NaN

    @Test("Keine NaN/Infinity-Werte im Ergebnis, auch bei vielen Wegpunkten")
    func noNaNValuesInResult() {
        let points = (0..<12).map {
            CLLocationCoordinate2D(latitude: Double($0) * 3.7 - 20, longitude: Double($0) * -2.1 + 40)
        }
        let result = RouteCurveSampler.curve(through: points, pointsPerSegment: 24)

        #expect(result.allSatisfy { $0.latitude.isFinite && $0.longitude.isFinite })
    }
}
