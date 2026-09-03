//
//  WidgetSnapshotPublisherTests.swift
//  ShipTripTests
//
//  Belegt ZIEL K3 fuer den Publisher (Taskplan 1.9.0, T3): der zentrale
//  `didSave`-Hook feuert ueberhaupt, jeder Mutationspfad landet im Snapshot,
//  Demo-Reisen nie, ein Sturm von Aufrufen ergibt genau einen Reload und ein
//  fehlschlagender Schreibvorgang bleibt folgenlos fuer die App.
//
//  Alle Tests laufen auf dem MainActor mit In-Memory-Container und einem
//  eigenen temporaeren Verzeichnis als App-Group-Ersatz.
//

import Testing
import Foundation
import SwiftData
@testable import ShipTrip

private typealias CruisePort = ShipTrip.Port

// MARK: - Testhilfen

/// Zaehlt Aufrufe aus beliebigen Threads (Reload-Closure, Notification-Block).
/// `@unchecked Sendable` ist hier vertretbar: der gesamte Zustand liegt hinter
/// dem `NSLock`, es gibt keinen anderen Zugriff.
private final class CallCounter: @unchecked Sendable {
    private let lock = NSLock()
    private var calls = 0

    func record() {
        lock.lock()
        calls += 1
        lock.unlock()
    }

    var count: Int {
        lock.lock()
        defer { lock.unlock() }
        return calls
    }
}

@MainActor
private func makeContainer() throws -> ModelContainer {
    let schema = Schema([
        Cruise.self, CruisePort.self, Expense.self, Deal.self, Photo.self,
        JournalEntry.self, CustomShippingLine.self, CustomShip.self, HiddenCatalogItem.self
    ])
    return try ModelContainer(
        for: schema,
        configurations: ModelConfiguration(
            schema: schema, isStoredInMemoryOnly: true, cloudKitDatabase: .none
        )
    )
}

/// Frisches, leeres Verzeichnis je Test — der Store legt es selbst an.
private func makeStore() -> WidgetSnapshotStore {
    WidgetSnapshotStore(
        containerURL: FileManager.default.temporaryDirectory
            .appendingPathComponent("widget-publisher-\(UUID().uuidString)", isDirectory: true)
    )
}

private func day(_ offset: Int) -> Date {
    Date().addingTimeInterval(Double(offset) * 86_400)
}

@discardableResult
@MainActor
private func insertCruise(
    _ title: String,
    start: Date,
    end: Date,
    isDemo: Bool = false,
    stops: Int = 0,
    in context: ModelContext
) -> Cruise {
    let cruise = Cruise(
        title: title, startDate: start, endDate: end, shippingLine: "AIDA", ship: "AIDAsol"
    )
    cruise.isDemo = isDemo
    context.insert(cruise)
    for index in 0..<stops {
        let port = CruisePort(
            name: "Hafen \(index)", country: "Norwegen", latitude: 0, longitude: 0
        )
        port.sortOrder = index
        port.arrival = start.addingTimeInterval(Double(index) * 86_400)
        port.departure = port.arrival.addingTimeInterval(28_800)
        port.cruise = cruise
        context.insert(port)
    }
    return cruise
}

/// Reisetitel im geschriebenen Snapshot; leer, wenn es keine lesbare Datei gibt.
private func titles(in store: WidgetSnapshotStore) -> [String] {
    guard case .snapshot(let snapshot) = store.load() else { return [] }
    return snapshot.cruises.map(\.title)
}

// MARK: - Suite

@Suite("WidgetSnapshotPublisher")
@MainActor
struct WidgetSnapshotPublisherTests {

    /// Traegt der zentrale Hook? Feuert `didSave` beim In-Memory-Container
    /// nicht, braucht T3 die expliziten Aufrufe in den Mutationspfaden.
    @Test("ModelContext.didSave feuert auch beim In-Memory-Container")
    func didSaveNotificationFiresForInMemoryContainer() async throws {
        let container = try makeContainer()
        let context = container.mainContext
        let observed = CallCounter()
        let token = NotificationCenter.default.addObserver(
            forName: ModelContext.didSave, object: context, queue: nil
        ) { _ in observed.record() }
        defer { NotificationCenter.default.removeObserver(token) }

        insertCruise("Nordland", start: day(10), end: day(17), in: context)
        try context.save()
        try await Task.sleep(for: .milliseconds(300))
        let notifications = observed.count

        #expect(notifications >= 1)
    }

    @Test("Anlegen, Bearbeiten und Loeschen spiegeln sich im Snapshot")
    func mutationPathsAreReflected() async throws {
        let container = try makeContainer()
        let context = container.mainContext
        let store = makeStore()
        let publisher = WidgetSnapshotPublisher(container: container, store: store, reload: {})

        let cruise = insertCruise("Nordland", start: day(10), end: day(17), in: context)
        try context.save()
        await publisher.publishNow()
        let afterInsert = titles(in: store)

        cruise.title = "Nordland Extra"
        try context.save()
        await publisher.publishNow()
        let afterEdit = titles(in: store)

        context.delete(cruise)
        try context.save()
        await publisher.publishNow()
        let afterDelete = titles(in: store)

        #expect(afterInsert == ["Nordland"])
        #expect(afterEdit == ["Nordland Extra"])
        #expect(afterDelete.isEmpty)
    }

    @Test("Beispielreise an und aus veraendert den Snapshot nicht")
    func demoDataStaysOutOfSnapshot() async throws {
        let container = try makeContainer()
        let context = container.mainContext
        let store = makeStore()
        let publisher = WidgetSnapshotPublisher(container: container, store: store, reload: {})

        insertCruise("Nordland", start: day(10), end: day(17), in: context)
        try context.save()

        DemoDataService.loadDemoData(into: context)
        await publisher.publishNow()
        let withDemo = titles(in: store)

        DemoDataService.removeDemoData(from: context)
        await publisher.publishNow()
        let withoutDemo = titles(in: store)

        #expect(withDemo == ["Nordland"])
        #expect(withoutDemo == ["Nordland"])
    }

    @Test("Alle Reisen loeschen leert den Snapshot")
    func deletingAllCruisesEmptiesSnapshot() async throws {
        let container = try makeContainer()
        let context = container.mainContext
        let store = makeStore()
        let publisher = WidgetSnapshotPublisher(container: container, store: store, reload: {})

        insertCruise("Nordland", start: day(10), end: day(17), in: context)
        insertCruise("Karibik", start: day(-30), end: day(-20), in: context)
        try context.save()
        await publisher.publishNow()
        let before = titles(in: store)

        for cruise in try context.fetch(FetchDescriptor<Cruise>()) {
            context.delete(cruise)
        }
        try context.save()
        await publisher.publishNow()
        let after = titles(in: store)

        #expect(before.count == 2)
        #expect(after.isEmpty)
    }

    @Test("Fuenf Aufrufe in kurzer Folge ergeben genau einen Reload")
    func repeatedPublishCoalescesIntoOneReload() async throws {
        let container = try makeContainer()
        let store = makeStore()
        let spy = CallCounter()
        let publisher = WidgetSnapshotPublisher(
            container: container, store: store,
            reload: { spy.record() }, debounce: .milliseconds(200)
        )

        for _ in 0..<5 { publisher.publish() }
        try await Task.sleep(for: .milliseconds(900))
        let calls = spy.count

        #expect(calls == 1)
    }

    @Test("Ein fehlschlagender Schreibvorgang bleibt folgenlos")
    func failingStoreNeverBreaksTheApp() async throws {
        let container = try makeContainer()
        let context = container.mainContext
        // Unterhalb einer Datei laesst sich kein Verzeichnis anlegen.
        let store = WidgetSnapshotStore(
            containerURL: URL(fileURLWithPath: "/dev/null/shiptrip-widget")
        )
        let spy = CallCounter()
        let publisher = WidgetSnapshotPublisher(
            container: container, store: store, reload: { spy.record() }
        )

        insertCruise("Nordland", start: day(10), end: day(17), in: context)
        try context.save()
        await publisher.publishNow()
        insertCruise("Karibik", start: day(40), end: day(47), in: context)
        try context.save()

        let saved = try context.fetch(FetchDescriptor<Cruise>()).count
        let calls = spy.count

        #expect(saved == 2)
        #expect(calls == 0)
    }

    @Test("Hoechstens drei Reisen, hoechstens vierzig Routeneintraege")
    func snapshotRespectsItsLimits() async throws {
        let container = try makeContainer()
        let context = container.mainContext
        let store = makeStore()
        let publisher = WidgetSnapshotPublisher(container: container, store: store, reload: {})

        insertCruise("Aktiv", start: day(-3), end: day(4), stops: 60, in: context)
        insertCruise("Geplant", start: day(30), end: day(37), stops: 60, in: context)
        insertCruise("Spaeter", start: day(60), end: day(67), in: context)
        insertCruise("Vergangen", start: day(-30), end: day(-20), in: context)
        insertCruise("Lange her", start: day(-300), end: day(-290), in: context)
        try context.save()
        await publisher.publishNow()

        guard case .snapshot(let snapshot) = store.load() else {
            Issue.record("Snapshot nicht lesbar")
            return
        }
        let selected = snapshot.cruises.map(\.title)
        let routeLengths = snapshot.cruises.map(\.route.count)

        #expect(selected == ["Aktiv", "Geplant", "Vergangen"])
        #expect(routeLengths == [40, 40, 0])
    }

    /// Kaltstart ohne Bearbeitung (W2a-F01): keiner der drei ereignisgebundenen
    /// Hooks feuert sicher, wenn der Nutzer die App nur oeffnet und liest.
    /// Der `.task`-Hook in `ShipTripApp` ruft dafuer `publishNow()` — hier ist
    /// die Zusicherung, auf die er sich stuetzt: ein Aufruf auf frischem
    /// Container **ohne** vorherigen Save hinterlaesst eine lesbare Datei,
    /// nicht `.missing`.
    @Test("Kaltstart ohne Save schreibt trotzdem einen Snapshot")
    func publishNowWritesSnapshotWithoutAnySave() async throws {
        let container = try makeContainer()
        let store = makeStore()
        let publisher = WidgetSnapshotPublisher(container: container, store: store, reload: {})

        await publisher.publishNow()

        guard case .snapshot(let snapshot) = store.load() else {
            Issue.record("Kaltstart hinterlaesst keine lesbare Snapshot-Datei")
            return
        }
        #expect(snapshot.cruises.isEmpty)
    }

    @Test("Ohne Veroeffentlichung entsteht keine Datei")
    func initDoesNotPublish() async throws {
        let container = try makeContainer()
        let store = makeStore()
        _ = WidgetSnapshotPublisher(container: container, store: store, reload: {})
        try await Task.sleep(for: .milliseconds(100))
        let result = store.load()

        #expect(result == .missing)
    }
}
