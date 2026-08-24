//
//  ExportImportService+Export.swift
//  ShipTrip
//
//  Die Export-Einstiegspunkte. Der Envelope-Bau (`buildArchive`) liegt in
//  `ExportImportService.swift`, der Lesepfad in `ExportImportService+Import.swift`.
//

import Foundation
import SwiftData

// MARK: - Bildquelle für den strömenden Export

/// Liefert die Roh-Bytes der Export-Bilder einzeln nach — in exakt der Reihenfolge, in der
/// `exportToZip` sie als ZIP-Einträge schreibt.
///
/// Der Sinn ist das Speicherprofil: SwiftData-`@Model`-Objekte dürfen die Aktorgrenze nicht
/// überqueren, deshalb bleibt der Zugriff auf `Photo.imageData` / `Port.imageData` hier auf dem
/// MainActor. Weil die Klasse `@MainActor`-isoliert (und damit `Sendable`) ist, kann der
/// off-main laufende ZIP-Writer sie halten und pro Eintrag genau ein Bild anfordern. Der
/// Spitzenverbrauch liegt damit bei O(größtes Bild) statt bei O(Bibliothek).
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
    func data(at index: Int) -> Data {
        switch sources[index] {
        case .photo(let photo):
            return photo.imageData
        case .portImage(let port):
            // `imageData` wurde beim Aufbau als non-nil geprüft; ein leerer Eintrag ist
            // trotzdem besser als ein Absturz, falls das Modell zwischenzeitlich geleert wurde.
            return port.imageData ?? Data()
        }
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
                    return ExportPhoto(id: photo.id.uuidString, ref: "data:image/png;base64,\(base64)")
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
                    ExportPhoto(id: photo.id.uuidString, ref: "images/\(cruise.id.uuidString)/\(index)")
                }
            },
            portImageURL: { cruise, port, index in
                port.imageData != nil ? "images/\(cruise.id.uuidString)/ports/\(index)" : nil
            }
        )

        let jsonData = try encodeArchive(archive)
        let imageSource = ExportImageSource(cruises: exportableCruises)

        var entries: [ZipArchiveStreamWriter.Entry] = [
            ZipArchiveStreamWriter.Entry(name: "data.json", body: { jsonData })
        ]
        entries.append(contentsOf: imageSource.entryNames.enumerated().map { index, name in
            ZipArchiveStreamWriter.Entry(name: name, body: { await imageSource.data(at: index) })
        })

        // --- Phase 2: strömendes Schreiben außerhalb des MainActors ---

        let zipPath = FileManager.default.temporaryDirectory
            .appendingPathComponent("kreuzfahrten-export-\(UUID().uuidString).zip")

        do {
            try await ZipArchiveStreamWriter().write(entries: entries, to: zipPath)
        } catch {
            // Kein halbfertiges Archiv im Temp-Verzeichnis zurücklassen — es sähe aus wie ein
            // gültiges Backup.
            try? FileManager.default.removeItem(at: zipPath)
            throw error
        }

        return zipPath
    }
}
