//
//  ShareImportCleanupTests.swift
//  ShipTripTests
//
//  Loeschregel des Share-Imports: seit `LSSupportsOpeningDocumentsInPlace`
//  reicht die Dateien-App die **Originaldatei des Nutzers** herein. Nur
//  App-eigene Kopien (Documents/Inbox, tmp) duerfen nach dem Import weg.
//

import Testing
import Foundation
@testable import ShipTrip

@Suite("Share-Import: Loeschregel der Quelldatei")
@MainActor
struct ShareImportCleanupTests {

    @Test("Datei aus Documents/Inbox wird entfernt")
    func inboxFileIsRemoved() {
        let url = URL.documentsDirectory
            .appending(path: "Inbox", directoryHint: .isDirectory)
            .appending(path: "reise.shiptrip")

        #expect(ShareImportCoordinator.shouldRemoveAfterImport(url))
    }

    @Test("Arbeitskopie im tmp-Verzeichnis wird entfernt")
    func temporaryFileIsRemoved() {
        let url = FileManager.default.temporaryDirectory
            .appending(path: "reise.shiptrip")

        #expect(ShareImportCoordinator.shouldRemoveAfterImport(url))
    }

    @Test("Fremde Datei unterhalb von Documents bleibt erhalten")
    func foreignDocumentsFileIsKept() {
        let url = URL.documentsDirectory
            .appending(path: "Archiv", directoryHint: .isDirectory)
            .appending(path: "reise.shiptrip")

        #expect(ShareImportCoordinator.shouldRemoveAfterImport(url) == false)
    }

    @Test("In-Place-URL ausserhalb des App-Containers bleibt erhalten")
    func inPlaceFileIsKept() {
        let url = URL(filePath: "/private/var/mobile/Library/Mobile Documents/"
                      + "com~apple~CloudDocs/reise.shiptrip")

        #expect(ShareImportCoordinator.shouldRemoveAfterImport(url) == false)
    }

    // MARK: - Uebergabeordner der Share-Extension (ADR-010, H3)

    /// Wegwerf-Ordner statt der echten App Group — der Test darf nie am
    /// Entitlement des Testlaufs haengen. Bewusst unter `Library/Caches` und
    /// **nicht** unter `tmp`: dort wuerde schon die bestehende tmp-Regel `true`
    /// liefern und die neue Uebergabe-Regel nichts mehr beweisen.
    private func makeHandoffRoot() throws -> URL {
        let root = URL.cachesDirectory
            .appending(path: "share-cleanup-tests", directoryHint: .isDirectory)
            .appending(path: UUID().uuidString, directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        return root
    }

    @Test("Datei im Uebergabeordner wird entfernt")
    func handoffFileIsRemoved() throws {
        let inbox = try makeHandoffRoot()
            .appending(path: ShareHandoffStore.folderName, directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: inbox, withIntermediateDirectories: true)
        let url = inbox.appending(path: "\(UUID().uuidString).shiptrip")

        #expect(ShareImportCoordinator.shouldRemoveAfterImport(url, inbox: inbox))
    }

    @Test("Geschwister-Ordner mit gleichem Praefix bleibt erhalten")
    func siblingOfHandoffInboxIsKept() throws {
        let root = try makeHandoffRoot()
        let inbox = root.appending(path: ShareHandoffStore.folderName, directoryHint: .isDirectory)
        // `ShareInbox2/` liegt neben dem Uebergabeordner — der abschliessende
        // Trenner in der Praefix-Pruefung ist genau dafuer da.
        let sibling = root
            .appending(path: "\(ShareHandoffStore.folderName)2", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: inbox, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: sibling, withIntermediateDirectories: true)
        let url = sibling.appending(path: "\(UUID().uuidString).shiptrip")

        #expect(ShareImportCoordinator.shouldRemoveAfterImport(url, inbox: inbox) == false)
    }

    @Test("Ohne App-Group-Container gilt unveraendert die alte Regel")
    func missingContainerKeepsForeignFile() {
        let url = URL(filePath: "/private/var/mobile/Containers/Shared/AppGroup/"
                      + "0F1E2D3C/ShareInbox/\(UUID().uuidString).shiptrip")

        #expect(ShareImportCoordinator.shouldRemoveAfterImport(url, inbox: nil) == false)
    }
}
