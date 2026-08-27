//
//  JournalStoreFixtureMigrationTests.swift
//  ShipTripTests
//
//  Migrations-Beweis aus ADR-003 („Fixture-Plan", Schritt 3): ein eingefrorener
//  1.8.0-Store öffnet mit dem 1.8.5-Schema verlustfrei, neue Attribute tragen
//  ihre Defaults, die neue Journal-Tabelle ist leer, aber nutzbar.
//
//  Solange die Fixture fehlt, überspringen die Tests sauber (kein falsches
//  Grün). Erzeugung: `ShipTripTests/Fixtures/make-store-1.8.0-fixture.sh`
//  (braucht das Build-Token — läuft im Test-Build-Spawn, nicht hier).
//

import Testing
import Foundation
import SwiftData
@testable import ShipTrip

// MARK: - Fixture-Zugriff

enum JournalStoreFixture {

    /// Verzeichnis der eingefrorenen 1.8.0-Store-Dateien im Repo.
    static var directoryURL: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .appendingPathComponent("Fixtures/store-1.8.0", isDirectory: true)
    }

    static var storeURL: URL {
        directoryURL.appendingPathComponent("default.store")
    }

    static var isAvailable: Bool {
        FileManager.default.fileExists(atPath: storeURL.path)
    }

    /// Kopiert die Fixture in ein temporäres Verzeichnis — die Migration darf die
    /// eingefrorenen Dateien im Repo nie anfassen.
    static func copyToTemporaryLocation() throws -> URL {
        let temporaryDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("JournalStoreFixture-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(
            at: temporaryDirectory,
            withIntermediateDirectories: true
        )

        for suffix in ["", "-wal", "-shm"] {
            let source = URL(fileURLWithPath: storeURL.path + suffix)
            guard FileManager.default.fileExists(atPath: source.path) else { continue }
            try FileManager.default.copyItem(
                at: source,
                to: temporaryDirectory.appendingPathComponent(source.lastPathComponent)
            )
        }

        return temporaryDirectory.appendingPathComponent("default.store")
    }
}

// MARK: - Migrationstest

@Suite("Migration eines eingefrorenen 1.8.0-Stores (ADR-003)")
struct JournalStoreFixtureMigrationTests {

    @Test(
        "1.8.0-Store öffnet mit dem 1.8.5-Schema verlustfrei",
        .enabled(if: JournalStoreFixture.isAvailable, "Fixture store-1.8.0 fehlt")
    )
    @MainActor
    func opensLegacyStoreWithoutLoss() throws {
        let storeURL = try JournalStoreFixture.copyToTemporaryLocation()
        defer { try? FileManager.default.removeItem(at: storeURL.deletingLastPathComponent()) }

        let schema = makeJournalAppSchema()
        let configuration = ModelConfiguration(schema: schema, url: storeURL)
        let container = try ModelContainer(for: schema, configurations: configuration)
        let context = container.mainContext

        // (1) Bestandsdaten überleben.
        let cruises = try context.fetch(FetchDescriptor<Cruise>())
        #expect(!cruises.isEmpty, "Die Fixture muss mindestens eine Reise enthalten")
        for cruise in cruises {
            #expect(!cruise.title.isEmpty)
        }

        let ports = try context.fetch(FetchDescriptor<ShipTrip.Port>())
        #expect(!ports.isEmpty, "Die Fixture muss Häfen enthalten")
        #expect(ports.allSatisfy { $0.cruise != nil }, "Port → Cruise darf nicht reißen")

        // (2) Neue Attribute tragen ihre Defaults.
        let photos = try context.fetch(FetchDescriptor<Photo>())
        #expect(photos.allSatisfy { $0.caption == "" }, "Photo.caption startet leer")
        #expect(photos.allSatisfy { $0.journalEntry == nil }, "Alt-Fotos hängen an keinem Eintrag")

        // (3) Die neue Tabelle ist leer, aber nutzbar.
        #expect(try context.fetch(FetchDescriptor<JournalEntry>()).isEmpty)

        let cruise = try #require(cruises.first)
        let entry = JournalEntry(text: "Nach der Migration geschrieben")
        entry.cruise = cruise
        context.insert(entry)
        try context.save()

        #expect(try context.fetch(FetchDescriptor<JournalEntry>()).count == 1)
        #expect(cruise.journalEntries.count == 1)

        // (4) Zweites Öffnen des migrierten Stores bleibt stabil.
        let reopenedConfiguration = ModelConfiguration(schema: schema, url: storeURL)
        let reopened = try ModelContainer(for: schema, configurations: reopenedConfiguration)
        #expect(try reopened.mainContext.fetch(FetchDescriptor<Cruise>()).count == cruises.count)
        #expect(try reopened.mainContext.fetch(FetchDescriptor<JournalEntry>()).count == 1)
    }

    @Test(
        "Aggregate der Bestandsreisen bleiben nach der Migration rechenbar",
        .enabled(if: JournalStoreFixture.isAvailable, "Fixture store-1.8.0 fehlt")
    )
    @MainActor
    func aggregatesSurviveMigration() throws {
        let storeURL = try JournalStoreFixture.copyToTemporaryLocation()
        defer { try? FileManager.default.removeItem(at: storeURL.deletingLastPathComponent()) }

        let schema = makeJournalAppSchema()
        let configuration = ModelConfiguration(schema: schema, url: storeURL)
        let container = try ModelContainer(for: schema, configurations: configuration)
        let context = container.mainContext

        let cruises = try context.fetch(FetchDescriptor<Cruise>())
        let photoCountBefore = cruises.reduce(0) { $0 + $1.photos.count }
        let portStopsBefore = cruises.totalPortStops

        let entry = JournalEntry(text: "Aggregat-Probe")
        entry.cruise = cruises.first
        context.insert(entry)
        try context.save()

        #expect(cruises.reduce(0) { $0 + $1.photos.count } == photoCountBefore)
        #expect(cruises.totalPortStops == portStopsBefore)
    }
}
