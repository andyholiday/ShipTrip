//
//  ProtoTheme.swift
//  Token-Set der Richtung „Logbuch".
//
//  Alles unter MARK „Bestand" ist wortgleich aus ShipTrip übernommen
//  (ShipTrip/Utilities/Color+Theme.swift, .planning/karten-redesign-v2-tokens.json,
//  .planning/karten-politur-c-tokens.json). Alles unter MARK „Neu" ist der
//  einzige Zuwachs dieser Richtung und im Report benannt.
//

import SwiftUI
import UIKit

enum Proto {

    // MARK: - Bestand: Marken- und Pin-Farben

    static let oceanBlue    = Color(red: 0.047, green: 0.549, blue: 0.914) // #0C8CE9
    static let oceanLight   = Color(red: 0.212, green: 0.663, blue: 0.941) // #36A9F0
    static let navyDark     = Color(red: 0.102, green: 0.212, blue: 0.365) // #1A365D
    static let sunsetOrange = Color(red: 1.000, green: 0.420, blue: 0.208) // #FF6B35
    static let seaGreen     = Color(red: 0.204, green: 0.780, blue: 0.349) // #34C759

    static let portPin     = oceanBlue
    static let homePortPin = sunsetOrange
    static let seaDayPin   = oceanLight
    static let endPortPin  = seaGreen

    // MARK: - Bestand: Journal-Atlas-Flächen (Karten-Redesign v2)

    /// Warmes Papier hell / Navy-Papier dunkel — #FBF7F0 / #15212E.
    static var journalSurface: Color {
        dynamic(light: UIColor(red: 0.984, green: 0.969, blue: 0.941, alpha: 1),
                dark:  UIColor(red: 0.082, green: 0.129, blue: 0.180, alpha: 1))
    }

    /// Gepunktete Zeitachse (`Color.journalTimeline`) — navyDark 18 % / weiß 14 %.
    static var timeline: Color {
        dynamic(light: UIColor(red: 0.102, green: 0.212, blue: 0.365, alpha: 0.18),
                dark:  UIColor(white: 1.0, alpha: 0.14))
    }

    // MARK: - Neu: Stimmungs-Rampe (die einzigen zwei neuen Farb-Token)

    /// Neutral für `okay` — bewusst unbunt, damit die Stimmung nicht mit dem Pin-Akzent konkurriert.
    static var moodNeutral: Color {
        dynamic(light: UIColor(red: 0.102, green: 0.212, blue: 0.365, alpha: 0.45),
                dark:  UIColor(white: 1.0, alpha: 0.42))
    }

    /// `awful` — #D63131, dunkler als System-Rot, damit er gegen #FBF7F0 sicher über 4.5:1 liegt.
    static let moodAwful = Color(red: 0.839, green: 0.192, blue: 0.192)

    // MARK: - Bestand: Radien (DesignRadius)

    enum Radius {
        static let sm: CGFloat = 10
        static let md: CGFloat = 16
        static let lg: CGFloat = 28
    }

    // MARK: - Layout der Richtung

    enum Layout {
        /// Breite der Logbuch-Rinne links (Tagesziffer + Zeitachse).
        static let rail: CGFloat = 46
        /// Seitenrand des Screens — wie CruiseDetailView.
        static let screenInset: CGFloat = 16
        /// Innenabstand der Papier-Fläche.
        static let panelInset: CGFloat = 16
        static let touchTargetMin: CGFloat = 44
        /// Kantenlängen einer Foto-Kachel in der mehrspaltigen Reihe — eine
        /// Größe, egal ob zwei oder drei Fotos am Eintrag hängen (4:3).
        ///
        /// Die Breite ist an die Inhaltsspalte gerechnet, nicht geschätzt:
        /// 402 (Display) − 2×16 (screenInset) − 2×16 (panelInset) − 46 (Rinne)
        /// − 10 (Abstand zur Rinne) = 282 pt. Drei Kacheln plus zwei Fugen
        /// müssen darunter bleiben: 3×88 + 2×6 = 276 pt. Eine breitere Kachel
        /// ist keine Kosmetik — eine feste Kachelbreite meldet sich als
        /// *Mindestbreite* nach oben, und 3×108 + 12 = 336 pt hat in Runde 2
        /// den kompletten Screen-Inhalt auf 456 pt aufgeblasen. Der ScrollView
        /// hat den zu breiten Inhalt zentriert, und damit hing alles 27 pt
        /// über beide Displaykanten: die Papierseite randlos, „Tagebuch" links
        /// angeschnitten, das Stift-Symbol rechts bündig abgesägt.
        static let photoTile: CGFloat = 88
        static let photoTileHeight: CGFloat = 66
        /// Abstand zwischen zwei Foto-Kacheln.
        static let photoGap: CGFloat = 6
        /// Durchmesser des Tages-Badges im Kopf — gemessen am gefüllten
        /// Kreis von `mappin.circle.fill` bei 15 pt.
        static let dayBadge: CGFloat = 15
        /// Abstand innerhalb eines Tages (zwischen zwei Einträgen).
        static let entryGap: CGFloat = 6
        /// Abstand am Tageswechsel — doppelt so gross wie der Abstand im Tag.
        static let dayGap: CGFloat = 30
    }

    // MARK: - Motion (Stagger / Cascade · List Entrance Cascade)

    enum Motion {
        static let standardIn: Double = 0.24
        static let staggerStep: Double = 0.06
        static let staggerCap: Int = 8
        static let entranceOffset: CGFloat = 14
    }

    // MARK: - Helfer

    static func dynamic(light: UIColor, dark: UIColor) -> Color {
        Color(uiColor: UIColor { trait in
            trait.userInterfaceStyle == .dark ? dark : light
        })
    }
}

// MARK: - Typografie der Richtung

extension Font {
    /// Die Tagesziffer — der eine mutige Move: 46 pt, ultraleicht, gerundet.
    static let protoDayNumeral = Font.system(size: 46, weight: .light, design: .rounded)
    /// Überzeile über Tag und Schritt.
    static let protoOverline = Font.caption2.weight(.semibold)
    /// Fließtext der Erinnerung.
    static let protoJournalBody = Font.callout
}
