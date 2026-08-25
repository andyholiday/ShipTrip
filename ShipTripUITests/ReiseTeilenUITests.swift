//
//  ReiseTeilenUITests.swift
//  ShipTripUITests
//
//  Teilen-Aktion der Reise-Detailansicht (Contract C7/C9):
//  - eigene Reise: der Eintrag „Reise teilen" ist da und öffnet das System-Share-Sheet,
//  - Beispielreise (isDemo): der Eintrag fehlt.
//

import XCTest

final class ReiseTeilenUITests: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = false
        // Landscape-Reste eines vorherigen Laufs lassen Form-/List-Zeilen unrealisiert und
        // bringen die Element-Queries unabhängig vom Testinhalt zum Timeout.
        XCUIDevice.shared.orientation = .portrait
    }

    // MARK: - C7: eigene Reise teilen

    @MainActor
    func testTeilenAktionOeffnetDasShareSheet() throws {
        let app = XCUIApplication()
        app.launchArguments += ["-uiTestingResetAndLoadDemoData", "-uiTestingCompleteOnboarding"]
        app.launch()

        let cruiseTitle = "UI-Test-Teilen-W3"
        try createCruise(named: cruiseTitle, in: app)
        openDetail(of: cruiseTitle, in: app)
        openMoreMenu(in: app)

        let shareButton = app.buttons["cruiseDetail.shareButton"]
        XCTAssertTrue(
            shareButton.waitForExistence(timeout: 5),
            "Teilen-Aktion (cruiseDetail.shareButton) fehlt in der Detailansicht einer eigenen Reise"
        )
        shareButton.tap()

        // Das System-Share-Sheet ist ein UIActivityViewController. Je nach iOS-Version trägt es
        // den Container-Identifier „ActivityListView" oder zeigt nur die Vorschau der Anhänge —
        // deshalb zwei gleichwertige Anker statt eines brüchigen.
        let activityList = app.otherElements["ActivityListView"]
        let attachmentPreview = app.staticTexts.matching(
            NSPredicate(format: "label CONTAINS[c] %@", "shiptrip")
        ).firstMatch
        let sheetAppeared = XCTNSPredicateExpectation(
            predicate: NSPredicate { _, _ in activityList.exists || attachmentPreview.exists },
            object: nil
        )
        // Großzügig: Der Export baut die Datei erst (ZIP + Foto-Transcode), bevor das Sheet kommt.
        wait(for: [sheetAppeared], timeout: 60)
    }

    // MARK: - C7: Beispielreise wird nicht geteilt

    @MainActor
    func testTeilenAktionFehltBeiDerBeispielreise() throws {
        let app = XCUIApplication()
        app.launchArguments += ["-uiTestingResetAndLoadDemoData", "-uiTestingCompleteOnboarding"]
        app.launch()

        // „Norwegische Fjorde" ist die einzige in der Zukunft liegende Demo-Reise und damit
        // stabil die Hero-Karte.
        openDetail(of: "Norwegische Fjorde", in: app)
        openMoreMenu(in: app)

        // Zwei Bedingungen: Das Menü ist wirklich offen (sonst wäre die Abwesenheit trivial
        // wahr) UND die Teilen-Aktion fehlt darin.
        XCTAssertTrue(
            app.buttons["Bearbeiten"].waitForExistence(timeout: 5),
            "Menü der Detailansicht ist nicht offen — die Abwesenheitsprüfung wäre wertlos"
        )
        XCTAssertFalse(
            app.buttons["cruiseDetail.shareButton"].exists,
            "Die Beispielreise darf keine Teilen-Aktion anbieten (C1/C7)"
        )
    }

    // MARK: - Helfer

    /// Legt über die UI eine eigene (nicht-Demo) Reise an — für den Share-Export ist das
    /// zwingend, weil `isDemo`-Reisen die Aktion gar nicht erst anbieten.
    @MainActor
    private func createCruise(named title: String, in app: XCUIApplication) throws {
        let reisenTab = app.tabBars.buttons["Reisen"]
        XCTAssertTrue(reisenTab.waitForExistence(timeout: 10))
        reisenTab.tap()

        let addCruiseButton = app.buttons["Neue Reise"]
        XCTAssertTrue(addCruiseButton.waitForExistence(timeout: 10), "Button 'Neue Reise' fehlt")
        addCruiseButton.tap()

        let titleField = app.textFields["Titel"]
        XCTAssertTrue(titleField.waitForExistence(timeout: 5))
        titleField.tap()
        titleField.typeText(title)

        let shipField = app.textFields["Schiffsname"]
        XCTAssertTrue(shipField.waitForExistence(timeout: 5))
        shipField.tap()
        shipField.typeText("Testschiff")

        let saveButton = app.navigationBars["Neue Kreuzfahrt"].buttons["Speichern"]
        XCTAssertTrue(saveButton.waitForExistence(timeout: 5))
        saveButton.tap()

        // Optionaler Erinnerungs-Berechtigungsdialog.
        let laterButton = app.buttons["Später"]
        if laterButton.waitForExistence(timeout: 3) {
            laterButton.tap()
        }
    }

    /// Öffnet die Detailansicht über den Reisetitel in der Liste bzw. auf der Hero-Karte.
    @MainActor
    private func openDetail(of title: String, in app: XCUIApplication) {
        let reisenTab = app.tabBars.buttons["Reisen"]
        XCTAssertTrue(reisenTab.waitForExistence(timeout: 10))
        reisenTab.tap()

        // `.firstMatch`: Der Titel kann kurzzeitig in zwei Repräsentationen auftauchen (Liste
        // und aufsteigende Hero-Karte) — beide führen zu derselben Reise.
        let entry = app.staticTexts.matching(
            NSPredicate(format: "label == %@", title)
        ).firstMatch
        XCTAssertTrue(entry.waitForExistence(timeout: 15), "Reise '\(title)' nicht in der Liste")
        entry.tap()

        XCTAssertTrue(
            app.navigationBars[title].waitForExistence(timeout: 10),
            "Detailansicht von '\(title)' hat sich nicht geöffnet"
        )
    }

    /// Öffnet das „…"-Menü der Detailansicht.
    ///
    /// Das Menü trägt bewusst keinen eigenen Identifier (C9 listet nur die Feature-Elemente),
    /// deshalb erst über das SF-Symbol suchen und ersatzweise die letzte Schaltfläche der
    /// Navigationsleiste nehmen.
    @MainActor
    private func openMoreMenu(in app: XCUIApplication) {
        let navigationBar = app.navigationBars.firstMatch
        XCTAssertTrue(navigationBar.waitForExistence(timeout: 10))

        let symbolMatch = navigationBar.buttons.matching(
            NSPredicate(format: "identifier CONTAINS[c] %@ OR label CONTAINS[c] %@",
                        "ellipsis", "ellipsis")
        ).firstMatch

        if symbolMatch.waitForExistence(timeout: 3) {
            symbolMatch.tap()
        } else {
            let buttons = navigationBar.buttons
            XCTAssertGreaterThan(buttons.count, 0, "Navigationsleiste ohne Schaltflächen")
            buttons.element(boundBy: buttons.count - 1).tap()
        }
    }
}
