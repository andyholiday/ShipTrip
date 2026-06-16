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

    // MARK: - Public Entry Point

    /// Läuft einmalig beim App-Start und korrigiert alle doppelten UUIDs.
    /// Synchron, kein async nötig – schnelle In-Memory-Operation über FetchDescriptor.
    /// - Parameter context: Der ModelContext der aufrufenden View (MainActor).
    @MainActor
    static func run(context: ModelContext) {
        var changed = false
        changed = dedupe(Cruise.self, idKey: \.id, context: context) || changed
        changed = dedupe(Port.self,   idKey: \.id, context: context) || changed
        changed = dedupe(Expense.self, idKey: \.id, context: context) || changed
        changed = dedupe(Photo.self,  idKey: \.id, context: context) || changed
        changed = dedupe(Deal.self,   idKey: \.id, context: context) || changed

        if changed {
            do {
                try context.save()
            } catch {
                logger.error("IdBackfill: Speichern der reparierten ids fehlgeschlagen: \(error)")
            }
        }
    }

    // MARK: - Private Helpers

    /// Durchläuft alle Objekte des Typs `T` und vergibt bei Duplikaten eine neue UUID.
    /// - Returns: `true`, wenn mindestens ein Objekt geändert wurde.
    @MainActor
    private static func dedupe<T: PersistentModel>(
        _ type: T.Type,
        idKey: ReferenceWritableKeyPath<T, UUID>,
        context: ModelContext
    ) -> Bool {
        let objects: [T]
        do {
            objects = try context.fetch(FetchDescriptor<T>())
        } catch {
            logger.error("IdBackfill: Fetch für \(String(describing: T.self)) fehlgeschlagen: \(error)")
            return false
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

        return changed
    }
}
