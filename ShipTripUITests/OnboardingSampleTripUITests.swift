//
//  OnboardingSampleTripUITests.swift
//  ShipTripUITests
//
//  Repro fuer den Abnahme-Befund: „Beispielreise ansehen" auf Karte 4 des
//  Erststart-Flows laedt die Beispielreise nicht in die Reise-Liste.
//
//  Bewusst ein UI-Test und kein Unit-Test: der Fehler sitzt nicht im
//  `DemoDataService` (der ist unter `DemoDataServiceTests` gruen), sondern in
//  der Naht zwischen `fullScreenCover` und dem `modelContext`, den der Flow
//  aus der Umgebung bekommt. Diese Naht existiert nur im laufenden App-Baum.
//
//  Der Erst-Start-Zustand kommt wie in `OnboardingUITests` ueber
//  `-uiTestingResetOnboarding` (DEBUG-Naht in `ShipTripApp`). Der leere Store
//  kommt aus der frischen Installation auf dem Wegwerf-Simulator.
//

import XCTest

@MainActor
final class OnboardingSampleTripUITests: XCTestCase {

    private enum Card {
        static let welcome = "Dein Logbuch für jede Kreuzfahrt"
        static let start = "Bereit für deine erste Reise"
    }

    /// Die Beispielreise, die Karte 4 ankuendigt. `insertNorwegen` datiert sie
    /// auf heute + 21 Tage — sie ist damit die Hero-Karte der Reise-Liste.
    private let sampleCruiseTitle = "Norwegische Fjorde"

    override func setUpWithError() throws {
        continueAfterFailure = false
        XCUIDevice.shared.orientation = .portrait
    }

    func testBeispielreiseAnsehenLaedtDieBeispielreiseInDieReiseListe() throws {
        let app = XCUIApplication()
        app.launchArguments += ["-uiTestingResetOnboarding"]
        app.launch()

        XCTAssertTrue(
            app.staticTexts[Card.welcome].waitForExistence(timeout: 15),
            "Erststart-Flow ist nicht erschienen"
        )

        // Ueber „Ueberspringen" direkt auf die Startentscheidung — der
        // Soft-Ask bleibt damit aussen vor, es erscheint kein Systemdialog.
        let skip = app.buttons["Überspringen"].firstMatch
        XCTAssertTrue(skip.waitForExistence(timeout: 10), "Skip-Taste auf Karte 1 fehlt")
        skip.tap()

        XCTAssertTrue(
            app.staticTexts[Card.start].waitForExistence(timeout: 10),
            "Startentscheidung (Karte 4) nicht erreicht"
        )

        let sample = app.buttons["Beispielreise ansehen"].firstMatch
        XCTAssertTrue(sample.waitForExistence(timeout: 10), "CTA „Beispielreise ansehen“ fehlt")
        sample.tap()

        XCTAssertTrue(
            app.staticTexts[Card.start].waitForNonExistence(timeout: 10),
            "Das Onboarding-Cover ist nach dem Beispielreise-CTA noch sichtbar"
        )

        // Der eigentliche Befund: die Reise-Liste bleibt leer.
        XCTAssertTrue(
            app.staticTexts[sampleCruiseTitle].waitForExistence(timeout: 15),
            "Beispielreise „\(sampleCruiseTitle)“ wurde nach dem CTA nicht in die Reise-Liste geladen"
        )
    }
}
