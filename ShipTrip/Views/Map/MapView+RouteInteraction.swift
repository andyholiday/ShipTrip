//
//  MapView+RouteInteraction.swift
//  ShipTrip
//
//  Kartenlinien-/Marker-Rendering + Linien-Tap-Hit-Testing für MapView, ausgelagert aus
//  MapView.swift (F01, swift-standards Datei-Größenlimit) — reine Verschiebung, keine
//  Verhaltensänderung. Die genutzten `MapView`-Members (`selectedStopID`, `primaryCruiseID`,
//  `isSheetPresented`, `sheetDetent`, `zoomBucket`, `displayedRoutes`, `validPorts(for:)`,
//  `curvePointsPerSegment`, `suppressedStopIDs`, `clusterMemberCoordinates`, `zoomTo(coordinates:)`,
//  `suppressSelectionCleanupOnNextCameraEnd`) sind dafür `internal` statt `private` (Swift-
//  Zugriffsebenen sind dateigebunden, nicht typgebunden).
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

        // F4 (Design-Politur Welle C): geclusterte Stops (Bildschirm-Überlappung im `.route`-
        // Bucket, siehe `recomputeClusters(using:)`) werden nicht als eigene Annotation gerendert
        // — sie sind im „+N"-Pill des jeweiligen Primary-Stops absorbiert.
        let visiblePortsToMark = portsToMark.filter { !suppressedStopIDs.contains($0.port.id) }

        ForEach(visiblePortsToMark) { role in
            // `anchor: .bottom`, damit der Tap-Callout im VStack darüber schweben kann, ohne die
            // Pin-Position eigens zu verschieben. Kein Text-`label:` (leerer `EmptyView`), sonst
            // würde MapKit den Portnamen wieder als Dauerlabel einblenden statt nur im Callout.
            Annotation(coordinate: role.port.coordinate, anchor: .bottom) {
                VStack(spacing: 6) {
                    if selectedStopID == role.port.id {
                        MapCalloutView(port: role.port)
                    }
                    Button {
                        // F4-Fix-Runde 1 (F01): Tap auf einen Cluster-Primary zoomt/rezentriert
                        // auf dessen Mitglieder-Koordinaten und löst den Cluster damit auf,
                        // statt Callout+Sheet zu öffnen (Spec: „kein separater Callout im
                        // geclusterten Zustand" — vorher hatten Cluster- und Einzel-Badge
                        // identisches Tap-Verhalten, das Kern-F4-Versprechen fehlte). Reine
                        // Entscheidung in `MapClusterPlanner.tapOutcome` — isoliert testbar.
                        switch MapClusterPlanner.tapOutcome(for: role.port.id, clusterMemberCoordinates: clusterMemberCoordinates) {
                        case .zoomToCluster(let coordinates):
                            // Fix-Runde 2, F01a: engerer Minimal-Span als der generische
                            // 2°-Default — sonst bleiben geografisch sehr nahe Mitglieder auch
                            // nach dem Zoom innerhalb der Kollisionsdistanz (Endlos-Loop).
                            zoomTo(coordinates: coordinates, minimumSpan: MapClusterPlanner.clusterZoomMinimumSpan)
                        case .selectStop:
                            // Fix-Runde 4 (Codex-Auflage): KEIN Guard-Scharfstellen hier — dieser
                            // Zweig (regulärer Marker-Tap wie auch der Unresolvable-Cluster-
                            // Fallback) löst keinen `zoomTo`/Kamera-Move aus. Das Flag würde sonst
                            // scharf bleiben, bis irgendwann später ein manuelles Pan/Zoom ein
                            // Kamera-End-Event feuert, und dort fälschlich eine dann längst
                            // legitime Stale-Bereinigung überspringen. Ohne folgendes Kamera-Event
                            // übersteht die frische Selektion `recomputeClusters` ohnehin, da hier
                            // gar kein `.onMapCameraChange` ausgelöst wird.
                            selectedStopID = MapSelectionPlanner.toggled(current: selectedStopID, tapped: role.port.id)
                            primaryCruiseID = cruise.id
                            isSheetPresented = true
                            sheetDetent = .height(140)
                        }
                    } label: {
                        markerContent(for: role, routeIndex: index)
                    }
                    .buttonStyle(.plain)
                    // F4: konsolidiertes Label unabhängig vom Zoom-Bucket (Nummer + Name + Land),
                    // ersetzt das bisherige reine `role.port.name` — blinde Nutzer bekommen immer
                    // den vollen Datensatz, auch wenn sehende Nutzer bei diesem Zoom nur einen Dot
                    // sehen. Überschreibt bewusst vollständig (siehe `accessibilityLabel(for:totalStops:)`
                    // + `.accessibilityHidden(true)` auf den internen Badge-/Dot-Labels weiter unten
                    // — verhindert das bisherige Doppel-Announcement-Risiko).
                    .accessibilityLabel(Text(stopAccessibilityLabel(for: role, totalStops: portsToMark.count)))
                }
            } label: {
                EmptyView()
            }
        }
    }

    /// Marker-Inhalt je Zoom-Bucket: Welt-Zoom zeigt nur einen kleinen, routenfarbenen Dot
    /// (keine Labels/Rollen — Roadtrippers-/VesselFinder-Dichtereduktion statt Clustering),
    /// Reise-Zoom zeigt die vollen Rollen-Pins bzw. nummerierte Wegpunkt-Badges — bzw. bei einer
    /// Bildschirm-Überlappung (F4) ein Badge + „+N"-Pill als gemeinsames Tap-Target.
    @ViewBuilder
    func markerContent(for role: MapPortRole, routeIndex: Int) -> some View {
        let isSelected = selectedStopID == role.port.id
        switch zoomBucket {
        case .world:
            worldDotView(color: Color.routeColor(at: routeIndex))
        case .route:
            if role.type == .port {
                if let members = clusterMemberCoordinates[role.port.id], members.count > 1 {
                    clusteredBadge(for: role, routeIndex: routeIndex, isSelected: isSelected, memberCount: members.count)
                } else {
                    MapStopBadgeView(number: role.stopNumber, color: Color.routeColor(at: routeIndex), isSelected: isSelected)
                        // Tap-Fläche 22pt → 44pt (F4 Pflicht-Vorgabe „alle Marker-Varianten ≥44×44pt").
                        .contentShape(Circle().inset(by: -11))
                        // Label sitzt jetzt vollständig auf dem umschließenden Button (siehe oben) —
                        // verhindert ein doppeltes VoiceOver-Announcement der internen Zahl.
                        .accessibilityHidden(true)
                }
            } else {
                markerView(for: role, isSelected: isSelected)
            }
        }
    }

    /// Kombiniertes Badge+„+N"-Pill für überlappende Stops (F4 Overlap-Cluster) — EIN
    /// gemeinsames Tap-Target über beide Elemente (kein separater Callout im geclusterten
    /// Zustand, siehe Design-Spec F4 Gate #5b-Korrektur: Badge und Pill liegen bei einer
    /// 44×44pt-Mindest-Tap-Fläche zu dicht übereinander für eine zuverlässige Unterscheidung).
    /// Tap zoomt/rezentriert über `zoomTo(coordinates:)` auf alle Cluster-Mitglieder (siehe
    /// `MapClusterPlanner.tapOutcome` in der Button-Action oben) — die Kamera zieht sich
    /// zusammen, der Cluster löst sich beim nächsten `.onMapCameraChange` selbstständig in
    /// Einzel-Badges auf.
    private func clusteredBadge(for role: MapPortRole, routeIndex: Int, isSelected: Bool, memberCount: Int) -> some View {
        MapStopBadgeView(number: role.stopNumber, color: Color.routeColor(at: routeIndex), isSelected: isSelected)
            .overlay(alignment: .topTrailing) {
                Text("+\(memberCount - 1)")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 5)
                    .frame(height: 20)
                    .background(Color.navyDark)
                    .clipShape(Capsule())
                    .offset(x: 14, y: -10)
            }
            // Herleitung (Fix-Runde 1, F03b — ersetzt „grobzügig bemessen"): Badge ist 22×22pt
            // (`MapStopBadgeView`), Koordinatensystem badge-lokal mit (0,0) oben-links, Badge
            // spannt x:[0,22] y:[0,22]. `.overlay(alignment: .topTrailing)` legt die
            // Pill-Oberkante-rechts-Ecke VOR dem Offset auf die Badge-Oberkante-rechts-Ecke
            // (22,0). Pill-Breite ist nicht fix (Text „+N" mit 5pt Padding je Seite);
            // ShipTrip-Routen haben laut eigener Recherche (`b4-fertigloesungen-research.md:75`)
            // max. ~20 Stops/Route, d.h. N ≤ 19 ⇒ max. 3 Zeichen „+19" bei 11pt `.caption2`
            // semibold (~7pt/Zeichen großzügig geschätzt) ⇒ Textbreite ≈ 21pt + 2×5pt Padding
            // ≈ 31pt, aufgerundet auf 34pt für Sicherheitsabstand gegen die Schätzung. Vor dem
            // Offset spannt die Pill damit x:[22-34,22]=[-12,22] y:[0,20]; nach
            // `.offset(x:14,y:-10)`: x:[2,36] y:[-10,10]. Kombiniert mit dem Badge (x:[0,22]
            // y:[0,22]) ergibt sich eine Bounding-Box x:[0,36] y:[-10,22] — 36pt breit rechts
            // vom Badge-Zentrum (11,11) entfernt ist die bindende Kante. `Rectangle().inset(by:
            // -X)` liegt symmetrisch um das 22×22-Badge-Zentrum (Größe 22+2X); die rechte Kante
            // (22+X) muss ≥36 sein ⇒ X≥14. Gewählt: X=18 (Größe 58×58, ≥44 in beiden
            // Dimensionen, ~4pt Marge über der Mindestanforderung als Puffer gegen die
            // Text-Breiten-Schätzung).
            .contentShape(Rectangle().inset(by: -18))
            .accessibilityHidden(true)
    }

    /// Konsolidiertes VoiceOver-Label (F4): „Stopp {n} von {gesamt}, {Hafenname}, {Land}" für
    /// reguläre Zwischenstopps, „{Heimathafen/Endhafen}, {Hafenname}, {Land}" für Start-/
    /// Endpunkt-Rollen — unabhängig vom sichtbaren Zoom-Bucket (Seetage sind vor `markerRoles`
    /// bereits gefiltert, `case .seaDay` ist hier praktisch unerreichbar, aber vollständig
    /// gehalten).
    func stopAccessibilityLabel(for role: MapPortRole, totalStops: Int) -> String {
        let roleLabel: String
        switch role.type {
        case .homePort:
            roleLabel = String(localized: "Heimathafen")
        case .endPort:
            roleLabel = String(localized: "Endhafen")
        case .port:
            roleLabel = String(localized: "Stopp \(role.stopNumber) von \(totalStops)")
        case .seaDay:
            roleLabel = String(localized: "Seetag")
        }
        return "\(roleLabel), \(role.port.name), \(role.port.country)"
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
            // F4-Bugfix: bislang kein Inset — reale Tap-Fläche war ~9pt statt der geforderten
            // 44pt.
            .contentShape(Circle().inset(by: -17.5))
            .accessibilityHidden(true)
    }

    /// Einheitliche Pin-Darstellung (siehe `PortPinView`) mit Halo für Lesbarkeit auf der Karte —
    /// `Color.journalSurface` statt hartkodiertem `.white` (Journal Atlas, Karten-Redesign v2).
    func markerView(for role: MapPortRole, isSelected: Bool) -> some View {
        PortPinView(type: role.type)
            .padding(6)
            .background(Circle().fill(Color.journalSurface))
            .overlay(Circle().strokeBorder(Color.oceanBlue, lineWidth: isSelected ? 3 : 0))
            .shadow(color: .black.opacity(0.18), radius: 8, y: 4)
            // Herleitung (Fix-Runde 1, F03c — ersetzt „geschätzt"): `PortPinView` setzt
            // `.frame(width: 24)` explizit und `.font(.system(size: 20))` ohne `.imageScale()`
            // (= Default-Skalierung „medium"), Höhe bleibt dadurch ungebunden = intrinsische
            // SF-Symbol-Glyphhöhe. Für kompakte, kreisbasierte Symbole (`mappin.circle.fill`,
            // `mappin.and.ellipse.circle.fill`, `water.waves`) entspricht die gerenderte
            // Glyphhöhe bei „medium"-Skalierung nach Apples SF-Symbols-Konvention näherungsweise
            // dem Punktwert selbst, hier also ≈20pt. Mit dem hier gesetzten `.padding(6)` auf
            // allen vier Seiten: Breite 24+6+6=36pt, Höhe 20+6+6=32pt. `Circle().inset(by: -X)`
            // legt sich symmetrisch um dieses (nicht-quadratische) Frame — die kleinere
            // Dimension (Höhe 32pt) ist bindend: 32+2X≥44 ⇒ X≥6 (exakt an der Grenze, 0pt
            // Marge). Gewählt: X=7 (Höhe 46pt, Breite 50pt) — 2pt Sicherheitsabstand gegen die
            // ±2pt-Unsicherheit der Glyphhöhen-Schätzung, da sie kein Code-Literal, sondern eine
            // SF-Symbols-Konvention ist.
            .contentShape(Circle().inset(by: -7))
            // Label sitzt vollständig auf dem umschließenden Button (`stopAccessibilityLabel`);
            // `PortPinView` setzt aber selbst ein `.accessibilityLabel` pro Rolle
            // ("Heimathafen"/"Endhafen") — ohne dieses Flag würde VoiceOver beides ansagen
            // (Fix-Runde 1, F02 — bislang nur bei Badge/Dot konsequent gesetzt).
            .accessibilityHidden(true)
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

    // MARK: - Overlap-Cluster (F4)

    /// Berechnet `suppressedStopIDs`/`clusterMemberCoordinates` neu (Design-Politur Welle C, F4).
    /// Nur im `.route`-Bucket relevant — im `.world`-Bucket zeigt jeder Stop ohnehin nur einen
    /// kleinen Dot ohne Nummer, Clustering wäre dort unsichtbar/unnötig. Projiziert jeden
    /// `.port`-Zwischenstopp (Start/End-Rollen-Pins bleiben unclustered, sie rendern ohnehin
    /// anders als die Badges) in Bildschirmkoordinaten und übergibt sie an `MapClusterPlanner`.
    /// Speichert zusätzlich die echten Geo-Koordinaten aller Cluster-Mitglieder (nicht nur die
    /// Anzahl) — Grundlage für den Cluster-Tap-Zoom (Fix-Runde 1, F01): `zoomTo(coordinates:)`
    /// braucht die tatsächlichen Koordinaten, nicht nur ein Zähler.
    ///
    /// Aufgerufen aus `.onMapCameraChange(frequency: .onEnd)` (`MapView.swift`) — MapKit feuert
    /// das auch nach programmatischen, animierten Kamera-Sprüngen (`zoomTo`), sobald die
    /// Animation abgeschlossen ist. Eine zusätzliche synchrone Vorab-Berechnung direkt in
    /// `zoomTo` (wie beim reinen Zoom-Bucket) ist hier bewusst NICHT umgesetzt: die
    /// Bildschirm-Projektion hängt vom tatsächlich gerenderten Kamera-Transform ab, der während
    /// einer noch laufenden Animation schlicht noch nicht existiert — anders als der Zoom-Bucket
    /// ist das keine reine Geometrie-Berechnung auf der Ziel-Region, sondern erfordert den
    /// live gerenderten Map-Zustand.
    ///
    /// `suppressSelectionCleanupOnNextCameraEnd` (Fix-Runde 3, P1): One-Shot-Guard, gesetzt
    /// ausschließlich beim Sheet-Row-Tap (`onStopTap`), da dort direkt ein programmatischer
    /// `zoomTo`-Kamera-Move folgt, dessen `.onMapCameraChange(.onEnd)` diese frische Selektion
    /// sonst sofort wieder wegräumen würde. Regulärer Marker-Tap (inkl. Unresolvable-Cluster-
    /// Fallback) setzt das Flag NICHT — er löst keinen Kamera-Move aus und braucht den Schutz
    /// daher nicht (Fix-Runde 4, Codex-Auflage). Wird hier per `defer` nach GENAU einem
    /// Durchlauf zurückgesetzt — unabhängig davon, welcher Zweig (früher Return bei `.world`
    /// oder der volle Cluster-Aufbau) tatsächlich läuft, damit das Flag nie „hängen bleibt" und
    /// einen späteren, echten Stale-Fall fälschlich überspringt.
    func recomputeClusters(using reader: MapProxy) {
        defer { suppressSelectionCleanupOnNextCameraEnd = false }

        guard zoomBucket == .route else {
            suppressedStopIDs = []
            clusterMemberCoordinates = [:]
            return
        }

        var suppressed: Set<UUID> = []
        var memberCoordinates: [UUID: [CLLocationCoordinate2D]] = [:]

        for route in displayedRoutes {
            let portableStops = MapMarkerPlanner.markerRoles(for: validPorts(for: route.cruise))
                .filter { $0.type == .port }
            let coordinateByID = Dictionary(uniqueKeysWithValues: portableStops.map { ($0.port.id, $0.port.coordinate) })

            let clusterPoints: [MapClusterPoint] = portableStops.compactMap { role in
                guard let screenPoint = reader.convert(role.port.coordinate, to: .local) else { return nil }
                return MapClusterPoint(id: role.port.id, stopNumber: role.stopNumber, screenPoint: screenPoint)
            }
            guard clusterPoints.count > 1 else { continue }

            let groups = MapClusterPlanner.clusters(points: clusterPoints, collisionDistance: 28)
            for group in groups where !group.suppressedIDs.isEmpty {
                suppressed.formUnion(group.suppressedIDs)
                let memberIDs = [group.primaryID] + group.suppressedIDs
                memberCoordinates[group.primaryID] = memberIDs.compactMap { coordinateByID[$0] }
            }
        }

        suppressedStopIDs = suppressed
        clusterMemberCoordinates = memberCoordinates

        // Fix-Runde 2, F02: eine Auswahl, die VOR diesem Durchlauf getroffen wurde, kann durch
        // das gerade berechnete Clustering ungültig geworden sein (Stop ist jetzt suppressed
        // oder selbst Cluster-Primary) — dann würde ein Callout für einen nicht mehr individuell
        // gerenderten/anders interagierbaren Stop hängen bleiben. Betrifft nur `selectedStopID`/
        // `isSheetPresented` (kein `position`-State) — löst also keinen erneuten
        // `.onMapCameraChange` aus, kein Loop-Risiko. Fix-Runde 3, P1: `suppressCleanup`
        // schützt eine frische, gerade eben vom Nutzer getroffene Selektion vor genau diesem
        // ersten Durchlauf danach (siehe Guard-Doc-Kommentar oben).
        let cleanedSelection = MapSelectionPlanner.selection(
            selectedStopID,
            afterClusteringWith: suppressedStopIDs,
            clusterMemberCoordinates: clusterMemberCoordinates,
            suppressCleanup: suppressSelectionCleanupOnNextCameraEnd
        )
        if cleanedSelection != selectedStopID {
            selectedStopID = cleanedSelection
            isSheetPresented = false
        }
    }
}
