//
//  CruiseLoeschenFilterUITests.swift
//  ShipTripUITests
//
//  UI-Smoke-Tests für Task S1.1 (Audit 2026-07-10):
//  - H1: Filter ohne Treffer war ein UX-Dead-End (keine Reset-Möglichkeit auf dem Screen).
//  - H5: Reise-Löschung in CruiseListView lief ohne Bestätigung/Rollback.
//

import XCTest

@MainActor
final class CruiseLoeschenFilterUITests: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = false
        // Der Simulator kann von einem vorherigen Lauf noch im Landscape-Zustand sein; im
        // verkleinerten Landscape-Viewport werden Zeilen/Buttons außerhalb des sichtbaren
        // Bereichs nicht gerendert, was nachfolgende Element-Queries verfälscht.
        XCUIDevice.shared.orientation = .portrait
    }

    // MARK: - Helper

    private func heroCard(_ app: XCUIApplication) -> XCUIElement {
        app.descendants(matching: .any).matching(identifier: "heroCard").firstMatch
    }

    private func filterMenuButton(_ app: XCUIApplication) -> XCUIElement {
        app.descendants(matching: .any).matching(identifier: "filterMenuButton").firstMatch
    }

    // MARK: - H1: Filter ohne Treffer → Reset erreichbar, Liste kommt zurück

    func testFilterOhneTrefferBietetResetUndListeKehrtZurueck() throws {
        let app = XCUIApplication()
        app.launchArguments += ["-uiTestingResetAndLoadDemoData", "-uiTestingCompleteOnboarding"]
        app.launch()

        let reisenTab = app.tabBars.buttons["Reisen"]
        XCTAssertTrue(reisenTab.waitForExistence(timeout: 10))
        reisenTab.tap()

        XCTAssertTrue(heroCard(app).waitForExistence(timeout: 10), "Hero-Karte vor dem Filtern nicht gefunden")

        filterMenuButton(app).tap()
        app.buttons["Jahr"].tap()

        // Dynamisch statt hartem Jahres-Literal (Codex-Auflage): im absteigend sortierten
        // Jahr-Menü ist der LETZTE (älteste) Jahres-Button garantiert eine der beiden fest
        // datierten Demo-Reisen (Jahr liegt für immer in der Vergangenheit relativ zu "heute").
        // Die einzige AIDA-Reise ("Norwegische Fjorde") ist dynamisch auf heute+21 Tage datiert
        // und damit immer neuer als die fest datierten Reisen – landet also nie ganz unten in
        // der Liste. Das älteste Jahr + Reederei "AIDA Cruises" ergibt so unabhängig vom
        // Testdatum garantiert 0 Treffer, ohne ein Jahr zu erraten, das im Menü existiert.
        let yearButtons = app.buttons.matching(NSPredicate(format: "label MATCHES %@", "^[0-9]{4}$"))
        XCTAssertTrue(yearButtons.firstMatch.waitForExistence(timeout: 5), "Jahr-Menü zeigt keine Jahres-Buttons")
        yearButtons.element(boundBy: yearButtons.count - 1).tap()

        filterMenuButton(app).tap()
        app.buttons["Reederei"].tap()
        app.buttons["AIDA Cruises"].tap()

        let noMatchState = app.descendants(matching: .any)
            .matching(NSPredicate(format: "label == %@", "Keine Treffer"))
            .firstMatch
        XCTAssertTrue(noMatchState.waitForExistence(timeout: 5), "Leerer Filter-Zustand nicht erreicht")

        // H1-Fix: Reset-Action direkt im leeren Zustand, kein Neustart/Zufalls-Fix nötig.
        let resetButton = app.buttons["Filter zurücksetzen"]
        XCTAssertTrue(resetButton.waitForExistence(timeout: 5), "Reset-Button im leeren Filter-Zustand fehlt (H1)")
        resetButton.tap()

        XCTAssertTrue(heroCard(app).waitForExistence(timeout: 5), "Liste kehrt nach Reset nicht zurück (H1)")
        XCTAssertFalse(noMatchState.exists, "Leerer Zustand besteht nach Reset weiter")
    }

    // MARK: - H5: Löschen zeigt Dialog, Abbrechen behält Reise, Bestätigen entfernt sie

    func testKreuzfahrtLoeschenZeigtDialogAbbrechenUndBestaetigen() throws {
        let app = XCUIApplication()
        app.launchArguments += ["-uiTestingResetAndLoadDemoData", "-uiTestingCompleteOnboarding"]
        app.launch()

        let reisenTab = app.tabBars.buttons["Reisen"]
        XCTAssertTrue(reisenTab.waitForExistence(timeout: 10))
        reisenTab.tap()

        let hero = heroCard(app)
        XCTAssertTrue(hero.waitForExistence(timeout: 10), "Hero-Karte nicht gefunden")

        // Demo-Reise "Norwegische Fjorde" ist die einzige zukünftige Reise → immer Hero.
        let heroTitle = app.staticTexts["Norwegische Fjorde"]
        XCTAssertTrue(heroTitle.waitForExistence(timeout: 5))

        // 1. Abbrechen behält die Reise.
        hero.press(forDuration: 1.0)
        let contextMenuDelete = app.buttons["Löschen"]
        XCTAssertTrue(contextMenuDelete.waitForExistence(timeout: 5), "Kontextmenü-Löschen nicht gefunden")
        contextMenuDelete.tap()

        let dialogTitle = app.staticTexts["Kreuzfahrt löschen?"]
        XCTAssertTrue(dialogTitle.waitForExistence(timeout: 5), "Bestätigungsdialog erscheint nicht (H5)")

        app.buttons["Abbrechen"].tap()
        XCTAssertTrue(heroTitle.waitForExistence(timeout: 5), "Reise wurde nach Abbrechen fälschlich entfernt (H5)")

        // 2. Bestätigen löscht tatsächlich.
        hero.press(forDuration: 1.0)
        app.buttons["Löschen"].tap()
        XCTAssertTrue(app.staticTexts["Kreuzfahrt löschen?"].waitForExistence(timeout: 5))
        app.buttons["Löschen"].tap()

        XCTAssertTrue(heroTitle.waitForNonExistence(timeout: 5), "Reise wurde nach Bestätigen nicht entfernt (H5)")
    }
}
