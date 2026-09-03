//
//  WidgetScreenshotUITests.swift
//  ShipTripUITests
//
//  Nachweis K2 (Taskplan 1.9.0, LE 10): Belegbilder aller Widget-Familien in
//  allen Zustaenden. WidgetKit rendert die echten Widgets in einem fremden
//  Prozess, den XCUITest nicht erreicht — fotografiert wird deshalb die
//  Debug-Galerie der App (`-widgetPreview`, `WidgetPreviewGalleryView`), die
//  dieselben Familien-Ansichten in Widget-Rahmengroesse zeigt.
//
//  Ausgabe-Ordner kommt wie in `HauptansichtScreenshotTests` aus der
//  Umgebungsvariable SHIPTRIP_SCREENSHOT_DIR; ohne sie wird die Suite per
//  XCTSkip uebersprungen statt zu scheitern.
//
//  Aufruf:
//    SHIPTRIP_SCREENSHOT_DIR=<repo>/audit/screenshots xcodebuild test-without-building \
//      -scheme ShipTrip -destination "id=$SIM_UDID" \
//      -only-testing:ShipTripUITests/WidgetScreenshotUITests
//

import XCTest

final class WidgetScreenshotUITests: XCTestCase {

    // MARK: - Zellen der Galerie

    /// Identifier-Bausteine — Spiegel von `WidgetPreviewFamily` und
    /// `WidgetPreviewStateKind`. Das UI-Test-Target linkt die App nicht, die
    /// Namen stehen hier deshalb als Zeichenketten.
    private static let families = ["small", "medium", "rectangular", "circular"]

    /// Reihenfolge wie in der Galerie — die Suite scrollt nur vorwaerts.
    private static let states = ["active", "countdown", "idle", "unavailable"]

    private static let outputDirEnvKey = "SHIPTRIP_SCREENSHOT_DIR"

    private var outputDir: URL {
        get throws {
            let path = ProcessInfo.processInfo.environment[Self.outputDirEnvKey] ?? ""
            guard !path.isEmpty else {
                throw XCTSkip(
                    "\(Self.outputDirEnvKey) nicht gesetzt — Widget-Screenshots uebersprungen."
                )
            }
            return URL(filePath: path)
        }
    }

    override func setUpWithError() throws {
        continueAfterFailure = false
        try FileManager.default.createDirectory(
            at: try outputDir, withIntermediateDirectories: true
        )
    }

    // MARK: - Laeufe

    /// Der Kontaktbogen: alle vier Familien in den drei regulaeren
    /// Zustaenden, dazu `unavailable` in der kleinen Familie.
    @MainActor
    func testGallery_DE_Light_LargeType() throws {
        let app = try launch(language: "de", locale: "de_DE", scheme: "light", size: .large)
        for family in Self.families {
            for state in ["active", "countdown", "idle"] {
                try capture(app, family: family, state: state, suffix: "de-light-L")
            }
        }
        try capture(app, family: "small", state: "unavailable", suffix: "de-light-L")
    }

    /// Englisch: Beleg, dass der Widget-Katalog auch im Harness greift.
    @MainActor
    func testGallery_EN_Light_LargeType() throws {
        let app = try launch(language: "en", locale: "en_US", scheme: "light", size: .large)
        try capture(app, family: "small", state: "active", suffix: "en-light-L")
    }

    /// Dunkles Erscheinungsbild.
    @MainActor
    func testGallery_DE_Dark_LargeType() throws {
        let app = try launch(language: "de", locale: "de_DE", scheme: "dark", size: .large)
        try capture(app, family: "medium", state: "active", suffix: "de-dark-L")
    }

    /// Dynamic Type XXL mit den adversarial langen Namen der Fixture —
    /// der Pruefstein fuer abgeschnittene Texte (LE 10).
    @MainActor
    func testGallery_DE_Light_AccessibilityXXL() throws {
        let app = try launch(
            language: "de", locale: "de_DE", scheme: "light", size: .accessibilityXXL
        )
        for family in Self.families {
            for state in ["active", "countdown"] {
                try capture(app, family: family, state: state, suffix: "de-light-XXL")
            }
        }
    }

    // MARK: - Start

    private enum ContentSize: String {
        case large = "UICTContentSizeCategoryL"
        case accessibilityXXL = "UICTContentSizeCategoryAccessibilityXXL"
    }

    @MainActor
    private func launch(
        language: String,
        locale: String,
        scheme: String,
        size: ContentSize
    ) throws -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments += [
            "-widgetPreview",
            "-uiTestingCompleteOnboarding",
            "-colorScheme", scheme,
            "-AppleLanguages", "(\(language))",
            "-AppleLocale", locale,
            "-UIPreferredContentSizeCategoryName", size.rawValue
        ]
        app.launch()

        // Erste Zelle der Galerie als Startsignal — sie ist die eigentliche
        // Vorbedingung, nicht die Scroll-Flaeche darum.
        let firstCell = app.descendants(matching: .any)
            .matching(identifier: "widget-small-active").firstMatch
        XCTAssertTrue(
            firstCell.waitForExistence(timeout: 15),
            "Debug-Galerie nicht erschienen — greift der `-widgetPreview`-Abzweig?"
        )
        return app
    }

    /// Die Flaeche, an der gezogen wird. Faellt der Identifier aus (SwiftUI
    /// legt die Scroll-Ansicht nicht in jeder Version als eigenes Element ab),
    /// tut es die erste Scroll-Ansicht und zuletzt das Fenster selbst.
    @MainActor
    private func scrollSurface(in app: XCUIApplication) -> XCUIElement {
        let named = app.scrollViews["widget-gallery"]
        if named.exists { return named }
        let any = app.scrollViews.firstMatch
        return any.exists ? any : app
    }

    // MARK: - Aufnahme

    /// Scrollt die Zelle in Sicht und legt `widget-<familie>-<zustand>-<lauf>.png`
    /// ab. Fotografiert wird das Element selbst, nicht der Bildschirm — die
    /// PNG-Kante entspricht damit exakt der Widget-Rahmengroesse.
    @MainActor
    private func capture(
        _ app: XCUIApplication,
        family: String,
        state: String,
        suffix: String
    ) throws {
        let identifier = "widget-\(family)-\(state)"
        let cell = app.descendants(matching: .any).matching(identifier: identifier).firstMatch
        XCTAssertTrue(
            cell.waitForExistence(timeout: 10),
            "Zelle \(identifier) fehlt in der Galerie"
        )
        XCTAssertTrue(
            scrollIntoView(cell, in: app),
            "Zelle \(identifier) liess sich nicht vollstaendig in Sicht scrollen"
        )

        let url = try outputDir.appending(component: "\(identifier)-\(suffix).png")
        try cell.screenshot().pngRepresentation.write(to: url)

        let size = try FileManager.default
            .attributesOfItem(atPath: url.path())[.size] as? Int ?? 0
        XCTAssertGreaterThan(size, 0, "Screenshot \(url.lastPathComponent) ist leer")
        print("[Widget-Screenshot] \(url.path())")
    }

    /// Zieht die Galerie schrittweise weiter, bis das Element vollstaendig im
    /// Fenster liegt. Bewusst kleine Schritte (~20 % der Fensterhoehe): eine
    /// Zelle ist hoechstens 170 pt hoch und kann so nicht uebersprungen werden.
    @MainActor
    private func scrollIntoView(
        _ element: XCUIElement,
        in app: XCUIApplication,
        maxSteps: Int = 25
    ) -> Bool {
        let window = app.windows.firstMatch
        let surface = scrollSurface(in: app)

        for _ in 0...maxSteps {
            let visible = window.frame.insetBy(dx: 0, dy: 60)
            if element.exists, element.frame.height > 0, visible.contains(element.frame) {
                // Kurz ausschwingen lassen, damit die Aufnahme nicht in eine
                // laufende Scroll-Animation faellt.
                RunLoop.current.run(until: Date().addingTimeInterval(0.35))
                return true
            }
            let start = surface.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.65))
            let end = surface.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.45))
            start.press(forDuration: 0.05, thenDragTo: end)
        }
        return false
    }
}
