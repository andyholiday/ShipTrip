//
//  OnboardingModel.swift
//  ShipTrip
//
//  Zustands- und Entscheidungslogik des Erststart-Flows (Task B2).
//
//  Bewusst getrennt von den Views: die beiden Zusagen, die B2 traegt —
//  „das Onboarding erscheint genau beim ersten Start" und „der Systemdialog
//  erscheint nur nach aktiver Zustimmung" — sind hier ohne UI pruefbar.
//  Lokale Notifications lassen sich im Unit-Host nicht integrativ testen;
//  deshalb liegt die System-Abfrage hinter einer injizierbaren Naht.
//

import Foundation
import Observation
import SwiftData
import SwiftUI

// MARK: - Sichtbarkeit / Persistenz

/// Der persistente Schalter, der ueber den Erststart-Flow entscheidet.
/// Gleicher Schluessel wie das `@AppStorage` in `ShipTripApp`.
enum OnboardingPresentation {

    /// Persistenz-Schluessel. `false`/fehlend heisst: noch nicht abgeschlossen.
    static let hasCompletedKey = "hasCompletedOnboarding"

    /// Uebersetzt den persistenten Schalter in die Sichtbarkeit des Covers —
    /// genau die Naht, die `ShipTripApp` an `fullScreenCover(isPresented:)`
    /// haengt. Beim ersten Start ist der Schluessel nicht gesetzt, das
    /// Onboarding erscheint; wird das Cover geschlossen, gilt der Flow als
    /// abgeschlossen und es bleibt weg, bis `requestReplay` es zurueckholt.
    ///
    /// `isSuppressed` haelt das Cover unabhaengig vom Schalter zurueck und
    /// laesst ihn dabei unangetastet — der Fall `.postpone` aus
    /// `startupDecision`.
    static func coverBinding(hasCompleted: Binding<Bool>, isSuppressed: Bool) -> Binding<Bool> {
        Binding(
            get: { !isSuppressed && !hasCompleted.wrappedValue },
            set: { isPresented in
                guard !isSuppressed else { return }
                if !isPresented { hasCompleted.wrappedValue = true }
            }
        )
    }

    /// „Intro erneut zeigen" aus den Einstellungen.
    static func requestReplay(in defaults: UserDefaults) {
        defaults.set(false, forKey: hasCompletedKey)
    }

    // MARK: - Erststart-Entscheidung beim App-Start

    /// Wie der Start mit dem Erststart-Flow umgeht.
    enum StartupDecision: Equatable {

        /// Frische Installation — das Cover darf erscheinen.
        case present

        /// Bestandsinstallation ohne Schalter (Update von 1.7.x): still
        /// abhaken, kein Cover. Wer bereits Reisen hat, hat die App nicht
        /// zum ersten Mal in der Hand.
        case migrateSilently

        /// Kein gesunder Store (In-Memory-Fallback): weder zeigen noch
        /// abhaken. Die Datenverlust-Warnung hat Vorrang; beim naechsten
        /// gesunden Start steht der Erststart unveraendert an.
        case postpone

        /// Der Schalter steht bereits.
        case alreadyCompleted
    }

    /// Reine Entscheidung — ohne Store und ohne `UserDefaults`, damit sie ohne
    /// UI pruefbar bleibt.
    ///
    /// `hasCompletedFlag` ist bewusst dreiwertig: `nil` (Schluessel fehlt)
    /// heisst „nie durchlaufen", `false` heisst „ueber die Einstellungen
    /// zurueckgeholt". Nur der erste Fall darf still migriert werden — ein
    /// angefordertes Wiedersehen bleibt eines, auch mit vorhandenen Reisen.
    static func startupDecision(
        hasCompletedFlag: Bool?,
        storeIsHealthy: Bool,
        hasExistingCruises: Bool
    ) -> StartupDecision {
        if hasCompletedFlag == true { return .alreadyCompleted }
        guard storeIsHealthy else { return .postpone }
        if hasCompletedFlag == nil, hasExistingCruises { return .migrateSilently }
        return .present
    }
}

// MARK: - Flow-Zustand

/// Fuehrt durch die vier Karten und kapselt die Soft-Ask-Entscheidung.
@MainActor
@Observable
final class OnboardingModel {

    /// Anzahl der Karten des Flows.
    static let cardCount = 4

    /// Aktuell sichtbare Karte.
    private(set) var selection: Int

    /// Bereits gezeigte Karten. Die Einlauf-Staffel laeuft pro Karte genau
    /// einmal — beim Zurueckblaettern gibt es keinen zweiten Einlauf und keinen
    /// Zustandsverlust.
    ///
    /// Startet bewusst **leer**: die Staffel haengt an der Flanke
    /// `appeared false → true`. Waere Karte 1 hier schon als gesehen markiert,
    /// bliebe genau der erste Einlauf aus, den der Nutzer sieht.
    private(set) var seen: Set<Int> = []

    /// Laeuft gerade eine Berechtigungs-Abfrage? Solange sie laeuft, sind beide
    /// Soft-Ask-Aktionen gesperrt — ein zweiter Tipp darf keinen zweiten
    /// System-Dialog anfordern.
    private(set) var isRequestingPermission = false

    /// Naht fuer den System-Dialog. Nur `enableReminders(in:)` ruft sie.
    /// Der Rueckgabewert ist die Antwort des Nutzers im System-Dialog.
    private let requestNotificationPermission: @MainActor () async -> Bool

    /// Naht fuer den Erinnerungs-Abgleich nach erteilter Berechtigung —
    /// dieselbe Aufruf-Semantik wie die Start-Kette in `CruiseListView`.
    private let reconcileReminders: @MainActor (ModelContext) async -> Void

    init(
        requestNotificationPermission: @escaping @MainActor () async -> Bool = {
            await NotificationService.shared.requestAuthorization()
        },
        reconcileReminders: @escaping @MainActor (ModelContext) async -> Void = { context in
            await NotificationReconciler.run(context: context)
        }
    ) {
        self.requestNotificationPermission = requestNotificationPermission
        self.reconcileReminders = reconcileReminders
        self.selection = 0
    }

    // MARK: - Navigation

    /// Scharfschalten der Einlauf-Staffel fuer die Startkarte. Gehoert an
    /// `onAppear` des Flows, nicht in den Initializer.
    func start() {
        seen.insert(selection)
    }

    /// Index der letzten Karte.
    var lastIndex: Int { Self.cardCount - 1 }

    /// Ob die Karte schon einmal sichtbar war (steuert die Einlauf-Staffel).
    func hasSeen(_ index: Int) -> Bool { seen.contains(index) }

    /// Karte direkt setzen — auch der Weg, den ein Wisch nimmt.
    func select(_ index: Int) {
        guard (0 ... lastIndex).contains(index) else { return }
        selection = index
        seen.insert(index)
    }

    /// „Weiter". Auf der letzten Karte passiert nichts — der Erststart soll
    /// nicht ohne Startentscheidung enden.
    func advance(from index: Int) {
        guard index < lastIndex else { return }
        select(index + 1)
    }

    /// „Ueberspringen" springt auf die Startentscheidung, nicht aus dem Flow.
    func skipToLastCard() {
        select(lastIndex)
    }

    /// Die Kopfzeile traegt „Ueberspringen" auf allen Karten ausser der letzten.
    func showsSkipButton(on index: Int) -> Bool {
        index < lastIndex
    }

    // MARK: - Soft-Ask (Karte 3)

    /// Aktive Zustimmung: **erst hier** darf der System-Dialog erscheinen.
    /// Danach geht es weiter, unabhaengig davon, wie der Nutzer im System-
    /// Dialog entscheidet.
    ///
    /// Der Vertrag der Taste ist „Berechtigung + Replan", nicht
    /// „Toggle umlegen": die App-Schalter in `NotificationSettingsView` stehen
    /// ohnehin auf an und bleiben unangetastet. Nach **erteilter** Berechtigung
    /// laeuft der Abgleich sofort, damit bereits vorhandene Reisen ihre
    /// Erinnerungen nicht erst beim naechsten App-Start bekommen.
    ///
    /// Der `context` kommt aus der Umgebung des Flows und bleibt auf dem
    /// MainActor — es wandert kein `@Model` ueber eine Aktorgrenze.
    func enableReminders(in context: ModelContext) async {
        guard !isRequestingPermission else { return }
        isRequestingPermission = true
        defer { isRequestingPermission = false }

        if await requestNotificationPermission() {
            await reconcileReminders(context)
        }
        advance(from: 2)
    }

    /// „Spaeter": kein System-Dialog, kein Flag ausser dem Flow-Fortschritt.
    /// Die kontextuelle Abfrage beim ersten Speichern einer Reise
    /// (`CruiseFormView`) bleibt davon unberuehrt — sie prueft weiterhin
    /// selbst den `authorizationStatus` und findet ihn hier unveraendert
    /// `.notDetermined` vor.
    func skipReminders() {
        guard !isRequestingPermission else { return }
        advance(from: 2)
    }
}
