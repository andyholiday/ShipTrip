//
//  CustomShip.swift
//  ShipTrip
//

import SwiftData
import Foundation

/// Eigenes, vom Nutzer angelegtes Schiff — Overlay über dem hartkodierten `ShippingLine`-Katalog
/// (ADR-006). Flach, keine Relationships, CloudKit-konform.
@Model
final class CustomShip {
    // MARK: - Properties

    /// Stabile App-seitige ID (kein Unique-Constraint; CloudKit-kompatibel). Alleiniges Ziel für
    /// `updateCustomShip`/`deleteCustomShip` — niemals der zusammengesetzte DTO-`id`-String.
    var id: UUID = UUID()

    var name: String = ""

    /// String-Referenz auf die zugehörige Reederei — Katalog (z. B. `"aida"`) oder eigene
    /// Reederei (`"custom:<UUID>"`). Bewusst kein `@Relationship`: ein Schiff kann einer
    /// Katalog-Reederei zugeordnet sein, und `ShippingLine` ist kein `PersistentModel`
    /// (ADR-006, Abschnitt 1).
    var lineOptionID: String = ""

    var createdAt: Date = Date()

    /// Letztes Änderungsdatum (für Last-Writer-Wins bei CloudKit-Sync, ADR-002).
    var updatedAt: Date = Date()

    // MARK: - Initialization

    init(name: String, lineOptionID: String) {
        self.name = name
        self.lineOptionID = lineOptionID
        self.createdAt = Date()
        self.updatedAt = Date()
    }
}
