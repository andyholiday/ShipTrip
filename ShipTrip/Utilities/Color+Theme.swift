//
//  Color+Theme.swift
//  ShipTrip
//
//  Created by ShipTrip on 18.12.25.
//

import SwiftUI

extension Color {
    // MARK: - Brand Colors
    
    /// Ozeanblau - Hauptfarbe
    static let oceanBlue = Color(red: 0.047, green: 0.549, blue: 0.914) // #0C8CE9
    
    /// Dunkles Navy
    static let navyDark = Color(red: 0.102, green: 0.212, blue: 0.365) // #1A365D
    
    /// Sonnenuntergang Orange
    static let sunsetOrange = Color(red: 1.0, green: 0.420, blue: 0.208) // #FF6B35
    
    /// Seegrün
    static let seaGreen = Color(red: 0.204, green: 0.780, blue: 0.349) // #34C759
    
    // MARK: - Expense Category Colors
    
    static func expenseColor(for category: ExpenseCategory) -> Color {
        switch category {
        case .cruise: return .blue
        case .flight: return .orange
        case .hotel: return .purple
        case .excursion: return .green
        case .onboard: return .pink
        case .other: return .gray
        }
    }
    
    // MARK: - Route Colors
    
    static let routeColors: [Color] = [
        .oceanBlue,
        .sunsetOrange,
        .seaGreen,
        .purple,
        .pink,
        .cyan,
        .indigo,
        .mint
    ]
    
    static func routeColor(at index: Int) -> Color {
        routeColors[index % routeColors.count]
    }
}

// MARK: - View Modifiers

extension View {
    /// Card-Style mit Schatten
    func cardStyle() -> some View {
        self
            .background(Color(.secondarySystemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .shadow(color: .black.opacity(0.05), radius: 4, y: 2)
    }
    
    /// iOS-Style Button
    func primaryButtonStyle() -> some View {
        self
            .font(.headline)
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding()
            .background(Color.accentColor)
            .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}
