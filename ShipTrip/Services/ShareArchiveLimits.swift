//
//  ShareArchiveLimits.swift
//  ShipTrip
//
//  Grenzwerte fuer geteilte Kreuzfahrten (`.shiptrip`). Sie binden beide Seiten:
//  die Export-Validierung und den Import-Preflight (Contract C10). Die Haertung des
//  `ZipArchiveReader` (Entry-Limit 50 MB, Zip-Slip, CRC) gilt zusaetzlich unveraendert.
//  Der bestehende Backup-Pfad bleibt von diesen Deckeln bewusst unberuehrt.
//

import Foundation

// MARK: - Grenzwerte

/// Reine Konstanten-Sammlung, keine Logik.
enum ShareArchiveLimits {
    /// Datei-Stat vor jeder Verarbeitung.
    static let maxArchiveFileSize = 275 * 1024 * 1024

    /// Summe der entpackten Eintraege.
    static let maxPayloadSize = 250 * 1024 * 1024

    /// Deckel auf den JSON-Dekodieraufwand.
    static let maxDataJSONSize = 10 * 1024 * 1024

    /// Haefen der einen Kreuzfahrt.
    static let maxPorts = 100

    /// Reisefotos + Hafenbilder gesamt (≈ 240 MB bei 2048 px / q0,8).
    static let maxPhotos = 300

    /// Ausgaben der einen Kreuzfahrt.
    static let maxExpenses = 1000
}
