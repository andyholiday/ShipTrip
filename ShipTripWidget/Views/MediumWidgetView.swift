//
//  MediumWidgetView.swift
//  ShipTripWidget
//
//  Familie `systemMedium`: zweispaltig — links der aktuelle Stopp, rechts der
//  naechste. Reisen ohne Route und die uebrigen Zustaende bleiben einspaltig.
//
//  Kuerzung bei grossem Schriftgrad: ab Dynamic Type XXL entfallen die
//  Spaltenueberschriften; der Platz geht an die Namen (dritte Zeile).
//

import SwiftUI

struct MediumWidgetView: View {

    @Environment(\.dynamicTypeSize) private var typeSize

    let state: WidgetState

    private var isTight: Bool { typeSize >= .xxLarge }
    private var nameLines: Int { isTight ? 3 : 2 }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
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
            single(symbol: WidgetSymbol.unavailable, text: WidgetFormatting.unavailable)
        }
    }

    // MARK: - Aktiv

    @ViewBuilder
    private func activeContent(_ info: ActiveInfo) -> some View {
        WidgetCaption(text: info.title)

        if info.currentStop == nil && info.nextStop == nil {
            // Reise ohne Route: Titel + Schiff + Zeitraum.
            WidgetHeadline(symbol: WidgetSymbol.ship, text: info.ship, lineLimit: nameLines)
            WidgetCaption(
                text: WidgetFormatting.dateRange(from: info.cruiseStart, to: info.cruiseEnd)
            )
        } else {
            HStack(alignment: .top, spacing: 10) {
                currentColumn(info)
                Divider()
                nextColumn(info)
            }
        }

        Spacer(minLength: 0)
    }

    @ViewBuilder
    private func currentColumn(_ info: ActiveInfo) -> some View {
        if let current = info.currentStop {
            column(
                label: WidgetFormatting.currentLabel,
                symbol: WidgetSymbol.stop(current),
                title: WidgetFormatting.stopName(current),
                detail: WidgetFormatting.stopDetail(current)
            )
        } else {
            column(
                label: WidgetFormatting.currentLabel,
                symbol: WidgetSymbol.embarkation,
                title: WidgetFormatting.embarkation,
                detail: WidgetFormatting.day(info.cruiseStart)
            )
        }
    }

    @ViewBuilder
    private func nextColumn(_ info: ActiveInfo) -> some View {
        if let next = info.nextStop {
            column(
                label: WidgetFormatting.nextStopLabel,
                symbol: WidgetSymbol.stop(next),
                title: WidgetFormatting.stopName(next),
                detail: WidgetFormatting.day(next.day)
            )
        } else {
            column(
                label: WidgetFormatting.nextStopLabel,
                symbol: WidgetSymbol.cruiseEnd,
                title: WidgetFormatting.cruiseEndLine(info.cruiseEnd),
                detail: nil
            )
        }
    }

    // MARK: - Countdown

    @ViewBuilder
    private func countdownContent(_ info: CountdownInfo) -> some View {
        WidgetCaption(text: info.title)
        HStack(alignment: .top, spacing: 10) {
            column(
                label: WidgetFormatting.currentLabel,
                symbol: WidgetSymbol.ship,
                title: info.ship,
                detail: WidgetFormatting.day(info.startDate)
            )
            Divider()
            Text(WidgetFormatting.countdown(daysUntilStart: info.daysUntilStart))
                .font(.title3.weight(.semibold))
                .lineLimit(3)
                .minimumScaleFactor(0.7)
                .truncationMode(.tail)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        Spacer(minLength: 0)
    }

    // MARK: - Leerlauf

    @ViewBuilder
    private func idleContent(_ info: IdleInfo) -> some View {
        if let days = info.daysSinceLastCruise {
            WidgetHeadline(symbol: WidgetSymbol.idle, text: WidgetFormatting.noPlannedCruise)
            WidgetCaption(text: WidgetFormatting.lastCruise(daysSince: days), lines: 2)
            Spacer(minLength: 0)
        } else {
            single(symbol: WidgetSymbol.idle, text: WidgetFormatting.noCruiseAtAll)
        }
    }

    // MARK: - Bausteine

    @ViewBuilder
    private func column(
        label: String,
        symbol: String,
        title: String,
        detail: String?
    ) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            if !isTight {
                WidgetCaption(text: label)
            }
            WidgetHeadline(symbol: symbol, text: title, lineLimit: nameLines)
            if let detail {
                WidgetCaption(text: detail, lines: 2)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func single(symbol: String, text: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 6) {
            Image(systemName: symbol)
                .font(.title3)
                .foregroundStyle(WidgetStyle.accent)
                .accessibilityHidden(true)
            Text(text)
                .font(.headline)
                .lineLimit(3)
                .minimumScaleFactor(0.7)
                .truncationMode(.tail)
            Spacer(minLength: 0)
        }
    }
}
