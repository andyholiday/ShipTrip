//
//  WidgetTimelinePlanner.swift
//  ShipTrip
//
//  Zeitpunkte der Widget-Timeline (Taskplan 1.9.0, Leitentscheidung 5;
//  ZIEL K4). Rein rechnend: Zustand + Zeitpunkt + Kalender -> Eintragszeiten.
//  WidgetKit-Begriffe (`Timeline`, `TimelineEntry`) bleiben im Widget-Target.
//

import Foundation

enum WidgetTimelinePlanner {

    /// Mehr Eintraege nimmt WidgetKit nicht sinnvoll ab.
    static let maxEntries = 12

    /// So weit reicht die Timeline mindestens, damit das Widget auch ohne
    /// Reload aktuell bleibt.
    static let minimumHorizon: TimeInterval = 24 * 60 * 60

    /// Zeitpunkte, zu denen sich die Anzeige aendern kann — aufsteigend,
    /// ohne Dubletten, `now` immer zuerst.
    ///
    /// Kandidaten sind die Ankunft und Abfahrt des aktuellen und des
    /// naechsten Stopps, die naechste lokale Mitternacht, der Reisestart und
    /// der Moment, in dem die laufende Reise endet — dazu die folgenden
    /// Tagesmitternachte, damit zwischen zwei Eintraegen hoechstens ein
    /// Kalendertag liegt.
    static func entryDates(for state: WidgetState, now: Date, calendar: Calendar) -> [Date] {
        // Leerlauf und leere Zustaende aendern sich nur mit dem Datumswechsel;
        // danach fragt WidgetKit ueber die `.after`-Policy ohnehin neu.
        switch state {
        case .idle, .unavailable:
            return [now, nextMidnight(after: now, calendar: calendar)]
        case .active, .countdown:
            break
        }

        // Die Tagesmitternachte gehen als Kandidaten mit ein, statt hinterher
        // angehaengt zu werden: sonst haelt ein einzelner ferner Kandidat
        // (Reiseende, Reisestart) die Auffuellung auf und die Timeline reisst
        // ueber Wochen.
        let midnights = dailyMidnights(after: now, count: maxEntries, calendar: calendar)
        let upcoming = (candidates(for: state, now: now, calendar: calendar) + midnights)
            .filter { $0 > now }
            .sorted()

        var dates = [now]
        for candidate in upcoming where dates.last != candidate {
            dates.append(candidate)
        }

        // Der Deckel greift erst nach dem Sortieren: die nahen Ankunfts- und
        // Abfahrtszeiten ueberleben ihn, nur ferne Mitternachte fallen weg.
        return Array(dates.prefix(maxEntries))
    }

    // MARK: - Kandidaten

    private static func candidates(
        for state: WidgetState,
        now: Date,
        calendar: Calendar
    ) -> [Date] {
        let midnight = nextMidnight(after: now, calendar: calendar)

        switch state {
        case .active(let info):
            var dates = [midnight, nextMidnight(after: info.cruiseEnd, calendar: calendar)]
            for stop in [info.currentStop, info.nextStop].compactMap({ $0 }) {
                if let arrival = stop.arrival { dates.append(arrival) }
                if let departure = stop.departure { dates.append(departure) }
            }
            return dates
        case .countdown(let info):
            return [midnight, info.startDate]
        case .idle, .unavailable:
            return [midnight]
        }
    }

    /// Die naechsten `count` lokalen Mitternachte nach `date`.
    private static func dailyMidnights(
        after date: Date,
        count: Int,
        calendar: Calendar
    ) -> [Date] {
        var result: [Date] = []
        var cursor = date
        for _ in 0..<count {
            cursor = nextMidnight(after: cursor, calendar: calendar)
            result.append(cursor)
        }
        return result
    }

    /// Naechste lokale Mitternacht **nach** `date` — auch wenn `date` selbst
    /// genau auf einer Mitternacht liegt. Ueber den Kalender gerechnet, damit
    /// 23- und 25-Stunden-Tage richtig herauskommen.
    private static func nextMidnight(after date: Date, calendar: Calendar) -> Date {
        let start = calendar.startOfDay(for: date)
        return calendar.date(byAdding: .day, value: 1, to: start)
            ?? start.addingTimeInterval(86_400)
    }
}
