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
//  Dazu die drei Integrations-Zusagen aus Gate #3: das Onboarding erscheint nur
//  bei frischer Installation, eine erteilte Berechtigung plant sofort, und ein
//  zweiter Tipp waehrend der laufenden Abfrage laeuft ins Leere.
//

import Foundation
import SwiftData
import SwiftUI
import Testing
@testable import ShipTrip

// Trennt ShipTrips `Port` von gleichnamigen System-Typen.
private typealias CruisePort = ShipTrip.Port

// MARK: - Sichtbarkeit / Persistenz

@Suite("Onboarding – Sichtbarkeit")
@MainActor
struct OnboardingPresentationTests {

    /// Frischer, isolierter Defaults-Bereich pro Test — `UserDefaults.standard`
    /// bleibt unangetastet.
    private func makeDefaults(_ name: String) throws -> (UserDefaults, String) {
        let suiteName = "OnboardingPresentationTests.\(name)"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defaults.removePersistentDomain(forName: suiteName)
        return (defaults, suiteName)
    }

    /// Genau die Naht, die `ShipTripApp` an `fullScreenCover(isPresented:)`
    /// haengt — nur mit einer isolierten `UserDefaults`-Suite unter dem
    /// Schluessel statt `@AppStorage`. `@AppStorage` liest denselben
    /// Schluessel mit demselben Default (`false`).
    private func makeCoverBinding(on defaults: UserDefaults) -> Binding<Bool> {
        OnboardingPresentation.coverBinding(
            hasCompleted: storedFlagBinding(on: defaults),
            isSuppressed: false
        )
    }

    private func storedFlagBinding(on defaults: UserDefaults) -> Binding<Bool> {
        Binding(
            get: { defaults.bool(forKey: OnboardingPresentation.hasCompletedKey) },
            set: { defaults.set($0, forKey: OnboardingPresentation.hasCompletedKey) }
        )
    }

    /// Die komplette Verhaltens-Naht des Starts, in derselben Reihenfolge wie
    /// `ShipTripApp`: Entscheidung treffen → eine Bestandsinstallation still
    /// abhaken → Cover binden. Geprueft wird das Ergebnis am Cover, nicht die
    /// Entscheidungsfunktion fuer sich.
    private func coverIsPresented(
        on defaults: UserDefaults,
        storeIsHealthy: Bool,
        hasExistingCruises: Bool
    ) -> Bool {
        let decision = OnboardingPresentation.startupDecision(
            hasCompletedFlag: defaults.object(
                forKey: OnboardingPresentation.hasCompletedKey
            ) as? Bool,
            storeIsHealthy: storeIsHealthy,
            hasExistingCruises: hasExistingCruises
        )
        if decision == .migrateSilently {
            defaults.set(true, forKey: OnboardingPresentation.hasCompletedKey)
        }
        return OnboardingPresentation.coverBinding(
            hasCompleted: storedFlagBinding(on: defaults),
            isSuppressed: decision == .postpone
        ).wrappedValue
    }

    @Test("Beim ersten Start erscheint das Onboarding")
    func presentsOnFirstLaunch() throws {
        let (defaults, suiteName) = try makeDefaults(#function)
        defer { defaults.removePersistentDomain(forName: suiteName) }

        #expect(makeCoverBinding(on: defaults).wrappedValue)
    }

    @Test("Nach Abschluss erscheint es bei den folgenden Starts nicht mehr")
    func doesNotPresentAfterCompletion() throws {
        let (defaults, suiteName) = try makeDefaults(#function)
        defer { defaults.removePersistentDomain(forName: suiteName) }

        // Das Schliessen des Covers ist der Abschluss — es gibt keinen zweiten Weg.
        makeCoverBinding(on: defaults).wrappedValue = false

        #expect(defaults.bool(forKey: OnboardingPresentation.hasCompletedKey))
        #expect(!makeCoverBinding(on: defaults).wrappedValue)
    }

    @Test("„Intro erneut zeigen“ holt es zurueck")
    func replayPresentsAgain() throws {
        let (defaults, suiteName) = try makeDefaults(#function)
        defer { defaults.removePersistentDomain(forName: suiteName) }

        makeCoverBinding(on: defaults).wrappedValue = false
        // Was der Knopf in den Einstellungen ruft (SettingsView).
        OnboardingPresentation.requestReplay(in: defaults)

        #expect(makeCoverBinding(on: defaults).wrappedValue)
    }

    // MARK: Frische Installation vs. Update (Gate #3, F2)

    @Test("Eine frische Installation sieht das Onboarding")
    func freshInstallSeesOnboarding() throws {
        let (defaults, suiteName) = try makeDefaults(#function)
        defer { defaults.removePersistentDomain(forName: suiteName) }

        #expect(coverIsPresented(on: defaults, storeIsHealthy: true, hasExistingCruises: false))
    }

    @Test("Ein Update von 1.7.x sieht es nicht — der Schalter wird still nachgezogen")
    func upgradeWithExistingDataSkipsOnboarding() throws {
        let (defaults, suiteName) = try makeDefaults(#function)
        defer { defaults.removePersistentDomain(forName: suiteName) }

        // Bestandsinstallation: Schluessel fehlt (gab es in 1.7.x nicht),
        // Reisen sind aber vorhanden.
        #expect(!coverIsPresented(on: defaults, storeIsHealthy: true, hasExistingCruises: true))
        #expect(defaults.bool(forKey: OnboardingPresentation.hasCompletedKey))
    }

    @Test("„Intro erneut zeigen“ ueberlebt vorhandene Reisen")
    func replayIsNotMistakenForAnUpgrade() throws {
        let (defaults, suiteName) = try makeDefaults(#function)
        defer { defaults.removePersistentDomain(forName: suiteName) }

        makeCoverBinding(on: defaults).wrappedValue = false
        OnboardingPresentation.requestReplay(in: defaults)

        // Der Schalter steht auf `false` statt zu fehlen — das ist ein
        // angefordertes Wiedersehen, keine Bestandsinstallation.
        #expect(coverIsPresented(on: defaults, storeIsHealthy: true, hasExistingCruises: true))
    }

    // MARK: In-Memory-Fallback (Gate #3, F3)

    @Test("Ohne gesunden Store bleibt das Onboarding weg — und ungezeigt bestehen")
    func temporaryStorePostponesOnboarding() throws {
        let (defaults, suiteName) = try makeDefaults(#function)
        defer { defaults.removePersistentDomain(forName: suiteName) }

        // Die Datenverlust-Warnung hat Vorrang; das Cover taucht nicht daneben auf.
        #expect(!coverIsPresented(on: defaults, storeIsHealthy: false, hasExistingCruises: false))
        // Und der Erststart gilt nicht als erledigt.
        #expect(defaults.object(forKey: OnboardingPresentation.hasCompletedKey) == nil)
    }
}

// MARK: - Flow-Zustand und Soft-Ask

@Suite("Onboarding – Flow und Soft-Ask")
@MainActor
struct OnboardingModelTests {

    /// Zaehlt System-Abfrage und Erinnerungs-Abgleich, ohne beides auszuloesen.
    @MainActor
    private final class PermissionSpy {
        private(set) var callCount = 0
        private(set) var reconcileCount = 0
        /// Antwort, die der Nutzer im System-Dialog gaebe.
        var granted = false

        func record() -> Bool {
            callCount += 1
            return granted
        }

        func recordReconcile() { reconcileCount += 1 }
    }

    /// Haelt die System-Abfrage an, bis der Test sie freigibt — nur so laesst
    /// sich ein zweiter Tipp *waehrend* der laufenden Abfrage nachstellen.
    @MainActor
    private final class GatedPermissionSpy {
        private(set) var callCount = 0
        private var continuation: CheckedContinuation<Bool, Never>?

        /// Nur der **erste** Aufruf haengt; jeder weitere kehrt sofort zurueck.
        /// Ein fehlender In-Flight-Guard wird damit zu einem roten Assert
        /// (`callCount == 2`) statt zu einem haengenden Test.
        func request() async -> Bool {
            callCount += 1
            guard continuation == nil else { return false }
            return await withCheckedContinuation { continuation = $0 }
        }

        func resume(granted: Bool) {
            continuation?.resume(returning: granted)
            continuation = nil
        }
    }

    private func makeModel(spy: PermissionSpy) -> OnboardingModel {
        OnboardingModel(
            requestNotificationPermission: { spy.record() },
            reconcileReminders: { _ in spy.recordReconcile() }
        )
    }

    /// Der Kontext, den der Flow aus der Umgebung erbt. Die Abgleich-Naht ist
    /// in allen Tests gestubbt — der Store bleibt leer.
    private func makeContext() throws -> ModelContext {
        let schema = Schema([Cruise.self, CruisePort.self, Expense.self, Deal.self, Photo.self])
        let container = try ModelContainer(
            for: schema,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        return ModelContext(container)
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
    func enableRequestsSystemPermissionOnce() async throws {
        let spy = PermissionSpy()
        let model = makeModel(spy: spy)
        model.select(2)

        await model.enableReminders(in: try makeContext())

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

    // MARK: Abgleich nach erteilter Berechtigung (Gate #3, F1)

    @Test("Erteilte Berechtigung plant die Erinnerungen sofort, nicht erst beim naechsten Start")
    func grantedPermissionReconcilesImmediately() async throws {
        let spy = PermissionSpy()
        spy.granted = true
        let model = makeModel(spy: spy)
        model.select(2)

        await model.enableReminders(in: try makeContext())

        #expect(spy.reconcileCount == 1)
        #expect(model.selection == 3)
    }

    @Test("Verweigerte Berechtigung plant nichts — und blockiert den Flow trotzdem nicht")
    func deniedPermissionSkipsReconcile() async throws {
        let spy = PermissionSpy()
        spy.granted = false
        let model = makeModel(spy: spy)
        model.select(2)

        await model.enableReminders(in: try makeContext())

        #expect(spy.reconcileCount == 0)
        #expect(model.selection == 3)
    }

    // MARK: In-Flight-Guard (Gate #3, F4)

    @Test("Ein zweiter Tipp waehrend der laufenden Abfrage fordert keinen zweiten Dialog an")
    func secondTapDuringRequestIsIgnored() async throws {
        let spy = GatedPermissionSpy()
        let counts = PermissionSpy()
        let context = try makeContext()
        let model = OnboardingModel(
            requestNotificationPermission: { await spy.request() },
            reconcileReminders: { _ in counts.recordReconcile() }
        )
        model.select(2)

        let firstTap = Task { await model.enableReminders(in: context) }
        // Die erste Abfrage haengt jetzt in der Naht.
        for _ in 0 ..< 100 where !model.isRequestingPermission { await Task.yield() }
        try #require(model.isRequestingPermission)

        await model.enableReminders(in: context)
        // Und „Spaeter" blaettert waehrenddessen ebenfalls nicht weiter.
        model.skipReminders()

        #expect(spy.callCount == 1)
        #expect(model.selection == 2)

        spy.resume(granted: true)
        await firstTap.value

        #expect(spy.callCount == 1)
        #expect(counts.reconcileCount == 1)
        #expect(model.selection == 3)
        #expect(!model.isRequestingPermission)
    }
}
