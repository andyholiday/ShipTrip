//
//  ShipTripApp.swift
//  ShipTrip
//
//  Created by Andre Book on 18.12.25.
//

import SwiftUI
import SwiftData
import OSLog

private let logger = Logger(subsystem: "com.andre.ShipTrip", category: "Persistence")

@main
struct ShipTripApp: App {

    // MARK: - Store bootstrap

    private let modelContainer: ModelContainer?
    private let usingTemporaryStore: Bool

    init() {
        let schema = Schema([
            Cruise.self,
            Port.self,
            Expense.self,
            Deal.self,
            Photo.self
        ])

        // CloudKit folgt in einem separaten Build nach verifizierter Schema-Migration (siehe ADR-002, Zwei-Schritt-Migration).
        let persistentConfig = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)

        do {
            modelContainer = try ModelContainer(for: schema, configurations: [persistentConfig])
            usingTemporaryStore = false
        } catch {
            logger.error("Persistenter Store nicht verfügbar, versuche In-Memory-Fallback: \(error)")
            let memoryConfig = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
            if let fallback = try? ModelContainer(for: schema, configurations: [memoryConfig]) {
                modelContainer = fallback
                usingTemporaryStore = true
            } else {
                logger.critical("In-Memory-Fallback ebenfalls fehlgeschlagen – App startet ohne Store.")
                modelContainer = nil
                usingTemporaryStore = false
            }
        }
    }

    // MARK: - UI

    @State private var showTemporaryStoreAlert = true

    var body: some Scene {
        WindowGroup {
            if let container = modelContainer {
                MainTabView()
                    .modelContainer(container)
                    .alert(
                        "Daten nicht verfügbar",
                        isPresented: Binding(
                            get: { usingTemporaryStore && showTemporaryStoreAlert },
                            set: { _ in showTemporaryStoreAlert = false }
                        )
                    ) {
                        Button("OK") { showTemporaryStoreAlert = false }
                    } message: {
                        Text(
                            "⚠️ Deine Daten konnten nicht geladen werden und werden in dieser Sitzung nicht gespeichert. " +
                            "Bitte starte die App neu; stelle bei Bedarf aus einem Backup (Export/Import) wieder her."
                        )
                    }
            } else {
                StoreUnavailableView()
            }
        }
    }
}

// MARK: - Fallback-Ansicht (kein Store verfügbar)

private struct StoreUnavailableView: View {
    var body: some View {
        ContentUnavailableView(
            "App kann nicht gestartet werden",
            systemImage: "exclamationmark.triangle",
            description: Text(
                "Die Datenbank konnte nicht initialisiert werden. " +
                "Bitte starte die App neu oder installiere sie neu, falls das Problem anhält."
            )
        )
    }
}
