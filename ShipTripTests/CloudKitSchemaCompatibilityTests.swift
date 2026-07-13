//
//  CloudKitSchemaCompatibilityTests.swift
//  ShipTripTests
//

import Testing
import CoreData
import SwiftData
@testable import ShipTrip

@Suite("CloudKit-Schema-Kompatibilität")
struct CloudKitSchemaCompatibilityTests {

    private var schema: Schema {
        Schema([
            Cruise.self,
            Port.self,
            Expense.self,
            Deal.self,
            Photo.self,
            CustomShippingLine.self,
            CustomShip.self,
            HiddenCatalogItem.self
        ])
    }

    @Test("Alle SwiftData-Beziehungen sind für CloudKit optional")
    func allRelationshipsAreOptional() {
        let nonOptionalRelationships = schema.entities.flatMap { entity in
            entity.relationships
                .filter { !$0.isOptional }
                .map { "\(entity.name).\($0.name)" }
        }

        #expect(
            nonOptionalRelationships.isEmpty,
            "CloudKit unterstützt keine nicht-optionalen Beziehungen: \(nonOptionalRelationships)"
        )
    }

    @Test("Die persistente Konfiguration verwendet den privaten ShipTrip-Container")
    func persistentConfigurationUsesPrivateContainer() {
        let configuration = ShipTripCloudSync.persistentConfiguration(for: schema, environment: [:])

        #expect(ShipTripCloudSync.containerIdentifier == "iCloud.com.andre.ShipTrip")
        #expect(configuration.cloudKitContainerIdentifier == ShipTripCloudSync.containerIdentifier)
        #expect(!configuration.isStoredInMemoryOnly)
    }

    @Test("Unit-Tests öffnen denselben Store ohne CloudKit-Mirroring")
    func unitTestsDisableCloudKitMirroring() {
        let configuration = ShipTripCloudSync.persistentConfiguration(
            for: schema,
            environment: ["XCTestConfigurationFilePath": "/tmp/ShipTripTests.xctestconfiguration"],
            arguments: []
        )

        #expect(configuration.cloudKitContainerIdentifier == nil)
        #expect(!configuration.isStoredInMemoryOnly)
    }

    @Test("UI-Test-Reset öffnet keinen CloudKit-Store")
    func uiTestResetDisablesCloudKitMirroring() {
        let configuration = ShipTripCloudSync.persistentConfiguration(
            for: schema,
            environment: [:],
            arguments: ["ShipTrip", "-uiTestingResetAndLoadDemoData"]
        )

        #expect(configuration.cloudKitContainerIdentifier == nil)
    }

    @Test("Core Data kann aus dem SwiftData-Modell ein CloudKit-Schema erzeugen")
    @MainActor
    func coreDataModelCanBeGenerated() throws {
        let types: [any PersistentModel.Type] = [
            Cruise.self,
            Port.self,
            Expense.self,
            Deal.self,
            Photo.self,
            CustomShippingLine.self,
            CustomShip.self,
            HiddenCatalogItem.self
        ]

        _ = try #require(NSManagedObjectModel.makeManagedObjectModel(for: types))
    }
}
