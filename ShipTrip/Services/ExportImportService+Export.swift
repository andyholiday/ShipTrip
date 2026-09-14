//
//  ExportImportService+Export.swift
//  ShipTrip
//
//  Die Export-Einstiegspunkte. Der Envelope-Bau (`buildArchive`) liegt in
//  `ExportImportService.swift`, der Lesepfad in `ExportImportService+Import.swift`.
//

import Foundation
import SwiftData

// MARK: - Export-Fehler

/// Fehler, die den Export abbrechen, *bevor* eine Datei entsteht bzw. die eine angefangene Datei
/// verwerfen. Alle drei Fälle hätten sonst ein Backup ergeben, das entweder unvollständig ist oder
/// vom eigenen Import abgelehnt würde.
enum ExportError: LocalizedError {
    /// Ein referenziertes Bild liefert keine Bytes mehr (Modell zwischenzeitlich geleert, externer
    /// Speicher nicht lesbar). Ein leerer ZIP-Eintrag wäre CRC-konsistent und damit unsichtbar
    /// kaputt — deshalb bricht der Export ab.
    case missingMedia(entryName: String)
    /// Ein einzelner Eintrag überschreitet `ZipArchiveReader.maxEntryUncompressedSize`.
    case entryTooLarge(name: String, size: Int)
    /// Die Nutzlast überschreitet `ZipArchiveReader.maxTotalUncompressedSize`.
    case payloadTooLarge(Int)
    /// Die resultierende ZIP-Datei überschreitet `ZipArchiveReader.maxArchiveFileSize`.
    case archiveTooLarge(Int)

    var errorDescription: String? {
        switch self {
        case .missingMedia(let entryName):
            return String(localized: "Backup abgebrochen: Das Bild '\(entryName)' ist nicht mehr lesbar. Es wäre als leerer Eintrag im Archiv gelandet.")
        case .entryTooLarge(let name, let size):
            return String(localized: "Backup wäre nicht wiederherstellbar: Das Bild '\(name)' ist zu groß (\(size) Bytes; Maximum \(ZipArchiveReader.maxEntryUncompressedSize) Bytes).")
        case .payloadTooLarge(let size):
            return String(localized: "Backup wäre zu groß: Die Daten belegen \(size) Bytes; Maximum sind \(ZipArchiveReader.maxTotalUncompressedSize) Bytes. Bitte in kleineren Teilen sichern.")
        case .archiveTooLarge(let size):
            return String(localized: "Backup wäre zu groß: Die ZIP-Datei würde \(size) Bytes belegen; Maximum sind \(ZipArchiveReader.maxArchiveFileSize) Bytes. Bitte in kleineren Teilen sichern.")
        }
    }
}

// MARK: - Bildquelle für den strömenden Export

/// Liefert die Roh-Bytes der Export-Bilder einzeln nach — in exakt der Reihenfolge, in der
/// `exportToZip` sie als ZIP-Einträge schreibt.
///
/// Der Sinn ist das Speicherprofil: SwiftData-`@Model`-Objekte dürfen die Aktorgrenze nicht
/// überqueren, deshalb bleibt der Zugriff auf `Photo.imageData` / `Port.imageData` hier auf dem
/// MainActor. Weil die Klasse `@MainActor`-isoliert (und damit `Sendable`) ist, kann der
/// off-main laufende ZIP-Writer sie halten und pro Eintrag genau ein Bild anfordern. Der
/// Spitzenverbrauch liegt damit bei O(größtes Bild) statt bei O(Bibliothek).
///
/// Die Klasse hält bewusst Referenzen auf die `@Model`-Objekte (nicht bloß deren Namen) und liest
/// die Bytes erst bei `data(at:)` — genau das ist der Grund, warum der Zugriff MainActor-isoliert
/// bleiben muss.
@MainActor
final class ExportImageSource {
    private enum Source {
        case photo(Photo)
        case portImage(Port)
    }

    /// Die ZIP-Eintragsnamen in Schreibreihenfolge. `nonisolated`, weil der Writer sie
    /// außerhalb des MainActors braucht — `[String]` ist `Sendable`.
    nonisolated let entryNames: [String]

    private let sources: [Source]

    /// Erwartet bereits demo-gefilterte Kreuzfahrten (siehe `ExportImportService.nonDemo`).
    init(cruises: [Cruise]) {
        var names: [String] = []
        var sources: [Source] = []

        for cruise in cruises {
            let sortedRoute = cruise.route.sorted { $0.sortOrder < $1.sortOrder }
            for (index, port) in sortedRoute.enumerated() where port.imageData != nil {
                names.append("images/\(cruise.id.uuidString)/ports/\(index)")
                sources.append(.portImage(port))
            }

            let sortedPhotos = cruise.photos.sorted { $0.sortOrder < $1.sortOrder }
            for (index, photo) in sortedPhotos.enumerated() {
                names.append("images/\(cruise.id.uuidString)/\(index)")
                sources.append(.photo(photo))
            }
        }

        self.entryNames = names
        self.sources = sources
    }

    /// Bytes des Eintrags `index` — genau ein Bild, nicht die Bibliothek.
    ///
    /// Wirft, wenn die Quelle keine Bytes mehr liefert (Modell zwischenzeitlich geleert, externer
    /// Speicher nicht lesbar). Früher entstand daraus ein leerer, CRC-konsistenter ZIP-Eintrag und
    /// der Export meldete Erfolg — ein stilles Datenloch im Backup. Ein Abbruch ist die
    /// Konsistenzgarantie: entweder das Archiv enthält alle Medien, oder es entsteht keines.
    func data(at index: Int) throws -> Data {
        let bytes: Data?
        switch sources[index] {
        case .photo(let photo):
            bytes = photo.imageData
        case .portImage(let port):
            bytes = port.imageData
        }
        guard let bytes, !bytes.isEmpty else {
            throw ExportError.missingMedia(entryName: entryNames[index])
        }
        return bytes
    }

    /// Bytegröße des Eintrags `index` für die Vorabprüfung der Archivgrenzen. Fasst wie `data(at:)`
    /// immer nur ein Bild an.
    func byteCount(at index: Int) throws -> Int {
        try data(at: index).count
    }
}

// MARK: - Export

extension ExportImportService {

    /// Exportiert Kreuzfahrten samt Wunschreisen und Katalog-Overlay als JSON-Datei mit stabilen
    /// IDs (kein frisches UUID()). Fotos stecken Base64-kodiert inline in der Datei.
    ///
    /// Bewusst synchron und auf dem MainActor: Das JSON-Format hält alle Bilder als
    /// Base64-Strings *im* Dokument, ist damit prinzipbedingt nicht strömbar (O(Bibliothek)),
    /// und hat keine UI-Aufrufstelle mehr — die App exportiert über `exportToZip`. Der JSON-Pfad
    /// bleibt als Lese-/Schreib-Referenz für ältere Backups und Tests bestehen.
    func exportToJSON(
        cruises: [Cruise],
        deals: [Deal] = [],
        customLines: [CustomShippingLine] = [],
        customShips: [CustomShip] = [],
        hiddenCatalogItems: [HiddenCatalogItem] = []
    ) throws -> URL {
        let archive = buildArchive(
            cruises: Self.nonDemo(cruises),
            deals: Self.nonDemo(deals),
            customLines: customLines,
            customShips: customShips,
            hiddenCatalogItems: hiddenCatalogItems,
            photoEncoder: { _, sortedPhotos in
                sortedPhotos.map { photo in
                    let base64 = photo.imageData.base64EncodedString()
                    return ExportPhoto(
                        id: photo.id.uuidString,
                        ref: "data:image/png;base64,\(base64)",
                        caption: Self.exportCaption(photo)
                    )
                }
            }
        )

        let jsonData = try encodeArchive(archive)

        let jsonPath = FileManager.default.temporaryDirectory
            .appendingPathComponent("kreuzfahrten-export-\(UUID().uuidString).json")
        try jsonData.write(to: jsonPath)

        return jsonPath
    }

    /// Exportiert alle Kreuzfahrten als ZIP-Archiv mit externalen Bilddateien.
    ///
    /// ZIP-Inhalt:
    /// - `data.json` – strukturierte Daten; Fotos als Pfadreferenzen `images/<cruiseId>/<index>`
    /// - `images/<cruiseId>/<index>` – Rohdaten aus `Photo.imageData` (verlustfrei, kein Re-Encoding)
    ///
    /// Das ZIP wird mit Compression Method 0 (STORED) geschrieben; kein Deflate.
    /// CRC-32 wird korrekt berechnet (IEEE 802.3 Polynom).
    ///
    /// Ablauf in zwei Phasen (C4):
    /// 1. **MainActor, synchron:** Aus den `@Model`-Objekten entsteht der Sendable-Snapshot —
    ///    `data.json` als fertige Bytes plus eine `ExportImageSource` mit der Eintragsliste.
    ///    Bild-Bytes werden hier bewusst *nicht* eingesammelt.
    /// 2. **Off-main:** `ZipArchiveStreamWriter` (ein `actor`) schreibt das Archiv strömend in
    ///    die Zieldatei und holt sich jedes Bild einzeln über einen kurzen MainActor-Hop.
    ///
    /// Damit blockiert der Export weder den Main-Thread (CRC-32, Dateischreiben laufen off-main)
    /// noch hält er mehr als ein Bild gleichzeitig im Speicher.
    ///
    /// Alles-oder-nichts: Überschreitet das geplante Archiv die Importgrenzen, fehlt ein Bild oder
    /// wird der Task abgebrochen, wirft der Export und lässt keine Datei zurück. Ein teilweise
    /// geschriebenes Backup wäre von einem vollständigen nicht zu unterscheiden.
    func exportToZip(
        cruises: [Cruise],
        deals: [Deal] = [],
        customLines: [CustomShippingLine] = [],
        customShips: [CustomShip] = [],
        hiddenCatalogItems: [HiddenCatalogItem] = []
    ) async throws -> URL {
        // --- Phase 1: Snapshot auf dem MainActor ---

        // Demo-Daten gehören nie in ein Backup. Der Filter liegt bewusst hier im Service und
        // nicht an der Aufrufstelle, damit ihn jeder Export-Pfad zwangsläufig durchläuft.
        let exportableCruises = Self.nonDemo(cruises)

        // Baue JSON mit Pfadreferenzen (Dateiname ohne Extension; Erweiterung ist kosmetisch)
        let archive = buildArchive(
            cruises: exportableCruises,
            deals: Self.nonDemo(deals),
            customLines: customLines,
            customShips: customShips,
            hiddenCatalogItems: hiddenCatalogItems,
            photoEncoder: { cruise, sortedPhotos in
                sortedPhotos.enumerated().map { index, photo in
                    ExportPhoto(
                        id: photo.id.uuidString,
                        ref: "images/\(cruise.id.uuidString)/\(index)",
                        caption: Self.exportCaption(photo)
                    )
                }
            },
            portImageURL: { cruise, port, index in
                port.imageData != nil ? "images/\(cruise.id.uuidString)/ports/\(index)" : nil
            }
        )

        let jsonData = try encodeArchive(archive)
        let imageSource = ExportImageSource(cruises: exportableCruises)

        // Grenzen prüfen, BEVOR eine Datei entsteht (siehe `validateArchiveSize`).
        try Self.validateArchiveSize(jsonByteCount: jsonData.count, imageSource: imageSource)

        var entries: [ZipArchiveStreamWriter.Entry] = [
            ZipArchiveStreamWriter.Entry(name: "data.json", body: { jsonData })
        ]
        entries.append(contentsOf: imageSource.entryNames.enumerated().map { index, name in
            ZipArchiveStreamWriter.Entry(name: name, body: { try await imageSource.data(at: index) })
        })

        // --- Phase 2: strömendes Schreiben außerhalb des MainActors ---

        // Ein Abbruch während Phase 1 soll gar nicht erst eine Datei anlegen.
        try Task.checkCancellation()

        let zipPath = FileManager.default.temporaryDirectory
            .appendingPathComponent("kreuzfahrten-export-\(UUID().uuidString).zip")

        do {
            try await ZipArchiveStreamWriter().write(entries: entries, to: zipPath)
        } catch {
            // Der Writer räumt bereits selbst auf; dieser zweite Griff kostet nichts und hält die
            // Zusage „kein halbfertiges Archiv im Temp-Verzeichnis" auch dann, wenn der Fehler
            // erst nach dem Schreiben auftritt.
            try? FileManager.default.removeItem(at: zipPath)
            throw error
        }

        return zipPath
    }

    // MARK: - Vorabprüfung der Archivgrenzen

    /// Prüft die geplante Archivgröße gegen dieselben Grenzen, die `importFromZip` beim Lesen
    /// anlegt (`ZipArchiveReader.max*` — die eine Quelle für beide Richtungen).
    ///
    /// Ohne diese Prüfung konnte die App ein Backup schreiben, das ihr eigener Import anschließend
    /// ablehnt: der Writer kennt nur die ZIP32-Grenze (4 GB), der Reader steigt schon bei 50 MB je
    /// Bild bzw. 500 MB Nutzlast aus.
    ///
    /// Der Preis ist ein zusätzlicher Lesedurchlauf über die Bilder. Das Speicherprofil bleibt
    /// davon unberührt — es wird immer nur ein Bild angefasst, nie die Bibliothek gehalten.
    static func validateArchiveSize(jsonByteCount: Int, imageSource: ExportImageSource) throws {
        guard jsonByteCount <= ZipArchiveReader.maxEntryUncompressedSize else {
            throw ExportError.entryTooLarge(name: "data.json", size: jsonByteCount)
        }

        var payload = jsonByteCount
        var structureBytes = zipStructureBytes(forEntryName: "data.json")

        for (index, name) in imageSource.entryNames.enumerated() {
            let size = try imageSource.byteCount(at: index)
            guard size <= ZipArchiveReader.maxEntryUncompressedSize else {
                throw ExportError.entryTooLarge(name: name, size: size)
            }
            payload += size
            structureBytes += zipStructureBytes(forEntryName: name)
            guard payload <= ZipArchiveReader.maxTotalUncompressedSize else {
                throw ExportError.payloadTooLarge(payload)
            }
        }

        // 22 Bytes End of Central Directory. Damit ist die Dateigröße exakt vorhergesagt, nicht
        // geschätzt — STORED schreibt unkomprimiert.
        let fileSize = payload + structureBytes + 22
        guard fileSize <= ZipArchiveReader.maxArchiveFileSize else {
            throw ExportError.archiveTooLarge(fileSize)
        }
    }

    /// Local File Header (30 B + Name) + Central-Directory-Eintrag (46 B + Name) eines Eintrags.
    private static func zipStructureBytes(forEntryName name: String) -> Int {
        30 + 46 + 2 * name.utf8.count
    }

    /// Bildunterschrift fürs DTO (ADR-003): leer → `nil`, damit der Schlüssel in Dateien ohne
    /// Captions gar nicht erst auftaucht (byte-identisch zu 1.8.0).
    static func exportCaption(_ photo: Photo) -> String? {
        photo.caption.isEmpty ? nil : photo.caption
    }
}
