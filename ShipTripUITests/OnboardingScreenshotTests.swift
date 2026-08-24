//
//  OnboardingScreenshotTests.swift
//  ShipTripUITests
//
//  Nimmt Abnahme-Screenshots der vier Erststart-Karten (Task B2/B5) — je einer
//  pro Karte, mit Sprach-Suffix im Dateinamen (karte1-de.png … karte4-en.png).
//
//  Zwei Umgebungsvariablen steuern den Lauf, beide ueber den Test-Runner
//  (`TEST_RUNNER_…`) gesetzt:
//  - `SHIPTRIP_SCREENSHOT_DIR`  Ziel-Ordner. Ohne ihn wird die Suite per
//    XCTSkip uebersprungen statt zu scheitern (Muster aus
//    `HauptansichtScreenshotTests`) — Screenshot-Laeufe sind lokal, nicht CI.
//  - `SHIPTRIP_SCREENSHOT_LANG` `de` (Vorgabe) oder `en`. Die Sprache setzt der
//    Test selbst per `-AppleLanguages`/`-AppleLocale`; die erwarteten
//    Beschriftungen kommen aus derselben Quelle, damit ein EN-Lauf nur mit
//    tatsaechlich englischer Oberflaeche gruen wird.
//
//  Der Erst-Start-Zustand kommt wie in `OnboardingUITests` ueber
//  `-uiTestingResetOnboarding` (Naht in `ShipTripApp`, nur DEBUG).
//

import XCTest

@MainActor
final class OnboardingScreenshotTests: XCTestCase {

    // MARK: - Sprachvarianten

    /// Beschriftungen einer Sprache: die vier Karten-Ueberschriften und die
    /// Tasten, ueber die der Flow weiterblaettert. Quelle: `Localizable.xcstrings`
    /// (DE = Katalog-Schluessel, EN = Uebersetzung).
    private struct Strings {
        let launchArguments: [String]
        let cardHeadlines: [String]
        /// Primaer-Taste der Karten 1 und 2.
        let next: String
        /// Sekundaer-Taste des Soft-Asks (Karte 3) — bewusst nicht die
        /// Primaer-Taste, damit kein System-Berechtigungsdialog aufgeht.
        let later: String

        static let german = Strings(
            launchArguments: ["-AppleLanguages", "(de)", "-AppleLocale", "de_DE"],
            cardHeadlines: [
                "Dein Logbuch für jede Kreuzfahrt",
                "Drei Dinge, die ShipTrip für dich mitschreibt",
                "Sollen wir dich an die Abreise erinnern?",
                "Bereit für deine erste Reise"
            ],
            next: "Weiter",
            later: "Später"
        )

        static let english = Strings(
            launchArguments: ["-AppleLanguages", "(en)", "-AppleLocale", "en_US"],
            cardHeadlines: [
                "Your logbook for every cruise",
                "Three things ShipTrip records for you",
                "Should we remind you about departure?",
                "Ready for your first trip"
            ],
            next: "Continue",
            later: "Later"
        )
    }

    // MARK: - Konfiguration aus der Umgebung

    private static let outputDirEnvKey = "SHIPTRIP_SCREENSHOT_DIR"
    private static let languageEnvKey = "SHIPTRIP_SCREENSHOT_LANG"

    private var outputDir: URL {
        get throws {
            let path = ProcessInfo.processInfo.environment[Self.outputDirEnvKey] ?? ""
            guard !path.isEmpty else {
                throw XCTSkip(
                    "\(Self.outputDirEnvKey) nicht gesetzt — Screenshot-Suite übersprungen."
                )
            }
            return URL(filePath: path)
        }
    }

    /// Sprachkuerzel des Laufs. Vorgabe `de`; ein unbekannter Wert ist ein
    /// Fehler, kein stiller Rueckfall auf Deutsch.
    private var language: String {
        get throws {
            let raw = ProcessInfo.processInfo.environment[Self.languageEnvKey] ?? "de"
            guard ["de", "en"].contains(raw) else {
                throw XCTSkip("\(Self.languageEnvKey)=\(raw) ist keine unterstützte Sprache.")
            }
            return raw
        }
    }

    override func setUpWithError() throws {
        continueAfterFailure = false
        // Wie in den uebrigen UI-Tests: der Simulator kann noch im Landscape-
        // Zustand eines vorherigen Laufs sein, was Element-Queries verfaelscht.
        XCUIDevice.shared.orientation = .portrait
        let dir = try outputDir
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    }

    // MARK: - Abnahme-Lauf

    func testScreenshotsDerVierOnboardingKarten() throws {
        let language = try language
        let strings = language == "en" ? Strings.english : Strings.german

        let app = XCUIApplication()
        app.launchArguments += strings.launchArguments + ["-uiTestingResetOnboarding"]
        app.launch()

        // Karte 1
        try capture(card: 1, headline: strings.cardHeadlines[0], language: language, in: app)
        tap(button: strings.next, leaving: strings.cardHeadlines[0], in: app)

        // Karte 2
        try capture(card: 2, headline: strings.cardHeadlines[1], language: language, in: app)
        tap(button: strings.next, leaving: strings.cardHeadlines[1], in: app)

        // Karte 3 (Soft-Ask) — ueber die Sekundaer-Taste weiter, damit iOS gar
        // nicht erst nach der Benachrichtigungs-Erlaubnis fragt.
        try capture(card: 3, headline: strings.cardHeadlines[2], language: language, in: app)
        tap(button: strings.later, leaving: strings.cardHeadlines[2], in: app)

        // Karte 4 — Endpunkt, hier wird nichts mehr getippt.
        try capture(card: 4, headline: strings.cardHeadlines[3], language: language, in: app)
    }

    // MARK: - Bausteine

    /// Wartet auf die Karte, laesst die Einlauf-Staffel auslaufen und schreibt
    /// das PNG. Die Ueberschrift ist zugleich die Sprachprobe: erscheint sie
    /// nicht, lief die App in der falschen Sprache und der Test faellt.
    private func capture(
        card index: Int,
        headline: String,
        language: String,
        in app: XCUIApplication
    ) throws {
        XCTAssertTrue(
            app.staticTexts[headline].waitForExistence(timeout: 15),
            "Onboarding-Karte \(index) („\(headline)“) nicht sichtbar — falsche Sprache?"
        )
        // Die Karten fahren ihre Elemente gestaffelt ein (onboardingCascadeIn);
        // ein Screenshot mitten in der Staffel zeigt halbe Karten.
        RunLoop.current.run(until: Date().addingTimeInterval(1.5))

        app.activate()
        let url = try outputDir.appending(component: "karte\(index)-\(language).png")
        try XCUIScreen.main.screenshot().pngRepresentation.write(to: url)
        print("[Onboarding-Screenshot] \(url.path)")
    }

    /// Blaettert weiter und wartet, bis die alte Karte aus dem Baum ist — die
    /// Beschriftung „Weiter" traegt mehrere Karten (Muster aus `OnboardingUITests`).
    private func tap(button title: String, leaving headline: String, in app: XCUIApplication) {
        let button = app.buttons[title].firstMatch
        XCTAssertTrue(
            button.waitForExistence(timeout: 10),
            "Taste „\(title)“ auf Karte „\(headline)“ fehlt"
        )
        button.tap()
        XCTAssertTrue(
            app.staticTexts[headline].waitForNonExistence(timeout: 10),
            "Karte „\(headline)“ ist nach dem Weiterblättern noch sichtbar"
        )
    }
}
