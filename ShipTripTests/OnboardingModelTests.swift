//
//  OnboardingModelTests.swift
//  ShipTripTests
//
//  Deckt die beiden Zusagen ab, die der Erststart-Flow (B2) traegt:
//  1. Sichtbarkeit — genau beim ersten Start, danach nur noch auf Anforderung.
//  2. Soft-Ask (B4) — der Systemdialog laeuft ausschliesslich nach aktiver
//     Zustimmung; „Spaeter" loest ihn nie aus.
//
//  Lokale Notifications sind im Unit-Host nicht integrativ testbar; geprueft
//  wird deshalb die Naht, hinter der `NotificationService.requestAuthorization`
//  liegt. Die UI selbst ist nicht Gegenstand dieser Tests (Task B5).
//

import Foundation
import Testing
@testable import ShipTrip

// MARK: - Sichtbarkeit / Persistenz

@Suite("Onboarding – Sichtbarkeit")
struct OnboardingPresentationTests {

    /// Frischer, isolierter Defaults-Bereich pro Test — `UserDefaults.standard`
    /// bleibt unangetastet.
    private func makeDefaults(_ name: String) throws -> (UserDefaults, String) {
        let suiteName = "OnboardingPresentationTests.\(name)"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defaults.removePersistentDomain(forName: suiteName)
        return (defaults, suiteName)
    }

    @Test("Beim ersten Start erscheint das Onboarding")
    func presentsOnFirstLaunch() throws {
        let (defaults, suiteName) = try makeDefaults(#function)
        defer { defaults.removePersistentDomain(forName: suiteName) }

        #expect(OnboardingPresentation.shouldPresent(defaults: defaults))
    }

    @Test("Nach Abschluss erscheint es bei den folgenden Starts nicht mehr")
    func doesNotPresentAfterCompletion() throws {
        let (defaults, suiteName) = try makeDefaults(#function)
        defer { defaults.removePersistentDomain(forName: suiteName) }

        OnboardingPresentation.markCompleted(in: defaults)

        #expect(!OnboardingPresentation.shouldPresent(defaults: defaults))
    }

    @Test("„Intro erneut zeigen“ holt es zurueck")
    func replayPresentsAgain() throws {
        let (defaults, suiteName) = try makeDefaults(#function)
        defer { defaults.removePersistentDomain(forName: suiteName) }

        OnboardingPresentation.markCompleted(in: defaults)
        OnboardingPresentation.requestReplay(in: defaults)

        #expect(OnboardingPresentation.shouldPresent(defaults: defaults))
    }
}

// MARK: - Flow-Zustand und Soft-Ask

@Suite("Onboarding – Flow und Soft-Ask")
@MainActor
struct OnboardingModelTests {

    /// Zaehlt die Aufrufe der System-Abfrage, ohne sie auszuloesen.
    @MainActor
    private final class PermissionSpy {
        private(set) var callCount = 0
        func record() { callCount += 1 }
    }

    private func makeModel(spy: PermissionSpy) -> OnboardingModel {
        OnboardingModel(requestNotificationPermission: { spy.record() })
    }

    // MARK: Navigation

    @Test("Der Flow startet auf Karte 1; deren Einlauf-Staffel ist erst nach start() scharf")
    func startsOnFirstCard() {
        let model = makeModel(spy: PermissionSpy())

        #expect(model.selection == 0)
        // Vor `start()` bewusst noch nicht gesehen — sonst faellt die Flanke
        // aus, an der die Einlauf-Staffel der ersten Karte haengt.
        #expect(!model.hasSeen(0))

        model.start()

        #expect(model.hasSeen(0))
        #expect(!model.hasSeen(1))
    }

    @Test("„Weiter“ blaettert eine Karte vor")
    func advanceMovesForward() {
        let model = makeModel(spy: PermissionSpy())

        model.advance(from: 0)

        #expect(model.selection == 1)
        #expect(model.hasSeen(1))
    }

    @Test("Auf der letzten Karte blaettert „Weiter“ nicht aus dem Flow heraus")
    func advanceStopsAtLastCard() {
        let model = makeModel(spy: PermissionSpy())

        model.select(model.lastIndex)
        model.advance(from: model.lastIndex)

        #expect(model.selection == model.lastIndex)
    }

    @Test("„Ueberspringen“ springt auf die Startentscheidung und fehlt dort")
    func skipJumpsToStartDecision() {
        let model = makeModel(spy: PermissionSpy())

        #expect(model.showsSkipButton(on: 0))
        #expect(model.showsSkipButton(on: 2))

        model.skipToLastCard()

        #expect(model.selection == model.lastIndex)
        #expect(!model.showsSkipButton(on: model.lastIndex))
    }

    @Test("Zurueckblaettern verliert den Zustand nicht")
    func goingBackKeepsSeenState() {
        let model = makeModel(spy: PermissionSpy())

        model.select(3)
        model.select(0)

        #expect(model.selection == 0)
        // Karte 3 bleibt „gesehen“ – die Einlauf-Staffel laeuft kein zweites Mal.
        #expect(model.hasSeen(3))
    }

    // MARK: Soft-Ask (B4)

    @Test("„Spaeter“ loest keinen Systemdialog aus und blaettert weiter")
    func laterNeverRequestsSystemPermission() {
        let spy = PermissionSpy()
        let model = makeModel(spy: spy)
        model.select(2)

        model.skipReminders()

        #expect(spy.callCount == 0)
        #expect(model.selection == 3)
    }

    @Test("Erst die aktive Zustimmung fragt das System genau einmal")
    func enableRequestsSystemPermissionOnce() async {
        let spy = PermissionSpy()
        let model = makeModel(spy: spy)
        model.select(2)

        await model.enableReminders()

        #expect(spy.callCount == 1)
        #expect(model.selection == 3)
    }

    @Test("Ohne Zustimmung erreicht kein Weg durch den Flow den Systemdialog")
    func skippingTheWholeFlowNeverRequestsPermission() {
        let spy = PermissionSpy()
        let model = makeModel(spy: spy)

        model.skipToLastCard()

        #expect(spy.callCount == 0)
    }
}
