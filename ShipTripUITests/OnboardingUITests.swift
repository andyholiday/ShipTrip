//
//  OnboardingUITests.swift
//  ShipTripUITests
//
//  UI-Smoke-Tests für den Erststart-Flow (Task B2, geprüft in B5):
//  - kompletter Durchlauf über alle vier Karten bis zur Hauptliste,
//  - „Überspringen“ springt an den mittleren Karten vorbei auf die Startentscheidung,
//  - der Flow erscheint beim nächsten Start nicht mehr.
//
//  Der Erst-Start-Zustand kommt über das Launch-Argument
//  `-uiTestingResetOnboarding` (Naht in `ShipTripApp`, nur DEBUG) — kein
//  Verlass auf den Restzustand des Simulators.
//
//  Sprache: DE-Abnahme genügt, die EN-Seite kommt erst mit C5.
//

import XCTest

@MainActor
final class OnboardingUITests: XCTestCase {

    // MARK: - Karten-Überschriften (jede eindeutig, deshalb der Anker je Karte)

    private enum Card {
        static let welcome = "Dein Logbuch für jede Kreuzfahrt"
        static let features = "Drei Dinge, die ShipTrip für dich mitschreibt"
        static let softAsk = "Sollen wir dich an die Abreise erinnern?"
        static let start = "Bereit für deine erste Reise"
    }

    /// Anker hinter dem Onboarding: auf frischer Installation ist der Store leer,
    /// dort steht der Empty-State der Reise-Liste. Der Listentitel „Meine Reisen“
    /// existiert nur im gefüllten Zweig und taugt deshalb nicht als Anker.
    private let mainListAnchor = "Keine Kreuzfahrten"

    override func setUpWithError() throws {
        continueAfterFailure = false
        // Wie in den übrigen UI-Tests: der Simulator kann noch im Landscape-Zustand
        // eines vorherigen Laufs sein, was Element-Queries verfälscht.
        XCUIDevice.shared.orientation = .portrait
    }

    // MARK: - Helper

    /// Startet die App mit zurückgesetztem Erststart-Schalter.
    private func launchWithFreshOnboarding() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments += ["-uiTestingResetOnboarding"]
        app.launch()
        return app
    }

    private func assertCardVisible(_ headline: String, in app: XCUIApplication) {
        XCTAssertTrue(
            app.staticTexts[headline].waitForExistence(timeout: 10),
            "Onboarding-Karte „\(headline)“ nicht sichtbar"
        )
    }

    /// Blättert mit der Primär-Taste weiter. „Weiter“ trägt sowohl Karte 1 als
    /// auch Karte 2 — deshalb nach dem Tipp warten, bis die alte Karte aus dem
    /// Baum ist, bevor die nächste angesprochen wird.
    private func tapWeiter(from headline: String, in app: XCUIApplication) {
        let weiter = app.buttons["Weiter"].firstMatch
        XCTAssertTrue(
            weiter.waitForExistence(timeout: 10),
            "Primär-Taste auf Karte „\(headline)“ fehlt"
        )
        weiter.tap()
        XCTAssertTrue(
            app.staticTexts[headline].waitForNonExistence(timeout: 10),
            "Karte „\(headline)“ ist nach dem Weiterblättern noch sichtbar"
        )
    }

    /// Beendet den Flow über die Startentscheidung und prüft, dass das Cover weg
    /// ist und die Hauptliste darunter steht.
    private func finishOnStartCardAndAssertMainList(in app: XCUIApplication) {
        let firstTrip = app.buttons["Erste Reise anlegen"].firstMatch
        XCTAssertTrue(firstTrip.waitForExistence(timeout: 10), "Primär-Taste auf Karte 4 fehlt")
        firstTrip.tap()

        XCTAssertTrue(
            app.staticTexts[Card.start].waitForNonExistence(timeout: 10),
            "Das Onboarding-Cover ist nach der Startentscheidung noch sichtbar"
        )
        XCTAssertTrue(
            mainListElement(in: app).waitForExistence(timeout: 10),
            "Reise-Liste („\(mainListAnchor)“) nach dem Onboarding nicht erreicht"
        )
    }

    /// Der Empty-State ist eine `ContentUnavailableView` — ob ihr Titel als
    /// eigener StaticText oder als zusammengefasstes Element im Baum landet,
    /// entscheidet SwiftUI. Deshalb über das Label suchen statt über den Typ.
    private func mainListElement(in app: XCUIApplication) -> XCUIElement {
        app.descendants(matching: .any)
            .matching(NSPredicate(format: "label CONTAINS %@", mainListAnchor))
            .firstMatch
    }

    /// Der Berechtigungsdialog gehört Springboard, nicht der App — deshalb dort
    /// nachsehen statt in `app.alerts`.
    private func springboardAlertVisible() -> Bool {
        XCUIApplication(bundleIdentifier: "com.apple.springboard").alerts.firstMatch.exists
    }

    // MARK: - 1) Kompletter Durchlauf

    func testDurchlaufUeberAlleVierKartenEndetInDerHauptliste() throws {
        let app = launchWithFreshOnboarding()

        assertCardVisible(Card.welcome, in: app)
        tapWeiter(from: Card.welcome, in: app)

        assertCardVisible(Card.features, in: app)
        tapWeiter(from: Card.features, in: app)

        // Karte 3 ist der Soft-Ask: bewusst die sekundäre Taste, damit iOS gar
        // nicht erst nach der Erlaubnis fragt (B4-Zusage).
        assertCardVisible(Card.softAsk, in: app)
        let spaeter = app.buttons["Später"].firstMatch
        XCTAssertTrue(
            spaeter.waitForExistence(timeout: 10),
            "Sekundär-Taste auf dem Soft-Ask fehlt"
        )
        spaeter.tap()

        assertCardVisible(Card.start, in: app)
        XCTAssertFalse(
            springboardAlertVisible(),
            "Ohne aktive Zustimmung darf kein System-Berechtigungsdialog erscheinen"
        )

        finishOnStartCardAndAssertMainList(in: app)
    }

    // MARK: - 2) Skip-Pfad

    func testUeberspringenGehtDirektZurStartentscheidung() throws {
        let app = launchWithFreshOnboarding()

        assertCardVisible(Card.welcome, in: app)

        let skip = app.buttons["Überspringen"].firstMatch
        XCTAssertTrue(skip.waitForExistence(timeout: 10), "Skip-Taste auf Karte 1 fehlt")
        skip.tap()

        // Der Sprung geht auf die Startentscheidung (letzte Karte) — übersprungen
        // werden die Karten 2 und 3, nicht der Flow.
        assertCardVisible(Card.start, in: app)
        XCTAssertFalse(
            app.staticTexts[Card.features].exists,
            "Karte 2 wurde beim Überspringen doch gezeigt"
        )
        XCTAssertFalse(
            app.staticTexts[Card.softAsk].exists,
            "Karte 3 wurde beim Überspringen doch gezeigt"
        )
        XCTAssertFalse(
            app.buttons["Überspringen"].firstMatch.exists,
            "Auf der Startentscheidung darf die Skip-Taste nicht mehr stehen"
        )

        finishOnStartCardAndAssertMainList(in: app)
    }

    // MARK: - 3) Persistenz über den Neustart

    func testOnboardingErscheintNachAbschlussBeimNaechstenStartNichtMehr() throws {
        let app = launchWithFreshOnboarding()

        assertCardVisible(Card.welcome, in: app)
        app.buttons["Überspringen"].firstMatch.tap()
        finishOnStartCardAndAssertMainList(in: app)

        // Erst in den Hintergrund, dann beenden: die Suspendierung schreibt die
        // UserDefaults auf die Platte, bevor der Prozess wegfällt.
        XCUIDevice.shared.press(.home)
        app.terminate()

        // Zweiter Start bewusst OHNE `-uiTestingResetOnboarding`.
        let relaunched = XCUIApplication()
        relaunched.launch()

        XCTAssertTrue(
            mainListElement(in: relaunched).waitForExistence(timeout: 15),
            "Reise-Liste beim zweiten Start nicht erreicht"
        )
        XCTAssertFalse(
            relaunched.staticTexts[Card.welcome].exists,
            "Das Onboarding erscheint nach Abschluss erneut"
        )
    }
}
