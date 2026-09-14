//
//  Photo.swift
//  ShipTrip
//
//  Created by ShipTrip on 18.12.25.
//

import SwiftData
import Foundation

/// Foto einer Kreuzfahrt
@Model
final class Photo {
    /// Stabile App-seitige ID (kein Unique-Constraint; CloudKit-kompatibel)
    var id: UUID = UUID()

    /// Die Bilddaten
    @Attribute(.externalStorage)
    var imageData: Data = Data()

    /// Vorschaubild (wird von einem späteren Task befüllt)
    var thumbnailData: Data?

    /// Sortierreihenfolge
    var sortOrder: Int = 0

    /// Bildunterschrift (optional befüllbar, ADR-003/J1)
    var caption: String = ""

    /// Erstellungsdatum
    var createdAt: Date = Date()

    /// Letztes Änderungsdatum (für Last-Writer-Wins bei CloudKit-Sync)
    var updatedAt: Date = Date()

    /// Zugehörige Kreuzfahrt
    var cruise: Cruise?

    /// Optionaler Journal-Eintrag, an dem dieses Foto hängt (ADR-003/J1).
    /// Das Foto bleibt zusätzlich Kind der Reise — Galerie, Statistiken und
    /// Export verhalten sich unverändert.
    ///
    /// Nur lesbar von aussen: geschrieben wird ausschliesslich über
    /// `setJournalEntry(_:at:)`, damit kein Schreibpfad am LWW-Bump vorbeikommt
    /// (J2a). Einstiege sind `JournalEntry.attach/detach` und
    /// `JournalDeletePaths`.
    private(set) var journalEntry: JournalEntry?

    init(imageData: Data, sortOrder: Int = 0) {
        self.imageData = imageData
        self.sortOrder = sortOrder
        self.createdAt = Date()
    }

    /// Bumpt `updatedAt` (Last-Writer-Wins, Matrix J2a).
    func touch(at now: Date = Date()) {
        updatedAt = now
    }

    /// Caption ändern — bumpt nur das Foto (J2a).
    func setCaption(_ newCaption: String, at now: Date = Date()) {
        caption = newCaption
        touch(at: now)
    }

    /// Einziger Schreibpfad für den Journal-Bezug: setzt die Beziehung und bumpt
    /// das Foto. Die Bumps der betroffenen **Einträge** liegen beim Aufrufer
    /// (`JournalEntry.attach/detach`, `JournalDeletePaths`) — nur der kennt
    /// alten und neuen Eintrag.
    func setJournalEntry(_ newEntry: JournalEntry?, at now: Date = Date()) {
        journalEntry = newEntry
        touch(at: now)
    }
}
