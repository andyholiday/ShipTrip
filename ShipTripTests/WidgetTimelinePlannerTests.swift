//
//  WidgetTimelinePlannerTests.swift
//  ShipTripTests
//
//  Timeline-Planung fuer das Widget (Taskplan 1.9.0, T1, LE 5): Kandidaten,
//  Deckel von 12 Eintraegen, Horizont von mindestens 24 Stunden, Luecken von
//  hoechstens 24 Stunden und das Auffuellen mit Mitternachten. Belegt ZIEL K4.
//

import Testing
import Foundation
@testable import ShipTrip

// MARK: - Testhilfen

private let berlin: Calendar = {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(identifier: "Europe/Berlin") ?? .gmt
    return calendar
}()

/// Zeitpunkt im Jahr 2026, explizit ueber `DateComponents`.
private func at(_ month: Int, _ day: Int, _ hour: Int = 12) -> Date {
    let components = DateComponents(year: 2026, month: month, day: day, hour: hour)
    return berlin.date(from: components) ?? Date(timeIntervalSince1970: 0)
}

private func plusDays(_ days: Int, from date: Date) -> Date {
    berlin.date(byAdding: .day, value: days, to: date) ?? date
}

/// Groesster Abstand zwischen zwei benachbarten Eintraegen.
private func maximumGap(in dates: [Date]) -> TimeInterval {
    zip(dates, dates.dropFirst()).map { $1.timeIntervalSince($0) }.max() ?? 0
}

private func stopInfo(day: Date, arrival: Date?, departure: Date?) -> WidgetStopInfo {
    WidgetStopInfo(id: UUID(), name: "Bergen", country: "Norwegen", isSeaDay: false,
                   day: day, arrival: arrival, departure: departure)
}

/// Aktive Reise am Maximalbestand: `maxRouteStops` datierte Eintraege an
/// aufeinanderfolgenden Tagen, aufgeloest ueber den echten Resolver.
private func maximalActiveState(now: Date) -> WidgetState {
    let firstArrival = at(6, 1, 8)
    let route = (0..<WidgetSnapshot.maxRouteStops).map { index in
        StopSummary(id: UUID(), name: "Hafen \(index)", country: "Norwegen",
                    arrival: plusDays(index, from: firstArrival),
                    departure: plusDays(index, from: at(6, 1, 18)),
                    sortOrder: index, isSeaDay: index.isMultiple(of: 5))
    }
    let cruise = CruiseSummary(
        id: UUID(), title: "Grosse Nordlandreise", ship: "AIDAsol", startDate: at(6, 1, 6),
        endDate: plusDays(WidgetSnapshot.maxRouteStops - 1, from: at(6, 1, 18)), route: route
    )
    let snapshot = WidgetSnapshot(generatedAt: now.addingTimeInterval(-3600), cruises: [cruise])
    return WidgetStateResolver.resolve(.snapshot(snapshot), now: now, calendar: berlin)
}

// MARK: - Timeline

@Suite("WidgetTimelinePlanner — Kandidaten, Deckel und Horizont (ZIEL K4)")
struct WidgetTimelinePlannerTests {

    @Test("Maximalbestand: hoechstens 12 Eintraege, aufsteigend, ueber 24 Stunden")
    func maximumStockStaysWithinLimits() {
        let now = plusDays(10, from: at(6, 1, 10))
        let dates = WidgetTimelinePlanner.entryDates(
            for: maximalActiveState(now: now),
            now: now,
            calendar: berlin
        )

        #expect(dates.first == now)
        #expect(dates.count <= 12)
        #expect(zip(dates, dates.dropFirst()).allSatisfy { $0 < $1 })
        #expect((dates.last ?? now) >= now.addingTimeInterval(24 * 60 * 60))
        // Der Wechsel auf den naechsten Stopp muss als Eintrag vorkommen.
        #expect(dates.contains(plusDays(11, from: at(6, 1, 8))))
    }

    @Test("Fehlen Kandidaten, fuellen folgende Mitternachte den Horizont auf")
    func fillsWithMidnights() {
        let now = at(6, 3, 10)
        // Ankunft liegt hinter uns, Abfahrt in drei Stunden, kein naechster Stopp.
        let state = WidgetState.active(ActiveInfo(
            title: "Nordland", ship: "AIDAsol", cruiseStart: at(6, 1, 17), cruiseEnd: at(6, 3, 8),
            currentStop: stopInfo(day: at(6, 3, 0), arrival: at(6, 3, 8), departure: at(6, 3, 13)),
            nextStop: nil, isAfterLastStop: true
        ))

        let dates = WidgetTimelinePlanner.entryDates(for: state, now: now, calendar: berlin)

        // Vergangene Ankunft faellt raus; Mitternacht und Reiseende fallen
        // auf denselben Zeitpunkt und stehen nur einmal drin. Dahinter fuellen
        // die Tagesmitternachte bis zum Deckel auf.
        #expect(Array(dates.prefix(4)) == [now, at(6, 3, 13), at(6, 4, 0), at(6, 5, 0)])
        #expect(dates.count == WidgetTimelinePlanner.maxEntries)
    }

    @Test("Countdown: Reisestart und naechste Mitternacht sind Eintraege")
    func countdownIncludesStart() {
        let now = at(6, 3, 10)
        let state = WidgetState.countdown(CountdownInfo(
            title: "Nordland", ship: "AIDAsol", startDate: at(6, 5, 17), daysUntilStart: 2
        ))

        let dates = WidgetTimelinePlanner.entryDates(for: state, now: now, calendar: berlin)

        #expect(Array(dates.prefix(4)) == [now, at(6, 4, 0), at(6, 5, 0), at(6, 5, 17)])
        #expect(dates.count == WidgetTimelinePlanner.maxEntries)
    }

    @Test("Countdown weit voraus: taegliche Eintraege statt einer Mehrtages-Luecke")
    func countdownFarAheadHasNoGaps() {
        let now = at(6, 3, 10)
        let state = WidgetState.countdown(CountdownInfo(
            title: "Nordland", ship: "AIDAsol",
            startDate: plusDays(30, from: at(6, 3, 17)), daysUntilStart: 30
        ))

        let dates = WidgetTimelinePlanner.entryDates(for: state, now: now, calendar: berlin)

        #expect(dates.first == now)
        #expect(dates.count == WidgetTimelinePlanner.maxEntries)
        #expect(maximumGap(in: dates) <= WidgetTimelinePlanner.minimumHorizon)
        #expect((dates.last ?? now)
                >= now.addingTimeInterval(WidgetTimelinePlanner.minimumHorizon))
    }

    @Test("Aktive Reise mit fernem Ende: taegliche Eintraege statt einer Luecke")
    func activeWithDistantEndHasNoGaps() {
        let now = plusDays(10, from: at(6, 1, 10))

        let dates = WidgetTimelinePlanner.entryDates(
            for: maximalActiveState(now: now),
            now: now,
            calendar: berlin
        )

        #expect(dates.first == now)
        #expect(dates.count == WidgetTimelinePlanner.maxEntries)
        #expect(maximumGap(in: dates) <= WidgetTimelinePlanner.minimumHorizon)
    }

    @Test("Leerlauf und leere Zustaende: Mitternacht und danach der Mindesthorizont")
    func idleAndUnavailable() {
        let now = at(6, 3, 10)
        let idle = WidgetState.idle(IdleInfo(
            lastCruiseTitle: "Nordland", lastCruiseEnd: at(5, 20, 8), daysSinceLastCruise: 14
        ))

        // Nur bis zur naechsten Mitternacht zu planen liesse die `.after`-Policy
        // schon nach 14 Stunden auslaufen; ein Tagesschritt mehr deckt die 24 h.
        let idleDates = WidgetTimelinePlanner.entryDates(for: idle, now: now, calendar: berlin)
        let emptyDates = WidgetTimelinePlanner.entryDates(for: .unavailable(.stale), now: now,
                                                          calendar: berlin)

        #expect(idleDates == [now, at(6, 4, 0), at(6, 5, 0)])
        #expect(emptyDates == [now, at(6, 4, 0), at(6, 5, 0)])
        for dates in [idleDates, emptyDates] {
            #expect((dates.last ?? now)
                    >= now.addingTimeInterval(WidgetTimelinePlanner.minimumHorizon))
            #expect(maximumGap(in: dates) <= WidgetTimelinePlanner.minimumHorizon)
        }
    }

    @Test("Leerlauf am 23-Stunden-Tag: Horizont bleibt trotz kurzem Tag bei 24 h")
    func idleOnShortDayStillCoversHorizon() {
        // 28.03. kurz vor Mitternacht: der Folgetag hat nur 23 Stunden, zwei
        // Mitternachte reichen also nicht ueber den Mindesthorizont.
        let now = at(3, 28, 23)
        let dates = WidgetTimelinePlanner.entryDates(for: .unavailable(.missing), now: now,
                                                     calendar: berlin)

        #expect(dates.first == now)
        #expect((dates.last ?? now)
                >= now.addingTimeInterval(WidgetTimelinePlanner.minimumHorizon))
        #expect(maximumGap(in: dates) <= WidgetTimelinePlanner.minimumHorizon)
    }

    @Test("25-Stunden-Tag: zwischen den Mitternachten steht ein Zwischeneintrag")
    func dstFallBackDayGetsIntermediateEntry() {
        // 25.10.2026 hat in Europe/Berlin 25 Stunden — zwei aufeinanderfolgende
        // Mitternachte allein reissen also eine Luecke von 25 Stunden auf.
        let now = at(10, 24, 10)
        let state = WidgetState.countdown(CountdownInfo(
            title: "Nordland", ship: "AIDAsol",
            startDate: plusDays(30, from: at(10, 24, 17)), daysUntilStart: 30
        ))

        let dates = WidgetTimelinePlanner.entryDates(for: state, now: now, calendar: berlin)

        #expect(maximumGap(in: dates) <= WidgetTimelinePlanner.minimumHorizon)
        // 25.10. 23:00 Ortszeit sind genau 24 Stunden nach der Mitternacht davor.
        #expect(dates.contains(at(10, 25, 23)))
    }
}
