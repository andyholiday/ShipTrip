//
//  ExportButtonStateTests.swift
//  ShipTripTests
//
//  Sperrbedingung des Export-Buttons in „Daten verwalten": Der Export umfasst fünf
//  Sammlungen — er darf erst gesperrt sein, wenn alle fünf leer sind.
//

import Testing
@testable import ShipTrip

@Suite("Export-Button: Sperrbedingung")
struct ExportButtonStateTests {

    /// REPRO (rot vor dem Fix): die Bedingung war `cruises.isEmpty && deals.isEmpty` — wer nur
    /// eigene Reedereien/Schiffe angelegt oder Katalog-Einträge ausgeblendet hatte, konnte diese
    /// Daten nicht sichern, obwohl der Export sie schreibt.
    @Test("Jede einzelne gefüllte Sammlung hält den Export offen; leer ist nur ganz leer")
    @MainActor
    func exportIsDisabledOnlyWhenAllCollectionsAreEmpty() {
        typealias Counts = (cruises: Int, deals: Int, lines: Int, ships: Int, hidden: Int)
        func hasData(_ counts: Counts) -> Bool {
            DataManagementView.hasExportableData(
                cruises: counts.cruises, deals: counts.deals, customLines: counts.lines,
                customShips: counts.ships, hiddenCatalogItems: counts.hidden
            )
        }

        #expect(hasData((1, 0, 0, 0, 0)))
        #expect(hasData((0, 1, 0, 0, 0)))
        #expect(hasData((0, 0, 1, 0, 0)), "Eigene Reederei allein muss exportierbar bleiben")
        #expect(hasData((0, 0, 0, 1, 0)), "Eigenes Schiff allein muss exportierbar bleiben")
        #expect(hasData((0, 0, 0, 0, 1)), "Ausblendung allein muss exportierbar bleiben")
        #expect(hasData((0, 0, 0, 0, 0)) == false)
    }
}
