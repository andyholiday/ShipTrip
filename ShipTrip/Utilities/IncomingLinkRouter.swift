//
//  IncomingLinkRouter.swift
//  ShipTrip
//
//  Eine Auswertungsstelle fuer alle eingehenden URLs (Datei-Oeffnen + Custom-Scheme,
//  Contract C3). Kalt- und Warmstart laufen ueber denselben Weg; unbekannte URLs
//  werden still ignoriert.
//

import Foundation

// MARK: - Ergebnis

/// Was eine eingehende URL fuer die App bedeutet.
enum IncomingLink: Equatable {
    /// `file://`-URL einer angetippten `.shiptrip`-Datei (Documents/Inbox oder Files-App).
    case shareFile(URL)
    /// `shiptrip://import` — nur App oeffnen + Hinweis zeigen (der Link traegt keine Daten).
    case importHint
}

// MARK: - Router

enum IncomingLinkRouter {

    /// Dateiendung geteilter Reisen (C1/C2).
    private static let shareFileExtension = "shiptrip"

    /// Custom-Scheme der App (`CFBundleURLTypes`, Seed W0).
    private static let scheme = "shiptrip"

    /// Einziges v1-Ziel des Schemes.
    private static let importHost = "import"

    /// `nil` = die URL geht uns nichts an (weder `.shiptrip`-Datei noch bekannte
    /// `shiptrip://`-URL). Kein Fehler, kein Crash.
    static func route(_ url: URL) -> IncomingLink? {
        if url.isFileURL {
            guard url.pathExtension.lowercased() == shareFileExtension else { return nil }
            return .shareFile(url)
        }

        guard url.scheme?.lowercased() == scheme else { return nil }

        // `shiptrip://import` liefert den Ziel-Namen als Host, `shiptrip:///import`
        // als ersten Pfadbestandteil — beide Schreibweisen fuehren zum Hinweis.
        let target = url.host?.lowercased()
            ?? url.path.split(separator: "/").first.map { $0.lowercased() }
        guard target == importHost else { return nil }
        return .importHint
    }
}
