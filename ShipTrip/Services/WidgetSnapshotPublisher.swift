//
//  WidgetSnapshotPublisher.swift
//  ShipTrip
//
//  Baut aus dem persistierten Reisebestand den Widget-Snapshot und laedt
//  danach die Widget-Timelines neu (Taskplan 1.9.0, Leitentscheidung 6;
//  ZIEL K3). Ausgeloest wird das durch **einen** zentralen Hook in
//  `ShipTripApp` — `ModelContext.didSave`, `NSPersistentStoreRemoteChange`
//  und `scenePhase == .active` laufen alle durch `publish()`.
//
//  Zwei Invarianten tragen den Rest:
//  1. Es wird nur der bereits persistierte Ist-Stand veroeffentlicht, nie ein
//     offener Kontext — deshalb haengen alle Trigger an Save-Ereignissen.
//  2. Ein Widget-Problem darf nie einen Speichervorgang der App gefaehrden:
//     Fehler werden protokolliert, nie geworfen.
//

import Foundation
import SwiftData
import WidgetKit
import OSLog

private let logger = Logger(subsystem: "com.andre.ShipTrip", category: "Widget")

/// Schreibt den Widget-Snapshot koalesziert aus dem `mainContext`.
@MainActor
final class WidgetSnapshotPublisher: WidgetSnapshotPublishing {

    private let container: ModelContainer
    private let writer: WidgetSnapshotWriter
    private let reload: @Sendable () -> Void
    private let debounce: Duration

    /// Lesevorgang als Naht (Fix 3): die Voreinstellung holt alle
    /// Nicht-Demo-Reisen aus dem uebergebenen Kontext, Tests reichen einen
    /// Fehlerfall herein.
    private let fetchCruises: (ModelContext) throws -> [Cruise]

    /// Der eine ausstehende Schreibauftrag. Ein neuer `publish()`-Aufruf
    /// verwirft ihn und plant neu — so wird aus einem Sturm von Saves genau
    /// ein Snapshot.
    private var pending: Task<Void, Never>?

    init(
        container: ModelContainer,
        store: WidgetSnapshotStore,
        reload: @escaping @Sendable () -> Void = { WidgetCenter.shared.reloadAllTimelines() },
        debounce: Duration = .seconds(1),
        fetchCruises: @escaping (ModelContext) throws -> [Cruise] = { context in
            try context.fetch(
                FetchDescriptor<Cruise>(predicate: #Predicate<Cruise> { $0.isDemo == false })
            )
        }
    ) {
        self.container = container
        self.writer = WidgetSnapshotWriter(store: store)
        self.reload = reload
        self.debounce = debounce
        self.fetchCruises = fetchCruises
    }

    // MARK: - Ausloesen

    /// Hinweis, dass sich der Bestand geaendert haben koennte.
    ///
    /// `nonisolated`, weil das Protokoll die Methode ohne Isolation verlangt —
    /// die eigentliche Arbeit hopst sofort auf den MainActor.
    nonisolated func publish() {
        Task { @MainActor [weak self] in
            self?.schedule()
        }
    }

    /// Schreibt sofort, ohne Entprellung. Fuer den Kaltstart-Hook in
    /// `ShipTripApp` und Tests, die kein Warten auf den Debounce brauchen.
    func publishNow() async {
        pending?.cancel()
        pending = nil
        await write()
    }

    private func schedule() {
        pending?.cancel()
        let delay = debounce
        pending = Task { @MainActor [weak self] in
            do {
                try await Task.sleep(for: delay)
            } catch {
                return // abgeloest durch einen neueren Aufruf
            }
            guard let self, !Task.isCancelled else { return }
            await self.write()
        }
    }

    // MARK: - Schreiben

    private func write() async {
        let snapshot = makeSnapshot(now: Date())
        do {
            try await writer.save(snapshot, generation: 0)
        } catch {
            logger.error("Widget-Snapshot nicht geschrieben: \(error.localizedDescription)")
            return
        }
        reload()
    }

    /// Fetch und DTO-Abbildung laufen vollstaendig hier auf dem MainActor;
    /// den Aktor verlassen ausschliesslich `Sendable`-Werte, nie ein `@Model`.
    private func makeSnapshot(now: Date) -> WidgetSnapshot {
        let cruises = (try? fetchCruises(container.mainContext)) ?? []
        let calendar = Calendar.current
        let active = activeCruise(in: cruises, now: now, calendar: calendar)

        let summaries = select(cruises, active: active, now: now, calendar: calendar)
            .map { cruise in
                summary(
                    for: cruise,
                    isActive: cruise.id == active?.id,
                    now: now,
                    calendar: calendar
                )
            }
        return WidgetSnapshot(generatedAt: now, cruises: summaries)
    }

    // MARK: - Auswahl (hoechstens drei Reisen)

    /// Die aktive Reise mit dem fruehesten Start, die naechste geplante und
    /// die juengste vergangene — dieselbe Rangfolge, die der Resolver spaeter
    /// im Widget auswertet.
    private func select(
        _ cruises: [Cruise],
        active: Cruise?,
        now: Date,
        calendar: Calendar
    ) -> [Cruise] {
        let planned = cruises
            .filter { $0.startDate > now }
            .min { $0.startDate < $1.startDate }
        let past = cruises
            .filter { endOfDay(for: $0.endDate, calendar: calendar) <= now }
            .max { $0.endDate < $1.endDate }

        var selected: [Cruise] = []
        for candidate in [active, planned, past] {
            guard let candidate, !selected.contains(where: { $0.id == candidate.id }) else {
                continue
            }
            selected.append(candidate)
        }
        return Array(selected.prefix(WidgetSnapshot.maxCruises))
    }

    /// Aktiv ist eine Reise ab `startDate` bis zum Ende des Kalendertags von
    /// `endDate`; bei mehreren gewinnt der frueheste Start.
    private func activeCruise(in cruises: [Cruise], now: Date, calendar: Calendar) -> Cruise? {
        cruises
            .filter { $0.startDate <= now && now < endOfDay(for: $0.endDate, calendar: calendar) }
            .min { $0.startDate < $1.startDate }
    }

    // MARK: - Abbildung einer Reise

    private func summary(
        for cruise: Cruise,
        isActive: Bool,
        now: Date,
        calendar: Calendar
    ) -> CruiseSummary {
        let ordered = cruise.route.sorted(by: isBefore)
        let anchor = isActive ? anchorIndex(in: ordered, now: now, calendar: calendar) : 0
        let route = capped(ordered, anchor: anchor).map { port in
            StopSummary(
                id: port.id,
                name: port.name,
                country: port.country.isEmpty ? nil : port.country,
                arrival: port.arrival,
                departure: port.departure,
                sortOrder: port.sortOrder,
                isSeaDay: port.isSeaDay
            )
        }
        return CruiseSummary(
            id: cruise.id,
            title: cruise.title,
            ship: cruise.ship,
            startDate: cruise.startDate,
            endDate: cruise.endDate,
            route: route
        )
    }

    /// Kanonische Ordnung: `sortOrder`, bei Gleichstand `arrival`, dann `id` —
    /// identisch zu `WidgetStateResolver`, damit Schreiber und Leser dieselbe
    /// Reihenfolge sehen.
    private func isBefore(_ lhs: Port, _ rhs: Port) -> Bool {
        if lhs.sortOrder != rhs.sortOrder { return lhs.sortOrder < rhs.sortOrder }
        if lhs.arrival != rhs.arrival { return lhs.arrival < rhs.arrival }
        return lhs.id.uuidString < rhs.id.uuidString
    }

    /// Fenster von hoechstens `maxRouteStops` Eintraegen um `anchor` herum
    /// (fuenf zurueck, der Rest nach vorn), an die Routengrenzen geklemmt.
    private func capped(_ stops: [Port], anchor: Int) -> ArraySlice<Port> {
        let limit = WidgetSnapshot.maxRouteStops
        guard stops.count > limit else { return stops[...] }
        let upper = min(stops.count, max(anchor - 5, 0) + limit)
        return stops[(upper - limit)..<upper]
    }

    /// Eintrag des heutigen Tages, sonst der letzte vergangene, sonst der
    /// Routenanfang.
    private func anchorIndex(in stops: [Port], now: Date, calendar: Calendar) -> Int {
        let today = calendar.startOfDay(for: now)
        let onToday = stops.firstIndex { calendar.startOfDay(for: $0.arrival) == today }
        if let onToday { return onToday }
        return stops.lastIndex { calendar.startOfDay(for: $0.arrival) < today } ?? 0
    }

    /// Erster Moment nach dem Kalendertag von `date`.
    private func endOfDay(for date: Date, calendar: Calendar) -> Date {
        let start = calendar.startOfDay(for: date)
        return calendar.date(byAdding: .day, value: 1, to: start)
            ?? start.addingTimeInterval(86_400)
    }
}
