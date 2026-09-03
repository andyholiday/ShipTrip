//
//  PreviewFixtures.swift
//  ShipTripWidget
//
//  Feste Zustaende fuer die Xcode-Vorschau (Taskplan 1.9.0, T4). Nur im
//  Debug-Build — der Release-Build kennt weder die Fixtures noch die
//  Vorschauen.
//
//  Zwei der Fixtures sind absichtlich unangenehm lang („Puerto de la Cruz de
//  Tenerife — Islas Canarias", „Mittelmeer-Traumreise mit Landausfluegen
//  2027"), damit die Layout-Kuerzungen bei Dynamic Type XXL schon in der
//  Vorschau sichtbar werden.
//

#if DEBUG
import Foundation
import SwiftUI
import WidgetKit

enum WidgetPreviewFixtures {

    // MARK: - Bausteine

    private static var today: Date { Calendar.current.startOfDay(for: Date()) }

    private static func moment(day: Int, hour: Int) -> Date {
        today.addingTimeInterval(TimeInterval(day * 86_400 + hour * 3_600))
    }

    private static func stop(
        _ name: String,
        day: Int,
        isSeaDay: Bool = false,
        arrival: Int? = 8,
        departure: Int? = 17
    ) -> WidgetStopInfo {
        WidgetStopInfo(
            id: UUID(),
            name: name,
            country: nil,
            isSeaDay: isSeaDay,
            day: moment(day: day, hour: 0),
            arrival: arrival.map { moment(day: day, hour: $0) },
            departure: departure.map { moment(day: day, hour: $0) }
        )
    }

    private static func entry(_ index: Int, _ state: WidgetState) -> ShipTripWidgetEntry {
        ShipTripWidgetEntry(date: Date().addingTimeInterval(TimeInterval(index * 60)), state: state)
    }

    private static func active(
        title: String = "Ostsee-Rundreise",
        ship: String = "Mein Schiff 4",
        current: WidgetStopInfo?,
        next: WidgetStopInfo?,
        isAfterLastStop: Bool = false
    ) -> WidgetState {
        .active(ActiveInfo(
            title: title,
            ship: ship,
            cruiseStart: moment(day: -2, hour: 18),
            cruiseEnd: moment(day: 5, hour: 8),
            currentStop: current,
            nextStop: next,
            isAfterLastStop: isAfterLastStop
        ))
    }

    // MARK: - Zustaende

    /// Aktiv: Hafen mit Zeiten, danach ein Seetag.
    static let activePort = entry(0, active(
        current: stop("Kopenhagen", day: 0),
        next: stop("Seetag", day: 1, isSeaDay: true, arrival: nil, departure: nil)
    ))

    /// Aktiv: heute ist Seetag, morgen ein Hafen.
    static let activeSeaDay = entry(1, active(
        current: stop("Seetag", day: 0, isSeaDay: true, arrival: 0, departure: 23),
        next: stop("Tallinn", day: 1)
    ))

    /// Aktiv mit adversarial langen Namen — Pruefstein fuer XXL.
    static let activeLongNames = entry(2, active(
        title: "Mittelmeer-Traumreise mit Landausflügen 2027",
        ship: "AIDAnova",
        current: stop("Puerto de la Cruz de Tenerife — Islas Canarias", day: 0),
        next: stop("Santa Cruz de la Palma — Islas Canarias", day: 1)
    ))

    /// Aktiv, aber der letzte Hafen liegt hinter uns.
    static let activeAfterLastStop = entry(3, active(
        current: stop("Kiel", day: 0),
        next: nil,
        isAfterLastStop: true
    ))

    /// Aktiv am Einschiffungsabend: der erste Eintrag steht noch bevor.
    static let activeEmbarkation = entry(4, active(
        current: nil,
        next: stop("Kiel", day: 1)
    ))

    /// Aktiv ohne Route: nur Titel, Schiff und Zeitraum.
    static let activeWithoutRoute = entry(5, active(current: nil, next: nil))

    /// Countdown in zwoelf Tagen.
    static let countdown = entry(6, .countdown(CountdownInfo(
        title: "Mittelmeer-Traumreise mit Landausflügen 2027",
        ship: "AIDAnova",
        startDate: moment(day: 12, hour: 18),
        daysUntilStart: 12
    )))

    /// Countdown jenseits von 99 Tagen — der Kreis zeigt „99+".
    static let countdownFar = entry(7, .countdown(CountdownInfo(
        title: "Karibik im Winter",
        ship: "Mein Schiff 6",
        startDate: moment(day: 210, hour: 18),
        daysUntilStart: 210
    )))

    /// Keine neue Reise, letzte liegt gut drei Monate zurueck.
    static let idle = entry(8, .idle(IdleInfo(
        lastCruiseTitle: "Ostsee-Rundreise",
        lastCruiseEnd: moment(day: -98, hour: 8),
        daysSinceLastCruise: 98
    )))

    /// Ueberhaupt noch keine Reise angelegt.
    static let idleWithoutHistory = entry(9, .idle(IdleInfo(
        lastCruiseTitle: nil,
        lastCruiseEnd: nil,
        daysSinceLastCruise: nil
    )))

    /// Snapshot fehlt, ist unlesbar oder veraltet.
    static let unavailable = entry(10, .unavailable(.stale))
}

// MARK: - Vorschauen

#Preview("Klein", as: .systemSmall) {
    ShipTripWidget()
} timeline: {
    WidgetPreviewFixtures.activePort
    WidgetPreviewFixtures.activeSeaDay
    WidgetPreviewFixtures.activeLongNames
    WidgetPreviewFixtures.activeAfterLastStop
    WidgetPreviewFixtures.countdown
    WidgetPreviewFixtures.idle
    WidgetPreviewFixtures.unavailable
}

#Preview("Mittel", as: .systemMedium) {
    ShipTripWidget()
} timeline: {
    WidgetPreviewFixtures.activePort
    WidgetPreviewFixtures.activeEmbarkation
    WidgetPreviewFixtures.activeLongNames
    WidgetPreviewFixtures.activeWithoutRoute
    WidgetPreviewFixtures.countdown
    WidgetPreviewFixtures.idleWithoutHistory
    WidgetPreviewFixtures.unavailable
}

#Preview("Sperrbildschirm rechteckig", as: .accessoryRectangular) {
    ShipTripWidget()
} timeline: {
    WidgetPreviewFixtures.activePort
    WidgetPreviewFixtures.activeSeaDay
    WidgetPreviewFixtures.activeLongNames
    WidgetPreviewFixtures.activeAfterLastStop
    WidgetPreviewFixtures.countdown
    WidgetPreviewFixtures.idle
    WidgetPreviewFixtures.unavailable
}

#Preview("Sperrbildschirm rund", as: .accessoryCircular) {
    ShipTripWidget()
} timeline: {
    WidgetPreviewFixtures.activePort
    WidgetPreviewFixtures.activeSeaDay
    WidgetPreviewFixtures.activeLongNames
    WidgetPreviewFixtures.countdown
    WidgetPreviewFixtures.countdownFar
    WidgetPreviewFixtures.idle
    WidgetPreviewFixtures.unavailable
}
#endif
