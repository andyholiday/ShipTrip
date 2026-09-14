//
//  OnboardingCards.swift
//  ProtoOnboarding — Design-Prototyp, KEIN Produktivcode.
//
//  Die vier Karten des Erststart-Flows. Inhalte sind deterministisch und
//  deutsch; Lokalisierung kommt zentral über den String-Katalog (C5).
//

import SwiftUI

// MARK: - Karte 1 · Wertversprechen

struct WelcomeCard: View {
    let appeared: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: Space.xl) {
            ProtoHero(asset: "hero_fjord", caption: "Geirangerfjord · Norwegen")
                .cascadeIn(0, appeared: appeared)

            VStack(alignment: .leading, spacing: Space.sm) {
                Text("Dein Logbuch für jede Kreuzfahrt")
                    .font(.title.weight(.bold))
                    .foregroundStyle(.primary)
                    .fixedSize(horizontal: false, vertical: true)
                    .cascadeIn(1, appeared: appeared)

                Text("Route, Häfen, Fotos und Ausgaben — jede Reise an einem Ort, auch ohne Netz. Alles bleibt auf deinem Gerät.")
                    .font(.body)
                    .foregroundStyle(Color.bodyText)
                    .fixedSize(horizontal: false, vertical: true)
                    .cascadeIn(2, appeared: appeared)
            }

            Spacer(minLength: 0)
        }
    }
}

// MARK: - Karte 2 · Kern-Features

struct FeaturesCard: View {
    let appeared: Bool

    private struct Feature: Identifiable {
        let id: Int
        let symbol: String
        let tint: Color
        let title: String
        let text: String
    }

    private let features: [Feature] = [
        Feature(id: 0, symbol: "map.fill", tint: .oceanBlue,
                title: "Karte & Route",
                text: "Jeder Hafen wird zum Pin, deine Reise zur Linie auf der Weltkarte."),
        Feature(id: 1, symbol: "photo.stack.fill", tint: .sunsetOrange,
                title: "Fotos & Ausflüge",
                text: "Bilder und Notizen landen direkt beim richtigen Anlauf — mit Datum und Ort."),
        Feature(id: 2, symbol: "bell.badge.fill", tint: .seaGreen,
                title: "Erinnerungen",
                text: "Ein Hinweis ein paar Tage vor dem Auslaufen, damit nichts untergeht.")
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: Space.lg) {
            VStack(alignment: .leading, spacing: Space.sm) {
                Text("Drei Dinge, die ShipTrip für dich mitschreibt")
                    .font(.title.weight(.bold))
                    .fixedSize(horizontal: false, vertical: true)
                    .cascadeIn(0, appeared: appeared)

                Text("Mehr musst du nicht einrichten — der Rest passiert beim Reisen.")
                    .font(.body)
                    .foregroundStyle(Color.bodyText)
                    .fixedSize(horizontal: false, vertical: true)
                    .cascadeIn(1, appeared: appeared)
            }
            .padding(.top, Space.xs)

            VStack(spacing: 0) {
                ForEach(Array(features.enumerated()), id: \.element.id) { position, feature in
                    if position > 0 {
                        Divider().padding(.leading, 48 + Space.md)
                    }
                    FeatureRow(feature: feature)
                        .padding(.vertical, Space.md)
                        .cascadeIn(2 + position, appeared: appeared)
                }
            }
            .padding(.horizontal, Space.md)
            .background(
                Color(.secondarySystemGroupedBackground),
                in: RoundedRectangle(cornerRadius: DesignRadius.md, style: .continuous)
            )

            Spacer(minLength: 0)
        }
    }

    private struct FeatureRow: View {
        let feature: Feature

        var body: some View {
            HStack(alignment: .top, spacing: Space.md) {
                Image(systemName: feature.symbol)
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(feature.tint)
                    .frame(width: 48, height: 48)
                    .background(
                        feature.tint.opacity(0.14),
                        in: RoundedRectangle(cornerRadius: DesignRadius.sm, style: .continuous)
                    )

                VStack(alignment: .leading, spacing: 3) {
                    Text(feature.title)
                        .font(.headline)
                    Text(feature.text)
                        .font(.subheadline)
                        .foregroundStyle(Color.bodyText)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 0)
            }
        }
    }
}

// MARK: - Karte 3 · Soft-Ask Erinnerungen

/// Priming-Karte vor der System-Abfrage. Muster übernommen aus
/// `CruiseFormView.ReminderPermissionSheet` (Nutzen erklären, dann fragen).
/// Der Systemdialog erscheint ausschließlich nach „Erinnerungen aktivieren“.
struct ReminderSoftAskCard: View {
    let appeared: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: Space.lg) {
            // Dieselbe Kachel wie die Zeile „Erinnerungen“ auf Karte 2 — gleiche
            // Form, gleicher Radius, gleicher Tint-Anteil, gleicher Farbton,
            // nur eine Stufe größer. Der vorherige 96-pt-Kreis in oceanBlue bei
            // 12 % lag bei 1,14 : 1 zum Grund und war weder als Form noch als
            // Zitat lesbar (Gate-Befund).
            Image(systemName: "bell.badge.fill")
                .font(.system(size: 28, weight: .semibold))
                .foregroundStyle(Color.seaGreen)
                .frame(width: 64, height: 64)
                .background(
                    Color.seaGreen.opacity(0.14),
                    in: RoundedRectangle(cornerRadius: DesignRadius.sm, style: .continuous)
                )
                .padding(.top, Space.md)
                .cascadeIn(0, appeared: appeared)

            VStack(alignment: .leading, spacing: Space.sm) {
                Text("Sollen wir dich an die Abreise erinnern?")
                    .font(.title.weight(.bold))
                    .fixedSize(horizontal: false, vertical: true)
                    .cascadeIn(1, appeared: appeared)

                Text("Ein paar Tage vor dem Auslaufen bekommst du einen Hinweis auf deine nächste Reise. Mehr nicht — keine Werbung, keine täglichen Meldungen.")
                    .font(.body)
                    .foregroundStyle(Color.bodyText)
                    .fixedSize(horizontal: false, vertical: true)
                    .cascadeIn(2, appeared: appeared)
            }

            // Eine Typo-Stufe unter dem Fließtext (`.footnote` statt
            // `.subheadline`): die Box erklärt, was danach passiert, sie
            // konkurriert nicht mit der Frage darüber.
            HStack(alignment: .top, spacing: Space.sm) {
                Image(systemName: "info.circle")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.secondary)
                Text("iOS fragt dich anschließend selbst um Erlaubnis — aber erst, wenn du hier auf „Erinnerungen aktivieren“ tippst.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(Space.md)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                Color(.secondarySystemGroupedBackground),
                in: RoundedRectangle(cornerRadius: DesignRadius.md, style: .continuous)
            )
            .cascadeIn(3, appeared: appeared)

            Spacer(minLength: 0)
        }
    }
}

// MARK: - Karte 4 · Start-CTA

/// Die Entscheidung am Ende des Erststarts steht als **Paar** in der
/// Aktions-Gruppe (`OnboardingFlow.actions`): gefüllt „Erste Reise anlegen“
/// über ungefüllt „Beispielreise ansehen“, gleiche Breite, gleiche Höhe — die
/// Behandlung, die Karte 3 im selben Flow für ein Optionen-Paar vorgibt.
///
/// Die Reise-Karte steht hier im Inhalt, **28 pt unter der Copy, die sie
/// ankündigt** (Gate-Befund: vorher lagen 202 pt Leere dazwischen und die
/// Karte gruppierte mit nichts; Gestalt-Nähe,
/// `design-library/references/psychology/gestalt.md`). 28 pt ist derselbe
/// Bild-zu-Text-Abstand, den Karte 1 zwischen Hero und Überschrift trägt.
/// Die überschüssige Seitenhöhe fällt dadurch **unter** der Karte an, über
/// den Seitenpunkten — so, wie Karte 1 und Karte 3 ihre Leere ablegen.
///
/// Die Karte ist Illustration der zweiten Option und ganzflächig antippbar;
/// sie löst dieselbe Aktion aus wie die ungefüllte Taste darunter.
struct StartCard: View {
    let appeared: Bool
    var onSample: () -> Void = {}

    var body: some View {
        VStack(alignment: .leading, spacing: Space.xl) {
            VStack(alignment: .leading, spacing: Space.sm) {
                Text("Bereit für deine erste Reise")
                    .font(.title.weight(.bold))
                    .fixedSize(horizontal: false, vertical: true)
                    .cascadeIn(0, appeared: appeared)

                Text("Leg deine Reise an — Schiff, Termin, Häfen. Oder sieh dir erst an, wie eine fertige Reise in ShipTrip aussieht.")
                    .font(.body)
                    .foregroundStyle(Color.bodyText)
                    .fixedSize(horizontal: false, vertical: true)
                    .cascadeIn(1, appeared: appeared)
            }

            ProtoTripCard(
                asset: "hero_reise",
                badge: "Beispielreise",
                title: "Norwegische Fjorde",
                meta: "Norwegen · 7 Tage",
                action: onSample
            )
            .cascadeIn(2, appeared: appeared)
        }
        // Ohne diese Zeile schrumpft der VStack auf seine breiteste Textzeile
        // und wird von der Inhaltsspalte zentriert — gemessen 27 pt Textachse
        // gegen 20 pt Kartenachse (Gate-Befund „zwei Achsen“).
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.top, Space.xs)
    }
}
