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
    let ships: [String]  // Bekannte Schiffe
    
    /// Alle verfügbaren Reedereien mit ihren Schiffen
    static let all: [ShippingLine] = [
        ShippingLine(id: "meinschiff", name: "TUI Cruises - Mein Schiff", logo: "🚢", ships: [
            "Mein Schiff 1", "Mein Schiff 2", "Mein Schiff 3", "Mein Schiff 4", 
            "Mein Schiff 5", "Mein Schiff 6", "Mein Schiff 7", "Mein Schiff Herz"
        ]),
        ShippingLine(id: "aida", name: "AIDA Cruises", logo: "💋", ships: [
            "AIDAcosma", "AIDAprima", "AIDAperla", "AIDAnova", "AIDAmar", "AIDAblu",
            "AIDAsol", "AIDAluna", "AIDAbella", "AIDAdiva", "AIDAaura", "AIDAvita", "AIDAcara"
        ]),
        ShippingLine(id: "costa", name: "Costa Kreuzfahrten", logo: "🌊", ships: [
            "Costa Toscana", "Costa Smeralda", "Costa Pacifica", "Costa Fortuna", 
            "Costa Fascinosa", "Costa Favolosa", "Costa Diadema", "Costa Firenze"
        ]),
        ShippingLine(id: "msc", name: "MSC Cruises", logo: "⚓", ships: [
            "MSC World Europa", "MSC Seascape", "MSC Seashore", "MSC Virtuosa", 
            "MSC Grandiosa", "MSC Bellissima", "MSC Meraviglia", "MSC Seaside",
            "MSC Preziosa", "MSC Divina", "MSC Fantasia", "MSC Splendida"
        ]),
        ShippingLine(id: "phoenix", name: "Phoenix Reisen", logo: "🐦", ships: [
            "Artania", "Amadea", "Amera", "Deutschland"
        ]),
        ShippingLine(id: "royalcaribbean", name: "Royal Caribbean", logo: "👑", ships: [
            "Icon of the Seas", "Wonder of the Seas", "Symphony of the Seas", 
            "Harmony of the Seas", "Allure of the Seas", "Oasis of the Seas",
            "Odyssey of the Seas", "Spectrum of the Seas", "Anthem of the Seas"
        ]),
        ShippingLine(id: "carnival", name: "Carnival Cruise Line", logo: "🎉", ships: [
            "Carnival Jubilee", "Carnival Celebration", "Mardi Gras", "Carnival Venezia"
        ]),
        ShippingLine(id: "ncl", name: "Norwegian Cruise Line", logo: "🇳🇴", ships: [
            "Norwegian Prima", "Norwegian Viva", "Norwegian Encore", "Norwegian Joy",
            "Norwegian Bliss", "Norwegian Escape", "Norwegian Breakaway"
        ]),
        ShippingLine(id: "celebrity", name: "Celebrity Cruises", logo: "⭐", ships: [
            "Celebrity Ascent", "Celebrity Beyond", "Celebrity Apex", "Celebrity Edge",
            "Celebrity Silhouette", "Celebrity Reflection", "Celebrity Eclipse"
        ]),
        ShippingLine(id: "hapag", name: "Hapag-Lloyd Cruises", logo: "🔵", ships: [
            "Europa", "Europa 2", "Hanseatic nature", "Hanseatic inspiration", "Hanseatic spirit"
        ]),
        ShippingLine(id: "cunard", name: "Cunard", logo: "🎩", ships: [
            "Queen Mary 2", "Queen Victoria", "Queen Elizabeth", "Queen Anne"
        ]),
        ShippingLine(id: "princess", name: "Princess Cruises", logo: "👸", ships: [
            "Sun Princess", "Discovery Princess", "Enchanted Princess", "Sky Princess",
            "Majestic Princess", "Regal Princess", "Royal Princess"
        ]),
        ShippingLine(id: "disney", name: "Disney Cruise Line", logo: "🏰", ships: [
            "Disney Wish", "Disney Fantasy", "Disney Dream", "Disney Wonder", "Disney Magic"
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
    
    /// Findet eine Reederei anhand des Schiffsnamens
    static func findByShipName(_ ship: String) -> ShippingLine? {
        let normalizedShip = ship.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        return all.first { line in
            line.ships.contains { $0.lowercased() == normalizedShip }
        }
    }
}

