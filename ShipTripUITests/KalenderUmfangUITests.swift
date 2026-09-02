//
//  KalenderUmfangUITests.swift
//  ShipTripUITests
//
//  Der Sync-Umfang steht seit 1.8.7 als zwei Schalter in den
//  Kalender-Einstellungen. Geprueft wird die Ausgangslage einer frischen
//  Installation — Stopps an, Gesamtreise aus — und dass das Opt-in auf die
//  Gesamtreise den Neustart ueberlebt.
//
//  Kein Kalenderzugriff noetig: Die Schalter schreiben nur die Praeferenz,
//  der Sync selbst haengt am Schalter „Reisen mit Kalender synchronisieren".
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
        app.launchArguments += ["-uiTestingCompleteOnboarding"]
        app.launch()

        openCalendarSettings(in: app)

        let itinerary = app.switches[itineraryToggle]
        let trip = app.switches[tripToggle]
        XCTAssertTrue(
            scrollUntilHittable(itinerary, in: app),
            "Der Schalter „Stopps eintragen“ fehlt im Umfangs-Bereich"
        )
        XCTAssertTrue(trip.exists, "Der Schalter „Gesamte Reise als Eintrag“ fehlt")

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
        XCTAssertEqual(
            tripAfterRestart.value as? String,
            "1",
            "Die zugeschaltete Gesamtreise hat den Neustart nicht ueberlebt"
        )

        // Ausgangslage wiederherstellen, damit ein zweiter Lauf auf demselben
        // Simulator wieder von der Auslieferungs-Voreinstellung startet.
        flip(tripAfterRestart)
        XCTAssertTrue(waitForSwitch(tripAfterRestart, toBe: "0"), "Aufraeumen fehlgeschlagen")
        XCUIDevice.shared.press(.home)
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
