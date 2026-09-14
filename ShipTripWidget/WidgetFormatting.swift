//
//  WidgetFormatting.swift
//  ShipTripWidget
//
//  Einzige Stelle, an der aus den rohen Werten des `WidgetState` sichtbarer
//  Text wird (Taskplan 1.9.0, T4). Alle Wortlaute liegen hier — die Views
//  bekommen fertige Strings und formatieren nichts selbst.
//
//  Der Countdown-Wortlaut bildet die Tabelle aus
//  `ShipTrip/Utilities/Date+Extensions.swift` (`cruiseStartDescription`) nach.
//  Das ist die in Leitentscheidung 4 bewusst in Kauf genommene Duplikation:
//  `WidgetShared` darf keine lokalisierten Strings enthalten.
//

import Foundation

enum WidgetFormatting {

    // MARK: - Katalog-Bundle

    /// Bundle, aus dem die Wortlaute kommen.
    ///
    /// Im Widget-Prozess ist `Bundle.main` bereits das `.appex` und traegt den
    /// Katalog. Derselbe Code laeuft aber auch im App-Prozess (Debug-Galerie
    /// fuer die Widget-Screenshots, Taskplan 1.9.0 LE 10) — dort liegt der
    /// Katalog im eingebetteten `ShipTripWidget.appex`, nicht im App-Bundle.
    /// Ohne diesen Umweg zeigten die Screenshots die deutschen Rohkeys statt
    /// der Uebersetzung. Faellt der Umweg aus, bleibt `.main` als Notnagel.
    static let bundle: Bundle = {
        if Bundle.main.bundleURL.pathExtension == "appex" { return .main }
        guard let plugIns = Bundle.main.builtInPlugInsURL,
              let widget = Bundle(url: plugIns.appending(component: "ShipTripWidget.appex"))
        else { return .main }
        return widget
    }()

    // MARK: - Datum und Uhrzeit

    /// Uhrzeit im Locale-Kurzformat (z. B. „08:00" bzw. „8:00 AM").
    static func time(_ date: Date) -> String {
        date.formatted(Date.FormatStyle(time: .shortened))
    }

    /// Tag ohne Jahr (z. B. „14. Mai" bzw. „May 14").
    static func day(_ date: Date) -> String {
        date.formatted(.dateTime.day().month(.abbreviated))
    }

    /// Tag mit Wochentag und Jahr (z. B. „Mo., 2. Juni 2025") — Kopfzeile des
    /// Mittelformats in der Richtung „Dynamic Instrument".
    static func dayWithWeekday(_ date: Date) -> String {
        date.formatted(.dateTime.weekday(.abbreviated).day().month(.wide).year())
    }

    /// Tag mit Jahr, ohne Wochentag (z. B. „17. Juni 2025").
    static func dayWithYear(_ date: Date) -> String {
        date.formatted(.dateTime.day().month(.wide).year())
    }

    /// Tag rein numerisch, mit zweistelligem Jahr (z. B. „13.09.26" bzw.
    /// „09/13/26") — Kopfzeile des Mittelformats bei grossem Schriftgrad. Die
    /// ausgeschriebene Form brach dort mit „13. September 20…" ab (ZIEL K2).
    static func dayNumeric(_ date: Date) -> String {
        date.formatted(.dateTime.day().month(.twoDigits).year(.twoDigits))
    }

    /// Zeitraum zweier Tage. Teilt sich den Katalog-Key mit `timeRange`.
    static func dateRange(from start: Date, to end: Date) -> String {
        String(localized: "\(day(start)) – \(day(end))", bundle: bundle)
    }

    // MARK: - Stopps

    static var seaDay: String { String(localized: "Seetag", bundle: bundle) }
    static var embarkation: String { String(localized: "Einschiffung", bundle: bundle) }

    /// Anzeigename eines Eintrags — Seetage tragen keinen Hafennamen.
    static func stopName(_ stop: WidgetStopInfo) -> String {
        stop.isSeaDay ? seaDay : stop.name
    }

    /// Gekuerzter Anzeigename fuer die schmalen Sperrbildschirm-Familien:
    /// alles ab dem ersten Trennzeichen faellt weg
    /// („Puerto de la Cruz — Islas Canarias" → „Puerto de la Cruz").
    static func shortStopName(_ stop: WidgetStopInfo) -> String {
        let full = stopName(stop)
        for separator in ["—", "–", " - ", ","] {
            guard let range = full.range(of: separator) else { continue }
            let head = full[..<range.lowerBound].trimmingCharacters(in: .whitespaces)
            if head.count >= 3 { return head }
        }
        return full
    }

    /// „Ankunft 08:00 · Abfahrt 17:00"; bei einem zeitlosen Eintrag der Tag.
    static func stopDetail(_ stop: WidgetStopInfo) -> String {
        guard let arrival = stop.arrival, let departure = stop.departure else {
            return day(stop.day)
        }
        return String(
            localized: "Ankunft \(time(arrival)) · Abfahrt \(time(departure))",
            bundle: bundle
        )
    }

    /// „08:00 – 17:00"; bei einem zeitlosen Eintrag der Tag.
    static func stopDetailCompact(_ stop: WidgetStopInfo) -> String {
        guard let arrival = stop.arrival, let departure = stop.departure else {
            return day(stop.day)
        }
        return String(localized: "\(time(arrival)) – \(time(departure))", bundle: bundle)
    }

    static var currentLabel: String { String(localized: "Aktuell", bundle: bundle) }
    static var nextStopLabel: String { String(localized: "Nächster Stopp", bundle: bundle) }

    /// Ueberschrift ueber dem aktuellen Hafen im Mittelformat.
    static var currentInLabel: String { String(localized: "Aktuell in", bundle: bundle) }

    /// Ueberschrift ueber der Countdown-Zahl im Mittelformat.
    static var nextCruiseInLabel: String {
        String(localized: "Nächste Kreuzfahrt in", bundle: bundle)
    }

    /// „Abfahrt: 17. Juni 2025".
    static func departureLine(_ date: Date) -> String {
        String(localized: "Abfahrt: \(dayWithYear(date))", bundle: bundle)
    }

    /// - Parameter compactName: kuerzt den Hafennamen ueber `shortStopName`.
    ///   Die Kacheln setzen das, VoiceOver bekommt weiter den vollen Wortlaut.
    static func nextStopLine(_ stop: WidgetStopInfo, compactName: Bool = false) -> String {
        let name = compactName ? shortStopName(stop) : stopName(stop)
        return String(localized: "Nächster Stopp: \(name), \(day(stop.day))", bundle: bundle)
    }

    /// Ohne Datum — fuer enge Layouts und grosse Schriftgrade.
    static func nextStopLineShort(_ stop: WidgetStopInfo, compactName: Bool = false) -> String {
        let name = compactName ? shortStopName(stop) : stopName(stop)
        return String(localized: "Nächster Stopp: \(name)", bundle: bundle)
    }

    static func cruiseEndLine(_ date: Date) -> String {
        String(localized: "Reiseende \(day(date))", bundle: bundle)
    }

    // MARK: - Countdown

    /// Wortlaut aus `cruiseStartDescription` (Date+Extensions.swift:58),
    /// Schwellen unveraendert uebernommen.
    static func countdown(daysUntilStart days: Int) -> String {
        switch days {
        case ..<0:
            return String(localized: "Bereits vorbei", bundle: bundle)
        case 0:
            return String(localized: "Heute!", bundle: bundle)
        case 1:
            return String(localized: "Morgen", bundle: bundle)
        case 2...7:
            return String(localized: "In \(days) Tagen", bundle: bundle)
        case 8...14:
            return days >= 14
                ? String(localized: "In \(days / 7) Wochen", bundle: bundle)
                : String(localized: "In \(days / 7) Woche", bundle: bundle)
        case 15...30:
            return String(localized: "In ca. \(days / 7) Wochen", bundle: bundle)
        default:
            return days >= 60
                ? String(localized: "In \(days / 30) Monaten", bundle: bundle)
                : String(localized: "In \(days / 30) Monat", bundle: bundle)
        }
    }

    /// „Noch" — Vorlauf ueber der grossen Countdown-Zahl im Kleinformat.
    static var stillLabel: String { String(localized: "Noch", bundle: bundle) }

    /// Zerlegt den Countdown in grosse Zahl und Einheit, damit die Kachel die
    /// Zahl als Instrument-Wert setzen kann (Konzept 03).
    ///
    /// `nil` bei allen Wortlauten ohne saubere Zahl-Einheit-Trennung —
    /// „Bereits vorbei", „Heute!", „Morgen" und die „ca."-Spanne. Dort setzt
    /// die Kachel den vollen Wortlaut aus `countdown(daysUntilStart:)`.
    ///
    /// Die Schwellen sind identisch mit `countdown(daysUntilStart:)`; der
    /// Wortlaut aendert sich durch diese Richtung nicht.
    ///
    /// - Parameter dative: deutscher Dativ nach „in" („in 12 **Tagen**")
    ///   statt Nominativ nach „Noch" („Noch 12 **Tage**").
    static func countdownParts(
        daysUntilStart days: Int,
        dative: Bool
    ) -> (value: String, unit: String)? {
        switch days {
        case ..<2:
            return nil
        case 2...7:
            return (days.formatted(.number.grouping(.never)), dative ? daysUnitDative : daysUnit)
        case 8...14:
            let weeks = days / 7
            return (
                weeks.formatted(.number.grouping(.never)),
                weeks >= 2 ? weeksUnit : weekUnit
            )
        case 15...30:
            return nil
        default:
            let months = days / 30
            if months >= 2 {
                return (
                    months.formatted(.number.grouping(.never)),
                    dative ? monthsUnitDative : monthsUnit
                )
            }
            return (months.formatted(.number.grouping(.never)), monthUnit)
        }
    }

    private static var daysUnit: String { String(localized: "Tage", bundle: bundle) }
    private static var daysUnitDative: String { String(localized: "Tagen", bundle: bundle) }
    private static var weekUnit: String { String(localized: "Woche", bundle: bundle) }
    private static var weeksUnit: String { String(localized: "Wochen", bundle: bundle) }
    private static var monthUnit: String { String(localized: "Monat", bundle: bundle) }
    private static var monthsUnit: String { String(localized: "Monate", bundle: bundle) }
    private static var monthsUnitDative: String { String(localized: "Monaten", bundle: bundle) }

    // MARK: - Leerlauf

    static var noPlannedCruise: String {
        String(localized: "Keine neue Reise geplant", bundle: bundle)
    }
    static var noCruiseAtAll: String {
        String(localized: "Noch keine Reise — leg deine erste an", bundle: bundle)
    }

    /// „Letzte Reise vor 3 Monaten" — gleiche Schwellen wie der Countdown.
    static func lastCruise(daysSince days: Int) -> String {
        switch days {
        case ..<1:
            return String(localized: "Letzte Reise heute beendet", bundle: bundle)
        case 1:
            return String(localized: "Letzte Reise gestern beendet", bundle: bundle)
        case 2...7:
            return String(localized: "Letzte Reise vor \(days) Tagen", bundle: bundle)
        case 8...14:
            return days >= 14
                ? String(localized: "Letzte Reise vor \(days / 7) Wochen", bundle: bundle)
                : String(localized: "Letzte Reise vor \(days / 7) Woche", bundle: bundle)
        case 15...30:
            return String(localized: "Letzte Reise vor ca. \(days / 7) Wochen", bundle: bundle)
        default:
            return days >= 60
                ? String(localized: "Letzte Reise vor \(days / 30) Monaten", bundle: bundle)
                : String(localized: "Letzte Reise vor \(days / 30) Monat", bundle: bundle)
        }
    }

    /// Ueberschrift ueber dem Abstand zur letzten Reise (Konzept 03 trennt
    /// Label und Wert: „Letzte Reise" / „vor 43 Tagen").
    static var lastCruiseLabel: String { String(localized: "Letzte Reise", bundle: bundle) }

    /// Nur der Wert zu `lastCruiseLabel` — „vor 43 Tagen", „heute beendet".
    /// Gleiche Schwellen wie `lastCruise(daysSince:)`, das fuer VoiceOver
    /// unveraendert den ganzen Satz liefert.
    static func sinceLastCruise(days: Int) -> String {
        switch days {
        case ..<1:
            return String(localized: "heute beendet", bundle: bundle)
        case 1:
            return String(localized: "gestern beendet", bundle: bundle)
        case 2...7:
            return String(localized: "vor \(days) Tagen", bundle: bundle)
        case 8...14:
            return days >= 14
                ? String(localized: "vor \(days / 7) Wochen", bundle: bundle)
                : String(localized: "vor \(days / 7) Woche", bundle: bundle)
        case 15...30:
            return String(localized: "vor ca. \(days / 7) Wochen", bundle: bundle)
        default:
            return days >= 60
                ? String(localized: "vor \(days / 30) Monaten", bundle: bundle)
                : String(localized: "vor \(days / 30) Monat", bundle: bundle)
        }
    }

    // MARK: - Beiwerk

    /// Kapitaelchen-Zeile im Mittelformat, aktiver Zustand.
    static var taglineActive: String {
        String(localized: "GUTE ORTE. BESSERE GESCHICHTEN.", bundle: bundle)
    }

    /// Kapitaelchen-Zeile im Mittelformat, Countdown.
    static var taglineCountdown: String {
        String(localized: "KREUZFAHRTEN VERBINDEN MENSCHEN.", bundle: bundle)
    }

    /// Handschriftliche Zeile ueber dem Bildkreis im Countdown.
    static var taglineScript: String {
        String(localized: "Neue Ziele. Gleicher Horizont.", bundle: bundle)
    }

    // MARK: - Sonstiges

    static var unavailable: String {
        String(localized: "Öffne ShipTrip zum Aktualisieren", bundle: bundle)
    }
    static var displayName: String { String(localized: "Reisestatus", bundle: bundle) }
    static var widgetDescription: String {
        String(
            localized: "Aktueller Hafen, nächster Stopp oder Countdown zur nächsten Reise.",
            bundle: bundle
        )
    }

    /// Beispiel-Reisetitel fuer Platzhalter und Galerie-Vorschau.
    static var sampleTitle: String { String(localized: "Mittelmeer-Kreuzfahrt", bundle: bundle) }

    /// Kurzwert der runden Familie; ueber 99 gekappt.
    static func shortCount(_ value: Int) -> String {
        value > 99 ? "99+" : value.formatted(.number.grouping(.never))
    }

    // MARK: - VoiceOver

    /// Ein Satz aus den bereits lokalisierten Bausteinen — noetig, weil die
    /// runde Familie nur Symbol und Kurzwert zeigt.
    static func accessibilityLabel(for state: WidgetState) -> String {
        switch state {
        case .active(let info):
            return activeLabel(info)
        case .countdown(let info):
            return [info.title, countdown(daysUntilStart: info.daysUntilStart)]
                .joined(separator: ", ")
        case .idle(let info):
            guard let days = info.daysSinceLastCruise else { return noCruiseAtAll }
            return [noPlannedCruise, lastCruise(daysSince: days)].joined(separator: ", ")
        case .unavailable:
            return unavailable
        }
    }

    private static func activeLabel(_ info: ActiveInfo) -> String {
        if let current = info.currentStop {
            var parts = [stopName(current), stopDetail(current)]
            if let next = info.nextStop {
                parts.append(nextStopLine(next))
            } else if info.isAfterLastStop {
                parts.append(cruiseEndLine(info.cruiseEnd))
            }
            return parts.joined(separator: ", ")
        }
        if let next = info.nextStop {
            return [embarkation, nextStopLine(next)].joined(separator: ", ")
        }
        return [info.title, info.ship, dateRange(from: info.cruiseStart, to: info.cruiseEnd)]
            .joined(separator: ", ")
    }
}
