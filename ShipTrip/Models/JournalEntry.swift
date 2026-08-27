//
//  JournalEntry.swift
//  ShipTrip
//
//  Journal-Kern (ADR-003, Contract J1/J2a).
//

import SwiftData
import Foundation

/// Tages-Erinnerung einer Kreuzfahrt („Erinnerung als Einstieg").
///
/// Mehrere Einträge pro Tag sind erlaubt. Kein `isDemo` — die Demo-Filterung
/// läuft wie bei Port/Expense/Photo über `cruise?.isDemo`.
@Model
final class JournalEntry {
    // MARK: - Properties

    /// Stabile App-seitige ID (kein Unique-Constraint; CloudKit-kompatibel)
    var id: UUID = UUID()

    /// Die Erinnerung (Freitext, mehrzeilig)
    var text: String = ""

    /// Kalendertag als Date-only-Wert: kanonisch 12:00 UTC des Tag-Tripels
    /// (Zeitzonen-Vertrag, siehe `JournalDay`). Der Default ist reiner
    /// Schema-Default (CloudKit-Pflicht) — persistiert wird nur normalisiert.
    var entryDate: Date = Date()

    /// Stimmung als stabiler Roh-String (J4); `""` = keine Stimmung.
    /// Unbekannte Rohwerte bleiben verbatim erhalten (Unknown-Preservation).
    var moodRaw: String = ""

    /// Erstellungsdatum — einmal beim Insert gesetzt, danach unveränderlich (J2a)
    var createdAt: Date = Date()

    /// Letztes Änderungsdatum (Last-Writer-Wins bei CloudKit-Sync, ADR-002 §2)
    var updatedAt: Date = Date()

    // MARK: - Relationships

    /// Zugehörige Kreuzfahrt (inverse Seite von `Cruise.journalEntriesStorage`)
    var cruise: Cruise?

    /// Optionaler Hafen-Bezug (inverse Seite von `Port.journalEntriesStorage`).
    /// Nur lesbar von aussen — Schreibpfad ist `setPort(_:at:)` (J2a).
    private(set) var port: Port?

    /// Angehängte Fotos; die Fotos bleiben zugleich Kinder der Reise.
    /// Nur lesbar von aussen — Schreibpfade sind `attach`/`detach` und
    /// `detachAllPhotosForDeletion` (J2a).
    @Relationship(deleteRule: .nullify, inverse: \Photo.journalEntry)
    private(set) var photosStorage: [Photo]?

    /// Nicht-optionale App-Sicht auf die CloudKit-kompatible optionale Beziehung.
    /// Bewusst **ohne** Setter: ein direkter Setter wäre ein Schreibpfad an den
    /// LWW-Bumps vorbei.
    var photos: [Photo] {
        photosStorage ?? []
    }

    // MARK: - Initialization

    /// - Parameter localDay: Der gewählte Kalendertag als **lokaler**
    ///   Zeitstempel; wird nach dem Zeitzonen-Vertrag auf 12:00 UTC seines
    ///   Tag-Tripels normalisiert.
    init(
        text: String = "",
        localDay: Date = Date(),
        moodRaw: String = "",
        calendar: Calendar = .current,
        now: Date = Date()
    ) {
        self.text = text
        self.entryDate = JournalDay.normalizedEntryDate(forLocalDay: localDay, calendar: calendar)
        self.moodRaw = moodRaw
        self.createdAt = now
        self.updatedAt = now
    }

    // MARK: - Mutationen (Bumps nach Matrix J2a)

    /// Bumpt `updatedAt` (LWW). `createdAt` bleibt unangetastet.
    func touch(at now: Date = Date()) {
        updatedAt = now
    }

    func setText(_ newText: String, at now: Date = Date()) {
        text = newText
        touch(at: now)
    }

    /// Editor-Schreibpfad: lokal gewählter Tag → 12:00 UTC des Tag-Tripels.
    func setEntryDate(localDay: Date, calendar: Calendar = .current, at now: Date = Date()) {
        entryDate = JournalDay.normalizedEntryDate(forLocalDay: localDay, calendar: calendar)
        touch(at: now)
    }

    /// Import-Schreibpfad (T7b): fremder Zeitstempel → 12:00 UTC seines
    /// UTC-Tag-Tripels.
    func setEntryDate(normalizingImported date: Date, at now: Date = Date()) {
        entryDate = JournalDay.normalizedEntryDate(forImported: date)
        touch(at: now)
    }

    /// Setzt den Roh-String der Stimmung (`""` = keine Stimmung).
    func setMoodRaw(_ newMoodRaw: String, at now: Date = Date()) {
        moodRaw = newMoodRaw
        touch(at: now)
    }

    /// Hafen setzen, wechseln oder entfernen.
    func setPort(_ newPort: Port?, at now: Date = Date()) {
        port = newPort
        touch(at: now)
    }

    /// Foto anhängen (neu oder bestehend) — Eintrag **und** Foto bumpen.
    ///
    /// Re-Attach: hing das Foto an einem **anderen** Eintrag, bumpt auch dieser.
    /// Sonst behielte der bisherige Eintrag trotz geänderter Foto-Liste sein
    /// altes `updatedAt` und verlöre den Wechsel beim LWW-Merge (J2a).
    func attach(_ photo: Photo, at now: Date = Date()) {
        let previousEntry = photo.journalEntry
        photo.setJournalEntry(self, at: now)
        previousEntry?.touch(at: now)
        touch(at: now)
    }

    /// Foto abhängen; das Foto bleibt Kind der Reise.
    func detach(_ photo: Photo, at now: Date = Date()) {
        guard photo.journalEntry === self else { return }
        photo.setJournalEntry(nil, at: now)
        touch(at: now)
    }

    /// Lösch-Pfad (`JournalDeletePaths.deleteEntry`): hängt alle Fotos ab und
    /// bumpt jedes. Der Eintrag selbst bumpt **nicht** — er wird unmittelbar
    /// danach gelöscht.
    func detachAllPhotosForDeletion(at now: Date = Date()) {
        // Erst schnappschussen, dann lösen — die Beziehung ändert sich beim Nullen.
        for photo in Array(photos) {
            photo.setJournalEntry(nil, at: now)
        }
        photosStorage = []
    }
}
