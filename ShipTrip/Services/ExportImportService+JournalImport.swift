//
//  ExportImportService+JournalImport.swift
//  ShipTrip
//
//  Import-Seite der Journal-Einträge (ADR-003 → „Export- und Teilen-Integration",
//  T7b-Contract). Gilt für beide Türen: ZIP-Backup und `.shiptrip`-Teilen laufen
//  durch denselben Import-Kern (`importFromJSONData`).
//

import Foundation
import SwiftData

extension ExportImportService {

    /// Legt die Journal-Einträge einer importierten Reise an und rekonstruiert ihre Bezüge.
    ///
    /// Vertrag (ADR-003):
    /// - **Re-Linking** über die stabilen UUIDs *innerhalb derselben Reise*; nicht auflösbare
    ///   IDs werden still verworfen — der Eintrag kommt ohne diesen Bezug an, das Foto bleibt
    ///   Reise-Kind, der Import bricht nie ab.
    /// - **Normalisierung:** `entryDate` landet immer auf 12:00 UTC seines UTC-Tag-Tripels
    ///   (Zeitzonen-Vertrag), egal wie unnormalisiert die Fremddatei war.
    /// - **`moodRaw`** wird verbatim übernommen, auch unbekannte Rohwerte
    ///   (Unknown-Preservation, J4).
    /// - **LWW:** `createdAt`/`updatedAt` kommen aus der Datei und werden *nach* den
    ///   Schreibpfaden gesetzt — deren Bumps (J2a) gelten für lokale Bearbeitung, nicht für
    ///   einen Import, der eine fremde Fassung 1:1 übernimmt.
    func importJournalEntries(
        _ exportEntries: [ExportJournalEntry],
        into cruise: Cruise,
        ports: [String: Port],
        photos: [String: Photo],
        modelContext: ModelContext
    ) {
        // ID-Dubletten innerhalb derselben Reise: nur das erste Vorkommen übernimmt die
        // Datei-ID, jedes weitere behält seine frische UUID (Muster der Häfen/Ausgaben).
        var seenEntryIDs: Set<UUID> = []

        for exportEntry in exportEntries {
            // Ohne lesbaren Tag hätte der Eintrag keinen Platz im Tages-Journal und landete
            // still auf „heute" — dann lieber verwerfen. Eigene Dateien sind davon nie
            // betroffen, der Exporter schreibt immer ISO-8601.
            guard let entryDate = isoFormatter.date(from: exportEntry.entryDate) else { continue }

            let entry = JournalEntry(text: exportEntry.text, moodRaw: exportEntry.moodRaw)
            if let entryUUID = UUID(uuidString: exportEntry.id), !seenEntryIDs.contains(entryUUID) {
                entry.id = entryUUID
                seenEntryIDs.insert(entryUUID)
            }
            entry.cruise = cruise
            modelContext.insert(entry)

            // Bezüge erst nach dem Insert setzen — Hafen und Fotos sind bereits registriert.
            entry.setEntryDate(normalizingImported: entryDate)

            if let portID = exportEntry.portId, let port = ports[portID] {
                entry.setPort(port)
            }

            for photoID in exportEntry.photoIds {
                guard let photo = photos[photoID] else { continue }
                entry.attach(photo)
            }

            // Datei-Zeitstempel zuletzt — sie überschreiben die Bumps der Schreibpfade oben.
            let createdAt = isoFormatter.date(from: exportEntry.createdAt)
            let updatedAt = isoFormatter.date(from: exportEntry.updatedAt)
            entry.createdAt = createdAt ?? entry.createdAt
            entry.updatedAt = updatedAt ?? entry.createdAt
        }
    }
}
