//
//  NotificationReconcileTests.swift
//  ShipTripTests
//
//  Deckt den Fix gegen mehrfache Push-Erinnerungen ab: stabile Identifier aus `Cruise.id`
//  plus den idempotenten Abgleich beim App-Start. Der Abgleich läuft über den
//  `NotificationScheduling`-Seam und damit ohne echtes `UNUserNotificationCenter` (das im
//  Unit-Test-Host ohnehin keine Pending Requests persistiert).
//

import Testing
import Foundation
import SwiftData
@testable import ShipTrip

// MARK: - Test-Double

/// Test-Double für das Notification-Center. Actor, weil der Abgleich asynchron zugreift.
private actor FakeNotificationCenter: NotificationScheduling {
    /// Protokollierter Aufruf – für Assertions über die Reihenfolge.
    enum Call: Equatable {
        case add(String)
        case remove([String])
    }

    struct AddFailure: Error {}

    private var pending: Set<String>
    private let failsAdd: Bool
    private var calls: [Call] = []

    init(pending: Set<String> = [], failsAdd: Bool = false) {
        self.pending = pending
        self.failsAdd = failsAdd
    }

    func pendingIdentifiers() async -> [String] {
        pending.sorted()
    }

    func add(_ request: ReminderRequest) async throws {
        calls.append(.add(request.identifier))
        if failsAdd { throw AddFailure() }
        pending.insert(request.identifier)
    }

    func removePending(identifiers: [String]) async {
        calls.append(.remove(identifiers))
        pending.subtract(identifiers)
    }

    /// Aktueller Bestand für Assertions.
    func snapshot() -> Set<String> {
        pending
    }

    /// Protokollierte Aufrufe für Assertions.
    func callLog() -> [Call] {
        calls
    }
}

// MARK: - Suite

@Suite("Erinnerungs-Abgleich")
struct NotificationReconcileTests {

    private let allEnabled = ReminderSettings(notifyBefore: true, notifyOnDay: true, daysBefore: 7)

    private func input(startsInDays: Int, now: Date) -> CruiseReminderInput {
        CruiseReminderInput(
            key: "A",
            title: "Nordland",
            startDate: now.addingTimeInterval(Double(startsInDays) * 86_400)
        )
    }

    private func makeInMemoryContainer() throws -> ModelContainer {
        let schema = Schema([Cruise.self, ShipTrip.Port.self, Expense.self, Deal.self, Photo.self])
        return try ModelContainer(
            for: schema,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
    }

    // MARK: Repro (vor dem Fix rot)

    /// Repro für „3 Pushes auf einmal": der Identifier wurde aus `persistentModelID` gebildet.
    /// Diese ID ist vor dem Save temporär und danach permanent, also erzeugte jedes Speichern
    /// eine zusätzliche Pending Request. Nur ein Schlüssel aus der stabilen `Cruise.id` erfüllt
    /// beide Zusagen: über den Save hinweg gleich UND aus der CloudKit-stabilen UUID abgeleitet.
    @Test("Repro: Identifier stammt aus der stabilen Cruise.id und überlebt den Save")
    @MainActor
    func identifierIsStableAcrossSave() throws {
        let container = try makeInMemoryContainer()
        let context = ModelContext(container)
        let cruise = Cruise(
            title: "Nordland",
            startDate: Date().addingTimeInterval(30 * 86_400),
            endDate: Date().addingTimeInterval(37 * 86_400),
            shippingLine: "AIDA Cruises",
            ship: "AIDAstella"
        )
        context.insert(cruise)

        let beforeSave = ReminderIdentifier.make(
            cruiseKey: ReminderIdentifier.key(for: cruise),
            kind: .before
        )
        try context.save()
        let afterSave = ReminderIdentifier.make(
            cruiseKey: ReminderIdentifier.key(for: cruise),
            kind: .before
        )

        #expect(beforeSave == afterSave)
        #expect(afterSave == "reminder.\(cruise.id.uuidString).before")
    }

    // MARK: Planner

    /// Replace-Semantik: das Soll wird immer komplett geschrieben – `add` ersetzt Requests mit
    /// gleichem Identifier und überschreibt damit auch veraltete Trigger (geändertes Startdatum
    /// oder `daysBefore` von einem Zweitgerät). Idempotent heißt hier: identische Adds, keine
    /// Removes – nicht „gar keine Aktion".
    @Test("Abgleich ist idempotent: passender Bestand wird unverändert erneut geschrieben")
    func planIsIdempotent() {
        let now = Date()
        let desired = ReminderPlanner.desiredRequests(
            for: [input(startsInDays: 30, now: now)],
            settings: allEnabled,
            now: now
        )

        let plan = ReminderPlanner.plan(existing: Set(desired.keys), desired: desired)

        #expect(desired.count == 2)
        #expect(plan.remove.isEmpty)
        #expect(plan.add == desired.values.sorted { $0.identifier < $1.identifier })
    }

    @Test("Legacy-Requests werden entfernt, fremde Identifier bleiben unangetastet")
    func planRemovesLegacyAndKeepsForeignIdentifiers() {
        let now = Date()
        let desired = ReminderPlanner.desiredRequests(
            for: [input(startsInDays: 30, now: now)],
            settings: allEnabled,
            now: now
        )
        let existing: Set<String> = ["cruise-p1-7days", "cruise-p1-departure", "fremde-request"]

        let plan = ReminderPlanner.plan(existing: existing, desired: desired)

        #expect(plan.remove == ["cruise-p1-7days", "cruise-p1-departure"])
        #expect(Set(plan.add.map(\.identifier)) == Set(desired.keys))
    }

    @Test("Vergangene Auslösezeitpunkte werden nicht geplant")
    func pastFireDatesAreSkipped() {
        let now = Date()
        // Reise startet in 3 Tagen – die Erinnerung „7 Tage vorher" liegt bereits hinter uns.
        let cruise = input(startsInDays: 3, now: now)

        let desired = ReminderPlanner.desiredRequests(
            for: [cruise],
            settings: allEnabled,
            now: now
        )

        #expect(desired[ReminderIdentifier.make(cruiseKey: cruise.key, kind: .before)] == nil)
        #expect(desired[ReminderIdentifier.make(cruiseKey: cruise.key, kind: .departure)] != nil)
    }

    // MARK: Reconcile über den Seam

    @Test("Deaktivierte Erinnerungen: es wird nur entfernt, nichts neu geplant")
    func disabledRemindersOnlyRemove() async {
        let now = Date()
        let center = FakeNotificationCenter(
            pending: ["reminder.A.before", "cruise-p1-departure", "fremde-request"]
        )

        await NotificationReconciler.reconcile(
            cruises: [input(startsInDays: 30, now: now)],
            settings: ReminderSettings(notifyBefore: false, notifyOnDay: false, daysBefore: 7),
            isAuthorized: true,
            now: now,
            center: center
        )

        let remaining = await center.snapshot()
        #expect(remaining == ["fremde-request"])
    }

    @Test("Abgleich plant Fehlendes und räumt Legacy-Requests ab")
    func reconcileAddsMissingAndRemovesLegacy() async {
        let now = Date()
        let cruise = input(startsInDays: 30, now: now)
        let center = FakeNotificationCenter(pending: ["cruise-p1-7days"])

        await NotificationReconciler.reconcile(
            cruises: [cruise],
            settings: allEnabled,
            isAuthorized: true,
            now: now,
            center: center
        )

        let expected = Set(
            ReminderKind.allCases.map { ReminderIdentifier.make(cruiseKey: cruise.key, kind: $0) }
        )
        let remaining = await center.snapshot()
        #expect(remaining == expected)
    }

    /// Create-before-delete: scheitern die Adds, darf der bestehende Bestand nicht schon
    /// abgeräumt sein. Der Fake protokolliert die Aufrufe; alle Adds liegen vor dem Remove.
    @Test("Erst anlegen, dann entfernen – auch wenn ein Add fehlschlägt")
    func addsRunBeforeRemovals() async {
        let now = Date()
        let cruise = input(startsInDays: 30, now: now)
        let center = FakeNotificationCenter(pending: ["cruise-p1-7days"], failsAdd: true)

        await NotificationReconciler.reconcile(
            cruises: [cruise],
            settings: allEnabled,
            isAuthorized: true,
            now: now,
            center: center
        )

        let calls = await center.callLog()
        #expect(calls == [
            .add(ReminderIdentifier.make(cruiseKey: cruise.key, kind: .before)),
            .add(ReminderIdentifier.make(cruiseKey: cruise.key, kind: .departure)),
            .remove(["cruise-p1-7days"])
        ])
    }
}
