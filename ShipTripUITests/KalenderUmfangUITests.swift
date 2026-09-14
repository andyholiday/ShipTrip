//
//  KalenderUmfangUITests.swift
//  ShipTripUITests
//
//  Der Sync-Umfang steht seit 1.8.7 als zwei Schalter in den
//  Kalender-Einstellungen. Geprueft wird die Ausgangslage einer frischen
//  Installation — Stopps an, Gesamtreise aus — und dass das Opt-in auf die
//  Gesamtreise den Neustart ueberlebt.
//
//  Voraussetzung ist voller Kalenderzugriff (im Test-Kanon per
//  `simctl privacy grant calendar com.andre.ShipTrip` gesetzt): Ohne ihn
//  bleibt die Bestands-Migration offen und die Umfangs-Schalter gesperrt.
//  Der erste Start setzt Umfang und Migrations-Merker zurueck, damit der Test
//  nicht vom Restzustand des Simulators abhaengt.
//

import XCTest

@MainActor
final class KalenderUmfangUITests: XCTestCase {

    private let itineraryToggle = "calendarSync.itineraryToggle"
    private let tripToggle = "calendarSync.tripToggle"

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    func testGesamtreiseIstOptInUndUeberlebtDenNeustart() throws {
        let app = XCUIApplication()
        app.launchArguments += [
            "-uiTestingCompleteOnboarding",
            // Auslieferungszustand des Umfangs erzwingen: gespeicherte Wahl
            // und Migrations-Merker weg. Nur beim ersten Start — der zweite
            // prueft ja gerade, dass die Wahl den Neustart ueberlebt.
            "-uiTestingResetCalendarSyncScope"
        ]
        app.launch()

        openCalendarSettings(in: app)

        let itinerary = app.switches[itineraryToggle]
        let trip = app.switches[tripToggle]
        XCTAssertTrue(
            scrollUntilHittable(itinerary, in: app),
            "Der Schalter „Stopps eintragen“ fehlt im Umfangs-Bereich"
        )
        XCTAssertTrue(trip.exists, "Der Schalter „Gesamte Reise als Eintrag“ fehlt")
        XCTAssertTrue(
            waitUntilEnabled(trip),
            "Die Umfangs-Schalter bleiben gesperrt — die Bestands-Migration hat nicht entschieden"
        )

        // Ausgangslage: nur die Stopps, kein Ganzreise-Termin.
        XCTAssertEqual(itinerary.value as? String, "1", "Stopps sind nicht voreingestellt")
        XCTAssertEqual(trip.value as? String, "0", "Die Gesamtreise ist nicht Opt-in")

        flip(trip)
        XCTAssertTrue(
            waitForSwitch(trip, toBe: "1"),
            "Die Gesamtreise laesst sich nicht zuschalten (Stopps: \(itinerary.value as? String ?? "?"))"
        )

        // Erst in den Hintergrund, dann beenden: die Suspendierung schreibt die
        // UserDefaults auf die Platte, bevor der Prozess wegfaellt.
        XCUIDevice.shared.press(.home)
        app.terminate()

        let relaunched = XCUIApplication()
        relaunched.launchArguments += ["-uiTestingCompleteOnboarding"]
        relaunched.launch()

        openCalendarSettings(in: relaunched)
        let tripAfterRestart = relaunched.switches[tripToggle]
        XCTAssertTrue(
            scrollUntilHittable(tripAfterRestart, in: relaunched),
            "Der Umfangs-Bereich fehlt nach dem Neustart"
        )
        XCTAssertTrue(
            waitUntilEnabled(tripAfterRestart),
            "Die Umfangs-Schalter bleiben nach dem Neustart gesperrt"
        )
        XCTAssertEqual(
            tripAfterRestart.value as? String,
            "1",
            "Die zugeschaltete Gesamtreise hat den Neustart nicht ueberlebt"
        )
    }

    // MARK: - Helper

    /// „Mehr" → „Kalender" (gleicher Weg wie `AppResetUITests`). Die Zeile
    /// traegt den Sync-Status im Label, deshalb ueber das Praefix suchen.
    private func openCalendarSettings(in app: XCUIApplication) {
        let moreTab = app.tabBars.buttons["Mehr"]
        XCTAssertTrue(moreTab.waitForExistence(timeout: 15), "Tab „Mehr“ nicht gefunden")
        moreTab.tap()

        let calendarLink = app.buttons
            .matching(NSPredicate(format: "label BEGINSWITH %@", "Kalender"))
            .firstMatch
        XCTAssertTrue(scrollUntilHittable(calendarLink, in: app), "„Kalender“ nicht gefunden")
        calendarLink.tap()

        XCTAssertTrue(
            app.navigationBars["Kalender"].waitForExistence(timeout: 10),
            "Die Kalender-Einstellungen stehen nicht offen"
        )
    }

    /// Der Switch meldet die ganze Formularzeile als Rahmen; ein Tipp auf deren
    /// Mitte landet auf dem Label und schaltet nichts. Deshalb gezielt auf den
    /// Schalter am rechten Rand.
    private func flip(_ element: XCUIElement) {
        element.coordinate(withNormalizedOffset: CGVector(dx: 0.9, dy: 0.5)).tap()
    }

    /// Die Umfangs-Schalter sind gesperrt, bis die Bestands-Migration
    /// entschieden hat. Die laeuft beim Erscheinen der Einstellungen — also
    /// auf `isEnabled` warten statt zu sleepen.
    private func waitUntilEnabled(_ element: XCUIElement) -> Bool {
        let enabled = expectation(
            for: NSPredicate(format: "isEnabled == true"),
            evaluatedWith: element
        )
        return XCTWaiter.wait(for: [enabled], timeout: 10) == .completed
    }

    /// Kein `sleep`: SwiftUI schreibt die Praeferenz und rendert den Schalter
    /// erst im naechsten Frame — deshalb auf den Wert warten statt ihn sofort
    /// abzulesen.
    private func waitForSwitch(_ element: XCUIElement, toBe value: String) -> Bool {
        let reached = expectation(
            for: NSPredicate(format: "value == %@", value),
            evaluatedWith: element
        )
        return XCTWaiter.wait(for: [reached], timeout: 5) == .completed
    }

    /// Die Einstellungen sind laenger als ein Bildschirm. Statt fester
    /// Wischzahlen: wischen, bis das Element antippbar ist.
    private func scrollUntilHittable(
        _ element: XCUIElement,
        in app: XCUIApplication,
        maxSwipes: Int = 6
    ) -> Bool {
        let list = app.collectionViews.firstMatch
        for _ in 0 ... maxSwipes {
            if element.exists && element.isHittable { return true }
            if list.exists { list.swipeUp() } else { app.swipeUp() }
        }
        return element.exists && element.isHittable
    }
}
