//
//  OnboardingCards.swift
//  ShipTrip
//
//  Die Inhaltsspalten der vier Karten des Erststart-Flows (Task B2).
//  Rahmen, Kopf- und Fusszeile liegen in `OnboardingFlowView`.
//
//  Die Karten tragen keinen `Spacer` am Ende: sie stehen in einer
//  `ScrollView`, damit sie bei grossen Dynamic-Type-Graden nicht abschneiden.
//  Die Restflaeche verteilt der Rahmen, nicht die Karte.
//
//  Bildmaterial: beide Fotos sind bereits im Asset-Katalog der App
//  (`demo_port_geiranger`, `cover_ship_aidanova`) — der Prototyp hatte sie nur
//  unter eigenen Namen kopiert.
//

import SwiftUI

// MARK: - Karte 1 · Wertversprechen

struct OnboardingWelcomeCard: View {
    let appeared: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: OnboardingSpace.xl) {
            OnboardingHero(
                asset: "demo_port_geiranger",
                caption: String(localized: "Geirangerfjord · Norwegen")
            )
            .onboardingCascadeIn(0, appeared: appeared)

            VStack(alignment: .leading, spacing: OnboardingSpace.sm) {
                Text(String(localized: "Dein Logbuch für jede Kreuzfahrt"))
                    .font(.title.weight(.bold))
                    .foregroundStyle(.primary)
                    .fixedSize(horizontal: false, vertical: true)
                    .onboardingCascadeIn(1, appeared: appeared)

                Text(String(localized: "Route, Häfen, Fotos und Ausgaben — jede Reise an einem Ort, auch ohne Netz. Alles bleibt auf deinem Gerät."))
                    .font(.body)
                    .foregroundStyle(OnboardingColor.bodyText)
                    .fixedSize(horizontal: false, vertical: true)
                    .onboardingCascadeIn(2, appeared: appeared)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - Karte 2 · Kern-Features

struct OnboardingFeaturesCard: View {
    let appeared: Bool

    private struct Feature: Identifiable {
        let id: Int
        let symbol: String
        let tint: Color
        let title: String
        let text: String
    }

    private var features: [Feature] {
        [
            Feature(id: 0, symbol: "map.fill", tint: .oceanBlue,
                    title: String(localized: "Karte & Route"),
                    text: String(localized: "Jeder Hafen wird zum Pin, deine Reise zur Linie auf der Weltkarte.")),
            Feature(id: 1, symbol: "photo.stack.fill", tint: .sunsetOrange,
                    title: String(localized: "Fotos & Ausflüge"),
                    text: String(localized: "Bilder und Notizen landen direkt beim richtigen Anlauf — mit Datum und Ort.")),
            Feature(id: 2, symbol: "bell.badge.fill", tint: .seaGreen,
                    title: String(localized: "Erinnerungen"),
                    text: String(localized: "Ein Hinweis ein paar Tage vor dem Auslaufen, damit nichts untergeht."))
        ]
    }

    var body: some View {
        VStack(alignment: .leading, spacing: OnboardingSpace.lg) {
            VStack(alignment: .leading, spacing: OnboardingSpace.sm) {
                Text(String(localized: "Drei Dinge, die ShipTrip für dich mitschreibt"))
                    .font(.title.weight(.bold))
                    .fixedSize(horizontal: false, vertical: true)
                    .onboardingCascadeIn(0, appeared: appeared)

                Text(String(localized: "Mehr musst du nicht einrichten — der Rest passiert beim Reisen."))
                    .font(.body)
                    .foregroundStyle(OnboardingColor.bodyText)
                    .fixedSize(horizontal: false, vertical: true)
                    .onboardingCascadeIn(1, appeared: appeared)
            }
            .padding(.top, OnboardingSpace.xs)

            VStack(spacing: 0) {
                ForEach(Array(features.enumerated()), id: \.element.id) { position, feature in
                    if position > 0 {
                        Divider().padding(.leading, 48 + OnboardingSpace.md)
                    }
                    FeatureRow(feature: feature)
                        .padding(.vertical, OnboardingSpace.md)
                        .onboardingCascadeIn(2 + position, appeared: appeared)
                }
            }
            .padding(.horizontal, OnboardingSpace.md)
            .background(
                Color(.secondarySystemGroupedBackground),
                in: RoundedRectangle(cornerRadius: DesignRadius.md, style: .continuous)
            )
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private struct FeatureRow: View {
        let feature: Feature

        var body: some View {
            HStack(alignment: .top, spacing: OnboardingSpace.md) {
                // Die Kachel traegt den Farbton nur als Flaeche bei 14 % und als
                // Glyphe — nie als Textfarbe. Der Text daneben bleibt neutral.
                Image(systemName: feature.symbol)
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(feature.tint)
                    .frame(width: 48, height: 48)
                    .background(
                        feature.tint.opacity(0.14),
                        in: RoundedRectangle(cornerRadius: DesignRadius.sm, style: .continuous)
                    )
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 3) {
                    Text(feature.title)
                        .font(.headline)
                    Text(feature.text)
                        .font(.subheadline)
                        .foregroundStyle(OnboardingColor.bodyText)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 0)
            }
            .accessibilityElement(children: .combine)
        }
    }
}

// MARK: - Karte 3 · Soft-Ask Erinnerungen

/// Priming-Karte vor der System-Abfrage. Muster uebernommen aus
/// `CruiseFormView.ReminderPermissionSheet` (Nutzen erklaeren, dann fragen).
/// Der Systemdialog erscheint ausschliesslich nach „Erinnerungen aktivieren".
struct OnboardingReminderSoftAskCard: View {
    let appeared: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: OnboardingSpace.lg) {
            // Dieselbe Kachel wie die Zeile „Erinnerungen" auf Karte 2 — gleiche
            // Form, gleicher Radius, gleicher Tint-Anteil, gleicher Farbton, nur
            // eine Stufe groesser.
            Image(systemName: "bell.badge.fill")
                .font(.system(size: 28, weight: .semibold))
                .foregroundStyle(Color.seaGreen)
                .frame(width: 64, height: 64)
                .background(
                    Color.seaGreen.opacity(0.14),
                    in: RoundedRectangle(cornerRadius: DesignRadius.sm, style: .continuous)
                )
                .padding(.top, OnboardingSpace.md)
                .accessibilityHidden(true)
                .onboardingCascadeIn(0, appeared: appeared)

            VStack(alignment: .leading, spacing: OnboardingSpace.sm) {
                Text(String(localized: "Sollen wir dich an die Abreise erinnern?"))
                    .font(.title.weight(.bold))
                    .fixedSize(horizontal: false, vertical: true)
                    .onboardingCascadeIn(1, appeared: appeared)

                Text(String(localized: "Ein paar Tage vor dem Auslaufen bekommst du einen Hinweis auf deine nächste Reise. Mehr nicht — keine Werbung, keine täglichen Meldungen."))
                    .font(.body)
                    .foregroundStyle(OnboardingColor.bodyText)
                    .fixedSize(horizontal: false, vertical: true)
                    .onboardingCascadeIn(2, appeared: appeared)
            }

            // Eine Typo-Stufe unter dem Fliesstext (`.footnote` statt
            // `.subheadline`): die Box erklaert, was danach passiert, sie
            // konkurriert nicht mit der Frage darueber.
            HStack(alignment: .top, spacing: OnboardingSpace.sm) {
                Image(systemName: "info.circle")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .accessibilityHidden(true)
                Text(String(localized: "iOS fragt dich anschließend selbst um Erlaubnis — aber erst, wenn du hier auf „Erinnerungen aktivieren“ tippst."))
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(OnboardingSpace.md)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                Color(.secondarySystemGroupedBackground),
                in: RoundedRectangle(cornerRadius: DesignRadius.md, style: .continuous)
            )
            .accessibilityElement(children: .combine)
            .onboardingCascadeIn(3, appeared: appeared)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - Karte 4 · Start-CTA

/// Die Entscheidung am Ende des Erststarts steht als **Paar** in der
/// Aktions-Gruppe (`OnboardingFlowView`): gefuellt „Erste Reise anlegen" ueber
/// ungefuellt „Beispielreise ansehen", gleiche Breite, gleiche Hoehe.
///
/// Die Reise-Karte steht hier im Inhalt, 28 pt unter der Copy, die sie
/// ankuendigt — derselbe Bild-zu-Text-Abstand, den Karte 1 zwischen Hero und
/// Ueberschrift traegt. Sie ist Illustration der zweiten Option und
/// ganzflaechig antippbar; sie loest dieselbe Aktion aus wie die ungefuellte
/// Taste darunter.
struct OnboardingStartCard: View {
    let appeared: Bool
    var onSample: () -> Void = {}

    var body: some View {
        VStack(alignment: .leading, spacing: OnboardingSpace.xl) {
            VStack(alignment: .leading, spacing: OnboardingSpace.sm) {
                Text(String(localized: "Bereit für deine erste Reise"))
                    .font(.title.weight(.bold))
                    .fixedSize(horizontal: false, vertical: true)
                    .onboardingCascadeIn(0, appeared: appeared)

                Text(String(localized: "Leg deine Reise an — Schiff, Termin, Häfen. Oder sieh dir erst an, wie eine fertige Reise in ShipTrip aussieht."))
                    .font(.body)
                    .foregroundStyle(OnboardingColor.bodyText)
                    .fixedSize(horizontal: false, vertical: true)
                    .onboardingCascadeIn(1, appeared: appeared)
            }

            OnboardingTripCard(
                asset: "cover_ship_aidanova",
                badge: String(localized: "Beispielreise"),
                title: String(localized: "Norwegische Fjorde"),
                meta: String(localized: "Norwegen · 7 Tage"),
                action: onSample
            )
            .onboardingCascadeIn(2, appeared: appeared)
        }
        // Ohne diese Zeile schrumpft der VStack auf seine breiteste Textzeile
        // und wird von der Inhaltsspalte zentriert — Textachse und Kartenachse
        // liefen dann auseinander (Gate-Befund „zwei Achsen").
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.top, OnboardingSpace.xs)
    }
}
