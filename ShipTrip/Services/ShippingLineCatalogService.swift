//
//  ShippingLineCatalogService.swift
//  ShipTrip
//

import SwiftData
import Foundation

/// Merge- und Verwaltungs-Logik für Katalog- + eigene Reedereien/Schiffe (ADR-006).
///
/// Reine Funktionen (`shippingLineOptions`/`shipOptions`) haben keine `ModelContext`-Abhängigkeit —
/// Views rufen diese direkt mit ihren `@Query`-Resultaten auf; eigene Merge-Logik in Views ist
/// nicht zulässig. Schreibende Operationen benötigen einen `ModelContext` und werfen bei
/// Namenskollision (Abschnitt 3).
enum ShippingLineCatalogService {

    // MARK: - Reine Merge-/Sortier-/Filter-Funktionen

    /// Katalog + eigene Reedereien (+ ggf. `.unlisted`) gemischt, sortiert nach
    /// `ShippingLineNameMatching.collisionKey(name)`.
    /// - Parameter currentSelection: der aktuell gespeicherte Freitext (z. B. `cruise.shippingLine`).
    ///   Matcht er keine der sonst zurückgegebenen Optionen, wird eine zusätzliche `.unlisted`-Option
    ///   mit genau diesem Namen angehängt. `nil`/leer für neue Cruises/Deals.
    static func shippingLineOptions(
        customLines: [CustomShippingLine],
        hidden: [HiddenCatalogItem],
        currentSelection: String?
    ) -> [ShippingLineOption] {
        let hiddenLineIDs = Set(hidden.filter { $0.shipKey == nil }.map(\.lineID))

        var options: [ShippingLineOption] = ShippingLine.all
            .filter { !hiddenLineIDs.contains($0.id) }
            .map {
                ShippingLineOption(id: $0.id, source: .catalog, customID: nil, name: $0.name, logo: $0.logo)
            }

        options += customLines.map {
            ShippingLineOption(
                id: "custom:\($0.id.uuidString)", source: .custom, customID: $0.id, name: $0.name, logo: $0.logo
            )
        }

        if let unlisted = unlistedLineOption(currentSelection: currentSelection, existing: options) {
            options.append(unlisted)
        }

        return options.sorted { ShippingLineNameMatching.collisionKey($0.name) < ShippingLineNameMatching.collisionKey($1.name) }
    }

    /// Schiff-Optionen einer Reederei (Katalog aktiv + historisch, plus eigene, plus ggf.
    /// `.unlisted`), sortiert nach `ShippingLineNameMatching.collisionKey(name)`.
    static func shipOptions(
        for lineOptionID: String,
        customShips: [CustomShip],
        hidden: [HiddenCatalogItem],
        currentSelection: String?
    ) -> [ShipOption] {
        let hiddenShipKeys = Set(hidden.filter { $0.lineID == lineOptionID }.compactMap(\.shipKey))

        var options: [ShipOption] = []

        if let line = ShippingLine.find(byId: lineOptionID) {
            options += line.ships
                .filter { !hiddenShipKeys.contains(ShippingLine.normalizedShipKey($0)) }
                .map { catalogShipOption(name: $0, lineOptionID: lineOptionID, isHistorical: false) }

            // Historische Schiffe nur bei Bestandsschutz einblenden: nur wenn currentSelection
            // exakt auf dieses ausgemusterte Schiff matcht (Edit-Pfad einer Bestandsreise), nie
            // generell — sonst erschiene z. B. AIDAcara bei jeder neuen Reise, obwohl
            // `historicalShips` laut Katalog "nicht mehr in der Auswahl für neue Reisen" ist.
            options += line.historicalShips
                .filter { $0 == currentSelection && !hiddenShipKeys.contains(ShippingLine.normalizedShipKey($0)) }
                .map { catalogShipOption(name: $0, lineOptionID: lineOptionID, isHistorical: true) }
        }

        options += customShips
            .filter { $0.lineOptionID == lineOptionID }
            .map {
                ShipOption(
                    id: "\(lineOptionID)|\(ShippingLine.normalizedShipKey($0.name))",
                    source: .custom, lineOptionID: lineOptionID, customID: $0.id, name: $0.name, isHistorical: false
                )
            }

        if let unlisted = unlistedShipOption(lineOptionID: lineOptionID, currentSelection: currentSelection, existing: options) {
            options.append(unlisted)
        }

        return options.sorted { ShippingLineNameMatching.collisionKey($0.name) < ShippingLineNameMatching.collisionKey($1.name) }
    }

    // MARK: - Schreibende Operationen (benötigen ModelContext, werfen bei Kollision)

    static func createCustomLine(name: String, logo: String, in context: ModelContext) throws -> ShippingLineOption {
        let existingLines = try context.fetch(FetchDescriptor<CustomShippingLine>())
        guard !hasLineCollision(name: name, existingLines: existingLines) else {
            throw ShippingLineCatalogError.duplicateLineName
        }

        let line = CustomShippingLine(name: name, logo: logo)
        context.insert(line)
        try context.save()
        return ShippingLineOption(id: "custom:\(line.id.uuidString)", source: .custom, customID: line.id, name: line.name, logo: line.logo)
    }

    static func updateCustomLine(_ customID: UUID, name: String, logo: String, in context: ModelContext) throws {
        let existingLines = try context.fetch(FetchDescriptor<CustomShippingLine>())
        guard let line = existingLines.first(where: { $0.id == customID }) else { return }
        guard !hasLineCollision(name: name, existingLines: existingLines, excluding: customID) else {
            throw ShippingLineCatalogError.duplicateLineName
        }

        line.name = name
        line.logo = logo
        line.updatedAt = Date()
        try context.save()
    }

    /// Löscht die eigene Reederei und alle zugehörigen `CustomShip`-Zeilen (App-seitiges Cascade,
    /// s. ADR-006 Konsequenzen — keine `@Relationship`, daher kein automatisches SwiftData-Cascade).
    static func deleteCustomLine(_ customID: UUID, in context: ModelContext) throws {
        let existingLines = try context.fetch(FetchDescriptor<CustomShippingLine>())
        guard let line = existingLines.first(where: { $0.id == customID }) else { return }

        let lineOptionID = "custom:\(customID.uuidString)"
        let ships = try context.fetch(FetchDescriptor<CustomShip>())
        for ship in ships where ship.lineOptionID == lineOptionID {
            context.delete(ship)
        }
        context.delete(line)
        try context.save()
    }

    static func createCustomShip(name: String, lineOptionID: String, in context: ModelContext) throws -> ShipOption {
        let existingShips = try context.fetch(FetchDescriptor<CustomShip>())
        guard !hasShipCollision(name: name, lineOptionID: lineOptionID, existingShips: existingShips) else {
            throw ShippingLineCatalogError.duplicateShipName
        }

        let ship = CustomShip(name: name, lineOptionID: lineOptionID)
        context.insert(ship)
        try context.save()
        return ShipOption(
            id: "\(lineOptionID)|\(ShippingLine.normalizedShipKey(ship.name))",
            source: .custom, lineOptionID: lineOptionID, customID: ship.id, name: ship.name, isHistorical: false
        )
    }

    static func updateCustomShip(_ customID: UUID, name: String, in context: ModelContext) throws {
        let existingShips = try context.fetch(FetchDescriptor<CustomShip>())
        guard let ship = existingShips.first(where: { $0.id == customID }) else { return }
        guard !hasShipCollision(name: name, lineOptionID: ship.lineOptionID, existingShips: existingShips, excluding: customID) else {
            throw ShippingLineCatalogError.duplicateShipName
        }

        ship.name = name
        ship.updatedAt = Date()
        try context.save()
    }

    static func deleteCustomShip(_ customID: UUID, in context: ModelContext) throws {
        let ships = try context.fetch(FetchDescriptor<CustomShip>())
        guard let ship = ships.first(where: { $0.id == customID }) else { return }
        context.delete(ship)
        try context.save()
    }

    static func hideCatalogLine(lineID: String, in context: ModelContext) throws {
        let existing = try context.fetch(FetchDescriptor<HiddenCatalogItem>())
        guard !existing.contains(where: { $0.lineID == lineID && $0.shipKey == nil }) else { return }
        context.insert(HiddenCatalogItem(lineID: lineID))
        try context.save()
    }

    static func unhideCatalogLine(lineID: String, in context: ModelContext) throws {
        let existing = try context.fetch(FetchDescriptor<HiddenCatalogItem>())
        for item in existing where item.lineID == lineID && item.shipKey == nil {
            context.delete(item)
        }
        try context.save()
    }

    static func hideCatalogShip(lineID: String, shipName: String, in context: ModelContext) throws {
        let key = ShippingLine.normalizedShipKey(shipName)
        let existing = try context.fetch(FetchDescriptor<HiddenCatalogItem>())
        guard !existing.contains(where: { $0.lineID == lineID && $0.shipKey == key }) else { return }
        context.insert(HiddenCatalogItem(lineID: lineID, shipKey: key))
        try context.save()
    }

    static func unhideCatalogShip(lineID: String, shipName: String, in context: ModelContext) throws {
        let key = ShippingLine.normalizedShipKey(shipName)
        let existing = try context.fetch(FetchDescriptor<HiddenCatalogItem>())
        for item in existing where item.lineID == lineID && item.shipKey == key {
            context.delete(item)
        }
        try context.save()
    }

    // MARK: - Private Helpers

    private static func catalogShipOption(name: String, lineOptionID: String, isHistorical: Bool) -> ShipOption {
        ShipOption(
            id: "\(lineOptionID)|\(ShippingLine.normalizedShipKey(name))",
            source: .catalog, lineOptionID: lineOptionID, customID: nil, name: name, isHistorical: isHistorical
        )
    }

    private static func unlistedLineOption(currentSelection: String?, existing: [ShippingLineOption]) -> ShippingLineOption? {
        guard let currentSelection, !currentSelection.isEmpty,
              !existing.contains(where: { $0.name == currentSelection }) else { return nil }
        return ShippingLineOption(
            id: "unlisted:\(ShippingLineNameMatching.collisionKey(currentSelection))",
            source: .unlisted, customID: nil, name: currentSelection, logo: "🛳️"
        )
    }

    private static func unlistedShipOption(lineOptionID: String, currentSelection: String?, existing: [ShipOption]) -> ShipOption? {
        guard let currentSelection, !currentSelection.isEmpty,
              !existing.contains(where: { $0.name == currentSelection }) else { return nil }
        return ShipOption(
            id: "unlisted|\(ShippingLineNameMatching.collisionKey(currentSelection))",
            source: .unlisted, lineOptionID: lineOptionID, customID: nil, name: currentSelection, isHistorical: false
        )
    }

    private static func hasLineCollision(name: String, existingLines: [CustomShippingLine], excluding excludedID: UUID? = nil) -> Bool {
        let key = ShippingLineNameMatching.collisionKey(name)
        let catalogCollision = ShippingLine.all.contains { ShippingLineNameMatching.collisionKey($0.name) == key }
        if catalogCollision { return true }
        return existingLines.contains { $0.id != excludedID && ShippingLineNameMatching.collisionKey($0.name) == key }
    }

    private static func hasShipCollision(
        name: String, lineOptionID: String, existingShips: [CustomShip], excluding excludedID: UUID? = nil
    ) -> Bool {
        let key = ShippingLineNameMatching.collisionKey(name)
        if let line = ShippingLine.find(byId: lineOptionID) {
            let catalogCollision = (line.ships + line.historicalShips).contains { ShippingLineNameMatching.collisionKey($0) == key }
            if catalogCollision { return true }
        }
        return existingShips.contains {
            $0.id != excludedID && $0.lineOptionID == lineOptionID && ShippingLineNameMatching.collisionKey($0.name) == key
        }
    }
}
