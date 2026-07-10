//
//  ReedereiAnlegenUITests.swift
//  ShipTripUITests
//
//  UI-Regressionstest für Welle D (TestFlight-Feedback):
//  - D2: Nach dem Anlegen einer eigenen Reederei wird direkt zum Schiff-Anlege-Formular
//    weitergeleitet, statt den Nutzer in der Reederei-Liste stehen zu lassen.
//

import XCTest

final class ReedereiAnlegenUITests: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = false
        // Siehe AusflugLoeschenUITests: im Landscape-Viewport werden Form-/List-Zeilen
        // außerhalb des sichtbaren Bereichs nicht gerendert – fest auf Portrait fixieren.
        XCUIDevice.shared.orientation = .portrait
    }

    /// Navigiert von "Mehr" zu "Eigene Reedereien & Schiffe" (wie testEinstellungenHinweisSichtbar
    /// in AusflugLoeschenUITests).
    @MainActor
    private func navigateToShippingLineManagement(_ app: XCUIApplication) {
        let moreTab = app.tabBars.buttons["Mehr"]
        XCTAssertTrue(moreTab.waitForExistence(timeout: 10))
        moreTab.tap()

        let settingsList = app.collectionViews.firstMatch
        if settingsList.waitForExistence(timeout: 5) {
            settingsList.swipeUp()
            settingsList.swipeUp()
        } else {
            app.swipeUp()
            app.swipeUp()
        }

        let managementLink = app.buttons["Eigene Reedereien & Schiffe"]
        XCTAssertTrue(managementLink.waitForExistence(timeout: 5))
        managementLink.tap()
    }

    // MARK: - D2: Eigene Reederei anlegen → Schiff-Formular erscheint automatisch

    @MainActor
    func testEigeneReedereiAnlegenOeffnetSchiffFormularAutomatisch() throws {
        let app = XCUIApplication()
        app.launch()

        // Eindeutiger Name pro Testlauf: CustomShippingLine-Namen werden app-seitig auf
        // Kollision geprüft (ADR-006) und bleiben zwischen Testläufen auf demselben Simulator
        // bestehen (anders als Demo-Cruises/-Deals, die -uiTestingResetAndLoadDemoData zurücksetzt).
        let uniqueSuffix = String(UUID().uuidString.prefix(8))
        let lineName = "UI-Test-Reederei-D2-\(uniqueSuffix)"
        let shipName = "UI-Test-Schiff-D2-\(uniqueSuffix)"

        navigateToShippingLineManagement(app)

        // 2. Eigene Reederei anlegen.
        let addLineButton = app.buttons["Eigene Reederei anlegen"]
        XCTAssertTrue(addLineButton.waitForExistence(timeout: 5))
        addLineButton.tap()

        let lineNameField = app.textFields["Name"]
        XCTAssertTrue(lineNameField.waitForExistence(timeout: 5))
        lineNameField.tap()
        lineNameField.typeText(lineName)

        let saveLineButton = app.navigationBars["Eigene Reederei"].buttons["Speichern"]
        XCTAssertTrue(saveLineButton.waitForExistence(timeout: 5))
        saveLineButton.tap()

        // 3. Das Schiff-Anlege-Formular muss jetzt automatisch erscheinen (D2) – ohne dass der
        // Nutzer erst auf "Eigenes Schiff hinzufügen" tippen muss.
        let shipNameField = app.textFields["Schiffsname"]
        XCTAssertTrue(shipNameField.waitForExistence(timeout: 5),
                      "Schiff-Formular öffnet nach dem Anlegen der Reederei nicht automatisch (D2)")

        // 4. Formular abbrechen → Nutzer landet in der Schiff-Liste der neuen Reederei.
        app.navigationBars["Eigenes Schiff"].buttons["Abbrechen"].tap()

        XCTAssertTrue(app.navigationBars[lineName].waitForExistence(timeout: 5),
                      "Nach Abbrechen nicht in der Schiff-Liste der neuen Reederei")
        let addShipButton = app.buttons["Eigenes Schiff hinzufügen"]
        XCTAssertTrue(addShipButton.waitForExistence(timeout: 5))

        // 5. One-Shot-Guard: Formular darf nach dem Abbrechen nicht erneut automatisch erscheinen.
        XCTAssertFalse(app.textFields["Schiffsname"].exists,
                       "Schiff-Formular öffnet nach dem Abbrechen erneut (One-Shot-Guard verletzt)")

        // 6. Erstes Schiff manuell anlegen → erscheint in der Liste der neuen Reederei.
        addShipButton.tap()
        let shipNameFieldAgain = app.textFields["Schiffsname"]
        XCTAssertTrue(shipNameFieldAgain.waitForExistence(timeout: 5))
        shipNameFieldAgain.tap()
        shipNameFieldAgain.typeText(shipName)

        let saveShipButton = app.navigationBars["Eigenes Schiff"].buttons["Speichern"]
        XCTAssertTrue(saveShipButton.waitForExistence(timeout: 5))
        saveShipButton.tap()

        XCTAssertTrue(app.staticTexts[shipName].waitForExistence(timeout: 5),
                      "Neu angelegtes Schiff erscheint nicht in der Liste der neuen Reederei")
    }

    // MARK: - D2: Abbruch des Reederei-Formulars löst KEINE Auto-Navigation aus

    @MainActor
    func testReedereiFormularAbbrechenLoestKeineAutoNavigationAus() throws {
        let app = XCUIApplication()
        app.launch()

        navigateToShippingLineManagement(app)

        let addLineButton = app.buttons["Eigene Reederei anlegen"]
        XCTAssertTrue(addLineButton.waitForExistence(timeout: 5))
        addLineButton.tap()

        let lineNameField = app.textFields["Name"]
        XCTAssertTrue(lineNameField.waitForExistence(timeout: 5))
        lineNameField.tap()
        lineNameField.typeText("UI-Test-Reederei-D2-Abbruch")

        app.navigationBars["Eigene Reederei"].buttons["Abbrechen"].tap()

        // Kein Pending-Ziel bei Abbruch (D2, Punkt 5): keine Auto-Navigation, kein automatisch
        // geöffnetes Schiff-Formular, Nutzer bleibt in der Reederei-Liste.
        XCTAssertTrue(addLineButton.waitForExistence(timeout: 5),
                      "Nach Abbrechen nicht mehr in der Reederei-Liste")
        XCTAssertFalse(app.textFields["Schiffsname"].exists,
                       "Schiff-Formular darf nach Abbrechen des Reederei-Formulars nicht erscheinen")
    }
}
