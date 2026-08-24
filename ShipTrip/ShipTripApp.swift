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
            Photo.self,
            CustomShippingLine.self,
            CustomShip.self,
            HiddenCatalogItem.self
        ])

        let persistentConfig = ShipTripCloudSync.persistentConfiguration(for: schema)

        do {
            let container = try ModelContainer(for: schema, configurations: [persistentConfig])
#if DEBUG
            Self.cleanupDemoDataIfNeeded(in: container)
            Self.prepareUITestDataIfNeeded(in: container)
#endif
            modelContainer = container
            usingTemporaryStore = false
        } catch {
            logger.error("Persistenter Store nicht verfügbar, versuche In-Memory-Fallback: \(error)")
            let memoryConfig = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
            if let fallback = try? ModelContainer(for: schema, configurations: [memoryConfig]) {
#if DEBUG
                Self.cleanupDemoDataIfNeeded(in: fallback)
                Self.prepareUITestDataIfNeeded(in: fallback)
#endif
                modelContainer = fallback
                usingTemporaryStore = true
            } else {
                logger.critical("In-Memory-Fallback ebenfalls fehlgeschlagen – App startet ohne Store.")
                modelContainer = nil
                usingTemporaryStore = false
            }
        }
    }

#if DEBUG
    private static func cleanupDemoDataIfNeeded(in container: ModelContainer) {
        let context = ModelContext(container)
        DemoDataService.removeDemoCruisePhotos(in: context)
        try? context.save()
    }

    private static func prepareUITestDataIfNeeded(in container: ModelContainer) {
        guard ProcessInfo.processInfo.arguments.contains("-uiTestingResetAndLoadDemoData") else { return }

        let context = ModelContext(container)
        do {
            try DemoDataService.resetAndLoadDemoDataForUITesting(in: context)
        } catch {
            fatalError("UI-Testdaten konnten nicht zurückgesetzt werden: \(error)")
        }
    }

#endif

    // MARK: - UI

    @State private var showTemporaryStoreAlert = true

    /// Erststart-Flow (B2). `false`/fehlend heisst: das Onboarding steht noch aus.
    /// „Intro erneut zeigen" in den Einstellungen setzt den Schalter zurueck —
    /// deshalb steuert er die Praesentation direkt statt ueber einen
    /// abgeleiteten `@State`.
    @AppStorage(OnboardingPresentation.hasCompletedKey) private var hasCompletedOnboarding = false

    var body: some Scene {
        WindowGroup {
            if let container = modelContainer {
                MainTabView()
                    .modelContainer(container)
                    // Das Cover haengt am **montierten** Hauptbaum: `MainTabView`
                    // bleibt aufgebaut, `CruiseListView` ebenso, und dessen
                    // `.task`-Kette (IdBackfill → NotificationReconciler →
                    // ThumbnailBackfill → ShippingLineCatalogDedup) laeuft
                    // unveraendert weiter, waehrend das Onboarding sichtbar ist.
                    //
                    // Nach `.modelContainer`, damit der Flow den `modelContext`
                    // fuer die Beispielreise aus der Umgebung erbt.
                    .fullScreenCover(
                        isPresented: Binding(
                            get: { !hasCompletedOnboarding },
                            set: { isPresented in
                                if !isPresented { hasCompletedOnboarding = true }
                            }
                        )
                    ) {
                        OnboardingFlowView { hasCompletedOnboarding = true }
                    }
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
