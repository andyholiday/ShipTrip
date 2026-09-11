//
//  CruiseDatesSection.swift
//  ShipTrip
//

import SwiftUI

/// Start- und Enddatum plus die Reisedauer in Nächten als ein gekoppelter
/// Formularabschnitt. Die Regeln liegen in `CruiseDateTriad`; diese View ist
/// nur die Präsentation: sie sammelt die Absicht, fragt bei mehrdeutigen
/// Änderungen nach und schreibt danach die neue Triade zurück.
///
/// Startdatum verschieben: erst Ruhephase (Dialog A kommt 0,5 s nach der
/// letzten Rad-Picker-Bewegung, damit Scrollen genau eine Frage erzeugt), dann
/// Dialog A, danach Dialog B für die Routen-Daten — aber nur, wenn es dort
/// etwas zu verschieben gibt. Bezugspunkt jeder Frage ist `baselineStart`:
/// das zuletzt bestätigte Startdatum.
@MainActor
struct CruiseDatesSection: View {

    // MARK: - Bindings

    @Binding var startDate: Date
    @Binding var endDate: Date
    @Binding var nights: Int

    /// Setzt das Formular, bevor es die Daten selbst schreibt (Laden, KI-Import).
    /// Solche Setzungen fragen nichts, sie ziehen nur den Bezugspunkt nach.
    @Binding var isProgrammaticDateChange: Bool

    /// Leere Route → Dialog B entfällt.
    let routeIsEmpty: Bool

    /// Verschiebt Häfen und Seetage um N Kalendertage.
    let shiftRoute: (Int) -> Void

    // MARK: - Dialog-Zustand

    /// Genau eine Frage zur Zeit, samt Nutzlast.
    enum DatePromptPhase: Equatable {
        case idle
        case dialogA(newStart: Date)
        case dialogB(shift: Int)
        case nightsDialog(newNights: Int)

        var isDialogA: Bool { if case .dialogA = self { true } else { false } }
        var isDialogB: Bool { if case .dialogB = self { true } else { false } }
        var isNightsDialog: Bool { if case .nightsDialog = self { true } else { false } }
    }

    @State private var phase: DatePromptPhase = .idle
    /// Zuletzt bestätigter Start; `nil`, solange nichts geändert wurde.
    @State private var baselineStart: Date?
    /// Eigene Setzung (Zurücknehmen, Nächte-Dialog) – kein Nutzer-Edit.
    @State private var isAdoptingDates = false
    @State private var pendingPromptTask: Task<Void, Never>?

    private var calendar: Calendar { .current }

    // MARK: - Body

    var body: some View {
        Section("Reisezeitraum") {
            DatePicker("Startdatum", selection: $startDate, displayedComponents: .date)
            DatePicker(
                "Enddatum", selection: $endDate, in: startDate..., displayedComponents: .date
            )
            Stepper {
                LabeledContent(String(localized: "Nächte"), value: nights.formatted())
            } onIncrement: {
                requestNights(nights + 1)
            } onDecrement: {
                requestNights(max(0, nights - 1))
            }
        }
        .onChange(of: startDate) { oldValue, _ in handleStartChange(from: oldValue) }
        .onChange(of: endDate) { _, _ in handleEndChange() }
        .onDisappear { pendingPromptTask?.cancel() }
        .confirmationDialog(
            String(localized: "Startdatum verschoben"),
            isPresented: isShowingDialogA,
            titleVisibility: .visible
        ) {
            Button(String(localized: "Enddatum mitverschieben")) { applyStartChoice(.keepNights) }
            Button(String(localized: "Nächte anpassen")) { applyStartChoice(.keepEnd) }
            Button(String(localized: "Abbrechen"), role: .cancel) { restoreBaselineStart() }
        }
        .confirmationDialog(
            routeShiftTitle,
            isPresented: isShowingDialogB,
            titleVisibility: .visible
        ) {
            if case .dialogB(let shift) = phase {
                Button(String(localized: "Verschieben")) {
                    shiftRoute(shift)
                    phase = .idle
                }
            }
            Button(String(localized: "Nicht verschieben"), role: .cancel) { phase = .idle }
        }
        .confirmationDialog(
            String(localized: "Nächte geändert"),
            isPresented: isShowingNightsDialog,
            titleVisibility: .visible
        ) {
            if case .nightsDialog(let newNights) = phase {
                Button(String(localized: "Startdatum anpassen")) {
                    applyNightsChoice(.moveStart, newNights: newNights)
                }
                Button(String(localized: "Enddatum anpassen")) {
                    applyNightsChoice(.moveEnd, newNights: newNights)
                }
            }
            Button(String(localized: "Abbrechen"), role: .cancel) { phase = .idle }
        }
    }

    // MARK: - Dialog-Bindings

    /// Ein Dismiss ohne Wahl beendet die Phase nur, wenn sie noch aktiv ist –
    /// eine Antwort hat sie vorher schon weitergeschaltet.
    private var isShowingDialogA: Binding<Bool> {
        Binding(get: { phase.isDialogA },
                set: { if !$0, phase.isDialogA { restoreBaselineStart() } })
    }

    private var isShowingDialogB: Binding<Bool> {
        Binding(get: { phase.isDialogB },
                set: { if !$0, phase.isDialogB { phase = .idle } })
    }

    private var isShowingNightsDialog: Binding<Bool> {
        Binding(get: { phase.isNightsDialog },
                set: { if !$0, phase.isNightsDialog { phase = .idle } })
    }

    /// Richtung im Klartext statt eines negativen N.
    private var routeShiftTitle: String {
        guard case .dialogB(let shift) = phase else { return "" }
        let days = abs(shift)
        return shift > 0
            ? String(localized: "Hafen- und Seetag-Daten um \(days) Tage nach hinten verschieben?")
            : String(localized: "Hafen- und Seetag-Daten um \(days) Tage nach vorne verschieben?")
    }

    // MARK: - Datumsänderungen

    private func handleStartChange(from oldValue: Date) {
        guard !isProgrammaticDateChange, !isAdoptingDates else {
            adoptDates()
            return
        }
        if baselineStart == nil { baselineStart = oldValue }
        pendingPromptTask?.cancel()
        pendingPromptTask = Task {
            try? await Task.sleep(for: .milliseconds(500))
            guard !Task.isCancelled else { return }
            presentStartPrompt()
        }
    }

    /// Ein neues Enddatum ist eindeutig – die Nächte folgen ohne Rückfrage.
    private func handleEndChange() {
        isProgrammaticDateChange = false
        let triad = currentTriad.changingEnd(to: endDate, calendar: calendar)
        if nights != triad.nights { nights = triad.nights }
    }

    /// Programmatische Setzung: keine Frage, nur Bezugspunkt und Invariante nachziehen.
    private func adoptDates() {
        isProgrammaticDateChange = false
        isAdoptingDates = false
        pendingPromptTask?.cancel()
        baselineStart = startDate
        if nights != currentTriad.nights { nights = currentTriad.nights }
    }

    private func presentStartPrompt() {
        guard dayShiftSinceBaseline != 0 else { phase = .idle; return }
        phase = .dialogA(newStart: startDate)
    }

    private func applyStartChoice(_ choice: CruiseDateTriad.StartShiftChoice) {
        let shift = dayShiftSinceBaseline
        let triad = CruiseDateTriad(
            start: baselineStart ?? startDate,
            end: endDate,
            storedNights: nights,
            calendar: calendar
        ).changingStart(to: startDate, choice: choice, calendar: calendar)

        if endDate != triad.end { endDate = triad.end }
        if nights != triad.nights { nights = triad.nights }
        baselineStart = startDate
        phase = .idle

        let needsRoutePrompt = CruiseDateTriad.needsRouteShiftPrompt(
            routeIsEmpty: routeIsEmpty, dayShift: shift
        )
        guard needsRoutePrompt else { return }
        // Kurze Lücke: zwei Dialoge im selben Zyklus verschluckt UIKit.
        pendingPromptTask?.cancel()
        pendingPromptTask = Task {
            try? await Task.sleep(for: .milliseconds(350))
            guard !Task.isCancelled else { return }
            phase = .dialogB(shift: shift)
        }
    }

    /// Abbruch in Dialog A: Startdatum zurück auf den letzten bestätigten Wert.
    private func restoreBaselineStart() {
        pendingPromptTask?.cancel()
        phase = .idle
        guard let baselineStart, startDate != baselineStart else { return }
        isAdoptingDates = true
        startDate = baselineStart
    }

    // MARK: - Nächte

    private func requestNights(_ newNights: Int) {
        guard newNights != nights else { return }
        phase = .nightsDialog(newNights: newNights)
    }

    private func applyNightsChoice(_ choice: CruiseDateTriad.NightsChoice, newNights: Int) {
        let triad = currentTriad.changingNights(to: newNights, choice: choice, calendar: calendar)
        if startDate != triad.start {
            isAdoptingDates = true
            startDate = triad.start
        }
        if endDate != triad.end { endDate = triad.end }
        nights = triad.nights
        baselineStart = triad.start
        phase = .idle
    }

    // MARK: - Rechenhilfen

    private var currentTriad: CruiseDateTriad {
        CruiseDateTriad(start: startDate, end: endDate, storedNights: nights, calendar: calendar)
    }

    private var dayShiftSinceBaseline: Int {
        CruiseDateTriad.dayShift(
            from: baselineStart ?? startDate, to: startDate, calendar: calendar
        )
    }
}
