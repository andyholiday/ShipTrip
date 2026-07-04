//
//  CustomShippingLine.swift
//  ShipTrip
//

import SwiftData
import Foundation

/// Eigene, vom Nutzer angelegte Reederei — Overlay über dem hartkodierten `ShippingLine`-Katalog
/// (ADR-006). Flach, keine Relationships, CloudKit-konform.
@Model
final class CustomShippingLine {
    // MARK: - Properties

    /// Stabile App-seitige ID (kein Unique-Constraint; CloudKit-kompatibel). Alleiniges Ziel für
    /// `updateCustomLine`/`deleteCustomLine` — niemals der zusammengesetzte DTO-`id`-String.
    var id: UUID = UUID()

    var name: String = ""

    /// Emoji-Logo, analog zum Katalog-Feld `ShippingLine.logo`. Kein Logo-Upload in dieser Welle
    /// (ADR-006, Non-Goal).
    var logo: String = "🚢"

    var createdAt: Date = Date()

    /// Letztes Änderungsdatum (für Last-Writer-Wins bei CloudKit-Sync, ADR-002).
    var updatedAt: Date = Date()

    // MARK: - Initialization

    init(name: String, logo: String = "🚢") {
        self.name = name
        self.logo = logo
        self.createdAt = Date()
        self.updatedAt = Date()
    }
}
