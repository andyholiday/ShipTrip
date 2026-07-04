//
//  PortMemoryCardUITests.swift
//  ShipTripUITests
//
//  UI-Smoke-Test für Welle B7.2 (Design-Vorschlag B2 „PortMemoryCard“,
//  docs/ux-pitch-decks/b6-hafen-momente.html): der einladende Zero-State muss
//  sichtbar sein, sobald ein Hafen ohne Foto/Ausflüge in der Detailansicht
//  angezeigt wird (statt der bisherigen, komplett ausgeblendeten Zeile).
//

import XCTest

final class PortMemoryCardUITests: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = false
        // Siehe AusflugLoeschenUITests: im Landscape-Viewport werden Form-/List-Zeilen
        // außerhalb des sichtbaren Bereichs nicht gerendert – fest auf Portrait fixieren.
        XCUIDevice.shared.orientation = .portrait
    }

    @MainActor
    func testZeroStateSichtbarBeiHafenOhneMomente() throws {
        let app = XCUIApplication()
        app.launchArguments += ["-uiTestingResetAndLoadDemoData"]
        app.launch()

        let cruiseTitle = "UI-Test-PortMemoryCard-B7"
        let portName = "Testhafen Zero"

        // 1. Neue Kreuzfahrt anlegen
        let reisenTab = app.tabBars.buttons["Reisen"]
        XCTAssertTrue(reisenTab.waitForExistence(timeout: 10))
        reisenTab.tap()

        let addCruiseButton = app.buttons["Neue Reise"]
        XCTAssertTrue(addCruiseButton.waitForExistence(timeout: 10), "Button 'Neue Reise' nicht gefunden")
        addCruiseButton.tap()

        let titleField = app.textFields["Titel"]
        XCTAssertTrue(titleField.waitForExistence(timeout: 5))
        titleField.tap()
        titleField.typeText(cruiseTitle)

        let shipField = app.textFields["Schiffsname"]
        XCTAssertTrue(shipField.waitForExistence(timeout: 5))
        shipField.tap()
        shipField.typeText("Testschiff")

        // 2. Hafen OHNE Foto/Ausflug hinzufügen (bewusst der Zero-State-Fall)
        let addPortButton = app.buttons["Hafen hinzufügen"]
        XCTAssertTrue(addPortButton.waitForExistence(timeout: 5))
        addPortButton.tap()

        let portNameField = app.textFields["Hafenname"]
        XCTAssertTrue(portNameField.waitForExistence(timeout: 5))
        portNameField.tap()
        portNameField.typeText(portName)

        let savePortButton = app.navigationBars["Hafen hinzufügen"].buttons["Speichern"]
        XCTAssertTrue(savePortButton.waitForExistence(timeout: 5))
        savePortButton.tap()

        let saveCruiseButton = app.navigationBars["Neue Kreuzfahrt"].buttons["Speichern"]
        XCTAssertTrue(saveCruiseButton.waitForExistence(timeout: 5))
        saveCruiseButton.tap()

        // Optionaler Erinnerungs-Berechtigungs-Dialog (A2.1) – falls vorhanden, "Später" wählen.
        let laterButton = app.buttons["Später"]
        if laterButton.waitForExistence(timeout: 3) {
            laterButton.tap()
        }

        // 3. Detailansicht öffnen und Zero-State prüfen
        let cruiseEntry = app.staticTexts.matching(NSPredicate(format: "label == %@", cruiseTitle)).firstMatch
        XCTAssertTrue(cruiseEntry.waitForExistence(timeout: 10), "Neu angelegte Reise nicht in der Liste gefunden")
        cruiseEntry.tap()

        XCTAssertTrue(app.staticTexts[portName].waitForExistence(timeout: 10))
        XCTAssertTrue(
            app.staticTexts["Foto & Ausflüge erfassen"].waitForExistence(timeout: 5),
            "Zero-State-Hinweis der PortMemoryCard fehlt bei Hafen ohne Momente (B7.2/B2)"
        )
    }
}
