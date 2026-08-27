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

    /// Optionaler Hafen-Bezug (inverse Seite von `Port.journalEntriesStorage`)
    var port: Port?

    /// Angehängte Fotos; die Fotos bleiben zugleich Kinder der Reise.
    @Relationship(deleteRule: .nullify, inverse: \Photo.journalEntry)
    var photosStorage: [Photo]?

    /// Nicht-optionale App-Sicht auf die CloudKit-kompatible optionale Beziehung.
    var photos: [Photo] {
        get { photosStorage ?? [] }
        set { photosStorage = newValue }
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
    func attach(_ photo: Photo, at now: Date = Date()) {
        photo.journalEntry = self
        photo.touch(at: now)
        touch(at: now)
    }

    /// Foto abhängen; das Foto bleibt Kind der Reise.
    func detach(_ photo: Photo, at now: Date = Date()) {
        guard photo.journalEntry === self else { return }
        photo.journalEntry = nil
        photo.touch(at: now)
        touch(at: now)
    }
}
