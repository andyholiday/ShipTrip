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

    /// Stabiler Foto-Slot, der bei realen Reisen zusätzlich deren Route/Ziel berücksichtigt.
    func coverPoolAssetName(for ship: String, context: String) -> String {
        let normalizedContext = Self.coverSlug(for: context)
        guard !normalizedContext.isEmpty else { return coverPoolAssetName(for: ship) }
        let anchor = ship.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? name : ship
        let key = "\(id)|\(Self.coverSlug(for: anchor))|\(normalizedContext)"
        return coverPoolAssetNames[Self.stableIndex(for: key, count: coverPoolAssetNames.count)]
    }

    /// Asset-Name für ein schiffsspezifisches Cover.
    static func shipCoverAssetName(for ship: String) -> String? {
        let normalizedShip = ship.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalizedShip.isEmpty else { return nil }
        return "cover_ship_\(coverSlug(for: normalizedShip))"
    }

    /// Priorisierte Cover-Kandidaten für große Hero-Flächen.
    /// Ausschließlich explizit kuratierte Foto-Assets sind zulässig; die stilisierten
    /// `cover_ship_*`, unsuffigierten `cover_line_*` und `cover_ocean_route` bleiben bewusst
    /// außerhalb dieses Pfads. Reise-/Zielkontext kann ein passendes Regionsfoto voranstellen.
    static func coverAssetCandidates(shippingLine: String, ship: String, context: String = "") -> [String] {
        var candidates: [String] = []
        let routePhoto = routePhotoAssetName(context: context)
        let shipAsset = shipCoverAssetName(for: ship)
        let curatedShipPhoto = shipAsset.flatMap { curatedShipCoverAssets.contains($0) ? $0 : nil }

        if let line = find(byName: shippingLine) ?? findByShipName(ship) {
            if let curatedShipPhoto { candidates.append(curatedShipPhoto) }
            if let routePhoto { candidates.append(routePhoto) }
            candidates.append(line.coverPoolAssetName(for: ship, context: context))
        } else {
            if let curatedShipPhoto { candidates.append(curatedShipPhoto) }
            if let routePhoto { candidates.append(routePhoto) }
            if let stockAsset = stockCoverAssetName(shippingLine: shippingLine, ship: ship, context: context) {
                candidates.append(stockAsset)
            }
        }

        if candidates.isEmpty {
            candidates.append(stockCoverPool[0])
        }
        return Array(dictOrderedKeys: candidates)
    }

    /// Eingefrorener Pool aus 70 fotografischen Reederei-Covern (14 × 5 Varianten) und drei
    /// einzeln visuell geprüften schiffsspezifischen Fotos. Die übrigen 111 `cover_ship_*`-Assets
    /// sind stilisierte Illustrationen und dürfen nicht als große Hero-Cover erscheinen.
    /// Bewusst NICHT dynamisch aus `all`/`coverPoolAssetNames` abgeleitet, damit die
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
        "cover_ship_aidanova", "cover_ship_mein_schiff_6", "cover_ship_msc_seaside",
    ]

    private static let curatedShipCoverAssets: Set<String> = [
        "cover_ship_aidanova",
        "cover_ship_mein_schiff_6",
        "cover_ship_msc_seaside",
    ]

    /// Kleine, visuell geprüfte Regions-Pools. Sie werden nur bei eindeutigen Zielbegriffen
    /// verwendet; sonst bleibt die reederei-/kontextgebundene Fotoauswahl maßgeblich.
    private static let routePhotoPools: [(keywords: [String], assets: [String])] = [
        (
            ["norwegen", "norway", "fjord", "geiranger", "bergen", "flam", "alesund", "stavanger"],
            ["cover_line_aida_1", "cover_line_meinschiff_3", "cover_ship_aidanova"]
        ),
        (
            ["kanaren", "canary", "teneriffa", "tenerife", "gran_canaria", "lanzarote", "fuerteventura", "la_palma"],
            ["cover_line_aida_2"]
        ),
        (
            ["karibik", "caribbean", "antigua", "barbados", "martinique", "st_lucia", "saint_lucia"],
            ["cover_line_aida_5", "cover_line_meinschiff_5", "cover_ship_msc_seaside"]
        ),
        (
            ["ostsee", "baltic", "stockholm", "helsinki", "tallinn", "kopenhagen", "copenhagen"],
            ["cover_line_aida_4"]
        ),
        (
            ["mittelmeer", "mediterranean", "mallorca", "barcelona", "santorini", "adriatic", "adria", "dubrovnik"],
            ["cover_line_aida_3", "cover_line_meinschiff_1", "cover_line_meinschiff_2", "cover_line_meinschiff_4", "cover_ship_mein_schiff_6"]
        ),
    ]

    private static func routePhotoAssetName(context: String) -> String? {
        let normalizedContext = coverSlug(for: context)
        guard !normalizedContext.isEmpty else { return nil }
        guard let pool = routePhotoPools.first(where: { entry in
            entry.keywords.contains { normalizedContext.contains($0) }
        })?.assets else { return nil }
        return pool[stableIndex(for: normalizedContext, count: pool.count)]
    }

    /// Deterministisches Stock-Cover für eine eigene (im Katalog nicht gefundene) Reederei/Schiff-
    /// Kombination, gewählt aus `stockCoverPool`. `nil`, wenn beide Namen leer sind.
    private static func stockCoverAssetName(shippingLine: String, ship: String, context: String) -> String? {
        let normalizedLine = coverSlug(for: shippingLine)
        let normalizedShip = coverSlug(for: ship)
        let normalizedContext = coverSlug(for: context)
        guard !normalizedLine.isEmpty || !normalizedShip.isEmpty || !normalizedContext.isEmpty else { return nil }
        let key = [normalizedLine, normalizedShip, normalizedContext]
            .filter { !$0.isEmpty }
            .joined(separator: "::")
        // Aufrufe ohne Kontext behalten die bisherige 70er-Zuordnung bei; reale Reisen
        // nutzen den um drei einzeln geprüfte Schiffs-Fotos erweiterten Pool.
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
