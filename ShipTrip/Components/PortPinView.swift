//
//  PortPinView.swift
//  ShipTrip
//

import SwiftUI

/// Art des Hafen-Pins — bestimmt Icon und Farbe.
enum PortPinType {
    /// Regulärer Hafen
    case port
    /// Erster Hafen / Heimathafen
    case homePort
    /// Seetag (kein Landgang)
    case seaDay
}

/// Einheitliche Pin-Darstellung für alle Hafen-Kontexte
/// (Karte, Detailansicht). Kein Duplikat mehr über Views.
struct PortPinView: View {
    let type: PortPinType

    // MARK: - Layout

    var body: some View {
        Image(systemName: iconName)
            .foregroundStyle(color)
            .font(.system(size: 20))
            .frame(width: 24)
            .accessibilityLabel(accessibilityLabel)
    }

    // MARK: - Private

    private var iconName: String {
        switch type {
        case .port, .homePort: return "mappin.circle.fill"
        case .seaDay:          return "water.waves"
        }
    }

    private var color: Color {
        switch type {
        case .port:     return .portPin
        case .homePort: return .homePortPin
        case .seaDay:   return .seaDayPin
        }
    }

    private var accessibilityLabel: String {
        switch type {
        case .port:     return String(localized: "Hafen")
        case .homePort: return String(localized: "Heimathafen")
        case .seaDay:   return String(localized: "Seetag")
        }
    }
}

// MARK: - Convenience

extension PortPinType {
    /// Leitet den Pin-Typ vom Port-Modell ab.
    /// `isFirst`: `true` wenn der Port den niedrigsten sortOrder in der Route hat.
    init(isSeaDay: Bool, isFirst: Bool) {
        if isSeaDay {
            self = .seaDay
        } else if isFirst {
            self = .homePort
        } else {
            self = .port
        }
    }
}

// MARK: - Preview

#Preview {
    HStack(spacing: 24) {
        PortPinView(type: .homePort)
        PortPinView(type: .port)
        PortPinView(type: .seaDay)
    }
    .padding()
}
