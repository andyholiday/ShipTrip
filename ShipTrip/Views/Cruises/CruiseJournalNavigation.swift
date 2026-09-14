//
//  CruiseJournalNavigation.swift
//  ShipTrip
//
//  Navigations-Naht zwischen Route-Faden (T8b) und Journal-Ansichten (T8c)
//  — Contract J3neu (c)/(d).
//

import SwiftUI

/// Wohin der Route-Journal-Faden gerade führt.
///
/// Liegt bewusst neben der `CruiseDetailView` (Muster `CruiseShareModel`), damit
/// die ohnehin große Detailansicht nur den Zustand hält und nicht auch noch die
/// Ziele. Nach J3neu führen die Eintragszeilen **ausschließlich** in die
/// Detailansicht — Bearbeiten und Löschen gibt es nur dort, nicht im Faden.
@MainActor
@Observable
final class CruiseJournalNavigation {

    /// Ein Editor-Aufruf. Eigene `id`, weil `.sheet(item:)` `Identifiable`
    /// verlangt und derselbe Stopp mehrmals hintereinander vorkommen darf.
    struct EditorRequest: Identifiable {
        let id = UUID()
        let prefill: JournalEntryPrefill
    }

    /// Gepushtes Ziel der Eintrags-Detailansicht; `nil` = nichts offen.
    var openedEntryID: UUID?

    /// Offener Editor als Sheet; `nil` = kein Editor.
    var editorRequest: EditorRequest?

    func openEntry(id: UUID) {
        openedEntryID = id
    }

    /// - Parameter port: der aufgeklappte Stopp, aus dem heraus erfasst wird;
    ///   `nil` = Einstieg aus dem Sammelblock „Weitere Einträge" (J2-Defaults).
    func addEntry(at port: Port?) {
        let prefill = port.map { JournalEntryPrefill.stop(portID: $0.id, arrival: $0.arrival) }
            ?? .noStop
        editorRequest = EditorRequest(prefill: prefill)
    }
}

extension View {
    /// Hängt Eintrags-Detailansicht (Push) und Eintrag-Editor (Sheet) an den
    /// Route-Faden — die Einstiegs-Signaturen aus T8c.
    func cruiseJournalNavigation(
        _ navigation: CruiseJournalNavigation,
        cruise: Cruise
    ) -> some View {
        modifier(CruiseJournalNavigationModifier(navigation: navigation, cruise: cruise))
    }
}

private struct CruiseJournalNavigationModifier: ViewModifier {
    @Bindable var navigation: CruiseJournalNavigation
    let cruise: Cruise

    func body(content: Content) -> some View {
        content
            // Push in den umgebenden `NavigationStack` — die Detailansicht bringt
            // laut ihrem Einstiegs-Vertrag bewusst keinen eigenen mit.
            .navigationDestination(item: $navigation.openedEntryID) { entryID in
                JournalEntryDetailView(entryID: entryID)
            }
            // Der Editor ist ein Sheet und bringt seinen `NavigationStack` selbst mit.
            .sheet(item: $navigation.editorRequest) { request in
                JournalEntryEditorView(cruise: cruise, prefill: request.prefill)
            }
    }
}
