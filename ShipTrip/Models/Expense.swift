//
//  Expense.swift
//  ShipTrip
//
//  Created by ShipTrip on 18.12.25.
//

import SwiftData
import Foundation

/// Kategorien für Ausgaben
enum ExpenseCategory: String, Codable, CaseIterable, Identifiable {
    case cruise = "Kreuzfahrt"
    case flight = "Flug"
    case hotel = "Hotel"
    case excursion = "Ausflug"
    case onboard = "An Bord"
    case other = "Sonstiges"
    
    var id: String { rawValue }
    
    /// SF Symbol für die Kategorie
    var icon: String {
        switch self {
        case .cruise: return "ferry"
        case .flight: return "airplane"
        case .hotel: return "bed.double"
        case .excursion: return "figure.walk"
        case .onboard: return "dollarsign.circle"
        case .other: return "ellipsis.circle"
        }
    }
    
    /// Farbe für die Kategorie (als String für SwiftData-Kompatibilität)
    var colorName: String {
        switch self {
        case .cruise: return "blue"
        case .flight: return "orange"
        case .hotel: return "purple"
        case .excursion: return "green"
        case .onboard: return "pink"
        case .other: return "gray"
        }
    }
}

/// Ausgabe/Kosten für eine Kreuzfahrt
@Model
final class Expense {
    // MARK: - Properties
    
    /// Kategorie der Ausgabe (als Raw String gespeichert)
    var categoryRaw: String
    
    /// Beschreibung
    var descriptionText: String
    
    /// Betrag in EUR
    var amount: Double
    
    /// Datum der Ausgabe (optional)
    var expenseDate: Date?
    
    /// Erstellungsdatum
    var createdAt: Date
    
    // MARK: - Relationships
    
    /// Zugehörige Kreuzfahrt
    var cruise: Cruise?
    
    // MARK: - Initialization
    
    init(category: ExpenseCategory, amount: Double, description: String = "") {
        self.categoryRaw = category.rawValue
        self.amount = amount
        self.descriptionText = description
        self.createdAt = Date()
    }
    
    // MARK: - Computed Properties
    
    /// Kategorie als Enum
    var category: ExpenseCategory {
        get { ExpenseCategory(rawValue: categoryRaw) ?? .other }
        set { categoryRaw = newValue.rawValue }
    }
    
    /// Formatierter Betrag
    var formattedAmount: String {
        amount.formatted(.currency(code: "EUR"))
    }
}
