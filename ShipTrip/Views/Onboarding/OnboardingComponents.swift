//
//  OnboardingComponents.swift
//  ShipTrip
//
//  Bausteine des Erststart-Flows (Task B2): Aktionen, Seitenpunkte, Foto-Hero
//  und die Mini-Reise-Karte auf Karte 4.
//
//  Warum die Reise-Karte hier lokal steht und nicht `CruiseHeroCardView`
//  wiederverwendet: jene Karte bindet ein `Cruise`-Modell (`let cruise: Cruise`)
//  und traegt einen Zwei-Stopp-Scrim ab der Mitte. Karte 4 zeigt aber eine
//  reine Illustration ohne Datensatz und braucht den Drei-Stopp-Scrim, den die
//  Gate-Runde festgelegt hat. Eine Wiederverwendung setzte einen Umbau von
//  `CruiseHeroCardView` voraus — der liegt ausserhalb des B2-Auftrags.
//

import SwiftUI

// MARK: - Aktionen

/// Gefuellte Primaer-Aktion. Entspricht `.borderedProminent` in der App
/// (`ReminderPermissionSheet`), nur mit festem Brand-Tint statt System-Blau.
struct OnboardingPrimaryButton: View {
    let title: String
    var action: () -> Void = {}

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.headline)
                .frame(maxWidth: .infinity)
                .frame(minHeight: OnboardingMetrics.primaryLabelHeight)
        }
        .buttonStyle(.borderedProminent)
        .buttonBorderShape(.roundedRectangle(radius: DesignRadius.sm))
        .tint(.oceanBlue)
    }
}

/// Gleichrangige Zweit-Aktion: gleiche Flaeche, gleiche Schrift, nur ungefuellt.
/// Bewusst kein grauer Mini-Link.
///
/// Nicht `.bordered` mit Tint: dessen getoente Fuellung lag in Light Mode bei
/// 1,22 : 1 zum Grund und trug ein Label bei 2,60 : 1. Statt dessen die
/// Kartenflaeche der App als Fuellung, eine neutrale Kontur in
/// Separator-Staerke (`actionBorder`, 1 pt, in beiden Modi derselbe Grauton)
/// und ein Label in `actionLabel`.
struct OnboardingSecondaryButton: View {
    let title: String
    var action: () -> Void = {}

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.headline)
                .foregroundStyle(OnboardingColor.actionLabel)
                .frame(maxWidth: .infinity)
                .frame(minHeight: OnboardingMetrics.actionHeight)
        }
        .buttonStyle(.plain)
        .background(
            Color(.secondarySystemGroupedBackground),
            in: RoundedRectangle(cornerRadius: DesignRadius.sm, style: .continuous)
        )
        .overlay(
            RoundedRectangle(cornerRadius: DesignRadius.sm, style: .continuous)
                .strokeBorder(OnboardingColor.actionBorder, lineWidth: 1)
        )
    }
}

// MARK: - Seitenpunkte

/// Seitenindikator 1…4. Der aktive Punkt ist als Kapsel breiter, damit die
/// Position auch ohne Farbunterscheidung ablesbar ist (Accessibility).
struct OnboardingPageDots: View {
    let count: Int
    let index: Int

    var body: some View {
        HStack(spacing: OnboardingSpace.xs) {
            ForEach(0 ..< count, id: \.self) { position in
                Capsule()
                    .fill(position == index ? Color.oceanBlue : Color.secondary.opacity(0.28))
                    .frame(width: position == index ? 22 : 8, height: 8)
            }
        }
        .accessibilityElement()
        .accessibilityLabel(String(localized: "Schritt \(index + 1) von \(count)"))
    }
}

// MARK: - Foto-Hero

/// Foto-Hero im Kartenstil der Startseite: volle Breite minus Gutter,
/// Radius `lg` (28), unten ein Verlaufs-Scrim fuer die Bildunterschrift.
///
/// Die Hoehe folgt aus einem fuer den ganzen Flow gemeinsamen
/// Seitenverhaeltnis (`OnboardingMetrics.heroRatio`), nicht aus einem
/// Parameter.
struct OnboardingHero: View {
    let asset: String
    let caption: String

    var body: some View {
        // Die Flaeche bestimmt das Layout, nicht das Bild: ein `fill`-skaliertes
        // 16:9-Foto haette bei 300 pt Hoehe eine Eigenbreite von 533 pt und
        // wuerde sonst die Breite der ganzen Karte diktieren.
        Color.clear
            .frame(maxWidth: .infinity)
            .aspectRatio(OnboardingMetrics.heroRatio, contentMode: .fit)
            .overlay {
                Image(asset)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            }
            .overlay {
                // Scrim ueber die untere Haelfte, als Stops statt fester Hoehe.
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
                    .padding(.horizontal, OnboardingSpace.sm)
                    .padding(.vertical, 7)
                    .background(.ultraThinMaterial, in: Capsule())
                    .padding(OnboardingSpace.md)
            }
            .clipShape(RoundedRectangle(cornerRadius: DesignRadius.lg, style: .continuous))
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(caption)
    }
}

// MARK: - Mini-Reise-Karte (nur Karte 4)

/// **Signatur-Move der Richtung — ausschliesslich auf Karte 4.**
///
/// Der zweite Weg aus dem Onboarding zeigt sich als echte Reise-Karte in der
/// Hero-Karten-Sprache der App: Foto, Scrim von der Mitte nach unten,
/// Status-Chip, Titel, Meta-Kapsel — dieselbe Anordnung, dieselben Radien, nur
/// 224 statt 286 pt hoch. Sie illustriert, was hinter „Beispielreise ansehen"
/// liegt: die gefuellte App.
///
/// Die Karte fuehrt **nicht**. Sie traegt bewusst keine eigene „Ansehen"-Pille:
/// die waere die lauteste Marke auf dem Screen und machte die Karte zum
/// konkurrierenden Primary. Die Wahl steht als gestapeltes Paar in der
/// Aktions-Gruppe; die ganze Karte bleibt Tap-Flaeche und loest dieselbe
/// Aktion aus wie die ungefuellte Taste „Beispielreise ansehen".
struct OnboardingTripCard: View {
    let asset: String
    let badge: String
    let title: String
    let meta: String
    var action: () -> Void = {}

    var body: some View {
        Button(action: action) {
            Color.clear
                .frame(maxWidth: .infinity)
                .frame(height: OnboardingMetrics.tripCardHeight)
                .overlay {
                    Image(asset)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                }
                .overlay {
                    // Nachgezogen an die Hero-Karte der App: dort ist das untere
                    // Kartendrittel nahezu schwarz. Der fruehere Zwei-Stopp-
                    // Verlauf liess den Text auf heller Wasserflaeche stehen —
                    // schwaechste Kantentrennung im Set (Gate-Befund).
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
        .accessibilityLabel(String(localized: "Beispielreise ansehen: \(title), \(meta), \(badge)"))
    }

    private var info: some View {
        VStack(alignment: .leading, spacing: OnboardingSpace.xs) {
            // Achromatischer Chip statt `sunsetOrange`: die Karte soll den
            // zweiten Weg zeigen, nicht um die Fuehrung mitbieten. Gesaettigt
            // bleibt auf Karte 4 genau ein Block — die blaue Primaer-Taste
            // (60-30-10). Das Orange der App markiert einen laufenden Countdown;
            // ein Demo-Etikett traegt keine solche Dringlichkeit.
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
        .padding(OnboardingSpace.md)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
