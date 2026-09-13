//
//  SmallWidgetView.swift
//  ShipTripWidget
//
//  Familie `systemSmall` in der Richtung „Dynamic Instrument" (Konzept 03):
//  oben das Ring-Instrument mit der aktuellen Uhrzeit, darunter der Name in
//  Weiss, darunter der cyane Wert. Der Grund kommt aus `WidgetStyle.surface`.
//
//  Unter dem Ring bleibt die Hierarchie des Konzepts: Name, darunter der eine
//  cyane Wert, darunter gedaempft Liegezeit und Ausblick. Die Liegezeit steht
//  dafuer immer in der kompakten Form „8:00 – 17:00".
//
//  Kuerzung bei grossem Schriftgrad: ab Dynamic Type XXL entfallen Ring,
//  Uhrzeit und Schmuckzeichen, der Ausblick verliert das Datum. Der so
//  gewonnene Platz geht an den Namen des aktuellen Stopps, damit auch ein
//  adversarial langer Hafenname ohne „…" umbricht — Text hat Vorrang vor Bild.
//
//  Zusaetzlich ist der Schriftgrad wie bei `RectangularWidgetView` nach oben
//  gedeckelt — die Kachel waechst nicht mit, 170×170 pt sind fest. Ohne
//  Deckel blieb bei Dynamic Type XXL von jedem Pflichtfeld nur ein Stummel
//  („Pue…", „Ankunft 8:…", „Nächster…") — Verstoss gegen ZIEL K2. Namen
//  laufen ausserdem ueber `shortStopName`, die Zeiten im engen Fall ueber die
//  kompakte Form „8:00 – 17:00". Der volle Wortlaut bleibt ueber
//  `accessibilityLabel` erreichbar.
//

import SwiftUI

struct SmallWidgetView: View {

    @Environment(\.dynamicTypeSize) private var typeSize

    let state: WidgetState

    private var isTight: Bool { typeSize >= .xxLarge }

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            content
        }
        .dynamicTypeSize(...DynamicTypeSize.xxLarge)
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
            instrumentHeader(symbol: WidgetSymbol.unavailable, progress: nil, title: nil)
            Spacer(minLength: 0)
            WidgetHeadline(text: WidgetFormatting.unavailable, size: 15, lineLimit: 4)
        }
    }

    // MARK: - Aktiv

    @ViewBuilder
    private func activeContent(_ info: ActiveInfo) -> some View {
        if let current = info.currentStop {
            instrumentHeader(
                symbol: WidgetSymbol.stop(current),
                progress: WidgetProgress.elapsed(current),
                title: info.title,
                clock: true
            )
            Spacer(minLength: 0)
            WidgetHeadline(
                text: WidgetFormatting.shortStopName(current),
                size: 17,
                lineLimit: isTight ? 3 : 2
            )
            remaining(current)
            // Immer die kompakte Form „8:00 – 17:00": unter dem Ring sollen
            // moeglichst wenige Nebenzeilen stehen, sonst kippt die Hierarchie
            // aus dem Konzept (Name gross, ein cyaner Wert, Rest gedaempft).
            WidgetCaption(
                text: WidgetFormatting.stopDetailCompact(current),
                lines: isTight ? 2 : 1,
                tint: WidgetStyle.tertiaryText
            )
        } else if info.nextStop != nil {
            instrumentHeader(symbol: WidgetSymbol.embarkation, progress: nil, title: info.title)
            Spacer(minLength: 0)
            WidgetHeadline(text: WidgetFormatting.embarkation, size: 17)
        } else {
            // Reise ohne Route: Titel (oben) + Schiff + Zeitraum.
            instrumentHeader(symbol: WidgetSymbol.ship, progress: nil, title: info.title)
            Spacer(minLength: 0)
            WidgetHeadline(text: info.ship, size: 17, lineLimit: isTight ? 3 : 2)
            WidgetCaption(
                text: WidgetFormatting.dateRange(from: info.cruiseStart, to: info.cruiseEnd),
                lines: 2
            )
        }

        if let next = info.nextStop {
            WidgetCaption(
                text: isTight
                    ? WidgetFormatting.nextStopLineShort(next, compactName: true)
                    : WidgetFormatting.nextStopLine(next, compactName: true),
                lines: 2,
                tint: WidgetStyle.tertiaryText
            )
        } else if info.isAfterLastStop {
            WidgetCaption(
                text: WidgetFormatting.cruiseEndLine(info.cruiseEnd),
                lines: 2,
                tint: WidgetStyle.tertiaryText
            )
        }
    }

    /// Cyane Restzeit im Hafen — live ueber `Text(_:style:)`, weil WidgetKit
    /// die Eintraege vorrendert und ein gerechneter Wert einfrieren wuerde.
    /// Faellt weg, sobald die Abfahrt vorbei ist (`.relative` zaehlt sonst hoch).
    ///
    /// `.relative` statt `.timer`: die Sekundenstelle von `.timer`
    /// („Noch 2:34:43") machte die Zeile fast so breit wie den Hafennamen und
    /// nahm ihm die Fuehrung. Dieselbe Form traegt schon die Fusszeile des
    /// Mittelformats.
    @ViewBuilder
    private func remaining(_ stop: WidgetStopInfo) -> some View {
        if let departure = stop.departure, departure > Date() {
            Text("Noch \(departure, style: .relative)", bundle: WidgetFormatting.bundle)
                .font(.system(size: 12, weight: .semibold))
                .monospacedDigit()
                .foregroundStyle(WidgetStyle.accent)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
    }

    // MARK: - Countdown

    @ViewBuilder
    private func countdownContent(_ info: CountdownInfo) -> some View {
        if !isTight {
            HStack(spacing: 0) {
                Image(systemName: WidgetSymbol.calendar)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(WidgetStyle.accent)
                Spacer(minLength: 0)
                Image(systemName: WidgetSymbol.shipLine)
                    .font(.system(size: 13))
                    .foregroundStyle(WidgetStyle.tertiaryText)
            }
            .accessibilityHidden(true)
            Spacer(minLength: 0)
            WidgetCaption(text: WidgetFormatting.stillLabel, tint: WidgetStyle.tertiaryText)
        }

        if let parts = WidgetFormatting.countdownParts(
            daysUntilStart: info.daysUntilStart,
            dative: false
        ) {
            WidgetNumeral(value: parts.value, unit: parts.unit, size: isTight ? 24 : 32)
        } else {
            WidgetHeadline(
                text: WidgetFormatting.countdown(daysUntilStart: info.daysUntilStart),
                size: isTight ? 18 : 24,
                lineLimit: 2
            )
        }

        WidgetValueLine(text: info.title, size: 13, lines: 2)

        if !isTight {
            Image(systemName: WidgetSymbol.seaDay)
                .font(.system(size: 11))
                .foregroundStyle(WidgetStyle.accent.opacity(0.7))
                .accessibilityHidden(true)
        }

        Spacer(minLength: 0)

        WidgetCaption(text: info.ship, lines: isTight ? 2 : 1)
        WidgetCaption(text: WidgetFormatting.day(info.startDate), tint: WidgetStyle.tertiaryText)
    }

    // MARK: - Leerlauf

    @ViewBuilder
    private func idleContent(_ info: IdleInfo) -> some View {
        if let days = info.daysSinceLastCruise {
            if !isTight {
                Image(systemName: WidgetSymbol.clock)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(WidgetStyle.accent)
                    .accessibilityHidden(true)
                Spacer(minLength: 0)
                WidgetCaption(
                    text: WidgetFormatting.lastCruiseLabel,
                    tint: WidgetStyle.tertiaryText
                )
            }
            WidgetValueLine(
                text: WidgetFormatting.sinceLastCruise(days: days),
                size: isTight ? 16 : 20,
                lines: 2
            )
            if !isTight {
                Image(systemName: WidgetSymbol.idle)
                    .font(.system(size: 13))
                    .foregroundStyle(WidgetStyle.accent)
                    .accessibilityHidden(true)
            }
            if let title = info.lastCruiseTitle {
                WidgetHeadline(text: title, size: 14, lineLimit: 2)
            }
            Spacer(minLength: 0)
            WidgetCaption(
                text: WidgetFormatting.noPlannedCruise,
                lines: 2,
                tint: WidgetStyle.tertiaryText
            )
        } else {
            Image(systemName: WidgetSymbol.idle)
                .font(.system(size: 20))
                .foregroundStyle(WidgetStyle.accent)
                .accessibilityHidden(true)
            Spacer(minLength: 0)
            WidgetHeadline(text: WidgetFormatting.noCruiseAtAll, size: 15, lineLimit: 4)
        }
    }

    // MARK: - Bausteine

    /// Kopfzone: Ring links, rechts Uhrzeit und Reisetitel. Ab Dynamic Type
    /// XXL bleibt nur der Titel — der Ring weicht dem Text.
    @ViewBuilder
    private func instrumentHeader(
        symbol: String,
        progress: Double?,
        title: String?,
        clock: Bool = false
    ) -> some View {
        if isTight {
            if let title {
                WidgetCaption(text: title, lines: 2, tint: WidgetStyle.tertiaryText)
            }
        } else {
            HStack(alignment: .top, spacing: 6) {
                WidgetRing(symbol: symbol, progress: progress, diameter: 52, lineWidth: 5)
                Spacer(minLength: 0)
                VStack(alignment: .trailing, spacing: 2) {
                    if clock {
                        Text(Date(), style: .time)
                            .font(.system(size: 11, weight: .semibold))
                            .monospacedDigit()
                            .foregroundStyle(WidgetStyle.accent)
                    }
                    if let title {
                        Text(title)
                            .font(.caption2)
                            .foregroundStyle(WidgetStyle.tertiaryText)
                            .multilineTextAlignment(.trailing)
                            .lineLimit(2)
                            .minimumScaleFactor(0.7)
                    }
                }
            }
        }
    }
}
