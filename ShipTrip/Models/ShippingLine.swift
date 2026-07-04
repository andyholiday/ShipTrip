//
//  ShippingLine.swift
//  ShipTrip
//
//  Created by ShipTrip on 18.12.25.
//

import Foundation

/// Reederei/Kreuzfahrt-Unternehmen
struct ShippingLine: Identifiable, Hashable {
    let id: String
    let name: String
    let logo: String  // Emoji
    let ships: [String]  // Aktive Schiffe — Auswahl für neue Reisen
    /// Ausgemusterte/abgegebene Schiffe — nicht mehr in der Auswahl für neue Reisen,
    /// aber für Bestandsreisen aus der Vergangenheit erhalten.
    let historicalShips: [String]

    init(id: String, name: String, logo: String, ships: [String], historicalShips: [String] = []) {
        self.id = id
        self.name = name
        self.logo = logo
        self.ships = ships
        self.historicalShips = historicalShips
    }

    /// Alle verfügbaren Reedereien mit ihren Schiffen
    static let all: [ShippingLine] = [
        ShippingLine(id: "meinschiff", name: "TUI Cruises - Mein Schiff", logo: "🚢", ships: [
            "Mein Schiff 1", "Mein Schiff 2", "Mein Schiff 3", "Mein Schiff 4",
            "Mein Schiff 5", "Mein Schiff 6", "Mein Schiff 7", "Mein Schiff Relax", "Mein Schiff Flow"
        ], historicalShips: [
            "Mein Schiff Herz"
        ]),
        ShippingLine(id: "aida", name: "AIDA Cruises", logo: "💋", ships: [
            "AIDAcosma", "AIDAprima", "AIDAperla", "AIDAnova", "AIDAmar", "AIDAblu",
            "AIDAsol", "AIDAluna", "AIDAbella", "AIDAdiva", "AIDAstella"
        ], historicalShips: [
            "AIDAcara", "AIDAvita", "AIDAaura"
        ]),
        ShippingLine(id: "costa", name: "Costa Kreuzfahrten", logo: "🌊", ships: [
            "Costa Toscana", "Costa Smeralda", "Costa Pacifica", "Costa Fortuna",
            "Costa Fascinosa", "Costa Favolosa", "Costa Diadema", "Costa Serena", "Costa Deliziosa"
        ], historicalShips: [
            "Costa Firenze"
        ]),
        ShippingLine(id: "msc", name: "MSC Cruises", logo: "⚓", ships: [
            "MSC World Europa", "MSC World America", "MSC Seascape", "MSC Seashore", "MSC Virtuosa",
            "MSC Grandiosa", "MSC Euribia", "MSC Bellissima", "MSC Meraviglia", "MSC Seaside",
            "MSC Preziosa", "MSC Divina", "MSC Fantasia", "MSC Splendida"
        ]),
        ShippingLine(id: "phoenix", name: "Phoenix Reisen", logo: "🐦", ships: [
            "Artania", "Amadea", "Amera", "Deutschland"
        ]),
        ShippingLine(id: "royalcaribbean", name: "Royal Caribbean", logo: "👑", ships: [
            "Icon of the Seas", "Star of the Seas", "Utopia of the Seas", "Wonder of the Seas",
            "Symphony of the Seas", "Harmony of the Seas", "Allure of the Seas", "Oasis of the Seas",
            "Odyssey of the Seas", "Spectrum of the Seas", "Anthem of the Seas"
        ]),
        ShippingLine(id: "carnival", name: "Carnival Cruise Line", logo: "🎉", ships: [
            "Carnival Jubilee", "Carnival Celebration", "Mardi Gras", "Carnival Venezia", "Carnival Firenze"
        ]),
        ShippingLine(id: "ncl", name: "Norwegian Cruise Line", logo: "🇳🇴", ships: [
            "Norwegian Aqua", "Norwegian Luna", "Norwegian Prima", "Norwegian Viva",
            "Norwegian Encore", "Norwegian Joy", "Norwegian Bliss", "Norwegian Escape", "Norwegian Breakaway"
        ]),
        ShippingLine(id: "celebrity", name: "Celebrity Cruises", logo: "⭐", ships: [
            "Celebrity Xcel", "Celebrity Ascent", "Celebrity Beyond", "Celebrity Apex", "Celebrity Edge",
            "Celebrity Silhouette", "Celebrity Reflection", "Celebrity Eclipse"
        ]),
        ShippingLine(id: "hapag", name: "Hapag-Lloyd Cruises", logo: "🔵", ships: [
            "Europa", "Europa 2", "Hanseatic nature", "Hanseatic inspiration", "Hanseatic spirit"
        ]),
        ShippingLine(id: "cunard", name: "Cunard", logo: "🎩", ships: [
            "Queen Mary 2", "Queen Victoria", "Queen Elizabeth", "Queen Anne"
        ]),
        ShippingLine(id: "princess", name: "Princess Cruises", logo: "👸", ships: [
            "Star Princess", "Sun Princess", "Discovery Princess", "Enchanted Princess", "Sky Princess",
            "Majestic Princess", "Regal Princess", "Royal Princess"
        ]),
        ShippingLine(id: "disney", name: "Disney Cruise Line", logo: "🏰", ships: [
            "Disney Wish", "Disney Treasure", "Disney Destiny", "Disney Adventure",
            "Disney Fantasy", "Disney Dream", "Disney Wonder", "Disney Magic"
        ]),
        ShippingLine(id: "virgin", name: "Virgin Voyages", logo: "🔴", ships: [
            "Scarlet Lady", "Valiant Lady", "Resilient Lady", "Brilliant Lady"
        ]),
    ]

    /// Findet eine Reederei anhand des Namens
    static func find(byName name: String) -> ShippingLine? {
        all.first { $0.name.lowercased() == name.lowercased() }
    }

    /// Findet eine Reederei anhand der ID
    static func find(byId id: String) -> ShippingLine? {
        all.first { $0.id == id }
    }

    /// Normalisiert einen Schiffsnamen für den Vergleich: kleingeschrieben, getrimmt,
    /// Leerzeichen entfernt. Aus `findByShipName` extrahiert (kein Verhaltenswechsel), damit
    /// derselbe Hidden-Key auch von `HiddenCatalogItem`/`ShippingLineCatalogService` genutzt
    /// werden kann (ADR-006, Abschnitt 2) — bewusst NICHT diakritik-insensitiv, damit Hidden-Keys
    /// 1:1 kompatibel mit diesem bestehenden Katalog-Matching bleiben.
    static func normalizedShipKey(_ name: String) -> String {
        name.lowercased()
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: " ", with: "")
    }

    /// Findet eine Reederei anhand des Schiffsnamens (aktive und historische Flotte).
    /// Whitespace wird beim Vergleich ignoriert, damit z. B. eine KI-Erfassung mit
    /// "AIDA Stella" weiterhin auf "AIDAstella" matcht.
    static func findByShipName(_ ship: String) -> ShippingLine? {
        let normalizedShip = normalizedShipKey(ship)
        return all.first { line in
            (line.ships + line.historicalShips).contains {
                normalizedShipKey($0) == normalizedShip
            }
        }
    }

    /// Asset-Name für das Reederei-Cover.
    var coverAssetName: String {
        "cover_line_\(id)"
    }

    /// Fünf fotorealistische Cover-Varianten pro Reederei.
    var coverPoolAssetNames: [String] {
        (1...5).map { "cover_line_\(id)_\($0)" }
    }

    /// Stabiler, schiffsgebundener Cover-Slot innerhalb der Reederei.
    func coverPoolAssetName(for ship: String) -> String {
        let anchor = ship.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? name : ship
        let index = Self.stableIndex(for: "\(id)|\(Self.coverSlug(for: anchor))", count: coverPoolAssetNames.count)
        return coverPoolAssetNames[index]
    }

    /// Asset-Name für ein schiffsspezifisches Cover.
    static func shipCoverAssetName(for ship: String) -> String? {
        let normalizedShip = ship.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalizedShip.isEmpty else { return nil }
        return "cover_ship_\(coverSlug(for: normalizedShip))"
    }

    /// Priorisierte Cover-Kandidaten: stabiler Reederei-Pool vor Legacy-Covern vor neutralem Ocean-Fallback.
    static func coverAssetCandidates(shippingLine: String, ship: String) -> [String] {
        var candidates: [String] = []

        if let line = find(byName: shippingLine) ?? findByShipName(ship) {
            candidates.append(line.coverPoolAssetName(for: ship))
            candidates.append(line.coverAssetName)
        }

        if let shipAsset = shipCoverAssetName(for: ship) {
            candidates.append(shipAsset)
        }

        candidates.append("cover_ocean_route")
        return Array(dictOrderedKeys: candidates)
    }

    /// Stabiler Asset-Slug, passend zu den generierten Cover-Namen.
    private static func coverSlug(for value: String) -> String {
        let folded = value
            .folding(options: [.caseInsensitive, .diacriticInsensitive], locale: Locale(identifier: "en_US_POSIX"))
            .lowercased()
        return folded
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { !$0.isEmpty }
            .joined(separator: "_")
    }

    private static func stableIndex(for value: String, count: Int) -> Int {
        guard count > 0 else { return 0 }
        let checksum = value.unicodeScalars.reduce(0) { partial, scalar in
            (partial &* 31 &+ Int(scalar.value)) & 0x7fffffff
        }
        return checksum % count
    }
}

private extension Array where Element == String {
    init(dictOrderedKeys keys: [String]) {
        var seen = Set<String>()
        self = keys.filter { seen.insert($0).inserted }
    }
}

/// Kollisions-/Sortier-Normalisierung für eigene Reedereien/Schiffe (ADR-006, Abschnitt 2).
/// Getrennt von `ShippingLine.normalizedShipKey(_:)`, weil hier zusätzlich diakritik-insensitiv
/// verglichen wird (z. B. "Königsklasse" vs. "Konigsklasse" gelten als Namenskollision), während
/// der Hidden-Key exakt mit dem bestehenden Katalog-Matching kompatibel bleiben muss.
enum ShippingLineNameMatching {
    /// Kollisions-/Sortier-Key: getrimmt, diakritik- und case-insensitiv gefaltet. Verwendet für
    /// Namenskollisionsprüfung (Anlegen eigener Reedereien/Schiffe), die Sortierung in
    /// `ShippingLineCatalogService` und die Gewinner-/Duplikat-Erkennung im Post-Sync-Dedup.
    static func collisionKey(_ name: String) -> String {
        name.trimmingCharacters(in: .whitespacesAndNewlines)
            .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
    }
}
