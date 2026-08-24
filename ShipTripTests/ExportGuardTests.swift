//
//  ExportGuardTests.swift
//  ShipTripTests
//
//  Die Alles-oder-nichts-Zusagen des Exports (C4, Iteration 2): Er schreibt nur Archive, die der
//  eigene Import auch wieder annimmt, er schreibt kein Archiv mit fehlenden Medien, und ein
//  Abbruch hinterlässt keine Datei.
//

import Testing
import Foundation
import SwiftData
@testable import ShipTrip

private typealias CruisePort = ShipTrip.Port

/// Ein Tor, das genau einmal geöffnet wird — macht die Abbruch-Reihenfolge deterministisch
/// (kein `sleep`, kein Polling).
private actor Gate {
    private var isOpen = false
    private var waiters: [CheckedContinuation<Void, Never>] = []

    func open() {
        isOpen = true
        let pending = waiters
        waiters = []
        for waiter in pending { waiter.resume() }
    }

    func wait() async {
        if isOpen { return }
        await withCheckedContinuation { waiters.append($0) }
    }
}

private struct BodyFailure: Error {}

@MainActor
private func makeContainer() throws -> ModelContainer {
    let schema = Schema([
        Cruise.self, CruisePort.self, Expense.self, Deal.self, Photo.self,
        CustomShippingLine.self, CustomShip.self, HiddenCatalogItem.self
    ])
    return try ModelContainer(
        for: schema, configurations: ModelConfiguration(isStoredInMemoryOnly: true)
    )
}

@MainActor
private func makeCruise(in context: ModelContext) -> Cruise {
    let cruise = Cruise(
        title: "Grenzfall",
        startDate: Date(timeIntervalSince1970: 0),
        endDate: Date(timeIntervalSince1970: 86_400),
        shippingLine: "AIDA",
        ship: "AIDAnova"
    )
    context.insert(cruise)
    return cruise
}

@Suite("Export: Grenzen, fehlende Medien, Abbruch")
struct ExportGuardTests {

    // MARK: - Fix 1: Export- und Importgrenzen sind dieselben

    /// REPRO: Der Writer kannte nur die ZIP32-Grenze (4 GB), der Reader steigt schon bei 50 MB je
    /// Eintrag aus — der Export konnte also ein Backup erzeugen, das die App selbst nicht mehr
    /// importiert. Die Vorabprüfung greift jetzt auf exakt die Reader-Konstante zu.
    @Test("Ein Eintrag über der Importgrenze bricht den Export ab, statt ihn zu schreiben")
    @MainActor
    func overLimitEntryIsRejectedBeforeWriting() throws {
        let source = ExportImageSource(cruises: [])   // keine Bilder; data.json ist der Überläufer

        #expect(throws: ExportError.self) {
            try ExportImportService.validateArchiveSize(
                jsonByteCount: ZipArchiveReader.maxEntryUncompressedSize + 1,
                imageSource: source
            )
        }
    }

    /// Gegenprobe: exakt auf der Grenze darf der Export NICHT abbrechen, sonst hätte die Prüfung
    /// legitime Backups abgewiesen.
    @Test("Genau auf der Importgrenze bleibt der Export offen")
    @MainActor
    func exactlyAtLimitIsAccepted() throws {
        let source = ExportImageSource(cruises: [])

        try ExportImportService.validateArchiveSize(
            jsonByteCount: ZipArchiveReader.maxEntryUncompressedSize,
            imageSource: source
        )
    }

    // MARK: - Fix 2: fehlendes Medium ist ein Fehler, kein leerer Eintrag

    /// REPRO: `data(at:)` gab für ein zwischenzeitlich geleertes Hafenbild `Data()` zurück. Der
    /// Writer schrieb daraus einen leeren, CRC-konsistenten Eintrag und der Export meldete Erfolg —
    /// ein stilles Loch im Backup.
    @Test("Verschwundene Bild-Bytes werfen, statt einen leeren Eintrag zu erzeugen")
    @MainActor
    func missingMediaThrows() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let cruise = makeCruise(in: context)

        let port = CruisePort(name: "Palma", country: "Spanien", latitude: 39.57, longitude: 2.65)
        port.imageData = Data(repeating: 0x01, count: 128)
        port.cruise = cruise
        context.insert(port)
        try context.save()

        let source = ExportImageSource(cruises: [cruise])
        #expect(try source.data(at: 0).count == 128)

        // Das Modell verliert seine Bytes nach dem Snapshot — genau der Fall aus dem Befund.
        port.imageData = nil
        #expect(throws: ExportError.self) { try source.data(at: 0) }
    }

    /// Und derselbe Fall am echten Einstiegspunkt: `exportToZip` meldet keinen Erfolg mehr.
    /// Weil die Vorabprüfung vor dem Anlegen der Datei greift, entsteht hier gar keine ZIP.
    @Test("Export mit unlesbarem Medium wirft, statt Erfolg zu melden")
    @MainActor
    func exportWithMissingMediaThrows() async throws {
        let container = try makeContainer()
        let context = container.mainContext
        let cruise = makeCruise(in: context)

        let port = CruisePort(name: "Palma", country: "Spanien", latitude: 39.57, longitude: 2.65)
        port.imageData = Data()          // referenziert, aber ohne Bytes
        port.cruise = cruise
        context.insert(port)
        try context.save()

        await #expect(throws: ExportError.self) {
            _ = try await ExportImportService.shared.exportToZip(cruises: [cruise])
        }
    }

    /// Wirft ein Eintrags-Body mitten im Schreiben, ist die angefangene Datei weg — die Zusage,
    /// die den Fehlerabbruch überhaupt erst zur Konsistenzgarantie macht.
    @Test("Werfender Eintrag räumt die angefangene ZIP weg")
    func throwingEntryRemovesPartialFile() async throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("export-guard-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }

        let zipURL = directory.appendingPathComponent("partial.zip")
        let payload = Data(repeating: 0xAB, count: 64 * 1024)
        let entries = (0..<4).map { index in
            ZipArchiveStreamWriter.Entry(name: "images/\(index)") {
                if index == 2 { throw BodyFailure() }
                return payload
            }
        }

        await #expect(throws: BodyFailure.self) {
            try await ZipArchiveStreamWriter().write(entries: entries, to: zipURL)
        }
        #expect(FileManager.default.fileExists(atPath: zipURL.path) == false)
    }

    // MARK: - Fix 3: Abbruch

    /// REPRO: Der Writer prüfte `Task.isCancelled` nie — ein abgebrochener Export lief bis zum
    /// letzten Bild weiter und legte am Ende ein vollständiges Archiv ab.
    @Test("Abbruch wirft CancellationError und hinterlässt keine Datei")
    func cancellationLeavesNoFile() async throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("export-cancel-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }

        let zipURL = directory.appendingPathComponent("cancel.zip")
        let payload = Data(repeating: 0x5A, count: 32 * 1024)
        let firstEntryStarted = Gate()
        let releaseFirstEntry = Gate()

        let entries = (0..<64).map { index in
            ZipArchiveStreamWriter.Entry(name: "images/\(index)") {
                if index == 0 {
                    await firstEntryStarted.open()
                    await releaseFirstEntry.wait()
                }
                return payload
            }
        }

        let task = Task { try await ZipArchiveStreamWriter().write(entries: entries, to: zipURL) }

        // Deterministisch: erst wenn der Writer im ersten Eintrag hängt, wird abgebrochen.
        await firstEntryStarted.wait()
        task.cancel()
        await releaseFirstEntry.open()

        await #expect(throws: CancellationError.self) { try await task.value }
        #expect(FileManager.default.fileExists(atPath: zipURL.path) == false)
    }
}
