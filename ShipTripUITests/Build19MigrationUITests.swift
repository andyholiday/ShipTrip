//
//  Build19MigrationUITests.swift
//  ShipTripUITests
//

import XCTest

/// Prüft einen zuvor mit dem unveränderten Build-19-Code erzeugten Store nach
/// Installation des aktuellen Builds. Der Test wird nur im expliziten
/// Migrations-Smoke-Workflow aktiviert; er setzt den Store bewusst nicht zurück.
@MainActor
final class Build19MigrationUITests: XCTestCase {

    func testBuild19StorePreservesCruisesAndRelationships() throws {
        guard ProcessInfo.processInfo.environment["SHIPTRIP_BUILD19_MIGRATION_SMOKE"] == "1" else {
            throw XCTSkip("Nur für den expliziten Build-19-Migrations-Smoke-Test")
        }

        let app = XCUIApplication()
        app.launch()

        XCTAssertTrue(app.tabBars.buttons["Reisen"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.staticTexts["Norwegische Fjorde"].waitForExistence(timeout: 10))

        app.staticTexts["Norwegische Fjorde"].tap()
        XCTAssertTrue(
            app.staticTexts["Kiel"].waitForExistence(timeout: 10),
            "Die Build-19-Route wurde bei der Migration nicht erhalten"
        )
    }
}
