//
//  ShareHandoffStore.swift
//  ShipTrip
//
//  Uebergabeordner der Share-Extension im App-Group-Container (ADR-010, H2).
//  Die Naht zwischen Extension (schreibt) und App (liest, importiert, loescht).
//  Nur Foundation, wie `WidgetShared/`: kein SwiftData, kein SwiftUI, keine
//  `String(localized:)`.
//

import Foundation

// MARK: - Uebergabeordner

/// Reine Pfad- und Dateilogik des Uebergabeordners. Kein Zustand, keine
/// Seiteneffekte ausser dem Loeschen abgelaufener Dateien.
///
/// - Important: Den Ordner legt die schreibende Seite (Extension) vor dem
///   ersten Kopieren mit `createDirectory(withIntermediateDirectories:)` an.
///   `inboxURL(groupID:)` liefert nur den Pfad und legt nichts an; die
///   lesenden Funktionen kommen mit einem fehlenden Ordner klar.
enum ShareHandoffStore: Sendable {

    /// App Group, die App und Extension teilen.
    static let groupID = "group.com.andre.ShipTrip"

    /// Ordnername im Container.
    static let folderName = "ShareInbox"

    /// Endung der Uebergabedateien (ohne Punkt).
    static let fileExtension = "shiptrip"

    /// Hoechstalter einer Uebergabedatei, danach raeumt die Extension sie weg.
    static let maxAge: TimeInterval = 24 * 60 * 60

    /// Laenge eines gueltigen Dateinamens: 36 UUID-Zeichen + "." + Endung.
    private static var validNameLength: Int { 36 + 1 + fileExtension.count }

    // MARK: Pfad

    /// Verzeichnis der Uebergabedateien im geteilten Container.
    ///
    /// `nil`, wenn das App-Group-Entitlement fehlt (etwa im Unit-Test-Bundle
    /// oder bei einem Build mit `CODE_SIGNING_ALLOWED=NO`). Aufrufer behandeln
    /// diesen Fall: die Extension meldet einen Fehler, die App scannt nicht.
    static func inboxURL(groupID: String = ShareHandoffStore.groupID) -> URL? {
        FileManager.default
            .containerURL(forSecurityApplicationGroupIdentifier: groupID)?
            .appendingPathComponent(folderName, isDirectory: true)
    }

    // MARK: Namenspruefung

    /// Prueft das Namensschema `<UUID>.shiptrip` rein auf dem String — bewusst
    /// nicht ueber `URL`, damit `..`, `/` und `\` per Konstruktion unmoeglich
    /// sind und kein Pfad ausserhalb des Ordners entstehen kann.
    static func isValidHandoffName(_ name: String) -> Bool {
        guard name.count == validNameLength else { return false }
        guard UUID(uuidString: String(name.prefix(36))) != nil else { return false }
        return name.dropFirst(36).lowercased() == ".\(fileExtension)"
    }

    // MARK: Lesen

    /// Regulaere, gueltig benannte Dateien direkt im Ordner — aelteste zuerst,
    /// Gleichstand nach Dateiname.
    ///
    /// Nicht rekursiv. Uebersprungen werden: Unterordner, Symlinks, versteckte
    /// Eintraege, falsch benannte Dateien (auch `.tmp`-Reste eines laufenden
    /// Kopiervorgangs) und Eintraege mit unlesbaren `resourceValues`. Fehlt der
    /// Ordner, ist das Ergebnis leer.
    static func pendingFiles(in inbox: URL) -> [URL] {
        let keys: Set<URLResourceKey> = [
            .isRegularFileKey, .isSymbolicLinkKey, .contentModificationDateKey
        ]
        guard let entries = try? FileManager.default.contentsOfDirectory(
            at: inbox,
            includingPropertiesForKeys: Array(keys),
            options: [.skipsSubdirectoryDescendants, .skipsHiddenFiles]
        ) else {
            return []
        }

        let candidates: [(url: URL, modified: Date)] = entries.compactMap { url in
            guard isValidHandoffName(url.lastPathComponent),
                  let values = try? url.resourceValues(forKeys: keys),
                  values.isRegularFile == true,
                  values.isSymbolicLink != true else {
                return nil
            }
            return (url, values.contentModificationDate ?? .distantPast)
        }

        return candidates
            .sorted { lhs, rhs in
                lhs.modified == rhs.modified
                    ? lhs.url.lastPathComponent < rhs.url.lastPathComponent
                    : lhs.modified < rhs.modified
            }
            .map(\.url)
    }

    // MARK: Aufraeumen

    /// Loescht alle Eintraege aelter als `maxAge` — auch `.tmp`-Reste eines
    /// abgebrochenen Kopiervorgangs. Die Extension ruft das vor jedem
    /// Schreiben; Fehler werden bewusst geschluckt (best effort).
    static func removeStaleFiles(in inbox: URL, now: Date = .now) {
        let keys: Set<URLResourceKey> = [.contentModificationDateKey]
        guard let entries = try? FileManager.default.contentsOfDirectory(
            at: inbox,
            includingPropertiesForKeys: Array(keys),
            options: [.skipsSubdirectoryDescendants, .skipsHiddenFiles]
        ) else {
            return
        }

        for url in entries {
            guard let modified = try? url.resourceValues(forKeys: keys).contentModificationDate,
                  now.timeIntervalSince(modified) > maxAge else {
                continue
            }
            try? FileManager.default.removeItem(at: url)
        }
    }
}
