//
//  MapRouteVisibilityPlannerTests.swift
//  ShipTripTests
//
//  Tests für `MapRouteVisibilityPlanner` (Karten-Redesign v2 „Journal Atlas"): Burger-Menü-
//  Semantik für Alle-ein/ausblenden + Einzel-Routen-Toggle inkl. Guard gegen eine leere Karte.
//

import Testing
import Foundation
@testable import ShipTrip

@Suite("MapRouteVisibilityPlanner.activeRouteIDs")
struct MapRouteVisibilityPlannerActiveRouteIDsTests {

    @Test("Default (leere Auswahl, nicht ausgeblendet) ergibt alle routbaren Reisen")
    func defaultShowsAllRoutable() {
        let routable: Set<UUID> = [UUID(), UUID(), UUID()]
        let result = MapRouteVisibilityPlanner.activeRouteIDs(
            selectedRouteIDs: [],
            allRoutesHidden: false,
            routableCruiseIDs: routable
        )
        #expect(result == routable)
    }

    @Test("allRoutesHidden hat Vorrang vor einer nicht-leeren selectedRouteIDs-Auswahl")
    func allRoutesHiddenOverridesSelection() {
        let a = UUID()
        let result = MapRouteVisibilityPlanner.activeRouteIDs(
            selectedRouteIDs: [a],
            allRoutesHidden: true,
            routableCruiseIDs: [a, UUID()]
        )
        #expect(result.isEmpty)
    }

    @Test("Nicht-leere Auswahl ohne allRoutesHidden ergibt exakt diese Auswahl")
    func explicitSelectionIsUsedAsIs() {
        let a = UUID()
        let b = UUID()
        let c = UUID()
        let result = MapRouteVisibilityPlanner.activeRouteIDs(
            selectedRouteIDs: [a],
            allRoutesHidden: false,
            routableCruiseIDs: [a, b, c]
        )
        #expect(result == [a])
    }
}

@Suite("MapRouteVisibilityPlanner.hidingAll / showingAll")
struct MapRouteVisibilityPlannerAllToggleTests {

    @Test("Alle ausblenden setzt nur das Flag, selectedRouteIDs bleibt unangetastet")
    func hidingAllPreservesSelection() {
        let existing: Set<UUID> = [UUID()]
        let result = MapRouteVisibilityPlanner.hidingAll(selectedRouteIDs: existing)

        #expect(result.allRoutesHidden == true)
        #expect(result.selectedRouteIDs == existing)
    }

    @Test("Alle einblenden räumt beides zurück auf den Default (leer, nicht ausgeblendet)")
    func showingAllResetsToDefault() {
        let result = MapRouteVisibilityPlanner.showingAll()

        #expect(result.allRoutesHidden == false)
        #expect(result.selectedRouteIDs.isEmpty)
    }

    @Test("Alle ausblenden gefolgt von Alle einblenden ergibt wieder alle sichtbar")
    func hideThenShowRoundTrips() {
        let routable: Set<UUID> = [UUID(), UUID()]
        let hidden = MapRouteVisibilityPlanner.hidingAll(selectedRouteIDs: [])
        #expect(MapRouteVisibilityPlanner.activeRouteIDs(
            selectedRouteIDs: hidden.selectedRouteIDs,
            allRoutesHidden: hidden.allRoutesHidden,
            routableCruiseIDs: routable
        ).isEmpty)

        let shown = MapRouteVisibilityPlanner.showingAll()
        #expect(MapRouteVisibilityPlanner.activeRouteIDs(
            selectedRouteIDs: shown.selectedRouteIDs,
            allRoutesHidden: shown.allRoutesHidden,
            routableCruiseIDs: routable
        ) == routable)
    }
}

@Suite("MapRouteVisibilityPlanner.toggling")
struct MapRouteVisibilityPlannerTogglingTests {

    @Test("Einzel-Tap auf eine bisher inaktive Route (bei impliziter Alle-Auswahl) reduziert auf genau diese Route")
    func togglingInactiveRouteFromImplicitAllSelectsOnlyThatRoute() {
        let a = UUID()
        let b = UUID()
        let routable: Set<UUID> = [a, b]

        // Default-Zustand: leere Auswahl == alle sichtbar. Tap auf `a` (bereits „aktiv" da alle
        // sichtbar sind) entfernt `a` aus der aktiven Menge, `b` bleibt übrig.
        let result = MapRouteVisibilityPlanner.toggling(
            routeID: a,
            selectedRouteIDs: [],
            allRoutesHidden: false,
            routableCruiseIDs: routable
        )

        #expect(result.selectedRouteIDs == [b])
        #expect(result.allRoutesHidden == false)
    }

    @Test("Einzel-Tap verlässt den allRoutesHidden-Zustand implizit")
    func togglingLeavesAllRoutesHiddenState() {
        let a = UUID()
        let routable: Set<UUID> = [a, UUID()]

        let result = MapRouteVisibilityPlanner.toggling(
            routeID: a,
            selectedRouteIDs: [],
            allRoutesHidden: true,
            routableCruiseIDs: routable
        )

        #expect(result.allRoutesHidden == false)
        // Ausgehend von „alle ausgeblendet" (aktive Menge leer) fügt der Tap `a` neu hinzu.
        #expect(result.selectedRouteIDs == [a])
    }

    @Test("Letzte verbleibende Route kann nicht per Einzel-Tap auf null reduziert werden")
    func lastRemainingRouteCannotBeDeselectedAlone() {
        let a = UUID()
        let routable: Set<UUID> = [a]

        let result = MapRouteVisibilityPlanner.toggling(
            routeID: a,
            selectedRouteIDs: [a],
            allRoutesHidden: false,
            routableCruiseIDs: routable
        )

        // Guard greift: einzige aktive Route bleibt aktiv, kein leeres Set als Ergebnis.
        #expect(result.selectedRouteIDs == [a])
    }

    @Test("Tap auf eine bereits abgewählte Route bei mehreren aktiven Routen fügt sie wieder hinzu")
    func togglingReselectsPreviouslyDeselectedRoute() {
        let a = UUID()
        let b = UUID()
        let routable: Set<UUID> = [a, b]

        let result = MapRouteVisibilityPlanner.toggling(
            routeID: a,
            selectedRouteIDs: [b],
            allRoutesHidden: false,
            routableCruiseIDs: routable
        )

        #expect(result.selectedRouteIDs == [a, b])
    }
}
