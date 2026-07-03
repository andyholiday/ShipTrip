//
//  CruiseTimelineRowView.swift
//  ShipTrip
//

import SwiftUI

// MARK: - CruiseYearDivider

/// Kleiner Abschnitts-Header mit Jahreszahl und horizontaler Trennlinie.
struct CruiseYearDivider: View {
    let year: Int
    var count: Int? = nil

    var body: some View {
        HStack(spacing: 8) {
            Text(verbatim: "\(year)")
                .font(.footnote)
                .fontWeight(.heavy)
                .foregroundStyle(.secondary)
                .padding(.leading, 10)

            Divider()
                .frame(height: 0.5)

            if let count {
                Text("\(count) \(count == 1 ? String(localized: "Reise") : String(localized: "Reisen"))")
                    .font(.caption2)
                    .fontWeight(.semibold)
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(.top, 6)
        .padding(.bottom, 4)
        .padding(.trailing, 16)
    }
}

// MARK: - Preview

#Preview {
    List {
        CruiseYearDivider(year: 2026, count: 3)
        CruiseYearDivider(year: 2025, count: 1)
    }
    .listStyle(.plain)
}
