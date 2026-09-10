//
//  ShareHandoffStoreTests.swift
//  ShipTripTests
//
//  Contract-Tests des Uebergabeordners (ADR-010, H2): Namensschema,
//  Scan-Regel (nur regulaere, gueltig benannte Dateien direkt im Ordner),
//  atomare Sichtbarkeit ueber `.tmp` + move, Sortierung und Aufraeumregel.
//  Alles gegen einen Wegwerf-Ordner, nie gegen die echte App Group.
//

import Testing
import Foundation
@testable import ShipTrip

// MARK: - Testhilfen

/// Frischer, leerer Uebergabeordner je Test.
private func makeInbox() throws -> URL {
    let url = FileManager.default.temporaryDirectory
        .appendingPathComponent("share-handoff-tests", isDirectory: true)
        .appendingPathComponent(UUID().uuidString, isDirectory: true)
    try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
    return url
}

/// Legt eine Datei an und setzt ihr Aenderungsdatum.
@discardableResult
private func makeFile(_ name: String, in inbox: URL, modified: Date = .now) throws -> URL {
    let url = inbox.appendingPathComponent(name, isDirectory: false)
    try Data("x".utf8).write(to: url)
    try FileManager.default.setAttributes([.modificationDate: modified], ofItemAtPath: url.path)
    return url
}

/// Gueltiger Uebergabename mit frischer UUID.
private func handoffName() -> String {
    "\(UUID().uuidString).\(ShareHandoffStore.fileExtension)"
}

@Suite("ShareHandoffStore — Namenspruefung")
struct ShareHandoffNameTests {

    @Test("Gueltig: <UUID>.shiptrip, Endung auch in Grossschreibung")
    func acceptsValidNames() {
        let uuid = UUID().uuidString
        #expect(ShareHandoffStore.isValidHandoffName("\(uuid).shiptrip"))
        #expect(ShareHandoffStore.isValidHandoffName("\(uuid).SHIPTRIP"))
    }

    @Test("Ungueltig: Pfadtrenner, Punkt-Punkt, Leerstring, falsche Endung, Laenge")
    func rejectsInvalidNames() {
        let uuid = UUID().uuidString
        let invalid = [
            "",                                   // leer
            "../\(uuid).shiptrip",                // Ausbruch nach oben
            "a/b/\(uuid).shiptrip",               // Unterpfad
            "..shiptrip",                         // Punkt-Punkt statt UUID
            "\(uuid).json",                       // falsche Endung
            "\(uuid.dropLast()).shiptrip",        // 44 Zeichen
            "\(uuid)x.shiptrip"                   // 46 Zeichen
        ]
        for name in invalid {
            #expect(!ShareHandoffStore.isValidHandoffName(name), "akzeptiert: \(name)")
        }
    }
}

@Suite("ShareHandoffStore — Scan und Aufraeumen")
struct ShareHandoffScanTests {

    @Test("Atomare Ablage: .tmp ist unsichtbar, nach dem move sichtbar")
    func tmpBecomesVisibleOnlyAfterMove() throws {
        let inbox = try makeInbox()
        let uuid = UUID().uuidString
        let tmp = try makeFile("\(uuid).tmp", in: inbox)
        #expect(ShareHandoffStore.pendingFiles(in: inbox).isEmpty)

        let final = inbox.appendingPathComponent("\(uuid).shiptrip", isDirectory: false)
        try FileManager.default.moveItem(at: tmp, to: final)
        #expect(ShareHandoffStore.pendingFiles(in: inbox).map(\.lastPathComponent)
            == [final.lastPathComponent])
    }

    @Test("Ignoriert Unterordner, Symlink nach aussen und falsch benannte Dateien")
    func skipsNonRegularAndMisnamedEntries() throws {
        let inbox = try makeInbox()
        let outside = try makeFile("geheim.txt", in: try makeInbox())
        try FileManager.default.createDirectory(
            at: inbox.appendingPathComponent(handoffName(), isDirectory: true),
            withIntermediateDirectories: true
        )
        try FileManager.default.createSymbolicLink(
            at: inbox.appendingPathComponent(handoffName(), isDirectory: false),
            withDestinationURL: outside
        )
        try makeFile("reise.shiptrip", in: inbox)

        #expect(ShareHandoffStore.pendingFiles(in: inbox).isEmpty)
    }

    @Test("Sortierung: aelteste zuerst")
    func sortsOldestFirst() throws {
        let inbox = try makeInbox()
        let reference = Date(timeIntervalSince1970: 1_800_000_000)
        let young = try makeFile(handoffName(), in: inbox, modified: reference)
        let old = try makeFile(handoffName(), in: inbox, modified: reference - 3600)

        #expect(ShareHandoffStore.pendingFiles(in: inbox).map(\.lastPathComponent)
            == [old.lastPathComponent, young.lastPathComponent])
    }

    @Test("removeStaleFiles loescht nur Eintraege aelter als 24 Stunden")
    func removesOnlyStaleEntries() throws {
        let inbox = try makeInbox()
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        let fresh = try makeFile(handoffName(), in: inbox, modified: now - ShareHandoffStore.maxAge + 60)
        let stale = try makeFile(handoffName(), in: inbox, modified: now - ShareHandoffStore.maxAge - 60)
        let staleTmp = try makeFile("\(UUID().uuidString).tmp", in: inbox, modified: now - 48 * 3600)

        ShareHandoffStore.removeStaleFiles(in: inbox, now: now)

        #expect(FileManager.default.fileExists(atPath: fresh.path))
        #expect(!FileManager.default.fileExists(atPath: stale.path))
        #expect(!FileManager.default.fileExists(atPath: staleTmp.path))
    }
}
