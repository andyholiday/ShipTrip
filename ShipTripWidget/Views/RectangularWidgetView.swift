//
//  RectangularWidgetView.swift
//  ShipTripWidget
//
//  Familie `accessoryRectangular` (Sperrbildschirm) in der Richtung
//  „Dynamic Instrument": links das Ring-Instrument als Motiv, rechts die
//  Hierarchie des Kleinformats. Keine eigenen Farben — der Sperrbildschirm
//  toent selbst; die Kopfzeile ist `widgetAccentable`.
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
        HStack(alignment: .center, spacing: 5) {
            ring
            VStack(alignment: .leading, spacing: 1) {
                content
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        }
        .dynamicTypeSize(...DynamicTypeSize.large)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(WidgetFormatting.accessibilityLabel(for: state))
    }

    // MARK: - Motiv

    /// Das Ring-Instrument, hier bewusst klein: die 26 pt nimmt es dem Text
    /// weg, der auf dieser Kachel Vorrang hat (ZIEL K2).
    private var ring: some View {
        WidgetRing(
            symbol: symbol,
            progress: progress,
            diameter: 26,
            lineWidth: 3.5,
            monochrome: true
        )
        .widgetAccentable()
    }

    private var symbol: String {
        switch state {
        case .active(let info):
            guard let current = info.currentStop else { return WidgetSymbol.ship }
            return WidgetSymbol.stop(current)
        case .countdown:
            return WidgetSymbol.ship
        case .idle:
            return WidgetSymbol.idle
        case .unavailable:
            return WidgetSymbol.unavailable
        }
    }

    private var progress: Double? {
        guard case .active(let info) = state, let current = info.currentStop else { return nil }
        return WidgetProgress.elapsed(current)
    }

    // MARK: - Inhalt

    @ViewBuilder
    private var content: some View {
        switch state {
        case .active(let info):
            activeContent(info)
        case .countdown(let info):
            headline(info.ship)
            secondary(WidgetFormatting.countdown(daysUntilStart: info.daysUntilStart))
            secondary(WidgetFormatting.day(info.startDate), lines: 2)
        case .idle(let info):
            headline(WidgetFormatting.noPlannedCruise)
            if let days = info.daysSinceLastCruise {
                secondary(WidgetFormatting.lastCruise(daysSince: days), lines: 2)
            } else {
                secondary(WidgetFormatting.noCruiseAtAll, lines: 2)
            }
        case .unavailable:
            headline(WidgetFormatting.unavailable)
        }
    }

    // MARK: - Aktiv

    @ViewBuilder
    private func activeContent(_ info: ActiveInfo) -> some View {
        if let current = info.currentStop {
            headline(WidgetFormatting.shortStopName(current))
            secondary(WidgetFormatting.stopDetailCompact(current))
            nextLine(info)
        } else if let next = info.nextStop {
            headline(WidgetFormatting.embarkation)
            secondary(WidgetFormatting.nextStopLineShort(next), lines: 2)
        } else {
            headline(info.ship)
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

    /// `minimumScaleFactor` liegt bei 0,45: ein Hafenname wie „Puerto de la
    /// Cruz de Tenerife" braucht in den nun rund 126 pt Textbreite (der Ring
    /// nimmt 26 pt) knapp 8 pt Schriftgrad. Mit 0,5 endete die Zeile mit „…"
    /// (ZIEL K2).
    private func headline(_ text: String) -> some View {
        Text(text)
            .font(.headline)
            .lineLimit(1)
            .minimumScaleFactor(0.45)
            .truncationMode(.tail)
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
