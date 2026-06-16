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
        IdBackfill.run(context: context)

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

        let sharedID = UUID()

        let c1 = Cruise(title: "Idem1", startDate: .now, endDate: .now, shippingLine: "Y", ship: "T1")
        c1.id = sharedID
        let c2 = Cruise(title: "Idem2", startDate: .now, endDate: .now, shippingLine: "Y", ship: "T2")
        c2.id = sharedID
        context.insert(c1); context.insert(c2)
        try context.save()

        // Erster Aufruf: repariert
        IdBackfill.run(context: context)

        let afterFirst = try context.fetch(FetchDescriptor<Cruise>())
        let idsAfterFirst = Set(afterFirst.map(\.id))
        #expect(idsAfterFirst.count == 2)

        // Zweiter Aufruf: darf nichts ändern
        IdBackfill.run(context: context)

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

        let sharedID = UUID()

        let p1 = CruisePort(name: "Hamburg", country: "DE", latitude: 53.5, longitude: 9.9)
        p1.id = sharedID
        let p2 = CruisePort(name: "Barcelona", country: "ES", latitude: 41.4, longitude: 2.2)
        p2.id = sharedID

        context.insert(p1); context.insert(p2)
        try context.save()

        IdBackfill.run(context: context)

        let ports = try context.fetch(FetchDescriptor<CruisePort>())
        #expect(ports.count == 2)
        #expect(Set(ports.map(\.id)).count == 2, "Port-UUIDs wurden nicht dedupliziert")
    }
}
