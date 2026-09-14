//
//  CruiseDateTriad.swift
//  ShipTrip
//

import Foundation

/// Startdatum, Enddatum und Nächte einer Reise als ein gekoppelter Wert.
///
/// Reiner Wert ohne SwiftData-Bezug, der Kalender kommt von außen — damit ist
/// jede Kopplungsregel des Reiseformulars ohne View testbar.
///
/// **Invariante:** `nights == max(0, Kalendertage(start, end))`. Gerechnet wird
/// immer auf Tagesgrenzen (`startOfDay`), nie auf Sekunden. Verschoben wird über
/// Kalender-Tagesarithmetik, damit die Uhrzeit des Ursprungsdatums auch über
/// einen Sommerzeitwechsel hinweg erhalten bleibt.
///
/// Die drei Werte sind bewusst unveränderlich: jede Änderung läuft über eine
/// der `changing…`-Methoden und liefert eine neue, wieder gültige Triade.
struct CruiseDateTriad: Equatable, Sendable {

    // MARK: - Properties

    /// Startdatum der Reise
    let start: Date

    /// Enddatum der Reise
    let end: Date

    /// Reisedauer in Nächten (≥ 0)
    let nights: Int

    // MARK: - Initialization

    /// Baut die Triade aus den persistierten Werten einer Reise.
    ///
    /// Backfill: Beide Zweige der Regel — „gespeicherte 0 bei echtem Zeitraum
    /// nachrechnen" und „sonst die Invariante erzwingen" — laufen auf dieselbe
    /// Rechnung hinaus. `nights` stammt immer aus Start und Ende; ein nicht
    /// passender gespeicherter Wert wird überschrieben. `storedNights` bleibt
    /// Teil der Signatur, damit der Backfill genau eine Aufrufstelle hat und
    /// das Formular den persistierten Wert nicht selbst prüfen muss.
    init(start: Date, end: Date, storedNights: Int, calendar: Calendar) {
        self.start = start
        self.end = end
        self.nights = Self.nightsBetween(start, end, calendar: calendar)
    }

    private init(start: Date, end: Date, nights: Int) {
        self.start = start
        self.end = end
        self.nights = nights
    }

    // MARK: - Entscheidungen der Dialoge

    /// Antwort auf Dialog A beim Verschieben des Startdatums.
    enum StartShiftChoice: Sendable {
        /// Nächte bleiben, das Enddatum wandert mit.
        case keepNights
        /// Enddatum bleibt, die Nächte werden neu gerechnet.
        case keepEnd
    }

    /// Antwort auf den Dialog beim Ändern der Nächtezahl.
    enum NightsChoice: Sendable {
        case moveStart
        case moveEnd
    }

    // MARK: - Kopplungsregeln

    /// Neues Startdatum.
    ///
    /// - `.keepNights`: das Enddatum wandert um dieselbe Tagesspanne mit.
    /// - `.keepEnd`: das Enddatum bleibt, die Nächte werden neu gerechnet.
    ///   Liegt der neue Start hinter dem Ende, rutscht das Ende auf den Start
    ///   (0 Nächte) — ein negativer Zeitraum entsteht nie.
    func changingStart(to newStart: Date, choice: StartShiftChoice, calendar: Calendar) -> Self {
        switch choice {
        case .keepNights:
            let shift = Self.dayShift(from: start, to: newStart, calendar: calendar)
            return Self(
                start: newStart,
                end: Self.shifted(end, byDays: shift, calendar: calendar),
                nights: nights
            )
        case .keepEnd:
            let days = Self.dayShift(from: newStart, to: end, calendar: calendar)
            guard days >= 0 else { return Self(start: newStart, end: newStart, nights: 0) }
            return Self(start: newStart, end: end, nights: days)
        }
    }

    /// Neues Enddatum — die Nächte folgen ohne Rückfrage.
    func changingEnd(to newEnd: Date, calendar: Calendar) -> Self {
        Self(
            start: start,
            end: newEnd,
            nights: Self.nightsBetween(start, newEnd, calendar: calendar)
        )
    }

    /// Neue Nächtezahl; negative Eingaben werden auf 0 geklemmt.
    ///
    /// - `.moveStart`: das Startdatum wandert, das Enddatum bleibt.
    /// - `.moveEnd`: das Enddatum wandert, das Startdatum bleibt.
    func changingNights(to newNights: Int, choice: NightsChoice, calendar: Calendar) -> Self {
        let target = max(0, newNights)
        let current = Self.dayShift(from: start, to: end, calendar: calendar)
        switch choice {
        case .moveStart:
            let newStart = Self.shifted(start, byDays: current - target, calendar: calendar)
            return Self(start: newStart, end: end, nights: target)
        case .moveEnd:
            let newEnd = Self.shifted(end, byDays: target - current, calendar: calendar)
            return Self(start: start, end: newEnd, nights: target)
        }
    }

    // MARK: - Rechenhilfen

    /// Kalendertage zwischen zwei Daten, vorzeichenbehaftet — das N der Dialoge.
    static func dayShift(from: Date, to: Date, calendar: Calendar) -> Int {
        let fromDay = calendar.startOfDay(for: from)
        let toDay = calendar.startOfDay(for: to)
        return calendar.dateComponents([.day], from: fromDay, to: toDay).day ?? 0
    }

    /// Dialog B („Hafen- und Seetagsdaten mitverschieben?") lohnt nur, wenn es
    /// tatsächlich etwas zu verschieben gibt.
    static func needsRouteShiftPrompt(routeIsEmpty: Bool, dayShift: Int) -> Bool {
        !routeIsEmpty && dayShift != 0
    }

    /// Verschiebt ein Datum um ganze Kalendertage und erhält dabei die Uhrzeit —
    /// für `Port.arrival` und `Port.departure` von Häfen und Seetagen.
    static func shifted(_ date: Date, byDays days: Int, calendar: Calendar) -> Date {
        calendar.date(byAdding: .day, value: days, to: date) ?? date
    }

    private static func nightsBetween(_ start: Date, _ end: Date, calendar: Calendar) -> Int {
        max(0, dayShift(from: start, to: end, calendar: calendar))
    }
}
