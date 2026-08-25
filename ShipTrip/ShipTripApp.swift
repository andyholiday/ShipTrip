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

    /// Erststart-Entscheidung, einmal beim Start getroffen — also **vor** der
    /// ersten Praesentation des Covers.
    private let onboardingStartupDecision: OnboardingPresentation.StartupDecision

    init() {
#if DEBUG
        Self.resetOnboardingIfNeeded()
        Self.completeOnboardingIfNeeded()
#endif

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

        onboardingStartupDecision = Self.resolveOnboardingStartupDecision(
            container: modelContainer,
            usingTemporaryStore: usingTemporaryStore
        )
        // Noch in `init`, damit das `@AppStorage` des Covers den migrierten
        // Wert schon beim ersten Auswerten sieht.
        if onboardingStartupDecision == .migrateSilently {
            UserDefaults.standard.set(true, forKey: OnboardingPresentation.hasCompletedKey)
        }
    }

    // MARK: - Erststart-Entscheidung

    /// Frische Installation, Bestandsinstallation oder ungesunder Store?
    private static func resolveOnboardingStartupDecision(
        container: ModelContainer?,
        usingTemporaryStore: Bool
    ) -> OnboardingPresentation.StartupDecision {
        let flag = UserDefaults.standard
            .object(forKey: OnboardingPresentation.hasCompletedKey) as? Bool

        guard let container, !usingTemporaryStore else {
            return OnboardingPresentation.startupDecision(
                hasCompletedFlag: flag,
                storeIsHealthy: false,
                hasExistingCruises: false
            )
        }

        // Der Store wird nur befragt, wenn der Schalter ueberhaupt fehlt —
        // der normale Start kostet damit keine zusaetzliche Abfrage.
        return OnboardingPresentation.startupDecision(
            hasCompletedFlag: flag,
            storeIsHealthy: true,
            hasExistingCruises: flag == nil && hasExistingCruises(in: container)
        )
    }

    /// Billige Ja/Nein-Abfrage: hoechstens ein Objekt verlaesst den Store.
    private static func hasExistingCruises(in container: ModelContainer) -> Bool {
#if DEBUG
        // `-uiTestingResetOnboarding` stellt eine frische Installation nach.
        // Restbestaende im Simulator-Store duerfen die Bestands-Migration
        // dann nicht ausloesen, sonst haengt der Onboarding-UI-Test am Zufall.
        if ProcessInfo.processInfo.arguments.contains("-uiTestingResetOnboarding") {
            return false
        }
#endif
        let context = ModelContext(container)
        var descriptor = FetchDescriptor<Cruise>()
        descriptor.fetchLimit = 1
        return (try? context.fetch(descriptor))?.isEmpty == false
    }

#if DEBUG
    private static func cleanupDemoDataIfNeeded(in container: ModelContainer) {
        let context = ModelContext(container)
        DemoDataService.removeDemoCruisePhotos(in: context)
        try? context.save()
    }

    /// UI-Test-Naht (B5): setzt den Erststart-Schalter zurueck, bevor die Views
    /// aufgebaut werden. Nur so laesst sich der Onboarding-Flow deterministisch
    /// starten, statt vom Restzustand des Simulators abzuhaengen.
    /// Ohne das Argument bleibt der Schalter unangetastet — genau das braucht
    /// der Persistenz-Test beim zweiten Start.
    private static func resetOnboardingIfNeeded() {
        guard ProcessInfo.processInfo.arguments.contains("-uiTestingResetOnboarding") else { return }
        UserDefaults.standard.removeObject(forKey: OnboardingPresentation.hasCompletedKey)
    }

    /// Gegenstueck zur Reset-Naht (B5): markiert den Erststart als erledigt,
    /// bevor die Views aufgebaut werden. Alle bestehenden UI-Tests zielen direkt
    /// auf die Hauptansicht und wuerden auf einem frisch installierten Simulator
    /// sonst am Onboarding-Cover haengenbleiben.
    /// Bewusst ueber `UserDefaults.standard` statt ueber die NSArgumentDomain:
    /// ein Argument der Form `-hasCompletedOnboarding YES` wuerde jeden spaeteren
    /// Schreibvorgang auf den Schluessel ueberschatten.
    private static func completeOnboardingIfNeeded() {
        let arguments = ProcessInfo.processInfo.arguments
        guard arguments.contains("-uiTestingCompleteOnboarding") else { return }
        UserDefaults.standard.set(true, forKey: OnboardingPresentation.hasCompletedKey)
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

    /// Automatischer Import geteilter Reisen (ADR-007). Haelt den Zustand des
    /// laufenden/abgeschlossenen Imports; Single-Flight steckt im Coordinator.
    @State private var shareImportCoordinator = ShareImportCoordinator()

    var body: some Scene {
        WindowGroup {
            if let container = modelContainer {
                MainTabView()
                    // Das Cover haengt am **montierten** Hauptbaum: `MainTabView`
                    // bleibt aufgebaut, `CruiseListView` ebenso, und dessen
                    // `.task`-Kette (IdBackfill → NotificationReconciler →
                    // ThumbnailBackfill → ShippingLineCatalogDedup) laeuft
                    // unveraendert weiter, waehrend das Onboarding sichtbar ist.
                    //
                    // `.postpone` (In-Memory-Fallback) haelt das Cover zurueck,
                    // damit die Datenverlust-Warnung allein steht — ohne den
                    // Schalter anzufassen: beim naechsten gesunden Start steht
                    // der Erststart unveraendert an.
                    .fullScreenCover(
                        isPresented: OnboardingPresentation.coverBinding(
                            hasCompleted: $hasCompletedOnboarding,
                            isSuppressed: onboardingStartupDecision == .postpone
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
                    // Share-Import (ADR-007/C6): Einstieg und Ergebnis-Sheet haengen
                    // ebenfalls **oberhalb** von `.modelContainer` — aus demselben
                    // Grund wie das Cover darueber. Der Kontext wird dem Coordinator
                    // ausdruecklich als `container.mainContext` mitgegeben, damit die
                    // Mutation im selben Store landet wie der Hauptbaum.
                    .sheet(
                        item: Binding(
                            get: { ShareImportPresentation(state: shareImportCoordinator.state) },
                            set: { if $0 == nil { shareImportCoordinator.dismiss() } }
                        )
                    ) { presentation in
                        ShareImportResultSheet(presentation: presentation) {
                            shareImportCoordinator.dismiss()
                        }
                    }
                    // Datei-Oeffnen (.shiptrip) und `shiptrip://import` laufen beide
                    // hierdurch — Kalt- und Warmstart identisch (C3).
                    .onOpenURL { url in
                        shareImportCoordinator.handleIncomingURL(
                            url, modelContext: container.mainContext
                        )
                    }
                    // Bewusst **nach** dem Cover: eine Praesentation erbt die
                    // Umgebung an der Stelle ihres Modifiers, nicht die der
                    // modifizierten Ansicht. Stand `.modelContainer` darueber,
                    // bekam der Onboarding-Flow einen Ersatz-Kontext ohne Store
                    // — „Beispielreise ansehen" schrieb die Beispieldaten ins
                    // Leere (kein Fehler, keine Reise in der Liste) und der
                    // Soft-Ask glich Erinnerungen gegen einen leeren Kontext ab.
                    // Hier unten liegt der Container ueber allem, was darueber
                    // haengt: Hauptbaum, Cover und Alert teilen denselben
                    // `mainContext`.
                    .modelContainer(container)
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
