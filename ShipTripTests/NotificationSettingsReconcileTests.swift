//
//  NotificationSettingsReconcileTests.swift
//  ShipTripTests
//

import Foundation
import SwiftData
import Testing
@testable import ShipTrip

/// Repro: Eine Änderung an Toggle oder Vorlauf in den Erinnerungs-Einstellungen
/// blieb bis 1.8.7 folgenlos — die geplanten Erinnerungen wurden erst beim
/// nächsten App-Start abgeglichen. Getestet wird der aus den `onChange`-Modifiern
/// gerufene Einstiegspunkt der View, nicht die SwiftUI-Laufzeit.
@Suite("Erinnerungs-Einstellungen — sofortiger Abgleich")
@MainActor
struct NotificationSettingsReconcileTests {

    @Test("Jede Änderung einer Erinnerungs-Einstellung löst genau einen Abgleich aus")
    func settingChangeTriggersReconcile() async throws {
        let context = try makeContext()
        let counter = ReconcileCounter()
        let view = NotificationSettingsView(reconcile: { _ in counter.record() })

        #expect(counter.count == 0, "Ohne Änderung darf nichts abgeglichen werden")

        await view.settingsChanged(context: context)
        #expect(counter.count == 1, "Toggle vor der Reise gleicht nicht ab")

        await view.settingsChanged(context: context)
        #expect(counter.count == 2, "Geänderter Vorlauf gleicht nicht ab")

        await view.settingsChanged(context: context)
        #expect(counter.count == 3, "Toggle am Reisetag gleicht nicht ab")
    }

    private func makeContext() throws -> ModelContext {
        let schema = Schema([
            Cruise.self, ShipTrip.Port.self, Expense.self, Deal.self, Photo.self
        ])
        let container = try ModelContainer(
            for: schema,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        return ModelContext(container)
    }
}

/// Zählt die Abgleich-Aufrufe. Referenztyp, damit die injizierte Closure den
/// Stand über den Aufruf hinaus fortschreiben kann.
@MainActor
private final class ReconcileCounter {
    private(set) var count = 0

    func record() {
        count += 1
    }
}
