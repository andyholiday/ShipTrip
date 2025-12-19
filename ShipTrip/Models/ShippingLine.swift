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
    
    /// Alle verfügbaren Reedereien
    static let all: [ShippingLine] = [
        ShippingLine(id: "meinschiff", name: "TUI Cruises - Mein Schiff", logo: "🚢"),
        ShippingLine(id: "aida", name: "AIDA Cruises", logo: "💋"),
        ShippingLine(id: "costa", name: "Costa Kreuzfahrten", logo: "🌊"),
        ShippingLine(id: "msc", name: "MSC Cruises", logo: "⚓"),
        ShippingLine(id: "phoenix", name: "Phoenix Reisen", logo: "🐦"),
        ShippingLine(id: "royalcaribbean", name: "Royal Caribbean", logo: "👑"),
        ShippingLine(id: "carnival", name: "Carnival Cruise Line", logo: "🎉"),
        ShippingLine(id: "ncl", name: "Norwegian Cruise Line", logo: "🇳🇴"),
        ShippingLine(id: "celebrity", name: "Celebrity Cruises", logo: "⭐"),
        ShippingLine(id: "hapag", name: "Hapag-Lloyd Cruises", logo: "🔵"),
        ShippingLine(id: "cunard", name: "Cunard", logo: "🎩"),
        ShippingLine(id: "princess", name: "Princess Cruises", logo: "👸"),
        ShippingLine(id: "disney", name: "Disney Cruise Line", logo: "🏰"),
        ShippingLine(id: "virgin", name: "Virgin Voyages", logo: "🔴"),
    ]
    
    /// Findet eine Reederei anhand des Namens
    static func find(byName name: String) -> ShippingLine? {
        all.first { $0.name.lowercased() == name.lowercased() }
    }
    
    /// Findet eine Reederei anhand der ID
    static func find(byId id: String) -> ShippingLine? {
        all.first { $0.id == id }
    }
}
