//
//  MapMarkerPlannerTests.swift
//  ShipTripTests
//
//  Tests für die B4.3a-Rollen-Zuordnung (MapView.swift): welcher Port bekommt welche
//  Kartenmarker-Rolle (Heimathafen/Zwischenstopp/Endhafen), Rundreise-Erkennung mit
//  Koordinaten-Toleranz sowie das Filtern von Seetagen/ungültigen Koordinaten.
//

import Testing
import Foundation
import CoreLocation
@testable import ShipTrip

private typealias CruisePort = ShipTrip.Port

// MARK: - Fixture-Helfer

/// Erzeugt einen Port mit gegebenem `sortOrder`, ohne SwiftData-Context — reicht für die
/// reine `MapMarkerPlanner`-Logik, die nur auf gespeicherten Properties operiert.
private func makePort(
    name: String,
    latitude: Double,
    longitude: Double,
    sortOrder: Int,
    isSeaDay: Bool = false
) -> CruisePort {
    let port = CruisePort(name: name, country: "Land", latitude: latitude, longitude: longitude)
    port.sortOrder = sortOrder
    port.isSeaDay = isSeaDay
    return port
}

// MARK: - markerRoles

@Suite("MapMarkerPlanner.markerRoles")
struct MapMarkerPlannerMarkerRolesTests {

    @Test("Normale Route: erster Hafen = Heimathafen, letzter = Endhafen, Rest = Zwischenstopp")
    func normalRoute() {
        let home = makePort(name: "Hamburg", latitude: 53.55, longitude: 9.99, sortOrder: 0)
        let stop = makePort(name: "Southampton", latitude: 50.90, longitude: -1.40, sortOrder: 1)
        let end = makePort(name: "Rotterdam", latitude: 51.92, longitude: 4.48, sortOrder: 2)

        let roles = MapMarkerPlanner.markerRoles(for: [home, stop, end])

        #expect(roles.count == 3)
        #expect(roles[0].id == home.id && roles[0].type == .homePort)
        #expect(roles[1].id == stop.id && roles[1].type == .port)
        #expect(roles[2].id == end.id && roles[2].type == .endPort)
    }

    @Test("Rundreise mit exakt identischen Koordinaten ergibt einen kombinierten Marker")
    func roundTripExactMatch() {
        let home = makePort(name: "Hamburg", latitude: 53.55, longitude: 9.99, sortOrder: 0)
        let stop = makePort(name: "Southampton", latitude: 50.90, longitude: -1.40, sortOrder: 1)
        let end = makePort(name: "Hamburg", latitude: 53.55, longitude: 9.99, sortOrder: 2)

        let roles = MapMarkerPlanner.markerRoles(for: [home, stop, end])

        #expect(roles.count == 2)
        #expect(roles[0].id == home.id && roles[0].type == .homePort)
        #expect(roles[1].id == stop.id && roles[1].type == .port)
        // Der zweite Hamburg-Eintrag darf nicht als eigener (überlappender) Marker auftauchen.
        #expect(roles.contains { $0.id == end.id } == false)
    }

    @Test("Rundreise mit leicht abweichenden Koordinaten (innerhalb Toleranz) wird trotzdem erkannt")
    func roundTripWithinTolerance() {
        let home = makePort(name: "Hamburg", latitude: 53.55000, longitude: 9.99000, sortOrder: 0)
        // Abweichung < roundTripEpsilon (0.0001) — z. B. Rundungsdrift zweier unabhängiger Erfassungen.
        let end = makePort(name: "Hamburg", latitude: 53.55004, longitude: 9.98997, sortOrder: 1)

        let roles = MapMarkerPlanner.markerRoles(for: [home, end])

        #expect(roles.count == 1)
        #expect(roles[0].id == home.id)
        #expect(roles[0].type == .homePort)
    }

    @Test("Rundreise mit Abweichung knapp unter der Toleranz wird noch erkannt")
    func roundTripJustUnderTolerance() {
        let home = makePort(name: "Hamburg", latitude: 53.55, longitude: 9.99, sortOrder: 0)
        // 0.00009 < roundTripEpsilon (0.0001).
        let end = makePort(name: "Hamburg", latitude: 53.55009, longitude: 9.99, sortOrder: 1)

        let roles = MapMarkerPlanner.markerRoles(for: [home, end])

        #expect(roles.count == 1)
        #expect(roles[0].id == home.id)
        #expect(roles[0].type == .homePort)
    }

    @Test("Rundreise mit Abweichung knapp über der Toleranz wird nicht mehr erkannt")
    func roundTripJustOverTolerance() {
        let home = makePort(name: "Hamburg", latitude: 53.55, longitude: 9.99, sortOrder: 0)
        // 0.00012 > roundTripEpsilon (0.0001).
        let end = makePort(name: "Hamburg", latitude: 53.55012, longitude: 9.99, sortOrder: 1)

        let roles = MapMarkerPlanner.markerRoles(for: [home, end])

        #expect(roles.count == 2)
        #expect(roles[0].type == .homePort)
        #expect(roles[1].type == .endPort)
    }

    @Test("Rundreise mit Abweichung außerhalb der Toleranz bleibt zwei separate Marker")
    func nearbyButDistinctPortsStayeparate() {
        let home = makePort(name: "Hamburg", latitude: 53.55, longitude: 9.99, sortOrder: 0)
        // Deutlich außerhalb der Toleranz (0.0001) — ein anderer Ort, keine Rundreise.
        let end = makePort(name: "Cuxhaven", latitude: 53.87, longitude: 8.70, sortOrder: 1)

        let roles = MapMarkerPlanner.markerRoles(for: [home, end])

        #expect(roles.count == 2)
        #expect(roles[0].type == .homePort)
        #expect(roles[1].type == .endPort)
    }

    @Test("Ein-Hafen-Route ergibt genau einen Heimathafen-Marker")
    func singlePortRoute() {
        let onlyPort = makePort(name: "Lissabon", latitude: 38.71, longitude: -9.14, sortOrder: 0)

        let roles = MapMarkerPlanner.markerRoles(for: [onlyPort])

        #expect(roles.count == 1)
        #expect(roles[0].id == onlyPort.id)
        #expect(roles[0].type == .homePort)
    }

    @Test("Leere Portliste ergibt keine Marker")
    func emptyRoute() {
        let roles = MapMarkerPlanner.markerRoles(for: [])
        #expect(roles.isEmpty)
    }
}

// MARK: - validPorts (Seetage/ungültige Koordinaten filtern)

@Suite("MapMarkerPlanner.validPorts")
struct MapMarkerPlannerValidPortsTests {

    @Test("Seetage werden aus den Kartenmarkern gefiltert")
    func filtersOutSeaDays() {
        let port = makePort(name: "Bergen", latitude: 60.4, longitude: 5.3, sortOrder: 0)
        let seaDay = makePort(name: "Seetag", latitude: 0, longitude: 0, sortOrder: 1, isSeaDay: true)

        let result = MapMarkerPlanner.validPorts(in: [port, seaDay])

        #expect(result.count == 1)
        #expect(result[0].id == port.id)
    }

    @Test("Route nur aus Seetagen ergibt eine leere Markerliste, kein Crash")
    func onlySeaDaysYieldsEmptyResult() {
        let sea1 = makePort(name: "Seetag 1", latitude: 0, longitude: 0, sortOrder: 0, isSeaDay: true)
        let sea2 = makePort(name: "Seetag 2", latitude: 0, longitude: 0, sortOrder: 1, isSeaDay: true)

        let valid = MapMarkerPlanner.validPorts(in: [sea1, sea2])
        #expect(valid.isEmpty)

        let roles = MapMarkerPlanner.markerRoles(for: valid)
        #expect(roles.isEmpty)
    }

    @Test("Ports mit ungültigen (0,0)-Koordinaten werden gefiltert")
    func filtersOutInvalidCoordinates() {
        let validPort = makePort(name: "Malaga", latitude: 36.7, longitude: -4.4, sortOrder: 0)
        let brokenPort = makePort(name: "Unbekannt", latitude: 0, longitude: 0, sortOrder: 1)

        let result = MapMarkerPlanner.validPorts(in: [validPort, brokenPort])

        #expect(result.count == 1)
        #expect(result[0].id == validPort.id)
    }

    @Test("Ports mit Out-of-Range-Koordinaten (außerhalb ±90/±180) werden gefiltert")
    func filtersOutOutOfRangeCoordinates() {
        let validPort = makePort(name: "Malaga", latitude: 36.7, longitude: -4.4, sortOrder: 0)
        let outOfRangeLat = makePort(name: "Kaputt-Lat", latitude: 91, longitude: 10, sortOrder: 1)
        let outOfRangeLon = makePort(name: "Kaputt-Lon", latitude: 10, longitude: 181, sortOrder: 2)

        let result = MapMarkerPlanner.validPorts(in: [validPort, outOfRangeLat, outOfRangeLon])

        #expect(result.count == 1)
        #expect(result[0].id == validPort.id)
    }

    @Test("Ports mit NaN- oder Infinity-Koordinaten werden gefiltert, kein Crash")
    func filtersOutNonFiniteCoordinates() {
        let validPort = makePort(name: "Malaga", latitude: 36.7, longitude: -4.4, sortOrder: 0)
        let nanPort = makePort(name: "NaN", latitude: .nan, longitude: 10, sortOrder: 1)
        let infPort = makePort(name: "Infinity", latitude: 10, longitude: .infinity, sortOrder: 2)

        let result = MapMarkerPlanner.validPorts(in: [validPort, nanPort, infPort])

        #expect(result.count == 1)
        #expect(result[0].id == validPort.id)
    }

    @Test("validPorts sortiert nach sortOrder unabhängig von der Einfüge-Reihenfolge")
    func sortsBySortOrder() {
        let second = makePort(name: "B", latitude: 10, longitude: 10, sortOrder: 1)
        let first = makePort(name: "A", latitude: 20, longitude: 20, sortOrder: 0)

        let result = MapMarkerPlanner.validPorts(in: [second, first])

        #expect(result.map(\.name) == ["A", "B"])
    }
}

// MARK: - stopNumber (nummerierte Wegpunkt-Badges, B4.3b)

@Suite("MapMarkerPlanner.markerRoles stopNumber")
struct MapMarkerPlannerStopNumberTests {

    @Test("Normale Route: stopNumber zählt Start=1 fortlaufend bis zum Endhafen hoch")
    func normalRouteNumbersSequentially() {
        let home = makePort(name: "Hamburg", latitude: 53.55, longitude: 9.99, sortOrder: 0)
        let stop = makePort(name: "Southampton", latitude: 50.90, longitude: -1.40, sortOrder: 1)
        let end = makePort(name: "Rotterdam", latitude: 51.92, longitude: 4.48, sortOrder: 2)

        let roles = MapMarkerPlanner.markerRoles(for: [home, stop, end])

        #expect(roles.map(\.stopNumber) == [1, 2, 3])
    }

    @Test("Rundreise: der kollabierte End-Marker wird nicht mitgezählt, Nummern bleiben lückenlos")
    func roundTripNumbersRemainContiguous() {
        let home = makePort(name: "Hamburg", latitude: 53.55, longitude: 9.99, sortOrder: 0)
        let stop = makePort(name: "Southampton", latitude: 50.90, longitude: -1.40, sortOrder: 1)
        let end = makePort(name: "Hamburg", latitude: 53.55, longitude: 9.99, sortOrder: 2)

        let roles = MapMarkerPlanner.markerRoles(for: [home, stop, end])

        #expect(roles.map(\.stopNumber) == [1, 2])
    }

    @Test("Seetage sind vor markerRoles bereits gefiltert — stopNumber bleibt trotz Lücken in sortOrder lückenlos")
    func skippedSeaDaysDoNotLeaveGapsInNumbering() {
        // Simuliert das Ergebnis von validPorts(in:): Seetage (ursprünglich sortOrder 1, 3)
        // wurden bereits herausgefiltert, die verbleibenden Ports haben Lücken im sortOrder.
        let home = makePort(name: "Hamburg", latitude: 53.55, longitude: 9.99, sortOrder: 0)
        let stop = makePort(name: "Southampton", latitude: 50.90, longitude: -1.40, sortOrder: 2)
        let end = makePort(name: "Rotterdam", latitude: 51.92, longitude: 4.48, sortOrder: 4)

        let roles = MapMarkerPlanner.markerRoles(for: [home, stop, end])

        #expect(roles.map(\.stopNumber) == [1, 2, 3])
    }

    @Test("Ein-Hafen-Route ergibt stopNumber 1")
    func singlePortRouteNumbersOne() {
        let onlyPort = makePort(name: "Lissabon", latitude: 38.71, longitude: -9.14, sortOrder: 0)

        let roles = MapMarkerPlanner.markerRoles(for: [onlyPort])

        #expect(roles.map(\.stopNumber) == [1])
    }

    @Test("Mehrfachrouten: jeder markerRoles-Aufruf nummeriert unabhängig neu ab 1")
    func multipleRoutesNumberIndependently() {
        let routeA = [
            makePort(name: "Barcelona", latitude: 41.38, longitude: 2.17, sortOrder: 0),
            makePort(name: "Marseille", latitude: 43.30, longitude: 5.37, sortOrder: 1),
        ]
        let routeB = [
            makePort(name: "Palma", latitude: 39.57, longitude: 2.65, sortOrder: 0),
            makePort(name: "Ibiza", latitude: 38.91, longitude: 1.43, sortOrder: 1),
            makePort(name: "Valencia", latitude: 39.47, longitude: -0.38, sortOrder: 2),
        ]

        let rolesA = MapMarkerPlanner.markerRoles(for: routeA)
        let rolesB = MapMarkerPlanner.markerRoles(for: routeB)

        #expect(rolesA.map(\.stopNumber) == [1, 2])
        #expect(rolesB.map(\.stopNumber) == [1, 2, 3])
    }
}
