//
//  SmallWidgetView.swift
//  ShipTripWidget
//
//  Familie `systemSmall`: hoechstens drei Zeilen-Gruppen — Reisetitel,
//  aktueller Wert, Ausblick.
//
//  Kuerzung bei grossem Schriftgrad: ab Dynamic Type XXL entfaellt die
//  Titelzeile und der Ausblick verliert das Datum. Der so gewonnene Platz
//  geht an den Namen des aktuellen Stopps (dritte Zeile), damit auch ein
//  adversarial langer Hafenname ohne „…" umbricht.
//

import SwiftUI

struct SmallWidgetView: View {

    @Environment(\.dynamicTypeSize) private var typeSize

    let state: WidgetState

    private var isTight: Bool { typeSize >= .xxLarge }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            content
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(WidgetFormatting.accessibilityLabel(for: state))
    }

    @ViewBuilder
    private var content: some View {
        switch state {
        case .active(let info):
            activeContent(info)
        case .countdown(let info):
            countdownContent(info)
        case .idle(let info):
            idleContent(info)
        case .unavailable:
            centered(symbol: WidgetSymbol.unavailable, text: WidgetFormatting.unavailable)
        }
    }

    // MARK: - Aktiv

    @ViewBuilder
    private func activeContent(_ info: ActiveInfo) -> some View {
        if !isTight {
            WidgetCaption(text: info.title)
        }

        if let current = info.currentStop {
            WidgetHeadline(
                symbol: WidgetSymbol.stop(current),
                text: WidgetFormatting.stopName(current),
                lineLimit: isTight ? 3 : 2
            )
            WidgetCaption(text: WidgetFormatting.stopDetail(current), lines: 2)
        } else if info.nextStop != nil {
            WidgetHeadline(symbol: WidgetSymbol.embarkation, text: WidgetFormatting.embarkation)
        } else {
            // Reise ohne Route: Titel (oben) + Schiff + Zeitraum.
            WidgetHeadline(symbol: WidgetSymbol.ship, text: info.ship)
            WidgetCaption(
                text: WidgetFormatting.dateRange(from: info.cruiseStart, to: info.cruiseEnd),
                lines: 2
            )
        }

        Spacer(minLength: 0)

        if let next = info.nextStop {
            WidgetCaption(
                text: isTight
                    ? WidgetFormatting.nextStopLineShort(next)
                    : WidgetFormatting.nextStopLine(next),
                lines: 2
            )
        } else if info.isAfterLastStop {
            WidgetCaption(text: WidgetFormatting.cruiseEndLine(info.cruiseEnd), lines: 2)
        }
    }

    // MARK: - Countdown

    @ViewBuilder
    private func countdownContent(_ info: CountdownInfo) -> some View {
        if !isTight {
            WidgetCaption(text: info.title)
        }
        Text(WidgetFormatting.countdown(daysUntilStart: info.daysUntilStart))
            .font(.title3.weight(.semibold))
            .lineLimit(2)
            .minimumScaleFactor(0.7)
            .truncationMode(.tail)

        Spacer(minLength: 0)

        WidgetHeadline(symbol: WidgetSymbol.ship, text: info.ship, lineLimit: isTight ? 2 : 1)
        WidgetCaption(text: WidgetFormatting.day(info.startDate))
    }

    // MARK: - Leerlauf

    @ViewBuilder
    private func idleContent(_ info: IdleInfo) -> some View {
        if let days = info.daysSinceLastCruise {
            WidgetHeadline(symbol: WidgetSymbol.idle, text: WidgetFormatting.noPlannedCruise)
            Spacer(minLength: 0)
            WidgetCaption(text: WidgetFormatting.lastCruise(daysSince: days), lines: 3)
        } else {
            centered(symbol: WidgetSymbol.idle, text: WidgetFormatting.noCruiseAtAll)
        }
    }

    // MARK: - Bausteine

    private func centered(symbol: String, text: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Image(systemName: symbol)
                .font(.title3)
                .foregroundStyle(WidgetStyle.accent)
                .accessibilityHidden(true)
            Text(text)
                .font(.subheadline.weight(.semibold))
                .lineLimit(4)
                .minimumScaleFactor(0.7)
                .truncationMode(.tail)
        }
    }
}
