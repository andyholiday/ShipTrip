//
//  JournalLWWMatrixTests.swift
//  ShipTripTests
//
//  Deckt die LWW-Mutations-Matrix J2a (journal-editor-contract.md) Zeile für
//  Zeile ab: `createdAt` einmalig beim Insert, `updatedAt` bei jeder Mutation —
//  inklusive der Nullify-Pfade, die SwiftData nicht automatisch bumpt.
//

import Testing
import Foundation
import SwiftData
@testable import ShipTrip

// MARK: - Fixture

@MainActor
private struct JournalFixture {
    let container: ModelContainer
    let context: ModelContext
    let cruise: Cruise
    let entry: JournalEntry

    init() throws {
        container = try makeJournalContainer()
        context = container.mainContext
        cruise = makeJournalCruise(context)
        entry = JournalEntry(text: "Erinnerung", now: JournalTestClock.insert)
        entry.cruise = cruise
        context.insert(entry)
    }

    /// Speichert und liest den Eintrag über einen frischen Kontext zurück.
    func savedAndRefetchedEntry() throws -> JournalEntry {
        try context.save()
        return try #require(refetchJournalEntry(id: entry.id, from: container))
    }
}

// MARK: - Insert

@Suite("J2a — Eintrag anlegen")
struct JournalInsertMatrixTests {

    @Test("Beim Anlegen ist updatedAt == createdAt")
    @MainActor
    func insertSetsBothTimestamps() throws {
        let fixture = try JournalFixture()
        try fixture.context.save()

        #expect(fixture.entry.createdAt == JournalTestClock.insert)
        #expect(fixture.entry.updatedAt == JournalTestClock.insert)
    }

    @Test("Ein beim Anlegen angehängtes Foto bekommt einen Zeitstempel")
    @MainActor
    func attachedPhotoGetsTimestampOnInsert() throws {
        let fixture = try JournalFixture()
        let photo = makeJournalPhoto(fixture.context, cruise: fixture.cruise)
        fixture.entry.attach(photo, at: JournalTestClock.insert)
        try fixture.context.save()

        #expect(photo.updatedAt == JournalTestClock.insert)
        #expect(photo.journalEntry?.id == fixture.entry.id)
    }
}

// MARK: - Editor-Mutationen

@Suite("J2a — Editor-Mutationen bumpen den Eintrag")
struct JournalEditMatrixTests {

    @Test("text ändern bumpt updatedAt, createdAt bleibt")
    @MainActor
    func textChangeBumps() throws {
        let fixture = try JournalFixture()
        fixture.entry.setText("Neue Fassung", at: JournalTestClock.firstEdit)

        #expect(fixture.entry.updatedAt == JournalTestClock.firstEdit)
        #expect(fixture.entry.createdAt == JournalTestClock.insert, "createdAt ist unveränderlich")
    }

    @Test("entryDate ändern bumpt updatedAt und normalisiert auf 12:00 UTC")
    @MainActor
    func entryDateChangeBumps() throws {
        let fixture = try JournalFixture()
        fixture.entry.setEntryDate(
            localDay: Date(timeIntervalSince1970: 1_780_300_000),
            at: JournalTestClock.firstEdit
        )

        #expect(fixture.entry.updatedAt == JournalTestClock.firstEdit)
        #expect(fixture.entry.createdAt == JournalTestClock.insert)
        #expect(JournalDay.utcCalendar.component(.hour, from: fixture.entry.entryDate) == 12)
    }

    @Test("moodRaw ändern bumpt updatedAt")
    @MainActor
    func moodChangeBumps() throws {
        let fixture = try JournalFixture()
        fixture.entry.setMoodRaw("okay", at: JournalTestClock.firstEdit)

        #expect(fixture.entry.moodRaw == "okay")
        #expect(fixture.entry.updatedAt == JournalTestClock.firstEdit)
    }

    @Test("Hafen setzen, wechseln und entfernen bumpt jedes Mal")
    @MainActor
    func portSetSwitchAndClearBump() throws {
        let fixture = try JournalFixture()
        let bergen = makeJournalPort(fixture.context, cruise: fixture.cruise, name: "Bergen")
        let tromso = makeJournalPort(fixture.context, cruise: fixture.cruise, name: "Tromsø")

        fixture.entry.setPort(bergen, at: JournalTestClock.firstEdit)
        #expect(fixture.entry.port?.name == "Bergen")
        #expect(fixture.entry.updatedAt == JournalTestClock.firstEdit)

        fixture.entry.setPort(tromso, at: JournalTestClock.secondEdit)
        #expect(fixture.entry.port?.name == "Tromsø")
        #expect(fixture.entry.updatedAt == JournalTestClock.secondEdit)

        let later = JournalTestClock.secondEdit.addingTimeInterval(60)
        fixture.entry.setPort(nil, at: later)
        #expect(fixture.entry.port == nil)
        #expect(fixture.entry.updatedAt == later)

        let stored = try fixture.savedAndRefetchedEntry()
        #expect(stored.port == nil, "Auch im Store hängt kein Hafen mehr am Eintrag")
        #expect(stored.updatedAt == later)
        #expect(stored.createdAt == JournalTestClock.insert)
    }
}

// MARK: - Foto-Mutationen

@Suite("J2a — Foto-Mutationen")
struct JournalPhotoMatrixTests {

    @Test("Foto anhängen bumpt Eintrag und Foto")
    @MainActor
    func attachBumpsBoth() throws {
        let fixture = try JournalFixture()
        let photo = makeJournalPhoto(fixture.context, cruise: fixture.cruise)
        photo.updatedAt = JournalTestClock.insert

        fixture.entry.attach(photo, at: JournalTestClock.firstEdit)

        #expect(fixture.entry.updatedAt == JournalTestClock.firstEdit)
        #expect(photo.updatedAt == JournalTestClock.firstEdit)

        let stored = try fixture.savedAndRefetchedEntry()
        #expect(stored.photos.map(\.id) == [photo.id], "Die Beziehung steht auch im Store")
        #expect(stored.updatedAt == JournalTestClock.firstEdit)
        let storedPhoto = try #require(refetchPhoto(id: photo.id, from: fixture.container))
        #expect(storedPhoto.journalEntry?.id == fixture.entry.id)
        #expect(storedPhoto.updatedAt == JournalTestClock.firstEdit)
    }

    @Test("Ein Foto an einen anderen Eintrag hängen bumpt beide Einträge")
    @MainActor
    func reAttachBumpsBothEntries() throws {
        let fixture = try JournalFixture()
        let target = JournalEntry(text: "Ziel-Eintrag", now: JournalTestClock.insert)
        target.cruise = fixture.cruise
        fixture.context.insert(target)

        let photo = makeJournalPhoto(fixture.context, cruise: fixture.cruise)
        fixture.entry.attach(photo, at: JournalTestClock.insert)
        fixture.entry.updatedAt = JournalTestClock.insert
        target.updatedAt = JournalTestClock.insert

        target.attach(photo, at: JournalTestClock.firstEdit)

        #expect(
            fixture.entry.updatedAt == JournalTestClock.firstEdit,
            "Der bisherige Eintrag verliert ein Foto und muss mitbumpen"
        )
        #expect(target.updatedAt == JournalTestClock.firstEdit)
        #expect(photo.updatedAt == JournalTestClock.firstEdit)

        try fixture.context.save()
        let storedPrevious = try #require(
            refetchJournalEntry(id: fixture.entry.id, from: fixture.container)
        )
        let storedTarget = try #require(
            refetchJournalEntry(id: target.id, from: fixture.container)
        )
        #expect(storedPrevious.photos.isEmpty)
        #expect(storedPrevious.updatedAt == JournalTestClock.firstEdit)
        #expect(storedTarget.photos.map(\.id) == [photo.id])
        #expect(storedTarget.updatedAt == JournalTestClock.firstEdit)
    }

    @Test("Foto abhängen bumpt Eintrag und Foto, das Foto bleibt Reise-Kind")
    @MainActor
    func detachBumpsBoth() throws {
        let fixture = try JournalFixture()
        let photo = makeJournalPhoto(fixture.context, cruise: fixture.cruise)
        fixture.entry.attach(photo, at: JournalTestClock.insert)

        fixture.entry.detach(photo, at: JournalTestClock.firstEdit)

        #expect(photo.journalEntry == nil)
        #expect(photo.cruise?.id == fixture.cruise.id)
        #expect(fixture.entry.updatedAt == JournalTestClock.firstEdit)
        #expect(photo.updatedAt == JournalTestClock.firstEdit)

        let stored = try fixture.savedAndRefetchedEntry()
        #expect(stored.photos.isEmpty, "Im Store hängt kein Foto mehr am Eintrag")
        #expect(stored.updatedAt == JournalTestClock.firstEdit)
        let storedPhoto = try #require(refetchPhoto(id: photo.id, from: fixture.container))
        #expect(storedPhoto.journalEntry == nil)
        #expect(storedPhoto.cruise?.id == fixture.cruise.id)
        #expect(storedPhoto.updatedAt == JournalTestClock.firstEdit)
    }

    @Test("Caption ändern bumpt nur das Foto")
    @MainActor
    func captionChangeBumpsOnlyPhoto() throws {
        let fixture = try JournalFixture()
        let photo = makeJournalPhoto(fixture.context, cruise: fixture.cruise)
        fixture.entry.attach(photo, at: JournalTestClock.insert)
        fixture.entry.updatedAt = JournalTestClock.insert

        photo.setCaption("Blick von Deck 9", at: JournalTestClock.firstEdit)

        #expect(photo.caption == "Blick von Deck 9")
        #expect(photo.updatedAt == JournalTestClock.firstEdit)
        #expect(
            fixture.entry.updatedAt == JournalTestClock.insert,
            "Der Eintrag bumpt bei Captions nicht"
        )
    }
}

// MARK: - Lösch-Pfade (Nullify bumpt nicht automatisch)

@Suite("J2a — Lösch-Pfade")
struct JournalDeleteMatrixTests {

    @Test("Foto aus der Galerie löschen bumpt den Eintrag, an dem es hing")
    @MainActor
    func deletingAttachedPhotoBumpsEntry() throws {
        let fixture = try JournalFixture()
        let photo = makeJournalPhoto(fixture.context, cruise: fixture.cruise)
        fixture.entry.attach(photo, at: JournalTestClock.insert)
        fixture.entry.updatedAt = JournalTestClock.insert
        try fixture.context.save()

        JournalDeletePaths.deletePhoto(photo, in: fixture.context, at: JournalTestClock.firstEdit)
        try fixture.context.save()

        #expect(try fixture.context.fetch(FetchDescriptor<Photo>()).isEmpty)
        #expect(fixture.entry.updatedAt == JournalTestClock.firstEdit)

        let stored = try #require(
            refetchJournalEntry(id: fixture.entry.id, from: fixture.container)
        )
        #expect(stored.photos.isEmpty)
        #expect(stored.updatedAt == JournalTestClock.firstEdit)
    }

    @Test("Ein freies Foto zu löschen bumpt nichts")
    @MainActor
    func deletingUnattachedPhotoBumpsNothing() throws {
        let fixture = try JournalFixture()
        let photo = makeJournalPhoto(fixture.context, cruise: fixture.cruise)
        fixture.entry.updatedAt = JournalTestClock.insert
        try fixture.context.save()

        JournalDeletePaths.deletePhoto(photo, in: fixture.context, at: JournalTestClock.firstEdit)
        try fixture.context.save()

        #expect(fixture.entry.updatedAt == JournalTestClock.insert)
    }

    @Test("Eintrag löschen bumpt jedes betroffene Foto (Nullify-Pfad)")
    @MainActor
    func deletingEntryBumpsDetachedPhotos() throws {
        let fixture = try JournalFixture()
        let first = makeJournalPhoto(fixture.context, cruise: fixture.cruise, sortOrder: 0)
        let second = makeJournalPhoto(fixture.context, cruise: fixture.cruise, sortOrder: 1)
        fixture.entry.attach(first, at: JournalTestClock.insert)
        fixture.entry.attach(second, at: JournalTestClock.insert)
        try fixture.context.save()

        JournalDeletePaths.deleteEntry(
            fixture.entry,
            in: fixture.context,
            at: JournalTestClock.firstEdit
        )
        try fixture.context.save()

        #expect(try fixture.context.fetch(FetchDescriptor<JournalEntry>()).isEmpty)
        #expect(first.updatedAt == JournalTestClock.firstEdit)
        #expect(second.updatedAt == JournalTestClock.firstEdit)
        #expect(first.journalEntry == nil)
        #expect(second.journalEntry == nil)

        for photo in [first, second] {
            let stored = try #require(refetchPhoto(id: photo.id, from: fixture.container))
            #expect(stored.journalEntry == nil)
            #expect(stored.updatedAt == JournalTestClock.firstEdit)
        }
    }

    @Test("Hafen löschen bumpt jeden betroffenen Eintrag (Nullify-Pfad)")
    @MainActor
    func deletingPortBumpsEntries() throws {
        let fixture = try JournalFixture()
        let port = makeJournalPort(fixture.context, cruise: fixture.cruise)
        fixture.entry.setPort(port, at: JournalTestClock.insert)

        let second = JournalEntry(text: "Zweiter Eintrag", now: JournalTestClock.insert)
        second.cruise = fixture.cruise
        fixture.context.insert(second)
        second.setPort(port, at: JournalTestClock.insert)
        try fixture.context.save()

        JournalDeletePaths.deletePort(port, in: fixture.context, at: JournalTestClock.firstEdit)
        try fixture.context.save()

        #expect(try fixture.context.fetch(FetchDescriptor<ShipTrip.Port>()).isEmpty)
        #expect(fixture.entry.port == nil)
        #expect(second.port == nil)
        #expect(fixture.entry.updatedAt == JournalTestClock.firstEdit)
        #expect(second.updatedAt == JournalTestClock.firstEdit)
        #expect(
            fixture.entry.createdAt == JournalTestClock.insert,
            "createdAt bleibt auch im Lösch-Pfad"
        )

        for entry in [fixture.entry, second] {
            let stored = try #require(refetchJournalEntry(id: entry.id, from: fixture.container))
            #expect(stored.port == nil)
            #expect(stored.updatedAt == JournalTestClock.firstEdit)
            #expect(stored.createdAt == JournalTestClock.insert)
        }
    }

    @Test("Reise löschen entfernt Einträge und deren Fotos (Cascade)")
    @MainActor
    func deletingCruiseCascades() throws {
        let fixture = try JournalFixture()
        let photo = makeJournalPhoto(fixture.context, cruise: fixture.cruise)
        fixture.entry.attach(photo, at: JournalTestClock.insert)
        try fixture.context.save()

        fixture.context.delete(fixture.cruise)
        try fixture.context.save()

        #expect(try fixture.context.fetch(FetchDescriptor<JournalEntry>()).isEmpty)
        #expect(try fixture.context.fetch(FetchDescriptor<Photo>()).isEmpty)
    }
}
