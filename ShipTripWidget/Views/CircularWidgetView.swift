//
//  CircularWidgetView.swift
//  ShipTripWidget
//
//  Familie `accessoryCircular` (Sperrbildschirm) in der Richtung
//  „Dynamic Instrument": der Kreis *ist* das Ring-Instrument. Aussen der
//  Fortschritt der Liegezeit, innen Symbol und Kurzwert. Mehr passt in den
//  Kreis nicht ohne Abschneiden.
//
//  Zuordnung: Seetag → Wellen, Hafen → Faehre plus Abfahrtszeit, Countdown →
//  gefuelltes Segelboot plus Anzahl Tage (ueber 99 als „99+"), Leerlauf →
//  Insel, nicht verfuegbar → Aktualisieren-Pfeil.
//
//  Der Kreis misst feste 76 pt und waechst mit dem Schriftgrad nicht mit;
//  deshalb ist der Schriftgrad hier bei `.large` gedeckelt. Ohne Deckel stiess
//  bei Dynamic Type XXL der Kurzwert an die Kreiskante („17:…", ZIEL K2). Der
//  Innenabstand von 10 pt haelt Symbol und Wert von der Ringspur fern, die in
//  jedem Zustand steht.
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

            // Die Ringspur steht in jedem Zustand — ohne sie fehlte dem
            // Countdown und dem Leerlauf das Leitmotiv der Richtung.
            Circle()
                .stroke(Color.primary.opacity(0.25), lineWidth: 4)

            if let progress {
                Circle()
                    .trim(from: 0, to: max(0.02, min(1, progress)))
                    .stroke(style: StrokeStyle(lineWidth: 4, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .foregroundStyle(.primary)
                    .widgetAccentable()
            }

            VStack(spacing: 0) {
                Image(systemName: symbol)
                    .font(value == nil ? Font.title2 : Font.caption)
                if let value {
                    Text(value)
                        .font(.caption.weight(.semibold))
                        .monospacedDigit()
                        .lineLimit(1)
                        .minimumScaleFactor(0.5)
                }
            }
            .padding(10)
        }
        .dynamicTypeSize(...DynamicTypeSize.large)
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

    /// Anteil, den der Ring zeigt. Aktiv: die verstrichene Liegezeit.
    /// Countdown: der bereits vergangene Teil des letzten Monats vor der
    /// Abfahrt, damit der Ring in den Tagen davor sichtbar zulaeuft.
    /// Leerlauf: ein geschlossener Ring — die Reise liegt hinter uns. Nur im
    /// Fehlerfall bleibt der Kreis bei der blossen Ringspur.
    private var progress: Double? {
        switch state {
        case .active(let info):
            guard let current = info.currentStop else { return nil }
            return WidgetProgress.elapsed(current)
        case .countdown(let info):
            return 1 - min(1, Double(max(0, info.daysUntilStart)) / countdownRingSpan)
        case .idle:
            return 1
        case .unavailable:
            return nil
        }
    }

    /// Zeitraum, ueber den sich der Countdown-Ring fuellt.
    private let countdownRingSpan: Double = 30

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
