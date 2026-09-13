//
//  MediumWidgetView.swift
//  ShipTripWidget
//
//  Familie `systemMedium` in der Richtung „Dynamic Instrument" (Konzept 03).
//
//  Aktiv: links das Ring-Instrument mit dem aktuellen Hafen, rechts Datum und
//  Ausblick, darunter die cyane Zeitleiste von Ankunft ueber jetzt bis
//  Abfahrt, unten die Restzeit im Hafen. Hinter allem eine stark gedaempfte
//  Schiffssilhouette (`WidgetShipGhost`). Die Kopfzeile teilt sich rund 60:40
//  zwischen Ring-plus-Name und dem Datumsblock; der Name hat Vorrang.
//
//  Countdown: links die grosse cyane Zahl mit Reisetitel, Schiff und Abfahrt,
//  rechts das kreisrunde Reisebild (`WidgetShipHero`) mit feinem cyanem Ring.
//
//  Kuerzung bei grossem Schriftgrad: ab Dynamic Type XXL entfallen Ring,
//  Bilder und der Balken der Zeitleiste — Text hat Vorrang. Der Ausblick
//  wandert dann aus der schmalen Kopfspalte auf die volle Breite, der
//  Reisetitel darf zweizeilig werden; beide brachen sonst mit „…" ab.
//
//  Der Schriftgrad ist wie bei
//  `RectangularWidgetView` nach oben gedeckelt; die Kachel waechst nicht mit,
//  364×170 pt sind fest. Ohne Deckel brachen bei Dynamic Type XXL die Namen
//  („Puert…", „Sant…") und die Zeiten („Ankunft 8:0…") ab, was ZIEL K2
//  verletzt. Namen laufen ausserdem ueber `shortStopName`, die Zeiten im
//  engen Fall ueber die kompakte Form „8:00 – 17:00".
//

import SwiftUI

struct MediumWidgetView: View {

    @Environment(\.dynamicTypeSize) private var typeSize

    let state: WidgetState

    private var isTight: Bool { typeSize >= .xxLarge }
    private var nameLines: Int { isTight ? 3 : 2 }

    /// Durchmesser des Leitmotivs im aktiven Zustand. Im Konzeptbild misst der
    /// Ring 42 % der Kachelhoehe (242 von 580 px nachgemessen) — auf 170 pt
    /// Kachel also rund 72 pt. Die uebrigen Zustaende bleiben bei 54 pt.
    private let heroRing: CGFloat = 72

    /// Breite der rechten Kopfspalte im aktiven Zustand. Der Kopf links
    /// bekommt den Rest — rund 60:40 statt der frueheren 45:55, sonst bleibt
    /// dem Ortsnamen neben dem 72-pt-Ring zu wenig Platz. Bei grossem
    /// Schriftgrad faellt die Spalte schmaler aus: dort traegt der Name bis
    /// zu drei Zeilen und braucht die Breite dringender als das Datum.
    private var outlookWidth: CGFloat { isTight ? 100 : 126 }

    var body: some View {
        content
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
            instrument(
                symbol: WidgetSymbol.unavailable,
                progress: nil,
                label: nil,
                title: WidgetFormatting.unavailable,
                detail: nil
            )
        }
    }

    // MARK: - Aktiv

    /// Die Silhouette liegt als `background` hinter dem Text und bestimmt die
    /// Groesse des Blocks nicht mit — als `ZStack`-Geschwister zog sie mit
    /// ihren 150 pt die Kachel ueber die Unterkante hinaus, was den
    /// angeschnittenen Rest am unteren Rand erzeugte.
    @ViewBuilder
    private func activeContent(_ info: ActiveInfo) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            // Kein `Spacer` zwischen den Spalten: er ist unbegrenzt flexibel
            // und nahm dem Ortsnamen — der ueber `minimumScaleFactor` eine
            // sehr kleine Mindestbreite meldet — so viel Breite weg, dass er
            // mit „…" abbrach („Kopenh…"). Stattdessen feste rechte Spalte,
            // der Kopf bekommt den ganzen Rest.
            HStack(alignment: .top, spacing: 12) {
                currentBlock(info)
                    .frame(maxWidth: .infinity, alignment: .leading)
                outlookBlock(info)
            }
            if isTight, let next = info.nextStop {
                // Bei grossem Schriftgrad bekommt der Ausblick die volle
                // Breite statt der schmalen Kopfspalte — dort brach er ab.
                WidgetCaption(
                    text: WidgetFormatting.nextStopLine(next, compactName: true),
                    lines: 2,
                    tint: WidgetStyle.tertiaryText
                )
            }
            Spacer(minLength: 0)
            timelineBlock(info)
            footerBlock(info)
        }
        .background(alignment: .trailing) {
            if !isTight { shipGhost }
        }
    }

    @ViewBuilder
    private func currentBlock(_ info: ActiveInfo) -> some View {
        if let current = info.currentStop {
            instrument(
                symbol: WidgetSymbol.stop(current),
                progress: WidgetProgress.elapsed(current),
                label: WidgetFormatting.currentInLabel,
                title: WidgetFormatting.shortStopName(current),
                detail: current.country ?? info.ship,
                diameter: heroRing
            )
        } else if info.nextStop != nil {
            instrument(
                symbol: WidgetSymbol.embarkation,
                progress: nil,
                label: WidgetFormatting.currentInLabel,
                title: WidgetFormatting.embarkation,
                detail: WidgetFormatting.day(info.cruiseStart),
                diameter: heroRing
            )
        } else {
            // Reise ohne Route: Schiff und Zeitraum tragen die Kachel.
            instrument(
                symbol: WidgetSymbol.ship,
                progress: nil,
                label: info.title,
                title: info.ship,
                detail: WidgetFormatting.dateRange(from: info.cruiseStart, to: info.cruiseEnd)
            )
        }
    }

    /// Rechte Kopfspalte: Datum oben, darunter der Ausblick. Im Konzept sitzt
    /// hier das Wetter — dafuer gibt es in ShipTrip keine Daten, den Platz
    /// bekommt der Pflichtinhalt „Nächster Stopp".
    @ViewBuilder
    private func outlookBlock(_ info: ActiveInfo) -> some View {
        VStack(alignment: .trailing, spacing: 2) {
            // Bei grossem Schriftgrad rein numerisch — die ausgeschriebene
            // Form passt nicht mehr einzeilig in die schmalere Spalte und
            // verlor dort das Jahr („13. September 20…").
            WidgetCaption(
                text: isTight
                    ? WidgetFormatting.dayNumeric(dateForHeader(info))
                    : WidgetFormatting.dayWithWeekday(dateForHeader(info))
            )
            if let next = info.nextStop, !isTight {
                Text(WidgetFormatting.nextStopLine(next, compactName: true))
                    .font(.caption2)
                    .foregroundStyle(WidgetStyle.tertiaryText)
                    .multilineTextAlignment(.trailing)
                    .lineLimit(2)
                    .minimumScaleFactor(0.7)
            } else if info.isAfterLastStop {
                WidgetCaption(
                    text: WidgetFormatting.cruiseEndLine(info.cruiseEnd),
                    lines: 2,
                    tint: WidgetStyle.tertiaryText
                )
            }
        }
        .frame(width: outlookWidth, alignment: .trailing)
    }

    private func dateForHeader(_ info: ActiveInfo) -> Date {
        info.currentStop?.day ?? info.cruiseStart
    }

    /// Zeitleiste mit Ankunft, jetzt und Abfahrt. Ohne Uhrzeiten bleibt der
    /// zeitlose Eintrag bei seiner Tagesangabe.
    @ViewBuilder
    private func timelineBlock(_ info: ActiveInfo) -> some View {
        if let current = info.currentStop,
           let arrival = current.arrival,
           let departure = current.departure,
           let progress = WidgetProgress.elapsed(current) {
            VStack(alignment: .leading, spacing: 2) {
                // Bei grossem Schriftgrad weicht der Balken — die drei Zeiten
                // darunter tragen denselben Inhalt und brauchen den Platz.
                if !isTight {
                    WidgetTimeline(progress: progress)
                }
                HStack(spacing: 4) {
                    timeLabel(WidgetFormatting.time(arrival))
                    Spacer(minLength: 0)
                    Text(Date(), style: .time)
                        .font(.system(size: 10, weight: .semibold))
                        .monospacedDigit()
                        .foregroundStyle(WidgetStyle.accent)
                    Spacer(minLength: 0)
                    timeLabel(WidgetFormatting.time(departure))
                }
            }
        }
    }

    private func timeLabel(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 10))
            .monospacedDigit()
            .foregroundStyle(WidgetStyle.tertiaryText)
            .lineLimit(1)
    }

    /// Fusszeile: links die cyane Restzeit, rechts der Reisetitel — im
    /// Konzept steht dort die Kapitaelchen-Zeile, hier traegt derselbe Platz
    /// den Pflichtinhalt.
    @ViewBuilder
    private func footerBlock(_ info: ActiveInfo) -> some View {
        HStack(alignment: .bottom, spacing: 8) {
            if let departure = info.currentStop?.departure, departure > Date() {
                Text("Noch \(departure, style: .relative) im Hafen",
                     bundle: WidgetFormatting.bundle)
                    .font(.system(size: 12, weight: .semibold))
                    .monospacedDigit()
                    .foregroundStyle(WidgetStyle.accent)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
            } else if let current = info.currentStop {
                WidgetValueLine(text: WidgetFormatting.stopDetailCompact(current), size: 12)
            }
            Spacer(minLength: 4)
            // Bei grossem Schriftgrad darf der Reisetitel umbrechen statt
            // abzubrechen — Text hat Vorrang vor der einzeiligen Form.
            WidgetCaption(
                text: info.title,
                lines: isTight ? 2 : 1,
                tint: WidgetStyle.tertiaryText
            )
                .multilineTextAlignment(.trailing)
                .frame(maxWidth: isTight ? 150 : 130, alignment: .trailing)
        }
    }

    // MARK: - Countdown

    @ViewBuilder
    private func countdownContent(_ info: CountdownInfo) -> some View {
        HStack(alignment: .top, spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                WidgetCaption(
                    text: WidgetFormatting.nextCruiseInLabel,
                    tint: WidgetStyle.tertiaryText
                )
                if let parts = WidgetFormatting.countdownParts(
                    daysUntilStart: info.daysUntilStart,
                    dative: true
                ) {
                    WidgetNumeral(
                        value: parts.value,
                        unit: parts.unit,
                        size: isTight ? 28 : 40,
                        numeralTint: WidgetStyle.accent
                    )
                } else {
                    WidgetHeadline(
                        text: WidgetFormatting.countdown(daysUntilStart: info.daysUntilStart),
                        size: isTight ? 20 : 28,
                        lineLimit: 2
                    )
                }
                WidgetValueLine(text: info.title, size: 14, lines: nameLines)
                Spacer(minLength: 2)
                detailRow(symbol: WidgetSymbol.ship, text: info.ship)
                detailRow(
                    symbol: WidgetSymbol.calendar,
                    text: WidgetFormatting.departureLine(info.startDate)
                )
                if !isTight {
                    WidgetTagline(text: WidgetFormatting.taglineCountdown)
                }
            }
            if !isTight {
                Spacer(minLength: 4)
                heroBlock
            }
        }
    }

    private func detailRow(symbol: String, text: String) -> some View {
        HStack(spacing: 5) {
            Image(systemName: symbol)
                .font(.system(size: 10))
                .foregroundStyle(WidgetStyle.accent)
                .frame(width: 12)
                .accessibilityHidden(true)
            Text(text)
                .font(.caption2)
                .foregroundStyle(WidgetStyle.secondaryText)
                .lineLimit(isTight ? 2 : 1)
                .minimumScaleFactor(0.7)
        }
    }

    /// Rechte Spalte des Countdowns: Schriftzeile, Bildkreis, Wortmarke.
    private var heroBlock: some View {
        VStack(alignment: .trailing, spacing: 3) {
            Text(WidgetFormatting.taglineScript)
                .font(.system(size: 9, weight: .regular, design: .serif).italic())
                .foregroundStyle(WidgetStyle.tertiaryText)
                .multilineTextAlignment(.trailing)
                .lineLimit(2)
                .accessibilityHidden(true)
            ZStack {
                Circle().fill(WidgetStyle.surfaceBottom)
                Image("WidgetShipHero")
                    .resizable()
                    .scaledToFill()
                    .frame(width: 84, height: 84)
                    .clipShape(Circle())
                Circle().strokeBorder(WidgetStyle.accent.opacity(0.85), lineWidth: 2.5)
            }
            .frame(width: 84, height: 84)
            .accessibilityHidden(true)
            HStack(spacing: 3) {
                Image(systemName: WidgetSymbol.ship)
                    .font(.system(size: 8))
                Text(verbatim: "ShipTrip")
                    .font(.system(size: 9, weight: .semibold))
            }
            .foregroundStyle(WidgetStyle.secondaryText)
            .accessibilityHidden(true)
        }
        .frame(width: 108)
    }

    // MARK: - Leerlauf

    @ViewBuilder
    private func idleContent(_ info: IdleInfo) -> some View {
        if let days = info.daysSinceLastCruise {
            VStack(alignment: .leading, spacing: 6) {
                HStack(alignment: .top, spacing: 10) {
                    if !isTight {
                        WidgetRing(
                            symbol: WidgetSymbol.idle,
                            progress: nil,
                            diameter: 54,
                            lineWidth: 6
                        )
                    }
                    VStack(alignment: .leading, spacing: 1) {
                        WidgetCaption(
                            text: WidgetFormatting.lastCruiseLabel,
                            tint: WidgetStyle.tertiaryText
                        )
                        WidgetValueLine(
                            text: WidgetFormatting.sinceLastCruise(days: days),
                            size: isTight ? 18 : 24
                        )
                        if let title = info.lastCruiseTitle {
                            WidgetHeadline(text: title, size: 15, lineLimit: nameLines)
                        }
                    }
                    Spacer(minLength: 0)
                }
                Spacer(minLength: 0)
                WidgetCaption(
                    text: WidgetFormatting.noPlannedCruise,
                    lines: 2,
                    tint: WidgetStyle.tertiaryText
                )
            }
        } else {
            instrument(
                symbol: WidgetSymbol.idle,
                progress: nil,
                label: nil,
                title: WidgetFormatting.noCruiseAtAll,
                detail: nil
            )
        }
    }

    // MARK: - Bausteine

    /// Ring links, Label/Name/Nebentext rechts. Ab Dynamic Type XXL faellt der
    /// Ring weg und der Text bekommt die ganze Breite.
    private func instrument(
        symbol: String,
        progress: Double?,
        label: String?,
        title: String,
        detail: String?,
        diameter: CGFloat = 54
    ) -> some View {
        HStack(alignment: .center, spacing: 10) {
            if !isTight {
                WidgetRing(symbol: symbol, progress: progress, diameter: diameter, lineWidth: 6)
            }
            VStack(alignment: .leading, spacing: 1) {
                if let label, !isTight {
                    WidgetCaption(text: label, tint: WidgetStyle.tertiaryText)
                }
                WidgetHeadline(text: title, size: 20, lineLimit: nameLines)
                if let detail {
                    WidgetCaption(text: detail, lines: 2)
                }
            }
        }
    }

    /// Gedaempfte Schiffssilhouette am rechten Rand, Bug nach links — das
    /// Markenzeichen der 2×1-Kachel im Konzept. Das Bild bringt seinen eigenen
    /// Navy-Grund mit; zwei Masken blenden es nach links und an Ober- wie
    /// Unterkante aus, damit keine sichtbare Kante entsteht. Das Schiff liegt
    /// in der Bildmitte (30–68 % der Hoehe) und bleibt dabei unangetastet.
    /// Fehlt das Bild, bleibt die Stelle leer — die Kachel haengt nicht daran.
    private var shipGhost: some View {
        Image("WidgetShipGhost")
            .resizable()
            .scaledToFill()
            .frame(width: 150, height: 142)
            .clipped()
            .opacity(0.85)
            .mask(
                LinearGradient(
                    stops: [
                        .init(color: .clear, location: 0),
                        .init(color: .black.opacity(0.4), location: 0.3),
                        .init(color: .black, location: 0.75)
                    ],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .mask(
                LinearGradient(
                    stops: [
                        .init(color: .clear, location: 0),
                        .init(color: .black, location: 0.14),
                        .init(color: .black, location: 0.86),
                        .init(color: .clear, location: 1)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            .allowsHitTesting(false)
            .accessibilityHidden(true)
    }
}
