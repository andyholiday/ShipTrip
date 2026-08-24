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
    static func coverBinding(hasCompleted: Binding<Bool>) -> Binding<Bool> {
        Binding(
            get: { !hasCompleted.wrappedValue },
            set: { isPresented in
                if !isPresented { hasCompleted.wrappedValue = true }
            }
        )
    }

    /// „Intro erneut zeigen" aus den Einstellungen.
    static func requestReplay(in defaults: UserDefaults) {
        defaults.set(false, forKey: hasCompletedKey)
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

    /// Naht fuer den System-Dialog. Nur `enableReminders()` ruft sie.
    private let requestNotificationPermission: @MainActor () async -> Void

    init(
        requestNotificationPermission: @escaping @MainActor () async -> Void = {
            _ = await NotificationService.shared.requestAuthorization()
        }
    ) {
        self.requestNotificationPermission = requestNotificationPermission
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
    func enableReminders() async {
        await requestNotificationPermission()
        advance(from: 2)
    }

    /// „Spaeter": kein System-Dialog, kein Flag ausser dem Flow-Fortschritt.
    /// Die kontextuelle Abfrage beim ersten Speichern einer Reise
    /// (`CruiseFormView`) bleibt davon unberuehrt — sie prueft weiterhin
    /// selbst den `authorizationStatus` und findet ihn hier unveraendert
    /// `.notDetermined` vor.
    func skipReminders() {
        advance(from: 2)
    }
}
