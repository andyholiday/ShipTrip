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

    /// So weit muss die Timeline mindestens reichen, damit das Widget auch
    /// ohne Reload aktuell bleibt.
    static let minimumHorizon: TimeInterval = 24 * 60 * 60

    /// Zeitpunkte, zu denen sich die Anzeige aendern kann — aufsteigend,
    /// ohne Dubletten, `now` immer zuerst.
    ///
    /// Kandidaten sind die Ankunft und Abfahrt des aktuellen und des
    /// naechsten Stopps, die naechste lokale Mitternacht, der Reisestart und
    /// der Moment, in dem die laufende Reise endet. Reicht das nicht ueber
    /// `minimumHorizon`, fuellen die folgenden Mitternachte auf.
    static func entryDates(for state: WidgetState, now: Date, calendar: Calendar) -> [Date] {
        // Leerlauf und leere Zustaende aendern sich nur mit dem Datumswechsel;
        // danach fragt WidgetKit ueber die `.after`-Policy ohnehin neu.
        switch state {
        case .idle, .unavailable:
            return [now, nextMidnight(after: now, calendar: calendar)]
        case .active, .countdown:
            break
        }

        let upcoming = candidates(for: state, now: now, calendar: calendar)
            .filter { $0 > now }
            .sorted()

        var dates = [now]
        for candidate in upcoming where dates.last != candidate {
            dates.append(candidate)
        }

        let horizon = now.addingTimeInterval(minimumHorizon)
        while let last = dates.last, last < horizon, dates.count < maxEntries {
            dates.append(nextMidnight(after: last, calendar: calendar))
        }

        // Der Deckel greift erst zuletzt: am Maximalbestand entstehen hoechstens
        // sechs Kandidaten, der Horizont bleibt also gedeckt.
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

    /// Naechste lokale Mitternacht **nach** `date` — auch wenn `date` selbst
    /// genau auf einer Mitternacht liegt. Ueber den Kalender gerechnet, damit
    /// 23- und 25-Stunden-Tage richtig herauskommen.
    private static func nextMidnight(after date: Date, calendar: Calendar) -> Date {
        let start = calendar.startOfDay(for: date)
        return calendar.date(byAdding: .day, value: 1, to: start)
            ?? start.addingTimeInterval(86_400)
    }
}
