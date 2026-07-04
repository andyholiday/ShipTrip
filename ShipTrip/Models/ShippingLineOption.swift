//
//  ShippingLineOption.swift
//  ShipTrip
//

import Foundation

/// DTO für eine Reederei-Option im Picker: Katalog + eigene (+ ggf. synthetische) Reedereien
/// gemischt (ADR-006, Abschnitt 4).
struct ShippingLineOption: Identifiable, Hashable {
    enum Source: String {
        case catalog
        case custom
        case unlisted
    }

    /// Anzeige-/Diffing-Key. catalog: `ShippingLine.id` ("aida"); custom: "custom:<uuidString>";
    /// unlisted: "unlisted:<collisionKey(name)>". NICHT für Mutationen verwenden — dafür `customID`.
    let id: String
    let source: Source
    /// Nur bei `source == .custom` gesetzt. Alleiniges Ziel für `updateCustomLine`/`deleteCustomLine`.
    let customID: UUID?
    let name: String
    let logo: String
}

/// DTO für eine Schiff-Option im Picker einer bestimmten Reederei (ADR-006, Abschnitt 4).
struct ShipOption: Identifiable, Hashable {
    enum Source: String {
        case catalog
        case custom
        case unlisted
    }

    /// Anzeige-/Diffing-Key: "<lineOptionID>|<normalizedShipKey(name)>" bzw. "unlisted|<...>".
    /// NICHT für Mutationen verwenden — dafür `customID`.
    let id: String
    let source: Source
    /// Explizit mitgeführt, nicht aus `id` geparst.
    let lineOptionID: String
    /// Nur bei `source == .custom` gesetzt. Alleiniges Ziel für `updateCustomShip`/`deleteCustomShip`.
    let customID: UUID?
    let name: String
    /// true bei Katalog-Schiffen aus `ShippingLine.historicalShips` — unabhängig von `source == .unlisted`.
    let isHistorical: Bool
}

/// Fehler bei Namenskollision beim Anlegen eigener Reedereien/Schiffe (ADR-006, Abschnitt 3).
enum ShippingLineCatalogError: Error {
    case duplicateLineName
    case duplicateShipName
}
