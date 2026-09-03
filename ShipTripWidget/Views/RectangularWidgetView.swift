//
//  RectangularWidgetView.swift
//  ShipTripWidget
//
//  Familie `accessoryRectangular` (Sperrbildschirm): zwei bis drei Zeilen,
//  monochrom. Die erste Zeile ist `widgetAccentable`, damit sie die
//  Tint-Farbe des Sperrbildschirms annimmt.
//
//  Kuerzung: die Kachel waechst nicht mit dem Schriftgrad. Ab Dynamic Type
//  XXL entfaellt deshalb die dritte Zeile (Ausblick); Hafennamen laufen hier
//  ausserdem ueber `shortStopName` — alles ab dem ersten Trennzeichen faellt
//  weg, statt mit „…" abzuschneiden.
//

import SwiftUI
import WidgetKit

struct RectangularWidgetView: View {

    @Environment(\.dynamicTypeSize) private var typeSize

    let state: WidgetState

    private var isTight: Bool { typeSize >= .xxLarge }

    var body: some View {
        VStack(alignment: .leading, spacing: 1) {
            content
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(WidgetFormatting.accessibilityLabel(for: state))
    }

    @ViewBuilder
    private var content: some View {
        switch state {
        case .active(let info):
            activeContent(info)
        case .countdown(let info):
            headline(symbol: WidgetSymbol.ship, text: info.ship)
            secondary(WidgetFormatting.countdown(daysUntilStart: info.daysUntilStart))
            if !isTight {
                secondary(WidgetFormatting.day(info.startDate), lines: 2)
            }
        case .idle(let info):
            headline(symbol: WidgetSymbol.idle, text: WidgetFormatting.noPlannedCruise)
            if let days = info.daysSinceLastCruise {
                secondary(WidgetFormatting.lastCruise(daysSince: days), lines: isTight ? 1 : 2)
            } else {
                secondary(WidgetFormatting.noCruiseAtAll, lines: isTight ? 1 : 2)
            }
        case .unavailable:
            headline(symbol: WidgetSymbol.unavailable, text: WidgetFormatting.unavailable)
        }
    }

    // MARK: - Aktiv

    @ViewBuilder
    private func activeContent(_ info: ActiveInfo) -> some View {
        if let current = info.currentStop {
            headline(
                symbol: WidgetSymbol.stop(current),
                text: WidgetFormatting.shortStopName(current)
            )
            secondary(WidgetFormatting.stopDetailCompact(current))
            if !isTight {
                nextLine(info)
            }
        } else if let next = info.nextStop {
            headline(symbol: WidgetSymbol.embarkation, text: WidgetFormatting.embarkation)
            secondary(WidgetFormatting.nextStopLineShort(next), lines: isTight ? 1 : 2)
        } else {
            headline(symbol: WidgetSymbol.ship, text: info.ship)
            secondary(WidgetFormatting.dateRange(from: info.cruiseStart, to: info.cruiseEnd))
        }
    }

    @ViewBuilder
    private func nextLine(_ info: ActiveInfo) -> some View {
        if let next = info.nextStop {
            secondary(WidgetFormatting.nextStopLineShort(next), lines: 2)
        } else if info.isAfterLastStop {
            secondary(WidgetFormatting.cruiseEndLine(info.cruiseEnd), lines: 2)
        }
    }

    // MARK: - Bausteine

    private func headline(symbol: String, text: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 3) {
            Image(systemName: symbol)
                .font(.caption2)
                .accessibilityHidden(true)
            Text(text)
                .font(.headline)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
                .truncationMode(.tail)
        }
        .widgetAccentable()
    }

    private func secondary(_ text: String, lines: Int = 1) -> some View {
        Text(text)
            .font(.caption2)
            .lineLimit(lines)
            .minimumScaleFactor(0.7)
            .truncationMode(.tail)
    }
}
