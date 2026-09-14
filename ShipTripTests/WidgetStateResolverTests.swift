//
//  WidgetStateResolverTests.swift
//  ShipTripTests
//
//  Zustandsableitung fuer das Widget (Taskplan 1.9.0, T1). Belegt die drei
//  Zweige aus ZIEL K1 samt Kanten: Tag-Grenze, Ausschiffungstag, zeitlose
//  Eintraege, `sortOrder`-Ties, Reise ohne Route, mehrere aktive Reisen,
//  Stale-Grenze, die Raender des Stopp-Fensters `[Ankunft, Abfahrt)` und
//  beide DST-Wechsel 2026 in Europe/Berlin.
//

import Testing
import Foundation
@testable import ShipTrip

// MARK: - Testhilfen

/// Fester Kalender fuer alle Tests: gregorianisch, Europe/Berlin. In dieser
/// Zone hat der 29.03.2026 nur 23 und der 25.10.2026 25 Stunden.
private let berlin: Calendar = {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(identifier: "Europe/Berlin") ?? .gmt
    return calendar
}()

/// Zeitpunkt im Jahr 2026, explizit ueber `DateComponents`.
private func at(_ month: Int, _ day: Int, _ hour: Int = 12, _ minute: Int = 0) -> Date {
    let components = DateComponents(year: 2026, month: month, day: day,
                                    hour: hour, minute: minute)
    return berlin.date(from: components) ?? Date(timeIntervalSince1970: 0)
}

/// Ankunft weit ausserhalb jedes Reisezeitraums -> der Eintrag ist zeitlos.
private let timelessArrival = Date(timeIntervalSince1970: 0)

private func stop(_ name: String, order: Int, arrival: Date, departure: Date,
                  seaDay: Bool = false, id: UUID = UUID()) -> StopSummary {
    StopSummary(id: id, name: name, country: seaDay ? nil : "Norwegen", arrival: arrival,
                departure: departure, sortOrder: order, isSeaDay: seaDay)
}

private func cruise(_ title: String = "Nordland", start: Date, end: Date,
                    route: [StopSummary] = []) -> CruiseSummary {
    CruiseSummary(id: UUID(), title: title, ship: "AIDAsol",
                  startDate: start, endDate: end, route: route)
}

private func loaded(_ cruises: [CruiseSummary], generatedAt: Date) -> WidgetSnapshotLoadResult {
    .snapshot(WidgetSnapshot(generatedAt: generatedAt, cruises: cruises))
}

/// Aufloesung mit frischem Snapshot (eine Stunde alt), damit die Stale-Regel
/// ausserhalb ihres eigenen Tests nie mitspricht.
private func resolve(_ cruises: [CruiseSummary], at now: Date) -> WidgetState {
    let fresh = loaded(cruises, generatedAt: now.addingTimeInterval(-3600))
    return WidgetStateResolver.resolve(fresh, now: now, calendar: berlin)
}

/// Reise 01.06.–07.06.2026 mit drei datierten Eintraegen (02./03./04.06.).
private func standardCruise() -> CruiseSummary {
    cruise(start: at(6, 1, 17), end: at(6, 7, 8), route: [
        stop("Bergen", order: 0, arrival: at(6, 2, 8), departure: at(6, 2, 18)),
        stop("Seetag", order: 1, arrival: at(6, 3, 0), departure: at(6, 3, 23, 59), seaDay: true),
        stop("Tromsoe", order: 2, arrival: at(6, 4, 7), departure: at(6, 4, 17))
    ])
}

private extension WidgetState {
    var asActive: ActiveInfo? { if case .active(let info) = self { info } else { nil } }
    var asCountdown: CountdownInfo? { if case .countdown(let info) = self { info } else { nil } }
    var asIdle: IdleInfo? { if case .idle(let info) = self { info } else { nil } }
}

// MARK: - Zustandsableitung

@Suite("WidgetStateResolver — drei Zweige und die Kanten aus ZIEL K1")
struct WidgetStateResolverTests {

    // MARK: Verfuegbarkeit

    @Test("Fehlende und unlesbare Datei melden den passenden Grund")
    func unavailableBranches() {
        #expect(WidgetStateResolver.resolve(.missing, now: at(6, 1), calendar: berlin)
                == .unavailable(.missing))
        #expect(WidgetStateResolver.resolve(.unreadable, now: at(6, 1), calendar: berlin)
                == .unavailable(.unreadable))
    }

    @Test("Stale-Grenze: 13 und exakt 14 Tage sind frisch, 15 Tage sind veraltet")
    func staleBoundary() {
        let now = at(6, 20)
        let fresh = loaded([], generatedAt: at(6, 7))
        let exactly = loaded([], generatedAt: at(6, 6))
        let old = loaded([], generatedAt: at(6, 5))

        #expect(WidgetStateResolver.resolve(fresh, now: now, calendar: berlin).asIdle != nil)
        #expect(WidgetStateResolver.resolve(exactly, now: now, calendar: berlin).asIdle != nil)
        #expect(WidgetStateResolver.resolve(old, now: now, calendar: berlin)
                == .unavailable(.stale))
    }

    // MARK: Aktiv

    @Test("Liegt `now` im Fenster eines Eintrags, ist er der aktuelle Stopp")
    func currentStopFromWindow() {
        let info = resolve([standardCruise()], at: at(6, 2, 10)).asActive

        #expect(info?.title == "Nordland")
        #expect(info?.ship == "AIDAsol")
        #expect(info?.currentStop?.name == "Bergen")
        #expect(info?.currentStop?.arrival == at(6, 2, 8))
        #expect(info?.currentStop?.departure == at(6, 2, 18))
        #expect(info?.nextStop?.name == "Seetag")
        #expect(info?.nextStop?.isSeaDay == true)
        #expect(info?.isAfterLastStop == false)
    }

    @Test("Tag-Grenze: um Mitternacht wechselt der aktuelle Stopp")
    func dayBoundary() {
        #expect(resolve([standardCruise()], at: at(6, 2, 23, 30)).asActive?.currentStop?.name
                == "Bergen")
        #expect(resolve([standardCruise()], at: at(6, 3, 0, 30)).asActive?.currentStop?.name
                == "Seetag")
    }

    @Test("Ausschiffungstag mit `endDate` um 08:00 ist abends noch aktiv")
    func disembarkationDayStaysActive() {
        let voyage = standardCruise()

        #expect(resolve([voyage], at: at(6, 7, 20)).asActive != nil)

        let afterwards = resolve([voyage], at: at(6, 8, 0, 30)).asIdle
        #expect(afterwards?.lastCruiseEnd == at(6, 7, 8))
        #expect(afterwards?.daysSinceLastCruise == 1)
    }

    @Test("Zeitloser Seetag: Tag aus Startdatum plus Index, keine Uhrzeiten")
    func timelessSeaDay() {
        let cruises = [cruise(start: at(6, 1, 17), end: at(6, 5, 8), route: [
            stop("Seetag", order: 0, arrival: timelessArrival, departure: timelessArrival,
                 seaDay: true),
            stop("Bergen", order: 1, arrival: at(6, 3, 8), departure: at(6, 3, 18))
        ])]

        let info = resolve(cruises, at: at(6, 1, 20)).asActive
        #expect(info?.currentStop?.name == "Seetag")
        #expect(info?.currentStop?.day == at(6, 1, 0))
        #expect(info?.currentStop?.arrival == nil)
        #expect(info?.currentStop?.departure == nil)
        #expect(info?.nextStop?.day == at(6, 3, 0))
        #expect(info?.nextStop?.arrival == at(6, 3, 8))
    }

    @Test("Gleicher `sortOrder`: fruehere Ankunft zuerst, dann die `id`")
    func sortOrderTies() {
        let ids = [UUID(), UUID()].sorted { $0.uuidString < $1.uuidString }
        let cruises = [cruise(start: at(6, 1, 17), end: at(6, 5, 8), route: [
            stop("Spaet", order: 5, arrival: at(6, 3, 10), departure: at(6, 3, 20)),
            stop("Tie B", order: 5, arrival: at(6, 2, 10), departure: at(6, 2, 20), id: ids[1]),
            stop("Tie A", order: 5, arrival: at(6, 2, 10), departure: at(6, 2, 20), id: ids[0])
        ])]

        // Beide Fenster sind deckungsgleich; kanonisch steht `ids[0]` vorn,
        // aktuell ist damit der spaetere Eintrag `ids[1]`.
        let first = resolve(cruises, at: at(6, 2, 12)).asActive
        #expect(first?.currentStop?.id == ids[1])
        #expect(first?.nextStop?.name == "Spaet")
        #expect(resolve(cruises, at: at(6, 3, 12)).asActive?.currentStop?.name == "Spaet")
    }

    @Test("Reise ohne Route: kein aktueller und kein naechster Stopp")
    func cruiseWithoutRoute() {
        let info = resolve([cruise(start: at(6, 1, 17), end: at(6, 5, 8))], at: at(6, 3)).asActive

        #expect(info?.currentStop == nil)
        #expect(info?.nextStop == nil)
        #expect(info?.isAfterLastStop == false)
        #expect(info?.cruiseEnd == at(6, 5, 8))
    }

    @Test("Mehrere aktive Reisen: die mit dem fruehesten Start gewinnt")
    func multipleActiveCruises() {
        let cruises = [
            cruise("Spaeter", start: at(6, 2, 17), end: at(6, 9, 8)),
            cruise("Frueher", start: at(6, 1, 17), end: at(6, 8, 8))
        ]

        #expect(resolve(cruises, at: at(6, 3)).asActive?.title == "Frueher")
    }

    @Test("Zwischen zwei Eintraegen: letzter vergangener gilt, Nachfolger folgt")
    func betweenStopsWithoutDayMatch() {
        let cruises = [cruise(start: at(6, 1, 17), end: at(6, 7, 8), route: [
            stop("Bergen", order: 0, arrival: at(6, 2, 8), departure: at(6, 2, 18)),
            stop("Tromsoe", order: 1, arrival: at(6, 5, 8), departure: at(6, 5, 18))
        ])]

        let info = resolve(cruises, at: at(6, 3, 12)).asActive
        #expect(info?.currentStop?.name == "Bergen")
        #expect(info?.nextStop?.name == "Tromsoe")
        #expect(info?.isAfterLastStop == false)
    }

    @Test("Zwei Stopps am selben Tag: der spaeter begonnene ist der aktuelle")
    func twoStopsOnSameDay() {
        let cruises = [cruise(start: at(6, 1, 17), end: at(6, 7, 8), route: [
            stop("Frueh", order: 0, arrival: at(6, 3, 6), departure: at(6, 3, 9)),
            stop("Spaet", order: 1, arrival: at(6, 3, 14), departure: at(6, 3, 20)),
            stop("Tromsoe", order: 2, arrival: at(6, 5, 8), departure: at(6, 5, 18))
        ])]

        // Beide Fenster sind vorbei: der spaetere Hafen ist der aktuelle.
        let afterBoth = resolve(cruises, at: at(6, 3, 22)).asActive
        #expect(afterBoth?.currentStop?.name == "Spaet")
        #expect(afterBoth?.nextStop?.name == "Tromsoe")

        // Zwischen beiden Fenstern gilt weiter der fruehere Hafen.
        let between = resolve(cruises, at: at(6, 3, 11)).asActive
        #expect(between?.currentStop?.name == "Frueh")
        #expect(between?.nextStop?.name == "Spaet")
    }

    @Test("Zur Ankunftszeit gilt der Eintrag bereits als aktuell")
    func currentStopAtItsArrival() {
        let info = resolve([standardCruise()], at: at(6, 2, 8)).asActive

        #expect(info?.currentStop?.name == "Bergen")
        #expect(info?.nextStop?.name == "Seetag")
    }

    @Test("Nahtloser Nachfolger: zur Abfahrtszeit gilt schon der naechste Stopp")
    func seamlessStopsSwitchAtDeparture() {
        // Abfahrt des ersten und Ankunft des zweiten fallen zusammen. Das
        // Fenster ist halboffen, der Wechsel faellt also exakt auf 14:00.
        let cruises = [cruise(start: at(6, 1, 17), end: at(6, 7, 8), route: [
            stop("Bergen", order: 0, arrival: at(6, 3, 8), departure: at(6, 3, 14)),
            stop("Tromsoe", order: 1, arrival: at(6, 3, 14), departure: at(6, 3, 20))
        ])]

        #expect(resolve(cruises, at: at(6, 3, 13, 59)).asActive?.currentStop?.name == "Bergen")

        let atSwitch = resolve(cruises, at: at(6, 3, 14)).asActive
        #expect(atSwitch?.currentStop?.name == "Tromsoe")
        #expect(atSwitch?.nextStop == nil)
        #expect(atSwitch?.isAfterLastStop == true)
    }

    @Test("Ueberlappende Fenster: der kanonisch letzte begonnene Stopp gilt")
    func overlappingStopsUseCanonicallyLast() {
        let cruises = [cruise(start: at(6, 1, 17), end: at(6, 7, 8), route: [
            stop("Bergen", order: 0, arrival: at(6, 3, 8), departure: at(6, 3, 19)),
            stop("Tromsoe", order: 1, arrival: at(6, 3, 14), departure: at(6, 3, 22))
        ])]

        #expect(resolve(cruises, at: at(6, 3, 12)).asActive?.currentStop?.name == "Bergen")
        #expect(resolve(cruises, at: at(6, 3, 16)).asActive?.currentStop?.name == "Tromsoe")
    }

    @Test("Nach dem letzten Eintrag: letzter Stopp bleibt, Nachfolger entfaellt")
    func afterLastStop() {
        let info = resolve([standardCruise()], at: at(6, 5, 12)).asActive

        #expect(info?.currentStop?.name == "Tromsoe")
        #expect(info?.nextStop == nil)
        #expect(info?.isAfterLastStop == true)
    }

    @Test("Vor dem ersten Eintrag: noch kein aktueller, aber ein naechster Stopp")
    func beforeFirstStop() {
        let info = resolve([standardCruise()], at: at(6, 1, 20)).asActive

        #expect(info?.currentStop == nil)
        #expect(info?.nextStop?.name == "Bergen")
        #expect(info?.isAfterLastStop == false)
    }

    // MARK: Countdown und Leerlauf

    @Test("Countdown: Start morgen ergibt einen Tag Restzeit")
    func countdownTomorrow() {
        let cruises = [
            cruise("Vergangen", start: at(5, 1, 17), end: at(5, 8, 8)),
            cruise("Geplant", start: at(6, 10, 17), end: at(6, 17, 8))
        ]

        let info = resolve(cruises, at: at(6, 9, 20)).asCountdown
        #expect(info?.title == "Geplant")
        #expect(info?.startDate == at(6, 10, 17))
        #expect(info?.daysUntilStart == 1)
    }

    @Test("Leerlauf: juengste vergangene Reise mit Abstand in Tagen")
    func idleWithLastCruise() {
        let cruises = [
            cruise("Aelter", start: at(4, 25, 17), end: at(5, 1, 8)),
            cruise("Juenger", start: at(5, 14, 17), end: at(5, 20, 8))
        ]

        let info = resolve(cruises, at: at(6, 10)).asIdle
        #expect(info?.lastCruiseTitle == "Juenger")
        #expect(info?.lastCruiseEnd == at(5, 20, 8))
        #expect(info?.daysSinceLastCruise == 21)
    }

    @Test("Leerlauf ohne jede Reise: alle Angaben leer")
    func idleWithoutAnyCruise() {
        #expect(resolve([], at: at(6, 10)).asIdle == IdleInfo(
            lastCruiseTitle: nil,
            lastCruiseEnd: nil,
            daysSinceLastCruise: nil
        ))
    }

    // MARK: Sommerzeit

    @Test("DST-Beginn 29.03.2026 (23 h): zeitlose Tage zaehlen korrekt weiter")
    func dstSpringForward() {
        let cruises = [cruise(start: at(3, 28, 17), end: at(3, 31, 8), route: [
            stop("Seetag 1", order: 0, arrival: timelessArrival, departure: timelessArrival,
                 seaDay: true),
            stop("Seetag 2", order: 1, arrival: timelessArrival, departure: timelessArrival,
                 seaDay: true),
            stop("Bergen", order: 2, arrival: timelessArrival, departure: timelessArrival)
        ])]

        #expect(resolve(cruises, at: at(3, 29, 12)).asActive?.currentStop?.name == "Seetag 2")
        #expect(resolve(cruises, at: at(3, 29, 12)).asActive?.currentStop?.day == at(3, 29, 0))
        #expect(resolve(cruises, at: at(3, 30, 12)).asActive?.currentStop?.name == "Bergen")
        #expect(resolve(cruises, at: at(3, 30, 12)).asActive?.currentStop?.day == at(3, 30, 0))
    }

    @Test("DST-Ende 25.10.2026 (25 h): Tageszuordnung bleibt richtig")
    func dstFallBack() {
        let cruises = [cruise(start: at(10, 24, 17), end: at(10, 27, 8), route: [
            stop("Seetag", order: 0, arrival: timelessArrival, departure: timelessArrival,
                 seaDay: true),
            stop("Kirkenes", order: 1, arrival: at(10, 25, 12), departure: at(10, 25, 20)),
            stop("Tromsoe", order: 2, arrival: at(10, 26, 8), departure: at(10, 26, 18))
        ])]

        let evening = resolve(cruises, at: at(10, 25, 23)).asActive
        #expect(evening?.currentStop?.name == "Kirkenes")
        #expect(evening?.currentStop?.day == at(10, 25, 0))
        #expect(evening?.nextStop?.day == at(10, 26, 0))
        #expect(resolve(cruises, at: at(10, 26, 12)).asActive?.currentStop?.name == "Tromsoe")
    }
}
