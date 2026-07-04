//
//  ShippingLineCatalogDedupTests.swift
//  ShipTripTests
//

import Testing
import Foundation
import SwiftData
@testable import ShipTrip

// MARK: - Hilfsfunktionen

private typealias CruisePort = ShipTrip.Port

/// Eigener Schema-Helfer (ADR-006, Abschnitt 7): registriert die drei neuen Modelle zusätzlich
/// zu den fünf bestehenden. Die sieben bestehenden Test-Schema-Helfer bleiben unangetastet.
private func makeInMemoryContainer() throws -> ModelContainer {
    let schema = Schema([
        Cruise.self, CruisePort.self, Expense.self, Deal.self, Photo.self,
        CustomShippingLine.self, CustomShip.self, HiddenCatalogItem.self
    ])
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    return try ModelContainer(for: schema, configurations: config)
}

/// `ShippingLineCatalogDedup.run` schreibt standardmäßig in `UserDefaults.standard` (Completed-Flag).
/// Damit Tests sich nicht gegenseitig beeinflussen, bekommt jeder Testlauf eine frische, isolierte Instanz.
private func makeIsolatedDefaults(_ label: String) -> (defaults: UserDefaults, suiteName: String) {
    let suiteName = "ShippingLineCatalogDedupTests.\(label).\(UUID().uuidString)"
    return (UserDefaults(suiteName: suiteName)!, suiteName)
}

@Suite("ShippingLineCatalogDedup")
struct ShippingLineCatalogDedupTests {

    // MARK: - Acceptance-Test 7: CustomShippingLine-Duplikate + Rewiring

    @Test("dedupliziert CustomShippingLine-Duplikate: ältestes createdAt gewinnt, CustomShip-Zeilen werden umgeschrieben")
    @MainActor
    func dedupesCustomShippingLineDuplicatesWithRewiring() throws {
        let container = try makeInMemoryContainer()
        let context = container.mainContext
        let (defaults, suiteName) = makeIsolatedDefaults("linesWithRewiring")
        defer { defaults.removePersistentDomain(forName: suiteName) }

        // Zwei "Geräte" legen offline dieselbe Custom-Reederei mit unterschiedlichen UUIDs an,
        // je mit einem eigenen CustomShip darunter.
        let older = CustomShippingLine(name: "Flussperle Reederei")
        older.createdAt = Date(timeIntervalSince1970: 1000)
        let newer = CustomShippingLine(name: "flussperle reederei") // gleicher collisionKey, andere Schreibweise
        newer.createdAt = Date(timeIntervalSince1970: 2000)
        context.insert(older); context.insert(newer)

        let shipOnOlder = CustomShip(name: "Flussperle I", lineOptionID: "custom:\(older.id.uuidString)")
        let shipOnNewer = CustomShip(name: "Flussperle II", lineOptionID: "custom:\(newer.id.uuidString)")
        context.insert(shipOnOlder); context.insert(shipOnNewer)
        try context.save()

        ShippingLineCatalogDedup.run(context: context, isFallbackStore: false, defaults: defaults)

        let remainingLines = try context.fetch(FetchDescriptor<CustomShippingLine>())
        #expect(remainingLines.count == 1, "Nach Dedup darf nur noch eine CustomShippingLine-Zeile existieren")
        #expect(remainingLines.first?.id == older.id, "Ältestes createdAt muss gewinnen")

        let ships = try context.fetch(FetchDescriptor<CustomShip>())
        #expect(ships.count == 2, "Datenverlust: Schiffe dürfen beim Line-Dedup nicht verschwinden")
        let winnerOptionID = "custom:\(older.id.uuidString)"
        #expect(ships.allSatisfy { $0.lineOptionID == winnerOptionID }, "Alle Schiffe müssen auf die Gewinner-lineOptionID umgeschrieben sein")
    }

    // MARK: - Acceptance-Test 7: CustomShip-Duplikate

    @Test("dedupliziert CustomShip-Duplikate unter derselben Reederei (gleiche lineOptionID + collisionKey)")
    @MainActor
    func dedupesCustomShipDuplicates() throws {
        let container = try makeInMemoryContainer()
        let context = container.mainContext
        let (defaults, suiteName) = makeIsolatedDefaults("ships")
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let older = CustomShip(name: "AIDAtest", lineOptionID: "aida")
        older.createdAt = Date(timeIntervalSince1970: 1000)
        let newer = CustomShip(name: "aidatest", lineOptionID: "aida") // gleicher collisionKey (case-insensitiv)
        newer.createdAt = Date(timeIntervalSince1970: 2000)
        context.insert(older); context.insert(newer)
        try context.save()

        ShippingLineCatalogDedup.run(context: context, isFallbackStore: false, defaults: defaults)

        let remaining = try context.fetch(FetchDescriptor<CustomShip>())
        #expect(remaining.count == 1)
        #expect(remaining.first?.id == older.id)
    }

    @Test("dedupliziert CustomShip-Duplikate mit diakritischer Schreibweise (gleicher collisionKey, cross-device)")
    @MainActor
    func dedupesCustomShipDuplicatesAcrossDiacritics() throws {
        let container = try makeInMemoryContainer()
        let context = container.mainContext
        let (defaults, suiteName) = makeIsolatedDefaults("shipsDiacritics")
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let older = CustomShip(name: "Königsklasse Schiff", lineOptionID: "aida")
        older.createdAt = Date(timeIntervalSince1970: 1000)
        let newer = CustomShip(name: "Konigsklasse Schiff", lineOptionID: "aida") // gleicher collisionKey, andere Geräte-Eingabe
        newer.createdAt = Date(timeIntervalSince1970: 2000)
        context.insert(older); context.insert(newer)
        try context.save()

        ShippingLineCatalogDedup.run(context: context, isFallbackStore: false, defaults: defaults)

        let remaining = try context.fetch(FetchDescriptor<CustomShip>())
        #expect(remaining.count == 1, "Diakritik-Duplikat wurde nicht als Kollision erkannt")
        #expect(remaining.first?.id == older.id)
    }

    @Test("CustomShip mit identischem Namen unter verschiedenen Reedereien bleibt unangetastet")
    @MainActor
    func customShipsUnderDifferentLinesAreNotMergedAsDuplicates() throws {
        let container = try makeInMemoryContainer()
        let context = container.mainContext
        let (defaults, suiteName) = makeIsolatedDefaults("shipsDifferentLines")
        defer { defaults.removePersistentDomain(forName: suiteName) }

        context.insert(CustomShip(name: "Ocean Star", lineOptionID: "aida"))
        context.insert(CustomShip(name: "Ocean Star", lineOptionID: "msc"))
        try context.save()

        ShippingLineCatalogDedup.run(context: context, isFallbackStore: false, defaults: defaults)

        let remaining = try context.fetch(FetchDescriptor<CustomShip>())
        #expect(remaining.count == 2, "Gleicher Name unter verschiedenen Reedereien ist keine Kollision")
    }

    // MARK: - Acceptance-Test 7: HiddenCatalogItem-Duplikate

    @Test("dedupliziert HiddenCatalogItem-Duplikate (gleiche lineID + shipKey)")
    @MainActor
    func dedupesHiddenCatalogItemDuplicates() throws {
        let container = try makeInMemoryContainer()
        let context = container.mainContext
        let (defaults, suiteName) = makeIsolatedDefaults("hidden")
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let older = HiddenCatalogItem(lineID: "aida")
        older.createdAt = Date(timeIntervalSince1970: 1000)
        let newer = HiddenCatalogItem(lineID: "aida")
        newer.createdAt = Date(timeIntervalSince1970: 2000)
        context.insert(older); context.insert(newer)
        try context.save()

        ShippingLineCatalogDedup.run(context: context, isFallbackStore: false, defaults: defaults)

        let remaining = try context.fetch(FetchDescriptor<HiddenCatalogItem>())
        #expect(remaining.count == 1)
        #expect(remaining.first?.id == older.id)
    }

    @Test("HiddenCatalogItem mit unterschiedlichem shipKey (inkl. beide nil vs. gesetzt) sind keine Duplikate")
    @MainActor
    func hiddenCatalogItemsWithDifferentShipKeyAreNotMerged() throws {
        let container = try makeInMemoryContainer()
        let context = container.mainContext
        let (defaults, suiteName) = makeIsolatedDefaults("hiddenDifferentKeys")
        defer { defaults.removePersistentDomain(forName: suiteName) }

        context.insert(HiddenCatalogItem(lineID: "aida")) // ganze Reederei
        context.insert(HiddenCatalogItem(lineID: "aida", shipKey: "aidastella")) // einzelnes Schiff
        try context.save()

        ShippingLineCatalogDedup.run(context: context, isFallbackStore: false, defaults: defaults)

        let remaining = try context.fetch(FetchDescriptor<HiddenCatalogItem>())
        #expect(remaining.count == 2)
    }

    // MARK: - Determinismus bei exaktem Gleichstand

    @Test("bei exaktem createdAt-Gleichstand gewinnt die lexikographisch kleinere UUID")
    @MainActor
    func tieBreaksOnLexicographicallySmallerUUID() throws {
        let container = try makeInMemoryContainer()
        let context = container.mainContext
        let (defaults, suiteName) = makeIsolatedDefaults("tieBreak")
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let sharedTimestamp = Date(timeIntervalSince1970: 5000)
        let lineA = CustomShippingLine(name: "Tie Break Reederei")
        lineA.createdAt = sharedTimestamp
        let lineB = CustomShippingLine(name: "Tie Break Reederei")
        lineB.createdAt = sharedTimestamp
        context.insert(lineA); context.insert(lineB)
        try context.save()

        let expectedWinnerID = min(lineA.id.uuidString, lineB.id.uuidString)

        ShippingLineCatalogDedup.run(context: context, isFallbackStore: false, defaults: defaults)

        let remaining = try context.fetch(FetchDescriptor<CustomShippingLine>())
        #expect(remaining.count == 1)
        #expect(remaining.first?.id.uuidString == expectedWinnerID)
    }

    // MARK: - Idempotenz

    @Test("zweiter Aufruf ist idempotent: keine weiteren Änderungen, wenn Flag bereits gesetzt")
    @MainActor
    func secondRunSkipsWhenFlagAlreadySet() throws {
        let container = try makeInMemoryContainer()
        let context = container.mainContext
        let (defaults, suiteName) = makeIsolatedDefaults("idempotent")
        defer { defaults.removePersistentDomain(forName: suiteName) }

        context.insert(CustomShippingLine(name: "Erste Reederei"))
        context.insert(CustomShippingLine(name: "erste reederei"))
        try context.save()

        ShippingLineCatalogDedup.run(context: context, isFallbackStore: false, defaults: defaults)
        #expect(try context.fetch(FetchDescriptor<CustomShippingLine>()).count == 1)

        // Neues Duplikat nach dem ersten (abgeschlossenen) Lauf einfügen — darf vom zweiten
        // Aufruf NICHT mehr angefasst werden, da das Completed-Flag bereits gesetzt ist.
        context.insert(CustomShippingLine(name: "erste reederei"))
        try context.save()

        ShippingLineCatalogDedup.run(context: context, isFallbackStore: false, defaults: defaults)
        #expect(try context.fetch(FetchDescriptor<CustomShippingLine>()).count == 2, "Zweiter Lauf hätte übersprungen werden müssen")
    }

    // MARK: - Completed-Flag-Gating (analog IdBackfillTests)

    @Test("shouldMarkCompleted: kein Flag bei allSucceeded == false, unabhängig vom Store")
    func shouldMarkCompletedFalseOnAnyFailure() {
        #expect(ShippingLineCatalogDedup.shouldMarkCompleted(allSucceeded: false, usingFallbackStore: false) == false)
        #expect(ShippingLineCatalogDedup.shouldMarkCompleted(allSucceeded: false, usingFallbackStore: true) == false)
    }

    @Test("shouldMarkCompleted: Flag nur bei Erfolg UND Nicht-Fallback")
    func shouldMarkCompletedTrueOnlyOnSuccessAndNonFallback() {
        #expect(ShippingLineCatalogDedup.shouldMarkCompleted(allSucceeded: true, usingFallbackStore: false) == true)
        #expect(ShippingLineCatalogDedup.shouldMarkCompleted(allSucceeded: true, usingFallbackStore: true) == false)
    }

    @Test("Fallback-Store (isFallbackStore: true) setzt das Completed-Flag auch bei Erfolg nicht")
    @MainActor
    func fallbackStoreDoesNotSetCompletedFlag() throws {
        let container = try makeInMemoryContainer()
        let context = container.mainContext
        let (defaults, suiteName) = makeIsolatedDefaults("fallback")
        defer { defaults.removePersistentDomain(forName: suiteName) }

        ShippingLineCatalogDedup.run(context: context, isFallbackStore: true, defaults: defaults)

        #expect(!defaults.bool(forKey: ShippingLineCatalogDedup.completedFlagKey))
    }

    @Test("keine Duplikate vorhanden -> Lauf ist ein No-Op, Completed-Flag wird trotzdem gesetzt")
    @MainActor
    func noDuplicatesIsNoOpButSetsFlag() throws {
        let container = try makeInMemoryContainer()
        let context = container.mainContext
        let (defaults, suiteName) = makeIsolatedDefaults("noop")
        defer { defaults.removePersistentDomain(forName: suiteName) }

        context.insert(CustomShippingLine(name: "Einzigartige Reederei"))
        try context.save()

        ShippingLineCatalogDedup.run(context: context, isFallbackStore: false, defaults: defaults)

        #expect(defaults.bool(forKey: ShippingLineCatalogDedup.completedFlagKey))
        #expect(try context.fetch(FetchDescriptor<CustomShippingLine>()).count == 1)
    }
}
