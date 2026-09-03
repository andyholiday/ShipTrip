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

    // MARK: - Datum und Uhrzeit

    /// Uhrzeit im Locale-Kurzformat (z. B. „08:00" bzw. „8:00 AM").
    static func time(_ date: Date) -> String {
        date.formatted(Date.FormatStyle(time: .shortened))
    }

    /// Tag ohne Jahr (z. B. „14. Mai" bzw. „May 14").
    static func day(_ date: Date) -> String {
        date.formatted(.dateTime.day().month(.abbreviated))
    }

    /// Zeitraum zweier Tage. Teilt sich den Katalog-Key mit `timeRange`.
    static func dateRange(from start: Date, to end: Date) -> String {
        String(localized: "\(day(start)) – \(day(end))")
    }

    // MARK: - Stopps

    static var seaDay: String { String(localized: "Seetag") }
    static var embarkation: String { String(localized: "Einschiffung") }

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
        return String(localized: "Ankunft \(time(arrival)) · Abfahrt \(time(departure))")
    }

    /// „08:00 – 17:00"; bei einem zeitlosen Eintrag der Tag.
    static func stopDetailCompact(_ stop: WidgetStopInfo) -> String {
        guard let arrival = stop.arrival, let departure = stop.departure else {
            return day(stop.day)
        }
        return String(localized: "\(time(arrival)) – \(time(departure))")
    }

    static var currentLabel: String { String(localized: "Aktuell") }
    static var nextStopLabel: String { String(localized: "Nächster Stopp") }

    static func nextStopLine(_ stop: WidgetStopInfo) -> String {
        String(localized: "Nächster Stopp: \(stopName(stop)), \(day(stop.day))")
    }

    /// Ohne Datum — fuer enge Layouts und grosse Schriftgrade.
    static func nextStopLineShort(_ stop: WidgetStopInfo) -> String {
        String(localized: "Nächster Stopp: \(stopName(stop))")
    }

    static func cruiseEndLine(_ date: Date) -> String {
        String(localized: "Reiseende \(day(date))")
    }

    // MARK: - Countdown

    /// Wortlaut aus `cruiseStartDescription` (Date+Extensions.swift:58),
    /// Schwellen unveraendert uebernommen.
    static func countdown(daysUntilStart days: Int) -> String {
        switch days {
        case ..<0:
            return String(localized: "Bereits vorbei")
        case 0:
            return String(localized: "Heute!")
        case 1:
            return String(localized: "Morgen")
        case 2...7:
            return String(localized: "In \(days) Tagen")
        case 8...14:
            return days >= 14
                ? String(localized: "In \(days / 7) Wochen")
                : String(localized: "In \(days / 7) Woche")
        case 15...30:
            return String(localized: "In ca. \(days / 7) Wochen")
        default:
            return days >= 60
                ? String(localized: "In \(days / 30) Monaten")
                : String(localized: "In \(days / 30) Monat")
        }
    }

    // MARK: - Leerlauf

    static var noPlannedCruise: String { String(localized: "Keine neue Reise geplant") }
    static var noCruiseAtAll: String {
        String(localized: "Noch keine Reise — leg deine erste an")
    }

    /// „Letzte Reise vor 3 Monaten" — gleiche Schwellen wie der Countdown.
    static func lastCruise(daysSince days: Int) -> String {
        switch days {
        case ..<1:
            return String(localized: "Letzte Reise heute beendet")
        case 1:
            return String(localized: "Letzte Reise gestern beendet")
        case 2...7:
            return String(localized: "Letzte Reise vor \(days) Tagen")
        case 8...14:
            return days >= 14
                ? String(localized: "Letzte Reise vor \(days / 7) Wochen")
                : String(localized: "Letzte Reise vor \(days / 7) Woche")
        case 15...30:
            return String(localized: "Letzte Reise vor ca. \(days / 7) Wochen")
        default:
            return days >= 60
                ? String(localized: "Letzte Reise vor \(days / 30) Monaten")
                : String(localized: "Letzte Reise vor \(days / 30) Monat")
        }
    }

    // MARK: - Sonstiges

    static var unavailable: String { String(localized: "Öffne ShipTrip zum Aktualisieren") }
    static var displayName: String { String(localized: "Reisestatus") }
    static var widgetDescription: String {
        String(localized: "Aktueller Hafen, nächster Stopp oder Countdown zur nächsten Reise.")
    }

    /// Beispiel-Reisetitel fuer Platzhalter und Galerie-Vorschau.
    static var sampleTitle: String { String(localized: "Mittelmeer-Kreuzfahrt") }

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
