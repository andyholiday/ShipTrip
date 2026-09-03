//
//  RectangularWidgetView.swift
//  ShipTripWidget
//
//  Familie `accessoryRectangular` (Sperrbildschirm): zwei bis drei Zeilen,
//  monochrom. Die erste Zeile ist `widgetAccentable`, damit sie die
//  Tint-Farbe des Sperrbildschirms annimmt.
//
//  Kuerzung: die Kachel waechst nicht mit dem Schriftgrad — 172×76 pt sind
//  fest, abzueglich Rand bleiben rund 156×60 pt. Gemessen (Belegbilder K2)
//  passen darin genau vier Textzeilen der Groesse „L". Der Pflichtinhalt des
//  aktiven Zustands (aktueller Stopp, seine Zeiten, Ausblick auf den
//  naechsten Stopp bzw. Seetag) braucht sie alle vier.
//
//  Deshalb ist der Schriftgrad hier nach oben bei `.large` gedeckelt: ab
//  Dynamic Type XXL fiel zuvor der Ausblick weg und die Kopfzeile brach mit
//  „…" ab — beides verletzt ZIEL K2. Kleinere Schriftgrade wirken weiter.
//  Der volle Wortlaut bleibt ueber `accessibilityLabel` erreichbar, also
//  genau auf dem Weg, den ein Nutzer mit sehr grossem Schriftgrad ohnehin
//  nutzt. Hafennamen laufen ausserdem ueber `shortStopName` — alles ab dem
//  ersten Trennzeichen faellt weg, statt abgeschnitten zu werden.
//

import SwiftUI
import WidgetKit

struct RectangularWidgetView: View {

    let state: WidgetState

    var body: some View {
        VStack(alignment: .leading, spacing: 1) {
            content
        }
        .dynamicTypeSize(...DynamicTypeSize.large)
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
            secondary(WidgetFormatting.day(info.startDate), lines: 2)
        case .idle(let info):
            headline(symbol: WidgetSymbol.idle, text: WidgetFormatting.noPlannedCruise)
            if let days = info.daysSinceLastCruise {
                secondary(WidgetFormatting.lastCruise(daysSince: days), lines: 2)
            } else {
                secondary(WidgetFormatting.noCruiseAtAll, lines: 2)
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
            nextLine(info)
        } else if let next = info.nextStop {
            headline(symbol: WidgetSymbol.embarkation, text: WidgetFormatting.embarkation)
            secondary(WidgetFormatting.nextStopLineShort(next), lines: 2)
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

    /// `minimumScaleFactor` liegt bei 0,5: ein Hafenname wie „Puerto de la
    /// Cruz de Tenerife" braucht in den ~139 pt Textbreite rund 8,5 pt
    /// Schriftgrad. Mit 0,6 endete die Zeile mit „…" (ZIEL K2).
    private func headline(symbol: String, text: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 3) {
            Image(systemName: symbol)
                .font(.caption2)
                .accessibilityHidden(true)
            Text(text)
                .font(.headline)
                .lineLimit(1)
                .minimumScaleFactor(0.5)
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
