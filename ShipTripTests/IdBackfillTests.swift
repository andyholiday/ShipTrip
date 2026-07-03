//
//  IdBackfillTests.swift
//  ShipTripTests
//

import Testing
import Foundation
import SwiftData
@testable import ShipTrip

// MARK: - Hilfsfunktionen

private typealias CruisePort = ShipTrip.Port

private func makeInMemoryContainer() throws -> ModelContainer {
    let schema = Schema([Cruise.self, CruisePort.self, Expense.self, Deal.self, Photo.self])
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    return try ModelContainer(for: schema, configurations: config)
}

/// `IdBackfill.run` schreibt standardmäßig in `UserDefaults.standard` (Completed-Flag). Damit
/// Tests sich nicht gegenseitig über die reale, testübergreifend persistente Domain beeinflussen,
/// bekommt jeder Testlauf hier eine frische, isolierte Instanz.
private func makeIsolatedDefaults(_ label: String) -> (defaults: UserDefaults, suiteName: String) {
    let suiteName = "IdBackfillTests.\(label).\(UUID().uuidString)"
    return (UserDefaults(suiteName: suiteName)!, suiteName)
}

/// Seedet zwei Cruise-Objekte mit identischer id in einen echten, dateibasierten Store und
/// speichert sie sofort. Container/Context laufen mit Rückgabe aus dem Scope, damit der
/// darauffolgende (schreibgeschützte) Zugriff auf dieselbe Datei nicht durch offene Locks blockiert.
@MainActor
private func seedDuplicateCruises(at url: URL, schema: Schema, sharedID: UUID) throws {
    let seedConfig = ModelConfiguration(schema: schema, url: url)
    let seedContainer = try ModelContainer(for: schema, configurations: seedConfig)
    let seedContext = seedContainer.mainContext

    let c1 = Cruise(title: "A", startDate: .now, endDate: .now, shippingLine: "X", ship: "S1")
    c1.id = sharedID
    let c2 = Cruise(title: "B", startDate: .now, endDate: .now, shippingLine: "X", ship: "S2")
    c2.id = sharedID
    seedContext.insert(c1); seedContext.insert(c2)
    try seedContext.save()
}

// MARK: - Tests

@Suite("IdBackfill")
struct IdBackfillTests {

    /// Drei Cruise-Objekte mit identischer UUID + ein viertes mit eigener UUID einfügen.
    /// Nach `IdBackfill.run` müssen alle vier UUIDs paarweise verschieden sein,
    /// die Gesamtzahl unverändert bleiben und der vierte seine Original-UUID behalten.
    @Test("dedupliziert kollidierende Cruise-UUIDs; vierte (eindeutige) id bleibt erhalten")
    @MainActor
    func dedupesCruiseUUIDs() throws {
        let container = try makeInMemoryContainer()
        let context = container.mainContext
        let (defaults, suiteName) = makeIsolatedDefaults("dedupesCruiseUUIDs")
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let sharedID = UUID()
        let uniqueID = UUID()

        // Drei mit derselben id
        let c1 = Cruise(title: "A", startDate: .now, endDate: .now, shippingLine: "X", ship: "S1")
        c1.id = sharedID
        let c2 = Cruise(title: "B", startDate: .now, endDate: .now, shippingLine: "X", ship: "S2")
        c2.id = sharedID
        let c3 = Cruise(title: "C", startDate: .now, endDate: .now, shippingLine: "X", ship: "S3")
        c3.id = sharedID

        // Einer mit eigener eindeutiger id
        let c4 = Cruise(title: "D", startDate: .now, endDate: .now, shippingLine: "X", ship: "S4")
        c4.id = uniqueID

        context.insert(c1); context.insert(c2); context.insert(c3); context.insert(c4)
        try context.save()

        // Vorbedingung: mindestens zwei Objekte teilen dieselbe id
        let before = try context.fetch(FetchDescriptor<Cruise>())
        #expect(before.count == 4)
        let beforeIDs = before.map(\.id)
        #expect(beforeIDs.filter { $0 == sharedID }.count == 3)

        // Reparatur
        IdBackfill.run(context: context, defaults: defaults)

        // Nachbedingung: alle vier ids paarweise verschieden
        let after = try context.fetch(FetchDescriptor<Cruise>())
        #expect(after.count == 4, "Datenverlust: Anzahl hat sich geändert")

        let afterIDs = after.map(\.id)
        #expect(Set(afterIDs).count == 4, "Nach Backfill existieren noch Duplikate")

        // Der vierte (vorher eindeutige) Träger behält seine ursprüngliche id
        #expect(afterIDs.contains(uniqueID), "Die ursprünglich eindeutige UUID wurde verändert")
    }

    /// Zweiter Aufruf von `IdBackfill.run` ist idempotent: alle ids bleiben unverändert.
    @Test("idempotent: zweiter Aufruf verändert keine ids")
    @MainActor
    func idempotentSecondRun() throws {
        let container = try makeInMemoryContainer()
        let context = container.mainContext
        let (defaults, suiteName) = makeIsolatedDefaults("idempotentSecondRun")
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let sharedID = UUID()

        let c1 = Cruise(title: "Idem1", startDate: .now, endDate: .now, shippingLine: "Y", ship: "T1")
        c1.id = sharedID
        let c2 = Cruise(title: "Idem2", startDate: .now, endDate: .now, shippingLine: "Y", ship: "T2")
        c2.id = sharedID
        context.insert(c1); context.insert(c2)
        try context.save()

        // Erster Aufruf: repariert
        IdBackfill.run(context: context, defaults: defaults)

        let afterFirst = try context.fetch(FetchDescriptor<Cruise>())
        let idsAfterFirst = Set(afterFirst.map(\.id))
        #expect(idsAfterFirst.count == 2)

        // Zweiter Aufruf: darf nichts ändern
        IdBackfill.run(context: context, defaults: defaults)

        let afterSecond = try context.fetch(FetchDescriptor<Cruise>())
        let idsAfterSecond = Set(afterSecond.map(\.id))
        #expect(idsAfterSecond == idsAfterFirst, "Zweiter Aufruf hat ids verändert")
    }

    /// Analoger Schnell-Check für `Port`: UUID-Kollisionen werden dedupliziert.
    @Test("dedupliziert kollidierende Port-UUIDs")
    @MainActor
    func deduplicatesPortUUIDs() throws {
        let container = try makeInMemoryContainer()
        let context = container.mainContext
        let (defaults, suiteName) = makeIsolatedDefaults("deduplicatesPortUUIDs")
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let sharedID = UUID()

        let p1 = CruisePort(name: "Hamburg", country: "DE", latitude: 53.5, longitude: 9.9)
        p1.id = sharedID
        let p2 = CruisePort(name: "Barcelona", country: "ES", latitude: 41.4, longitude: 2.2)
        p2.id = sharedID

        context.insert(p1); context.insert(p2)
        try context.save()

        IdBackfill.run(context: context, defaults: defaults)

        let ports = try context.fetch(FetchDescriptor<CruisePort>())
        #expect(ports.count == 2)
        #expect(Set(ports.map(\.id)).count == 2, "Port-UUIDs wurden nicht dedupliziert")
    }

    // MARK: - Completed-Flag

    @Test("Duplikate erfolgreich repariert -> Completed-Flag wird gesetzt")
    @MainActor
    func successfulRunSetsCompletedFlag() throws {
        let container = try makeInMemoryContainer()
        let context = container.mainContext
        let (defaults, suiteName) = makeIsolatedDefaults("set")
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let sharedID = UUID()
        let c1 = Cruise(title: "A", startDate: .now, endDate: .now, shippingLine: "X", ship: "S1")
        c1.id = sharedID
        let c2 = Cruise(title: "B", startDate: .now, endDate: .now, shippingLine: "X", ship: "S2")
        c2.id = sharedID
        context.insert(c1); context.insert(c2)
        try context.save()

        // In-Memory-Testcontainer ist kein produktiver Fallback-Store -> explizit als
        // "nicht Fallback" markieren, damit das Flag bei Erfolg tatsächlich gesetzt wird.
        IdBackfill.run(context: context, isFallbackStore: false, defaults: defaults)

        #expect(defaults.bool(forKey: IdBackfill.completedFlagKey), "Flag wurde bei erfolgreichem Lauf nicht gesetzt")

        let after = try context.fetch(FetchDescriptor<Cruise>())
        #expect(Set(after.map(\.id)).count == 2, "Duplikate wurden nicht repariert")
    }

    @Test("Zweiter Lauf überspringt die Arbeit, wenn das Completed-Flag bereits gesetzt ist")
    @MainActor
    func secondRunSkipsWhenFlagAlreadySet() throws {
        let container = try makeInMemoryContainer()
        let context = container.mainContext
        let (defaults, suiteName) = makeIsolatedDefaults("skip")
        defer { defaults.removePersistentDomain(forName: suiteName) }

        // Flag simuliert einen bereits erfolgreich abgeschlossenen Vorlauf.
        defaults.set(true, forKey: IdBackfill.completedFlagKey)

        let sharedID = UUID()
        let c1 = Cruise(title: "A", startDate: .now, endDate: .now, shippingLine: "X", ship: "S1")
        c1.id = sharedID
        let c2 = Cruise(title: "B", startDate: .now, endDate: .now, shippingLine: "X", ship: "S2")
        c2.id = sharedID
        context.insert(c1); context.insert(c2)
        try context.save()

        IdBackfill.run(context: context, isFallbackStore: false, defaults: defaults)

        // Lauf wurde übersprungen: die Kollision besteht unverändert weiter.
        let after = try context.fetch(FetchDescriptor<Cruise>())
        #expect(Set(after.map(\.id)).count == 1, "Lauf hat trotz gesetztem Flag Arbeit verrichtet")
    }

    // Hinweis: Ein Test, der einen echten SwiftData-Fetch-Fehler provoziert (z.B. durch Auslassen
    // eines Modelltyps aus dem Schema), ließ sich nicht deterministisch erzeugen – SwiftData toleriert
    // das offenbar transitiv/lazy, unabhängig davon, welcher der fünf Typen ausgelassen wird. Der
    // Contract „kein Flag bei Fehlschlag" ist stattdessen deterministisch über die
    // shouldMarkCompleted-Gating-Tests unten sowie über saveErrorDoesNotSetCompletedFlag abgedeckt.

    /// Deterministischer Backstop, unabhängig von SwiftData-Schema-Quirks: prüft direkt die reine
    /// Gating-Entscheidung, die `run()` verwendet. `allSucceeded: false` deckt sowohl Fetch- als
    /// auch Save-Fehler ab (beide münden in `dedupe`/`run` in genau dieses Flag).
    @Test("shouldMarkCompleted: kein Flag bei allSucceeded == false, unabhängig vom Store")
    func shouldMarkCompletedFalseOnAnyFailure() {
        #expect(IdBackfill.shouldMarkCompleted(allSucceeded: false, usingFallbackStore: false) == false)
        #expect(IdBackfill.shouldMarkCompleted(allSucceeded: false, usingFallbackStore: true) == false)
    }

    @Test("shouldMarkCompleted: Flag nur bei Erfolg UND Nicht-Fallback")
    func shouldMarkCompletedTrueOnlyOnSuccessAndNonFallback() {
        #expect(IdBackfill.shouldMarkCompleted(allSucceeded: true, usingFallbackStore: false) == true)
        #expect(IdBackfill.shouldMarkCompleted(allSucceeded: true, usingFallbackStore: true) == false)
    }

    @Test("Save-Fehler nach reparierten Duplikaten verhindert das Setzen des Completed-Flags")
    @MainActor
    func saveErrorDoesNotSetCompletedFlag() throws {
        // Duplikate real auf die Platte seeden (eigener Container/Context, der danach aus dem
        // Scope läuft), dann denselben Store schreibgeschützt (`allowsSave: false`) neu öffnen –
        // so ist garantiert, dass IdBackfill die Duplikate per Fetch sieht und der anschließende
        // interne Save-Versuch deterministisch fehlschlägt (kein Verlass auf Fetch-Sichtbarkeit
        // ungesicherter Inserts).
        let schema = Schema([Cruise.self, CruisePort.self, Expense.self, Deal.self, Photo.self])
        let storeURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("IdBackfillTests-saveerror-\(UUID().uuidString)")
            .appendingPathExtension("store")
        defer {
            // SQLite legt neben der Hauptdatei ggf. -wal/-shm-Begleitdateien an.
            for suffix in ["", "-wal", "-shm"] {
                try? FileManager.default.removeItem(at: URL(fileURLWithPath: storeURL.path + suffix))
            }
        }

        let sharedID = UUID()
        try seedDuplicateCruises(at: storeURL, schema: schema, sharedID: sharedID)

        let restrictedConfig = ModelConfiguration(schema: schema, url: storeURL, allowsSave: false)
        let container = try ModelContainer(for: schema, configurations: restrictedConfig)
        let context = container.mainContext

        let (defaults, suiteName) = makeIsolatedDefaults("saveerror")
        defer { defaults.removePersistentDomain(forName: suiteName) }

        // Vorbedingung: die geseedeten Duplikate sind über den neuen (read-only) Context sichtbar.
        let before = try context.fetch(FetchDescriptor<Cruise>())
        #expect(before.filter { $0.id == sharedID }.count == 2)

        IdBackfill.run(context: context, isFallbackStore: false, defaults: defaults)

        #expect(!defaults.bool(forKey: IdBackfill.completedFlagKey), "Flag wurde trotz Save-Fehler gesetzt")
    }

    @Test("Fallback-Store (isFallbackStore: true) setzt das Completed-Flag auch bei Erfolg nicht")
    @MainActor
    func fallbackStoreDoesNotSetCompletedFlag() throws {
        let container = try makeInMemoryContainer()
        let context = container.mainContext
        let (defaults, suiteName) = makeIsolatedDefaults("fallback")
        defer { defaults.removePersistentDomain(forName: suiteName) }

        IdBackfill.run(context: context, isFallbackStore: true, defaults: defaults)

        #expect(!defaults.bool(forKey: IdBackfill.completedFlagKey), "Flag wurde im Fallback-Store gesetzt")
    }
}
