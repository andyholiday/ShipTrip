//
//  Cruise.swift
//  ShipTrip
//
//  Created by ShipTrip on 18.12.25.
//

import SwiftData
import Foundation

/// Kreuzfahrt-Modell mit allen relevanten Informationen
@Model
final class Cruise {
    // MARK: - Properties
    
    /// Titel der Kreuzfahrt (z.B. "Mittelmeer Kreuzfahrt 2024")
    var title: String
    
    /// Startdatum der Reise
    var startDate: Date
    
    /// Enddatum der Reise
    var endDate: Date
    
    /// Name der Reederei
    var shippingLine: String
    
    /// Name des Schiffs
    var ship: String
    
    /// Kabinentyp (z.B. "Balkonkabine")
    var cabinType: String
    
    /// Kabinennummer (z.B. "8042")
    var cabinNumber: String = ""
    
    /// Buchungsnummer
    var bookingNumber: String
    
    /// Persönliche Notizen
    var notes: String
    
    /// Bewertung (1-5 Sterne)
    var rating: Double
    
    /// Erstellungsdatum
    var createdAt: Date
    
    /// Letztes Änderungsdatum
    var updatedAt: Date
    
    // MARK: - Relationships
    
    /// Route mit allen besuchten Häfen
    @Relationship(deleteRule: .cascade)
    var route: [Port] = []
    
    /// Ausgaben für diese Kreuzfahrt
    @Relationship(deleteRule: .cascade)
    var expenses: [Expense] = []
    
    /// Fotos der Kreuzfahrt
    @Relationship(deleteRule: .cascade)
    var photos: [Photo] = []
    
    // MARK: - Initialization
    
    init(
        title: String,
        startDate: Date,
        endDate: Date,
        shippingLine: String,
        ship: String
    ) {
        self.title = title
        self.startDate = startDate
        self.endDate = endDate
        self.shippingLine = shippingLine
        self.ship = ship
        self.cabinType = ""
        self.cabinNumber = ""
        self.bookingNumber = ""
        self.notes = ""
        self.rating = 0
        self.createdAt = Date()
        self.updatedAt = Date()
    }
    
    // MARK: - Computed Properties
    
    /// Dauer der Kreuzfahrt in Tagen
    var duration: Int {
        let days = Calendar.current.dateComponents([.day], from: startDate, to: endDate).day ?? 0
        return days + 1 // Inklusiv Start- und Endtag
    }
    
    /// Prüft ob die Kreuzfahrt in der Zukunft liegt
    var isUpcoming: Bool {
        startDate > Date()
    }
    
    /// Prüft ob die Kreuzfahrt gerade stattfindet
    var isOngoing: Bool {
        let now = Date()
        return startDate <= now && endDate >= now
    }
    
    /// Jahr der Kreuzfahrt
    var year: Int {
        Calendar.current.component(.year, from: startDate)
    }
    
    /// Gesamtkosten aller Ausgaben
    var totalExpenses: Double {
        expenses.reduce(0) { $0 + $1.amount }
    }
    
    /// Anzahl der besuchten Länder
    var countriesVisited: Set<String> {
        Set(route.map { $0.country })
    }
    
    /// Emoji-Logo der Reederei
    var shippingLineLogo: String {
        ShippingLine.all.first { $0.name == shippingLine }?.logo ?? "🛳️"
    }
    
    /// Sortierte Fotos
    var sortedPhotos: [Photo] {
        photos.sorted { $0.sortOrder < $1.sortOrder }
    }
}
