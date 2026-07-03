//
//  CruiseFormRouteReconciliationTests.swift
//  ShipTripTests
//
//  Tests für `reconcileRoute` (CruiseFormView.swift): Edit-Pfad darf Ports nicht mehr
//  löschen und neu anlegen, sondern muss bestehende Ports per ID in-place aktualisieren
//  (ID-Stabilität für CloudKit-Last-Writer-Wins, ADR-002).
//

import Testing
import Foundation
import SwiftData
@testable import ShipTrip

private typealias CruisePort = ShipTrip.Port

// MARK: - Fixture-Helfer

private func makeInMemoryContainer() throws -> ModelContainer {
    let schema = Schema([Cruise.self, CruisePort.self, Expense.self, Deal.self, Photo.self])
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    return try ModelContainer(for: schema, configurations: config)
}

/// Baut eine `TempPort`-Repräsentation eines bestehenden `Port`, wie es
/// `CruiseFormView.loadExistingData()` tut (inkl. `id`, `excursionsRaw`, `imageData`).
private func tempPort(from port: CruisePort) -> TempPort {
    TempPort(
        id: port.id,
        name: port.name,
        country: port.country,
        arrival: port.arrival,
        departure: port.departure,
        latitude: port.latitude,
        longitude: port.longitude,
        isSeaDay: port.isSeaDay,
        excursionsRaw: port.excursionsRaw,
        imageData: port.imageData
    )
}

@Suite("CruiseFormView Route Reconciliation")
struct CruiseFormRouteReconciliationTests {

    // MARK: No-op Edit

    @Test("No-op-Edit: IDs, excursionsRaw und imageData bleiben identisch")
    @MainActor
    func noOpEditPreservesIdentityAndPayload() throws {
        let container = try makeInMemoryContainer()
        let context = container.mainContext

        let cruise = Cruise(
            title: "Test",
            startDate: Date(),
            endDate: Date().addingTimeInterval(7 * 86400),
            shippingLine: "MSC",
            ship: "Bellissima"
        )
        context.insert(cruise)

        let port1 = CruisePort(name: "Hamburg", country: "Deutschland", latitude: 53.5, longitude: 9.9)
        port1.excursionsRaw = "Stadtrundfahrt, Hafenrundfahrt"
        port1.imageData = Data([0x01, 0x02, 0x03])
        port1.sortOrder = 0
        port1.cruise = cruise
        context.insert(port1)

        let port2 = CruisePort(name: "Kopenhagen", country: "Dänemark", latitude: 55.6, longitude: 12.5)
        port2.sortOrder = 1
        port2.cruise = cruise
        context.insert(port2)

        try context.save()

        let originalID1 = port1.id
        let originalID2 = port2.id
        let originalUpdatedAt1 = port1.updatedAt
        let originalUpdatedAt2 = port2.updatedAt

        let tempPorts = [tempPort(from: port1), tempPort(from: port2)]

        reconcileRoute(
            existingPorts: cruise.route,
            tempPorts: tempPorts,
            cruise: cruise,
            modelContext: context
        )
        try context.save()

        let route = cruise.route.sorted { $0.sortOrder < $1.sortOrder }
        #expect(route.count == 2)
        #expect(route[0].id == originalID1)
        #expect(route[1].id == originalID2)
        #expect(route[0].excursionsRaw == "Stadtrundfahrt, Hafenrundfahrt")
        #expect(route[0].imageData == Data([0x01, 0x02, 0x03]))
        #expect(route[0].updatedAt == originalUpdatedAt1, "updatedAt darf sich bei unveränderten Feldern nicht ändern")
        #expect(route[1].updatedAt == originalUpdatedAt2)
    }

    // MARK: Reorder

    @Test("Reorder: IDs bleiben erhalten, sortOrder entspricht neuer Reihenfolge")
    @MainActor
    func reorderPreservesIDsAndUpdatesSortOrder() throws {
        let container = try makeInMemoryContainer()
        let context = container.mainContext

        let cruise = Cruise(
            title: "Test",
            startDate: Date(),
            endDate: Date().addingTimeInterval(7 * 86400),
            shippingLine: "AIDA",
            ship: "AIDAmar"
        )
        context.insert(cruise)

        let port1 = CruisePort(name: "A", country: "Land A", latitude: 1, longitude: 1)
        port1.sortOrder = 0
        port1.cruise = cruise
        context.insert(port1)

        let port2 = CruisePort(name: "B", country: "Land B", latitude: 2, longitude: 2)
        port2.sortOrder = 1
        port2.cruise = cruise
        context.insert(port2)

        let port3 = CruisePort(name: "C", country: "Land C", latitude: 3, longitude: 3)
        port3.sortOrder = 2
        port3.cruise = cruise
        context.insert(port3)

        try context.save()

        let id1 = port1.id
        let id2 = port2.id
        let id3 = port3.id

        // Neue Reihenfolge: C, A, B
        let reordered = [tempPort(from: port3), tempPort(from: port1), tempPort(from: port2)]

        reconcileRoute(
            existingPorts: cruise.route,
            tempPorts: reordered,
            cruise: cruise,
            modelContext: context
        )
        try context.save()

        let route = cruise.route.sorted { $0.sortOrder < $1.sortOrder }
        #expect(route.map { $0.id } == [id3, id1, id2])
        #expect(route[0].name == "C" && route[0].sortOrder == 0)
        #expect(route[1].name == "A" && route[1].sortOrder == 1)
        #expect(route[2].name == "B" && route[2].sortOrder == 2)
    }

    // MARK: Remove

    @Test("Remove: nur der entfernte Port wird gelöscht, Rest-IDs bleiben unverändert")
    @MainActor
    func removePortDeletesOnlyThatPort() throws {
        let container = try makeInMemoryContainer()
        let context = container.mainContext

        let cruise = Cruise(
            title: "Test",
            startDate: Date(),
            endDate: Date().addingTimeInterval(7 * 86400),
            shippingLine: "TUI",
            ship: "Mein Schiff 4"
        )
        context.insert(cruise)

        let port1 = CruisePort(name: "A", country: "Land A", latitude: 1, longitude: 1)
        port1.sortOrder = 0
        port1.cruise = cruise
        context.insert(port1)

        let port2 = CruisePort(name: "B", country: "Land B", latitude: 2, longitude: 2)
        port2.sortOrder = 1
        port2.cruise = cruise
        context.insert(port2)

        let port3 = CruisePort(name: "C", country: "Land C", latitude: 3, longitude: 3)
        port3.sortOrder = 2
        port3.cruise = cruise
        context.insert(port3)

        try context.save()

        let id1 = port1.id
        let id3 = port3.id
        let removedID = port2.id

        // Hafen B entfernen
        let remaining = [tempPort(from: port1), tempPort(from: port3)]

        reconcileRoute(
            existingPorts: cruise.route,
            tempPorts: remaining,
            cruise: cruise,
            modelContext: context
        )
        try context.save()

        let route = cruise.route
        #expect(route.count == 2)
        #expect(Set(route.map { $0.id }) == Set([id1, id3]))

        let fetchedRemoved = try context.fetch(FetchDescriptor<CruisePort>()).first { $0.id == removedID }
        #expect(fetchedRemoved == nil, "Entfernter Hafen muss aus dem Kontext gelöscht sein")
    }

    // MARK: Add

    @Test("Add: genau ein neuer Port entsteht, bestehende IDs bleiben unverändert")
    @MainActor
    func addPortCreatesExactlyOneNewPort() throws {
        let container = try makeInMemoryContainer()
        let context = container.mainContext

        let cruise = Cruise(
            title: "Test",
            startDate: Date(),
            endDate: Date().addingTimeInterval(7 * 86400),
            shippingLine: "Costa",
            ship: "Costa Smeralda"
        )
        context.insert(cruise)

        let port1 = CruisePort(name: "A", country: "Land A", latitude: 1, longitude: 1)
        port1.sortOrder = 0
        port1.cruise = cruise
        context.insert(port1)

        let port2 = CruisePort(name: "B", country: "Land B", latitude: 2, longitude: 2)
        port2.sortOrder = 1
        port2.cruise = cruise
        context.insert(port2)

        try context.save()

        let id1 = port1.id
        let id2 = port2.id

        let newPort = TempPort(
            name: "Neuer Hafen",
            country: "Land C",
            arrival: Date(),
            departure: Date(),
            latitude: 3,
            longitude: 3
        )

        let tempPorts = [tempPort(from: port1), tempPort(from: port2), newPort]

        reconcileRoute(
            existingPorts: cruise.route,
            tempPorts: tempPorts,
            cruise: cruise,
            modelContext: context
        )
        try context.save()

        let route = cruise.route.sorted { $0.sortOrder < $1.sortOrder }
        #expect(route.count == 3)
        #expect(route[0].id == id1)
        #expect(route[1].id == id2)
        #expect(route[2].id == newPort.id)
        #expect(route[2].name == "Neuer Hafen")
        #expect(route[2].cruise === cruise)
    }

    // MARK: Duplikat-IDs (Robustheit)

    @Test("Doppelte IDs im Altbestand werden toleriert: kein Crash, ein Port pro ID überlebt")
    @MainActor
    func duplicateExistingPortIDsAreDedupedWithoutCrash() throws {
        let container = try makeInMemoryContainer()
        let context = container.mainContext

        let cruise = Cruise(
            title: "Test",
            startDate: Date(),
            endDate: Date().addingTimeInterval(7 * 86400),
            shippingLine: "MSC",
            ship: "Seaside"
        )
        context.insert(cruise)

        // Simuliert den IdBackfill-Altfall: zwei Port-Objekte mit identischer UUID.
        let sharedID = UUID()

        let portA = CruisePort(name: "Palma", country: "Spanien", latitude: 39.5, longitude: 2.6)
        portA.id = sharedID
        portA.sortOrder = 0
        portA.cruise = cruise
        context.insert(portA)

        let portB = CruisePort(name: "Palma (Duplikat)", country: "Spanien", latitude: 39.5, longitude: 2.6)
        portB.id = sharedID
        portB.sortOrder = 1
        portB.cruise = cruise
        context.insert(portB)

        try context.save()
        #expect(cruise.route.count == 2, "Vorbedingung: Duplikat existiert im Altbestand")

        let temp = TempPort(
            id: sharedID,
            name: "Palma",
            country: "Spanien",
            arrival: Date(),
            departure: Date(),
            latitude: 39.5,
            longitude: 2.6
        )

        reconcileRoute(
            existingPorts: cruise.route,
            tempPorts: [temp],
            cruise: cruise,
            modelContext: context
        )
        try context.save()

        let route = cruise.route
        #expect(route.count == 1, "Nach Reconciliation darf nur ein Port mit der geteilten ID übrig bleiben")
        #expect(route.first?.id == sharedID)
    }

    @Test("Doppelte IDs in tempPorts erzeugen nur einen neuen Port")
    @MainActor
    func duplicateTempPortIDsCreateOnlyOnePort() throws {
        let container = try makeInMemoryContainer()
        let context = container.mainContext

        let cruise = Cruise(
            title: "Test",
            startDate: Date(),
            endDate: Date().addingTimeInterval(7 * 86400),
            shippingLine: "AIDA",
            ship: "AIDAperla"
        )
        context.insert(cruise)
        try context.save()

        let sharedID = UUID()
        let temp1 = TempPort(
            id: sharedID,
            name: "Málaga",
            country: "Spanien",
            arrival: Date(),
            departure: Date(),
            latitude: 36.7,
            longitude: -4.4
        )
        // Gleiche ID, abweichende Felder (simuliert einen inkonsistenten Zwischenzustand)
        var temp2 = temp1
        temp2.name = "Málaga (Duplikat)"

        reconcileRoute(
            existingPorts: cruise.route,
            tempPorts: [temp1, temp2],
            cruise: cruise,
            modelContext: context
        )
        try context.save()

        let route = cruise.route
        #expect(route.count == 1, "Duplikate IDs in tempPorts dürfen nur einen Port erzeugen")
        #expect(route.first?.id == sharedID)
        #expect(route.first?.name == "Málaga", "Der erste Eintrag gewinnt deterministisch")
    }
}
