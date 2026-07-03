//
//  CruiseStatsStripView.swift
//  ShipTrip
//

import SwiftUI

/// Horizontaler Stats-Streifen mit 4 aggregierten Kennzahlen über alle Kreuzfahrten.
/// Zellen in fester Reihenfolge: Reisen · Tage · Länder · Häfen.
struct CruiseStatsStripView: View {
    let cruises: [Cruise]

    var body: some View {
        // Aggregation einmalig — nicht pro Zelle
        let reisen = cruises.count
        let tage = cruises.totalTravelDays
        let laender = cruises.uniqueCountryCount
        let haefen = cruises.totalPortStops

        HStack(spacing: 8) {
            StatCell(
                value: reisen,
                label: String(localized: "Reisen"),
                color: .oceanBlue
            )
            StatCell(
                value: tage,
                label: String(localized: "Tage"),
                color: .oceanLight
            )
            StatCell(
                value: laender,
                label: String(localized: "Länder"),
                color: .seaGreen
            )
            StatCell(
                value: haefen,
                label: String(localized: "Häfen"),
                color: .sunsetOrange
            )
        }
    }
}

// MARK: - StatCell

/// Eine einzelne Statistik-Zelle (Zahl oben, Beschriftung unten)
private struct StatCell: View {
    let value: Int
    let label: String
    let color: Color

    @ScaledMetric(relativeTo: .title3) private var cellHeight: CGFloat = 58

        var body: some View {
            VStack(spacing: 2) {
                Text("\(value)")
                    .font(.title3)
                    .fontWeight(.heavy)
                    .foregroundStyle(.primary)
                    .monospacedDigit()
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)
                Text(label)
                    .font(.caption2)
                    .fontWeight(.bold)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)
            }
        .frame(minHeight: cellHeight)
        .frame(maxWidth: .infinity)
        .background(color.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: DesignRadius.md))
        .overlay {
            RoundedRectangle(cornerRadius: DesignRadius.md)
                .strokeBorder(Color(UIColor.separator).opacity(0.16), lineWidth: 0.5)
        }
    }
}

// MARK: - Preview

#Preview {
    // Zwei Sample-Kreuzfahrten mit je einigen Häfen inkl. Seetag
    let cruise1 = Cruise(
        title: "Mittelmeer Kreuzfahrt",
        startDate: Date(),
        endDate: Date().addingTimeInterval(7 * 24 * 60 * 60),
        shippingLine: "TUI Cruises - Mein Schiff",
        ship: "Mein Schiff 4"
    )
    let barcelona = Port(name: "Barcelona", country: "Spanien", latitude: 41.38, longitude: 2.18)
    let seetag1 = Port(name: "Seetag", country: "", latitude: 0, longitude: 0)
    seetag1.isSeaDay = true
    let palma = Port(name: "Palma de Mallorca", country: "Spanien", latitude: 39.57, longitude: 2.65)
    cruise1.route = [barcelona, seetag1, palma]

    let cruise2 = Cruise(
        title: "Karibik Reise",
        startDate: Date().addingTimeInterval(-30 * 24 * 60 * 60),
        endDate: Date().addingTimeInterval(-23 * 24 * 60 * 60),
        shippingLine: "MSC Cruises",
        ship: "MSC Bellissima"
    )
    let miami = Port(name: "Miami", country: "USA", latitude: 25.77, longitude: -80.19)
    let seetag2 = Port(name: "Seetag", country: "", latitude: 0, longitude: 0)
    seetag2.isSeaDay = true
    let nassau = Port(name: "Nassau", country: "Bahamas", latitude: 25.04, longitude: -77.35)
    cruise2.route = [miami, seetag2, nassau]

    return CruiseStatsStripView(cruises: [cruise1, cruise2])
        .padding()
}
