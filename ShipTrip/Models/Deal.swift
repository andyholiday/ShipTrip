//
//  Deal.swift
//  ShipTrip
//
//  Created by ShipTrip on 18.12.25.
//

import SwiftData
import Foundation

/// Gespeichertes Kreuzfahrt-Angebot
@Model
final class Deal {
    // MARK: - Properties
    
    /// Titel des Angebots
    var title: String
    
    /// Reederei (optional)
    var shippingLine: String?
    
    /// Aktueller Preis in EUR
    var price: Double?
    
    /// Originalpreis vor Rabatt
    var originalPrice: Double?
    
    /// Startdatum der Kreuzfahrt
    var startDate: Date?
    
    /// Enddatum der Kreuzfahrt
    var endDate: Date?
    
    /// Zielregion/Destination
    var destination: String?
    
    /// Name des Schiffs
    var ship: String?
    
    /// Link zur Buchungsseite
    var url: String?
    
    /// Persönliche Notizen
    var notes: String?
    
    /// Zeitpunkt der Speicherung
    var createdAt: Date
    
    // MARK: - Initialization
    
    init(title: String) {
        self.title = title
        self.createdAt = Date()
    }
    
    // MARK: - Computed Properties
    
    /// Rabatt in Prozent (falls Originalpreis vorhanden)
    var discountPercent: Int? {
        guard let original = originalPrice,
              let current = price,
              original > 0,
              current < original else {
            return nil
        }
        return Int(((original - current) / original) * 100)
    }
    
    /// Ersparnis in EUR
    var savings: Double? {
        guard let original = originalPrice,
              let current = price,
              current < original else {
            return nil
        }
        return original - current
    }
    
    /// Formatierter Preis
    var formattedPrice: String? {
        price?.formatted(.currency(code: "EUR"))
    }
    
    /// Formatierter Originalpreis
    var formattedOriginalPrice: String? {
        originalPrice?.formatted(.currency(code: "EUR"))
    }
    
    /// Dauer in Tagen (falls Start- und Enddatum vorhanden)
    var duration: Int? {
        guard let start = startDate, let end = endDate else { return nil }
        let days = Calendar.current.dateComponents([.day], from: start, to: end).day ?? 0
        return days + 1
    }
    
    /// Emoji-Logo der Reederei
    var shippingLineLogo: String {
        guard let line = shippingLine else { return "🛳️" }
        return ShippingLine.all.first { $0.name == line }?.logo ?? "🛳️"
    }
}
