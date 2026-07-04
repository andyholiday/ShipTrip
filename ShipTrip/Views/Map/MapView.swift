//
//  MapView.swift
//  ShipTrip
//
//  Created by ShipTrip on 18.12.25.
//

import SwiftUI
import SwiftData
import MapKit
import CoreLocation

// MARK: - Marker Role Planning

/// Ein Port samt der ihm zugewiesenen Kartenmarker-Rolle (siehe `PortPinType`).
struct MapPortRole: Identifiable {
    let id: UUID
    let port: Port
    let type: PortPinType
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
            return [MapPortRole(id: first.id, port: first, type: .homePort)]
        }

        let isRoundTrip = coordinatesMatch(first.coordinate, last.coordinate)

        return ports.compactMap { port in
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
            return MapPortRole(id: port.id, port: port, type: type)
        }
    }

    private static func coordinatesMatch(_ a: CLLocationCoordinate2D, _ b: CLLocationCoordinate2D) -> Bool {
        abs(a.latitude - b.latitude) <= roundTripEpsilon && abs(a.longitude - b.longitude) <= roundTripEpsilon
    }
}

/// Interaktive Weltkarte mit allen Kreuzfahrt-Routen
struct MapView: View {
    @Query(sort: \Cruise.startDate, order: .reverse) private var cruises: [Cruise]

    @State private var position: MapCameraPosition = .automatic
    @State private var selectedRouteIDs: Set<UUID> = []
    @State private var primaryCruiseID: UUID?
    
    // Routenfarben aus zentraler Quelle (Color+Theme)
    
    var body: some View {
        NavigationStack {
            ZStack {
                Map(position: $position) {
                    ForEach(displayedRoutes, id: \.cruise.id) { route in
                        let index = route.index
                        let cruise = route.cruise
                        let validPorts = validPorts(for: cruise)
                        let portsToMark = MapMarkerPlanner.markerRoles(for: validPorts)

                        if validPorts.count > 1 {
                            MapPolyline(coordinates: validPorts.map { $0.coordinate })
                                .stroke(Color.routeColor(at: index).opacity(displayedRoutes.count == 1 ? 0.78 : 0.52), lineWidth: displayedRoutes.count == 1 ? 3 : 2)
                        }

                        ForEach(portsToMark) { role in
                            Annotation(role.port.name, coordinate: role.port.coordinate) {
                                Button {
                                    primaryCruiseID = cruise.id
                                } label: {
                                    markerView(for: role)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }
                .mapStyle(.standard)

                mapHeader

                if routableCruises.isEmpty {
                    ContentUnavailableView {
                        Label(String(localized: "Keine Häfen auf der Karte"), systemImage: "map")
                    } description: {
                        Text(String(localized: "Füge Häfen zu deinen Reisen hinzu, um sie hier zu sehen"))
                    }
                } else if !displayedRoutes.isEmpty {
                    routeSelectionCard(routes: displayedRoutes)
                }
            }
            .toolbar(.hidden, for: .navigationBar)
            .onAppear {
                syncRouteSelectionIfNeeded()
                zoomTo(routes: displayedRoutes)
            }
            .onChange(of: routableCruiseIDs) { _, _ in
                syncRouteSelectionIfNeeded()
                zoomTo(routes: displayedRoutes)
            }
            .navigationDestination(for: Cruise.self) { cruise in
                CruiseDetailView(cruise: cruise)
            }
        }
    }
    
    private var routableCruises: [(index: Int, cruise: Cruise)] {
        Array(cruises.enumerated())
            .filter { validPorts(for: $0.element).isEmpty == false }
            .map { (index: $0.offset, cruise: $0.element) }
    }

    private var routableCruiseIDs: [UUID] {
        routableCruises.map(\.cruise.id)
    }

    private var activeRouteIDs: Set<UUID> {
        selectedRouteIDs.isEmpty ? Set(routableCruiseIDs) : selectedRouteIDs
    }

    private var displayedRoutes: [(index: Int, cruise: Cruise)] {
        routableCruises.filter { activeRouteIDs.contains($0.cruise.id) }
    }

    private var primaryRoute: (index: Int, cruise: Cruise)? {
        if let primaryCruiseID,
           let route = displayedRoutes.first(where: { $0.cruise.id == primaryCruiseID }) {
            return route
        }
        return displayedRoutes.count == 1 ? displayedRoutes.first : nil
    }

    private func validPorts(for cruise: Cruise) -> [Port] {
        MapMarkerPlanner.validPorts(in: cruise.route)
    }

    /// Einheitliche Pin-Darstellung (siehe `PortPinView`) mit weißem Halo für Lesbarkeit auf der Karte.
    private func markerView(for role: MapPortRole) -> some View {
        PortPinView(type: role.type)
            .padding(6)
            .background(Circle().fill(.white))
            .shadow(color: .black.opacity(0.18), radius: 8, y: 4)
    }

    private func routeSelectionCard(routes: [(index: Int, cruise: Cruise)]) -> some View {
        let primary = primaryRoute?.cruise
        let ports = routes.flatMap { validPorts(for: $0.cruise) }
        let countries = Set(ports.map(\.country)).filter { !$0.isEmpty }.count

        return VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(selectionTitle(for: routes))
                        .font(.headline)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                    Text(selectionSubtitle(for: routes))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                }

                Spacer()

                if let primary {
                    NavigationLink(value: primary) {
                        Text(String(localized: "Öffnen"))
                            .font(.caption)
                            .fontWeight(.bold)
                            .foregroundStyle(.white)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(Color.oceanBlue)
                            .clipShape(Capsule())
                    }
                } else {
                    routeMenu
                }
            }

            HStack(spacing: 8) {
                Text("\(routes.reduce(0) { $0 + $1.cruise.duration }) \(String(localized: "Tage"))")
                Text("·")
                Text("\(ports.count) \(String(localized: "Häfen"))")
                Text("·")
                Text("\(countries) \(String(localized: "Länder"))")
            }
            .font(.caption)
            .fontWeight(.semibold)
            .foregroundStyle(.secondary)
            .lineLimit(1)

            if primary != nil {
                routeMenu
            }
        }
        .padding(16)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: DesignRadius.lg))
        .shadow(color: .black.opacity(0.16), radius: 18, y: 10)
        .padding(.horizontal, 16)
        .padding(.bottom, 92)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
    }

    private var mapHeader: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                routeCircleMenu

                Spacer()

                Button {
                    zoomTo(routes: displayedRoutes)
                } label: {
                    Image(systemName: "point.topleft.down.curvedto.point.bottomright.up")
                        .font(.title3.weight(.semibold))
                        .frame(width: 42, height: 42)
                        .background(.ultraThinMaterial)
                        .clipShape(Circle())
                        .shadow(color: Color.navyDark.opacity(0.08), radius: 11, y: 4)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(Text(String(localized: "Route anzeigen")))
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(String(localized: "Karte"))
                    .font(.largeTitle)
                    .fontWeight(.heavy)
                    .lineLimit(1)

                Text(selectionTitle(for: displayedRoutes))
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            .padding(.top, 76)
        }
        .padding(.horizontal, 20)
        .padding(.top, 10)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private var routeCircleMenu: some View {
        Menu {
            routeMenuItems
        } label: {
            Image(systemName: "line.3.horizontal.decrease.circle")
                .font(.title2.weight(.semibold))
                .frame(width: 42, height: 42)
                .background(.ultraThinMaterial)
                .clipShape(Circle())
                .shadow(color: Color.navyDark.opacity(0.08), radius: 11, y: 4)
        }
        .accessibilityLabel(Text(String(localized: "Routen")))
    }

    private var routeMenu: some View {
        Menu {
            routeMenuItems
        } label: {
            Label(String(localized: "Routen"), systemImage: "slider.horizontal.3")
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundStyle(.white)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Color.oceanBlue)
                .clipShape(Capsule())
        }
    }

    @ViewBuilder
    private var routeMenuItems: some View {
        Button {
            selectedRouteIDs = Set(routableCruiseIDs)
            primaryCruiseID = nil
            zoomTo(routes: routableCruises)
        } label: {
            Label(String(localized: "Alle Reisen anzeigen"), systemImage: activeRouteIDs == Set(routableCruiseIDs) ? "checkmark" : "map")
        }

        Divider()

        ForEach(routableCruises, id: \.cruise.id) { route in
            Button {
                toggle(route: route)
            } label: {
                Label(route.cruise.title, systemImage: activeRouteIDs.contains(route.cruise.id) ? "checkmark" : "circle")
            }
        }
    }

    private func selectionTitle(for routes: [(index: Int, cruise: Cruise)]) -> String {
        if let primary = primaryRoute?.cruise {
            return primary.title
        }
        if routes.count == routableCruises.count {
            return String(localized: "Alle Reisen")
        }
        return String(localized: "\(routes.count) Reisen")
    }

    private func selectionSubtitle(for routes: [(index: Int, cruise: Cruise)]) -> String {
        if let primary = primaryRoute?.cruise {
            let firstPort = validPorts(for: primary).first?.name ?? primary.ship
            return "\(firstPort) · \(DateInterval(start: primary.startDate, end: primary.endDate).formatted)"
        }
        return String(localized: "Mehrere Routen gleichzeitig")
    }

    private func syncRouteSelectionIfNeeded() {
        let available = Set(routableCruiseIDs)
        selectedRouteIDs = activeRouteIDs.intersection(available)
        if selectedRouteIDs.isEmpty {
            selectedRouteIDs = available
        }
        if let primaryCruiseID, !selectedRouteIDs.contains(primaryCruiseID) {
            self.primaryCruiseID = nil
        }
    }

    private func toggle(route: (index: Int, cruise: Cruise)) {
        var next = activeRouteIDs
        if next.contains(route.cruise.id), next.count > 1 {
            next.remove(route.cruise.id)
        } else {
            next.insert(route.cruise.id)
            primaryCruiseID = route.cruise.id
        }
        selectedRouteIDs = next
        if next.count != 1 {
            primaryCruiseID = nil
        } else {
            primaryCruiseID = next.first
        }
        zoomTo(routes: routableCruises.filter { next.contains($0.cruise.id) })
    }

    private func zoomTo(routes: [(index: Int, cruise: Cruise)]) {
        let coordinates = routes.flatMap { validPorts(for: $0.cruise).map(\.coordinate) }
        guard !coordinates.isEmpty else { return }

        let region = MKCoordinateRegion(coordinates: coordinates)

        withAnimation(.easeInOut(duration: 0.5)) {
            position = .region(region)
        }
    }
}

// MARK: - Helper Extension

extension MKCoordinateRegion {
    init(coordinates: [CLLocationCoordinate2D]) {
        guard !coordinates.isEmpty else {
            self = MKCoordinateRegion()
            return
        }
        
        let minLat = coordinates.map(\.latitude).min()!
        let maxLat = coordinates.map(\.latitude).max()!
        let minLon = coordinates.map(\.longitude).min()!
        let maxLon = coordinates.map(\.longitude).max()!
        
        let center = CLLocationCoordinate2D(
            latitude: (minLat + maxLat) / 2,
            longitude: (minLon + maxLon) / 2
        )
        
        // Berechne Span mit Padding und Minimum
        var latDelta = (maxLat - minLat) * 1.5
        var lonDelta = (maxLon - minLon) * 1.5
        
        // Minimum Span für einzelne Punkte oder sehr kleine Regionen
        latDelta = max(latDelta, 2.0)
        lonDelta = max(lonDelta, 2.0)
        
        // Maximum nur grob begrenzen, damit die Default-Karte mehrere Reisen weltweit zeigen kann.
        latDelta = min(latDelta, 120.0)
        lonDelta = min(lonDelta, 320.0)
        
        let span = MKCoordinateSpan(
            latitudeDelta: latDelta,
            longitudeDelta: lonDelta
        )
        
        self = MKCoordinateRegion(center: center, span: span)
    }
}

#Preview {
    MapView()
        .modelContainer(for: [Cruise.self, Port.self], inMemory: true)
}
