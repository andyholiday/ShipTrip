//
//  ShippingLineCatalogServiceTests.swift
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
private let shippingLineCatalogTestSchema = Schema([
    Cruise.self, CruisePort.self, Expense.self, Deal.self, Photo.self,
    CustomShippingLine.self, CustomShip.self, HiddenCatalogItem.self
])

private func makeInMemoryContainer() throws -> ModelContainer {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    return try ModelContainer(for: shippingLineCatalogTestSchema, configurations: config)
}

/// Echter, dateibasierter Store, read-only geöffnet (`allowsSave: false`) – erzwingt einen
/// deterministischen `context.save()`-Fehler, um zu verifizieren, dass die schreibenden
/// Service-Funktionen Fetch-/Save-Fehler propagieren statt sie per `try?` zu verschlucken
/// (Fix-Runde 1, A3). Analog `IdBackfillTests.saveErrorDoesNotSetCompletedFlag`.
@MainActor
private func makeReadOnlyContainer(label: String) throws -> ModelContainer {
    let storeURL = FileManager.default.temporaryDirectory
        .appendingPathComponent("ShippingLineCatalogServiceTests-\(label)-\(UUID().uuidString)")
        .appendingPathExtension("store")

    // Store zunächst normal (leer) anlegen, danach read-only neu öffnen.
    let seedConfig = ModelConfiguration(schema: shippingLineCatalogTestSchema, url: storeURL)
    _ = try ModelContainer(for: shippingLineCatalogTestSchema, configurations: seedConfig)

    let restrictedConfig = ModelConfiguration(schema: shippingLineCatalogTestSchema, url: storeURL, allowsSave: false)
    return try ModelContainer(for: shippingLineCatalogTestSchema, configurations: restrictedConfig)
}

/// `ShippingLineCatalogError` ist bewusst nicht `Equatable` (ADR-006-Contract unverändert) —
/// diese Helfer prüfen den erwarteten Case per `switch`, statt Equatable-Konformität zu erzwingen.
private func expectDuplicateLineName(_ operation: () throws -> Void) throws {
    do {
        try operation()
        Issue.record("Erwartete ShippingLineCatalogError.duplicateLineName wurde nicht geworfen")
    } catch let error as ShippingLineCatalogError {
        switch error {
        case .duplicateLineName: break
        case .duplicateShipName: Issue.record("Falscher Error-Case: duplicateShipName statt duplicateLineName")
        }
    }
}

private func expectDuplicateShipName(_ operation: () throws -> Void) throws {
    do {
        try operation()
        Issue.record("Erwartete ShippingLineCatalogError.duplicateShipName wurde nicht geworfen")
    } catch let error as ShippingLineCatalogError {
        switch error {
        case .duplicateShipName: break
        case .duplicateLineName: Issue.record("Falscher Error-Case: duplicateLineName statt duplicateShipName")
        }
    }
}

@Suite("ShippingLineCatalogService")
struct ShippingLineCatalogServiceTests {

    // MARK: - Acceptance-Test 1: Merge gemischt + sortiert

    @Test("shippingLineOptions mischt Katalog und Custom, sortiert nach collisionKey(name)")
    @MainActor
    func shippingLineOptionsMergedAndSorted() throws {
        let container = try makeInMemoryContainer()
        let context = container.mainContext

        let custom = CustomShippingLine(name: "AAA Flusskreuzfahrten")
        context.insert(custom)
        try context.save()

        let customLines = try context.fetch(FetchDescriptor<CustomShippingLine>())
        let options = ShippingLineCatalogService.shippingLineOptions(customLines: customLines, hidden: [], currentSelection: nil)

        #expect(options.contains { $0.source == .catalog && $0.id == "aida" })
        #expect(options.contains { $0.source == .custom && $0.name == "AAA Flusskreuzfahrten" })

        // "AAA..." sortiert alphabetisch vor allen Katalog-Reedereien.
        #expect(options.first?.name == "AAA Flusskreuzfahrten")

        let sortedKeys = options.map { ShippingLineNameMatching.collisionKey($0.name) }
        #expect(sortedKeys == sortedKeys.sorted())
    }

    @Test("shipOptions mischt Katalog- und Custom-Schiffe einer Reederei, sortiert")
    @MainActor
    func shipOptionsMergedAndSorted() throws {
        let container = try makeInMemoryContainer()
        let context = container.mainContext

        let ship = CustomShip(name: "AIDAtest", lineOptionID: "aida")
        context.insert(ship)
        try context.save()

        let customShips = try context.fetch(FetchDescriptor<CustomShip>())
        let options = ShippingLineCatalogService.shipOptions(
            for: "aida", customShips: customShips, hidden: [], currentSelection: nil
        )

        #expect(options.contains { $0.source == .catalog && $0.name == "AIDAstella" && !$0.isHistorical })
        #expect(options.contains { $0.source == .custom && $0.name == "AIDAtest" })

        let sortedKeys = options.map { ShippingLineNameMatching.collisionKey($0.name) }
        #expect(sortedKeys == sortedKeys.sorted())
    }

    @Test("historische Schiffe erscheinen NICHT generell (nur Bestandsschutz bei Katalog-Umbenennung)")
    func historicalShipsAreExcludedForNewSelections() {
        // Ohne currentSelection (neue Reise): AIDAcara ist ausgemustert und darf nicht auftauchen.
        let optionsForNewCruise = ShippingLineCatalogService.shipOptions(
            for: "aida", customShips: [], hidden: [], currentSelection: nil
        )
        #expect(!optionsForNewCruise.contains { $0.name == "AIDAcara" })

        // currentSelection auf ein AKTIVES Schiff darf historische Schiffe ebenfalls nicht einblenden.
        let optionsForActiveSelection = ShippingLineCatalogService.shipOptions(
            for: "aida", customShips: [], hidden: [], currentSelection: "AIDAstella"
        )
        #expect(!optionsForActiveSelection.contains { $0.name == "AIDAcara" })
    }

    @Test("historisches Schiff bleibt beim Bearbeiten einer Bestandsreise als Katalog-Option sichtbar (Edit-Bestandsschutz)")
    func historicalShipVisibleWhenCurrentSelectionMatches() {
        let options = ShippingLineCatalogService.shipOptions(
            for: "aida", customShips: [], hidden: [], currentSelection: "AIDAcara"
        )
        let match = options.first { $0.name == "AIDAcara" }
        #expect(match?.source == .catalog, "muss als Katalog-Option erscheinen, nicht als .unlisted-Duplikat")
        #expect(match?.isHistorical == true)
        #expect(options.filter { $0.name == "AIDAcara" }.count == 1, "darf nicht doppelt (Katalog + unlisted) auftauchen")
    }

    // MARK: - Acceptance-Test 2 + 3: Hide / Unhide

    @Test("hideCatalogLine entfernt Reederei aus shippingLineOptions, unhide stellt sie wieder her")
    @MainActor
    func hideAndUnhideCatalogLine() throws {
        let container = try makeInMemoryContainer()
        let context = container.mainContext

        try ShippingLineCatalogService.hideCatalogLine(lineID: "aida", in: context)

        var hidden = try context.fetch(FetchDescriptor<HiddenCatalogItem>())
        var options = ShippingLineCatalogService.shippingLineOptions(customLines: [], hidden: hidden, currentSelection: nil)
        #expect(!options.contains { $0.id == "aida" })

        try ShippingLineCatalogService.unhideCatalogLine(lineID: "aida", in: context)

        hidden = try context.fetch(FetchDescriptor<HiddenCatalogItem>())
        options = ShippingLineCatalogService.shippingLineOptions(customLines: [], hidden: hidden, currentSelection: nil)
        #expect(options.contains { $0.id == "aida" })
    }

    @Test("hideCatalogShip entfernt Schiff aus shipOptions, unhide stellt es wieder her")
    @MainActor
    func hideAndUnhideCatalogShip() throws {
        let container = try makeInMemoryContainer()
        let context = container.mainContext

        try ShippingLineCatalogService.hideCatalogShip(lineID: "aida", shipName: "AIDAstella", in: context)

        var hidden = try context.fetch(FetchDescriptor<HiddenCatalogItem>())
        var options = ShippingLineCatalogService.shipOptions(for: "aida", customShips: [], hidden: hidden, currentSelection: nil)
        #expect(!options.contains { $0.name == "AIDAstella" })
        // Andere Schiffe derselben Reederei bleiben unberührt.
        #expect(options.contains { $0.name == "AIDAnova" })

        try ShippingLineCatalogService.unhideCatalogShip(lineID: "aida", shipName: "AIDAstella", in: context)

        hidden = try context.fetch(FetchDescriptor<HiddenCatalogItem>())
        options = ShippingLineCatalogService.shipOptions(for: "aida", customShips: [], hidden: hidden, currentSelection: nil)
        #expect(options.contains { $0.name == "AIDAstella" })
    }

    // MARK: - Acceptance-Test 4: Namenskollision

    @Test("createCustomLine lehnt Kollision mit Katalog-Namen ab (exakt)")
    @MainActor
    func createCustomLineRejectsCatalogCollision() throws {
        let container = try makeInMemoryContainer()
        let context = container.mainContext

        try expectDuplicateLineName {
            try ShippingLineCatalogService.createCustomLine(name: "AIDA Cruises", logo: "🚢", in: context)
        }

        let lines = try context.fetch(FetchDescriptor<CustomShippingLine>())
        #expect(lines.isEmpty, "Kein Duplikat darf angelegt werden")
    }

    @Test("createCustomLine lehnt diakritik-insensitive Kollision mit bestehendem Custom-Namen ab")
    @MainActor
    func createCustomLineRejectsDiacriticCollision() throws {
        let container = try makeInMemoryContainer()
        let context = container.mainContext

        _ = try ShippingLineCatalogService.createCustomLine(name: "Königsklasse Reederei", logo: "🚢", in: context)
        try context.save()

        try expectDuplicateLineName {
            try ShippingLineCatalogService.createCustomLine(name: "Konigsklasse Reederei", logo: "🚢", in: context)
        }

        let lines = try context.fetch(FetchDescriptor<CustomShippingLine>())
        #expect(lines.count == 1, "Diakritik-Kollision darf kein zweites Duplikat erzeugen")
    }

    @Test("createCustomShip lehnt Kollision mit Katalog-Schiff der Ziel-Reederei ab")
    @MainActor
    func createCustomShipRejectsCatalogCollision() throws {
        let container = try makeInMemoryContainer()
        let context = container.mainContext

        try expectDuplicateShipName {
            try ShippingLineCatalogService.createCustomShip(name: "AIDAstella", lineOptionID: "aida", in: context)
        }

        let ships = try context.fetch(FetchDescriptor<CustomShip>())
        #expect(ships.isEmpty)
    }

    @Test("createCustomShip erlaubt denselben Namen unter einer anderen Reederei")
    @MainActor
    func createCustomShipAllowsSameNameUnderDifferentLine() throws {
        let container = try makeInMemoryContainer()
        let context = container.mainContext

        _ = try ShippingLineCatalogService.createCustomShip(name: "Ocean Star", lineOptionID: "aida", in: context)
        _ = try ShippingLineCatalogService.createCustomShip(name: "Ocean Star", lineOptionID: "msc", in: context)
        try context.save()

        let ships = try context.fetch(FetchDescriptor<CustomShip>())
        #expect(ships.count == 2)
    }

    // MARK: - Acceptance-Test 5: Cascade-Delete

    @Test("deleteCustomLine löscht zugehörige CustomShip-Zeilen (App-seitiges Cascade)")
    @MainActor
    func deleteCustomLineCascadesToShips() throws {
        let container = try makeInMemoryContainer()
        let context = container.mainContext

        let lineOption = try ShippingLineCatalogService.createCustomLine(name: "Flussperle Reederei", logo: "🚢", in: context)
        _ = try ShippingLineCatalogService.createCustomShip(name: "Flussperle I", lineOptionID: lineOption.id, in: context)
        _ = try ShippingLineCatalogService.createCustomShip(name: "Flussperle II", lineOptionID: lineOption.id, in: context)
        try context.save()

        #expect(try context.fetch(FetchDescriptor<CustomShip>()).count == 2)

        guard let customID = lineOption.customID else {
            Issue.record("customID muss bei source == .custom gesetzt sein")
            return
        }
        try ShippingLineCatalogService.deleteCustomLine(customID, in: context)

        #expect(try context.fetch(FetchDescriptor<CustomShippingLine>()).isEmpty)
        #expect(try context.fetch(FetchDescriptor<CustomShip>()).isEmpty, "Cascade-Delete hat die Schiffe nicht mitgelöscht")
    }

    @Test("deleteCustomLine lässt Schiffe anderer Reedereien unangetastet")
    @MainActor
    func deleteCustomLineLeavesOtherLinesShipsIntact() throws {
        let container = try makeInMemoryContainer()
        let context = container.mainContext

        let lineA = try ShippingLineCatalogService.createCustomLine(name: "Reederei A", logo: "🚢", in: context)
        let lineB = try ShippingLineCatalogService.createCustomLine(name: "Reederei B", logo: "🚢", in: context)
        _ = try ShippingLineCatalogService.createCustomShip(name: "Schiff A", lineOptionID: lineA.id, in: context)
        _ = try ShippingLineCatalogService.createCustomShip(name: "Schiff B", lineOptionID: lineB.id, in: context)
        try context.save()

        guard let customIDA = lineA.customID else {
            Issue.record("customID muss gesetzt sein")
            return
        }
        try ShippingLineCatalogService.deleteCustomLine(customIDA, in: context)

        let remainingShips = try context.fetch(FetchDescriptor<CustomShip>())
        #expect(remainingShips.count == 1)
        #expect(remainingShips.first?.name == "Schiff B")
    }

    // MARK: - Schreibende Operationen sind throws und speichern selbst (kein try? mehr, Fix-Runde 1 A3)

    @Test("createCustomLine speichert selbst (try context.save()) – Daten überleben einen neuen Context auf demselben Store")
    @MainActor
    func createCustomLinePersistsToDisk() throws {
        let schema = shippingLineCatalogTestSchema
        let storeURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("ShippingLineCatalogServiceTests-persist-\(UUID().uuidString)")
            .appendingPathExtension("store")
        defer {
            for suffix in ["", "-wal", "-shm"] {
                try? FileManager.default.removeItem(at: URL(fileURLWithPath: storeURL.path + suffix))
            }
        }

        do {
            let config = ModelConfiguration(schema: schema, url: storeURL)
            let container = try ModelContainer(for: schema, configurations: config)
            // Bewusst KEIN zusätzliches context.save() danach — der Service muss selbst speichern.
            _ = try ShippingLineCatalogService.createCustomLine(name: "Persistenz-Reederei", logo: "🚢", in: container.mainContext)
        }

        let reopenedConfig = ModelConfiguration(schema: schema, url: storeURL)
        let reopenedContainer = try ModelContainer(for: schema, configurations: reopenedConfig)
        let reopenedLines = try reopenedContainer.mainContext.fetch(FetchDescriptor<CustomShippingLine>())
        #expect(reopenedLines.contains { $0.name == "Persistenz-Reederei" }, "createCustomLine hat nicht selbst gespeichert")
    }

    @Test("createCustomLine propagiert einen Save-Fehler (read-only Store) statt ihn zu verschlucken")
    @MainActor
    func createCustomLinePropagatesSaveError() throws {
        let container = try makeReadOnlyContainer(label: "createline")

        #expect(throws: (any Error).self) {
            _ = try ShippingLineCatalogService.createCustomLine(name: "Wird nie gespeichert", logo: "🚢", in: container.mainContext)
        }
    }

    @Test("hideCatalogLine propagiert einen Save-Fehler (read-only Store) statt ihn zu verschlucken")
    @MainActor
    func hideCatalogLinePropagatesSaveError() throws {
        let container = try makeReadOnlyContainer(label: "hideline")

        #expect(throws: (any Error).self) {
            try ShippingLineCatalogService.hideCatalogLine(lineID: "aida", in: container.mainContext)
        }
    }

    // MARK: - currentSelection -> .unlisted-Option (Preserve-on-save-Baustein, ADR-006 Abschnitt 5)

    @Test("currentSelection ohne Match erzeugt eine zusätzliche .unlisted-Option")
    func currentSelectionCreatesUnlistedLineOption() {
        let options = ShippingLineCatalogService.shippingLineOptions(
            customLines: [], hidden: [], currentSelection: "Gelöschte Alte Reederei"
        )

        let unlisted = options.first { $0.source == .unlisted }
        #expect(unlisted?.name == "Gelöschte Alte Reederei")
        #expect(unlisted?.customID == nil)
    }

    @Test("currentSelection mit exaktem Match erzeugt KEINE zusätzliche .unlisted-Option")
    func currentSelectionMatchingCatalogDoesNotDuplicate() {
        let options = ShippingLineCatalogService.shippingLineOptions(
            customLines: [], hidden: [], currentSelection: "AIDA Cruises"
        )
        #expect(!options.contains { $0.source == .unlisted })
        #expect(options.filter { $0.name == "AIDA Cruises" }.count == 1)
    }

    @Test("currentSelection nil/leer erzeugt keine .unlisted-Option")
    func currentSelectionNilOrEmptyCreatesNoUnlisted() {
        let optionsNil = ShippingLineCatalogService.shippingLineOptions(customLines: [], hidden: [], currentSelection: nil)
        #expect(!optionsNil.contains { $0.source == .unlisted })

        let optionsEmpty = ShippingLineCatalogService.shippingLineOptions(customLines: [], hidden: [], currentSelection: "")
        #expect(!optionsEmpty.contains { $0.source == .unlisted })
    }

    @Test("currentSelection ohne Match erzeugt eine zusätzliche .unlisted-Schiff-Option")
    func currentSelectionCreatesUnlistedShipOption() {
        let options = ShippingLineCatalogService.shipOptions(
            for: "aida", customShips: [], hidden: [], currentSelection: "AIDAtest-nicht-im-Katalog"
        )
        let unlisted = options.first { $0.source == .unlisted }
        #expect(unlisted?.name == "AIDAtest-nicht-im-Katalog")
        #expect(unlisted?.lineOptionID == "aida")
        #expect(unlisted?.customID == nil)
    }

    // MARK: - Acceptance-Test 6: findByShipName unverändert (Regression)

    @Test("findByShipName bleibt nach der normalizedShipKey-Extraktion funktional unverändert")
    func findByShipNameStillMatchesExistingCases() {
        #expect(ShippingLine.findByShipName("AIDAstella")?.id == "aida")
        #expect(ShippingLine.findByShipName("AIDA Stella")?.id == "aida")
        #expect(ShippingLine.findByShipName("aidastella")?.id == "aida")
        #expect(ShippingLine.find(byId: "aida")?.ships.contains("AIDAstella") == true)
    }
}
