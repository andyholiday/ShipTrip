//
//  ShareFingerprint.swift
//  ShipTrip
//
//  Inhalts-Fingerabdruck einer geteilten Kreuzfahrt (Contract C1).
//
//  Der Wert wird **einmal vom Sender** beim Share-Export berechnet und in der Datei
//  gespeichert; der Empfaenger persistiert ihn und rechnet ihn nie nach. Determinismus
//  wird deshalb nur senderlokal benoetigt (ein Prozess, eine Foundation-Version) —
//  geraeteuebergreifend byte-identische Kanonisierung wird weder gebraucht noch behauptet.
//

import CryptoKit
import Foundation

// MARK: - Fingerabdruck

/// Reine Funktion ueber dem Export-DTO — kein Zustand, keine Aktor-Isolation.
enum ShareFingerprint {

    /// SHA-256-Hex ueber das kanonische JSON-Encoding der Kreuzfahrt.
    ///
    /// Kanonisch heisst: `JSONEncoder` mit ausschliesslich `.sortedKeys`, ohne
    /// `.prettyPrinted`. Bildreferenzen stehen im DTO bereits als ZIP-Pfade, Datumsfelder
    /// als Strings des Export-`dateFormatter`.
    static func contentFingerprint(for cruise: ExportCruise) throws -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        let canonical = try encoder.encode(cruise)
        return SHA256.hash(data: canonical)
            .map { String(format: "%02x", $0) }
            .joined()
    }
}
