//
//  RouteJournalSection.swift
//  ShipTrip
//
//  Route-Abschnitt der CruiseDetailView als Tagesfaden: Stopp-Karten mit
//  Klapp-Zustand, Journal-Eintragszeilen und Sammelblock (Contract J3neu).
//

import Combine
import SwiftUI

/// Der Route-Abschnitt der Detailansicht — **ein** Tagesfaden aus Route-Stopps
/// (inkl. Seetage), keine zweite parallele Tages-Liste (J3neu).
///
/// Der Klapp-Zustand lebt ausschließlich hier im `@State` (J3neu (b),
/// „Persistenz: keine"): effektiver Zustand = manuelle Übersteuerung ??
/// Automatik-Default aus der Reisephase. Bei Tageswechsel (`NSCalendarDayChanged`
/// oder Reaktivierung der Szene an einem neuen Tag) werden Defaults neu berechnet
/// **und** alle Übersteuerungen gelöscht.
struct RouteJournalSection: View {
    let cruise: Cruise
    let onAddPort: () -> Void
    let onSelectPort: (Port) -> Void
    let onDeletePort: (Port) -> Void
    /// Öffnet die Eintrags-Detailansicht (T8c).
    let onOpenEntry: (UUID) -> Void
    /// Öffnet den J2-Editor (T8c). `nil` = Einstieg aus dem Sammelblock, also
    /// ohne Stopp-Vorbelegung (J2-Defaults); sonst der vorbelegte Stopp.
    let onAddEntry: (Port?) -> Void

    @Environment(\.scenePhase) private var scenePhase

    /// Manuelle Übersteuerungen der Klapp-Maschine — nur In-Memory.
    @State private var collapseState = RouteCollapseState()
    /// „Heute" der zuletzt berechneten Defaults; Anker für die Tageswechsel-Erkennung.
    @State private var todayAnchor = Date()

    var body: some View {
        let layout = journalLayout
        let defaults = collapseDefaults
        VStack(alignment: .leading, spacing: 12) {
            header

            if cruise.route.isEmpty {
                emptyRouteHint
            } else {
                ForEach(sortedPorts, id: \.id) { port in
                    stopCard(
                        for: port,
                        entries: layout.entriesByStopID[port.id] ?? [],
                        defaults: defaults
                    )
                }
            }

            if !layout.extraEntries.isEmpty {
                RouteExtraEntriesBlock(
                    entries: layout.extraEntries,
                    onOpenEntry: onOpenEntry,
                    onAddEntry: { onAddEntry(nil) }
                )
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: DesignRadius.sm))
        .onReceive(dayChangePublisher) { _ in refreshIfDayChanged() }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { refreshIfDayChanged() }
        }
    }

    // MARK: - Kopf

    private var header: some View {
        HStack {
            Text("Route")
                .font(.headline)
            Spacer()
            if !sortedPorts.isEmpty {
                Button {
                    toggleAll()
                } label: {
                    Image(systemName: isEverythingExpanded
                          ? "rectangle.compress.vertical"
                          : "rectangle.expand.vertical")
                        .foregroundStyle(Color.accentColor)
                }
                .accessibilityLabel(isEverythingExpanded
                                    ? String(localized: "Alle zuklappen")
                                    : String(localized: "Alle aufklappen"))
            }
            Button {
                onAddPort()
            } label: {
                Image(systemName: "plus.circle.fill")
                    .foregroundStyle(Color.accentColor)
            }
            .accessibilityLabel(String(localized: "Hafen hinzufügen"))
        }
    }

    private var emptyRouteHint: some View {
        Text("Noch keine Häfen hinzugefügt")
            .font(.subheadline)
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, alignment: .center)
            .padding(.vertical, 20)
    }

    private func stopCard(
        for port: Port,
        entries: [JournalEntry],
        defaults: RouteCollapseDefaults
    ) -> some View {
        RouteStopCard(
            port: port,
            pinType: PortPinType(
                isSeaDay: port.isSeaDay,
                isFirst: port.sortOrder == firstPortSortOrder,
                isLast: port.sortOrder == lastPortSortOrder
            ),
            isExpanded: collapseState.isExpanded(stopID: port.id, defaults: defaults),
            entries: entries,
            onToggle: { toggle(stopID: port.id) },
            onSelectPort: { onSelectPort(port) },
            onDeletePort: { onDeletePort(port) },
            onOpenEntry: onOpenEntry,
            onAddEntry: { onAddEntry(port) }
        )
    }

    // MARK: - Klapp-Zustand

    private var collapseDefaults: RouteCollapseDefaults {
        RouteCollapseDefaults.make(
            stops: stopInputs,
            today: todayAnchor,
            startDate: cruise.startDate,
            endDate: cruise.endDate
        )
    }

    private var isEverythingExpanded: Bool {
        let defaults = collapseDefaults
        return !stopInputs.isEmpty && stopInputs.allSatisfy {
            collapseState.isExpanded(stopID: $0.id, defaults: defaults)
        }
    }

    private func toggle(stopID: UUID) {
        let defaults = collapseDefaults
        withAnimation(.easeInOut(duration: 0.2)) {
            collapseState.toggle(stopID: stopID, defaults: defaults)
        }
    }

    private func toggleAll() {
        let stopIDs = stopInputs.map(\.id)
        let shouldCollapse = isEverythingExpanded
        withAnimation(.easeInOut(duration: 0.2)) {
            if shouldCollapse {
                collapseState.collapseAll(stopIDs: stopIDs)
            } else {
                collapseState.expandAll(stopIDs: stopIDs)
            }
        }
    }

    /// Tageswechsel: Defaults neu berechnen **und** alle Übersteuerungen löschen —
    /// sonst hielte eine gestrige Übersteuerung den neuen aktiven Tag zu
    /// (J3neu (b), Ereignis-Tabelle).
    private func refreshIfDayChanged() {
        let now = Date()
        guard RouteDayKey.localDay(now) != RouteDayKey.localDay(todayAnchor) else { return }
        todayAnchor = now
        collapseState.resetForDayChange()
    }

    /// `NSCalendarDayChanged` wird nicht garantiert auf dem Main-Thread
    /// zugestellt; `@State` darf nur dort geändert werden.
    private var dayChangePublisher: AnyPublisher<Notification, Never> {
        NotificationCenter.default
            .publisher(for: .NSCalendarDayChanged)
            .receive(on: RunLoop.main)
            .eraseToAnyPublisher()
    }

    // MARK: - Zuordnung (Rand-Mapping auf die T8a-Planer)

    private var sortedPorts: [Port] {
        cruise.route.sorted { $0.sortOrder < $1.sortOrder }
    }

    /// `@Model`-Objekte bleiben außerhalb der Planer — hier wird auf Werte gemappt.
    private var stopInputs: [RouteStopInput] {
        sortedPorts.map {
            RouteStopInput(id: $0.id, sortOrder: $0.sortOrder, arrival: $0.arrival)
        }
    }

    private var firstPortSortOrder: Int? {
        sortedPorts.first { !$0.isSeaDay }?.sortOrder
    }

    private var lastPortSortOrder: Int? {
        sortedPorts.last { !$0.isSeaDay }?.sortOrder
    }

    private struct JournalLayout {
        let entriesByStopID: [UUID: [JournalEntry]]
        let extraEntries: [JournalEntry]
    }

    /// Einmal pro `body`-Durchlauf berechnet und an die Stopps verteilt.
    private var journalLayout: JournalLayout {
        let entries = cruise.journalEntries
        let entriesByID = Dictionary(
            entries.map { ($0.id, $0) },
            uniquingKeysWith: { lhs, _ in lhs }
        )
        let assignment = RouteJournalPlanner.assign(
            entries: entries.map {
                JournalEntryInput(
                    id: $0.id,
                    portID: $0.port?.id,
                    entryDate: $0.entryDate,
                    createdAt: $0.createdAt
                )
            },
            stops: stopInputs
        )
        return JournalLayout(
            entriesByStopID: assignment.entryIDsByStopID.mapValues { ids in
                ids.compactMap { entriesByID[$0] }
            },
            extraEntries: assignment.unassignedEntryIDs.compactMap { entriesByID[$0] }
        )
    }
}
