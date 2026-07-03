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
    
    /// Lokalisierter Anzeigename (rawValue bleibt stabiler Speicher-Schlüssel)
    var displayName: String {
        String(localized: String.LocalizationValue(rawValue))
    }
}

/// Ausgabe/Kosten für eine Kreuzfahrt
@Model
final class Expense {
    // MARK: - Properties

    /// Stabile App-seitige ID (kein Unique-Constraint; CloudKit-kompatibel)
    var id: UUID = UUID()

    /// Kategorie der Ausgabe (als Raw String gespeichert)
    var categoryRaw: String = ""

    /// Beschreibung
    var descriptionText: String = ""

    /// Betrag in Geräte-Währung
    var amount: Double = 0

    /// Datum der Ausgabe (optional)
    var expenseDate: Date?

    /// Erstellungsdatum
    var createdAt: Date = Date()

    /// Letztes Änderungsdatum (für Last-Writer-Wins bei CloudKit-Sync)
    var updatedAt: Date = Date()

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
        amount.formattedCurrencyOrNumber
    }
}

extension Double {
    /// Currency-Format, falls die Geräte-Locale eine Währung kennt; sonst neutrales
    /// Zahlenformat statt eines hartkodierten EUR-Fallbacks (Muster: ExpenseFormView.amountField).
    var formattedCurrencyOrNumber: String {
        if let currencyCode = Locale.current.currency?.identifier {
            return formatted(.currency(code: currencyCode))
        }
        return formatted(.number.precision(.fractionLength(2)))
    }
}
