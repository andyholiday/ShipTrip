//
//  ShippingLineCatalogDedup.swift
//  ShipTrip
//

import SwiftData
import Foundation
import OSLog

private let logger = Logger(subsystem: "com.andre.ShipTrip", category: "Persistence")

/// Post-Sync-Dedup für eigene Reedereien/Schiffe/ausgeblendete Katalog-Einträge (ADR-006,
/// Abschnitt 6).
///
/// **Ursache:** `CustomShippingLine`/`CustomShip`/`HiddenCatalogItem` haben keine
/// `@Attribute(.unique)`-Constraints (CloudKit erlaubt das nicht, ADR-002). Zwei Geräte können
/// offline unabhängig voneinander gleich benannte Zeilen anlegen; nach dem Sync existieren dann
/// mehrere gültige, aber kollidierende Zeilen.
///
/// **Lösung:** Beim App-Start einmalig über alle drei Typen iterieren, Duplikate deterministisch
/// zusammenführen (ältestes `createdAt` gewinnt, bei Gleichstand die lexikographisch kleinere
/// `id.uuidString`). Analog zu `IdBackfill`: synchron, `@MainActor`, idempotent, mit eigenem
/// versionierten Completed-Flag.
enum ShippingLineCatalogDedup {

    /// Versionierte UserDefaults-Flag, die einen vollständig erfolgreichen Dedup-Lauf markiert.
    /// Bei einer künftigen, grundlegend geänderten Dedup-Logik den Suffix hochzählen (z. B. `.v2`).
    static let completedFlagKey = "shippingLineCatalogDedupCompleted.v1"

    // MARK: - Public Entry Point

    /// Läuft einmalig beim App-Start und räumt kollidierende Custom-Reedereien/-Schiffe/Hidden-
    /// Einträge auf. Das Completed-Flag wird **ausschließlich** gesetzt, wenn alle drei Passes
    /// fehlerfrei geprüft wurden und ein nötiger Save erfolgreich war — sonst läuft der Dedup beim
    /// nächsten Start erneut. Läuft die App auf dem In-Memory-Fallback-Store, wird das Flag
    /// ebenfalls nicht gesetzt.
    @MainActor
    static func run(context: ModelContext, isFallbackStore: Bool? = nil, defaults: UserDefaults = .standard) {
        guard !defaults.bool(forKey: completedFlagKey) else { return }

        let usingFallbackStore = isFallbackStore
            ?? context.container.configurations.contains { $0.isStoredInMemoryOnly }

        let lineResult = dedupeLines(context: context)
        let shipResult = dedupeShips(context: context)
        let hiddenResult = dedupeHidden(context: context)

        let changed = lineResult.changed || shipResult.changed || hiddenResult.changed
        var allSucceeded = lineResult.success && shipResult.success && hiddenResult.success

        if changed {
            do {
                try context.save()
            } catch {
                logger.error("ShippingLineCatalogDedup: Speichern der bereinigten Duplikate fehlgeschlagen: \(error)")
                allSucceeded = false
            }
        }

        if shouldMarkCompleted(allSucceeded: allSucceeded, usingFallbackStore: usingFallbackStore) {
            defaults.set(true, forKey: completedFlagKey)
        }
    }

    /// Reine Entscheidung, ob das Completed-Flag gesetzt werden darf – getrennt von der
    /// eigentlichen SwiftData-I/O (analog `IdBackfill.shouldMarkCompleted`).
    static func shouldMarkCompleted(allSucceeded: Bool, usingFallbackStore: Bool) -> Bool {
        allSucceeded && !usingFallbackStore
    }

    // MARK: - Private Helpers

    /// `CustomShippingLine`-Duplikate (Kollision: `collisionKey(name)` gleich). Gewinner nach
    /// Gewinner-Regel; alle `CustomShip`-Zeilen mit `lineOptionID == "custom:<Verlierer-UUID>"`
    /// werden **vor** dem Löschen auf `"custom:<Gewinner-UUID>"` umgeschrieben.
    @MainActor
    private static func dedupeLines(context: ModelContext) -> (changed: Bool, success: Bool) {
        let lines: [CustomShippingLine]
        let ships: [CustomShip]
        do {
            lines = try context.fetch(FetchDescriptor<CustomShippingLine>())
            ships = try context.fetch(FetchDescriptor<CustomShip>())
        } catch {
            logger.error("ShippingLineCatalogDedup: Fetch für CustomShippingLine/CustomShip fehlgeschlagen: \(error)")
            return (false, false)
        }

        let groups = Dictionary(grouping: lines) { ShippingLineNameMatching.collisionKey($0.name) }
        var changed = false

        for (_, group) in groups where group.count > 1 {
            let sorted = sortedByDedupPriority(group, createdAt: { $0.createdAt }, id: { $0.id })
            guard let winner = sorted.first else { continue }
            let winnerOptionID = "custom:\(winner.id.uuidString)"

            for loser in sorted.dropFirst() {
                let loserOptionID = "custom:\(loser.id.uuidString)"
                for ship in ships where ship.lineOptionID == loserOptionID {
                    ship.lineOptionID = winnerOptionID
                    ship.updatedAt = Date()
                }
                context.delete(loser)
                changed = true
            }
        }

        return (changed, true)
    }

    /// `CustomShip`-Duplikate (Kollision: gleiche `lineOptionID` **und** gleicher
    /// `ShippingLineNameMatching.collisionKey(name)` — diakritik-insensitiv, damit z. B.
    /// "Königsklasse"/"Konigsklasse" als dasselbe Schiff erkannt werden, analog zur lokalen
    /// Kollisionsprüfung in `createCustomShip`). Gewinner nach Gewinner-Regel, Verlierer gelöscht,
    /// kein Rewiring nötig (nichts referenziert `CustomShip.id`).
    @MainActor
    private static func dedupeShips(context: ModelContext) -> (changed: Bool, success: Bool) {
        let ships: [CustomShip]
        do {
            ships = try context.fetch(FetchDescriptor<CustomShip>())
        } catch {
            logger.error("ShippingLineCatalogDedup: Fetch für CustomShip fehlgeschlagen: \(error)")
            return (false, false)
        }

        let groups = Dictionary(grouping: ships) { "\($0.lineOptionID)|\(ShippingLineNameMatching.collisionKey($0.name))" }
        var changed = false

        for (_, group) in groups where group.count > 1 {
            let sorted = sortedByDedupPriority(group, createdAt: { $0.createdAt }, id: { $0.id })
            for loser in sorted.dropFirst() {
                context.delete(loser)
                changed = true
            }
        }

        return (changed, true)
    }

    /// `HiddenCatalogItem`-Duplikate (Kollision: gleiche `lineID` **und** gleicher `shipKey`,
    /// inkl. beide `nil`). Gewinner nach Gewinner-Regel, Rest gelöscht, kein Rewiring nötig.
    @MainActor
    private static func dedupeHidden(context: ModelContext) -> (changed: Bool, success: Bool) {
        let items: [HiddenCatalogItem]
        do {
            items = try context.fetch(FetchDescriptor<HiddenCatalogItem>())
        } catch {
            logger.error("ShippingLineCatalogDedup: Fetch für HiddenCatalogItem fehlgeschlagen: \(error)")
            return (false, false)
        }

        let groups = Dictionary(grouping: items) { "\($0.lineID)|\($0.shipKey ?? "")" }
        var changed = false

        for (_, group) in groups where group.count > 1 {
            let sorted = sortedByDedupPriority(group, createdAt: { $0.createdAt }, id: { $0.id })
            for loser in sorted.dropFirst() {
                context.delete(loser)
                changed = true
            }
        }

        return (changed, true)
    }

    /// Deterministische Gewinner-Reihenfolge: ältestes `createdAt` zuerst; bei exaktem Gleichstand
    /// die lexikographisch kleinere `id.uuidString` (kein Zufall, reproduzierbar über alle Geräte).
    private static func sortedByDedupPriority<T>(_ items: [T], createdAt: (T) -> Date, id: (T) -> UUID) -> [T] {
        items.sorted { lhs, rhs in
            let lhsDate = createdAt(lhs)
            let rhsDate = createdAt(rhs)
            if lhsDate != rhsDate { return lhsDate < rhsDate }
            return id(lhs).uuidString < id(rhs).uuidString
        }
    }
}
