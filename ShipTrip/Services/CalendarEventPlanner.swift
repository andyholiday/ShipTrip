//
//  CalendarEventPlanner.swift
//  ShipTrip
//

import Foundation

enum CalendarSyncMode: String, CaseIterable, Identifiable {
    case tripOnly
    case tripAndItinerary

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .tripOnly:
            String(localized: "Nur Reisen")
        case .tripAndItinerary:
            String(localized: "Reisen, Häfen & Seetage")
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
    let notes: String

    var markerURL: URL {
        URL(string: "shiptrip://calendar/\(stableKey)")!
    }
}

enum CalendarEventPlanner {

    static func makeDrafts(
        for cruise: Cruise,
        mode: CalendarSyncMode,
        calendar: Calendar = .current
    ) -> [CalendarEventDraft] {
        var drafts = [tripDraft(for: cruise, calendar: calendar)]
        guard mode == .tripAndItinerary else { return drafts }

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
                notes: cruiseNotes(cruise)
            )
        }

        let hasTimedStay = port.departure > port.arrival
        let start = hasTimedStay ? port.arrival : calendar.startOfDay(for: port.arrival)
        let end = hasTimedStay
            ? port.departure
            : (calendar.date(byAdding: .day, value: 1, to: start) ?? start)
        let location = port.country.isEmpty ? port.name : "\(port.name), \(port.country)"

        return CalendarEventDraft(
            stableKey: stableKey,
            title: String(localized: "Hafen: \(port.name)"),
            startDate: start,
            endDate: end,
            isAllDay: !hasTimedStay,
            location: location,
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
