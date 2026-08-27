//
//  JournalEntryModelTests.swift
//  ShipTripTests
//
//  Modell-Naht J1 aus ADR-003: Felder, Defaults, Beziehungen, Löschregeln und
//  CloudKit-Konformität des Journal-Kerns.
//

import Testing
import Foundation
import SwiftData
@testable import ShipTrip

private typealias CruisePort = ShipTrip.Port

// MARK: - Felder und Defaults

@Suite("JournalEntry — Felder und Defaults (J1)")
struct JournalEntryFieldTests {

    @Test("Ein frischer Eintrag trägt die Contract-Defaults")
    @MainActor
    func defaultsMatchContract() throws {
        let container = try makeJournalContainer()
        let context = container.mainContext
        let entry = JournalEntry()
        context.insert(entry)
        try context.save()

        #expect(entry.text == "")
        #expect(entry.moodRaw == "")
        #expect(entry.cruise == nil)
        #expect(entry.port == nil)
        #expect(entry.photos.isEmpty)
        #expect(entry.createdAt == entry.updatedAt, "Beim Insert gilt updatedAt == createdAt (J2a)")
        #expect(
            JournalDay.utcCalendar.component(.hour, from: entry.entryDate) == 12,
            "entryDate wird auch ohne explizite Tageswahl auf 12:00 UTC normalisiert"
        )
    }

    @Test("Ein neues Foto hat eine leere Caption und keinen Journal-Bezug")
    @MainActor
    func photoDefaults() throws {
        let container = try makeJournalContainer()
        let context = container.mainContext
        let cruise = makeJournalCruise(context)
        let photo = makeJournalPhoto(context, cruise: cruise)
        try context.save()

        #expect(photo.caption == "")
        #expect(photo.journalEntry == nil)
        #expect(photo.cruise?.id == cruise.id)
    }
}

// MARK: - CRUD

@Suite("JournalEntry — CRUD")
struct JournalEntryCRUDTests {

    @Test("Eintrag anlegen, lesen, ändern, löschen")
    @MainActor
    func createReadUpdateDelete() throws {
        let container = try makeJournalContainer()
        let context = container.mainContext
        let cruise = makeJournalCruise(context)
        let port = CruisePort(name: "Bergen", country: "Norwegen", latitude: 60.39, longitude: 5.32)
        port.cruise = cruise
        context.insert(port)

        let entry = JournalEntry(text: "Erster Seetag", moodRaw: "good")
        entry.cruise = cruise
        entry.setPort(port)
        context.insert(entry)
        try context.save()

        // Lesen über die Reise-Beziehung.
        let cruises = try context.fetch(FetchDescriptor<Cruise>())
        let stored = try #require(cruises.first)
        #expect(stored.journalEntries.count == 1)
        #expect(stored.journalEntries.first?.text == "Erster Seetag")
        #expect(stored.journalEntries.first?.port?.name == "Bergen")

        // Ändern.
        entry.setText("Erster Seetag, ruhige See")
        entry.setMoodRaw("great")
        try context.save()
        #expect(try context.fetch(FetchDescriptor<JournalEntry>()).first?.moodRaw == "great")

        // Löschen.
        JournalDeletePaths.deleteEntry(entry, in: context)
        try context.save()
        #expect(try context.fetch(FetchDescriptor<JournalEntry>()).isEmpty)
    }

    @Test("Mehrere Einträge am selben Tag sind erlaubt")
    @MainActor
    func allowsMultipleEntriesPerDay() throws {
        let container = try makeJournalContainer()
        let context = container.mainContext
        let cruise = makeJournalCruise(context)
        let day = Date(timeIntervalSince1970: 1_780_100_000)

        for text in ["Morgens am Deck", "Abends im Hafen"] {
            let entry = JournalEntry(text: text, localDay: day)
            entry.cruise = cruise
            context.insert(entry)
        }
        try context.save()

        let entries = try context.fetch(FetchDescriptor<JournalEntry>())
        #expect(entries.count == 2)
        #expect(
            JournalDay.isSameDay(
                entryDate: try #require(entries.first).entryDate,
                otherEntryDate: try #require(entries.last).entryDate
            )
        )
    }

    @Test("Ein unbekannter moodRaw-Rohwert bleibt verbatim erhalten (Unknown-Preservation)")
    @MainActor
    func preservesUnknownMoodRaw() throws {
        let container = try makeJournalContainer()
        let context = container.mainContext
        let entry = JournalEntry(moodRaw: "euphoric-from-a-newer-version")
        context.insert(entry)
        try context.save()

        #expect(
            try context.fetch(FetchDescriptor<JournalEntry>()).first?.moodRaw
                == "euphoric-from-a-newer-version"
        )
    }
}

// MARK: - Löschregeln

@Suite("JournalEntry — Löschregeln (J1)")
struct JournalEntryDeleteRuleTests {

    @Test("Reise löschen entfernt ihre Einträge (cascade)")
    @MainActor
    func deletingCruiseCascadesToEntries() throws {
        let container = try makeJournalContainer()
        let context = container.mainContext
        let cruise = makeJournalCruise(context)
        let entry = JournalEntry(text: "Ankunft")
        entry.cruise = cruise
        context.insert(entry)
        try context.save()

        context.delete(cruise)
        try context.save()

        #expect(try context.fetch(FetchDescriptor<JournalEntry>()).isEmpty)
    }

    @Test("Eintrag löschen lässt die Fotos in der Reise-Galerie zurück (nullify)")
    @MainActor
    func deletingEntryKeepsPhotosInGallery() throws {
        let container = try makeJournalContainer()
        let context = container.mainContext
        let cruise = makeJournalCruise(context)
        let photo = makeJournalPhoto(context, cruise: cruise)
        let entry = JournalEntry(text: "Mit Foto")
        entry.cruise = cruise
        context.insert(entry)
        entry.attach(photo)
        try context.save()

        JournalDeletePaths.deleteEntry(entry, in: context)
        try context.save()

        let photos = try context.fetch(FetchDescriptor<Photo>())
        #expect(photos.count == 1, "Das Foto bleibt Kind der Reise")
        #expect(photos.first?.journalEntry == nil)
        #expect(photos.first?.cruise?.id == cruise.id)
    }

    @Test("Hafen löschen lässt den Eintrag zurück und nullt nur den Bezug")
    @MainActor
    func deletingPortKeepsEntry() throws {
        let container = try makeJournalContainer()
        let context = container.mainContext
        let cruise = makeJournalCruise(context)
        let port = CruisePort(name: "Tromsø", country: "Norwegen", latitude: 69.6, longitude: 18.9)
        port.cruise = cruise
        context.insert(port)
        let entry = JournalEntry(text: "Nordlicht")
        entry.cruise = cruise
        entry.setPort(port)
        context.insert(entry)
        try context.save()

        JournalDeletePaths.deletePort(port, in: context)
        try context.save()

        let entries = try context.fetch(FetchDescriptor<JournalEntry>())
        #expect(entries.count == 1)
        #expect(entries.first?.port == nil)
        #expect(entries.first?.cruise?.id == cruise.id)
    }
}

// MARK: - CloudKit-Konformität

@Suite("JournalEntry — CloudKit-Konformität (ADR-002 §3)")
struct JournalEntrySchemaTests {

    @Test("JournalEntry ist im App-Schema explizit registriert")
    func journalEntryIsPartOfAppSchema() throws {
        let names = makeJournalAppSchema().entities.map(\.name)
        #expect(
            names.contains("JournalEntry"),
            "JournalEntry muss in ShipTripApp.init explizit im Schema stehen"
        )
    }

    @Test("Keine Uniqueness-Constraints auf den neuen Entitäten")
    func newEntitiesHaveNoUniquenessConstraints() throws {
        for name in ["JournalEntry", "Photo"] {
            let entity = try #require(makeJournalAppSchema().entities.first { $0.name == name })
            #expect(
                entity.uniquenessConstraints.isEmpty,
                "\(name) darf keine .unique-Constraints tragen"
            )
        }
    }

    @Test("Alle Journal-Beziehungen sind optional")
    func journalRelationshipsAreOptional() throws {
        let entities = makeJournalAppSchema().entities
        let entity = try #require(entities.first { $0.name == "JournalEntry" })
        let nonOptional = entity.relationships.filter { !$0.isOptional }.map(\.name)
        #expect(nonOptional.isEmpty, "CloudKit verlangt optionale Beziehungen: \(nonOptional)")
    }

    @Test("Die Löschregeln entsprechen der Contract-Tabelle J1")
    func deleteRulesMatchContract() throws {
        func rule(
            _ entityName: String,
            _ relationship: String
        ) throws -> Schema.Relationship.DeleteRule {
            let entities = makeJournalAppSchema().entities
            let entity = try #require(entities.first { $0.name == entityName })
            return try #require(entity.relationships.first { $0.name == relationship }).deleteRule
        }

        #expect(try rule("Cruise", "journalEntriesStorage") == .cascade)
        #expect(try rule("Port", "journalEntriesStorage") == .nullify)
        #expect(try rule("JournalEntry", "photosStorage") == .nullify)
    }
}
