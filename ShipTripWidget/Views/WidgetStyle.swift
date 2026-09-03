//
//  WidgetStyle.swift
//  ShipTripWidget
//
//  Kleine widget-eigene Tokens und die zwei Textbausteine, aus denen die
//  Home-Screen-Familien bestehen. Das Widget ist ein eigenes Bundle und darf
//  `Color+Theme.swift` der App nicht einbinden — die beiden Journal-Farben
//  sind hier deshalb bewusst nachgebildet, nicht importiert.
//

import SwiftUI
import UIKit

// MARK: - Farben

enum WidgetStyle {

    /// Papierton der Journal-Oberflaeche (App: `Color.journalSurface`).
    static var surface: Color {
        Color(uiColor: UIColor { trait in
            trait.userInterfaceStyle == .dark
                ? UIColor(red: 0.082, green: 0.129, blue: 0.180, alpha: 1)  // #15212E
                : UIColor(red: 0.984, green: 0.969, blue: 0.941, alpha: 1)  // #FBF7F0
        })
    }

    /// Akzent fuer Symbole (App: `Color.oceanBlue` / `Color.oceanLight`).
    static var accent: Color {
        Color(uiColor: UIColor { trait in
            trait.userInterfaceStyle == .dark
                ? UIColor(red: 0.212, green: 0.663, blue: 0.941, alpha: 1)  // #36A9F0
                : UIColor(red: 0.047, green: 0.549, blue: 0.914, alpha: 1)  // #0C8CE9
        })
    }
}

// MARK: - Symbole

enum WidgetSymbol {

    static let port = "ferry.fill"
    static let seaDay = "water.waves"
    static let ship = "sailboat.fill"
    static let embarkation = "figure.walk"
    static let cruiseEnd = "flag.checkered"
    /// Umriss statt Fuellung — genau das unterscheidet den Leerlauf vom
    /// aktiven `ship`. Kein Anker: „anchor" ist kein SF Symbol, das Bild fiel
    /// dadurch in allen Familien aus (rund blieb ganz leer).
    static let idle = "sailboat"
    static let unavailable = "arrow.clockwise"

    static func stop(_ stop: WidgetStopInfo) -> String {
        stop.isSeaDay ? seaDay : port
    }
}

// MARK: - Textbausteine

/// Der grosse Wert einer Gruppe: Symbol plus Name.
///
/// `minimumScaleFactor` liegt hier bei 0,7 statt 0,8 — bei Dynamic Type XXL
/// und einem adversarial langen Hafennamen ist 0,8 nicht genug, um ohne
/// abschneidendes „…" auszukommen.
struct WidgetHeadline: View {

    let symbol: String
    let text: String
    var lineLimit: Int = 2

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 4) {
            Image(systemName: symbol)
                .font(.caption)
                .foregroundStyle(WidgetStyle.accent)
                .accessibilityHidden(true)
            Text(text)
                .font(.headline)
                .lineLimit(lineLimit)
                .minimumScaleFactor(0.7)
                .truncationMode(.tail)
        }
    }
}

/// Nebentext einer Gruppe.
struct WidgetCaption: View {

    let text: String
    var lines: Int = 1

    var body: some View {
        Text(text)
            .font(.caption2)
            .foregroundStyle(.secondary)
            .lineLimit(lines)
            .minimumScaleFactor(0.75)
            .truncationMode(.tail)
    }
}
