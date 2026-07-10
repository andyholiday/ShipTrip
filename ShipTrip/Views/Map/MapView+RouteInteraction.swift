//
//  MapView+RouteInteraction.swift
//  ShipTrip
//
//  Kartenlinien-/Marker-Rendering + Linien-Tap-Hit-Testing für MapView, ausgelagert aus
//  MapView.swift (F01, swift-standards Datei-Größenlimit) — reine Verschiebung, keine
//  Verhaltensänderung. Die genutzten `MapView`-Members (`selectedStopID`, `primaryCruiseID`,
//  `isSheetPresented`, `sheetDetent`, `zoomBucket`, `displayedRoutes`, `validPorts(for:)`,
//  `curvePointsPerSegment`) sind dafür `internal` statt `private` (Swift-Zugriffsebenen sind
//  dateigebunden, nicht typgebunden).
//

import SwiftUI
import MapKit
import CoreLocation

extension MapView {
    // MARK: - Kartenlinien + Marker je Route

    @MapContentBuilder
    func routeContent(for route: (index: Int, cruise: Cruise)) -> some MapContent {
        let index = route.index
        let cruise = route.cruise
        let ports = validPorts(for: cruise)
        let portsToMark = MapMarkerPlanner.markerRoles(for: ports)
        let curvePoints = RouteCurveSampler.curve(through: ports.map(\.coordinate), pointsPerSegment: curvePointsPerSegment)
        let isFocused = displayedRoutes.count == 1
        let routeColor = Color.routeColor(at: index)

        if curvePoints.count > 1 {
            // Schatten-Underlay zuerst (breiter, transparenter) — pragmatischer Ersatz für einen
            // echten Glow, da `MapPolyline` keinen `.shadow()`-Modifier unterstützt.
            MapPolyline(coordinates: curvePoints)
                .stroke(routeColor.opacity(0.30), style: StrokeStyle(lineWidth: isFocused ? 9 : 6, lineCap: .round, lineJoin: .round))

            MapPolyline(coordinates: curvePoints)
                .stroke(routeColor.opacity(isFocused ? 0.85 : 0.35), style: StrokeStyle(lineWidth: isFocused ? 4.5 : 2.5, lineCap: .round, lineJoin: .round))
        }

        ForEach(portsToMark) { role in
            // `anchor: .bottom`, damit der Tap-Callout im VStack darüber schweben kann, ohne die
            // Pin-Position eigens zu verschieben. Kein Text-`label:` (leerer `EmptyView`), sonst
            // würde MapKit den Portnamen wieder als Dauerlabel einblenden statt nur im Callout.
            Annotation(coordinate: role.port.coordinate, anchor: .bottom) {
                VStack(spacing: 6) {
                    if selectedStopID == role.port.id {
                        MapCalloutView(port: role.port)
                    }
                    Button {
                        selectedStopID = MapSelectionPlanner.toggled(current: selectedStopID, tapped: role.port.id)
                        primaryCruiseID = cruise.id
                        isSheetPresented = true
                        sheetDetent = .height(140)
                    } label: {
                        markerContent(for: role, routeIndex: index)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(Text(role.port.name))
                }
            } label: {
                EmptyView()
            }
        }
    }

    /// Marker-Inhalt je Zoom-Bucket: Welt-Zoom zeigt nur einen kleinen, routenfarbenen Dot
    /// (keine Labels/Rollen — Roadtrippers-/VesselFinder-Dichtereduktion statt Clustering),
    /// Reise-Zoom zeigt die vollen Rollen-Pins bzw. nummerierte Wegpunkt-Badges.
    @ViewBuilder
    func markerContent(for role: MapPortRole, routeIndex: Int) -> some View {
        let isSelected = selectedStopID == role.port.id
        switch zoomBucket {
        case .world:
            worldDotView(color: Color.routeColor(at: routeIndex))
        case .route:
            if role.type == .port {
                MapStopBadgeView(number: role.stopNumber, color: Color.routeColor(at: routeIndex), isSelected: isSelected)
            } else {
                markerView(for: role, isSelected: isSelected)
            }
        }
    }

    /// Winziger Dot für den Welt-Zoom, in Routenfarbe statt einheitlichem `Color.portPin` —
    /// behebt nebenbei die B4.3a-Known-Limitation (Zwischenstopps mehrerer Routen nicht
    /// unterscheidbar), da hier ohnehin jede Route ihre eigene Farbe bekommt.
    func worldDotView(color: Color) -> some View {
        Circle()
            .fill(color)
            .frame(width: 9, height: 9)
            .overlay(Circle().strokeBorder(.white, lineWidth: 1.5))
            .shadow(color: .black.opacity(0.16), radius: 3, y: 1)
    }

    /// Einheitliche Pin-Darstellung (siehe `PortPinView`) mit Halo für Lesbarkeit auf der Karte —
    /// `Color.journalSurface` statt hartkodiertem `.white` (Journal Atlas, Karten-Redesign v2).
    func markerView(for role: MapPortRole, isSelected: Bool) -> some View {
        PortPinView(type: role.type)
            .padding(6)
            .background(Circle().fill(Color.journalSurface))
            .overlay(Circle().strokeBorder(Color.oceanBlue, lineWidth: isSelected ? 3 : 0))
            .shadow(color: .black.opacity(0.18), radius: 8, y: 4)
    }

    // MARK: - Linien-Tap (primärer Sheet-Trigger)

    /// Primärer Sheet-Trigger „Tap auf eine Route" (Spec Abschnitt 5): konvertiert die
    /// interpolierten `RouteCurveSampler`-Punkte jeder sichtbaren Route in Bildschirmkoordinaten
    /// und sucht die nächste Route zur Tap-Position (Toleranz ~20pt). Kein Treffer im Toleranz-
    /// radius → bestehendes Verhalten (Callout-Auswahl aufheben), wie zuvor beim reinen
    /// `.onTapGesture` auf leere Kartenfläche.
    func handleMapTap(at location: CGPoint, using reader: MapProxy) {
        guard let cruiseID = nearestRouteID(to: location, using: reader) else {
            selectedStopID = nil
            return
        }
        primaryCruiseID = cruiseID
        isSheetPresented = true
        sheetDetent = .height(140)
    }

    func nearestRouteID(to location: CGPoint, using reader: MapProxy) -> UUID? {
        let tolerance: CGFloat = 20
        var bestCruiseID: UUID?
        var bestDistance: CGFloat = .greatestFiniteMagnitude

        for route in displayedRoutes {
            let coordinates = validPorts(for: route.cruise).map(\.coordinate)
            guard coordinates.count > 1 else { continue }
            let curvePoints = RouteCurveSampler.curve(through: coordinates, pointsPerSegment: curvePointsPerSegment)

            for coordinate in curvePoints {
                guard let screenPoint = reader.convert(coordinate, to: .local) else { continue }
                let distance = hypot(screenPoint.x - location.x, screenPoint.y - location.y)
                if distance < bestDistance {
                    bestDistance = distance
                    bestCruiseID = route.cruise.id
                }
            }
        }

        return bestDistance <= tolerance ? bestCruiseID : nil
    }
}
