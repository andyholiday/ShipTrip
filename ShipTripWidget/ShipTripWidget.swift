//
//  ShipTripWidget.swift
//  ShipTripWidget
//
//  Geruest des Home-Screen-Widgets (Taskplan 1.9.0, LE 1). Der Provider liest
//  den Snapshot aus dem App-Group-Container ueber `WidgetSnapshotStore` aus
//  `ShipTrip/WidgetShared/`; die App wird nicht importiert.
//
//  - Important: Die Ansicht ist ein Platzhalter, der lediglich den Ladezustand
//    sichtbar macht. Die eigentlichen Layouts entstehen in T4.
//

import SwiftUI
import WidgetKit

// MARK: - Eintrag

/// Ein Zeitpunkt der Timeline samt dem, was zu diesem Zeitpunkt aus dem
/// Container gelesen wurde.
struct ShipTripWidgetEntry: TimelineEntry {
    let date: Date
    let loadResult: WidgetSnapshotLoadResult
}

// MARK: - Provider

/// Liest den Snapshot bei jeder Anfrage neu. Koaleszierung und Neuladen
/// steuert die App-Seite ueber `WidgetCenter`.
struct ShipTripWidgetProvider: TimelineProvider {

    func placeholder(in context: Context) -> ShipTripWidgetEntry {
        ShipTripWidgetEntry(date: Date(), loadResult: .missing)
    }

    func getSnapshot(in context: Context, completion: @escaping (ShipTripWidgetEntry) -> Void) {
        completion(Self.currentEntry())
    }

    func getTimeline(
        in context: Context,
        completion: @escaping (Timeline<ShipTripWidgetEntry>) -> Void
    ) {
        completion(Timeline(entries: [Self.currentEntry()], policy: .never))
    }

    /// Liest den aktuellen Stand. Fehlt das App-Group-Entitlement, faellt der
    /// Pfad auf das temporaere Verzeichnis zurueck — dort liegt nie eine
    /// Datei, das Ergebnis ist also `.missing` statt eines Absturzes.
    private static func currentEntry() -> ShipTripWidgetEntry {
        let container = WidgetSnapshotStore.appGroupURL()
            ?? URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
        let store = WidgetSnapshotStore(containerURL: container)
        return ShipTripWidgetEntry(date: Date(), loadResult: store.load())
    }
}

// MARK: - Platzhalter-Ansicht

/// Zeigt nur, ob und wann ein Snapshot geschrieben wurde. Bewusst ohne
/// Lokalisierung und ohne Gestaltung — beides kommt mit den echten Layouts.
struct ShipTripWidgetPlaceholderView: View {

    let entry: ShipTripWidgetEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(verbatim: "ShipTrip")
                .font(.caption.bold())
            Text(verbatim: statusText)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
    }

    private var statusText: String {
        switch entry.loadResult {
        case .snapshot(let snapshot):
            return snapshot.generatedAt.formatted(date: .numeric, time: .shortened)
        case .missing:
            return "missing"
        case .unreadable:
            return "unreadable"
        }
    }
}

// MARK: - Widget

struct ShipTripWidget: Widget {

    static let kind = "ShipTripWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: Self.kind, provider: ShipTripWidgetProvider()) { entry in
            ShipTripWidgetPlaceholderView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName(Text(verbatim: "ShipTrip"))
        .description(Text(verbatim: "Reisestatus auf dem Home-Bildschirm."))
        .supportedFamilies([.systemSmall, .systemMedium, .accessoryRectangular, .accessoryCircular])
    }
}
