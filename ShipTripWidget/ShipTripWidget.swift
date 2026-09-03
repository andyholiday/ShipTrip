//
//  ShipTripWidget.swift
//  ShipTripWidget
//
//  Provider und Konfiguration des Home-Screen-Widgets (Taskplan 1.9.0, T4).
//  Der Provider liest den Snapshot ueber `WidgetSnapshotStore` aus dem
//  App-Group-Container, leitet den Zustand mit `WidgetStateResolver` ab und
//  legt fuer jeden von `WidgetTimelinePlanner` geplanten Zeitpunkt einen
//  eigenen Eintrag an. Die App wird nicht importiert.
//
//  - Note: `Calendar.autoupdatingCurrent` kommt ausschliesslich hier vor —
//    die Ansichten bekommen fertig abgeleitete Werte.
//

import SwiftUI
import WidgetKit

// MARK: - Eintrag

/// Ein Zeitpunkt der Timeline samt dem Zustand, der zu genau diesem Zeitpunkt
/// gilt.
struct ShipTripWidgetEntry: TimelineEntry, Sendable {
    let date: Date
    let state: WidgetState
}

// MARK: - Provider

struct ShipTripWidgetProvider: TimelineProvider {

    // Hinweis: `TimelineProvider` verlangt die Completion-Varianten; die
    // async-Schreibweisen `snapshot(in:)`/`timeline(in:)` sind Erweiterungen,
    // die auf genau diese Methoden weiterleiten.

    func placeholder(in context: Context) -> ShipTripWidgetEntry {
        Self.sampleEntry
    }

    func getSnapshot(in context: Context, completion: @escaping (ShipTripWidgetEntry) -> Void) {
        completion(context.isPreview ? Self.sampleEntry : Self.currentEntry())
    }

    func getTimeline(
        in context: Context,
        completion: @escaping (Timeline<ShipTripWidgetEntry>) -> Void
    ) {
        let load = Self.loadResult()
        let now = Date()
        let calendar = Calendar.autoupdatingCurrent
        let state = WidgetStateResolver.resolve(load, now: now, calendar: calendar)

        let entries = WidgetTimelinePlanner
            .entryDates(for: state, now: now, calendar: calendar)
            .map { date in
                ShipTripWidgetEntry(
                    date: date,
                    state: WidgetStateResolver.resolve(load, now: date, calendar: calendar)
                )
            }

        guard let last = entries.last else {
            let fallback = ShipTripWidgetEntry(date: now, state: state)
            completion(Timeline(entries: [fallback], policy: .after(now.addingTimeInterval(3600))))
            return
        }
        completion(Timeline(entries: entries, policy: .after(last.date)))
    }

    // MARK: Lesen

    /// Liest den Snapshot. Fehlt das App-Group-Entitlement, faellt der Pfad
    /// auf das temporaere Verzeichnis zurueck — dort liegt nie eine Datei,
    /// das Ergebnis ist also `.missing` statt eines Absturzes.
    private static func loadResult() -> WidgetSnapshotLoadResult {
        let container = WidgetSnapshotStore.appGroupURL()
            ?? URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
        return WidgetSnapshotStore(containerURL: container).load()
    }

    private static func currentEntry() -> ShipTripWidgetEntry {
        let now = Date()
        return ShipTripWidgetEntry(
            date: now,
            state: WidgetStateResolver.resolve(
                loadResult(),
                now: now,
                calendar: .autoupdatingCurrent
            )
        )
    }

    /// Beispielstand fuer Platzhalter und Widget-Galerie: ein Countdown.
    /// WidgetKit zeichnet den Platzhalter selbst geschwaerzt (`redacted`).
    static var sampleEntry: ShipTripWidgetEntry {
        let now = Date()
        return ShipTripWidgetEntry(
            date: now,
            state: .countdown(CountdownInfo(
                title: WidgetFormatting.sampleTitle,
                ship: "Mein Schiff 4",
                startDate: now.addingTimeInterval(12 * 86_400),
                daysUntilStart: 12
            ))
        )
    }
}

// MARK: - Widget

struct ShipTripWidget: Widget {

    static let kind = "ShipTripWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: Self.kind, provider: ShipTripWidgetProvider()) { entry in
            ShipTripWidgetEntryView(entry: entry)
        }
        .configurationDisplayName(Text(WidgetFormatting.displayName))
        .description(Text(WidgetFormatting.widgetDescription))
        .supportedFamilies([.systemSmall, .systemMedium, .accessoryRectangular, .accessoryCircular])
    }
}
