//
//  MapAlleRoutenUITests.swift
//  ShipTripUITests
//
//  UI-Regressions-Test für F1 (TestFlight-Feedback Build 16): Burger-Menü → „Alle ausblenden"
//  → „Alle Reisen anzeigen" ließ das Menü offen (`.menuActionDismissBehavior(.disabled)` lag
//  auf dem gesamten Menü statt nur auf den Einzel-Routen-Toggles), wodurch der Menü-Blur-
//  Backdrop die bereits korrekt neu gezoomte Karte dauerhaft verdeckte („weißer Bildschirm").
//

import XCTest

final class MapAlleRoutenUITests: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = false
        XCUIDevice.shared.orientation = .portrait
    }

    @MainActor
    func testAlleAusblendenUndWiederAnzeigenSchliesstMenuUndZeigtRoutenWieder() throws {
        let app = XCUIApplication()
        app.launchArguments += ["-uiTestingResetAndLoadDemoData"]
        app.launch()

        let mapTab = app.tabBars.buttons["Karte"]
        XCTAssertTrue(mapTab.waitForExistence(timeout: 10))
        mapTab.tap()

        XCTAssertTrue(app.staticTexts["Alle Reisen"].waitForExistence(timeout: 10),
                      "Kartenansicht zeigt nicht standardmäßig alle Reisen")

        let burgerMenu = app.buttons["Routenauswahl"]
        XCTAssertTrue(burgerMenu.waitForExistence(timeout: 5))
        burgerMenu.tap()

        let hideAllButton = app.buttons["Alle ausblenden"]
        XCTAssertTrue(hideAllButton.waitForExistence(timeout: 5))
        hideAllButton.tap()

        // Menü darf nach einem einmaligen Alle-ausblenden-Tap NICHT offen bleiben.
        XCTAssertTrue(hideAllButton.waitForNonExistence(timeout: 5),
                      "Burger-Menü bleibt nach 'Alle ausblenden' offen (F1-Regression)")

        burgerMenu.tap()
        let showAllButton = app.buttons["Alle Reisen anzeigen"]
        XCTAssertTrue(showAllButton.waitForExistence(timeout: 5))
        showAllButton.tap()

        // Menü muss sich ebenso schließen, sonst verdeckt der Blur-Backdrop die Karte dauerhaft
        // (genau das gemeldete "weißer Bildschirm"-Verhalten).
        XCTAssertTrue(showAllButton.waitForNonExistence(timeout: 5),
                      "Burger-Menü bleibt nach 'Alle Reisen anzeigen' offen — Karte bleibt verdeckt (F1-Regression)")

        // Routen-UI ist wieder da: Auswahltitel zurück auf "Alle Reisen", Burger-Button wieder
        // antippbar (kein Overlay blockiert mehr Taps auf die Karte).
        XCTAssertTrue(app.staticTexts["Alle Reisen"].waitForExistence(timeout: 5),
                      "Auswahltitel kehrt nach 'Alle Reisen anzeigen' nicht zurück")
        XCTAssertTrue(burgerMenu.isHittable,
                      "Burger-Menü-Button ist nach dem Schließen nicht mehr antippbar")
    }
}
