//
//  IdBackfill.swift
//  ShipTrip
//

import SwiftData
import Foundation
import OSLog

private let logger = Logger(subsystem: "com.andre.ShipTrip", category: "Persistence")

/// Repariert kollidierende UUIDs, die durch Lightweight-Migration entstanden sind.
///
/// **Ursache:** Phase 1 (v1.5.0) hat allen fünf @Model-Typen `var id: UUID = UUID()`
/// als Default-Wert gegeben. Beim Lightweight-Migration-Pfad aus Versionen < 1.5.0
/// schreibt SwiftData *denselben* Default-Wert in alle bestehenden Datensätze desselben
/// Typs → alle Alt-Objekte eines Typs teilen sich eine UUID. `ForEach` in der
/// CruiseListView rendert über `id`, was zur Mehrfachanzeige führt (Daten sind intakt,
/// nur die `id`-Werte kollidieren).
///
/// **Lösung:** Beim App-Start einmalig über jeden Typ iterieren; trifft ein Objekt auf
/// eine bereits gesehene `id`, bekommt es eine neue `UUID()`. Der erste Träger einer
/// id behält sie unverändert. Idempotent: bei bereits eindeutigen ids kein Save.
enum IdBackfill {

    /// Versionierte UserDefaults-Flag, die einen vollständig erfolgreichen Backfill-Lauf markiert.
    /// Bei einer künftigen, grundlegend geänderten Backfill-Logik den Suffix hochzählen (z.B. `.v2`),
    /// damit betroffene Installationen den Lauf einmalig wiederholen.
    static let completedFlagKey = "idBackfillCompleted.v1"

    // MARK: - Public Entry Point

    /// Läuft einmalig beim App-Start und korrigiert alle doppelten UUIDs.
    /// Synchron, kein async nötig – schnelle In-Memory-Operation über FetchDescriptor.
    ///
    /// Das Completed-Flag wird **ausschließlich** gesetzt, wenn alle fünf Modelltypen fehlerfrei
    /// geprüft wurden und ein nötiger Save erfolgreich war – sonst läuft der Backfill beim nächsten
    /// Start erneut (kein Risiko, undetektierte Duplikate dauerhaft zu überspringen). Läuft die App
    /// gerade auf dem In-Memory-Fallback-Store (siehe `ShipTripApp`), wird das Flag ebenfalls nicht
    /// gesetzt, da dieser Lauf nichts über den eigentlichen persistenten Store aussagt.
    /// - Parameters:
    ///   - context: Der ModelContext der aufrufenden View (MainActor).
    ///   - isFallbackStore: Erzwingt die Fallback-Einordnung (für Tests). `nil` = automatische
    ///     Erkennung anhand der Store-Konfiguration (`isStoredInMemoryOnly`).
    ///   - defaults: UserDefaults-Instanz für das Completed-Flag (für Tests isolierbar).
    @MainActor
    static func run(context: ModelContext, isFallbackStore: Bool? = nil, defaults: UserDefaults = .standard) {
        guard !defaults.bool(forKey: completedFlagKey) else { return }

        let usingFallbackStore = isFallbackStore
            ?? context.container.configurations.contains { $0.isStoredInMemoryOnly }

        let cruiseResult = dedupe(Cruise.self, idKey: \.id, context: context)
        let portResult = dedupe(Port.self, idKey: \.id, context: context)
        let expenseResult = dedupe(Expense.self, idKey: \.id, context: context)
        let photoResult = dedupe(Photo.self, idKey: \.id, context: context)
        let dealResult = dedupe(Deal.self, idKey: \.id, context: context)

        let changed = cruiseResult.changed || portResult.changed || expenseResult.changed
            || photoResult.changed || dealResult.changed
        var allSucceeded = cruiseResult.success && portResult.success && expenseResult.success
            && photoResult.success && dealResult.success

        if changed {
            do {
                try context.save()
            } catch {
                logger.error("IdBackfill: Speichern der reparierten ids fehlgeschlagen: \(error)")
                allSucceeded = false
            }
        }

        if shouldMarkCompleted(allSucceeded: allSucceeded, usingFallbackStore: usingFallbackStore) {
            defaults.set(true, forKey: completedFlagKey)
        }
    }

    /// Reine Entscheidung, ob das Completed-Flag gesetzt werden darf – getrennt von der
    /// eigentlichen SwiftData-I/O, damit sich der Fehler-Contract (kein Flag bei Fetch- oder
    /// Save-Fehler, kein Flag im Fallback-Store) deterministisch testen lässt, unabhängig davon,
    /// wie zuverlässig sich ein echter SwiftData-Fehler in einem Test provozieren lässt.
    static func shouldMarkCompleted(allSucceeded: Bool, usingFallbackStore: Bool) -> Bool {
        allSucceeded && !usingFallbackStore
    }

    // MARK: - Private Helpers

    /// Durchläuft alle Objekte des Typs `T` und vergibt bei Duplikaten eine neue UUID.
    /// - Returns: `changed` = mindestens ein Objekt geändert, `success` = Fetch ohne Fehler.
    @MainActor
    private static func dedupe<T: PersistentModel>(
        _ type: T.Type,
        idKey: ReferenceWritableKeyPath<T, UUID>,
        context: ModelContext
    ) -> (changed: Bool, success: Bool) {
        let objects: [T]
        do {
            objects = try context.fetch(FetchDescriptor<T>())
        } catch {
            logger.error("IdBackfill: Fetch für \(String(describing: T.self)) fehlgeschlagen: \(error)")
            return (false, false)
        }

        var seen = Set<UUID>()
        var changed = false

        for object in objects {
            let current = object[keyPath: idKey]
            if !seen.insert(current).inserted {
                // Kollision: neue, im Lauf garantiert eindeutige UUID vergeben
                var newID = UUID()
                while !seen.insert(newID).inserted { newID = UUID() }
                object[keyPath: idKey] = newID
                changed = true
            }
        }

        return (changed, true)
    }
}
