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
        app.launchArguments += ["-uiTestingResetAndLoadDemoData", "-uiTestingCompleteOnboarding"]
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

        // B7.1/A2 vergrößert die "Hafen-Momente"-Sektion deutlich (große Cover-Foto-Kachel +
        // Chip-Reihe vor der Ausflugsliste). Bei aktiver Tastatur ist "Ausflug hinzufügen"
        // dadurch nicht mehr automatisch sichtbar/realisiert (das Form ist eine lazy
        // gerenderte CollectionView) – ein Scroll ist hier nötig, wie bei jedem längeren
        // Formular (kein Produktfehler, siehe testEinstellungenHinweisSichtbar für dasselbe
        // Muster bei anderem Content).
        let portForm = app.collectionViews.firstMatch
        XCTAssertTrue(portForm.waitForExistence(timeout: 5))
        portForm.swipeUp()

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

        // Seit dem Route-Journal (Contract J3neu (b)) sind die Trefferflächen getrennt:
        // die Stopp-Kopfzeile klappt, nur der Karteninhalt (PortMemoryCard) navigiert ins
        // Hafen-Formular. Der Stopp muss dafür aufgeklappt sein.
        let stopHeader = app.buttons["routeStop.header.\(portName)"]
        XCTAssertTrue(stopHeader.waitForExistence(timeout: 10))
        if stopHeader.value as? String == "zugeklappt" {
            stopHeader.tap()
        }
        XCTAssertEqual(stopHeader.value as? String, "aufgeklappt",
                       "Stopp liess sich nicht aufklappen – die Karte waere nicht erreichbar")

        // Der Ausflugs-Chip liegt in der PortMemoryCard; ein Tap darauf löst deren
        // Navigation ins Formular aus. Elementtyp-unabhängig, weil der Karteninhalt seit
        // dem A11y-Pass (T8d-2) den Button-Trait trägt.
        let excursionChip = kartenElement(app, label: excursionName)
        XCTAssertTrue(excursionChip.waitForExistence(timeout: 5), "Ausflug nach dem Speichern nicht mehr vorhanden")
        XCTAssertTrue(scrollUntilHittable(excursionChip, in: app), "Hafen-Karte nicht erreichbar")
        excursionChip.tap()

        // 4. Ausflug über die sichtbare Schaltfläche löschen
        // S1.2 (Audit H2) ergänzt im manuellen Modus eine "Zur Suche"-Zeile oberhalb der
        // Hafen-Momente – die Ausflugszeile rutscht damit im Edit-Sheet unter die
        // Bildschirmkante (Tap-Punkt off-screen, das Entfernen kommt nie an). Wie im
        // Anlage-Pfad oben ist deshalb ein Scroll nötig (kein Produktfehler).
        let editForm = app.collectionViews.firstMatch
        XCTAssertTrue(editForm.waitForExistence(timeout: 5))
        editForm.swipeUp()

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
        XCTAssertTrue(stopHeader.waitForExistence(timeout: 10))
        XCTAssertFalse(kartenElement(app, label: excursionName).exists,
                       "Ausflug ist nach dem Speichern wieder da")
    }

    // MARK: - B7.1/A2: Reorder-Toggle + sichtbare native Reorder-Affordance (Gate #2)

    @MainActor
    func testAusflugReihenfolgeAendernZeigtReorderAffordance() throws {
        let app = XCUIApplication()
        app.launchArguments += ["-uiTestingResetAndLoadDemoData", "-uiTestingCompleteOnboarding"]
        app.launch()

        let cruiseTitle = "UI-Test-Reorder-B7"
        let portName = "Testhafen"
        let firstExcursion = "Stadtrundfahrt"
        let secondExcursion = "Hafenrundfahrt"

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

        let addPortButton = app.buttons["Hafen hinzufügen"]
        XCTAssertTrue(addPortButton.waitForExistence(timeout: 5))
        addPortButton.tap()

        let portNameField = app.textFields["Hafenname"]
        XCTAssertTrue(portNameField.waitForExistence(timeout: 5))
        portNameField.tap()
        portNameField.typeText(portName)

        // B7.1/A2 vergrößert die "Hafen-Momente"-Sektion deutlich (große Cover-Foto-Kachel +
        // Chip-Reihe vor der Ausflugsliste). Bei aktiver Tastatur ist "Ausflug hinzufügen"
        // dadurch nicht mehr automatisch sichtbar/realisiert (das Form ist eine lazy
        // gerenderte CollectionView) – ein Scroll ist hier nötig, wie bei jedem längeren
        // Formular (kein Produktfehler, siehe testEinstellungenHinweisSichtbar für dasselbe
        // Muster bei anderem Content).
        let portForm = app.collectionViews.firstMatch
        XCTAssertTrue(portForm.waitForExistence(timeout: 5))
        portForm.swipeUp()

        let excursionField = app.textFields["Ausflug hinzufügen"]
        let addExcursionButton = app.buttons["Ausflug hinzufügen"]
        XCTAssertTrue(excursionField.waitForExistence(timeout: 5))

        // Ersten Ausflug anlegen.
        excursionField.tap()
        excursionField.typeText(firstExcursion)
        addExcursionButton.tap()
        XCTAssertTrue(app.staticTexts[firstExcursion].waitForExistence(timeout: 5))

        // Mit nur einem Ausflug darf der Sortieren-Umschalter noch nicht sichtbar sein
        // (Regressions-Guard für `if excursions.count > 1`).
        XCTAssertFalse(app.buttons["Reihenfolge ändern"].exists,
                        "Reorder-Toggle darf bei nur einem Ausflug nicht erscheinen")

        // Zweiten Ausflug anlegen – erst ab zwei Einträgen ergibt Sortieren Sinn.
        excursionField.tap()
        excursionField.typeText(secondExcursion)
        addExcursionButton.tap()
        XCTAssertTrue(app.staticTexts[secondExcursion].waitForExistence(timeout: 5))

        let reorderToggle = app.buttons["Reihenfolge ändern"]
        XCTAssertTrue(reorderToggle.waitForExistence(timeout: 5), "Reorder-Toggle fehlt trotz zwei Ausflügen")

        // Ausgangsreihenfolge vor dem Umsortieren: erster Ausflug steht über dem zweiten.
        let firstRowText = app.staticTexts[firstExcursion]
        let secondRowText = app.staticTexts[secondExcursion]
        XCTAssertTrue(firstRowText.frame.minY < secondRowText.frame.minY,
                      "Ausgangsreihenfolge unerwartet – '\(firstExcursion)' sollte über '\(secondExcursion)' stehen")

        reorderToggle.tap()

        let doneToggle = app.buttons["Fertig"]
        XCTAssertTrue(doneToggle.waitForExistence(timeout: 5),
                      "Toggle-Button wechselt nach dem Antippen nicht auf 'Fertig'")

        // Sichtbare Reorder-Affordance (Gate #2, Plan B): explizite Auf-/Ab-Buttons statt
        // nativem List-EditMode – Letzteres zeigte in der echten Form/List zweifach
        // nachweislich KEINE Move-Griffe (s. Team-Report). Oberste Zeile ohne aktives
        // "Nach oben", unterste Zeile ohne aktives "Nach unten".
        let moveUpFirstRow = app.buttons["excursion-0-moveUp"]
        let moveDownFirstRow = app.buttons["excursion-0-moveDown"]
        let moveUpSecondRow = app.buttons["excursion-1-moveUp"]
        let moveDownSecondRow = app.buttons["excursion-1-moveDown"]
        XCTAssertTrue(moveUpFirstRow.waitForExistence(timeout: 5), "Auf-/Ab-Buttons für Reorder fehlen")
        XCTAssertTrue(moveDownFirstRow.exists)
        XCTAssertTrue(moveUpSecondRow.exists)
        XCTAssertTrue(moveDownSecondRow.exists)
        XCTAssertFalse(moveUpFirstRow.isEnabled, "Oberste Zeile darf keinen aktiven 'Nach oben'-Button haben")
        XCTAssertFalse(moveDownSecondRow.isEnabled, "Unterste Zeile darf keinen aktiven 'Nach unten'-Button haben")

        // Zweiten Ausflug einmal nach oben verschieben – Reihenfolge muss sich im UI vertauschen
        // (stärkerer Beleg als ein reiner Elementzahl-Vergleich).
        moveUpSecondRow.tap()
        XCTAssertTrue(secondRowText.frame.minY < firstRowText.frame.minY,
                      "Reihenfolge hat sich nach 'Nach oben' nicht vertauscht")

        // Roundtrip: "Fertig" schaltet zurück, Auf-/Ab-Buttons verschwinden wieder.
        doneToggle.tap()
        XCTAssertTrue(reorderToggle.waitForExistence(timeout: 5),
                      "Toggle-Button kehrt nach 'Fertig' nicht wieder zu 'Reihenfolge ändern' zurück")
        XCTAssertFalse(app.buttons["excursion-0-moveUp"].exists,
                       "Auf-/Ab-Buttons sollten nach 'Fertig' nicht mehr existieren")

        // Sheets ohne Speichern verlassen (sauberer Teardown, kein Roundtrip-Anspruch hier).
        app.navigationBars["Hafen hinzufügen"].buttons["Abbrechen"].tap()
        app.navigationBars["Neue Kreuzfahrt"].buttons["Abbrechen"].tap()
    }

    // MARK: - B6.3: Einstellungen-Hinweis zu eigenen Reedereien/Schiffen

    @MainActor
    func testEinstellungenHinweisSichtbar() throws {
        let app = XCUIApplication()
        app.launchArguments += ["-uiTestingCompleteOnboarding"]
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

    // MARK: - Bausteine

    /// Element in der Hafen-Karte über sein Label, unabhängig vom Elementtyp: der
    /// Karteninhalt trägt seit dem A11y-Pass (T8d-2) den Button-Trait, war davor aber
    /// StaticText.
    private func kartenElement(_ app: XCUIApplication, label: String) -> XCUIElement {
        app.descendants(matching: .any)
            .matching(NSPredicate(format: "label == %@", label))
            .firstMatch
    }

    /// Wartet erst auf die Existenz und scrollt **danach** – andersherum scrollt der Test
    /// an einem noch nicht gerenderten Element vorbei (Idiom aus JournalRouteFadenUITests).
    @discardableResult
    private func scrollUntilHittable(
        _ element: XCUIElement,
        in app: XCUIApplication,
        timeout: TimeInterval = 15,
        maxSwipes: Int = 8
    ) -> Bool {
        guard element.waitForExistence(timeout: timeout) else { return false }
        var swipes = 0
        while !element.isHittable && swipes < maxSwipes {
            let form = app.collectionViews.firstMatch
            if form.exists && form.isHittable { form.swipeUp() } else { app.swipeUp() }
            swipes += 1
        }
        return element.isHittable
    }
}
