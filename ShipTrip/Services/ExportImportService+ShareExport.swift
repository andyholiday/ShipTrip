//
//  ExportImportService+ShareExport.swift
//  ShipTrip
//
//  Export-Seite des Teilens (Contract C5): genau eine Kreuzfahrt als `.shiptrip`-Datei.
//  Wiederverwendet den Backup-Pfad (`buildArchive`, `encodeArchive`, `ExportImageSource`,
//  `ZipArchiveStreamWriter`) — neu sind nur Transcode-Spool, `share`-Metablock,
//  Einzel-Cruise-Zuschnitt und Dateiname.
//

import Foundation
import SwiftData

// MARK: - Share-Export-Fehler

/// Fehler, die den Share-Export abbrechen, *bevor* eine `.shiptrip`-Datei entsteht, bzw. die
/// eine angefangene Datei verwerfen (Alles-oder-nichts wie beim Backup).
///
/// Die Texte sind nutzersichtbar: Die Teilen-UI interpoliert sie in die Hülle
/// „Teilen fehlgeschlagen: %@" (Contract C8) und zeigt sie im Alert. Deshalb laufen sie über
/// `String(localized:)` (DE/EN). Der technische `reason` von `limitExceeded` bleibt bewusst
/// unlokalisiert — er trägt nur Byte-/Stückzahlen aus dem Service.
enum ShareExportError: LocalizedError {
    /// Die Beispielreise (`isDemo`) wird nicht geteilt.
    case demoCruise
    /// Ein Bild ließ sich nicht als Share-JPEG transkodieren — kein halbes Archiv.
    case transcodeFailed(entryName: String)
    /// Die Reise überschreitet die Share-Grenzen aus `ShareArchiveLimits` (Contract C10).
    case limitExceeded(reason: String)

    var errorDescription: String? {
        switch self {
        case .demoCruise:
            return String(localized: "Die Beispielreise kann nicht geteilt werden.")
        case .transcodeFailed(let entryName):
            return String(
                localized: "Das Bild '\(entryName)' ließ sich nicht für den Versand aufbereiten."
            )
        case .limitExceeded(let reason):
            return String(
                localized: "Die Reise überschreitet die Grenzen für geteilte Reisen: \(reason)"
            )
        }
    }
}

// MARK: - Export einer einzelnen Kreuzfahrt

extension ExportImportService {

    /// Erzeugt die `.shiptrip`-Datei für genau eine Kreuzfahrt im Temp-Verzeichnis.
    ///
    /// Ablauf in drei Phasen (Design-Doc §4):
    /// 1. **MainActor-Snapshot:** Demo-Sperre, Zählgrenzen (vor jeder Transcode-Arbeit),
    ///    `buildArchive` mit `share`-Block inkl. `contentFingerprint`, `encodeArchive`.
    /// 2. **Off-main Transcode-Spool:** pro Bild ein kurzer MainActor-Hop für die Roh-Bytes,
    ///    dann `ShareImageTranscoder` und Schreiben nach `spool/<entryName>`. Speicherprofil
    ///    O(größtes Bild), jedes Bild genau einmal transkodiert.
    /// 3. **Validieren + Schreiben:** Größenprüfung über JSON- und Spool-Größen (exakt, weil
    ///    STORED) gegen `ShareArchiveLimits`; dann schreibt `ZipArchiveStreamWriter` strömend.
    ///
    /// Alles-oder-nichts wie `exportToZip`: Spool und Zieldatei verschwinden im Fehlerfall,
    /// der Spool auch im Erfolgsfall. Der Aufrufer löscht die Zieldatei (bzw. deren
    /// Elternordner) nach Abschluss der Share-Präsentation.
    func exportCruiseForSharing(_ cruise: Cruise) async throws -> URL {
        // --- Phase 1: Snapshot auf dem MainActor ---

        guard !cruise.isDemo else { throw ShareExportError.demoCruise }

        guard cruise.route.count <= ShareArchiveLimits.maxPorts else {
            throw ShareExportError.limitExceeded(
                reason: "\(cruise.route.count) Häfen; erlaubt sind \(ShareArchiveLimits.maxPorts)."
            )
        }
        guard cruise.expenses.count <= ShareArchiveLimits.maxExpenses else {
            throw ShareExportError.limitExceeded(
                reason: "\(cruise.expenses.count) Ausgaben; "
                    + "erlaubt sind \(ShareArchiveLimits.maxExpenses)."
            )
        }

        let imageSource = ExportImageSource(cruises: [cruise])
        let imageCount = imageSource.entryNames.count
        guard imageCount <= ShareArchiveLimits.maxPhotos else {
            throw ShareExportError.limitExceeded(
                reason: "\(imageCount) Bilder; erlaubt sind \(ShareArchiveLimits.maxPhotos)."
            )
        }

        let jsonData = try encodeArchive(makeShareArchive(for: cruise))
        guard jsonData.count <= ShareArchiveLimits.maxDataJSONSize else {
            throw ShareExportError.limitExceeded(
                reason: "data.json belegt \(jsonData.count) Bytes; "
                    + "erlaubt sind \(ShareArchiveLimits.maxDataJSONSize)."
            )
        }

        // --- Phase 2: Transcode-Spool, off-main ---

        let spool = FileManager.default.temporaryDirectory
            .appendingPathComponent("share-spool-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: spool, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: spool) }

        var spooledSizes: [Int] = []
        spooledSizes.reserveCapacity(imageCount)
        for (index, name) in imageSource.entryNames.enumerated() {
            try Task.checkCancellation()
            let raw = try imageSource.data(at: index)   // MainActor-Hop: genau ein Bild
            let size = try await Self.spoolShareImage(
                raw, as: name, to: spool.appendingPathComponent(name)
            )
            spooledSizes.append(size)
        }

        // --- Phase 3: Validieren + strömend schreiben ---

        try Self.validateShareArchiveSize(
            jsonByteCount: jsonData.count,
            entryNames: imageSource.entryNames,
            spooledSizes: spooledSizes
        )

        // Frischer Unterordner: der Anzeigename im Share-Sheet ist der Dateiname, und
        // gleichnamige Reisen dürfen sich nicht gegenseitig überschreiben.
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("share-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let fileURL = directory
            .appendingPathComponent("\(Self.shareFileSlug(for: cruise.title)).shiptrip")

        var entries: [ZipArchiveStreamWriter.Entry] = [
            ZipArchiveStreamWriter.Entry(name: "data.json", body: { jsonData })
        ]
        entries.append(contentsOf: imageSource.entryNames.map { name in
            let spooled = spool.appendingPathComponent(name)
            return ZipArchiveStreamWriter.Entry(name: name, body: { try Data(contentsOf: spooled) })
        })

        do {
            try Task.checkCancellation()
            try await ZipArchiveStreamWriter().write(entries: entries, to: fileURL)
        } catch {
            try? FileManager.default.removeItem(at: directory)
            throw error
        }

        return fileURL
    }

    // MARK: - Bausteine

    /// Envelope v2 mit genau einer Kreuzfahrt, leeren Sammlungen und dem `share`-Block (C1).
    private func makeShareArchive(for cruise: Cruise) throws -> ExportArchive {
        let base = buildArchive(
            cruises: [cruise],
            deals: [],
            customLines: [],
            customShips: [],
            hiddenCatalogItems: [],
            photoEncoder: { cruise, sortedPhotos in
                sortedPhotos.enumerated().map { index, photo in
                    ExportPhoto(
                        id: photo.id.uuidString,
                        ref: "images/\(cruise.id.uuidString)/\(index)"
                    )
                }
            },
            portImageURL: { cruise, port, index in
                port.imageData != nil ? "images/\(cruise.id.uuidString)/ports/\(index)" : nil
            }
        )

        // Unerreichbar — `buildArchive` bekommt genau diese eine Kreuzfahrt. Der Guard steht
        // hier nur, weil Force-Unwraps im Projekt nicht zulässig sind.
        guard let shared = base.cruises.first else {
            throw ShareExportError.limitExceeded(
                reason: "Die Reise enthält keine übertragbaren Daten."
            )
        }

        let appVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String
        let share = ExportShareInfo(
            shareFormatVersion: ExportShareInfo.currentShareFormatVersion,
            sharedAt: isoFormatter.string(from: Date()),
            appVersion: appVersion ?? "1.0",
            contentFingerprint: try ShareFingerprint.contentFingerprint(for: shared)
        )

        return ExportArchive(
            formatVersion: base.formatVersion,
            cruises: base.cruises,
            deals: base.deals,
            customShippingLines: base.customShippingLines,
            customShips: base.customShips,
            hiddenCatalogItems: base.hiddenCatalogItems,
            share: share
        )
    }

    /// Transkodiert ein Bild off-main und legt es im Spool ab; gibt die Bytegröße zurück.
    ///
    /// `Task.detached` statt bloßer `async`-Deklaration: Unter Swift 6 garantiert erst der
    /// abgetrennte Task, dass die ImageIO-Arbeit den MainActor wirklich verlässt.
    private static func spoolShareImage(
        _ raw: Data,
        as entryName: String,
        to target: URL
    ) async throws -> Int {
        try await Task.detached(priority: .userInitiated) {
            guard let jpeg = ShareImageTranscoder.downscaledJPEG(from: raw) else {
                throw ShareExportError.transcodeFailed(entryName: entryName)
            }
            try FileManager.default.createDirectory(
                at: target.deletingLastPathComponent(), withIntermediateDirectories: true
            )
            try jpeg.write(to: target)
            return jpeg.count
        }.value
    }

    /// Prüft die geplante Archivgröße gegen `ShareArchiveLimits` — die engeren Share-Grenzen,
    /// nicht die weiteren Backup-Grenzen (C5). Exakt statt geschätzt, weil STORED unkomprimiert
    /// schreibt; die Strukturbytes entsprechen `validateArchiveSize` im Backup-Pfad.
    private static func validateShareArchiveSize(
        jsonByteCount: Int,
        entryNames: [String],
        spooledSizes: [Int]
    ) throws {
        var payload = jsonByteCount
        var structureBytes = shareZipStructureBytes(forEntryName: "data.json")
        for (name, size) in zip(entryNames, spooledSizes) {
            payload += size
            structureBytes += shareZipStructureBytes(forEntryName: name)
        }

        guard payload <= ShareArchiveLimits.maxPayloadSize else {
            throw ShareExportError.limitExceeded(
                reason: "Die Inhalte belegen \(payload) Bytes; "
                    + "erlaubt sind \(ShareArchiveLimits.maxPayloadSize)."
            )
        }

        // 22 Bytes End of Central Directory.
        let fileSize = payload + structureBytes + 22
        guard fileSize <= ShareArchiveLimits.maxArchiveFileSize else {
            throw ShareExportError.limitExceeded(
                reason: "Die Datei würde \(fileSize) Bytes belegen; "
                    + "erlaubt sind \(ShareArchiveLimits.maxArchiveFileSize)."
            )
        }
    }

    /// Local File Header (30 B + Name) + Central-Directory-Eintrag (46 B + Name).
    private static func shareZipStructureBytes(forEntryName name: String) -> Int {
        30 + 46 + 2 * name.utf8.count
    }

    /// Dateiname-Slug: Alphanumerik und Bindestriche, Umlaute/Diakritika transliteriert,
    /// leer → „Kreuzfahrt". Auf 60 Zeichen gedeckelt, damit lange Reisetitel keine
    /// unbrauchbaren Dateinamen erzeugen.
    static func shareFileSlug(for title: String) -> String {
        let latin = title.applyingTransform(
            StringTransform("Any-Latin; Latin-ASCII"), reverse: false
        ) ?? title

        var slug = ""
        for character in latin {
            if character.isASCII, character.isLetter || character.isNumber {
                slug.append(character)
            } else if !slug.isEmpty, slug.last != "-" {
                slug.append("-")
            }
        }
        while slug.hasSuffix("-") { slug.removeLast() }

        let trimmed = String(slug.prefix(60))
        return trimmed.isEmpty ? "Kreuzfahrt" : trimmed
    }
}
