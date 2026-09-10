//
//  ShareImportHandoffScanTests.swift
//  ShipTripTests
//
//  Vordergrund-Scan des Uebergabeordners (ADR-010, H3): die Share-Extension
//  legt nur ab, importiert wird beim naechsten Wechsel in den Vordergrund.
//  Geprueft wird gegen einen Wegwerf-Ordner und einen In-Memory-Store, nie
//  gegen die echte App Group.
//

import Testing
import Foundation
import SwiftData
@testable import ShipTrip

// MARK: - Testhilfen

/// Frischer, leerer Uebergabeordner je Test.
///
/// Bewusst unter `Library/Caches` und **nicht** unter `tmp`: dort wuerde die
/// bestehende tmp-Regel die Datei ohnehin loeschen und der Nachweis „die
/// Uebergabedatei ist nach dem Import weg" waere wertlos.
private func makeHandoffInbox() throws -> URL {
    let url = URL.cachesDirectory
        .appending(path: "share-handoff-scan-tests", directoryHint: .isDirectory)
        .appending(path: UUID().uuidString, directoryHint: .isDirectory)
        .appending(path: ShareHandoffStore.folderName, directoryHint: .isDirectory)
    try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
    return url
}

/// Legt eine gueltig benannte Uebergabedatei mit echtem Share-Archiv ab.
private func placeHandoffFile(in inbox: URL, cruiseID: UUID = UUID()) throws -> URL {
    let source = try writeShareFile(
        archive: makeShareArchive(cruises: [makeShareCruise(id: cruiseID)])
    )
    let target = inbox.appending(
        path: "\(UUID().uuidString).\(ShareHandoffStore.fileExtension)"
    )
    try FileManager.default.moveItem(at: source, to: target)
    return target
}

/// Wartet, bis der Import-Task fertig ist — `startImport` laeuft in einem
/// `Task` auf dem MainActor, sein Preflight kurz off-main.
@MainActor
private func settle(_ coordinator: ShareImportCoordinator) async throws {
    for _ in 0..<300 {
        if coordinator.state != .importing { return }
        try await Task.sleep(for: .milliseconds(10))
    }
}

private func exists(_ url: URL) -> Bool {
    FileManager.default.fileExists(atPath: url.path(percentEncoded: false))
}

// MARK: - Tests

@Suite("Share-Import: Vordergrund-Scan des Uebergabeordners (H3)")
@MainActor
struct ShareImportHandoffScanTests {

    @Test("Anstehende Datei wird importiert, danach entfernt; Zweitlauf ist ein No-op")
    func pendingFileIsImportedAndRemoved() async throws {
        let container = try makeShareImportContainer()
        let inbox = try makeHandoffInbox()
        let file = try placeHandoffFile(in: inbox)
        let coordinator = ShareImportCoordinator()

        coordinator.importPendingHandoffIfIdle(
            modelContext: container.mainContext, inbox: inbox
        )
        #expect(coordinator.state == .importing)

        try await settle(coordinator)
        if case .finished(let imported, _, _, _, _) = coordinator.state {
            #expect(imported == 1)
        } else {
            Issue.record("Erwartet wurde .finished, gefunden: \(coordinator.state)")
        }
        // Erfolg wie Fehler: die Uebergabedatei liegt im gescannten Ordner und
        // ist damit eine App-eigene Kopie — sie darf nicht liegen bleiben.
        #expect(exists(file) == false)

        // Ordner jetzt leer: der naechste Scan tut nichts.
        coordinator.dismiss()
        coordinator.importPendingHandoffIfIdle(
            modelContext: container.mainContext, inbox: inbox
        )
        #expect(coordinator.state == .idle)
    }

    @Test("Leerer Ordner und fehlender App-Group-Container: kein Import")
    func emptyInboxAndMissingContainerStayIdle() throws {
        let container = try makeShareImportContainer()
        let inbox = try makeHandoffInbox()
        let coordinator = ShareImportCoordinator()

        coordinator.importPendingHandoffIfIdle(
            modelContext: container.mainContext, inbox: inbox
        )
        #expect(coordinator.state == .idle)

        // `inbox: nil` = kein Entitlement. Die wartende Datei bleibt liegen.
        let file = try placeHandoffFile(in: inbox)
        coordinator.importPendingHandoffIfIdle(
            modelContext: container.mainContext, inbox: nil
        )
        #expect(coordinator.state == .idle)
        #expect(exists(file))
    }

    @Test("Single-Flight: steht ein Ergebnis an, wird der Scan verworfen")
    func pendingResultBlocksScan() async throws {
        let container = try makeShareImportContainer()
        let inbox = try makeHandoffInbox()
        _ = try placeHandoffFile(in: inbox)
        let coordinator = ShareImportCoordinator()

        coordinator.importPendingHandoffIfIdle(
            modelContext: container.mainContext, inbox: inbox
        )
        try await settle(coordinator)
        let resultState = coordinator.state

        // Zweite Datei trifft ein, waehrend das Ergebnis-Sheet noch steht.
        let second = try placeHandoffFile(in: inbox)
        coordinator.importPendingHandoffIfIdle(
            modelContext: container.mainContext, inbox: inbox
        )

        #expect(coordinator.state == resultState)
        #expect(exists(second))

        // Nach dem Schliessen des Sheets holt der Re-Scan sie nach.
        coordinator.dismiss()
        coordinator.importPendingHandoffIfIdle(
            modelContext: container.mainContext, inbox: inbox
        )
        #expect(coordinator.state == .importing)
        try await settle(coordinator)
        #expect(exists(second) == false)
    }
}
