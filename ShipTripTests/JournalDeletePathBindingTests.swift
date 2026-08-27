//
//  JournalDeletePathBindingTests.swift
//  ShipTripTests
//
//  Bindung der produktiven Lösch-Einstiege an `JournalDeletePaths` (T8-Auflage,
//  Contract J2a). Repro-Test zum Go-Live-Blocker: die UI löschte Ports direkt
//  über `modelContext.delete(...)`, wodurch SwiftData den Journal-Bezug still
//  nullte und der betroffene Eintrag mit altem `updatedAt` zurückblieb — beim
//  CloudKit-Merge (LWW, ADR-002 §2) ginge das Lösen damit verloren.
//

import Testing
import Foundation
import SwiftData
@testable import ShipTrip

@Suite("Journal-Lösch-Pfade der UI-Einstiege (J2a)")
@MainActor
struct JournalDeletePathBindingTests {

    @Test("reconcileRoute: ein entfernter Hafen bumpt seine Journal-Einträge")
    func removingPortViaReconcileBumpsJournalEntries() throws {
        let container = try makeJournalContainer()
        let context = container.mainContext

        let cruise = makeJournalCruise(context)
        let port = makeJournalPort(context, cruise: cruise)
        let entry = JournalEntry(text: "Bergen war grandios", now: JournalTestClock.insert)
        entry.cruise = cruise
        context.insert(entry)
        entry.setPort(port, at: JournalTestClock.insert)
        let entryID = entry.id
        try context.save()

        // Der Hafen fällt beim Speichern des Formulars aus der Route heraus.
        _ = reconcileRoute(
            existingPorts: [port],
            tempPorts: [],
            cruise: cruise,
            modelContext: context
        )
        try context.save()

        let stored = try #require(try refetchJournalEntry(id: entryID, from: container))
        #expect(stored.port == nil)
        // Der Bump ist der eigentliche Vertrag: ohne ihn gewinnt beim Merge die
        // alte Fassung mit Hafen-Bezug.
        #expect(stored.updatedAt > JournalTestClock.insert)
    }
}
