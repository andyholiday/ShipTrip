//
//  WidgetStyle.swift
//  ShipTripWidget
//
//  Tokens und Bausteine der Richtung „Dynamic Instrument" (Konzept 03).
//  Das Widget ist ein eigenes Bundle und darf `Color+Theme.swift` der App
//  nicht einbinden — die Farben sind hier bewusst eigenstaendig definiert.
//
//  Leitidee der Richtung: die Home-Screen-Familien sind ein dunkles
//  Instrument. Tiefes Navy als Grund (in Hell *und* Dunkel, damit das Widget
//  auf jedem Hintergrund dieselbe Kachel bleibt), Cyan ausschliesslich fuer
//  Werte und den Fortschrittsring, Weiss fuer Namen, gedaempftes Weiss fuer
//  Nebentext. Die Sperrbildschirm-Familien bekommen keinen eigenen Grund —
//  dort toent das System — uebernehmen aber Ring und Hierarchie.
//
//  Kontrast (Cyan #22D3EE auf Navy #0B1622): 10,2:1. Nebentext bei 72 %
//  Weiss rund 9:1, Beiwerk bei 55 % rund 5,4:1 — alle ueber 4,5:1.
//

import SwiftUI

// MARK: - Farben

enum WidgetStyle {

    /// Oberer Ton des Kachelverlaufs.
    static let surfaceTop = Color(red: 0.063, green: 0.118, blue: 0.180)  // #101E2E

    /// Unterer Ton des Kachelverlaufs.
    static let surfaceBottom = Color(red: 0.043, green: 0.086, blue: 0.133)  // #0B1622

    /// Der Grund der Home-Screen-Familien.
    static let surface = LinearGradient(
        colors: [surfaceTop, surfaceBottom],
        startPoint: .top,
        endPoint: .bottom
    )

    /// Akzent: Werte, Ring, Zeitleiste, Sekundaerlabels.
    static let accent = Color(red: 0.133, green: 0.827, blue: 0.933)  // #22D3EE

    /// Weicherer Akzent fuer Verlaeufe und Flaechen.
    static let accentSoft = Color(red: 0.220, green: 0.741, blue: 0.973)  // #38BDF8

    /// Namen und grosse Zahlen.
    static let primaryText = Color.white

    /// Nebentext (Land, Schiff, Datum).
    static let secondaryText = Color.white.opacity(0.72)

    /// Beiwerk: Kapitaelchen-Zeile, Zeitleisten-Beschriftung.
    static let tertiaryText = Color.white.opacity(0.55)

    /// Nicht zurueckgelegter Teil des Rings und der Zeitleiste.
    static let track = Color.white.opacity(0.14)

    /// Verlauf des Fortschritts — von weich nach kraeftig, wie im Konzept.
    static let progress = LinearGradient(
        colors: [accentSoft, accent],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
}

// MARK: - Schrift

extension Font {

    /// Grosse Zahl im Instrument-Duktus: gerundet, fett, feste Groesse.
    static func widgetNumeral(_ size: CGFloat) -> Font {
        .system(size: size, weight: .bold, design: .rounded)
    }

    /// Halbfette gerundete Schrift fuer die Einheit neben einer grossen Zahl.
    static func widgetUnit(_ size: CGFloat) -> Font {
        .system(size: size, weight: .semibold, design: .rounded)
    }
}

// MARK: - Symbole

enum WidgetSymbol {

    static let port = "ferry.fill"
    static let seaDay = "water.waves"
    static let ship = "sailboat.fill"
    static let shipLine = "sailboat"
    static let embarkation = "figure.walk"
    static let cruiseEnd = "flag.checkered"
    static let calendar = "calendar"
    static let clock = "clock"
    static let place = "mappin.and.ellipse"
    /// Leerlauf-Motiv des Konzepts: Insel statt Schiff.
    static let idle = "beach.umbrella.fill"
    static let unavailable = "arrow.clockwise"

    static func stop(_ stop: WidgetStopInfo) -> String {
        stop.isSeaDay ? seaDay : port
    }
}

// MARK: - Ring-Instrument

/// Das Leitmotiv der Richtung: ein Fortschrittsring um ein Symbol.
///
/// `progress` ist der Anteil der bereits verstrichenen Liegezeit. Ist er
/// `nil`, steht der Ring als geschlossener, gedaempfter Kreis — das Motiv
/// bleibt, nur ohne Messwert.
///
/// - Note: Der Anteil wird beim Zeichnen aus `Date()` bestimmt. WidgetKit
///   rendert Eintraege vor, der Ring springt deshalb nur zu den Zeitpunkten
///   der Timeline weiter, nicht kontinuierlich. Die Restzeit daneben laeuft
///   ueber `Text(_:style:)` und ist dadurch live.
struct WidgetRing: View {

    let symbol: String
    let progress: Double?
    var diameter: CGFloat = 56
    var lineWidth: CGFloat = 6
    /// Sperrbildschirm: keine eigene Farbe — alles uebernimmt die Tint-Farbe.
    var monochrome: Bool = false

    var body: some View {
        ZStack {
            Circle()
                .stroke(
                    monochrome ? Color.primary.opacity(0.25) : WidgetStyle.track,
                    lineWidth: lineWidth
                )

            if let progress {
                Circle()
                    .trim(from: 0, to: max(0.02, min(1, progress)))
                    .stroke(style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .foregroundStyle(ringStyle)
            }

            Image(systemName: symbol)
                .font(.system(size: diameter * 0.34, weight: .semibold))
                .foregroundStyle(symbolStyle)
        }
        .frame(width: diameter, height: diameter)
        .accessibilityHidden(true)
    }

    private var ringStyle: AnyShapeStyle {
        monochrome ? AnyShapeStyle(.primary) : AnyShapeStyle(WidgetStyle.progress)
    }

    private var symbolStyle: AnyShapeStyle {
        monochrome ? AnyShapeStyle(.primary) : AnyShapeStyle(WidgetStyle.primaryText)
    }
}

// MARK: - Fortschritt

enum WidgetProgress {

    /// Anteil der verstrichenen Liegezeit eines Eintrags; `nil` bei einem
    /// zeitlosen Eintrag oder einer Spanne ohne Dauer.
    static func elapsed(_ stop: WidgetStopInfo, now: Date = Date()) -> Double? {
        guard let arrival = stop.arrival, let departure = stop.departure else { return nil }
        let span = departure.timeIntervalSince(arrival)
        guard span > 0 else { return nil }
        return min(1, max(0, now.timeIntervalSince(arrival) / span))
    }
}

// MARK: - Textbausteine

/// Der grosse Wert einer Gruppe: der Name, weiss und fett.
///
/// `minimumScaleFactor` liegt bei 0,7 — bei Dynamic Type XXL und einem
/// adversarial langen Hafennamen reicht 0,8 nicht, um ohne „…" auszukommen.
struct WidgetHeadline: View {

    let text: String
    var size: CGFloat = 18
    var lineLimit: Int = 2

    var body: some View {
        Text(text)
            .font(.system(size: size, weight: .bold))
            .foregroundStyle(WidgetStyle.primaryText)
            .lineLimit(lineLimit)
            .minimumScaleFactor(0.7)
            .truncationMode(.tail)
    }
}

/// Nebentext einer Gruppe.
struct WidgetCaption: View {

    let text: String
    var lines: Int = 1
    var tint: Color = WidgetStyle.secondaryText

    var body: some View {
        Text(text)
            .font(.caption2)
            .foregroundStyle(tint)
            .lineLimit(lines)
            .minimumScaleFactor(0.7)
            .truncationMode(.tail)
    }
}

/// Cyaner Wert unter einem Namen — „vor 43 Tagen", „08:00 – 17:00".
struct WidgetValueLine: View {

    let text: String
    var size: CGFloat = 14
    var lines: Int = 1

    var body: some View {
        Text(text)
            .font(.system(size: size, weight: .semibold))
            .monospacedDigit()
            .foregroundStyle(WidgetStyle.accent)
            .lineLimit(lines)
            .minimumScaleFactor(0.7)
            .truncationMode(.tail)
    }
}

/// Grosse Zahl plus Einheit — der Countdown-Blick des Konzepts.
struct WidgetNumeral: View {

    let value: String
    let unit: String
    var size: CGFloat = 34
    /// Im Kleinformat ist die Zahl weiss, im Mittelformat cyan (Konzept 03).
    var numeralTint: Color = WidgetStyle.primaryText

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 5) {
            Text(value)
                .font(.widgetNumeral(size))
                .monospacedDigit()
                .foregroundStyle(numeralTint)
            Text(unit)
                .font(.widgetUnit(size * 0.55))
                .foregroundStyle(WidgetStyle.primaryText)
        }
        .lineLimit(1)
        .minimumScaleFactor(0.5)
    }
}

/// Kleine Kapitaelchen-Zeile des Konzepts („GUTE ORTE. BESSERE GESCHICHTEN.").
struct WidgetTagline: View {

    let text: String

    var body: some View {
        Text(text)
            .font(.system(size: 7, weight: .medium))
            .tracking(1.4)
            .foregroundStyle(WidgetStyle.tertiaryText)
            .lineLimit(1)
            .accessibilityHidden(true)
    }
}

/// Zeitleiste des Mittelformats: Spur, zurueckgelegter Teil, Punkt.
struct WidgetTimeline: View {

    let progress: Double

    var body: some View {
        GeometryReader { geometry in
            let width = geometry.size.width
            let fraction = min(1, max(0, progress))
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(WidgetStyle.track)
                    .frame(height: 3)
                Capsule()
                    .fill(WidgetStyle.progress)
                    .frame(width: width * fraction, height: 3)
                Circle()
                    .fill(WidgetStyle.accent)
                    .frame(width: 9, height: 9)
                    .offset(x: min(width - 9, max(0, width * fraction - 4.5)))
            }
            .frame(height: geometry.size.height, alignment: .center)
        }
        .frame(height: 10)
        .accessibilityHidden(true)
    }
}
