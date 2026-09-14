//
//  JournalExportRoundtripTests.swift
//  ShipTripTests
//
//  Contract-Fixtures (b) und (c) aus ADR-003 → „Export- und Teilen-Integration":
//  Journal-Einträge und Foto-Captions überleben BEIDE Türen — ZIP-Backup und
//  `.shiptrip`-Teilen — verlustfrei, inklusive Seetag-Eintrag ohne Hafen, mehrerer
//  Einträge pro Tag und eines unbekannten `moodRaw`. Dazu die Randfälle des Contracts:
//  Import-Normalisierung des `entryDate`, stilles Verwerfen nicht auflösbarer Bezüge,
//  Zählgrenze und `isDemo`-Filterung.
//

import Testing
import Foundation
import SwiftData
@testable import ShipTrip

private typealias CruisePort = ShipTrip.Port

// MARK: - Fixture

/// Der Tag, an dem zwei Einträge liegen (Kalendertag, nicht Zeitstempel).
private let journalDayOne = DateComponents(year: 2026, month: 5, day: 3)
private let journalDayTwo = DateComponents(year: 2026, month: 5, day: 4)

/// Ein Roh-String, den diese App-Version nicht kennt (Unknown-Preservation, J4).
private let unknownMoodRaw = "aurora-borealis"

private struct JournalFixtureError: Error {}

/// Eine Reise mit Journal: Seetag-Eintrag ohne Hafen, zweiter Eintrag am selben Tag mit
/// Hafenbezug und angehängtem Foto, dritter Eintrag am Folgetag mit unbekannter Stimmung.
@MainActor
private func makeJournalExportCruise(in context: ModelContext) throws -> Cruise {
    let cruise = makeJournalCruise(context, title: "Nordkap")
    let bergen = makeJournalPort(context, cruise: cruise)

    let captioned = Photo(imageData: journalFixturePNG, sortOrder: 0)
    captioned.cruise = cruise
    captioned.caption = "Mitternachtssonne über dem Fjord"
    context.insert(captioned)

    let plain = Photo(imageData: journalFixturePNG, sortOrder: 1)
    plain.cruise = cruise
    context.insert(plain)

    guard let dayOne = JournalDay.entryDate(fromDayComponents: journalDayOne),
          let dayTwo = JournalDay.entryDate(fromDayComponents: journalDayTwo) else {
        throw JournalFixtureError()
    }

    // `entryDate` wird direkt auf den kanonischen Wert gesetzt (12:00 UTC des Tag-Tripels)
    // statt über `localDay` — sonst hinge das Fixture an der Zeitzone der Test-Lane.

    // (1) Seetag: kein Hafen, keine Fotos, keine Stimmung.
    let seaDayEntry = JournalEntry(text: "Den ganzen Tag nur Wasser.")
    seaDayEntry.entryDate = dayOne
    seaDayEntry.cruise = cruise
    context.insert(seaDayEntry)

    // (2) Zweiter Eintrag am selben Tag — mit Hafen und Foto.
    let portEntry = JournalEntry(text: "Abends noch an Land.", moodRaw: "happy")
    portEntry.entryDate = dayOne
    portEntry.cruise = cruise
    context.insert(portEntry)
    portEntry.setPort(bergen)
    portEntry.attach(captioned)

    // (3) Folgetag mit einem Rohwert, den diese Version nicht kennt.
    let unknownMoodEntry = JournalEntry(text: "Nordlicht!", moodRaw: unknownMoodRaw)
    unknownMoodEntry.entryDate = dayTwo
    unknownMoodEntry.cruise = cruise
    context.insert(unknownMoodEntry)

    try context.save()
    return cruise
}

/// Prüft die angekommene Reise gegen das Fixture — identisch für beide Türen.
@MainActor
private func expectJournalArrivedIntact(_ arrived: Cruise) throws {
    #expect(arrived.journalEntries.count == 3)

    let dayOneEntries = arrived.journalEntries.filter {
        JournalDay.dayComponents(ofEntryDate: $0.entryDate) == journalDayOne
    }
    #expect(dayOneEntries.count == 2)

    let seaDay = try #require(
        arrived.journalEntries.first { $0.text == "Den ganzen Tag nur Wasser." }
    )
    #expect(seaDay.port == nil)
    #expect(seaDay.photos.isEmpty)
    #expect(seaDay.moodRaw == "")

    let portEntry = try #require(arrived.journalEntries.first { $0.text == "Abends noch an Land." })
    #expect(portEntry.moodRaw == "happy")
    #expect(portEntry.port?.name == "Bergen")
    #expect(portEntry.photos.count == 1)
    #expect(portEntry.photos.first?.caption == "Mitternachtssonne über dem Fjord")
    // Angehängte Fotos bleiben zugleich Kinder der Reise (ADR-003).
    #expect(portEntry.photos.first?.cruise?.id == arrived.id)

    let unknownMood = try #require(arrived.journalEntries.first { $0.text == "Nordlicht!" })
    // Rohwert verbatim — nicht auf "" normalisiert, weil unbekannt (J4).
    #expect(unknownMood.moodRaw == unknownMoodRaw)
    #expect(JournalDay.dayComponents(ofEntryDate: unknownMood.entryDate) == journalDayTwo)

    // Alle Kalendertage kanonisch auf 12:00 UTC verankert.
    for entry in arrived.journalEntries {
        let expected = JournalDay.entryDate(
            fromDayComponents: JournalDay.dayComponents(ofEntryDate: entry.entryDate)
        )
        #expect(entry.entryDate == expected)
    }

    // Das Foto ohne Unterschrift bleibt leer — kein „nil wird zu null"-Unfall.
    #expect(arrived.photos.filter { $0.caption.isEmpty }.count == 1)
}

// MARK: - Roundtrip über beide Türen

@Suite("Journal-Export: Roundtrip über ZIP und Teilen")
@MainActor
struct JournalExportRoundtripTests {

    @Test("ZIP-Roundtrip: Einträge, Bezüge und Captions kommen verlustfrei an")
    func zipRoundtripPreservesJournal() async throws {
        let source = try makeJournalContainer()
        let cruise = try makeJournalExportCruise(in: source.mainContext)
        let expectedUpdatedAt = Dictionary(
            uniqueKeysWithValues: cruise.journalEntries.map { ($0.id, $0.updatedAt) }
        )

        let url = try await ExportImportService.shared.exportToZip(cruises: [cruise])
        defer { try? FileManager.default.removeItem(at: url) }

        let target = try makeJournalContainer()
        let context = target.mainContext
        let result = try ExportImportService.shared.importFromZip(url: url, modelContext: context)
        #expect(result.imported == 1)
        #expect(result.invalidMedia == 0)

        let arrived = try #require(try context.fetch(FetchDescriptor<Cruise>()).first)
        try expectJournalArrivedIntact(arrived)

        // Stabile IDs und LWW-Zeitstempel überleben den Roundtrip (Millisekunden-Auflösung
        // des ISO-Formatters).
        for entry in arrived.journalEntries {
            let expected = try #require(expectedUpdatedAt[entry.id])
            #expect(abs(entry.updatedAt.timeIntervalSince(expected)) < 0.002)
            #expect(entry.createdAt <= entry.updatedAt)
        }
    }

    @Test("Teilen-Roundtrip: dieselbe Reise über .shiptrip kommt verlustfrei an")
    func shareRoundtripPreservesJournal() async throws {
        let source = try makeJournalContainer()
        let cruise = try makeJournalExportCruise(in: source.mainContext)

        let url = try await ExportImportService.shared.exportCruiseForSharing(cruise)
        defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }

        let target = try makeJournalContainer()
        let context = ModelContext(target)
        let result = try await ExportImportService.shared.importSharedCruise(
            from: url, modelContext: context
        )
        #expect(result.base.imported == 1)
        #expect(result.base.invalidMedia == 0)

        let arrived = try #require(try context.fetch(FetchDescriptor<Cruise>()).first)
        try expectJournalArrivedIntact(arrived)
    }

    /// Die Beispielreise bleibt aus beiden Türen gefiltert — auch mit Journal-Nutzlast.
    @Test("Demo-Reise mit Journal-Einträgen landet nicht im Export")
    func demoCruiseWithJournalIsFilteredOut() throws {
        let source = try makeJournalContainer()
        let context = source.mainContext
        let cruise = try makeJournalExportCruise(in: context)
        cruise.isDemo = true
        try context.save()

        let url = try ExportImportService.shared.exportToJSON(cruises: [cruise])
        defer { try? FileManager.default.removeItem(at: url) }

        let archive = try ExportArchive.decode(from: Data(contentsOf: url))
        #expect(archive.cruises.isEmpty)
    }
}

// MARK: - Contract-Randfälle des Imports

@Suite("Journal-Import: Normalisierung, verwaiste Bezüge, Zählgrenze")
@MainActor
struct JournalImportContractTests {

    /// Baut ein Backup-Archiv mit genau einem Journal-Eintrag und den übergebenen Bezügen.
    private func archive(
        cruiseID: String = UUID().uuidString,
        entryDate: String,
        portId: String?,
        photoIds: [String]
    ) -> ExportArchive {
        let entry = ExportJournalEntry(
            id: UUID().uuidString,
            text: "Fremddatei",
            entryDate: entryDate,
            moodRaw: "",
            createdAt: "2026-05-03T09:00:00.000Z",
            updatedAt: "2026-05-03T09:30:00.000Z",
            portId: portId,
            photoIds: photoIds
        )
        var cruise = makeShareCruise(rawID: cruiseID, portCount: 1)
        cruise.journalEntries = [entry]
        return makeBackupArchive(cruises: [cruise])
    }

    @Test("Unnormalisiertes entryDate landet auf 12:00 UTC seines UTC-Tages")
    func importNormalizesEntryDate() throws {
        let data = try encodeArchiveJSON(
            archive(entryDate: "2026-05-03T23:30:00.000Z", portId: nil, photoIds: [])
        )

        let container = try makeJournalContainer()
        let context = container.mainContext
        let result = try ExportImportService.shared.importFromJSONData(
            data: data, imagesDir: nil, modelContext: context
        )
        #expect(result.imported == 1)

        let entry = try #require(try context.fetch(FetchDescriptor<JournalEntry>()).first)
        #expect(JournalDay.dayComponents(ofEntryDate: entry.entryDate) == journalDayOne)
        #expect(entry.entryDate == JournalDay.entryDate(fromDayComponents: journalDayOne))
    }

    @Test("Nicht auflösbare Hafen-/Foto-IDs werden still verworfen, der Eintrag bleibt")
    func unresolvableReferencesAreDroppedSilently() throws {
        let data = try encodeArchiveJSON(archive(
            entryDate: "2026-05-03T12:00:00.000Z",
            portId: UUID().uuidString,        // gehört zu keinem Hafen dieser Reise
            photoIds: [UUID().uuidString]     // gehört zu keinem Foto dieser Reise
        ))

        let container = try makeJournalContainer()
        let context = container.mainContext
        let result = try ExportImportService.shared.importFromJSONData(
            data: data, imagesDir: nil, modelContext: context
        )
        #expect(result.imported == 1)
        #expect(result.skippedInvalid == 0)

        let entry = try #require(try context.fetch(FetchDescriptor<JournalEntry>()).first)
        #expect(entry.text == "Fremddatei")
        #expect(entry.port == nil)
        #expect(entry.photos.isEmpty)
    }

    @Test("Mehr als maxJournalEntries Einträge lehnt der Share-Preflight ab")
    func preflightRejectsTooManyJournalEntries() throws {
        let entries = (0...ShareArchiveLimits.maxJournalEntries).map { index in
            ExportJournalEntry(
                id: UUID().uuidString,
                text: "Eintrag \(index)",
                entryDate: "2026-05-03T12:00:00.000Z",
                moodRaw: "",
                createdAt: "2026-05-03T09:00:00.000Z",
                updatedAt: "2026-05-03T09:00:00.000Z",
                portId: nil,
                photoIds: []
            )
        }
        var cruise = makeShareCruise()
        cruise.journalEntries = entries

        #expect(throws: ShareImportError.self) {
            try SharePreflight.validateArchive(makeShareArchive(cruises: [cruise]))
        }
        // Die Gegenprobe genau an der Grenze muss durchgehen.
        var atLimit = makeShareCruise()
        atLimit.journalEntries = Array(entries.dropLast())
        try SharePreflight.validateArchive(makeShareArchive(cruises: [atLimit]))
    }
}
