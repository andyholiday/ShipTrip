//
//  ProtoComponents.swift
//  Bausteine der Richtung „Logbuch" — Rinne, Tagesziffer, Stimmung, Fotos.
//

import SwiftUI

// MARK: - Die Logbuch-Rinne

/// Gepunktete Zeitachse, die durch den gesamten Tagesblock läuft.
struct ProtoRailLine: View {
    var body: some View {
        GeometryReader { geo in
            Path { path in
                let x = geo.size.width / 2
                path.move(to: CGPoint(x: x, y: 0))
                path.addLine(to: CGPoint(x: x, y: geo.size.height))
            }
            .stroke(style: StrokeStyle(lineWidth: 2, lineCap: .round, dash: [2.5, 6]))
            .foregroundStyle(Proto.timeline)
        }
        .frame(width: 2)
    }
}

/// Der mutige Move: die Tagesziffer sitzt als 46-pt-Zahl in der Rinne,
/// die Zeitachse läuft darunter weiter.
private struct ProtoRail: View {
    let numeral: String
    let tint: Color
    var dimmed: Bool = false

    var body: some View {
        VStack(spacing: 4) {
            Text(numeral)
                .font(.protoDayNumeral)
                .monospacedDigit()
                .foregroundStyle(tint.opacity(dimmed ? 0.30 : 0.62))
                .fixedSize()
                .padding(.top, -6)
            ProtoRailLine()
                .padding(.top, 2)
        }
        .frame(width: Proto.Layout.rail)
    }
}

/// Ein Block mit Rinne links: die Rinne liegt als Hintergrund hinter dem Block
/// und bekommt dadurch eine definierte Höhe — die Zeitachse läuft immer exakt
/// bis zum Fuß des Blocks, egal wie lang der Inhalt ist.
struct ProtoRailRow<Content: View>: View {
    let numeral: String
    let tint: Color
    var dimmed: Bool = false
    @ViewBuilder var content: Content

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Color.clear
                .frame(width: Proto.Layout.rail, height: 1)
            content
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(alignment: .topLeading) {
            ProtoRail(numeral: numeral, tint: tint, dimmed: dimmed)
        }
    }
}

// MARK: - Tages-Badge

/// Das Symbol im Kopf einer Tagesgruppe. Hafen-, Heim- und Zielhafen bringen
/// ihren gefüllten Kreis als SF-Symbol mit; `water.waves` tut das nicht und
/// stand deshalb als nackte Glyphe im selben Slot wie drei Badges. Für den
/// Seetag wird derselbe Kreis hier gebaut, die Glyphe als Aussparung wie bei
/// den `.circle.fill`-Symbolen — eine Ikonen-Familie über alle Tagestypen.
struct ProtoDayBadge: View {
    let pin: ProtoPinType

    var body: some View {
        if pin.needsBadgeCircle {
            Circle()
                .fill(pin.color)
                .frame(width: Proto.Layout.dayBadge, height: Proto.Layout.dayBadge)
                .overlay(
                    Image(systemName: pin.icon)
                        .font(.system(size: 8, weight: .semibold))
                        .blendMode(.destinationOut)
                )
                .compositingGroup()
        } else {
            Image(systemName: pin.icon)
                .font(.system(size: Proto.Layout.dayBadge))
                .foregroundStyle(pin.color)
        }
    }
}

// MARK: - Stimmung

/// Leseansicht: Farbpunkt der Stimmungs-Rampe plus Wort, auf neutraler Kapsel.
struct ProtoMoodChip: View {
    let mood: ProtoMood

    var body: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(mood.color)
                .frame(width: 8, height: 8)
            Text(mood.label)
                .font(.protoOverline)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 9)
        .padding(.vertical, 4)
        .background(Capsule().fill(Color.primary.opacity(0.05)))
        .accessibilityLabel("Stimmung: \(mood.label)")
    }
}

// MARK: - Fotos im Strang

struct ProtoPhotoStrip: View {
    let photos: [ProtoPhoto]

    var body: some View {
        if photos.count == 1, let photo = photos.first {
            VStack(alignment: .leading, spacing: 6) {
                Image(photo.asset)
                    .resizable()
                    .aspectRatio(16.0 / 9.0, contentMode: .fill)
                    .frame(maxWidth: .infinity)
                    .clipped()
                    .clipShape(RoundedRectangle(cornerRadius: Proto.Radius.md))
                if !photo.caption.isEmpty {
                    ProtoCaptionText(photo.caption)
                }
            }
        } else if !photos.isEmpty {
            // Feste Kachelbreite statt `maxWidth: .infinity`: eine Kachel mit
            // flexibler Breite über einem `aspectRatio(.fill)`-Bild meldet als
            // Mindestbreite ihre Eigenbreite auf Kachelhöhe — die fällt je Foto
            // anders aus (gemessen: 93 / 121 / 78 pt in einer Reihe). Deren
            // Summe sprengte die Spalte, der HStack wuchs mit, und weil ein
            // VStack seine Kinder mit der eigenen Breite platziert, brach
            // danach auch der Fließtext erst am Rand der Papierseite um.
            //
            // Feste Breite heißt aber auch: feste *Mindest*breite. Die Reihe
            // muss deshalb vollständig in die 282 pt der Inhaltsspalte passen,
            // sonst schiebt sie den ganzen Screen auseinander statt sich
            // schneiden zu lassen (`.clipped()` malt weniger, misst aber
            // gleich viel). Drei Kacheln à 88 pt + zwei Fugen à 6 pt = 276 pt:
            // alle drei Fotos stehen ganz in der Spalte, nichts ragt hinaus.
            HStack(alignment: .top, spacing: Proto.Layout.photoGap) {
                ForEach(photos) { photo in
                    VStack(alignment: .leading, spacing: 5) {
                        Image(photo.asset)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: Proto.Layout.photoTile,
                                   height: Proto.Layout.photoTileHeight)
                            .clipped()
                            .clipShape(RoundedRectangle(cornerRadius: Proto.Radius.sm))
                        if !photo.caption.isEmpty {
                            ProtoCaptionText(photo.caption)
                        }
                    }
                    .frame(width: Proto.Layout.photoTile, alignment: .leading)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .clipped()
        }
    }
}

struct ProtoCaptionText: View {
    let text: String
    init(_ text: String) { self.text = text }

    var body: some View {
        Text(text)
            .font(.caption2)
            .foregroundStyle(.secondary)
            .lineLimit(2)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - App-Chrome

/// Die echte Tab-Leiste der App (ShipTrip/Views/MainTabView.swift), damit ein
/// Screenshot des Strangs zeigt, wo der Screen in der App wirklich sitzt.
/// Nur der Reisen-Tab hat Inhalt — die übrigen tragen ihr Label.
struct ProtoAppChrome<Content: View>: View {
    @ViewBuilder var content: Content

    var body: some View {
        TabView(selection: .constant(0)) {
            content
                .tabItem { Label("Reisen", systemImage: "ferry") }
                .tag(0)
            Color(.systemBackground)
                .tabItem { Label("Karte", systemImage: "map") }
                .tag(1)
            Color(.systemBackground)
                .tabItem { Label("Wunschreisen", systemImage: "bookmark") }
                .tag(2)
            Color(.systemBackground)
                .tabItem { Label("Bilanz", systemImage: "chart.bar") }
                .tag(3)
            Color(.systemBackground)
                .tabItem { Label("Mehr", systemImage: "ellipsis") }
                .tag(4)
        }
        .tint(Proto.oceanBlue)
    }
}

// MARK: - Hairline

struct ProtoHairline: View {
    var body: some View {
        Rectangle()
            .fill(Proto.timeline)
            .frame(height: 1)
    }
}
