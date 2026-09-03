//
//  WidgetSnapshotStore.swift
//  ShipTrip
//
//  Lesen und Schreiben der Snapshot-Datei im App-Group-Container
//  (Taskplan 1.9.0, Leitentscheidung 3). Nur Foundation, siehe
//  `WidgetSnapshot.swift`.
//

import Foundation

// MARK: - Ladeergebnis

/// Ergebnis eines Lesevorgangs.
///
/// `WidgetSnapshotStore.load()` wirft nie und stuerzt nie ab: jeder Fehlerfall
/// wird auf einen dieser Faelle abgebildet.
enum WidgetSnapshotLoadResult: Sendable, Equatable {
    /// Gueltige Datei der aktuellen Schema-Version.
    case snapshot(WidgetSnapshot)
    /// Es gibt (noch) keine Datei — die App hat nie veroeffentlicht.
    case missing
    /// Datei vorhanden, aber nicht verwertbar: kaputtes JSON, falsche Struktur
    /// oder eine fremde `schemaVersion`.
    case unreadable
}

// MARK: - Store

/// Dateizugriff auf den Widget-Snapshot. Der Store haelt keinen Zustand und
/// ist damit gefahrlos ueber Aktorgrenzen weiterzureichen.
///
/// - Important: Schreibende Zugriffe der App laufen ausschliesslich ueber den
///   `WidgetSnapshotWriter`-Aktor (App-Seite), nie direkt ueber `save(_:)`.
struct WidgetSnapshotStore: Sendable {

    /// Dateiname im Container. Der Store besitzt den Namen, nicht der Aufrufer.
    static let fileName = "widget-snapshot.json"

    /// Verzeichnis, in dem die Snapshot-Datei liegt (App-Group-Container oder
    /// im Test ein temporaeres Verzeichnis).
    let containerURL: URL

    /// Vollstaendiger Pfad der Snapshot-Datei.
    var fileURL: URL {
        containerURL.appendingPathComponent(Self.fileName, isDirectory: false)
    }

    init(containerURL: URL) {
        self.containerURL = containerURL
    }

    /// Verzeichnis des geteilten App-Group-Containers.
    ///
    /// Gedacht als Eingabe fuer `init(containerURL:)` — den Dateinamen haengt
    /// der Store selbst an, damit der Pfad nur an einer Stelle entsteht.
    /// `nil`, wenn das App-Group-Entitlement fehlt (etwa im Unit-Test-Bundle);
    /// Aufrufer muessen diesen Fall behandeln, statt ihn auszupacken.
    static func appGroupURL(groupID: String = "group.com.andre.ShipTrip") -> URL? {
        FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: groupID)
    }

    // MARK: Lesen

    /// Liest den Snapshot. Wirft nie.
    func load() -> WidgetSnapshotLoadResult {
        let url = fileURL
        guard FileManager.default.fileExists(atPath: url.path) else {
            return .missing
        }
        guard let data = try? Data(contentsOf: url) else {
            return .unreadable
        }
        guard let snapshot = try? Self.makeDecoder().decode(WidgetSnapshot.self, from: data),
              snapshot.schemaVersion == WidgetSnapshot.current else {
            return .unreadable
        }
        return .snapshot(snapshot)
    }

    // MARK: Schreiben

    /// Schreibt den Snapshot atomar.
    ///
    /// Das Verzeichnis wird bei Bedarf angelegt. Scheitert der Schreibvorgang,
    /// wirft die Methode und die zuvor vorhandene Datei bleibt unveraendert
    /// erhalten (Last-known-good) — dafuer sorgt `.atomic`.
    func save(_ snapshot: WidgetSnapshot) throws {
        let data = try Self.makeEncoder().encode(snapshot)
        try FileManager.default.createDirectory(
            at: containerURL,
            withIntermediateDirectories: true
        )
        try data.write(to: fileURL, options: .atomic)
    }

    // MARK: Codierung

    // Bewusst pro Aufruf erzeugt: `JSONEncoder`/`JSONDecoder` sind Klassen und
    // damit nicht `Sendable` — als statische Konstanten waeren sie unter
    // Swift-6-Isolation nicht zulaessig.

    static func makeEncoder() -> JSONEncoder {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }

    static func makeDecoder() -> JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }
}
