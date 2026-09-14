//
//  JournalRouteFadenUITests.swift
//  ShipTripUITests
//
//  UI-Tests fuer den Journal-Kern-Flow im Route-Faden (T8, Contract J2/J2a/J3neu):
//  Eintrag anlegen → in der Stopp-Karte sehen → oeffnen → bearbeiten → loeschen,
//  dazu die Klapp-Automatik und der Sammelblock „Weitere Eintraege“.
//
//  Die Anker sind `accessibilityIdentifier`-basiert (T8d-2 A11y-Pass), damit die
//  Tests weder an Label-Wortlauten noch an der Reihenfolge im Store haengen.
//  Die Datumslagen entstehen ausschliesslich aus den Formular-Defaults bzw. der
//  Beispielreise — keine Systemzeit-Manipulation.
//

import XCTest

final class JournalRouteFadenUITests: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = false
        // Wie in AusflugLoeschenUITests: im Landscape-Viewport werden Form-/List-Zeilen
        // ausserhalb des sichtbaren Bereichs nicht gerendert.
        XCUIDevice.shared.orientation = .portrait
    }

    // MARK: - Kern-Flow: anlegen → sehen → oeffnen → bearbeiten → loeschen

    @MainActor
    func testEintragAnlegenOeffnenBearbeitenLoeschen() throws {
        let app = startApp()
        let hafen = "TesthafenHeute"
        let text = "Erster Eintrag"
        let ergaenzung = "Nachtrag"

        oeffneNeueReise(app, titel: "UI-Test-Journal-Kern", haefen: [hafen])

        // Aktive Reise (Start = heute): der heutige Stopp ist offen, die Erfassung
        // liegt also direkt in der Karte (J3neu (b)/(d)).
        let addEntry = app.buttons["routeStop.addEntry.\(hafen)"]
        XCTAssertTrue(scrollUntilHittable(addEntry, in: app),
                      "Aktion „Tagebuch-Eintrag“ im aufgeklappten Stopp nicht erreichbar")
        addEntry.tap()

        schreibeErinnerung(app, text: text)
        waehleStimmungGut(app)
        speichereEditor(app)

        // 1. In der Stopp-Karte sichtbar — und gerade nicht im Sammelblock:
        //    der Eintrag haengt am Stopp, aus dem heraus er erfasst wurde.
        let row = eintragsZeile(app, enthaelt: text)
        XCTAssertTrue(row.waitForExistence(timeout: 10),
                      "Neuer Eintrag erscheint nicht als Zeile im Route-Faden")
        XCTAssertFalse(app.staticTexts["routeExtraEntries.title"].exists,
                       "Eintrag mit Stopp-Bezug darf nicht im Sammelblock landen (J3neu (a))")

        // 2. Oeffnen
        XCTAssertTrue(scrollUntilHittable(row, in: app))
        row.tap()

        let detailText = app.staticTexts["journalDetail.text"]
        XCTAssertTrue(detailText.waitForExistence(timeout: 10),
                      "Eintrags-Detailansicht zeigt den Text nicht")
        XCTAssertEqual(detailText.label, text)
        XCTAssertTrue(
            app.descendants(matching: .any)
                .matching(NSPredicate(format: "label CONTAINS %@", "Gut"))
                .firstMatch.exists,
            "Lokalisiertes Stimmungs-Label „Gut“ fehlt in der Detailansicht"
        )

        // 3. Bearbeiten — einziger Bearbeiten-Einstieg ist die Detailansicht (J3neu (c)).
        let editButton = app.buttons["journalDetail.editButton"]
        XCTAssertTrue(editButton.waitForExistence(timeout: 5))
        editButton.tap()

        schreibeErinnerung(app, text: ergaenzung)
        speichereEditor(app)

        let nachEdit = app.staticTexts["journalDetail.text"]
        XCTAssertTrue(nachEdit.waitForExistence(timeout: 10),
                      "Detailansicht nach dem Bearbeiten nicht mehr da")
        // Wo genau der Cursor beim Antippen des TextEditors landet, ist
        // Systemverhalten und ueber iOS-Versionen nicht zugesichert — geprueft
        // wird deshalb, dass beide Teile im gespeicherten Text stehen, nicht
        // ihre Reihenfolge.
        XCTAssertTrue(nachEdit.label.contains(text),
                      "Ursprungstext beim Bearbeiten verloren: \(nachEdit.label)")
        XCTAssertTrue(nachEdit.label.contains(ergaenzung),
                      "Ergaenzung nicht uebernommen: \(nachEdit.label)")

        // 4. Loeschen — ebenfalls nur hier (J3neu (d)).
        let deleteButton = app.buttons["journalDetail.deleteButton"]
        XCTAssertTrue(scrollUntilHittable(deleteButton, in: app))
        deleteButton.tap()

        let confirm = app.buttons["Löschen"].firstMatch
        XCTAssertTrue(confirm.waitForExistence(timeout: 5), "Loesch-Bestaetigung fehlt")
        confirm.tap()

        XCTAssertTrue(
            app.buttons["routeStop.addEntry.\(hafen)"].waitForExistence(timeout: 10),
            "Nach dem Loeschen wird nicht in den Route-Faden zurueckgekehrt"
        )
        XCTAssertFalse(eintragsZeile(app, enthaelt: ergaenzung).exists,
                       "Geloeschter Eintrag steht weiterhin im Route-Faden")
    }

    // MARK: - Klapp-Automatik (J3neu (b))

    /// Aktive Reise: nur der heutige Stopp ist offen. Der zweite Hafen bekommt im
    /// Formular automatisch den Folgetag (`defaultArrivalDate`), deshalb braucht der
    /// Test keinen DatePicker und keine gefaelschte Systemzeit.
    @MainActor
    func testKlappAutomatikAktiveReiseNurHeuteOffenUndManuellesToggle() throws {
        let app = startApp()
        let heute = "StoppHeute"
        let morgen = "StoppMorgen"

        oeffneNeueReise(app, titel: "UI-Test-Journal-Klapp", haefen: [heute, morgen])

        let kopfHeute = app.buttons["routeStop.header.\(heute)"]
        let kopfMorgen = app.buttons["routeStop.header.\(morgen)"]
        XCTAssertTrue(kopfHeute.waitForExistence(timeout: 10))
        XCTAssertTrue(kopfMorgen.waitForExistence(timeout: 10))

        XCTAssertEqual(kopfHeute.value as? String, "aufgeklappt",
                       "Aktive Reise: der heutige Stopp muss aufgeklappt sein")
        XCTAssertEqual(kopfMorgen.value as? String, "zugeklappt",
                       "Aktive Reise: fremde Tage muessen zugeklappt bleiben")

        // Manuelle Uebersteuerung
        XCTAssertTrue(scrollUntilHittable(kopfMorgen, in: app))
        kopfMorgen.tap()
        XCTAssertEqual(kopfMorgen.value as? String, "aufgeklappt",
                       "Manuelles Aufklappen wirkt nicht")

        // Jetzt ist alles offen — der Kopf-Schalter klappt folglich alles zu.
        let alleSchalter = app.buttons["routeSection.toggleAll"]
        XCTAssertTrue(scrollUntilHittable(alleSchalter, in: app))
        alleSchalter.tap()
        XCTAssertEqual(kopfHeute.value as? String, "zugeklappt")
        XCTAssertEqual(kopfMorgen.value as? String, "zugeklappt")
    }

    /// Beendete Reise: alle Stopps offen. Traeger ist die Beispielreise
    /// „Westliches Mittelmeer 2025“ — eine Reise, die garantiert in der
    /// Vergangenheit liegt.
    @MainActor
    func testKlappAutomatikBeendeteReiseAllesOffen() throws {
        let app = startApp()

        let reisenTab = app.tabBars.buttons["Reisen"]
        XCTAssertTrue(reisenTab.waitForExistence(timeout: 15))
        reisenTab.tap()

        let demoReise = app.staticTexts
            .matching(NSPredicate(format: "label == %@", "Westliches Mittelmeer 2025"))
            .firstMatch
        XCTAssertTrue(scrollUntilHittable(demoReise, in: app),
                      "Beispielreise „Westliches Mittelmeer 2025“ nicht gefunden")
        demoReise.tap()

        let koepfe = app.buttons.matching(
            NSPredicate(format: "identifier BEGINSWITH %@", "routeStop.header.")
        )
        XCTAssertTrue(app.buttons["routeStop.header.Barcelona"].waitForExistence(timeout: 15),
                      "Route-Faden der Beispielreise nicht geladen")
        XCTAssertGreaterThan(koepfe.count, 1, "Beispielreise ohne Route-Stopps")

        for index in 0..<koepfe.count {
            let kopf = koepfe.element(boundBy: index)
            XCTAssertEqual(kopf.value as? String, "aufgeklappt",
                           "Beendete Reise: „\(kopf.identifier)“ ist zugeklappt")
        }
    }

    // MARK: - Sammelblock (J3neu (a) Regel 4)

    /// Ein Eintrag verliert seinen Traeger, wenn der Stopp geloescht wird — dann
    /// muss ihn der Sammelblock „Weitere Eintraege“ auffangen statt ihn zu
    /// verschlucken.
    @MainActor
    func testSammelblockFaengtEintragOhneStoppAuf() throws {
        let app = startApp()
        let heute = "SammelHeute"
        let morgen = "SammelMorgen"
        let text = "Eintrag ohne Stopp"

        oeffneNeueReise(app, titel: "UI-Test-Journal-Sammel", haefen: [heute, morgen])

        // Stopp von morgen aufklappen und dort erfassen (Eintragstag = morgen).
        let kopfMorgen = app.buttons["routeStop.header.\(morgen)"]
        XCTAssertTrue(scrollUntilHittable(kopfMorgen, in: app))
        kopfMorgen.tap()

        let addEntry = app.buttons["routeStop.addEntry.\(morgen)"]
        XCTAssertTrue(scrollUntilHittable(addEntry, in: app))
        addEntry.tap()

        schreibeErinnerung(app, text: text)
        speichereEditor(app)

        XCTAssertTrue(eintragsZeile(app, enthaelt: text).waitForExistence(timeout: 10))
        XCTAssertFalse(app.staticTexts["routeExtraEntries.title"].exists,
                       "Solange der Stopp existiert, gehoert der Eintrag zu ihm")

        // Stopp loeschen → der Tag hat keinen Traeger mehr.
        XCTAssertTrue(scrollUntilHittable(kopfMorgen, in: app))
        kopfMorgen.press(forDuration: 1.2)
        let loeschen = app.buttons["Löschen"].firstMatch
        XCTAssertTrue(loeschen.waitForExistence(timeout: 5), "Kontextmenue ohne „Löschen“")
        loeschen.tap()

        XCTAssertTrue(
            app.staticTexts["routeExtraEntries.title"].waitForExistence(timeout: 10),
            "Sammelblock „Weitere Eintraege“ erscheint nicht fuer einen traegerlosen Eintrag"
        )
        XCTAssertTrue(eintragsZeile(app, enthaelt: text).exists,
                      "Traegerloser Eintrag ist aus dem Faden verschwunden")
    }

    // MARK: - Bausteine

    private func startApp() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments += ["-uiTestingResetAndLoadDemoData", "-uiTestingCompleteOnboarding"]
        app.launch()
        return app
    }

    /// Legt eine Reise mit den Standard-Daten des Formulars an (Start = heute,
    /// Ende = heute + 7 Tage → Phase „aktiv“) und oeffnet ihre Detailansicht.
    /// Der erste Hafen bekommt den Starttag, jeder weitere den Folgetag.
    private func oeffneNeueReise(_ app: XCUIApplication, titel: String, haefen: [String]) {
        let reisenTab = app.tabBars.buttons["Reisen"]
        XCTAssertTrue(reisenTab.waitForExistence(timeout: 15))
        reisenTab.tap()

        let addCruise = app.buttons["Neue Reise"]
        XCTAssertTrue(addCruise.waitForExistence(timeout: 15), "Button „Neue Reise“ fehlt")
        addCruise.tap()

        let titleField = app.textFields["Titel"]
        XCTAssertTrue(titleField.waitForExistence(timeout: 10))
        titleField.tap()
        titleField.typeText(titel)

        let shipField = app.textFields["Schiffsname"]
        XCTAssertTrue(shipField.waitForExistence(timeout: 10))
        shipField.tap()
        shipField.typeText("Testschiff")

        for hafen in haefen {
            let addPort = app.buttons["Hafen hinzufügen"].firstMatch
            XCTAssertTrue(scrollUntilHittable(addPort, in: app), "„Hafen hinzufügen“ fehlt")
            addPort.tap()

            let nameField = app.textFields["Hafenname"]
            XCTAssertTrue(nameField.waitForExistence(timeout: 10))
            nameField.tap()
            nameField.typeText(hafen)

            let savePort = app.navigationBars["Hafen hinzufügen"].buttons["Speichern"]
            XCTAssertTrue(savePort.waitForExistence(timeout: 10))
            savePort.tap()
        }

        let saveCruise = app.navigationBars["Neue Kreuzfahrt"].buttons["Speichern"]
        XCTAssertTrue(saveCruise.waitForExistence(timeout: 10))
        saveCruise.tap()

        // Optionaler Erinnerungs-Dialog (A2.1).
        let later = app.buttons["Später"]
        if later.waitForExistence(timeout: 3) { later.tap() }

        let entry = app.staticTexts.matching(NSPredicate(format: "label == %@", titel)).firstMatch
        XCTAssertTrue(entry.waitForExistence(timeout: 15), "Neue Reise nicht in der Liste")
        entry.tap()
    }

    /// Tippt in den „Erinnerung“-Editor. Der Tap landet unterhalb der bestehenden
    /// Zeilen im 140 pt hohen `TextEditor`, der Cursor also am Textende — neuer
    /// Text wird angehaengt statt eingeschoben.
    private func schreibeErinnerung(_ app: XCUIApplication, text: String) {
        let editor = app.textViews["journalEditor.text"]
        XCTAssertTrue(editor.waitForExistence(timeout: 10), "Eintrag-Editor nicht geoeffnet")
        editor.tap()
        editor.typeText(text)
    }

    /// Stimmung „Gut“ waehlen und pruefen, dass die Auswahl auch als
    /// VoiceOver-Trait (`isSelected`) ankommt — nicht nur farblich.
    private func waehleStimmungGut(_ app: XCUIApplication) {
        let form = app.collectionViews.firstMatch
        if form.exists { form.swipeUp() }

        let gut = app.buttons["journalEditor.mood.good"]
        XCTAssertTrue(scrollUntilHittable(gut, in: app), "Stimmungs-Auswahl nicht erreichbar")
        gut.tap()
        XCTAssertTrue(gut.isSelected,
                      "Gewaehlte Stimmung traegt den Auswahl-Trait nicht (A11y)")
    }

    private func speichereEditor(_ app: XCUIApplication) {
        let save = app.buttons["journalEditor.saveButton"]
        XCTAssertTrue(save.waitForExistence(timeout: 10))
        save.tap()
    }

    /// Eintragszeile ueber Identifier **und** Textausschnitt — unabhaengig von der
    /// Reihenfolge im Faden und vom Elementtyp, den SwiftUI fuer das kombinierte
    /// Accessibility-Element waehlt.
    private func eintragsZeile(_ app: XCUIApplication, enthaelt text: String) -> XCUIElement {
        app.descendants(matching: .any)
            .matching(NSPredicate(
                format: "identifier == %@ AND label CONTAINS %@", "journalEntryRow", text
            ))
            .firstMatch
    }

    /// Wartet erst auf die Existenz und scrollt **danach** — andersherum scrollt
    /// der Test an einem noch nicht gerenderten Element vorbei.
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
            // Form/List rendert lazy und scrollt zuverlaessiger ueber die
            // CollectionView; die ScrollView der Detailansicht ueber das Fenster.
            let form = app.collectionViews.firstMatch
            if form.exists && form.isHittable { form.swipeUp() } else { app.swipeUp() }
            swipes += 1
        }
        return element.isHittable
    }
}
