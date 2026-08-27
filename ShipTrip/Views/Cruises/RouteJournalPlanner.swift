//
//  RouteJournalPlanner.swift
//  ShipTrip
//
//  Zuordnung Journal-Eintrag → Route-Stopp (ADR-003, Contract J3neu (a)).
//

import Foundation

/// Ordnet Journal-Eintraege den Route-Stopps des Tagesfadens zu.
///
/// Reine Anzeige-Logik: es wird **kein** Feld am Modell geaendert oder ergaenzt
/// (J3neu (a)). Rein und ohne SwiftUI-Abhaengigkeit, damit die Semantik isoliert
/// testbar ist (Muster `MapRouteVisibilityPlanner`).
enum RouteJournalPlanner {

    /// Ergebnis der Zuordnung: Eintraege je Stopp plus der Sammelblock
    /// „Weitere Eintraege" fuer Tage ohne Route-Stopp.
    struct Assignment: Equatable, Sendable {
        /// `port.id` → Eintrags-IDs in Anzeige-Reihenfolge. Stopps ohne
        /// Eintraege fehlen im Dictionary (kein leerer Journal-Abschnitt,
        /// J3neu (e)).
        let entryIDsByStopID: [UUID: [UUID]]

        /// Sammelblock „Weitere Eintraege" — leer heisst: Block nicht anzeigen
        /// (J3neu (a) Regel 4).
        let unassignedEntryIDs: [UUID]

        /// Eintraege eines Stopps in Anzeige-Reihenfolge; `[]` fuer Stopps ohne
        /// Eintraege.
        func entryIDs(forStopID stopID: UUID) -> [UUID] {
            entryIDsByStopID[stopID] ?? []
        }
    }

    /// Zuordnung nach J3neu (a).
    ///
    /// 1. Eintrag mit `portID`, das ein Stopp der Route traegt → genau dieser
    ///    Stopp. Der Hafen-Bezug hat Vorrang vor dem Datum.
    /// 2. Eintrag ohne `portID` → **erster** Stopp (niedrigster `sortOrder`),
    ///    dessen `arrival`-Tag dem `entryDate`-Tag entspricht. Seetage sind
    ///    normale Traeger.
    /// 3. Ergibt sich aus 1 + 2 (Tag mit mehreren Stopps).
    /// 4. Kein Traeger → Sammelblock „Weitere Eintraege".
    ///
    /// Ein `portID`, das **kein** Stopp der uebergebenen Route traegt (im Live-Store
    /// unerreichbar — SwiftData nullt `port` beim Loeschen), faellt bewusst auf
    /// Regel 2/4 zurueck, statt den Eintrag zu verschlucken.
    ///
    /// Sortierung innerhalb eines Stopps und des Sammelblocks: `entryDate`
    /// aufsteigend, innerhalb eines Tages `createdAt` aufsteigend; `id` als
    /// deterministischer Letzt-Tiebreak.
    ///
    /// - Parameter calendar: Geraete-Kalender fuer die `arrival`-Seite der
    ///   Tag-Vergleiche (Zeitzonen-Vertrag).
    static func assign(
        entries: [JournalEntryInput],
        stops: [RouteStopInput],
        calendar: Calendar = .current
    ) -> Assignment {
        let stopIDs = Set(stops.map(\.id))
        // Erster Stopp je Tag = niedrigster sortOrder; `arrival`/`id` nur als
        // deterministischer Tiebreak bei gleichem sortOrder.
        var firstStopIDByDay: [RouteDayKey: UUID] = [:]
        for stop in stops.sorted(by: isOrderedBefore) {
            let day = RouteDayKey.localDay(stop.arrival, calendar: calendar)
            if firstStopIDByDay[day] == nil { firstStopIDByDay[day] = stop.id }
        }

        var entryIDsByStopID: [UUID: [UUID]] = [:]
        var unassigned: [UUID] = []

        for entry in entries.sorted(by: isOrderedBefore) {
            let carrierID: UUID?
            if let portID = entry.portID, stopIDs.contains(portID) {
                carrierID = portID
            } else {
                carrierID = firstStopIDByDay[RouteDayKey.entryDay(entry.entryDate)]
            }

            if let carrierID {
                entryIDsByStopID[carrierID, default: []].append(entry.id)
            } else {
                unassigned.append(entry.id)
            }
        }

        return Assignment(entryIDsByStopID: entryIDsByStopID, unassignedEntryIDs: unassigned)
    }

    // MARK: - Deterministische Ordnungen

    private static func isOrderedBefore(_ lhs: RouteStopInput, _ rhs: RouteStopInput) -> Bool {
        if lhs.sortOrder != rhs.sortOrder { return lhs.sortOrder < rhs.sortOrder }
        if lhs.arrival != rhs.arrival { return lhs.arrival < rhs.arrival }
        return lhs.id.uuidString < rhs.id.uuidString
    }

    private static func isOrderedBefore(_ lhs: JournalEntryInput, _ rhs: JournalEntryInput) -> Bool {
        let lhsDay = RouteDayKey.entryDay(lhs.entryDate)
        let rhsDay = RouteDayKey.entryDay(rhs.entryDate)
        if lhsDay != rhsDay { return lhsDay < rhsDay }
        if lhs.createdAt != rhs.createdAt { return lhs.createdAt < rhs.createdAt }
        return lhs.id.uuidString < rhs.id.uuidString
    }
}
