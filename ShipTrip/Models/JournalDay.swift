//
//  JournalDay.swift
//  ShipTrip
//
//  Zeitzonen-Vertrag fuer `JournalEntry.entryDate` (ADR-003, Contract J1).
//

import Foundation

/// Kalendertag-Rechnen fuer Journal-Einträge.
///
/// `entryDate` ist ein **Date-only-Wert** ohne Uhrzeit-Semantik: kanonisch
/// kodiert als **12:00 UTC** des gewählten Kalendertags (Mittags-Anker: hält den
/// Tag defensiv bei Geräte-Offsets unter ±12 h; ab genau ±12 h liegt 12:00 UTC
/// auf der lokalen Tagesgrenze — deshalb wird der Tag **nie** lokal extrahiert,
/// sondern immer über `utcCalendar`). Auf Kreuzfahrten wechselt die Zeitzone,
/// deshalb gilt: **nie** lokales `startOfDay`, **nie** `Date ==`, und Vergleiche
/// laufen ausschliesslich über Tag-Tripel (Jahr/Monat/Tag) — die
/// `entryDate`-Seite über den UTC-Kalender, lokale Ereignis-Zeitstempel
/// (`cruise.startDate`, `port.arrival`) über den Geräte-Kalender.
///
/// Jeder Schreibpfad (Editor-Save, Import) normalisiert über diesen Typ.
enum JournalDay {

    /// Fester UTC-Kalender fuer alle `entryDate`-Extraktionen.
    static let utcCalendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .gmt
        return calendar
    }()

    // MARK: - Tag-Tripel

    /// Tag-Tripel eines lokalen Ereignis-Zeitstempels (Geräte-Kalender).
    static func localDayComponents(
        of date: Date,
        calendar: Calendar = .current
    ) -> DateComponents {
        calendar.dateComponents([.year, .month, .day], from: date)
    }

    /// Tag-Tripel eines gespeicherten `entryDate` (immer UTC-Kalender).
    static func dayComponents(ofEntryDate entryDate: Date) -> DateComponents {
        utcCalendar.dateComponents([.year, .month, .day], from: entryDate)
    }

    /// Kanonische Kodierung eines Tag-Tripels: 12:00 UTC.
    /// `nil` nur bei einem unvollständigen oder ungültigen Tripel.
    static func entryDate(fromDayComponents components: DateComponents) -> Date? {
        var normalized = DateComponents()
        normalized.year = components.year
        normalized.month = components.month
        normalized.day = components.day
        normalized.hour = 12
        normalized.minute = 0
        normalized.second = 0
        return utcCalendar.date(from: normalized)
    }

    // MARK: - Schreibpfad-Normalisierung

    /// Editor-Schreibpfad: der vom User im Geräte-Kalender gewählte Tag wird auf
    /// 12:00 UTC seines Tag-Tripels normalisiert.
    ///
    /// Fällt auf den Eingabewert zurück, wenn der Kalender kein Datum bilden kann
    /// (praktisch unerreichbar fuer gregorianische Tripel aus einem echten `Date`).
    static func normalizedEntryDate(
        forLocalDay date: Date,
        calendar: Calendar = .current
    ) -> Date {
        entryDate(fromDayComponents: localDayComponents(of: date, calendar: calendar)) ?? date
    }

    /// Import-Schreibpfad (ZIP/Teilen): ein fremder Zeitstempel wird auf 12:00 UTC
    /// **seines UTC-Tag-Tripels** normalisiert — Alt- und Fremddateien bringen so
    /// keine unnormalisierten Werte in den Store.
    static func normalizedEntryDate(forImported date: Date) -> Date {
        entryDate(fromDayComponents: dayComponents(ofEntryDate: date)) ?? date
    }

    // MARK: - Vergleiche (immer auf Tag-Tripeln)

    /// Liegt ein `entryDate` (UTC-Kalender) auf demselben Kalendertag wie ein
    /// lokaler Ereignis-Zeitstempel (Geräte-Kalender)?
    static func isSameDay(
        entryDate: Date,
        asLocalDay localDate: Date,
        calendar: Calendar = .current
    ) -> Bool {
        dayComponents(ofEntryDate: entryDate)
            == localDayComponents(of: localDate, calendar: calendar)
    }

    /// Liegen zwei `entryDate`-Werte auf demselben Kalendertag?
    static func isSameDay(entryDate lhs: Date, otherEntryDate rhs: Date) -> Bool {
        dayComponents(ofEntryDate: lhs) == dayComponents(ofEntryDate: rhs)
    }
}
