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

    /// Priorisierte Cover-Kandidaten: schiffsspezifisches Cover vor stabilem Reederei-Pool,
    /// Legacy-Reederei-Cover und neutralem Ocean-Fallback.
    /// Findet der Katalog-Lookup (`find(byName:)`/`findByShipName`) keine Reederei — z. B. bei
    /// eigenen Reedereien/Schiffen, aber auch bei Katalog-Namen mit Tippfehler/Variante wie
    /// „Cunard Line" + „Queen-Mary 2" —, greift zuerst weiterhin der namensbasierte
    /// `cover_ship_<slug>`-Legacy-Kandidat (falls das Asset existiert, z. B. `cover_ship_queen_mary_2`),
    /// erst danach ein namensbasiert zugelostes Stock-Cover aus `stockCoverPool`, statt direkt auf
    /// `cover_ocean_route` zu springen. Achtung: eine Umbenennung der Reederei/des Schiffs kann
    /// dadurch das zugeloste Cover ändern.
    static func coverAssetCandidates(shippingLine: String, ship: String, context: String = "") -> [String] {
        var candidates: [String] = []

        if let line = find(byName: shippingLine) ?? findByShipName(ship) {
            let shipAsset = shipCoverAssetName(for: ship)
            let hasExactCatalogShip = findByShipName(ship) != nil
            if hasExactCatalogShip, let shipAsset {
                candidates.append(shipAsset)
            }
            candidates.append(line.coverPoolAssetName(for: ship))
            candidates.append(line.coverAssetName)
            if !hasExactCatalogShip, let shipAsset {
                candidates.append(shipAsset)
            }
        } else {
            if let shipAsset = shipCoverAssetName(for: ship) {
                candidates.append(shipAsset)
            }
            if let stockAsset = stockCoverAssetName(shippingLine: shippingLine, ship: ship, context: context) {
                candidates.append(stockAsset)
            }
        }

        candidates.append("cover_ocean_route")
        return Array(dictOrderedKeys: candidates)
    }

    /// Eingefrorener Pool aller 70 Reederei-Cover-Assets (14 Katalog-Reedereien × 5 Varianten) und
    /// 114 vorhandenen schiffsspezifischen Cover als
    /// feste Liste — bewusst NICHT dynamisch aus `all`/`coverPoolAssetNames` abgeleitet, damit die
    /// `hash % count`-Zuordnung für eigene Reedereien/Schiffe stabil bleibt, auch wenn der Katalog
    /// später um weitere Reedereien erweitert wird.
    static let stockCoverPool: [String] = [
        "cover_line_meinschiff_1", "cover_line_meinschiff_2", "cover_line_meinschiff_3", "cover_line_meinschiff_4", "cover_line_meinschiff_5",
        "cover_line_aida_1", "cover_line_aida_2", "cover_line_aida_3", "cover_line_aida_4", "cover_line_aida_5",
        "cover_line_costa_1", "cover_line_costa_2", "cover_line_costa_3", "cover_line_costa_4", "cover_line_costa_5",
        "cover_line_msc_1", "cover_line_msc_2", "cover_line_msc_3", "cover_line_msc_4", "cover_line_msc_5",
        "cover_line_phoenix_1", "cover_line_phoenix_2", "cover_line_phoenix_3", "cover_line_phoenix_4", "cover_line_phoenix_5",
        "cover_line_royalcaribbean_1", "cover_line_royalcaribbean_2", "cover_line_royalcaribbean_3", "cover_line_royalcaribbean_4", "cover_line_royalcaribbean_5",
        "cover_line_carnival_1", "cover_line_carnival_2", "cover_line_carnival_3", "cover_line_carnival_4", "cover_line_carnival_5",
        "cover_line_ncl_1", "cover_line_ncl_2", "cover_line_ncl_3", "cover_line_ncl_4", "cover_line_ncl_5",
        "cover_line_celebrity_1", "cover_line_celebrity_2", "cover_line_celebrity_3", "cover_line_celebrity_4", "cover_line_celebrity_5",
        "cover_line_hapag_1", "cover_line_hapag_2", "cover_line_hapag_3", "cover_line_hapag_4", "cover_line_hapag_5",
        "cover_line_cunard_1", "cover_line_cunard_2", "cover_line_cunard_3", "cover_line_cunard_4", "cover_line_cunard_5",
        "cover_line_princess_1", "cover_line_princess_2", "cover_line_princess_3", "cover_line_princess_4", "cover_line_princess_5",
        "cover_line_disney_1", "cover_line_disney_2", "cover_line_disney_3", "cover_line_disney_4", "cover_line_disney_5",
        "cover_line_virgin_1", "cover_line_virgin_2", "cover_line_virgin_3", "cover_line_virgin_4", "cover_line_virgin_5",
        "cover_ship_aidaaura", "cover_ship_aidabella", "cover_ship_aidablu", "cover_ship_aidacara",
        "cover_ship_aidacosma", "cover_ship_aidadiva", "cover_ship_aidaluna", "cover_ship_aidamar",
        "cover_ship_aidanova", "cover_ship_aidaperla", "cover_ship_aidaprima", "cover_ship_aidasol",
        "cover_ship_aidastella", "cover_ship_aidavita", "cover_ship_allure_of_the_seas", "cover_ship_amadea",
        "cover_ship_amera", "cover_ship_anthem_of_the_seas", "cover_ship_artania", "cover_ship_brilliant_lady",
        "cover_ship_carnival_celebration", "cover_ship_carnival_firenze", "cover_ship_carnival_jubilee", "cover_ship_carnival_venezia",
        "cover_ship_celebrity_apex", "cover_ship_celebrity_ascent", "cover_ship_celebrity_beyond", "cover_ship_celebrity_eclipse",
        "cover_ship_celebrity_edge", "cover_ship_celebrity_reflection", "cover_ship_celebrity_silhouette", "cover_ship_celebrity_xcel",
        "cover_ship_costa_deliziosa", "cover_ship_costa_diadema", "cover_ship_costa_fascinosa", "cover_ship_costa_favolosa",
        "cover_ship_costa_firenze", "cover_ship_costa_fortuna", "cover_ship_costa_pacifica", "cover_ship_costa_serena",
        "cover_ship_costa_smeralda", "cover_ship_costa_toscana", "cover_ship_deutschland", "cover_ship_discovery_princess",
        "cover_ship_disney_adventure", "cover_ship_disney_destiny", "cover_ship_disney_dream", "cover_ship_disney_fantasy",
        "cover_ship_disney_magic", "cover_ship_disney_treasure", "cover_ship_disney_wish", "cover_ship_disney_wonder",
        "cover_ship_enchanted_princess", "cover_ship_europa", "cover_ship_europa_2", "cover_ship_hanseatic_inspiration",
        "cover_ship_hanseatic_nature", "cover_ship_hanseatic_spirit", "cover_ship_harmony_of_the_seas", "cover_ship_icon_of_the_seas",
        "cover_ship_majestic_princess", "cover_ship_mardi_gras", "cover_ship_mein_schiff_1", "cover_ship_mein_schiff_2",
        "cover_ship_mein_schiff_3", "cover_ship_mein_schiff_4", "cover_ship_mein_schiff_5", "cover_ship_mein_schiff_6",
        "cover_ship_mein_schiff_7", "cover_ship_mein_schiff_flow", "cover_ship_mein_schiff_herz", "cover_ship_mein_schiff_relax",
        "cover_ship_msc_bellissima", "cover_ship_msc_divina", "cover_ship_msc_euribia", "cover_ship_msc_fantasia",
        "cover_ship_msc_grandiosa", "cover_ship_msc_meraviglia", "cover_ship_msc_preziosa", "cover_ship_msc_seascape",
        "cover_ship_msc_seashore", "cover_ship_msc_seaside", "cover_ship_msc_splendida", "cover_ship_msc_virtuosa",
        "cover_ship_msc_world_america", "cover_ship_msc_world_europa", "cover_ship_norwegian_aqua", "cover_ship_norwegian_bliss",
        "cover_ship_norwegian_breakaway", "cover_ship_norwegian_encore", "cover_ship_norwegian_escape", "cover_ship_norwegian_joy",
        "cover_ship_norwegian_luna", "cover_ship_norwegian_prima", "cover_ship_norwegian_viva", "cover_ship_oasis_of_the_seas",
        "cover_ship_odyssey_of_the_seas", "cover_ship_queen_anne", "cover_ship_queen_elizabeth", "cover_ship_queen_mary_2",
        "cover_ship_queen_victoria", "cover_ship_regal_princess", "cover_ship_resilient_lady", "cover_ship_royal_princess",
        "cover_ship_scarlet_lady", "cover_ship_sky_princess", "cover_ship_spectrum_of_the_seas", "cover_ship_star_of_the_seas",
        "cover_ship_star_princess", "cover_ship_sun_princess", "cover_ship_symphony_of_the_seas", "cover_ship_utopia_of_the_seas",
        "cover_ship_valiant_lady", "cover_ship_wonder_of_the_seas",
    ]

    /// Deterministisches Stock-Cover für eine eigene (im Katalog nicht gefundene) Reederei/Schiff-
    /// Kombination, gewählt aus `stockCoverPool`. `nil`, wenn beide Namen leer sind.
    private static func stockCoverAssetName(shippingLine: String, ship: String, context: String) -> String? {
        let normalizedLine = coverSlug(for: shippingLine)
        let normalizedShip = coverSlug(for: ship)
        guard !normalizedLine.isEmpty || !normalizedShip.isEmpty else { return nil }
        let normalizedContext = coverSlug(for: context)
        let key = [normalizedLine, normalizedShip, normalizedContext]
            .filter { !$0.isEmpty }
            .joined(separator: "::")
        // Aufrufe ohne Reise-/Ortskontext behalten die bisherige 70er-Zuordnung bei;
        // reale Reisen und Wunschreisen nutzen den erweiterten, vielfältigeren Pool.
        let poolCount = normalizedContext.isEmpty ? 70 : stockCoverPool.count
        let index = Int(fnv1aHash(key) % UInt64(poolCount))
        return stockCoverPool[index]
    }

    /// Feste eigene FNV-1a-64-Implementierung statt Swift-`Hasher`: `Hasher` ist pro Prozessstart
    /// zufällig geseedet und daher nicht launch-stabil, würde also bei jedem App-Start ein anderes
    /// Stock-Cover zulosen.
    private static func fnv1aHash(_ value: String) -> UInt64 {
        var hash: UInt64 = 0xcbf29ce484222325
        let prime: UInt64 = 0x100000001b3
        for byte in value.utf8 {
            hash ^= UInt64(byte)
            hash = hash &* prime
        }
        return hash
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
