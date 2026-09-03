//
//  WidgetStateResolver.swift
//  ShipTrip
//
//  Reine Zustandsableitung fuer das Widget (Taskplan 1.9.0,
//  Leitentscheidung 4; Regeln aus ZIEL K1): Snapshot + Zeitpunkt +
//  Kalender -> `WidgetState`. Keine Formatierung, keine Strings, kein I/O.
//
//  Kalender und Zeitzone werden immer injiziert — Kalendertage rechnet der
//  Leser, nie der Schreiber.
//

import Foundation

enum WidgetStateResolver {

    /// Ab diesem Alter gilt ein Snapshot als veraltet.
    static let staleAfterDays = 14

    // MARK: - Einstieg

    /// Leitet den anzuzeigenden Zustand ab.
    ///
    /// Pruefreihenfolge: fehlend/unlesbar -> veraltet -> aktiv -> geplant ->
    /// Leerlauf. Demo-Reisen filtert bereits die App-Seite beim Schreiben.
    static func resolve(
        _ load: WidgetSnapshotLoadResult,
        now: Date,
        calendar: Calendar
    ) -> WidgetState {
        let snapshot: WidgetSnapshot
        switch load {
        case .missing:
            return .unavailable(.missing)
        case .unreadable:
            return .unavailable(.unreadable)
        case .snapshot(let value):
            snapshot = value
        }

        guard snapshot.generatedAt >= staleThreshold(now: now, calendar: calendar) else {
            return .unavailable(.stale)
        }

        if let cruise = activeCruise(in: snapshot.cruises, now: now, calendar: calendar) {
            return .active(activeInfo(for: cruise, now: now, calendar: calendar))
        }
        if let cruise = plannedCruise(in: snapshot.cruises, now: now) {
            return .countdown(CountdownInfo(
                title: cruise.title,
                ship: cruise.ship,
                startDate: cruise.startDate,
                daysUntilStart: dayDifference(from: now, to: cruise.startDate, calendar: calendar)
            ))
        }
        return .idle(idleInfo(for: lastCruise(in: snapshot.cruises, now: now),
                              now: now,
                              calendar: calendar))
    }

    // MARK: - Auswahl der Reise

    /// Aktiv ist eine Reise ab `startDate` bis zum Ende des Kalendertags von
    /// `endDate` — ein um 00:00 gespeicherter Ausschiffungstag zaehlt also
    /// den ganzen Tag mit. Bei mehreren aktiven gewinnt der frueheste Start.
    private static func activeCruise(
        in cruises: [CruiseSummary],
        now: Date,
        calendar: Calendar
    ) -> CruiseSummary? {
        cruises
            .filter { $0.startDate <= now && now < endOfDay(for: $0.endDate, calendar: calendar) }
            .min { $0.startDate < $1.startDate }
    }

    private static func plannedCruise(in cruises: [CruiseSummary], now: Date) -> CruiseSummary? {
        cruises.filter { $0.startDate > now }.min { $0.startDate < $1.startDate }
    }

    private static func lastCruise(in cruises: [CruiseSummary], now: Date) -> CruiseSummary? {
        cruises.filter { $0.endDate < now }.max { $0.endDate < $1.endDate }
    }

    // MARK: - Aktive Reise

    private static func activeInfo(
        for cruise: CruiseSummary,
        now: Date,
        calendar: Calendar
    ) -> ActiveInfo {
        let stops = resolvedStops(of: cruise, calendar: calendar)
        let index = currentIndex(in: stops, now: now, calendar: calendar)
        let current = index.map { stops[$0] }
        let next: WidgetStopInfo?
        if let index {
            next = index + 1 < stops.count ? stops[index + 1] : nil
        } else {
            // Der erste Eintrag steht noch bevor (etwa am Einschiffungsabend).
            next = stops.first
        }

        return ActiveInfo(
            title: cruise.title,
            ship: cruise.ship,
            cruiseStart: cruise.startDate,
            cruiseEnd: cruise.endDate,
            currentStop: current,
            nextStop: next,
            isAfterLastStop: current != nil && next == nil
        )
    }

    /// Route in kanonischer Ordnung, mit aufgeloestem Kalendertag.
    ///
    /// Ein Eintrag gilt als *zeitlos*, wenn seine Ankunft ausserhalb von
    /// `[startDate, Ende des endDate-Tages]` liegt. Dann traegt er keine
    /// Uhrzeiten und sein Tag ist `startDate` plus Index in der Ordnung.
    private static func resolvedStops(
        of cruise: CruiseSummary,
        calendar: Calendar
    ) -> [WidgetStopInfo] {
        let startDay = calendar.startOfDay(for: cruise.startDate)
        let endExclusive = endOfDay(for: cruise.endDate, calendar: calendar)

        return cruise.route.sorted(by: isBefore).enumerated().map { index, stop in
            let isTimeless = stop.arrival < cruise.startDate || stop.arrival >= endExclusive
            let day = isTimeless
                ? (calendar.date(byAdding: .day, value: index, to: startDay) ?? startDay)
                : calendar.startOfDay(for: stop.arrival)

            return WidgetStopInfo(
                id: stop.id,
                name: stop.name,
                country: stop.country,
                isSeaDay: stop.isSeaDay,
                day: day,
                arrival: isTimeless ? nil : stop.arrival,
                departure: isTimeless ? nil : stop.departure
            )
        }
    }

    /// Kanonische Ordnung: `sortOrder`, bei Gleichstand `arrival`, dann `id`.
    private static func isBefore(_ lhs: StopSummary, _ rhs: StopSummary) -> Bool {
        if lhs.sortOrder != rhs.sortOrder { return lhs.sortOrder < rhs.sortOrder }
        if lhs.arrival != rhs.arrival { return lhs.arrival < rhs.arrival }
        return lhs.id.uuidString < rhs.id.uuidString
    }

    /// Aktueller Eintrag: erst das Zeitfenster, dann der heutige Kalendertag,
    /// zuletzt der letzte vergangene Eintrag. `nil`, wenn die Route leer ist
    /// oder noch kein Eintrag begonnen hat.
    ///
    /// Liegen mehrere Eintraege auf dem heutigen Tag (Tenderhafen morgens,
    /// Abendhafen), gilt der letzte, dessen Ankunft schon vorbei ist.
    private static func currentIndex(
        in stops: [WidgetStopInfo],
        now: Date,
        calendar: Calendar
    ) -> Int? {
        let inWindow = stops.firstIndex { stop in
            guard let arrival = stop.arrival, let departure = stop.departure else { return false }
            return arrival <= now && now <= departure
        }
        if let inWindow { return inWindow }

        let today = calendar.startOfDay(for: now)
        let todays = stops.indices.filter { stops[$0].day == today }
        if let started = todays.last(where: { (stops[$0].arrival ?? today) <= now }) {
            return started
        }
        if let first = todays.first { return first }
        return stops.lastIndex { $0.day < today }
    }

    // MARK: - Leerlauf

    private static func idleInfo(
        for cruise: CruiseSummary?,
        now: Date,
        calendar: Calendar
    ) -> IdleInfo {
        guard let cruise else {
            return IdleInfo(lastCruiseTitle: nil, lastCruiseEnd: nil, daysSinceLastCruise: nil)
        }
        return IdleInfo(
            lastCruiseTitle: cruise.title,
            lastCruiseEnd: cruise.endDate,
            daysSinceLastCruise: dayDifference(from: cruise.endDate, to: now, calendar: calendar)
        )
    }

    // MARK: - Kalenderrechnung

    /// Aelter als dieser Zeitpunkt heisst veraltet.
    private static func staleThreshold(now: Date, calendar: Calendar) -> Date {
        calendar.date(byAdding: .day, value: -staleAfterDays, to: now)
            ?? now.addingTimeInterval(-Double(staleAfterDays) * 86_400)
    }

    /// Erster Moment nach dem Kalendertag von `date` (lokale Mitternacht).
    private static func endOfDay(for date: Date, calendar: Calendar) -> Date {
        let start = calendar.startOfDay(for: date)
        return calendar.date(byAdding: .day, value: 1, to: start)
            ?? start.addingTimeInterval(86_400)
    }

    /// Ganze Kalendertage zwischen zwei Zeitpunkten, ueber die Tagesgrenzen
    /// gerechnet — damit zaehlt auch ein 23- oder 25-Stunden-Tag als einer.
    private static func dayDifference(from: Date, to: Date, calendar: Calendar) -> Int {
        calendar.dateComponents(
            [.day],
            from: calendar.startOfDay(for: from),
            to: calendar.startOfDay(for: to)
        ).day ?? 0
    }
}
