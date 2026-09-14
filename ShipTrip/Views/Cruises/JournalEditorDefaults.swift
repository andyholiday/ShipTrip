//
//  JournalEditorDefaults.swift
//  ShipTrip
//
//  Default-Regeln von Schritt 2 „Eckdaten" und das Save-Gate von Schritt 1
//  (ADR-003, Contract J2/J3neu).
//

import Foundation

/// Die Vorbelegungen aus J2 Schritt 2 als reine, testbare Logik.
///
/// Alle Tag-Vergleiche laufen ueber `RouteDayKey` (Tag-Tripel, Zeitzonen-Vertrag
/// ADR-003) — nie `Date ==`, nie rohe Zeitstempel-Differenzen. Die hier
/// gelieferten Daten sind **lokale** Tageswerte; die Normalisierung auf 12:00 UTC
/// macht der Save-Pfad im Modell (`JournalEntry.setEntryDate(localDay:)`).
enum JournalEditorDefaults {

    // MARK: - Tag

    /// Datums-Default: der vorbelegte Stopp-Tag, sonst heute — beides geklemmt
    /// auf den Reisezeitraum (J2 Schritt 2, J3neu (d)).
    static func localDay(
        prefill: Date?,
        today: Date = Date(),
        cruiseStart: Date,
        cruiseEnd: Date,
        calendar: Calendar = .current
    ) -> Date {
        clamped(
            prefill ?? today,
            cruiseStart: cruiseStart,
            cruiseEnd: cruiseEnd,
            calendar: calendar
        )
    }

    /// Klemmt einen lokalen Tageswert auf `[startDate, endDate]`: vor der Reise →
    /// Starttag, danach → Endtag. Verglichen wird auf Tag-Tripeln, damit ein
    /// spaeter Abend am Starttag nicht faelschlich „vor der Reise" ist.
    ///
    /// Bei widerspruechlichen Reisedaten (`endDate` vor `startDate`) gewinnt der
    /// Starttag — ein leerer Bereich waere sonst nicht darstellbar.
    static func clamped(
        _ date: Date,
        cruiseStart: Date,
        cruiseEnd: Date,
        calendar: Calendar = .current
    ) -> Date {
        let startKey = RouteDayKey.localDay(cruiseStart, calendar: calendar)
        let endKey = RouteDayKey.localDay(cruiseEnd, calendar: calendar)
        guard startKey <= endKey else { return cruiseStart }

        let key = RouteDayKey.localDay(date, calendar: calendar)
        if key < startKey { return cruiseStart }
        if key > endKey { return cruiseEnd }
        return date
    }

    /// Rueckweg fuer den Datums-Picker beim Bearbeiten: das gespeicherte
    /// Tag-Tripel (UTC) als **lokaler** Mittags-Zeitstempel desselben Tages.
    ///
    /// Ohne diese Umrechnung zeigte der Picker bei Geraete-Offsets ab ±12 h den
    /// Nachbartag — und ein blosses Durchwinken schoebe den Eintrag beim Speichern
    /// um einen Tag (Zeitzonen-Vertrag ADR-003).
    static func localDay(ofEntryDate entryDate: Date, calendar: Calendar = .current) -> Date {
        let key = RouteDayKey.entryDay(entryDate)
        var components = DateComponents()
        components.year = key.year
        components.month = key.month
        components.day = key.day
        components.hour = 12
        return JournalDay.gregorianCalendar(zonedLike: calendar).date(from: components) ?? entryDate
    }

    /// Auswahlbereich des Datums-Pickers: vom Beginn des Starttags bis zum Ende
    /// des Endtags, damit beide Randtage waehlbar bleiben.
    static func dayRange(
        cruiseStart: Date,
        cruiseEnd: Date,
        calendar: Calendar = .current
    ) -> ClosedRange<Date> {
        let zoned = JournalDay.gregorianCalendar(zonedLike: calendar)
        let lower = zoned.startOfDay(for: cruiseStart)
        let lastDay = zoned.startOfDay(for: cruiseEnd)
        let upper = zoned.date(byAdding: DateComponents(day: 1, second: -1), to: lastDay) ?? lastDay
        // Widerspruechliche Reisedaten wuerden `lower...upper` zum Absturz bringen.
        guard lower <= upper else { return lower...lower }
        return lower...upper
    }

    // MARK: - Save-Gate (Schritt 1)

    /// Pflichtregel J2 Schritt 1 als reine Logik: speicherbar, sobald Text da ist
    /// **oder** mindestens ein Foto am Eintrag haengt.
    ///
    /// Solange noch ein Picker-Transfer laeuft, bleibt Speichern gesperrt: der
    /// Save-Pfad wartet nicht auf den Transfer, ein Speichern waehrenddessen
    /// verwuerfe die gerade geladenen Fotos still mit dem View-State.
    ///
    /// - Parameter photoLoadsInFlight: Anzahl der noch laufenden Foto-Transfers
    ///   des Pickers.
    static func canSave(
        hasText: Bool,
        pendingPhotoCount: Int,
        attachedPhotoCount: Int,
        photoLoadsInFlight: Int
    ) -> Bool {
        guard photoLoadsInFlight == 0 else { return false }
        return hasText || pendingPhotoCount > 0 || attachedPhotoCount > 0
    }

    // MARK: - Hafen

    /// Hafen-Default: **erster** Stopp des gewaehlten Tages (niedrigster
    /// `sortOrder`), sonst „Kein Hafen" (J2 Schritt 2; deckungsgleich mit der
    /// Traeger-Regel J3neu (a) Regel 2, damit der neue Eintrag dort landet, wo
    /// der User ihn erfasst hat).
    ///
    /// - Parameter localDay: der im Editor gewaehlte Tag als lokaler Wert.
    static func portID(
        forLocalDay localDay: Date,
        stops: [RouteStopInput],
        calendar: Calendar = .current
    ) -> UUID? {
        let dayKey = RouteDayKey.localDay(localDay, calendar: calendar)
        return stops
            .filter { RouteDayKey.localDay($0.arrival, calendar: calendar) == dayKey }
            .min(by: isOrderedBefore)?
            .id
    }

    /// Reihenfolge der Route: `sortOrder` regiert; `arrival`/`id` nur als
    /// deterministischer Tiebreak (wie in `RouteJournalPlanner`).
    private static func isOrderedBefore(_ lhs: RouteStopInput, _ rhs: RouteStopInput) -> Bool {
        if lhs.sortOrder != rhs.sortOrder { return lhs.sortOrder < rhs.sortOrder }
        if lhs.arrival != rhs.arrival { return lhs.arrival < rhs.arrival }
        return lhs.id.uuidString < rhs.id.uuidString
    }
}
