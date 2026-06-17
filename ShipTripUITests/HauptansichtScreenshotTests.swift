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
            Thread.sleep(forTimeInterval: 0.5)
        } else {
            // Fallback: einfach die App nach oben swipen
            app.swipeUp()
            Thread.sleep(forTimeInterval: 0.5)
        }

        // 3. Falls Demo-Daten vorhanden (Restbestand), erst entfernen
        let removeButton = app.buttons["Beispieldaten entfernen"]
        if removeButton.waitForExistence(timeout: 5) {
            removeButton.tap()
            Thread.sleep(forTimeInterval: 2.5)
            // Nach dem Entfernen wieder nach unten scrollen, um Lade-Button zu sehen
            if settingsList.exists { settingsList.swipeUp() } else { app.swipeUp() }
            Thread.sleep(forTimeInterval: 0.5)
        }

        // 4. Lade-Button muss jetzt sichtbar sein (leerer Store)
        let loadButton = app.buttons["Beispieldaten laden"]
        XCTAssertTrue(loadButton.waitForExistence(timeout: 15),
                      "Lade-Button 'Beispieldaten laden' nicht erschienen – Demo-Sektion fehlt oder nicht sichtbar?")
        loadButton.tap()

        // 4. Warten bis alle SwiftData-Objekte inkl. Photo (Gradient-PNG) gespeichert sind
        Thread.sleep(forTimeInterval: 4.0)

        // 5. Zum Reisen-Tab wechseln
        let reisenTab = app.tabBars.buttons["Reisen"]
        XCTAssertTrue(reisenTab.waitForExistence(timeout: 8))
        reisenTab.tap()
        Thread.sleep(forTimeInterval: 2.0)

        // 6. Screenshot als hero-photo-clean speichern
        let screenshot = XCUIScreen.main.screenshot()
        let outURL = outputDir.appending(component: "meine-reisen-hero-photo-clean.png")
        try screenshot.pngRepresentation.write(to: outURL)
        print("[Screenshot-HeroClean] \(outURL.path)")
    }

    // MARK: - Core

    @MainActor
    private func captureMainView(suffix: String) throws {
        let app = XCUIApplication()
        app.launch()

        // 1. Zum Einstellungs-Tab wechseln (Tab "Mehr")
        let moreTab = app.tabBars.buttons["Mehr"]
        XCTAssertTrue(moreTab.waitForExistence(timeout: 8))
        moreTab.tap()

        // 2. Demo-Daten immer frisch laden: erst entfernen (falls vorhanden), dann neu laden.
        //    Demo-Sektion ist unten in der Liste — erst scrollen, dann Buttons suchen.
        //    SwiftUI List rendert auf iOS 18+ als UICollectionView, nicht als UITableView.
        let settingsList = app.collectionViews.firstMatch
        if settingsList.waitForExistence(timeout: 5) {
            settingsList.swipeUp()
        } else {
            app.swipeUp()
        }
        Thread.sleep(forTimeInterval: 0.5)

        let loadButton = app.buttons["Beispieldaten laden"]
        let removeButton = app.buttons["Beispieldaten entfernen"]

        if removeButton.waitForExistence(timeout: 5) {
            removeButton.tap()
            // Warten bis SwiftData persistiert und SwiftUI re-rendert (Lade-Button erscheint)
            Thread.sleep(forTimeInterval: 2.0)
            if settingsList.exists { settingsList.swipeUp() } else { app.swipeUp() }
            Thread.sleep(forTimeInterval: 0.5)
        }

        // Nach dem Entfernen (oder bei leerem Store) muss der Lade-Button sichtbar sein.
        XCTAssertTrue(loadButton.waitForExistence(timeout: 12))
        loadButton.tap()
        // Warten bis SwiftData + Photo-Seed gespeichert hat (inkl. Gradient-Bild)
        Thread.sleep(forTimeInterval: 3.5)

        // 3. Zum Reisen-Tab wechseln
        let reisenTab = app.tabBars.buttons["Reisen"]
        XCTAssertTrue(reisenTab.waitForExistence(timeout: 5))
        reisenTab.tap()
        Thread.sleep(forTimeInterval: 1.5)

        // 4. Screenshot oben (Hero-Card + Stats-Strip sichtbar)
        try write(screenshot: XCUIScreen.main.screenshot(), name: "meine-reisen-\(suffix)")

        // 5. Nach unten scrollen für Timeline-Rows
        let list = app.collectionViews.firstMatch
        if list.exists {
            list.swipeUp(velocity: .slow)
        } else {
            app.swipeUp(velocity: .slow)
        }
        Thread.sleep(forTimeInterval: 0.8)

        try write(screenshot: XCUIScreen.main.screenshot(), name: "meine-reisen-\(suffix)-scrolled")
    }

    // MARK: - Hilfsfunktion

    private func write(screenshot: XCUIScreenshot, name: String) throws {
        let url = outputDir.appending(component: "\(name).png")
        try screenshot.pngRepresentation.write(to: url)
        print("[Screenshot] \(url.path)")
    }
}
