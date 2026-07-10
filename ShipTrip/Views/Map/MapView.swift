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
    /// F2 (Design-Politur Welle C): eigenes Popover statt nativem `Menu` — löst das gesamte
    /// Dismiss-Verhalten selbst (siehe `burgerMenu`), da `.popover` kein `Menu`-Äquivalent zu
    /// `menuActionDismissBehavior` besitzt.
    @State private var isRouteMenuOpen = false
    /// F4 (Design-Politur Welle C): Overlap-Cluster-Ergebnis für den `.route`-Zoom-Bucket —
    /// IDs von Stops, die wegen Bildschirm-Überlappung nicht als eigenes Badge gerendert werden
    /// (siehe `recomputeClusters(using:)` in `MapView+RouteInteraction.swift`).
    @State var suppressedStopIDs: Set<UUID> = []
    /// Primär-Stop-ID → Koordinaten ALLER geclusterten Mitglieder (inkl. sich selbst). Treibt
    /// sowohl den „+N"-Pill (`N = coordinates.count - 1`) als auch den Cluster-Tap: ein Tap auf
    /// den Cluster fittet die Kamera über `zoomTo(coordinates:)` auf genau diese Koordinaten,
    /// statt Callout/Sheet zu öffnen (Fix-Runde 1, F01 — Kern-Verhalten „Tap löst Cluster auf"
    /// fehlte, weil nur die Anzahl, nicht die Mitglieder gespeichert wurden).
    @State var clusterMemberCoordinates: [UUID: [CLLocationCoordinate2D]] = [:]
    /// One-Shot-Guard (Fix-Runde 3, P1, angelehnt an das Loop-Schutz-Muster „eine Source of
    /// Truth + programmatic-move-Guard"): wird ausschließlich beim Sheet-Row-Tap (`onStopTap`)
    /// gesetzt, weil dort direkt danach ein programmatischer `zoomTo`-Kamera-Move folgt. Marker-
    /// Taps (inkl. Unresolvable-Cluster-Fallback in `MapView+RouteInteraction.swift`) lösen
    /// keinen Kamera-Move aus und brauchen den Guard daher nicht (Fix-Runde 4, Codex-Auflage —
    /// ein hier gesetztes, aber nie durch ein Kamera-Ende konsumiertes Flag bliebe sonst bis zum
    /// nächsten manuellen Pan/Zoom scharf und würde dort fälschlich eine legitime Stale-
    /// Bereinigung überspringen). Verhindert so, dass der durch `zoomTo`/Kamera-Settle
    /// ausgelöste `.onMapCameraChange(.onEnd)`-Recompute die frische Sheet-Row-Selektion sofort
    /// wieder als „geclustert" wegräumt. Wird in `recomputeClusters(using:)`
    /// nach genau einem Durchlauf per `defer` zurückgesetzt — kein Dauer-Skip.
    @State var suppressSelectionCleanupOnNextCameraEnd = false
    /// Container-Höhe der Karte (F4-Fix-Runde 1, F04) — ersetzt das deprecated/szenen-blinde
    /// `UIScreen.main.bounds.height` für die Popover-Höhenbegrenzung. Default entspricht einer
    /// typischen iPhone-Portrait-Höhe, bevor der erste `GeometryReader`-Callback feuert.
    @State private var mapViewportHeight: CGFloat = 844

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
                        let bucket = MapZoomBucketPlanner.bucket(for: context.region.span, centerLatitude: context.region.center.latitude)
                        if bucket != zoomBucket {
                            zoomBucket = bucket
                            selectedStopID = MapSelectionPlanner.selection(selectedStopID, afterBucketChangeTo: bucket)
                        }
                        // Overlap-Cluster (F4) hängen vom tatsächlich gerenderten Kamera-Transform ab
                        // (Bildschirm-Projektion via `reader.convert`) — nur hier korrekt berechenbar,
                        // nicht vorab synchron in `zoomTo` (siehe Doc-Kommentar an `recomputeClusters`).
                        recomputeClusters(using: reader)
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
            // F4-Fix-Runde 1 (F04): liest die tatsächliche Container-Höhe reaktiv (statt der
            // deprecated/szenen-blinden `UIScreen.main`) — `.background` sorgt dafür, dass der
            // `GeometryReader` selbst keinen Einfluss auf das Layout nimmt.
            .background {
                GeometryReader { proxy in
                    Color.clear
                        .onAppear { mapViewportHeight = proxy.size.height }
                        .onChange(of: proxy.size) { _, newSize in mapViewportHeight = newSize.height }
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
                            // Fix-Runde 3, P1: frische, explizite Nutzer-Selektion — der direkt
                            // folgende `zoomTo`-Kamera-Settle darf `recomputeClusters` nicht dazu
                            // bringen, sie sofort wieder als „geclustert" wegzuräumen (z. B. wenn
                            // der Default-2°-Zoom einen Nachbar-Stop mit ins Bild holt).
                            suppressSelectionCleanupOnNextCameraEnd = true
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
                    // F3 (Design-Politur Welle C): löst den ScrollView-vs-Sheet-Drag-Konflikt
                    // („hakeliges Runterswipen") — Drag im Content resized das Sheet zuerst bis
                    // zum größten Detent, danach übernimmt Scrollen (Apple-Doku-Vertrag, gilt in
                    // beide Richtungen — kein Bug, siehe design-spec-karten-politur-c.md F3).
                    .presentationContentInteraction(.resizes)
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
    /// Design-Politur Welle C (F2): eigenes Popover-Panel (`RouteMenuPanelView`) statt nativem
    /// `Menu` — das System-`Menu` lief bis zu bildschirmfüllend und schien durch (siehe
    /// `.planning/design-spec-karten-politur-c.md`, Abschnitt F2). `.popover` liefert
    /// Dismiss-on-outside-tap/VoiceOver-Fokus-Trap weiterhin vom System, Breite/Hintergrund/
    /// Radius bleiben voll in eigener Hand.
    private var burgerMenu: some View {
        Button {
            isRouteMenuOpen.toggle()
        } label: {
            chromeButton(systemImage: "line.3.horizontal")
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text(String(localized: "Routenauswahl")))
        .popover(isPresented: $isRouteMenuOpen, attachmentAnchor: .rect(.bounds), arrowEdge: .top) {
            RouteMenuPanelView(
                routableCruises: routableCruises,
                activeRouteIDs: activeRouteIDs,
                allRoutesCurrentlyVisible: allRoutesCurrentlyVisible,
                onToggleAll: {
                    // Einmaliger Tap, muss das Panel schließen — sonst verdeckt der weiterhin
                    // offene Popover-Backdrop die darunter bereits korrekt neu gezoomte Karte
                    // dauerhaft (F1, TestFlight-Feedback Build 16: „weißer Bildschirm").
                    toggleAllRoutesVisibility()
                    isRouteMenuOpen = false
                },
                onToggle: { route in
                    // Mehrere Taps (z. B. drei Routen einzeln abwählen) sollen das Panel nicht
                    // nach jedem Tap schließen — sonst müsste der Nutzer für „alle bis auf eine
                    // abwählen" den Burger dreimal neu öffnen. Bewusst nur hier: `isRouteMenuOpen`
                    // bleibt unangetastet.
                    toggle(route: route)
                }
            )
            .frame(maxWidth: 300, maxHeight: routeMenuPanelMaxHeight)
            .presentationCompactAdaptation(.popover)
            .presentationBackground(Color.journalSurface)
            .presentationCornerRadius(DesignRadius.md)
        }
    }

    /// „Höhenbegrenzung verschärft" (Gate #5b): auf iPhone SE/Mini kann ein zu hohes Popover
    /// fast den ganzen Screen blockieren — `min(0.45 × Container-Höhe, 380pt)` statt einer
    /// vagen „~60 %"-Angabe. `mapViewportHeight` kommt reaktiv vom `GeometryReader` in `body`
    /// (F4-Fix-Runde 1, F04 — ersetzt das deprecated `UIScreen.main.bounds.height`).
    private var routeMenuPanelMaxHeight: CGFloat {
        min(mapViewportHeight * 0.45, 380)
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

    /// `internal` (kein `private`) statt der Geschwister-Overloads: wird vom Cluster-Tap in
    /// `MapView+RouteInteraction.swift` direkt aufgerufen (F4-Fix-Runde 1, F01 — Tap auf einen
    /// Cluster fittet die Kamera auf dessen Mitglieder-Koordinaten statt Callout/Sheet zu öffnen).
    /// Nutzt denselben, bereits an anderer Stelle (Sheet-Stop-Tap) bewährten Kamera-Pfad — kein
    /// zusätzlicher Loop-Schutz nötig, da hier kein neuer Karte↔Liste-Rückkanal entsteht.
    /// `minimumSpan` (Default `2.0`, unverändert für alle bestehenden Aufrufer) — Fix-Runde 2,
    /// F01a: der Cluster-Tap ruft mit einem deutlich kleineren Wert
    /// (`MapClusterPlanner.clusterZoomMinimumSpan`), damit geografisch nahe Cluster-Mitglieder
    /// tatsächlich weit genug auseinandergezogen werden, statt am alten 2°-Floor hängen zu
    /// bleiben.
    func zoomTo(coordinates: [CLLocationCoordinate2D], minimumSpan: Double = 2.0) {
        guard !coordinates.isEmpty else { return }

        let region = MKCoordinateRegion(coordinates: coordinates, minimumSpan: minimumSpan)
        // Bucket sofort synchron setzen statt auf den nächsten `.onMapCameraChange`-Callback zu
        // warten — verhindert einen kurzen Flash der falschen Zoom-Stufe bei Reisewechsel/Start.
        zoomBucket = MapZoomBucketPlanner.bucket(for: region.span, centerLatitude: region.center.latitude)
        selectedStopID = MapSelectionPlanner.selection(selectedStopID, afterBucketChangeTo: zoomBucket)

        withAnimation(.easeInOut(duration: 0.5)) {
            position = .region(region)
        }
    }
}

#Preview {
    MapView()
        .modelContainer(for: [Cruise.self, Port.self], inMemory: true)
}
