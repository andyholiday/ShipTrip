//
//  CircularWidgetView.swift
//  ShipTripWidget
//
//  Familie `accessoryCircular` (Sperrbildschirm): ein Symbol und hoechstens
//  ein Kurzwert. Mehr passt in den Kreis nicht ohne Abschneiden.
//
//  Zuordnung: Seetag → Wellen, Hafen → Faehre plus Abfahrtszeit, Countdown →
//  Segel plus Anzahl Tage (ueber 99 als „99+"), Leerlauf → Anker,
//  nicht verfuegbar → Aktualisieren-Pfeil.
//
//  - Note: Im aktiven Zustand steht die Abfahrtszeit statt einer Tageszahl.
//    `ActiveInfo` fuehrt bewusst keinen vorberechneten Tageswert, und in der
//    Ansicht darf nicht mit einem `Calendar` gerechnet werden.
//

import SwiftUI
import WidgetKit

struct CircularWidgetView: View {

    let state: WidgetState

    var body: some View {
        ZStack {
            AccessoryWidgetBackground()
            VStack(spacing: 0) {
                Image(systemName: symbol)
                    .font(value == nil ? Font.title2 : Font.caption)
                if let value {
                    Text(value)
                        .font(.caption.weight(.semibold))
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                }
            }
            .padding(2)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(WidgetFormatting.accessibilityLabel(for: state))
    }

    // MARK: - Inhalt

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

    /// Kurzwert; `nil`, wenn nur das Symbol steht.
    private var value: String? {
        switch state {
        case .active(let info):
            // Am Seetag steht das Wellensymbol fuer sich allein.
            guard let current = info.currentStop, !current.isSeaDay,
                  let departure = current.departure else { return nil }
            return WidgetFormatting.time(departure)
        case .countdown(let info):
            return WidgetFormatting.shortCount(info.daysUntilStart)
        case .idle, .unavailable:
            return nil
        }
    }
}
