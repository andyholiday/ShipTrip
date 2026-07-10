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

    // MARK: - Journal Atlas (Karten-Redesign v2)

    /// Journal Atlas — warmes Papier-Surface für das Routen-Sheet (Karten-Redesign v2).
    static let journalSurfaceLight = Color(red: 0.984, green: 0.969, blue: 0.941) // #FBF7F0
    static let journalSurfaceDark  = Color(red: 0.082, green: 0.129, blue: 0.180) // #15212E

    /// Adaptiv je Farbschema — ersetzt das zuvor hartkodierte `.white` hinter `PortPinView`
    /// und dient als Ziel-Ton für das Routen-Sheet (Fallback für `.presentationBackground`, siehe
    /// `.planning/karten-redesign-v2-spec.md` Abschnitt 5).
    static var journalSurface: Color {
        Color(uiColor: UIColor { trait in
            trait.userInterfaceStyle == .dark
                ? UIColor(Color.journalSurfaceDark)
                : UIColor(Color.journalSurfaceLight)
        })
    }

    /// Journal Atlas — gepunktete Timeline-Linie zwischen den Stop-Rows im Routen-Sheet.
    static var journalTimeline: Color {
        Color(uiColor: UIColor { trait in
            trait.userInterfaceStyle == .dark
                ? UIColor(Color.white.opacity(0.14))
                : UIColor(Color.navyDark.opacity(0.18))
        })
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
