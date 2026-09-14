//
//  OnboardingFlow.swift
//  ProtoOnboarding — Design-Prototyp, KEIN Produktivcode.
//
//  Rahmen der vier Karten: Kopfzeile („Überspringen“), Inhalt, Fußzeile
//  (Seitenpunkte + Aktionen). Der Prototyp führt keine Aktion aus; jeder
//  Tipp blättert nur weiter. Die Zustandsführung (`hasCompletedOnboarding`,
//  echte Permission-Abfrage, Demo-Daten) gehört in die App, nicht hierher.
//

import SwiftUI

struct OnboardingFlow: View {
    /// Karte, mit der der Flow startet — die Screen-Registry setzt sie.
    var startIndex: Int = 0

    @State private var selection: Int = 0
    @State private var seen: Set<Int> = []

    private let cardCount = 4

    var body: some View {
        TabView(selection: $selection) {
            ForEach(0 ..< cardCount, id: \.self) { index in
                page(index)
                    .tag(index)
            }
        }
        .tabViewStyle(.page(indexDisplayMode: .never))
        .background(Color(.systemGroupedBackground))
        .onAppear {
            selection = startIndex
            seen.insert(startIndex)
        }
        .onChange(of: selection) { _, new in
            seen.insert(new)
        }
    }

    // MARK: - Eine Seite

    @ViewBuilder
    private func page(_ index: Int) -> some View {
        let appeared = seen.contains(index)

        VStack(spacing: 0) {
            header(index)

            // Die Inhaltsspalte ist das flexible Glied: sie nimmt auf, was die
            // unterschiedlich hohen Aktions-Staffeln übrig lassen. Nur so steht
            // die Fußzeile auf jeder Karte an derselben Stelle.
            content(index, appeared: appeared)
                .padding(.horizontal, Space.gutter)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)

            footer(index, appeared: appeared)
        }
    }

    @ViewBuilder
    private func header(_ index: Int) -> some View {
        HStack {
            Spacer()
            if index < cardCount - 1 {
                Button("Überspringen") { selection = cardCount - 1 }
                    .font(.body)
                    .tint(.oceanBlue)
            }
        }
        .frame(height: 44)
        .padding(.horizontal, Space.gutter)
    }

    @ViewBuilder
    private func content(_ index: Int, appeared: Bool) -> some View {
        switch index {
        case 0: WelcomeCard(appeared: appeared)
        case 1: FeaturesCard(appeared: appeared)
        case 2: ReminderSoftAskCard(appeared: appeared)
        default: StartCard(appeared: appeared, onSample: showSample)
        }
    }

    /// Die Aktions-Gruppe am unteren Rand. Die Seitenpunkte sitzen fest 28 pt
    /// über der Primär-Aktion. Die überschüssige Höhe der Seite fällt dadurch
    /// als **ein** Zwischenraum zwischen Inhaltsspalte und Aktions-Gruppe an
    /// statt als zwei Leerbänder um freistehende Punkte.
    @ViewBuilder
    private func footer(_ index: Int, appeared: Bool) -> some View {
        VStack(spacing: ProtoMetrics.dotsToAction) {
            ProtoPageDots(count: cardCount, index: index)

            VStack(spacing: Space.sm) {
                actions(index, appeared: appeared)
            }
        }
        .padding(.horizontal, Space.gutter)
        .padding(.bottom, Space.md)
    }

    @ViewBuilder
    private func actions(_ index: Int, appeared: Bool) -> some View {
        switch index {
        case 0, 1:
            ProtoPrimaryButton(title: "Weiter") { advance(from: index) }
                .cascadeIn(4, appeared: appeared)

        case 2:
            ProtoPrimaryButton(title: "Erinnerungen aktivieren") { advance(from: index) }
                .cascadeIn(4, appeared: appeared)
            ProtoSecondaryButton(title: "Später") { advance(from: index) }
                .cascadeIn(5, appeared: appeared)
            footnote("Beides lässt sich jederzeit in den Einstellungen ändern.")
                .cascadeIn(6, appeared: appeared)

        default:
            // Dieselbe Behandlung wie das Paar auf Karte 3: gefüllt über
            // ungefüllt, gleiche Breite, gleiche 66 pt, gleiche Kanten. Vorher
            // war die Sekundär-Option eine 362 × 224 pt große Foto-Karte mit
            // eigener weißer Pille und die blaue Taste stand 130 pt tiefer —
            // die beiden lasen sich nie als Paar (Gate-Befund).
            ProtoPrimaryButton(title: "Erste Reise anlegen")
                .cascadeIn(3, appeared: appeared)
            ProtoSecondaryButton(title: "Beispielreise ansehen", action: showSample)
                .cascadeIn(4, appeared: appeared)
            footnote("Die Beispielreise ist als Demo markiert und lässt sich mit einem Tipp wieder entfernen.")
                .cascadeIn(5, appeared: appeared)
        }
    }

    private func footnote(_ text: String) -> some View {
        Text(text)
            .font(.footnote)
            .foregroundStyle(.secondary)
            .multilineTextAlignment(.center)
            .fixedSize(horizontal: false, vertical: true)
            .padding(.horizontal, Space.xs)
    }

    /// Beide Träger der zweiten Option — die Reise-Karte im Inhalt und die
    /// ungefüllte Taste in der Aktions-Gruppe — lösen dieselbe Aktion aus.
    /// Der Prototyp führt sie nicht aus; das Anlegen der Demo-Reise gehört in
    /// die App (`DemoDataService`), nicht hierher.
    private func showSample() {}

    private func advance(from index: Int) {
        guard index < cardCount - 1 else { return }
        selection = index + 1
    }
}
