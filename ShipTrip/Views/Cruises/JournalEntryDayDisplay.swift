//
//  JournalEntryDayDisplay.swift
//  ShipTrip
//
//  Tag-Darstellung eines Journal-Eintrags (ADR-003 Zeitzonen-Vertrag, J1/J3neu (c)).
//

import Foundation

/// Reisetag-Nummer und Datums-Text eines `entryDate`.
///
/// Beides haengt am Zeitzonen-Vertrag (ADR-003): `entryDate` ist ein
/// Date-only-Wert (12:00 UTC des Tag-Tripels) und wird **ausschliesslich** ueber
/// den UTC-Kalender gelesen. Wuerde die Anzeige den Geraete-Kalender nehmen,
/// zeigte sie bei Offsets ab ±12 h den Nachbartag — genau der Fehler, den der
/// Vertrag ausschliesst.
///
/// Rein und ohne SwiftUI-Abhaengigkeit, damit die Semantik isoliert testbar ist
/// (Muster `RouteJournalPlanner`).
enum JournalEntryDayDisplay {

    /// Reisetag-Nummer („Tag 3") = Kalendertag-Differenz der Tag-Tripel + 1
    /// (J1, abgeleitet und **nicht** gespeichert).
    ///
    /// - Parameter calendar: Geraete-Kalender fuer die `cruise.startDate`-Seite.
    /// - Returns: `nil`, wenn der Eintrag **vor** dem Starttag liegt (dann gibt es
    ///   keinen sinnvollen Reisetag) oder die Tripel kein Datum bilden.
    static func tripDayNumber(
        entryDate: Date,
        cruiseStart: Date,
        calendar: Calendar = .current
    ) -> Int? {
        let entryKey = RouteDayKey.entryDay(entryDate)
        let startKey = RouteDayKey.localDay(cruiseStart, calendar: calendar)
        guard let entryAnchor = anchor(for: entryKey),
              let startAnchor = anchor(for: startKey),
              let dayDifference = JournalDay.utcCalendar
                .dateComponents([.day], from: startAnchor, to: entryAnchor).day
        else { return nil }

        let number = dayDifference + 1
        return number >= 1 ? number : nil
    }

    /// Lokalisierter Datums-Text eines `entryDate`.
    ///
    /// Die Zeitzone ist fest GMT — nur so trifft die Anzeige das gespeicherte
    /// Tag-Tripel. Kalendersystem und Sprache bleiben die des Geraets.
    static func dayText(
        for entryDate: Date,
        style: Date.FormatStyle.DateStyle = .abbreviated
    ) -> String {
        entryDate.formatted(Date.FormatStyle(date: style, time: .omitted, timeZone: .gmt))
    }

    /// Kanonischer Zeitpunkt eines Tag-Tripels (12:00 UTC) — Rechen-Anker der
    /// Reisetag-Differenz.
    private static func anchor(for key: RouteDayKey) -> Date? {
        var components = DateComponents()
        components.year = key.year
        components.month = key.month
        components.day = key.day
        return JournalDay.entryDate(fromDayComponents: components)
    }
}
