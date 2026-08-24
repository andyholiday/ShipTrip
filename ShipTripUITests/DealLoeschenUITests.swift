//
//  DealLoeschenUITests.swift
//  ShipTripUITests
//
//  UI-Smoke-Test für Stabilitätswelle S1 (Audit 2026-07-10, H4):
//  Der als Hero dargestellte (neueste) Wunschreise-Eintrag war strukturell unlöschbar
//  (DealsView.deleteListDeals überspringt Index 0). Fix: Kontextmenü + Alert-Bestätigung
//  auf dem Hero. Dieser Test deckt den kompletten Pfad ab: Alert erscheint, Abbrechen
//  behält den Eintrag, Bestätigen entfernt ihn.
//

import XCTest

final class DealLoeschenUITests: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = false
        // Siehe AusflugLoeschenUITests: Simulator kann noch im Landscape-Zustand vom
        // vorherigen Lauf sein, was Zeilen-Queries außerhalb des sichtbaren Bereichs lässt.
        XCUIDevice.shared.orientation = .portrait
    }

    // MARK: - H4: Hero-Deal löschbar (Kontextmenü + Alert)

    @MainActor
    func testNeuesterWunschreiseEintragIstAlsHeroLoeschbar() throws {
        let app = XCUIApplication()
        app.launchArguments += ["-uiTestingResetAndLoadDemoData", "-uiTestingCompleteOnboarding"]
        app.launch()

        let dealTitle = "UI-Test-Wunschreise-S1.3"

        // 1. Zum Wunschreisen-Tab wechseln.
        let dealsTab = app.tabBars.buttons["Wunschreisen"]
        XCTAssertTrue(dealsTab.waitForExistence(timeout: 10))
        dealsTab.tap()

        // 2. Neuen Eintrag anlegen – wird über \Deal.createdAt (order: .reverse) automatisch
        // der neueste und damit der Hero-Eintrag, unabhängig von den Demo-Daten.
        let addButton = app.navigationBars["Wunschreisen"].buttons["Eintrag hinzufügen"]
        XCTAssertTrue(addButton.waitForExistence(timeout: 10), "Button 'Eintrag hinzufügen' nicht gefunden")
        addButton.tap()

        let titleField = app.textFields["Titel"]
        XCTAssertTrue(titleField.waitForExistence(timeout: 5))
        titleField.tap()
        titleField.typeText(dealTitle)

        let saveButton = app.navigationBars["Neuer Eintrag"].buttons["Speichern"]
        XCTAssertTrue(saveButton.waitForExistence(timeout: 5))
        saveButton.tap()

        // 3. Neuer Eintrag muss als Hero-Karte sichtbar sein.
        let heroTitle = app.staticTexts[dealTitle]
        XCTAssertTrue(heroTitle.waitForExistence(timeout: 10), "Neu angelegte Wunschreise nicht als Hero sichtbar")

        // 4. Kontextmenü öffnen, Löschen antippen → Bestätigungs-Alert erscheint.
        heroTitle.press(forDuration: 1.2)

        let contextMenuDeleteButton = app.buttons["Löschen"].firstMatch
        XCTAssertTrue(contextMenuDeleteButton.waitForExistence(timeout: 5), "Kontextmenü-Eintrag 'Löschen' fehlt")
        contextMenuDeleteButton.tap()

        let dialogTitle = app.staticTexts["Eintrag löschen?"]
        XCTAssertTrue(dialogTitle.waitForExistence(timeout: 5), "Bestätigungsdialog erscheint nicht")

        // 5. Abbrechen → Eintrag bleibt erhalten.
        let cancelButton = app.buttons["Abbrechen"]
        XCTAssertTrue(cancelButton.waitForExistence(timeout: 5))
        cancelButton.tap()
        XCTAssertTrue(heroTitle.waitForExistence(timeout: 5), "Eintrag nach 'Abbrechen' nicht mehr sichtbar")

        // 6. Erneut löschen, diesmal bestätigen → Eintrag verschwindet.
        heroTitle.press(forDuration: 1.2)

        let contextMenuDeleteButtonAgain = app.buttons["Löschen"].firstMatch
        XCTAssertTrue(contextMenuDeleteButtonAgain.waitForExistence(timeout: 5))
        contextMenuDeleteButtonAgain.tap()

        let confirmDeleteButton = app.buttons["Löschen"].firstMatch
        XCTAssertTrue(confirmDeleteButton.waitForExistence(timeout: 5), "Bestätigen-Button im Dialog fehlt")
        confirmDeleteButton.tap()

        XCTAssertTrue(heroTitle.waitForNonExistence(timeout: 5), "Eintrag wurde nach Bestätigen nicht gelöscht")
    }
}
