//
//  MapMarkerPlanner.swift
//  ShipTrip
//
//  Ausgelagert aus MapView.swift (F01, swift-standards Datei-Größenlimit) — reine
//  Verschiebung, keine Verhaltensänderung.
//

import Foundation
import CoreLocation

// MARK: - Marker Role Planning

/// Ein Port samt der ihm zugewiesenen Kartenmarker-Rolle (siehe `PortPinType`).
struct MapPortRole: Identifiable {
    let id: UUID
    let port: Port
    let type: PortPinType
    /// 1-basierte Position in der Routenreihenfolge (Start zählt als 1). Treibt die
    /// nummerierten Wegpunkt-Badges der Zwischenstopps im Reise-Zoom (B4.3b); Start-/End-/
    /// Rundreise-Rollen zeigen weiterhin ihr eigenes `PortPinView`-Icon und ignorieren die Zahl.
    let stopNumber: Int
}

/// Leitet aus einer Portliste die Kartenmarker-Rollen ab (Heimathafen/Zwischenstopp/Endhafen)
/// und erkennt den Rundreise-Sonderfall (Start- und Endkoordinate identisch). Rein und ohne
/// SwiftUI-Abhängigkeit, damit die Zuordnung isoliert testbar ist.
enum MapMarkerPlanner {
    /// Toleranz für den Rundreise-Koordinatenvergleich in Grad (~11 m bei diesem Delta) —
    /// deckt Rundungsdrift zwischen zwei unabhängig erfassten Einträgen desselben Hafens ab,
    /// liegt aber weit unter dem Abstand zweier unterschiedlicher Häfen auf einer Route.
    /// Vergleich ist inklusive (`<=`); der exakte Grenzwert selbst ist wegen binärer
    /// Fließkomma-Rundung (z. B. `53.55 + 0.0001 != 53.5501`) nicht sinnvoll exakt testbar —
    /// die Tests prüfen daher knapp unter/über der Grenze statt exakt auf ihr.
    static let roundTripEpsilon: Double = 0.0001

    /// Seetage und Ports mit fehlenden/ungültigen Koordinaten ausfiltern, nach `sortOrder` sortieren.
    /// `hasValidCoordinates` schließt nur Seetage und exakt (0,0) aus — zusätzlich werden hier
    /// Out-of-Range- (Import, manuelle Eingabe) und nicht-endliche Werte (NaN/Infinity) verworfen,
    /// damit sie nicht als Geister-Pins in Annotation/MapPolyline landen.
    static func validPorts(in ports: [Port]) -> [Port] {
        ports
            .filter { $0.hasValidCoordinates && isFinitePlausible($0.coordinate) }
            .sorted { $0.sortOrder < $1.sortOrder }
    }

    private static func isFinitePlausible(_ coordinate: CLLocationCoordinate2D) -> Bool {
        coordinate.latitude.isFinite && coordinate.longitude.isFinite
            && CLLocationCoordinate2DIsValid(coordinate)
    }

    /// Weist bereits gefilterten/sortierten Ports ihre Marker-Rolle zu. Bei einer Rundreise
    /// (Start == Ende innerhalb der Toleranz) entsteht ein einziger kombinierter Marker
    /// (Rolle `.homePort`) statt zweier überlappender Pins.
    static func markerRoles(for ports: [Port]) -> [MapPortRole] {
        guard let first = ports.first else { return [] }
        guard let last = ports.last, last.id != first.id else {
            return [MapPortRole(id: first.id, port: first, type: .homePort, stopNumber: 1)]
        }

        let isRoundTrip = coordinatesMatch(first.coordinate, last.coordinate)

        return ports.enumerated().compactMap { index, port in
            if isRoundTrip, port.id == last.id {
                return nil
            }
            let type: PortPinType
            if port.id == first.id {
                type = .homePort
            } else if port.id == last.id {
                type = .endPort
            } else {
                type = .port
            }
            return MapPortRole(id: port.id, port: port, type: type, stopNumber: index + 1)
        }
    }

    private static func coordinatesMatch(_ a: CLLocationCoordinate2D, _ b: CLLocationCoordinate2D) -> Bool {
        abs(a.latitude - b.latitude) <= roundTripEpsilon && abs(a.longitude - b.longitude) <= roundTripEpsilon
    }
}
