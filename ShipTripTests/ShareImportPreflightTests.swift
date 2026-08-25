//
//  ShareImportPreflightTests.swift
//  ShipTripTests
//
//  Preflight und Haertung des Share-Imports (Contract C10). Geprueft wird beides:
//  der Transport-Preflight am Share-Einstieg (Stufe A) und der archiv-gebundene
//  Preflight, der im Import-Kern haengt und damit auch den manuellen Backup-Import
//  bindet, sobald die Datei einen `share`-Block traegt.
//

import Testing
import Foundation
import SwiftData
@testable import ShipTrip

// MARK: - Ablehnungs-Token

/// `ShareImportError` ist nicht `Equatable` (String-Payload) — fuer Vergleiche in den
/// Erwartungen reicht der Fall-Name.
private func token(_ error: ShareImportError) -> String {
    switch error {
    case .notAShareFile: "notAShareFile"
    case .unsupportedVersion: "unsupportedVersion"
    case .limitExceeded: "limitExceeded"
    }
}

/// `nil` = akzeptiert.
private func rejectionOfArchive(_ archive: ExportArchive) -> String? {
    do {
        try SharePreflight.validateArchive(archive)
        return nil
    } catch {
        return token(error)
    }
}

/// `nil` = akzeptiert (Stufe A, Share-Einstieg).
private func rejectionOfShareEntry(_ url: URL) -> String? {
    do {
        _ = try SharePreflight.run(url)
        return nil
    } catch {
        return token(error)
    }
}

/// `nil` = akzeptiert (manueller Pfad ueber den Import-Kern).
@MainActor
private func rejectionOfManualImport(
    _ archive: ExportArchive, in context: ModelContext
) throws -> String? {
    let json = try encodeArchiveJSON(archive)
    do {
        _ = try ExportImportService.shared.importFromJSONData(
            data: json, imagesDir: nil, modelContext: context
        )
        return nil
    } catch let error as ShareImportError {
        return token(error)
    }
}

// MARK: - Versionsmatrix

/// Eine Zelle der C10-Versionsmatrix.
fileprivate struct VersionMatrixCase: Sendable {
    let formatVersion: Int
    let shareFormatVersion: Int
    /// `nil` = akzeptieren.
    let expected: String?
}

@Suite("Share-Import: Versionsmatrix und Invarianten (C10)")
struct ShareArchivePreflightTests {

    @Test("Versionsmatrix ist total: jede Kombination trifft genau eine Zeile", arguments: [
        VersionMatrixCase(formatVersion: 2, shareFormatVersion: 1, expected: nil),
        VersionMatrixCase(formatVersion: 2, shareFormatVersion: 2, expected: "unsupportedVersion"),
        VersionMatrixCase(formatVersion: 2, shareFormatVersion: 0, expected: "notAShareFile"),
        VersionMatrixCase(formatVersion: 2, shareFormatVersion: -1, expected: "notAShareFile"),
        VersionMatrixCase(formatVersion: 3, shareFormatVersion: 1, expected: "unsupportedVersion"),
        VersionMatrixCase(formatVersion: 3, shareFormatVersion: 9, expected: "unsupportedVersion"),
        VersionMatrixCase(formatVersion: 1, shareFormatVersion: 1, expected: "notAShareFile"),
        VersionMatrixCase(formatVersion: 0, shareFormatVersion: 1, expected: "notAShareFile")
    ])
    func versionMatrix(testCase: VersionMatrixCase) throws {
        let archive = makeShareArchive(
            cruises: [makeShareCruise()],
            formatVersion: testCase.formatVersion,
            shareFormatVersion: testCase.shareFormatVersion
        )
        #expect(rejectionOfArchive(archive) == testCase.expected)
    }

    @Test("Ohne share-Block greift der Guard nicht — Backup-Semantik bleibt unveraendert")
    func backupArchivePassesUntouched() throws {
        let backup = makeBackupArchive(cruises: [makeShareCruise(), makeShareCruise()])
        #expect(rejectionOfArchive(backup) == nil)
    }

    @Test("Mehr als eine Kreuzfahrt im share-Archiv wird abgewiesen (Massenimport-Abwehr)")
    func multipleCruisesAreRejected() throws {
        let archive = makeShareArchive(cruises: [makeShareCruise(), makeShareCruise()])
        #expect(rejectionOfArchive(archive) == "notAShareFile")
    }

    @Test("Keine Kreuzfahrt im share-Archiv wird abgewiesen")
    func emptyShareArchiveIsRejected() throws {
        #expect(rejectionOfArchive(makeShareArchive(cruises: [])) == "notAShareFile")
    }

    @Test("Nicht-leere Nebensammlungen verletzen die Share-Invariante")
    func sideCollectionsAreRejected() throws {
        let deal = ExportDeal(
            id: UUID().uuidString, title: "Restplatz", shippingLine: nil, ship: nil,
            destination: nil, price: nil, originalPrice: nil, startDate: nil, endDate: nil,
            url: nil, notes: nil, createdAt: nil, updatedAt: nil
        )
        let withDeal = makeShareArchive(cruises: [makeShareCruise()], deals: [deal])
        #expect(rejectionOfArchive(withDeal) == "notAShareFile")

        let line = ExportCustomShippingLine(
            id: UUID().uuidString, name: "Eigene Reederei",
            logo: nil, createdAt: nil, updatedAt: nil
        )
        let withLine = makeShareArchive(cruises: [makeShareCruise()], customShippingLines: [line])
        #expect(rejectionOfArchive(withLine) == "notAShareFile")
    }

    @Test("Zaehlgrenzen aus ShareArchiveLimits binden Haefen, Bilder und Ausgaben")
    func countLimitsAreEnforced() throws {
        let tooManyPorts = makeShareArchive(
            cruises: [makeShareCruise(portCount: ShareArchiveLimits.maxPorts + 1)]
        )
        #expect(rejectionOfArchive(tooManyPorts) == "limitExceeded")

        let tooManyExpenses = makeShareArchive(
            cruises: [makeShareCruise(
                portCount: 1, expenseCount: ShareArchiveLimits.maxExpenses + 1
            )]
        )
        #expect(rejectionOfArchive(tooManyExpenses) == "limitExceeded")

        // Reisefotos UND Hafenbilder zaehlen gemeinsam gegen maxPhotos.
        let tooManyImages = makeShareArchive(cruises: [makeShareCruise(
            portCount: 10, portsWithImage: 10, photoCount: ShareArchiveLimits.maxPhotos - 9
        )])
        #expect(rejectionOfArchive(tooManyImages) == "limitExceeded")

        let atLimit = makeShareArchive(cruises: [makeShareCruise(
            portCount: ShareArchiveLimits.maxPorts,
            photoCount: ShareArchiveLimits.maxPhotos,
            expenseCount: ShareArchiveLimits.maxExpenses
        )])
        #expect(rejectionOfArchive(atLimit) == nil)
    }
}

// MARK: - Beide Einstiegspfade

@Suite("Share-Import: Preflight in beiden Einstiegspfaden (C10)")
@MainActor
struct ShareImportEntryPathTests {

    @Test("Gueltige Share-Datei passiert den Transport-Preflight")
    func validShareFilePassesStageA() throws {
        let url = try writeShareFile(archive: makeShareArchive(cruises: [makeShareCruise()]))
        let result = try SharePreflight.run(url)
        #expect(result.envelope.share != nil)
        #expect(result.envelope.cruises.count == 1)
        try? FileManager.default.removeItem(at: result.imagesDir)
    }

    @Test("Backup-Archiv am Share-Einstieg wird abgewiesen — kein Massenimport")
    func backupArchiveIsRejectedAtShareEntry() throws {
        let url = try writeShareFile(
            archive: makeBackupArchive(cruises: [makeShareCruise(), makeShareCruise()])
        )
        #expect(rejectionOfShareEntry(url) == "notAShareFile")
    }

    @Test("Defektes ZIP ist keine gueltige geteilte Reise")
    func brokenArchiveIsRejected() throws {
        let url = try writeRawFile(Data("kein zip, nur text".utf8))
        #expect(rejectionOfShareEntry(url) == "notAShareFile")
    }

    @Test("Zip-Slip-Eintrag wird vom Reader abgewiesen und als ungueltig gemeldet")
    func zipSlipIsRejected() throws {
        let archive = makeShareArchive(cruises: [makeShareCruise()])
        let url = try writeShareFile(
            archive: archive,
            extraEntries: [(name: "../entkommen.txt", data: Data("boese".utf8))]
        )
        #expect(rejectionOfShareEntry(url) == "notAShareFile")
    }

    @Test("data.json oberhalb von maxDataJSONSize wird vor dem Decodieren abgewiesen")
    func oversizedDataJSONIsRejected() throws {
        let filler = String(repeating: "a", count: ShareArchiveLimits.maxDataJSONSize + 1024)
        let archive = makeShareArchive(cruises: [makeShareCruise(notes: filler)])
        let url = try writeShareFile(archive: archive)
        #expect(rejectionOfShareEntry(url) == "limitExceeded")
    }

    @Test("Fehlende data.json wird abgewiesen")
    func missingDataJSONIsRejected() throws {
        let zip = try ZipArchiveWriter.build(entries: [(name: "notiz.txt", data: Data("x".utf8))])
        let url = try writeRawFile(zip)
        #expect(rejectionOfShareEntry(url) == "notAShareFile")
    }

    @Test("Mehr-als-1-Cruise: der Share-Einstieg mutiert nichts")
    func multipleCruisesAreRejectedAtShareEntry() async throws {
        let container = try makeShareImportContainer()
        let context = ModelContext(container)
        let url = try writeShareFile(
            archive: makeShareArchive(cruises: [makeShareCruise(), makeShareCruise()])
        )

        var rejection: String?
        do {
            _ = try await ExportImportService.shared.importSharedCruise(
                from: url, modelContext: context
            )
        } catch let error as ShareImportError {
            rejection = token(error)
        }

        #expect(rejection == "notAShareFile")
        #expect(try context.fetch(FetchDescriptor<Cruise>()).isEmpty)
    }

    @Test("Mehr-als-1-Cruise: auch der manuelle Import-Pfad mutiert nichts")
    func multipleCruisesAreRejectedInManualPath() throws {
        let container = try makeShareImportContainer()
        let context = ModelContext(container)
        let archive = makeShareArchive(cruises: [makeShareCruise(), makeShareCruise()])

        #expect(try rejectionOfManualImport(archive, in: context) == "notAShareFile")
        #expect(try context.fetch(FetchDescriptor<Cruise>()).isEmpty)
    }

    @Test("Manipulierter Envelope: auch manuell greift die Versionsmatrix")
    func manipulatedEnvelopeIsRejectedInManualPath() throws {
        let container = try makeShareImportContainer()
        let context = ModelContext(container)

        let futureShare = makeShareArchive(cruises: [makeShareCruise()], shareFormatVersion: 2)
        #expect(try rejectionOfManualImport(futureShare, in: context) == "unsupportedVersion")

        let impossibleShare = makeShareArchive(cruises: [makeShareCruise()], shareFormatVersion: 0)
        #expect(try rejectionOfManualImport(impossibleShare, in: context) == "notAShareFile")

        #expect(try context.fetch(FetchDescriptor<Cruise>()).isEmpty)
    }

    @Test("Backup ohne share-Block bleibt im manuellen Pfad importierbar")
    func backupStillImportsManually() throws {
        let container = try makeShareImportContainer()
        let context = ModelContext(container)
        let backup = makeBackupArchive(cruises: [makeShareCruise(), makeShareCruise()])

        #expect(try rejectionOfManualImport(backup, in: context) == nil)
        #expect(try context.fetch(FetchDescriptor<Cruise>()).count == 2)
    }
}
