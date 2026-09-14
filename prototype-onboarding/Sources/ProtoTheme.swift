//
//  ProtoTheme.swift
//  ProtoOnboarding — Design-Prototyp, KEIN Produktivcode.
//
//  Die Farb- und Radius-Token sind 1:1 aus `ShipTrip/Utilities/Color+Theme.swift`
//  kopiert. Der Prototyp erfindet keine eigene Palette; er benutzt die der App.
//

import SwiftUI
import UIKit

// MARK: - Brand Colors (kopiert aus Color+Theme.swift)

extension Color {
    /// Ozeanblau – Hauptfarbe
    static let oceanBlue = Color(red: 0.047, green: 0.549, blue: 0.914) // #0C8CE9

    /// Ozeanblau – helle Variante
    static let oceanLight = Color(red: 0.212, green: 0.663, blue: 0.941) // #36A9F0

    /// Dunkles Navy
    static let navyDark = Color(red: 0.102, green: 0.212, blue: 0.365) // #1A365D

    /// Sonnenuntergang Orange
    static let sunsetOrange = Color(red: 1.0, green: 0.420, blue: 0.208) // #FF6B35

    /// Seegrün
    static let seaGreen = Color(red: 0.204, green: 0.780, blue: 0.349) // #34C759

    /// Label-Farbe der ungefüllten Aktion. Keine neue Marke, sondern zwei
    /// bestehende Token je Schema: `navyDark` auf hellem Grund (12,1 : 1 auf
    /// Weiß), `oceanLight` auf dunklem Grund (6,6 : 1 auf `#1C1C1E`). Reines
    /// `oceanBlue` erreicht auf Weiß nur 3,53 : 1 und fällt damit unter
    /// WCAG AA für normalen Text — Befund der Gate-Runde.
    static let actionLabel = Color(UIColor { trait in
        trait.userInterfaceStyle == .dark
            ? UIColor(red: 0.212, green: 0.663, blue: 0.941, alpha: 1) // oceanLight
            : UIColor(red: 0.102, green: 0.212, blue: 0.365, alpha: 1) // navyDark
    })

    /// Kontur der ungefüllten Aktion — **ein** Grauton für beide Modi.
    /// Vorher wechselte sie die Farbfamilie: Light trug eine schwere
    /// Navy-Kontur, Dark eine Akzentblau-Kontur — zwei verschiedene
    /// Behandlungen desselben Bauteils (Gate-Befund). `systemGray` #8E8E93
    /// ist in beiden Schemata derselbe Wert und trägt in beiden über der
    /// 3 : 1-Schwelle aus WCAG 1.4.11: 3,53 : 1 auf der weißen Kartenfläche
    /// (Light), 4,57 : 1 auf `#1C1C1E` (Dark). Die Aktion bleibt damit als
    /// Kontur-Aktion erkennbar, ohne eine zweite Markenfarbe aufzumachen —
    /// geführt wird ausschließlich über die gefüllte Primär-Taste.
    static let actionBorder = Color(UIColor.systemGray)

    /// Fließtext-Grau des Onboardings — eine Stufe dunkler als das
    /// Caption-Grau der App (#85858B): das erreicht auf `#F2F2F7` nur
    /// 3,29 : 1 und fällt damit unter WCAG AA für normalen Text (Gate-Befund).
    /// #65656B erreicht 5,20 : 1. Captions und Fußnoten bleiben bewusst auf
    /// dem App-Grau (`.secondary`) — der Token der App wird nicht angefasst.
    static let bodyText = Color(UIColor { trait in
        trait.userInterfaceStyle == .dark
            ? UIColor(red: 0.557, green: 0.557, blue: 0.588, alpha: 1) // #8E8E96
            : UIColor(red: 0.396, green: 0.396, blue: 0.420, alpha: 1) // #65656B
    })
}

// MARK: - Radien (kopiert aus Color+Theme.swift)

enum DesignRadius {
    static let sm: CGFloat = 10
    static let md: CGFloat = 16
    static let lg: CGFloat = 28
}

// MARK: - Abstände

/// 4-pt-Raster; die Werte, die im Onboarding tatsächlich vorkommen.
enum Space {
    static let xs: CGFloat = 8
    static let sm: CGFloat = 12
    static let md: CGFloat = 16
    static let lg: CGFloat = 20
    static let xl: CGFloat = 28
    static let xxl: CGFloat = 40

    /// Seitenrand aller Onboarding-Karten (gemessen an „Meine Reisen“).
    static let gutter: CGFloat = 20
}

// MARK: - Maße

/// Ein gemeinsames Seitenverhältnis für **alle** Foto-Heros des Flows.
/// Vorher: 280 pt auf Karte 1, 220 pt auf Karte 4 — zwei Formate ohne Grund.
enum ProtoMetrics {
    /// 3 : 2 — bei 362 pt Kartenbreite sind das 241 pt Höhe.
    static let heroRatio: CGFloat = 3.0 / 2.0

    /// Sichtbare Höhe **jeder** Aktion im Flow. 66 pt ist das gemessene Maß der
    /// Weiter-Taste auf Karte 1; die ungefüllte Zweit-Aktion lag bei 52 pt und
    /// riss damit ein zweites Button-Größen-Level auf (Gate-Befund).
    static let actionHeight: CGFloat = 66

    /// `.borderedProminent` legt je 7 pt Polster um sein Label — die
    /// Label-Höhe der Primär-Aktion ist deshalb 66 − 14.
    static let primaryLabelHeight: CGFloat = actionHeight - 14

    /// Abstand der Seitenpunkte zur Primär-Aktion. Die Punkte gehören zur
    /// Aktions-Gruppe, nicht in die Bildmitte: mit der früheren festen
    /// Block-Höhe standen sie zwar auf jeder Karte gleich hoch, aber ~340 pt
    /// vom Inhalt und ~380 pt von der Taste entfernt und gruppierten mit
    /// nichts (Gate-Befund; Gestalt-Nähe, design-library/references/
    /// psychology/gestalt.md). 28 pt sind halb so viel wie der kleinste
    /// Zwischenraum, der im Flow zwischen Inhaltsspalte und Aktions-Gruppe
    /// stehen bleibt (127 pt auf Karte 3).
    static let dotsToAction: CGFloat = Space.xl

    /// Höhe der Mini-Reise-Karte auf Karte 4. Die Reise-Karte der App
    /// (`CruiseHeroCardView`) ist 286 pt hoch; 224 pt sind erkennbar dieselbe
    /// Karte, eine Stufe kleiner — sie zitiert, sie ersetzt nicht.
    static let tripCardHeight: CGFloat = 224
}

// MARK: - Motion

/// Token aus `design-library/references/systems/motion.md` (Bindung in
/// `motion-benchmarks.md`, Abschnitt „Token bindings“).
enum Motion {
    static let standardIn: TimeInterval = 0.25
    static let staggerStep: TimeInterval = 0.03
    static let staggerCap = 6
}

// MARK: - Bausteine

/// Gefüllte Primär-Aktion. Entspricht `.borderedProminent` in der App
/// (`ReminderPermissionSheet`), nur mit festem Brand-Tint statt System-Blau.
struct ProtoPrimaryButton: View {
    let title: String
    var action: () -> Void = {}

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.headline)
                .frame(maxWidth: .infinity)
                .frame(height: ProtoMetrics.primaryLabelHeight)
        }
        .buttonStyle(.borderedProminent)
        .buttonBorderShape(.roundedRectangle(radius: DesignRadius.sm))
        .tint(.oceanBlue)
    }
}

/// Gleichrangige Zweit-Aktion: gleiche Fläche, gleiche Schrift, nur ungefüllt.
/// Bewusst kein grauer Mini-Link – siehe design-spec-onboarding.md, Abschnitt 4.
///
/// Nicht mehr `.bordered` mit Tint: dessen getönte Füllung lag in Light Mode
/// bei 1,22 : 1 zum Grund und trug ein Label bei 2,60 : 1 (Gate-Befund). Statt
/// dessen die Kartenfläche der App als Füllung, eine neutrale Kontur in
/// Separator-Stärke (`actionBorder`, 1 pt, in beiden Modi derselbe Grauton)
/// und ein Label in `actionLabel`.
///
/// Die Höhe ist jetzt dieselbe 66 pt wie bei der Primär-Aktion: die Primär-
/// Markierung trägt fill-vs-outline, nicht Größe.
struct ProtoSecondaryButton: View {
    let title: String
    var action: () -> Void = {}

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.headline)
                .foregroundStyle(Color.actionLabel)
                .frame(maxWidth: .infinity)
                .frame(height: ProtoMetrics.actionHeight)
        }
        .buttonStyle(.plain)
        .background(
            Color(.secondarySystemGroupedBackground),
            in: RoundedRectangle(cornerRadius: DesignRadius.sm, style: .continuous)
        )
        .overlay(
            RoundedRectangle(cornerRadius: DesignRadius.sm, style: .continuous)
                .strokeBorder(Color.actionBorder, lineWidth: 1)
        )
    }
}

/// Seitenindikator 1…4. Der aktive Punkt ist als Kapsel breiter, damit die
/// Position auch ohne Farbunterscheidung ablesbar ist (Accessibility).
struct ProtoPageDots: View {
    let count: Int
    let index: Int

    var body: some View {
        HStack(spacing: Space.xs) {
            ForEach(0 ..< count, id: \.self) { i in
                Capsule()
                    .fill(i == index ? Color.oceanBlue : Color.secondary.opacity(0.28))
                    .frame(width: i == index ? 22 : 8, height: 8)
            }
        }
        .accessibilityElement()
        .accessibilityLabel("Schritt \(index + 1) von \(count)")
    }
}

/// Foto-Hero im Kartenstil der Startseite: volle Breite minus Gutter,
/// Radius `lg` (28), unten ein Verlaufs-Scrim für die Bildunterschrift.
///
/// Die Höhe ist **kein** Parameter mehr, sondern folgt aus einem für den
/// ganzen Flow gemeinsamen Seitenverhältnis (`ProtoMetrics.heroRatio`).
struct ProtoHero: View {
    let asset: String
    let caption: String

    var body: some View {
        // Die Fläche bestimmt das Layout, nicht das Bild: ein `fill`-skaliertes
        // 16:9-Foto hat bei 300 pt Höhe eine Eigenbreite von 533 pt und würde
        // sonst die Breite der ganzen Karte diktieren (gemessen, Runde 1).
        Color.clear
            .frame(maxWidth: .infinity)
            .aspectRatio(ProtoMetrics.heroRatio, contentMode: .fit)
            .overlay {
                Image(asset)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            }
            .overlay {
                // Scrim über die untere Hälfte, als Stops statt fester Höhe —
                // sonst müsste die Höhe wieder als Zahl bekannt sein.
                LinearGradient(
                    stops: [
                        .init(color: .clear, location: 0.5),
                        .init(color: .black.opacity(0.55), location: 1.0)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .allowsHitTesting(false)
            }
            .overlay(alignment: .bottomLeading) {
                Text(caption)
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, Space.sm)
                    .padding(.vertical, 7)
                    .background(.ultraThinMaterial, in: Capsule())
                    .padding(Space.md)
            }
            .clipShape(RoundedRectangle(cornerRadius: DesignRadius.lg, style: .continuous))
    }
}

/// **Signatur-Move der Richtung — ausschließlich auf Karte 4.**
///
/// Der zweite Weg aus dem Onboarding zeigt sich als echte Reise-Karte in der
/// Hero-Karten-Sprache der App (`CruiseHeroCardView`): Foto, Scrim von der
/// Mitte nach unten, Status-Chip, Titel, Meta-Kapsel — dieselbe Anordnung,
/// dieselben Radien, nur 224 statt 286 pt hoch. Sie illustriert, was hinter
/// „Beispielreise ansehen“ liegt: die gefüllte App.
///
/// Die Karte führt **nicht**. Die frühere weiße „Ansehen“-Pille ist gestrichen
/// (Gate-Befund): sie war die lauteste Marke auf dem Screen und machte die
/// Karte zum konkurrierenden Primary, statt sie als eine von zwei Optionen
/// lesbar zu machen. Die Wahl steht jetzt als gestapeltes Paar in der
/// Aktions-Gruppe; die ganze Karte bleibt Tap-Fläche und löst dieselbe Aktion
/// aus wie die ungefüllte Taste „Beispielreise ansehen“.
struct ProtoTripCard: View {
    let asset: String
    let badge: String
    let title: String
    let meta: String
    var action: () -> Void = {}

    var body: some View {
        Button(action: action) {
            // Wie bei `ProtoHero`: die Fläche bestimmt das Layout, nicht das
            // Bild — ein `fill`-skaliertes Foto würde sonst die Breite diktieren.
            Color.clear
                .frame(maxWidth: .infinity)
                .frame(height: ProtoMetrics.tripCardHeight)
                .overlay {
                    Image(asset)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                }
                .overlay {
                    // Nachgezogen an die Hero-Karte der App: dort ist das
                    // untere Kartendrittel nahezu schwarz, und genau darauf
                    // sitzt die weiße „Reise öffnen“-Pille. Der frühere
                    // Zwei-Stopp-Verlauf (ab Mitte, 0,84) ließ die Pille auf
                    // heller Wasserfläche stehen — schwächste Kantentrennung
                    // im Set (Gate-Befund).
                    LinearGradient(
                        stops: [
                            .init(color: .clear, location: 0.30),
                            .init(color: .black.opacity(0.45), location: 0.62),
                            .init(color: .black.opacity(0.90), location: 1.0)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                }
                .overlay(alignment: .bottomLeading) { info }
                .clipShape(RoundedRectangle(cornerRadius: DesignRadius.lg, style: .continuous))
                .shadow(color: Color.navyDark.opacity(0.22), radius: 17, y: 10)
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .ignore)
        .accessibilityAddTraits(.isButton)
        .accessibilityLabel("Beispielreise ansehen: \(title), \(meta), \(badge)")
    }

    private var info: some View {
        VStack(alignment: .leading, spacing: Space.xs) {
            // Achromatischer Chip statt `sunsetOrange`: die Karte soll den
            // zweiten Weg zeigen, nicht um die Führung mitbieten. Gesättigt
            // bleibt auf Karte 4 genau ein Block — die blaue Primär-Taste
            // (60-30-10, design-library/references/systems/color-systems.md).
            // Das Orange der App markiert dort einen laufenden Countdown
            // („In 21 Tagen“); ein Demo-Etikett trägt keine solche Dringlichkeit.
            // Dunkle Füllung statt heller, weil der Chip oberhalb des Scrims
            // sitzt und dort auch über hellem Bildinhalt lesbar bleiben muss.
            Text(badge)
                .font(.caption2.weight(.bold))
                .foregroundStyle(.white)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(.black.opacity(0.55), in: Capsule())

            Text(title)
                .font(.title3.weight(.heavy))
                .foregroundStyle(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.85)

            Text(meta)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.white.opacity(0.92))
                .lineLimit(1)
                .minimumScaleFactor(0.85)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(.white.opacity(0.16), in: Capsule())
        }
        .padding(Space.md)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - Entrance-Cascade

/// „List Entrance Cascade“ (design-library motion-benchmarks.md, Familie
/// Stagger/Cascade): Elemente laufen in Lesereihenfolge ein, 250 ms easeOut,
/// 30 ms Versatz, gedeckelt bei 6. `reduceMotion` schaltet sie komplett ab.
struct CascadeIn: ViewModifier {
    let index: Int
    let appeared: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
        let step = Double(min(index, Motion.staggerCap)) * Motion.staggerStep
        return content
            .opacity(appeared || reduceMotion ? 1 : 0)
            .offset(y: appeared || reduceMotion ? 0 : 12)
            .animation(
                reduceMotion ? nil
                             : .easeOut(duration: Motion.standardIn).delay(step),
                value: appeared
            )
    }
}

extension View {
    func cascadeIn(_ index: Int, appeared: Bool) -> some View {
        modifier(CascadeIn(index: index, appeared: appeared))
    }
}
