//
//  MapStopBadgeView.swift
//  ShipTrip
//

import SwiftUI

/// Nummeriertes Wegpunkt-Badge für Zwischenstopps im Reise-Zoom (Roadtrippers-Stil, B4.3b).
/// Start-/End-/Rundreise-Häfen behalten ihr eigenes `PortPinView`-Rollen-Icon und nutzen
/// dieses Badge nicht.
struct MapStopBadgeView: View {
    let number: Int
    /// Per-Route-Farbe (siehe `Color.routeColor(at:)`) — löst die B4.3a-Known-Limitation
    /// „alle Zwischenstopps einfarbig" auf.
    let color: Color
    let isSelected: Bool

    var body: some View {
        Text("\(number)")
            .font(.caption2.weight(.bold))
            .foregroundStyle(.white)
            .frame(width: 22, height: 22)
            // Design-Politur Welle C (F3): dezenter Fill-Gradient statt Flat-Fill für „papierne"
            // Tiefe (Deployment-Target iOS 18.5, `.glass*`-APIs sind iOS 26+).
            .background(
                LinearGradient(colors: [color, color.opacity(0.75)], startPoint: .topLeading, endPoint: .bottomTrailing)
            )
            .clipShape(Circle())
            .overlay(Circle().strokeBorder(.white, lineWidth: isSelected ? 3 : 1.5))
            .shadow(color: .black.opacity(0.18), radius: 6, y: 3)
            .accessibilityLabel(Text(String(localized: "Stopp \(number)")))
    }
}

// MARK: - Preview

#Preview {
    HStack(spacing: 16) {
        MapStopBadgeView(number: 2, color: .oceanBlue, isSelected: false)
        MapStopBadgeView(number: 3, color: .purple, isSelected: true)
    }
    .padding()
}
