//
//  CalendarEventPlanner.swift
//  ShipTrip
//

import CoreLocation
import Foundation

/// Umfang der Kalender-Spiegelung. Die vier Fälle sind die Kombinationen der
/// zwei Schalter „Stopps eintragen" und „Gesamte Reise als Eintrag".
///
/// Die rawValues von `tripOnly` und `tripAndItinerary` sind Bestand und
/// dürfen sich nicht ändern — sie stehen in den Präferenzen der Nutzer.
enum CalendarSyncMode: String, CaseIterable, Identifiable {
    case tripOnly
    case tripAndItinerary
    case itineraryOnly
    case none

    var id: String { rawValue }

    /// Ob der Ganztagestermin über die gesamte Reise angelegt wird (Opt-in).
    var includesTrip: Bool {
        switch self {
        case .tripOnly, .tripAndItinerary: true
        case .itineraryOnly, .none: false
        }
    }

    /// Ob jeder Hafen und Seetag einen eigenen Termin bekommt.
    var includesItinerary: Bool {
        switch self {
        case .tripAndItinerary, .itineraryOnly: true
        case .tripOnly, .none: false
        }
    }

    var displayName: String {
        switch self {
        case .tripOnly:
            String(localized: "Nur Reisen")
        case .tripAndItinerary:
            String(localized: "Reisen, Häfen & Seetage")
        case .itineraryOnly:
            String(localized: "Nur Häfen & Seetage")
        case .none:
            String(localized: "Keine Einträge")
        }
    }
}

struct CalendarEventDraft: Equatable {
    let stableKey: String
    let title: String
    let startDate: Date
    let endDate: Date
    let isAllDay: Bool
    let location: String?
    /// Koordinate des Hafens, sofern bekannt — damit trägt der Termin einen
    /// strukturierten Ort und der Kalender öffnet Karte und Navigation.
    /// `nil` bei Reise- und Seetagsterminen sowie bei Häfen ohne Koordinate.
    let coordinate: CLLocationCoordinate2D?
    let notes: String

    var markerURL: URL {
        URL(string: "shiptrip://calendar/\(stableKey)")!
    }

    /// Von Hand, weil `CLLocationCoordinate2D` als C-Struktur keine
    /// Equatable-Synthese zulässt.
    static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.stableKey == rhs.stableKey
            && lhs.title == rhs.title
            && lhs.startDate == rhs.startDate
            && lhs.endDate == rhs.endDate
            && lhs.isAllDay == rhs.isAllDay
            && lhs.location == rhs.location
            && lhs.coordinate?.latitude == rhs.coordinate?.latitude
            && lhs.coordinate?.longitude == rhs.coordinate?.longitude
            && lhs.notes == rhs.notes
    }
}

enum CalendarEventPlanner {

    static func makeDrafts(
        for cruise: Cruise,
        mode: CalendarSyncMode,
        calendar: Calendar = .current
    ) -> [CalendarEventDraft] {
        var drafts: [CalendarEventDraft] = []
        if mode.includesTrip {
            drafts.append(tripDraft(for: cruise, calendar: calendar))
        }
        guard mode.includesItinerary else { return drafts }

        let route = cruise.route.sorted { $0.sortOrder < $1.sortOrder }
        drafts.append(contentsOf: route.enumerated().map { index, port in
            routeDraft(
                for: port,
                cruise: cruise,
                route: route,
                index: index,
                calendar: calendar
            )
        })
        return drafts
    }

    private static func tripDraft(for cruise: Cruise, calendar: Calendar) -> CalendarEventDraft {
        let start = calendar.startOfDay(for: cruise.startDate)
        let inclusiveEnd = calendar.startOfDay(for: max(cruise.startDate, cruise.endDate))
        let end = calendar.date(byAdding: .day, value: 1, to: inclusiveEnd) ?? inclusiveEnd
        let title = String(localized: "Kreuzfahrt: \(cruise.title)")

        return CalendarEventDraft(
            stableKey: "cruise/\(cruise.id.uuidString)/trip",
            title: title,
            startDate: start,
            endDate: end,
            isAllDay: true,
            location: nil,
            coordinate: nil,
            notes: cruiseNotes(cruise)
        )
    }

    private static func routeDraft(
        for port: Port,
        cruise: Cruise,
        route: [Port],
        index: Int,
        calendar: Calendar
    ) -> CalendarEventDraft {
        let stableKey = "cruise/\(cruise.id.uuidString)/route/\(port.id.uuidString)"

        if port.isSeaDay {
            let previousPort = route[..<index].last { !$0.isSeaDay }
            let nextPort = route[(index + 1)...].first { !$0.isSeaDay }
            let title: String
            if let previousPort, let nextPort {
                title = String(localized: "Seetag: \(previousPort.name) → \(nextPort.name)")
            } else {
                title = String(localized: "Seetag")
            }

            let start = calendar.startOfDay(for: port.arrival)
            let end = calendar.date(byAdding: .day, value: 1, to: start) ?? start
            return CalendarEventDraft(
                stableKey: stableKey,
                title: title,
                startDate: start,
                endDate: end,
                isAllDay: true,
                location: nil,
                coordinate: nil,
                notes: cruiseNotes(cruise)
            )
        }

        let hasTimedStay = port.departure > port.arrival
        let start = hasTimedStay ? port.arrival : calendar.startOfDay(for: port.arrival)
        let end = hasTimedStay
            ? port.departure
            : (calendar.date(byAdding: .day, value: 1, to: start) ?? start)
        let location = port.country.isEmpty ? port.name : "\(port.name), \(port.country)"
        let coordinate = port.hasValidCoordinates
            ? CLLocationCoordinate2D(latitude: port.latitude, longitude: port.longitude)
            : nil

        return CalendarEventDraft(
            stableKey: stableKey,
            title: String(localized: "Hafen: \(port.name)"),
            startDate: start,
            endDate: end,
            isAllDay: !hasTimedStay,
            location: location,
            coordinate: coordinate,
            notes: cruiseNotes(cruise)
        )
    }

    private static func cruiseNotes(_ cruise: Cruise) -> String {
        [
            cruise.shippingLine,
            cruise.ship,
            String(localized: "Automatisch mit ShipTrip synchronisiert")
        ]
        .filter { !$0.isEmpty }
        .joined(separator: " · ")
    }
}
