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
    /// Letzter Hafen / Endpunkt
    case endPort
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
        case .endPort:         return "mappin.and.ellipse.circle.fill"
        case .seaDay:          return "water.waves"
        }
    }

    private var color: Color {
        switch type {
        case .port:     return .portPin
        case .homePort: return .homePortPin
        case .endPort:  return .endPortPin
        case .seaDay:   return .seaDayPin
        }
    }

    private var accessibilityLabel: String {
        switch type {
        case .port:     return String(localized: "Hafen")
        case .homePort: return String(localized: "Heimathafen")
        case .endPort:  return String(localized: "Endhafen")
        case .seaDay:   return String(localized: "Seetag")
        }
    }
}

// MARK: - Convenience

extension PortPinType {
    /// Leitet den Pin-Typ vom Port-Modell ab.
    /// `isFirst`: `true` wenn der Port den niedrigsten sortOrder in der Route hat.
    /// `isLast`: `true` wenn der Port den höchsten sortOrder unter den Nicht-Seetag-Häfen hat.
    init(isSeaDay: Bool, isFirst: Bool, isLast: Bool) {
        if isSeaDay {
            self = .seaDay
        } else if isFirst {
            self = .homePort
        } else if isLast {
            self = .endPort
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
        PortPinView(type: .endPort)
        PortPinView(type: .seaDay)
    }
    .padding()
}
