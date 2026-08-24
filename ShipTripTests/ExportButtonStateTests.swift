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

    /// REPRO (rot vor dem Fix): Export, Import und „Alle Daten löschen" sperrten sich nicht
    /// gegenseitig — ein Import oder ein Löschen konnte einem laufenden Export die Modelle unter
    /// den Händen wegziehen. Jetzt sperrt jede laufende Aktion die anderen beiden.
    @Test("Jede laufende Datenaktion sperrt die anderen")
    @MainActor
    func runningActionBlocksTheOthers() {
        func blocked(_ isExporting: Bool, _ isImporting: Bool) -> Bool {
            DataManagementView.isDataActionBlocked(isExporting: isExporting, isImporting: isImporting)
        }

        #expect(blocked(false, false) == false, "Im Ruhezustand ist nichts gesperrt")
        #expect(blocked(true, false), "Laufender Export sperrt Import und Löschen")
        #expect(blocked(false, true), "Laufender Import sperrt Export und Löschen")
        #expect(blocked(true, true))
    }
}
