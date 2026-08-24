//
//  OnboardingTheme.swift
//  ShipTrip
//
//  Lokale Token des Erststart-Flows (Task B2).
//
//  Farben und Radien der Marke kommen aus `Utilities/Color+Theme.swift`
//  (`oceanBlue`, `oceanLight`, `navyDark`, `sunsetOrange`, `seaGreen`,
//  `DesignRadius`) — hier stehen ausschliesslich die Werte, die die App
//  bisher nicht kennt. Sie liegen bewusst im Onboarding-Ordner und nicht im
//  globalen Theme: sie sind fuer diesen Flow entstanden, und der
//  String-/Token-Durchstich der App ist ein eigener Task.
//

import SwiftUI
import UIKit

// MARK: - Farben

/// Die drei Farbwerte, die der Prototyp zusaetzlich zur App-Palette gebraucht hat.
/// Als eigener Namensraum statt als `Color`-Extension, damit der Flow keine
/// globalen Namen belegt.
enum OnboardingColor {

    /// Label der ungefuellten Aktion. Keine neue Marke, sondern zwei bestehende
    /// Token je Schema: `navyDark` auf hellem Grund (12,1 : 1 auf Weiss),
    /// `oceanLight` auf dunklem Grund (6,6 : 1 auf `#1C1C1E`). Reines
    /// `oceanBlue` erreicht auf Weiss nur 3,53 : 1 und faellt damit unter
    /// WCAG AA fuer normalen Text.
    static let actionLabel = Color(UIColor { trait in
        trait.userInterfaceStyle == .dark
            ? UIColor(Color.oceanLight)
            : UIColor(Color.navyDark)
    })

    /// Kontur der ungefuellten Aktion — **ein** Grauton fuer beide Modi.
    /// `systemGray` #8E8E93 traegt in beiden Schemata ueber der 3 : 1-Schwelle
    /// aus WCAG 1.4.11: 3,53 : 1 auf der weissen Kartenflaeche (Light),
    /// 4,57 : 1 auf `#1C1C1E` (Dark). Die Aktion bleibt als Kontur-Aktion
    /// erkennbar, ohne eine zweite Markenfarbe aufzumachen — gefuehrt wird
    /// ausschliesslich ueber die gefuellte Primaer-Taste.
    static let actionBorder = Color(UIColor.systemGray)

    /// Fliesstext-Grau des Onboardings — eine Stufe dunkler als das
    /// Caption-Grau der App (#85858B): das erreicht auf `#F2F2F7` nur
    /// 3,29 : 1 und faellt damit unter WCAG AA fuer normalen Text. #65656B
    /// erreicht 5,20 : 1. Captions und Fussnoten bleiben bewusst auf dem
    /// App-Grau (`.secondary`) — der Token der App wird nicht angefasst.
    static let bodyText = Color(UIColor { trait in
        trait.userInterfaceStyle == .dark
            ? UIColor(red: 0.557, green: 0.557, blue: 0.588, alpha: 1) // #8E8E96
            : UIColor(red: 0.396, green: 0.396, blue: 0.420, alpha: 1) // #65656B
    })
}

// MARK: - Abstaende

/// 4-pt-Raster; die Werte, die im Onboarding tatsaechlich vorkommen.
enum OnboardingSpace {
    static let xs: CGFloat = 8
    static let sm: CGFloat = 12
    static let md: CGFloat = 16
    static let lg: CGFloat = 20
    static let xl: CGFloat = 28

    /// Seitenrand aller Onboarding-Karten (gemessen an „Meine Reisen").
    static let gutter: CGFloat = 20
}

// MARK: - Masse

enum OnboardingMetrics {

    /// Ein gemeinsames Seitenverhaeltnis fuer **alle** Foto-Heros des Flows.
    /// 3 : 2 — bei 362 pt Kartenbreite sind das 241 pt Hoehe.
    static let heroRatio: CGFloat = 3.0 / 2.0

    /// Sichtbare Hoehe **jeder** Aktion im Flow. Die Primaer-Markierung traegt
    /// fill-vs-outline, nicht Groesse — deshalb ein einziges Groessen-Level.
    static let actionHeight: CGFloat = 66

    /// `.borderedProminent` legt je 7 pt Polster um sein Label — die
    /// Label-Hoehe der Primaer-Aktion ist deshalb 66 − 14.
    static let primaryLabelHeight: CGFloat = actionHeight - 14

    /// Abstand der Seitenpunkte zur Primaer-Aktion. Die Punkte gehoeren zur
    /// Aktions-Gruppe, nicht in die Bildmitte (Gestalt-Naehe).
    static let dotsToAction: CGFloat = OnboardingSpace.xl

    /// Hoehe der Mini-Reise-Karte auf Karte 4. Die Reise-Karte der App
    /// (`CruiseHeroCardView`) ist 286 pt hoch; 224 pt sind erkennbar dieselbe
    /// Karte, eine Stufe kleiner — sie zitiert, sie ersetzt nicht.
    static let tripCardHeight: CGFloat = 224

    /// Hoehe der Kopfzeile („Ueberspringen"). Mindest-Tap-Ziel.
    static let headerHeight: CGFloat = 44
}

// MARK: - Motion

/// Token aus der Design-Library (`systems/motion.md`).
enum OnboardingMotion {
    static let standardIn: TimeInterval = 0.25
    static let staggerStep: TimeInterval = 0.03
    static let staggerCap = 6
}

// MARK: - Entrance-Cascade

/// „List Entrance Cascade": Elemente laufen in Lesereihenfolge ein, 250 ms
/// easeOut, 30 ms Versatz, gedeckelt bei 6. `reduceMotion` schaltet sie
/// komplett ab.
private struct OnboardingCascadeIn: ViewModifier {
    let index: Int
    let appeared: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
        let step = Double(min(index, OnboardingMotion.staggerCap)) * OnboardingMotion.staggerStep
        return content
            .opacity(appeared || reduceMotion ? 1 : 0)
            .offset(y: appeared || reduceMotion ? 0 : 12)
            .animation(
                reduceMotion ? nil
                             : .easeOut(duration: OnboardingMotion.standardIn).delay(step),
                value: appeared
            )
    }
}

extension View {
    /// Einlauf-Staffel des Onboardings. `index` ist die Lesereihenfolge auf der
    /// Karte, `appeared` schaltet die Staffel einmalig scharf.
    func onboardingCascadeIn(_ index: Int, appeared: Bool) -> some View {
        modifier(OnboardingCascadeIn(index: index, appeared: appeared))
    }
}
