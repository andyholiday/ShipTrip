//
//  AusflugLoeschenUITests.swift
//  ShipTripUITests
//
//  UI-Smoke-Tests für Welle B6 (TestFlight-Feedback):
//  - B6.1: Ausflug entfernen – die neue sichtbare Papierkorb-Schaltfläche muss in beiden
//    Editor-Pfaden (PortFormView übers CruiseDetailView-Reopen) funktionieren.
//  - B6.3: Einstellungen-Hinweis zu eigenen Reedereien/Schiffen muss sichtbar sein.
//

import XCTest

final class AusflugLoeschenUITests: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = false
        // Der Simulator kann von einem vorherigen Lauf noch im Landscape-Zustand sein (die App
        // unterstützt laut Info.plist auch Landscape); sie richtet sich beim Start danach aus.
        // Im stark verkleinerten Landscape-Viewport werden Form-/List-Zeilen unterhalb der
        // Tastatur bzw. außerhalb des sichtbaren Bereichs nicht mehr gerendert, was die
        // nachfolgenden Element-Queries unabhängig vom eigentlichen Testinhalt zum Timeout
        // bringt – deshalb fest auf Portrait fixieren.
        XCUIDevice.shared.orientation = .portrait
    }

    // MARK: - B6.1: Ausflug anlegen → speichern → Reise erneut öffnen → löschen → speichern

    @MainActor
    func testAusflugLoeschenUeberSichtbareSchaltflaeche() throws {
        let app = XCUIApplication()
        app.launchArguments += ["-uiTestingResetAndLoadDemoData"]
        app.launch()

        let cruiseTitle = "UI-Test-Ausflug-B6"
        let portName = "Testhafen"
        let excursionName = "Stadtrundfahrt"

        // 1. Neue Kreuzfahrt anlegen
        let reisenTab = app.tabBars.buttons["Reisen"]
        XCTAssertTrue(reisenTab.waitForExistence(timeout: 10))
        reisenTab.tap()

        let addCruiseButton = app.buttons["Neue Reise"]
        XCTAssertTrue(addCruiseButton.waitForExistence(timeout: 10), "Button 'Neue Reise' nicht gefunden")
        addCruiseButton.tap()

        let titleField = app.textFields["Titel"]
        XCTAssertTrue(titleField.waitForExistence(timeout: 5))
        titleField.tap()
        titleField.typeText(cruiseTitle)

        let shipField = app.textFields["Schiffsname"]
        XCTAssertTrue(shipField.waitForExistence(timeout: 5))
        shipField.tap()
        shipField.typeText("Testschiff")

        // 2. Hafen mit Ausflug hinzufügen
        let addPortButton = app.buttons["Hafen hinzufügen"]
        XCTAssertTrue(addPortButton.waitForExistence(timeout: 5))
        addPortButton.tap()

        let portNameField = app.textFields["Hafenname"]
        XCTAssertTrue(portNameField.waitForExistence(timeout: 5))
        portNameField.tap()
        portNameField.typeText(portName)

        let excursionField = app.textFields["Ausflug hinzufügen"]
        XCTAssertTrue(excursionField.waitForExistence(timeout: 5))
        excursionField.tap()
        excursionField.typeText(excursionName)

        let addExcursionButton = app.buttons["Ausflug hinzufügen"]
        XCTAssertTrue(addExcursionButton.waitForExistence(timeout: 5))
        addExcursionButton.tap()

        // Sichtbare Lösch-Affordance (B6.1) muss jetzt neben dem Ausflug erscheinen.
        XCTAssertTrue(app.staticTexts[excursionName].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["Ausflug entfernen"].waitForExistence(timeout: 5),
                      "Sichtbare Lösch-Schaltfläche für Ausflug fehlt (B6.1)")

        // Hafen-Sheet speichern (navigationBar-Titel "Hafen hinzufügen" statt der generischen
        // Query, da sonst der spätere Kreuzfahrt-Speichern-Button ebenfalls "Speichern" heißt).
        let savePortButton = app.navigationBars["Hafen hinzufügen"].buttons["Speichern"]
        XCTAssertTrue(savePortButton.waitForExistence(timeout: 5))
        savePortButton.tap()

        // Kreuzfahrt speichern
        let saveCruiseButton = app.navigationBars["Neue Kreuzfahrt"].buttons["Speichern"]
        XCTAssertTrue(saveCruiseButton.waitForExistence(timeout: 5))
        saveCruiseButton.tap()

        // Optionaler Erinnerungs-Berechtigungs-Dialog (A2.1) – falls vorhanden, "Später" wählen.
        let laterButton = app.buttons["Später"]
        if laterButton.waitForExistence(timeout: 3) {
            laterButton.tap()
        }

        // 3. Reise erneut öffnen (Detailansicht)
        // .firstMatch statt exaktem Einzel-Element: der Titel kann kurz nach dem Schließen des
        // Formulars gleichzeitig in zwei Repräsentationen auftauchen (z. B. während die neue
        // Reise zur Hero-Karte aufsteigt); beide referenzieren dieselbe Kreuzfahrt, daher ist
        // jedes Match für die Navigation gleichwertig.
        let cruiseEntry = app.staticTexts.matching(NSPredicate(format: "label == %@", cruiseTitle)).firstMatch
        XCTAssertTrue(cruiseEntry.waitForExistence(timeout: 10), "Neu angelegte Reise nicht in der Liste gefunden")
        cruiseEntry.tap()

        let portRow = app.staticTexts[portName]
        XCTAssertTrue(portRow.waitForExistence(timeout: 10))
        XCTAssertTrue(app.staticTexts[excursionName].waitForExistence(timeout: 5), "Ausflug nach dem Speichern nicht mehr vorhanden")
        portRow.tap()

        // 4. Ausflug über die sichtbare Schaltfläche löschen
        let removeExcursionButton = app.buttons["Ausflug entfernen"]
        XCTAssertTrue(removeExcursionButton.waitForExistence(timeout: 5), "Lösch-Schaltfläche im Edit-Pfad nicht gefunden")
        removeExcursionButton.tap()
        // Scoped auf die Form (CollectionView) des Sheets: Im Hintergrund zeigt
        // CruiseDetailView denselben Ausflugsnamen noch an (Route-Zeile aus dem
        // ungespeicherten Modell), eine unscoped staticTexts-Query trifft sonst dieses
        // Hintergrund-Element statt des gerade geleerten Sheets und meldet false-negativ.
        XCTAssertTrue(app.collectionViews.staticTexts[excursionName].waitForNonExistence(timeout: 5),
                      "Ausflug wurde nicht aus der Liste entfernt")

        let savePortAgainButton = app.navigationBars["Hafen bearbeiten"].buttons["Speichern"]
        XCTAssertTrue(savePortAgainButton.waitForExistence(timeout: 5))
        savePortAgainButton.tap()

        // 5. Roundtrip verifizieren: Ausflug bleibt nach dem Speichern gelöscht
        XCTAssertTrue(portRow.waitForExistence(timeout: 10))
        XCTAssertFalse(app.staticTexts[excursionName].exists, "Ausflug ist nach dem Speichern wieder da")
    }

    // MARK: - B6.3: Einstellungen-Hinweis zu eigenen Reedereien/Schiffen

    @MainActor
    func testEinstellungenHinweisSichtbar() throws {
        let app = XCUIApplication()
        app.launch()

        let moreTab = app.tabBars.buttons["Mehr"]
        XCTAssertTrue(moreTab.waitForExistence(timeout: 10))
        moreTab.tap()

        let settingsList = app.collectionViews.firstMatch
        if settingsList.waitForExistence(timeout: 5) {
            settingsList.swipeUp()
            settingsList.swipeUp()
        } else {
            app.swipeUp()
            app.swipeUp()
        }

        // Volltext als Identifier überschreitet XCUITests 128-Zeichen-Limit für String-Queries –
        // stattdessen per NSPredicate auf einen kurzen, stabilen Teilstring matchen.
        let entryHint = app.staticTexts.matching(
            NSPredicate(format: "label CONTAINS[c] %@", "eigene Einträge anlegen")
        ).firstMatch
        XCTAssertTrue(entryHint.waitForExistence(timeout: 5), "Einstellungen-Hinweis (B6.3) nicht sichtbar")

        let managementLink = app.buttons["Eigene Reedereien & Schiffe"]
        XCTAssertTrue(managementLink.waitForExistence(timeout: 5))
        managementLink.tap()

        let detailHint = app.staticTexts.matching(
            NSPredicate(format: "label CONTAINS[c] %@", "Lege sie hier selbst an")
        ).firstMatch
        XCTAssertTrue(detailHint.waitForExistence(timeout: 5), "Hinweis in ShippingLineManagementView (B6.3) nicht sichtbar")
    }
}
