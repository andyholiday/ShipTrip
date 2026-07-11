//
//  EnglishLocalizationSmokeUITests.swift
//  ShipTripUITests
//
//  UI-Smoke-Test für S2.1b-2 (Audit H6, Teil 3):
//  Startet die App unter Systemsprache Englisch und geht die fünf Kern-Screens durch
//  (Reisen, Karte, Wunschreisen, Bilanz, Mehr). Pro Screen wird geprüft, dass 2-3 bekannte
//  deutsche Marker-Strings NICHT erscheinen, und dass mindestens ein erwarteter EN-String
//  existiert (sonst würde der Test nur ins Leere prüfen).
//
//  Markerauswahl: nur Strings, die aktuell im Katalog (Localizable.xcstrings) eine
//  abweichende EN-Übersetzung besitzen – Strings ohne EN-Eintrag taugen laut Vorgabe nicht
//  als Marker. Die Tab-/Titel-Strings "Wunschreisen" (DealsView → NavigationTitle "Deals")
//  und "Bilanz" (StatsView → NavigationTitle "Stats") waren anfangs NICHT im Katalog und sind
//  inzwischen nachgetragen; die entsprechenden NavigationTitle-Marker sind unten mit ergänzt.
//  Die Tabs werden trotzdem weiterhin per Index statt per Label-Text angesteuert (nicht mehr
//  wegen fehlender Katalog-Einträge, sondern weil die eigentlichen Tab-Bar-Beschriftungen
//  ohnehin nicht Testgegenstand sind – geprüft wird der jeweilige Screen-Inhalt).
//
//  Der frühere Code-Bug in StatsView.swift (StatCard-Titel liefen über Text(_ content: String)
//  mit einem einfachen String-Parameter statt LocalizedStringKey und wurden dadurch nie
//  lokalisiert) ist ebenfalls gefixt (String(localized:)) – der StatCard-Marker "Häfen"/"Ports"
//  ist unten mit ergänzt.
//

import XCTest

@MainActor
final class EnglishLocalizationSmokeUITests: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = false
        // Siehe AusflugLoeschenUITests: der Simulator kann von einem vorherigen Lauf noch im
        // Landscape-Zustand sein, was Element-Queries außerhalb des sichtbaren Bereichs
        // verfälscht.
        XCUIDevice.shared.orientation = .portrait
    }

    // MARK: - Tab-Reihenfolge (siehe MainTabView.swift: TabView-Deklarationsreihenfolge/-tags)

    private enum Tab: Int {
        case reisen = 0
        case karte = 1
        case wunschreisen = 2
        case bilanz = 3
        case mehr = 4
    }

    private func selectTab(_ tab: Tab, in app: XCUIApplication) {
        app.tabBars.buttons.element(boundBy: tab.rawValue).tap()
    }

    // MARK: - Smoke-Test

    func testEnglischeLokalisierungZeigtKeineBekanntenDeutschenMarkerStrings() throws {
        let app = XCUIApplication()
        app.launchArguments += [
            "-AppleLanguages", "(en)",
            "-AppleLocale", "en_US",
            "-uiTestingResetAndLoadDemoData"
        ]
        app.launch()

        let reisenTab = app.tabBars.buttons.element(boundBy: Tab.reisen.rawValue)
        XCTAssertTrue(reisenTab.waitForExistence(timeout: 10), "Tab-Leiste erscheint nicht nach EN-Start")

        // MARK: Reisen-Liste (Tab 0)
        // "Meine Reisen" (Bildschirmtitel) und "Neue Reise" (Accessibility-Label des
        // +-Buttons) sind beide via String(localized:) an den Katalog angebunden und werden
        // unabhängig von Demo-Daten immer gerendert. "Reiselogbuch" wird bewusst NICHT
        // genutzt: der Sektionstitel trägt `.textCase(.uppercase)`, was die tatsächlich
        // gerenderte/zugängliche Beschriftung case-transformiert.
        XCTAssertTrue(app.staticTexts["My Cruises"].waitForExistence(timeout: 10), "EN-Positivprobe 'My Cruises' fehlt")
        XCTAssertTrue(app.buttons["New Trip"].exists, "EN-Positivprobe 'New Trip' fehlt")
        XCTAssertFalse(app.staticTexts["Meine Reisen"].exists, "DE-Marker 'Meine Reisen' sichtbar trotz EN-Locale")
        XCTAssertFalse(app.buttons["Neue Reise"].exists, "DE-Marker 'Neue Reise' sichtbar trotz EN-Locale")

        // MARK: Karte (Tab 1)
        // "Karte" (eigener Screen-Header, die NavigationBar ist hier ausgeblendet) und
        // "Alle Reisen" (Routen-Unterzeile im Default-Zustand: alle drei Demo-Kreuzfahrten
        // sind sichtbar, keine Einzelauswahl aktiv) sind beide über String(localized:)
        // angebunden.
        selectTab(.karte, in: app)
        XCTAssertTrue(app.staticTexts["Map"].waitForExistence(timeout: 10), "EN-Positivprobe 'Map' fehlt")
        XCTAssertTrue(app.staticTexts["All Trips"].waitForExistence(timeout: 5), "EN-Positivprobe 'All Trips' fehlt")
        XCTAssertFalse(app.staticTexts["Karte"].exists, "DE-Marker 'Karte' sichtbar trotz EN-Locale")
        XCTAssertFalse(app.staticTexts["Alle Reisen"].exists, "DE-Marker 'Alle Reisen' sichtbar trotz EN-Locale")

        // MARK: Wunschreisen/Deals (Tab 2)
        // "Deals" ist der echte NavigationBar-Titel (`.navigationTitle`, DE "Wunschreisen" →
        // EN "Deals"), deshalb Zugriff über `navigationBars` wie beim Settings-Tab. "Add Entry"
        // (Accessibility-Label des Toolbar-+-Buttons, datenunabhängig) und "Best Option"
        // (Rabatt-Badge auf der Hero-Karte – beide Demo-Angebote haben einen Originalpreis über
        // dem aktuellen Preis, das Badge ist also garantiert sichtbar) ergänzen den Screen-Inhalt.
        selectTab(.wunschreisen, in: app)
        XCTAssertTrue(app.navigationBars["Deals"].waitForExistence(timeout: 10), "EN-Positivprobe 'Deals' fehlt")
        XCTAssertTrue(app.buttons["Add Entry"].waitForExistence(timeout: 5), "EN-Positivprobe 'Add Entry' fehlt")
        XCTAssertTrue(app.staticTexts["Best Option"].waitForExistence(timeout: 5), "EN-Positivprobe 'Best Option' fehlt")
        XCTAssertFalse(app.navigationBars["Wunschreisen"].exists, "DE-Marker 'Wunschreisen' sichtbar trotz EN-Locale")
        XCTAssertFalse(app.buttons["Eintrag hinzufügen"].exists, "DE-Marker 'Eintrag hinzufügen' sichtbar trotz EN-Locale")
        XCTAssertFalse(app.staticTexts["Beste Option"].exists, "DE-Marker 'Beste Option' sichtbar trotz EN-Locale")

        // MARK: Bilanz/Stats (Tab 3)
        // "Stats" ist der echte NavigationBar-Titel (`.navigationTitle`, DE "Bilanz" →
        // EN "Stats"), deshalb Zugriff über `navigationBars`. "Total Memories" (Hero-Kachel-
        // Titel, String(localized:)) sowie "Cruises per Year" und "Top Shipping Lines" (beide
        // direkt als Text(_:)-Literal lokalisiert) sind unabhängig von Demo-Daten sichtbar (die
        // Sektionen rendern immer einen Titel, auch bei leeren/keinen Werten). Zusätzlich der
        // StatCard-Marker "Häfen"/"Ports" (Häfen-Kachel im Quick-Stats-Grid) – deckt den
        // ehemaligen verbatim-Text-Bug ab, der jetzt über String(localized:) läuft.
        selectTab(.bilanz, in: app)
        XCTAssertTrue(app.navigationBars["Stats"].waitForExistence(timeout: 10), "EN-Positivprobe 'Stats' fehlt")
        XCTAssertTrue(app.staticTexts["Total Memories"].waitForExistence(timeout: 5), "EN-Positivprobe 'Total Memories' fehlt")
        XCTAssertTrue(app.staticTexts["Cruises per Year"].waitForExistence(timeout: 5), "EN-Positivprobe 'Cruises per Year' fehlt")
        XCTAssertTrue(app.staticTexts["Top Shipping Lines"].waitForExistence(timeout: 5), "EN-Positivprobe 'Top Shipping Lines' fehlt")
        XCTAssertTrue(app.staticTexts["Ports"].waitForExistence(timeout: 5), "EN-Positivprobe 'Ports' fehlt")
        XCTAssertFalse(app.navigationBars["Bilanz"].exists, "DE-Marker 'Bilanz' sichtbar trotz EN-Locale")
        XCTAssertFalse(app.staticTexts["Gesamterinnerung"].exists, "DE-Marker 'Gesamterinnerung' sichtbar trotz EN-Locale")
        XCTAssertFalse(app.staticTexts["Kreuzfahrten pro Jahr"].exists, "DE-Marker 'Kreuzfahrten pro Jahr' sichtbar trotz EN-Locale")
        XCTAssertFalse(app.staticTexts["Top Reedereien"].exists, "DE-Marker 'Top Reedereien' sichtbar trotz EN-Locale")
        XCTAssertFalse(app.staticTexts["Häfen"].exists, "DE-Marker 'Häfen' sichtbar trotz EN-Locale")

        // MARK: Mehr/Settings (Tab 4)
        // "Settings" ist der echte NavigationBar-Titel (`.navigationTitle`), deshalb Zugriff
        // über `navigationBars` statt `staticTexts` (Muster aus AusflugLoeschenUITests).
        // "Appearance" (Sektionstitel) und "Color Scheme" (Picker-Label) liegen beide oberhalb
        // der Scroll-Kante, kein Swipe nötig.
        selectTab(.mehr, in: app)
        XCTAssertTrue(app.navigationBars["Settings"].waitForExistence(timeout: 10), "EN-Positivprobe 'Settings' fehlt")
        XCTAssertTrue(app.staticTexts["Appearance"].exists, "EN-Positivprobe 'Appearance' fehlt")
        XCTAssertTrue(app.staticTexts["Color Scheme"].exists, "EN-Positivprobe 'Color Scheme' fehlt")
        XCTAssertFalse(app.navigationBars["Einstellungen"].exists, "DE-Marker 'Einstellungen' sichtbar trotz EN-Locale")
        XCTAssertFalse(app.staticTexts["Erscheinungsbild"].exists, "DE-Marker 'Erscheinungsbild' sichtbar trotz EN-Locale")
        XCTAssertFalse(app.staticTexts["Farbschema"].exists, "DE-Marker 'Farbschema' sichtbar trotz EN-Locale")
    }
}
