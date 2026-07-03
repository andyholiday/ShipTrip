//
//  HauptansichtScreenshotTests.swift
//  ShipTripUITests
//
//  Nimmt Screenshots der redesignten "Meine Reisen"-Ansicht mit Demo-Daten.
//  Ausgabe: /Users/andreja/Documents/0.Projekte/ShipTrip/audit/screenshots/
//
//  Erscheinungsbild (light/dark) wird per Launch-Argument gesetzt,
//  das der Test-Runner via xcrun simctl ui vor dem Start setzt.
//

import XCTest

final class HauptansichtScreenshotTests: XCTestCase {

    private let outputDir = URL(filePath: "/Users/andreja/Documents/0.Projekte/ShipTrip/audit/screenshots")

    override func setUpWithError() throws {
        continueAfterFailure = false
        try FileManager.default.createDirectory(at: outputDir, withIntermediateDirectories: true)
    }

    // MARK: - Light Mode

    @MainActor
    func testScreenshot_Light() throws {
        try captureMainView(suffix: "light")
    }

    // MARK: - Dark Mode

    @MainActor
    func testScreenshot_Dark() throws {
        try captureMainView(suffix: "dark")
    }

    // MARK: - Clean Hero Photo (Fresh Store)

    /// Spezieller Screenshot für den Audit-Beweis: Hero zeigt Foto (Gradient-PNG),
    /// kein Geo-Fallback mit gestrichelten Linien. Setzt voraus, dass der Store
    /// LEER ist (xcrun simctl uninstall vor diesem Test). Speichert nach:
    /// audit/screenshots/meine-reisen-hero-photo-clean.png
    @MainActor
    func testScreenshot_HeroPhotoClean() throws {
        let app = XCUIApplication()
        app.launchArguments += ["-colorScheme", "light"]
        app.launch()

        // 1. Einstellungs-Tab öffnen
        let moreTab = app.tabBars.buttons["Mehr"]
        XCTAssertTrue(moreTab.waitForExistence(timeout: 10), "Tab 'Mehr' nicht gefunden")
        moreTab.tap()

        // 2. Liste nach unten scrollen um die Demo-Sektion sichtbar zu machen
        //    (sie steht unterhalb von KI-Funktionen, iCloud, Benachrichtigungen, Daten)
        // SwiftUI List rendert auf iOS 18+ als UICollectionView, nicht als UITableView
        let settingsList = app.collectionViews.firstMatch
        if settingsList.waitForExistence(timeout: 5) {
            settingsList.swipeUp()
        } else {
            // Fallback: einfach die App nach oben swipen
            app.swipeUp()
        }

        // 3. Falls Demo-Daten vorhanden (Restbestand), erst entfernen
        let removeButton = app.buttons["Beispieldaten entfernen"]
        if removeButton.waitForExistence(timeout: 5) {
            removeButton.tap()
            // Nach dem Entfernen warten bis Lade-Button erscheint
            if settingsList.exists { settingsList.swipeUp() } else { app.swipeUp() }
        }

        // 4. Lade-Button muss jetzt sichtbar sein (leerer Store)
        let loadButton = app.buttons["Beispieldaten laden"]
        XCTAssertTrue(loadButton.waitForExistence(timeout: 15),
                      "Lade-Button 'Beispieldaten laden' nicht erschienen – Demo-Sektion fehlt oder nicht sichtbar?")
        loadButton.tap()

        // 5. Zum Reisen-Tab wechseln (Existenz des Tabs signalisiert, dass App bereit ist)
        let reisenTab = app.tabBars.buttons["Reisen"]
        XCTAssertTrue(reisenTab.waitForExistence(timeout: 8))
        reisenTab.tap()

        // 6. Warten bis Hero-Card geladen ist
        XCTAssertTrue(app.staticTexts["Norwegische Fjorde"].waitForExistence(timeout: 10),
                      "Hero-Reise ist nicht sichtbar")
        RunLoop.current.run(until: Date().addingTimeInterval(0.8))

        // 7. Screenshot als hero-photo-clean speichern
        let screenshot = XCUIScreen.main.screenshot()
        let outURL = outputDir.appending(component: "meine-reisen-hero-photo-clean.png")
        try screenshot.pngRepresentation.write(to: outURL)
        print("[Screenshot-HeroClean] \(outURL.path)")
    }

    // MARK: - Core

    @MainActor
    private func captureMainView(suffix: String) throws {
        let app = XCUIApplication()
        app.launchArguments += ["-colorScheme", suffix, "-uiTestingResetAndLoadDemoData"]
        app.launch()

        // 1. Zum Reisen-Tab wechseln
        let reisenTab = app.tabBars.buttons["Reisen"]
        XCTAssertTrue(reisenTab.waitForExistence(timeout: 5))
        reisenTab.tap()

        // 2. Warten bis die Hauptansicht geladen ist
        XCTAssertTrue(app.staticTexts["Norwegische Fjorde"].waitForExistence(timeout: 10),
                      "Hero-Reise ist nicht sichtbar — Demo-Daten wurden nicht geladen?")
        RunLoop.current.run(until: Date().addingTimeInterval(0.8))

        // 3. Screenshot oben (Hero-Card + Stats-Strip sichtbar)
        app.activate()
        try write(screenshot: XCUIScreen.main.screenshot(), name: "meine-reisen-\(suffix)")

        // 4. Nach unten scrollen für Timeline-Rows
        app.activate()
        app.swipeUp(velocity: .slow)

        // Warten bis Scroll-Animation abgeschlossen und eine Timeline-Reise sichtbar ist
        XCTAssertTrue(app.staticTexts["Westliches Mittelmeer 2025"].waitForExistence(timeout: 5),
                      "Timeline-Reise ist nach dem Scrollen nicht sichtbar")

        app.activate()
        try write(screenshot: XCUIScreen.main.screenshot(), name: "meine-reisen-\(suffix)-scrolled")
    }

    // MARK: - Detail-Ansicht mit differenzierten Pins (Light)

    /// Öffnet eine Kreuzfahrt-Detailansicht mit Demo-Daten und screenshottet die Hafen-Pin-Liste.
    @MainActor
    func testScreenshot_DetailPins_Light() throws {
        try captureDetailView(suffix: "light")
    }

    // MARK: - Detail-Ansicht mit differenzierten Pins (Dark)

    @MainActor
    func testScreenshot_DetailPins_Dark() throws {
        try captureDetailView(suffix: "dark")
    }

    // MARK: - Geo-Route Hero (Light + Dark)

    /// Hero-Karte mit Geo-Route: benutzt die Upstream-Demo-Reise „Norwegische Fjorde"
    /// (kein Foto, aber Hafen-Koordinaten vorhanden) — zeigt CruiseGeoFallbackView
    /// mit differenzierten Start/End-Punkten.
    @MainActor
    func testScreenshot_GeoHero_Light() throws {
        try captureGeoHero(suffix: "light")
    }

    @MainActor
    func testScreenshot_GeoHero_Dark() throws {
        try captureGeoHero(suffix: "dark")
    }

    // MARK: - Kartenansicht: alle Reisen (Light + Dark)

    @MainActor
    func testScreenshot_MapAllTrips_Light() throws {
        try captureMapAllTrips(suffix: "light")
    }

    @MainActor
    func testScreenshot_MapAllTrips_Dark() throws {
        try captureMapAllTrips(suffix: "dark")
    }

    // MARK: - Core helper: Detail-Pins

    @MainActor
    private func captureDetailView(suffix: String) throws {
        let app = XCUIApplication()
        app.launchArguments += ["-colorScheme", suffix, "-uiTestingResetAndLoadDemoData"]
        app.launch()

        // 1. Zum Reisen-Tab wechseln
        let reisenTab = app.tabBars.buttons["Reisen"]
        XCTAssertTrue(reisenTab.waitForExistence(timeout: 5))
        reisenTab.tap()

        // 2. Timeline-Row antippen: Demo enthält "Westliches Mittelmeer 2025"
        //    als erste Timeline-Zeile unter dem Hero.
        //    StaticText mit dem Reisetitel suchen.
        // Scrollen damit Timeline-Zeilen sichtbar sind
        XCTAssertTrue(app.staticTexts["Norwegische Fjorde"].waitForExistence(timeout: 8))
        app.swipeUp(velocity: .slow)
        RunLoop.current.run(until: Date().addingTimeInterval(0.8))

        // Erste sichtbare Timeline-Reise antippen
        let timelineTitle = app.staticTexts["Westliches Mittelmeer 2025"]
        XCTAssertTrue(timelineTitle.waitForExistence(timeout: 5),
                      "Timeline-Reise ist nach dem Scrollen nicht sichtbar")
        timelineTitle.tap()

        // 4. Auf Detailansicht warten (NavigationLink öffnet sich)
        sleep(2)

        // 5. In der Detailansicht nach unten scrollen um Hafen-Pin-Liste zu sehen
        let detailView = app.collectionViews.firstMatch
        if detailView.waitForExistence(timeout: 5) {
            detailView.swipeUp(velocity: .slow)
        } else {
            app.swipeUp(velocity: .slow)
        }
        sleep(1)

        // 6. Screenshot
        try write(screenshot: XCUIScreen.main.screenshot(), name: "detail-pins-\(suffix)")
    }

    // MARK: - Core helper: Geo-Hero

    @MainActor
    private func captureGeoHero(suffix: String) throws {
        let app = XCUIApplication()
        app.launchArguments += ["-colorScheme", suffix, "-uiTestingResetAndLoadDemoData"]
        app.launch()

        let reisenTab = app.tabBars.buttons["Reisen"]
        XCTAssertTrue(reisenTab.waitForExistence(timeout: 5))
        reisenTab.tap()

        // Warten bis Hero-Card geladen ist
        XCTAssertTrue(app.staticTexts["Norwegische Fjorde"].waitForExistence(timeout: 8))

        try write(screenshot: XCUIScreen.main.screenshot(), name: "geo-hero-\(suffix)")
    }

    // MARK: - Core helper: Karte alle Reisen

    @MainActor
    private func captureMapAllTrips(suffix: String) throws {
        let app = XCUIApplication()
        app.launchArguments += ["-colorScheme", suffix, "-uiTestingResetAndLoadDemoData"]
        app.launch()

        let mapTab = app.tabBars.buttons["Karte"]
        XCTAssertTrue(mapTab.waitForExistence(timeout: 5))
        mapTab.tap()

        XCTAssertTrue(app.staticTexts["Alle Reisen"].waitForExistence(timeout: 10),
                      "Kartenansicht zeigt nicht standardmäßig alle Reisen")
        XCTAssertTrue(app.staticTexts["Mehrere Routen gleichzeitig"].waitForExistence(timeout: 5),
                      "Mehrfachrouten-Hinweis fehlt in der Auswahlkarte")
        RunLoop.current.run(until: Date().addingTimeInterval(1.0))

        app.activate()
        try write(screenshot: XCUIScreen.main.screenshot(), name: "weltkarte-all-\(suffix)")
    }

    // MARK: - Demo-Daten-Loader (shared)

    @MainActor
    private func loadDemoData(app: XCUIApplication) throws {
        let moreTab = app.tabBars.buttons["Mehr"]
        XCTAssertTrue(moreTab.waitForExistence(timeout: 8))
        moreTab.tap()

        let settingsList = app.collectionViews.firstMatch
        if settingsList.waitForExistence(timeout: 5) {
            settingsList.swipeUp()
        } else {
            app.swipeUp()
        }

        let removeButton = app.buttons["Beispieldaten entfernen"]
        if removeButton.waitForExistence(timeout: 3) {
            removeButton.tap()
            if settingsList.exists { settingsList.swipeUp() } else { app.swipeUp() }
        }

        let loadButton = app.buttons["Beispieldaten laden"]
        XCTAssertTrue(loadButton.waitForExistence(timeout: 12))
        loadButton.tap()
    }

    // MARK: - Hilfsfunktion

    private func write(screenshot: XCUIScreenshot, name: String) throws {
        let url = outputDir.appending(component: "\(name).png")
        try screenshot.pngRepresentation.write(to: url)
        print("[Screenshot] \(url.path)")
    }
}
