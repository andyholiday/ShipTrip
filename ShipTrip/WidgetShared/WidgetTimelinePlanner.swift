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
    /// Reload aktuell bleibt — und zugleich die groesste erlaubte Luecke
    /// zwischen zwei Eintraegen.
    static let minimumHorizon: TimeInterval = 24 * 60 * 60

    /// Zeitpunkte, zu denen sich die Anzeige aendern kann — aufsteigend,
    /// ohne Dubletten, `now` immer zuerst.
    ///
    /// Kandidaten sind die Ankunft und Abfahrt des aktuellen und des
    /// naechsten Stopps, die naechste lokale Mitternacht, der Reisestart und
    /// der Moment, in dem die laufende Reise endet — dazu die folgenden
    /// Tagesmitternachte, damit zwischen zwei Eintraegen hoechstens ein
    /// Kalendertag liegt.
    ///
    /// In jedem Zustand reicht die Liste mindestens `minimumHorizon` weit und
    /// laesst zwischen zwei Eintraegen hoechstens `minimumHorizon` — dafuer
    /// sorgt `filled(_:now:calendar:)`.
    static func entryDates(for state: WidgetState, now: Date, calendar: Calendar) -> [Date] {
        // Leerlauf und leere Zustaende aendern sich nur mit dem Datumswechsel;
        // danach fragt WidgetKit ueber die `.after`-Policy ohnehin neu. Die
        // naechste Mitternacht allein liegt aber oft weniger als 24 Stunden
        // voraus — deshalb auffuellen, statt dort aufzuhoeren.
        switch state {
        case .idle, .unavailable:
            return filled([now, nextMidnight(after: now, calendar: calendar)],
                          now: now,
                          calendar: calendar)
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
        return Array(filled(dates, now: now, calendar: calendar).prefix(maxEntries))
    }

    // MARK: - Horizont und Luecken

    /// Ergaenzt Zwischenschritte, bis die Liste `minimumHorizon` weit reicht
    /// und zwischen zwei Eintraegen hoechstens `minimumHorizon` liegt.
    ///
    /// Noetig wird das an zwei Stellen: bei Leerlauf und leeren Zustaenden,
    /// deren einziger Kandidat die naechste Mitternacht ist, und am
    /// 25-Stunden-Tag der Zeitumstellung, an dem zwei aufeinanderfolgende
    /// Mitternachte eine Luecke von 25 Stunden aufreissen.
    ///
    /// - Precondition: `dates` ist aufsteigend sortiert und dublettenfrei.
    private static func filled(_ dates: [Date], now: Date, calendar: Calendar) -> [Date] {
        var result: [Date] = []
        for date in dates {
            while let last = result.last, date.timeIntervalSince(last) > minimumHorizon {
                result.append(dayLater(than: last, calendar: calendar))
            }
            result.append(date)
        }
        while let last = result.last, last.timeIntervalSince(now) < minimumHorizon {
            result.append(dayLater(than: last, calendar: calendar))
        }
        return result
    }

    /// 24 Stunden spaeter — ueber den Kalender gerechnet statt ueber eine
    /// feste Sekundenzahl.
    private static func dayLater(than date: Date, calendar: Calendar) -> Date {
        calendar.date(byAdding: .hour, value: 24, to: date)
            ?? date.addingTimeInterval(minimumHorizon)
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
