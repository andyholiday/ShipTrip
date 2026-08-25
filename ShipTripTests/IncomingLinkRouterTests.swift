//
//  IncomingLinkRouterTests.swift
//  ShipTripTests
//
//  Vertrag des Einstiegs-Routers (Contract C3): `.shiptrip`-Dateien und `shiptrip://import`
//  werden erkannt, alles andere ist stillschweigend nicht unsere Sache.
//

import Testing
import Foundation
@testable import ShipTrip

@Suite("IncomingLinkRouter (C3)")
struct IncomingLinkRouterTests {

    @Test("file://-URL mit .shiptrip-Endung wird zur Share-Datei")
    func shareFileIsRouted() throws {
        let url = URL(fileURLWithPath: "/tmp/Documents/Inbox/Nordland.shiptrip")
        #expect(IncomingLinkRouter.route(url) == .shareFile(url))
    }

    @Test("Endung wird case-insensitiv erkannt")
    func shareFileExtensionIsCaseInsensitive() throws {
        let url = URL(fileURLWithPath: "/tmp/Nordland.SHIPTRIP")
        #expect(IncomingLinkRouter.route(url) == .shareFile(url))
    }

    @Test("Andere Datei-Endungen gehen uns nichts an")
    func foreignFileIsIgnored() throws {
        #expect(IncomingLinkRouter.route(URL(fileURLWithPath: "/tmp/backup.zip")) == nil)
        #expect(IncomingLinkRouter.route(URL(fileURLWithPath: "/tmp/daten.json")) == nil)
    }

    @Test("shiptrip://import ergibt den Link-Hinweis")
    func importSchemeIsRouted() throws {
        let url = try #require(URL(string: "shiptrip://import"))
        #expect(IncomingLinkRouter.route(url) == .importHint)
    }

    @Test("shiptrip:///import (Pfad-Schreibweise) ergibt ebenfalls den Hinweis")
    func importSchemeWithPathIsRouted() throws {
        let url = try #require(URL(string: "shiptrip:///import"))
        #expect(IncomingLinkRouter.route(url) == .importHint)
    }

    @Test("Unbekannte shiptrip-Ziele werden ignoriert — kein Fehler, kein Crash")
    func unknownSchemeTargetIsIgnored() throws {
        let url = try #require(URL(string: "shiptrip://export"))
        #expect(IncomingLinkRouter.route(url) == nil)
    }

    @Test("Fremde Schemes werden ignoriert")
    func foreignSchemeIsIgnored() throws {
        let https = try #require(URL(string: "https://example.com/import"))
        #expect(IncomingLinkRouter.route(https) == nil)
        let other = try #require(URL(string: "otherapp://import"))
        #expect(IncomingLinkRouter.route(other) == nil)
    }
}
