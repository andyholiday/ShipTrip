//
//  HiddenCatalogItem.swift
//  ShipTrip
//

import SwiftData
import Foundation

/// Ausgeblendeter Katalog-Eintrag — deckt sowohl "ganze Reederei ausblenden"
/// (`shipKey == nil`) als auch "einzelnes Schiff ausblenden" (`shipKey` gesetzt) ab (ADR-006,
/// Abschnitt 1). Gilt nur für Katalog-Einträge; eigene Einträge werden statt versteckt gelöscht.
@Model
final class HiddenCatalogItem {
    // MARK: - Properties

    /// Stabile App-seitige ID (kein Unique-Constraint; CloudKit-kompatibel).
    var id: UUID = UUID()

    /// `ShippingLine.id` der betroffenen Katalog-Reederei (Reederei-Hide-Key).
    var lineID: String = ""

    /// `ShippingLine.normalizedShipKey(name)` des ausgeblendeten Schiffs; zusammen mit `lineID`
    /// bildet das den vollständigen Schiff-Hide-Key (ADR-006, Abschnitt 2). `nil`, wenn die
    /// ganze Reederei ausgeblendet ist.
    var shipKey: String?

    var createdAt: Date = Date()

    // MARK: - Initialization

    init(lineID: String, shipKey: String? = nil) {
        self.lineID = lineID
        self.shipKey = shipKey
        self.createdAt = Date()
    }
}
