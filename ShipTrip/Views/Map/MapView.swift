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

/// Interaktive Weltkarte mit allen Kreuzfahrt-Routen (Karten-Redesign v2 „Journal Atlas"):
/// Burger-Menü oben rechts für die Routen-Auswahl, kurvige Ribbon-Routen (`RouteCurveSampler`),
/// Bottom-Sheet mit Stop-Liste und Kamera-Sprung statt der früheren Bottom-Card.
struct MapView: View {
    @Query(sort: \Cruise.startDate, order: .reverse) private var cruises: [Cruise]

    @State private var position: MapCameraPosition = .automatic
    @State private var selectedRouteIDs: Set<UUID> = []
    /// Explizites „alle ausgeblendet"-Flag (siehe `MapRouteVisibilityPlanner`) — hat Vorrang vor
    /// `selectedRouteIDs`, damit ein leeres Auswahl-Set nicht wieder als „alle sichtbar" gilt.
    @State private var allRoutesHidden = false
    // Zugriffsebene ab hier `internal` (kein `private`): wird von `MapView+RouteInteraction.swift`
    // (Kartenlinien-/Marker-Rendering + Linien-Tap-Hit-Testing, ausgelagert wegen Datei-Größenlimit,
    // F01) gelesen/geschrieben. `private` ist in Swift datei-, nicht typgebunden — Extensions in
    // anderen Dateien desselben Typs benötigen mindestens `internal`.
    @State var primaryCruiseID: UUID?
    @State var zoomBucket: MapZoomBucket = .route
    /// Single Source of Truth für den ausgewählten Stopp (Port-`UUID`), gespeist vom
    /// Pin-/Badge-Tap. Treibt sowohl den Karten-Callout als auch das Sheet-Highlight.
    @State var selectedStopID: UUID?
    @State var isSheetPresented = false
    @State var sheetDetent: PresentationDetent = .height(140)
    /// Ziel der programmatischen Navigation, ausgelöst vom „Öffnen"-CTA im Sheet. Ein
    /// `NavigationLink` innerhalb des Sheets funktioniert nicht (eigener Presentation-Kontext ohne
    /// den `NavigationStack` des Parents) — stattdessen wird das Sheet geschlossen und dieses
    /// Ziel gesetzt, `.navigationDestination(item:)` am `NavigationStack` übernimmt den Push.
    @State private var cruiseToNavigate: Cruise?

    var body: some View {
        NavigationStack {
            ZStack {
                MapReader { reader in
                    Map(position: $position) {
                        ForEach(displayedRoutes, id: \.cruise.id) { route in
                            routeContent(for: route)
                        }
                    }
                    .mapStyle(.standard)
                    .gesture(
                        SpatialTapGesture().onEnded { value in
                            handleMapTap(at: value.location, using: reader)
                        }
                    )
                    .onMapCameraChange(frequency: .onEnd) { context in
                        let bucket = MapZoomBucketPlanner.bucket(for: context.region.span)
                        if bucket != zoomBucket {
                            zoomBucket = bucket
                            selectedStopID = MapSelectionPlanner.selection(selectedStopID, afterBucketChangeTo: bucket)
                        }
                    }
                }

                mapHeader

                if routableCruises.isEmpty {
                    ContentUnavailableView {
                        Label(String(localized: "Keine Häfen auf der Karte"), systemImage: "map")
                    } description: {
                        Text(String(localized: "Füge Häfen zu deinen Reisen hinzu, um sie hier zu sehen"))
                    }
                } else if allRoutesHidden {
                    allRoutesHiddenOverlay
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
            .navigationDestination(item: $cruiseToNavigate) { cruise in
                CruiseDetailView(cruise: cruise)
            }
            .sheet(isPresented: $isSheetPresented) {
                if let primaryRoute {
                    RouteStopSheetView(
                        cruise: primaryRoute.cruise,
                        ports: MapMarkerPlanner.markerRoles(for: validPorts(for: primaryRoute.cruise)),
                        routeColor: Color.routeColor(at: primaryRoute.index),
                        selectedStopID: $selectedStopID,
                        detent: $sheetDetent,
                        onStopTap: { port in
                            selectedStopID = port.id
                            zoomTo(coordinate: port.coordinate)
                            sheetDetent = .height(140)
                        },
                        onOpen: {
                            isSheetPresented = false
                            cruiseToNavigate = primaryRoute.cruise
                        }
                    )
                    .presentationDetents([.height(140), .medium, .large], selection: $sheetDetent)
                    .presentationBackgroundInteraction(.enabled(upThrough: .medium))
                    .presentationCornerRadius(DesignRadius.lg)
                    .presentationDragIndicator(.visible)
                    .presentationBackground(.regularMaterial)
                }
            }
        }
    }

    // MARK: - Abgeleiteter Zustand

    private var routableCruises: [(index: Int, cruise: Cruise)] {
        Array(cruises.enumerated())
            .filter { validPorts(for: $0.element).isEmpty == false }
            .map { (index: $0.offset, cruise: $0.element) }
    }

    private var routableCruiseIDs: [UUID] {
        routableCruises.map(\.cruise.id)
    }

    private var activeRouteIDs: Set<UUID> {
        MapRouteVisibilityPlanner.activeRouteIDs(
            selectedRouteIDs: selectedRouteIDs,
            allRoutesHidden: allRoutesHidden,
            routableCruiseIDs: Set(routableCruiseIDs)
        )
    }

    var displayedRoutes: [(index: Int, cruise: Cruise)] {
        routableCruises.filter { activeRouteIDs.contains($0.cruise.id) }
    }

    private var primaryRoute: (index: Int, cruise: Cruise)? {
        if let primaryCruiseID,
           let route = displayedRoutes.first(where: { $0.cruise.id == primaryCruiseID }) {
            return route
        }
        return displayedRoutes.count == 1 ? displayedRoutes.first : nil
    }

    func validPorts(for cruise: Cruise) -> [Port] {
        MapMarkerPlanner.validPorts(in: cruise.route)
    }

    /// Gesamtzahl der Routensegmente über alle sichtbaren Routen — Grundlage für den
    /// Punkte-Budget-Deckel der Kurven-Interpolation (Spec: `clamp(280 / gesamtSegmente, 6, 24)`).
    private var totalRouteSegments: Int {
        displayedRoutes.reduce(0) { total, route in
            total + max(0, validPorts(for: route.cruise).count - 1)
        }
    }

    var curvePointsPerSegment: Int {
        guard totalRouteSegments > 0 else { return 24 }
        return min(max(280 / totalRouteSegments, 6), 24)
    }

    // MARK: - Chrome (Header-Buttons)

    private var mapHeader: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                recenterButton
                Spacer()
                burgerMenu
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

    /// Solider Navy-Kreis-Button (Journal Atlas: kein `.ultraThinMaterial` mehr auf der Chrome).
    /// `.contentShape` hebt die effektive Hit-Area auf 44pt an (HIG-Minimum), ohne die
    /// sichtbare 42pt-Kreisgröße aus dem Token zu verändern.
    private func chromeButton(systemImage: String) -> some View {
        Image(systemName: systemImage)
            .font(.title3.weight(.semibold))
            .foregroundStyle(.white)
            .frame(width: 42, height: 42)
            .background(Color.navyDark)
            .clipShape(Circle())
            .contentShape(Circle().inset(by: -1))
            .shadow(color: .black.opacity(0.28), radius: 10, y: 4)
    }

    /// Wandert von oben rechts nach oben links (ersetzt dort das entfallene Filter-Menü).
    private var recenterButton: some View {
        Button {
            zoomTo(routes: displayedRoutes)
        } label: {
            chromeButton(systemImage: "point.topleft.down.curvedto.point.bottomright.up")
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text(String(localized: "Route anzeigen")))
    }

    /// Ersetzt das frühere Filter-Menü + die „Routen"-Capsule der Bottom-Card vollständig.
    private var burgerMenu: some View {
        Menu {
            routeMenuItems
        } label: {
            chromeButton(systemImage: "line.3.horizontal")
        }
        // Mehrere Taps (z. B. drei Routen einzeln abwählen) sollen das Menü nicht nach jedem Tap
        // schließen — sonst müsste der Nutzer für „alle bis auf eine abwählen" den Burger dreimal
        // neu öffnen.
        .menuActionDismissBehavior(.disabled)
        .accessibilityLabel(Text(String(localized: "Routenauswahl")))
    }

    @ViewBuilder
    private var routeMenuItems: some View {
        Button {
            toggleAllRoutesVisibility()
        } label: {
            Label(
                allRoutesCurrentlyVisible ? String(localized: "Alle ausblenden") : String(localized: "Alle Reisen anzeigen"),
                systemImage: allRoutesCurrentlyVisible ? "eye.slash.fill" : "eye.fill"
            )
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

    private var allRoutesCurrentlyVisible: Bool {
        !routableCruiseIDs.isEmpty && activeRouteIDs == Set(routableCruiseIDs)
    }

    /// Dezenter Leerzustand-Hinweis, wenn der Nutzer bewusst alle Routen über die
    /// Alle-ausblenden-Zeile ausgeblendet hat (kein `ContentUnavailableView` — der ist für
    /// „keine Häfen vorhanden", nicht für „bewusst ausgeblendet").
    private var allRoutesHiddenOverlay: some View {
        VStack(spacing: 10) {
            Image(systemName: "eye.slash")
                .font(.system(size: 34, weight: .semibold))
                .foregroundStyle(.white)
            Text(String(localized: "Alle Routen ausgeblendet"))
                .font(.headline)
                .foregroundStyle(.white)
            Text(String(localized: "Tippe auf das Menü, um Routen einzublenden"))
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.85))
                .multilineTextAlignment(.center)
        }
        .padding(24)
        .background(Color.navyDark.opacity(0.85))
        .clipShape(RoundedRectangle(cornerRadius: DesignRadius.lg))
        .padding(.horizontal, 40)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
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

    // MARK: - Routen-Auswahl (Burger-Menü)

    private func toggleAllRoutesVisibility() {
        if allRoutesCurrentlyVisible {
            let result = MapRouteVisibilityPlanner.hidingAll(selectedRouteIDs: selectedRouteIDs)
            selectedRouteIDs = result.selectedRouteIDs
            allRoutesHidden = result.allRoutesHidden
            primaryCruiseID = nil
            selectedStopID = nil
            isSheetPresented = false
        } else {
            let result = MapRouteVisibilityPlanner.showingAll()
            selectedRouteIDs = result.selectedRouteIDs
            allRoutesHidden = result.allRoutesHidden
            primaryCruiseID = nil
            zoomTo(routes: routableCruises)
        }
    }

    private func syncRouteSelectionIfNeeded() {
        let available = Set(routableCruiseIDs)
        selectedRouteIDs = selectedRouteIDs.intersection(available)
        if !allRoutesHidden, selectedRouteIDs.isEmpty {
            selectedRouteIDs = available
        }
        if let primaryCruiseID, !activeRouteIDs.contains(primaryCruiseID) {
            self.primaryCruiseID = nil
        }
    }

    private func toggle(route: (index: Int, cruise: Cruise)) {
        let result = MapRouteVisibilityPlanner.toggling(
            routeID: route.cruise.id,
            selectedRouteIDs: selectedRouteIDs,
            allRoutesHidden: allRoutesHidden,
            routableCruiseIDs: Set(routableCruiseIDs)
        )
        selectedRouteIDs = result.selectedRouteIDs
        allRoutesHidden = result.allRoutesHidden
        primaryCruiseID = result.selectedRouteIDs.count == 1 ? result.selectedRouteIDs.first : nil

        zoomTo(routes: routableCruises.filter { result.selectedRouteIDs.contains($0.cruise.id) })
    }

    // MARK: - Kamera

    private func zoomTo(routes: [(index: Int, cruise: Cruise)]) {
        let coordinates = routes.flatMap { validPorts(for: $0.cruise).map(\.coordinate) }
        zoomTo(coordinates: coordinates)
    }

    /// Kamera-Sprung auf einen einzelnen Stopp (Sheet-Stop-Tap) — nutzt dieselbe Zoom-Mechanik
    /// wie `zoomTo(routes:)`, nur mit einer einzelnen Koordinate statt der gesamten Route.
    private func zoomTo(coordinate: CLLocationCoordinate2D) {
        zoomTo(coordinates: [coordinate])
    }

    private func zoomTo(coordinates: [CLLocationCoordinate2D]) {
        guard !coordinates.isEmpty else { return }

        let region = MKCoordinateRegion(coordinates: coordinates)
        // Bucket sofort synchron setzen statt auf den nächsten `.onMapCameraChange`-Callback zu
        // warten — verhindert einen kurzen Flash der falschen Zoom-Stufe bei Reisewechsel/Start.
        zoomBucket = MapZoomBucketPlanner.bucket(for: region.span)
        selectedStopID = MapSelectionPlanner.selection(selectedStopID, afterBucketChangeTo: zoomBucket)

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
