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
/// explizit aus.
///
/// **Verbindlicher Einstieg:** Journal-Objekte (`JournalEntry`, `Photo` mit
/// Journal-Bezug, `Port` mit Einträgen) werden ausschliesslich über diese
/// Methoden gelöscht. Ein direktes `context.delete(...)` auf eines dieser
/// Objekte ist ein Vertragsbruch — es nullt die Beziehung still und lässt die
/// Gegenseite mit altem `updatedAt` zurück, womit der Löschvorgang beim
/// CloudKit-Merge verlorengeht. Die Bindung der produktiven UI-Einstiege an
/// diese Helfer ist Auflage von T8.
enum JournalDeletePaths {

    /// Eintrag löschen: Fotos bleiben in der Reise-Galerie, `journalEntry` wird
    /// genullt — jedes betroffene Foto bumpt.
    static func deleteEntry(
        _ entry: JournalEntry,
        in context: ModelContext,
        at now: Date = Date()
    ) {
        entry.detachAllPhotosForDeletion(at: now)
        context.delete(entry)
    }

    /// Foto aus der Galerie löschen: hing es an einem Eintrag, bumpt der Eintrag.
    static func deletePhoto(
        _ photo: Photo,
        in context: ModelContext,
        at now: Date = Date()
    ) {
        if let entry = photo.journalEntry {
            entry.detach(photo, at: now)
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
            entry.setPort(nil, at: now)
        }
        port.journalEntriesStorage = []
        context.delete(port)
    }
}
