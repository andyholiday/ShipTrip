//
//  OnboardingFlowView.swift
//  ShipTrip
//
//  Rahmen der vier Erststart-Karten (Task B2): Kopfzeile („Ueberspringen"),
//  scrollende Inhaltsspalte, Fusszeile (Seitenpunkte + Aktionen).
//
//  Der Flow haengt als `fullScreenCover` ueber dem bereits montierten
//  Hauptbaum (siehe `ShipTripApp`) — er ersetzt ihn nicht. Damit laufen die
//  Start-Reparaturen in `CruiseListView.task` (IdBackfill →
//  NotificationReconciler → ThumbnailBackfill → ShippingLineCatalogDedup)
//  unveraendert weiter, waehrend das Onboarding sichtbar ist.
//

import SwiftUI
import SwiftData

@MainActor
struct OnboardingFlowView: View {

    /// Wird gerufen, wenn der Flow endet — schliesst das Cover und setzt den
    /// persistenten Schalter.
    let onFinish: () -> Void

    @Environment(\.modelContext) private var modelContext
    @State private var model = OnboardingModel()

    var body: some View {
        TabView(selection: selectionBinding) {
            ForEach(0 ..< OnboardingModel.cardCount, id: \.self) { index in
                page(index)
                    .tag(index)
            }
        }
        .tabViewStyle(.page(indexDisplayMode: .never))
        .background(Color(.systemGroupedBackground).ignoresSafeArea())
        // Erst hier gilt Karte 1 als gesehen — so laeuft ihre Einlauf-Staffel
        // sichtbar an, statt schon fertig zu sein.
        .onAppear { model.start() }
    }

    /// Ein Wisch geht denselben Weg wie ein Tipp — beides landet in `select`,
    /// damit die Einlauf-Staffel pro Karte genau einmal laeuft.
    private var selectionBinding: Binding<Int> {
        Binding(
            get: { model.selection },
            set: { model.select($0) }
        )
    }

    // MARK: - Eine Seite

    @ViewBuilder
    private func page(_ index: Int) -> some View {
        let appeared = model.hasSeen(index)

        VStack(spacing: 0) {
            header(index)

            // Nur die Inhaltsspalte scrollt. Kopf- und Fusszeile stehen
            // ausserhalb, damit die Aktionen bei jedem Dynamic-Type-Grad an
            // derselben Stelle bleiben und der Inhalt ab ca. AX1 nicht
            // abschneidet.
            ScrollView {
                content(index, appeared: appeared)
                    .padding(.horizontal, OnboardingSpace.gutter)
                    .padding(.bottom, OnboardingSpace.md)
            }
            .scrollBounceBehavior(.basedOnSize)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)

            footer(index, appeared: appeared)
        }
    }

    @ViewBuilder
    private func header(_ index: Int) -> some View {
        HStack {
            Spacer()
            if model.showsSkipButton(on: index) {
                // `.semibold` statt `.regular`: `oceanBlue` auf
                // `systemGroupedBackground` misst 3,17 : 1 und faellt als
                // normaler Text unter WCAG AA. Halbfett bei 17 pt zaehlt als
                // grosser Text — dort gilt die 3 : 1-Schwelle, die der Wert
                // haelt. Die Farbe bleibt damit unveraendert.
                Button(String(localized: "Überspringen")) {
                    model.skipToLastCard()
                }
                .font(.body.weight(.semibold))
                .tint(.oceanBlue)
            }
        }
        .frame(height: OnboardingMetrics.headerHeight)
        .padding(.horizontal, OnboardingSpace.gutter)
    }

    @ViewBuilder
    private func content(_ index: Int, appeared: Bool) -> some View {
        switch index {
        case 0: OnboardingWelcomeCard(appeared: appeared)
        case 1: OnboardingFeaturesCard(appeared: appeared)
        case 2: OnboardingReminderSoftAskCard(appeared: appeared)
        default: OnboardingStartCard(appeared: appeared, onSample: showSampleTrip)
        }
    }

    /// Die Aktions-Gruppe am unteren Rand. Die Seitenpunkte sitzen fest 28 pt
    /// ueber der Primaer-Aktion — sie gehoeren zur Aktions-Gruppe, nicht in die
    /// Bildmitte. Die ueberschuessige Hoehe der Seite faellt dadurch als **ein**
    /// Zwischenraum zwischen Inhaltsspalte und Aktions-Gruppe an.
    @ViewBuilder
    private func footer(_ index: Int, appeared: Bool) -> some View {
        VStack(spacing: OnboardingMetrics.dotsToAction) {
            OnboardingPageDots(count: OnboardingModel.cardCount, index: index)

            VStack(spacing: OnboardingSpace.sm) {
                actions(index, appeared: appeared)
            }
        }
        .padding(.horizontal, OnboardingSpace.gutter)
        .padding(.bottom, OnboardingSpace.md)
    }

    @ViewBuilder
    private func actions(_ index: Int, appeared: Bool) -> some View {
        switch index {
        case 0, 1:
            OnboardingPrimaryButton(title: String(localized: "Weiter")) {
                model.advance(from: index)
            }
            .onboardingCascadeIn(4, appeared: appeared)

        case 2:
            // B4-Soft-Ask: **nur** diese Taste darf den Systemdialog ausloesen.
            OnboardingPrimaryButton(title: String(localized: "Erinnerungen aktivieren")) {
                Task { await model.enableReminders() }
            }
            .onboardingCascadeIn(4, appeared: appeared)

            // „Spaeter" blaettert nur weiter — kein Systemdialog, kein Flag.
            OnboardingSecondaryButton(title: String(localized: "Später")) {
                model.skipReminders()
            }
            .onboardingCascadeIn(5, appeared: appeared)

            footnote(String(localized: "Beides lässt sich jederzeit in den Einstellungen ändern."))
                .onboardingCascadeIn(6, appeared: appeared)

        default:
            // Dieselbe Behandlung wie das Paar auf Karte 3: gefuellt ueber
            // ungefuellt, gleiche Breite, gleiche Hoehe, gleiche Kanten.
            OnboardingPrimaryButton(title: String(localized: "Erste Reise anlegen")) {
                onFinish()
            }
            .onboardingCascadeIn(3, appeared: appeared)

            OnboardingSecondaryButton(
                title: String(localized: "Beispielreise ansehen"),
                action: showSampleTrip
            )
            .onboardingCascadeIn(4, appeared: appeared)

            // Plural mit Absicht: `loadDemoData` legt drei Reisen und zwei
            // Wunschreisen an, nicht nur die gezeigte Norwegen-Reise.
            footnote(String(localized: "Die Beispieldaten sind als Demo markiert und lassen sich mit einem Tipp wieder entfernen."))
                .onboardingCascadeIn(5, appeared: appeared)
        }
    }

    private func footnote(_ text: String) -> some View {
        Text(text)
            .font(.footnote)
            .foregroundStyle(.secondary)
            .multilineTextAlignment(.center)
            .fixedSize(horizontal: false, vertical: true)
            .padding(.horizontal, OnboardingSpace.xs)
    }

    // MARK: - Aktionen der Startentscheidung

    /// Beide Traeger der zweiten Option — die Reise-Karte im Inhalt und die
    /// ungefuellte Taste in der Aktions-Gruppe — loesen dieselbe Aktion aus.
    /// Die Beispielreise entsteht ausschliesslich ueber die bestehende
    /// `DemoDataService`-API; alle Objekte tragen `isDemo` und lassen sich in
    /// den Einstellungen mit einer Aktion wieder entfernen.
    private func showSampleTrip() {
        DemoDataService.loadDemoData(into: modelContext)
        onFinish()
    }
}

// MARK: - Preview

#Preview("Onboarding") {
    OnboardingFlowView(onFinish: {})
        .modelContainer(for: [Cruise.self, Port.self, Expense.self, Deal.self], inMemory: true)
}
