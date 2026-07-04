//
//  SchemaUpgradeMigrationTests.swift
//  ShipTripTests
//

import Testing
import Foundation
import SwiftData
@testable import ShipTrip

// MARK: - Hilfsfunktionen

private typealias CruisePort = ShipTrip.Port

/// Schema VOR ADR-006: nur die fünf Bestandsmodelle (Stand 1.6.1).
private let legacyFiveModelSchema = Schema([Cruise.self, CruisePort.self, Expense.self, Deal.self, Photo.self])

/// Schema NACH ADR-006: die fünf Bestandsmodelle plus die drei neuen Typen, exakt wie in
/// `ShipTripApp.swift` registriert.
private let currentEightModelSchema = Schema([
    Cruise.self, CruisePort.self, Expense.self, Deal.self, Photo.self,
    CustomShippingLine.self, CustomShip.self, HiddenCatalogItem.self
])

/// Verifiziert den in ADR-006, Abschnitt 7 verbindlich vorgeschriebenen Upgrade-Pflicht-Check:
/// ein bestehender Store aus 1.6.1 (fünf Modelle) muss mit dem neuen Acht-Modell-Schema klaglos
/// öffnen, Bestandsdaten unverändert erhalten und die drei neuen Tabellen leer, aber nutzbar
/// bereitstellen (rein additive Lightweight-Migration, keine bestehenden Attribute geändert).
@Suite("Schema-Upgrade-Migration (ADR-006)")
struct SchemaUpgradeMigrationTests {

    @Test("Store aus dem alten 5-Modell-Schema öffnet mit dem neuen 8-Modell-Schema, Bestandsdaten bleiben intakt, neue Tabellen sind nutzbar")
    @MainActor
    func upgradesFromFiveToEightModelSchema() throws {
        let storeURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("SchemaUpgradeMigrationTests-\(UUID().uuidString)")
            .appendingPathExtension("store")
        defer {
            for suffix in ["", "-wal", "-shm"] {
                try? FileManager.default.removeItem(at: URL(fileURLWithPath: storeURL.path + suffix))
            }
        }

        let cruiseID = UUID()

        // (1) Store mit dem ALTEN Schema anlegen und mit Bestandsdaten befüllen.
        do {
            let legacyConfig = ModelConfiguration(schema: legacyFiveModelSchema, url: storeURL)
            let legacyContainer = try ModelContainer(for: legacyFiveModelSchema, configurations: legacyConfig)
            let legacyContext = legacyContainer.mainContext

            let cruise = Cruise(
                title: "Mittelmeer-Rundreise",
                startDate: Date(timeIntervalSince1970: 1_700_000_000),
                endDate: Date(timeIntervalSince1970: 1_700_600_000),
                shippingLine: "AIDA Cruises",
                ship: "AIDAstella"
            )
            cruise.id = cruiseID

            let port = CruisePort(name: "Barcelona", country: "ES", latitude: 41.4, longitude: 2.2)
            port.cruise = cruise

            legacyContext.insert(cruise)
            legacyContext.insert(port)
            try legacyContext.save()
        }

        // (2) Denselben Store mit dem NEUEN 8-Modell-Schema öffnen (wie ShipTripApp.init).
        let upgradedConfig = ModelConfiguration(schema: currentEightModelSchema, url: storeURL)
        let upgradedContainer = try ModelContainer(for: currentEightModelSchema, configurations: upgradedConfig)
        let upgradedContext = upgradedContainer.mainContext

        // Bestandsdaten unverändert.
        let cruises = try upgradedContext.fetch(FetchDescriptor<Cruise>())
        #expect(cruises.count == 1, "Bestands-Cruise darf beim Upgrade nicht verloren gehen")
        let migratedCruise = try #require(cruises.first { $0.id == cruiseID })
        #expect(migratedCruise.title == "Mittelmeer-Rundreise")
        #expect(migratedCruise.shippingLine == "AIDA Cruises")
        #expect(migratedCruise.ship == "AIDAstella")

        let ports = try upgradedContext.fetch(FetchDescriptor<CruisePort>())
        #expect(ports.count == 1, "Bestands-Port darf beim Upgrade nicht verloren gehen")
        #expect(ports.first?.name == "Barcelona")
        #expect(ports.first?.cruise?.id == cruiseID, "Relationship Port -> Cruise muss über die Migration erhalten bleiben")

        // Neue Tabellen sind leer, aber einfüg- und abfragbar (kein Crash bei leerem Store).
        #expect(try upgradedContext.fetch(FetchDescriptor<CustomShippingLine>()).isEmpty)
        #expect(try upgradedContext.fetch(FetchDescriptor<CustomShip>()).isEmpty)
        #expect(try upgradedContext.fetch(FetchDescriptor<HiddenCatalogItem>()).isEmpty)

        let customLine = CustomShippingLine(name: "Neue Flussreederei")
        upgradedContext.insert(customLine)
        try upgradedContext.save()

        let customLines = try upgradedContext.fetch(FetchDescriptor<CustomShippingLine>())
        #expect(customLines.count == 1)
        #expect(customLines.first?.name == "Neue Flussreederei")

        // (3) Idempotenz: ein zweites Öffnen desselben migrierten Stores darf nicht crashen und
        // muss weiterhin sowohl Bestands- als auch neue Daten liefern.
        let reopenedConfig = ModelConfiguration(schema: currentEightModelSchema, url: storeURL)
        let reopenedContainer = try ModelContainer(for: currentEightModelSchema, configurations: reopenedConfig)
        let reopenedContext = reopenedContainer.mainContext

        #expect(try reopenedContext.fetch(FetchDescriptor<Cruise>()).count == 1)
        #expect(try reopenedContext.fetch(FetchDescriptor<CustomShippingLine>()).count == 1)
    }
}
