//
//  JournalDeletePaths.swift
//  ShipTrip
//
//  Lösch-Pfade des Journal-Kerns (ADR-003 LWW-Vertrag, Contract J2a).
//

import SwiftData
import Foundation

/// SwiftData-Nullify bumpt **nichts** automatisch. Damit Last-Writer-Wins auch
/// beim Löschen trägt, führen diese Pfade die von J2a geforderten Bumps
/// explizit aus — jede Lösch-Aktion des Journals läuft über sie.
enum JournalDeletePaths {

    /// Eintrag löschen: Fotos bleiben in der Reise-Galerie, `journalEntry` wird
    /// genullt — jedes betroffene Foto bumpt.
    static func deleteEntry(
        _ entry: JournalEntry,
        in context: ModelContext,
        at now: Date = Date()
    ) {
        // Erst schnappschussen, dann lösen — die Beziehung ändert sich beim Nullen.
        let attachedPhotos = Array(entry.photos)
        for photo in attachedPhotos {
            photo.journalEntry = nil
            photo.touch(at: now)
        }
        entry.photosStorage = []
        context.delete(entry)
    }

    /// Foto aus der Galerie löschen: hing es an einem Eintrag, bumpt der Eintrag.
    static func deletePhoto(
        _ photo: Photo,
        in context: ModelContext,
        at now: Date = Date()
    ) {
        if let entry = photo.journalEntry {
            photo.journalEntry = nil
            entry.touch(at: now)
        }
        context.delete(photo)
    }

    /// Hafen löschen: Einträge bleiben erhalten, `port` wird genullt — jeder
    /// betroffene Eintrag bumpt.
    static func deletePort(
        _ port: Port,
        in context: ModelContext,
        at now: Date = Date()
    ) {
        let affectedEntries = Array(port.journalEntriesStorage ?? [])
        for entry in affectedEntries {
            entry.port = nil
            entry.touch(at: now)
        }
        port.journalEntriesStorage = []
        context.delete(port)
    }
}
