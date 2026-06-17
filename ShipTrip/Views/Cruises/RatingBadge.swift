//
//  RatingBadge.swift
//  ShipTrip

import SwiftUI

/// Kleine Rating-Badge
struct RatingBadge: View {
    let rating: Double

    var body: some View {
        HStack(spacing: 2) {
            Image(systemName: "star.fill")
                .font(.caption2)
            Text(String(format: "%.1f", rating))
                .font(.caption)
                .fontWeight(.medium)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(.yellow.opacity(0.2))
        .foregroundStyle(.orange)
        .clipShape(Capsule())
    }
}
