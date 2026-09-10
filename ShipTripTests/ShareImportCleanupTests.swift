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
}
