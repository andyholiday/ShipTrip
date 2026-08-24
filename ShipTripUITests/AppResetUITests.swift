//
//  AppResetUITests.swift
//  ShipTripUITests
//
//  „App zuruecksetzen" in Einstellungen → Daten verwalten: loescht alle Daten
//  und stellt den Erststart-Schalter zurueck, sodass das Onboarding wieder
//  erscheint. Geprueft wird beides — die geleerte Reise-Liste und das Cover.
//
//  Ausgangslage ueber die bestehenden DEBUG-Nahten in `ShipTripApp`:
//  `-uiTestingResetAndLoadDemoData` fuellt den Store, `-uiTestingCompleteOnboarding`
//  haakt den Erststart ab — genau die Lage, aus der der Reset heraus wirken soll.
//

import XCTest

@MainActor
final class AppResetUITests: XCTestCase {

    private let welcomeCard = "Dein Logbuch für jede Kreuzfahrt"
    private let demoCruiseTitle = "Norwegische Fjorde"

    override func setUpWithError() throws {
        continueAfterFailure = false
        XCUIDevice.shared.orientation = .portrait
    }

    func testAppZuruecksetzenLeertDieDatenUndZeigtDasOnboardingWieder() throws {
        let app = XCUIApplication()
        app.launchArguments += ["-uiTestingResetAndLoadDemoData", "-uiTestingCompleteOnboarding"]
        app.launch()

        XCTAssertTrue(
            app.staticTexts[demoCruiseTitle].waitForExistence(timeout: 15),
            "Ausgangslage fehlt: die Beispielreise ist nicht in der Liste"
        )

        navigateToDataManagement(app)

        let resetButton = app.buttons["App zurücksetzen"]
        XCTAssertTrue(
            scrollUntilHittable(resetButton, in: app),
            "„App zurücksetzen“ fehlt im Daten-Bereich"
        )
        try writeScreenshotIfRequested(name: "settings-daten", resetButton: resetButton, in: app)
        resetButton.tap()

        let confirm = app.alerts.buttons["Zurücksetzen"]
        XCTAssertTrue(
            confirm.waitForExistence(timeout: 5),
            "Der Reset laeuft ohne Bestaetigungs-Dialog"
        )
        confirm.tap()

        // 1) Das Onboarding steht wieder — der Erststart-Schalter ist zurueck.
        XCTAssertTrue(
            app.staticTexts[welcomeCard].waitForExistence(timeout: 10),
            "Nach dem Reset erscheint das Onboarding nicht"
        )

        // 2) Und dahinter ist der Store leer. Der Flow wird ueber die
        //    Startentscheidung beendet, ohne die Beispielreise zu laden.
        app.buttons["Überspringen"].firstMatch.tap()
        let firstTrip = app.buttons["Erste Reise anlegen"].firstMatch
        XCTAssertTrue(firstTrip.waitForExistence(timeout: 10), "Startentscheidung nicht erreicht")
        firstTrip.tap()

        // Das Cover lag ueber der Datenverwaltung — die Reise-Liste steht im
        // Reisen-Tab, nicht darunter.
        let tripsTab = app.tabBars.buttons["Reisen"]
        XCTAssertTrue(tripsTab.waitForExistence(timeout: 10), "Reisen-Tab nach dem Onboarding nicht erreichbar")
        tripsTab.tap()

        XCTAssertTrue(
            app.staticTexts["Keine Kreuzfahrten"].waitForExistence(timeout: 10),
            "Nach dem Reset stehen noch Reisen in der Liste"
        )
        XCTAssertFalse(
            app.staticTexts[demoCruiseTitle].exists,
            "Die Beispielreise hat den Reset ueberlebt"
        )
    }

    // MARK: - Helper

    /// Abnahme-Screenshot, nur wenn `SHIPTRIP_SCREENSHOT_DIR` gesetzt ist —
    /// dasselbe Muster wie in `OnboardingScreenshotTests`. Ohne die Variable
    /// passiert nichts und der Test laeuft unveraendert.
    private func writeScreenshotIfRequested(
        name: String,
        resetButton: XCUIElement,
        in app: XCUIApplication
    ) throws {
        let path = ProcessInfo.processInfo.environment["SHIPTRIP_SCREENSHOT_DIR"] ?? ""
        guard !path.isEmpty else { return }
        // Ans Listenende scrollen, damit der Daten-Bereich vollstaendig im Bild
        // steht, danach zurueck in die antippbare Lage.
        app.collectionViews.firstMatch.swipeUp()
        RunLoop.current.run(until: Date().addingTimeInterval(1.0))
        defer { _ = scrollUntilHittable(resetButton, in: app) }
        let dir = URL(filePath: path)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        try XCUIScreen.main.screenshot().pngRepresentation
            .write(to: dir.appending(component: "\(name).png"))
    }

    /// „Mehr" → „Daten verwalten" (gleicher Weg wie `ReedereiAnlegenUITests`).
    private func navigateToDataManagement(_ app: XCUIApplication) {
        let moreTab = app.tabBars.buttons["Mehr"]
        XCTAssertTrue(moreTab.waitForExistence(timeout: 10), "Tab „Mehr“ nicht gefunden")
        moreTab.tap()

        let dataLink = app.buttons["Daten verwalten"]
        XCTAssertTrue(
            scrollUntilHittable(dataLink, in: app),
            "„Daten verwalten“ nicht gefunden"
        )
        dataLink.tap()
    }

    /// Die Einstellungen und die Datenverwaltung sind laenger als ein Bildschirm.
    /// Statt fester Wischzahlen: wischen, bis das Element antippbar ist.
    private func scrollUntilHittable(
        _ element: XCUIElement,
        in app: XCUIApplication,
        maxSwipes: Int = 6
    ) -> Bool {
        let list = app.collectionViews.firstMatch
        for _ in 0 ... maxSwipes {
            if element.exists && element.isHittable { return true }
            if list.exists { list.swipeUp() } else { app.swipeUp() }
        }
        return element.exists && element.isHittable
    }
}
