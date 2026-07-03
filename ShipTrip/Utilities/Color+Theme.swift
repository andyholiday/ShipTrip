//
//  Color+Theme.swift
//  ShipTrip
//
//  Created by ShipTrip on 18.12.25.
//

import SwiftUI
import UIKit

extension Color {
    // MARK: - Brand Colors

    /// Ozeanblau - Hauptfarbe
    static let oceanBlue = Color(red: 0.047, green: 0.549, blue: 0.914) // #0C8CE9

    /// Ozeanblau - helle Variante (Seetag)
    static let oceanLight = Color(red: 0.212, green: 0.663, blue: 0.941) // #36A9F0

    /// Dunkles Navy
    static let navyDark = Color(red: 0.102, green: 0.212, blue: 0.365) // #1A365D

    /// Sonnenuntergang Orange
    static let sunsetOrange = Color(red: 1.0, green: 0.420, blue: 0.208) // #FF6B35

    /// Seegrün
    static let seaGreen = Color(red: 0.204, green: 0.780, blue: 0.349) // #34C759

    // MARK: - Pin-Farben (semantische Token)

    /// Hafen-Pin: oceanBlue
    static let portPin = Color.oceanBlue

    /// Heimathafen-Pin (erster Hafen): sunsetOrange
    static let homePortPin = Color.sunsetOrange

    /// Seetag-Pin: oceanLight (helles Blau)
    static let seaDayPin = Color.oceanLight

    /// Endhafen-Pin: seaGreen (kontrastiert gut im Dark Mode gegen Ozean-Verlauf)
    static let endPortPin = Color.seaGreen
    
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

// MARK: - Design Radius Tokens

/// Einheitliche Corner-Radien fuer Karten/Panels quer durch die App.
enum DesignRadius {
    static let sm: CGFloat = 10
    static let md: CGFloat = 16
    static let lg: CGFloat = 28
}

// MARK: - View Modifiers

extension View {
    /// iOS-Style Button
    func primaryButtonStyle() -> some View {
        self
            .font(.headline)
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding()
            .background(Color.accentColor)
            .clipShape(RoundedRectangle(cornerRadius: DesignRadius.sm))
    }
}
