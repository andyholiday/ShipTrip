//
//  ShareImportResultTests.swift
//  ShipTripTests
//
//  Ergebnis des Share-Imports (Contract C6): neu importiert, „bereits vorhanden" und
//  Versionskonflikt — letzterer ausschliesslich ueber den beim Import persistierten
//  `Cruise.shareContentFingerprint` (C1: keine Neuberechnung, kein Merge).
//

import Testing
import Foundation
import SwiftData
@testable import ShipTrip

private let fingerprintA = "aaaa1111bbbb2222cccc3333dddd4444eeee5555ffff6666aaaa1111bbbb2222"
private let fingerprintB = "9999888877776666555544443333222211110000ffffeeeeddddccccbbbbaaaa"

@Suite("Share-Import: Ergebnis und Fingerabdruck (C1/C6)")
@MainActor
struct ShareImportResultTests {

    private func storedCruise(_ id: UUID, in context: ModelContext) throws -> Cruise? {
        try context.fetch(FetchDescriptor<Cruise>()).first { $0.id == id }
    }

    @Test("Neue Reise wird importiert und der Fingerabdruck persistiert")
    func newCruiseIsImportedAndFingerprintPersisted() async throws {
        let container = try makeShareImportContainer()
        let context = ModelContext(container)
        let cruiseID = UUID()
        let url = try writeShareFile(archive: makeShareArchive(
            cruises: [makeShareCruise(id: cruiseID)], contentFingerprint: fingerprintA
        ))

        let result = try await ExportImportService.shared.importSharedCruise(
            from: url, modelContext: context
        )

        #expect(result.base.imported == 1)
        #expect(result.versionConflict == false)
        let cruise = try #require(try storedCruise(cruiseID, in: context))
        #expect(cruise.shareContentFingerprint == fingerprintA)
    }

    @Test("Dieselbe Datei ein zweites Mal: bereits vorhanden, kein Konflikt")
    func sameFileTwiceIsDuplicateWithoutConflict() async throws {
        let container = try makeShareImportContainer()
        let context = ModelContext(container)
        let url = try writeShareFile(archive: makeShareArchive(
            cruises: [makeShareCruise(id: UUID())], contentFingerprint: fingerprintA
        ))

        _ = try await ExportImportService.shared.importSharedCruise(
            from: url, modelContext: context
        )
        let second = try await ExportImportService.shared.importSharedCruise(
            from: url, modelContext: context
        )

        #expect(second.base.imported == 0)
        #expect(second.base.skippedDuplicates == 1)
        #expect(second.versionConflict == false)
        #expect(try context.fetch(FetchDescriptor<Cruise>()).count == 1)
    }

    @Test("Abweichende Senderfassung meldet den Versionskonflikt — ohne zu ueberschreiben")
    func differingFingerprintReportsConflict() async throws {
        let container = try makeShareImportContainer()
        let context = ModelContext(container)
        let cruiseID = UUID()

        let first = try writeShareFile(archive: makeShareArchive(
            cruises: [makeShareCruise(id: cruiseID, title: "Nordland-Route")],
            contentFingerprint: fingerprintA
        ))
        _ = try await ExportImportService.shared.importSharedCruise(
            from: first, modelContext: context
        )

        // Gleiche Reise-id, andere Senderfassung.
        let second = try writeShareFile(archive: makeShareArchive(
            cruises: [makeShareCruise(id: cruiseID, title: "Nordland-Route (überarbeitet)")],
            contentFingerprint: fingerprintB
        ))
        let result = try await ExportImportService.shared.importSharedCruise(
            from: second, modelContext: context
        )

        #expect(result.versionConflict)
        #expect(result.base.imported == 0)
        #expect(result.base.skippedDuplicates == 1)

        // Kein Merge, kein Ueberschreiben: Titel und Fingerabdruck bleiben die alten.
        let cruise = try #require(try storedCruise(cruiseID, in: context))
        #expect(cruise.title == "Nordland-Route")
        #expect(cruise.shareContentFingerprint == fingerprintA)
    }

    @Test("Reise ohne persistierten Fingerabdruck loest keinen Konflikt aus")
    func cruiseWithoutStoredFingerprintReportsNoConflict() async throws {
        let container = try makeShareImportContainer()
        let context = ModelContext(container)
        let cruiseID = UUID()

        // Ueber den Backup-Pfad angelegt — dort wird nie ein Fingerabdruck gesetzt.
        let backupJSON = try encodeArchiveJSON(
            makeBackupArchive(cruises: [makeShareCruise(id: cruiseID)])
        )
        _ = try ExportImportService.shared.importFromJSONData(
            data: backupJSON, imagesDir: nil, modelContext: context
        )
        #expect(try storedCruise(cruiseID, in: context)?.shareContentFingerprint == nil)

        let url = try writeShareFile(archive: makeShareArchive(
            cruises: [makeShareCruise(id: cruiseID)], contentFingerprint: fingerprintA
        ))
        let result = try await ExportImportService.shared.importSharedCruise(
            from: url, modelContext: context
        )

        #expect(result.versionConflict == false)
        #expect(result.base.skippedDuplicates == 1)
        // Ein Duplikat bleibt unangetastet — auch der leere Fingerabdruck.
        #expect(try storedCruise(cruiseID, in: context)?.shareContentFingerprint == nil)
    }

    @Test("Zustand des Coordinators bestimmt Text und Accessibility-Identifier (C8/C9)")
    func presentationMapsStateToContractStrings() throws {
        let imported = try #require(ShareImportPresentation(state: .finished(
            imported: 1, skippedDuplicates: 0, skippedInvalid: 0,
            invalidMedia: 0, versionConflict: false
        )))
        #expect(imported.message == String(localized: "Reise importiert"))
        #expect(imported.kind.accessibilityIdentifier == "shareImport.resultSheet")

        let duplicate = try #require(ShareImportPresentation(state: .finished(
            imported: 0, skippedDuplicates: 1, skippedInvalid: 0,
            invalidMedia: 0, versionConflict: false
        )))
        #expect(duplicate.message == String(localized: "Diese Reise ist bereits vorhanden."))

        let conflict = try #require(ShareImportPresentation(state: .finished(
            imported: 0, skippedDuplicates: 1, skippedInvalid: 0,
            invalidMedia: 0, versionConflict: true
        )))
        #expect(conflict.message != duplicate.message)

        let hint = try #require(ShareImportPresentation(state: .linkHint))
        #expect(hint.kind.accessibilityIdentifier == "shareImport.linkHintSheet")

        #expect(ShareImportPresentation(state: .idle) == nil)
        #expect(ShareImportPresentation(state: .importing) == nil)
    }
}
