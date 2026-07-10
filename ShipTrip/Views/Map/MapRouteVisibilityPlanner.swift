//
//  MapRouteVisibilityPlanner.swift
//  ShipTrip
//
//  Reine Sichtbarkeits-Logik für das Burger-Menü im Karten-Redesign v2 „Journal Atlas".
//

import Foundation

/// Leitet die tatsächlich aktiven Routen-IDs aus dem Auswahl-Zustand ab und kapselt die
/// Zustandsübergänge des Burger-Menüs (Einzel-Toggle, Alle ausblenden, Alle wieder einblenden).
/// Rein und ohne SwiftUI-Abhängigkeit, damit die Semantik isoliert testbar ist (Muster
/// `MapSelectionPlanner`).
///
/// Hintergrund: `selectedRouteIDs.isEmpty` kodiert historisch „alle sichtbar" — das kollidiert
/// mit der neuen Anforderung „ein Klick blendet alle aus", weil ein leeres Set sonst wieder als
/// „alle" interpretiert würde. Das separate `allRoutesHidden`-Flag löst den Widerspruch: es hat
/// Vorrang vor `selectedRouteIDs` und wird ausschließlich über die explizite Alle-ausblenden-Zeile
/// gesetzt, nicht durch Wegtippen der letzten Einzelroute.
enum MapRouteVisibilityPlanner {
    /// Ergebnis eines Zustandsübergangs: neue `selectedRouteIDs` + `allRoutesHidden`.
    struct Selection: Equatable {
        let selectedRouteIDs: Set<UUID>
        let allRoutesHidden: Bool
    }

    /// Leitet die tatsächlich aktiven Routen-IDs aus dem Auswahl-Zustand ab. `allRoutesHidden`
    /// hat Vorrang vor `selectedRouteIDs`.
    static func activeRouteIDs(
        selectedRouteIDs: Set<UUID>,
        allRoutesHidden: Bool,
        routableCruiseIDs: Set<UUID>
    ) -> Set<UUID> {
        if allRoutesHidden { return [] }
        return selectedRouteIDs.isEmpty ? routableCruiseIDs : selectedRouteIDs
    }

    /// Einzel-Tap auf eine Route: verlässt „alle ausgeblendet" implizit und togglet die Route in
    /// der aktiven Menge. Schutzregel: die letzte verbleibende Route kann nicht per Einzel-Tap auf
    /// null reduziert werden — nur die explizite Alle-ausblenden-Zeile darf die Karte vollständig
    /// leeren (verhindert eine versehentlich leere Karte, die wie ein Bug aussieht).
    static func toggling(
        routeID: UUID,
        selectedRouteIDs: Set<UUID>,
        allRoutesHidden: Bool,
        routableCruiseIDs: Set<UUID>
    ) -> Selection {
        var next = activeRouteIDs(
            selectedRouteIDs: selectedRouteIDs,
            allRoutesHidden: allRoutesHidden,
            routableCruiseIDs: routableCruiseIDs
        )
        if next.contains(routeID), next.count > 1 {
            next.remove(routeID)
        } else {
            next.insert(routeID)
        }
        return Selection(selectedRouteIDs: next, allRoutesHidden: false)
    }

    /// Explizite „Alle ausblenden"-Zeile: setzt nur das Flag, lässt `selectedRouteIDs` unangetastet
    /// — „Alle einblenden" muss den vorherigen Auswahlzustand dadurch nicht extra merken.
    static func hidingAll(selectedRouteIDs: Set<UUID>) -> Selection {
        Selection(selectedRouteIDs: selectedRouteIDs, allRoutesHidden: true)
    }

    /// Explizite „Alle einblenden"-Zeile: räumt beides auf den Default zurück (leere Auswahl, die
    /// über `activeRouteIDs` wieder als „alle sichtbar" interpretiert wird).
    static func showingAll() -> Selection {
        Selection(selectedRouteIDs: [], allRoutesHidden: false)
    }
}
