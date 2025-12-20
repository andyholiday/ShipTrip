//
//  CruiseCardView.swift
//  ShipTrip
//
//  Created by ShipTrip on 18.12.25.
//

import SwiftUI

/// iOS-Style Card für eine Kreuzfahrt in der Liste
struct CruiseCardView: View {
    let cruise: Cruise
    
    private let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "dd.MM.yyyy"
        return formatter
    }()
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Hero Image oder Placeholder
            ZStack {
                if let firstPhoto = cruise.sortedPhotos.first,
                   let uiImage = UIImage(data: firstPhoto.imageData) {
                    Image(uiImage: uiImage)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } else {
                    Rectangle()
                        .fill(Color.secondary.opacity(0.2))
                        .overlay {
                            Image(systemName: "ferry")
                                .font(.system(size: 40))
                                .foregroundStyle(.secondary)
                        }
                }
            }
            .frame(height: 180)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            
            // Content
            VStack(alignment: .leading, spacing: 8) {
                // Titel und Rating
                HStack(alignment: .top) {
                    Text(cruise.title)
                        .font(.headline)
                        .lineLimit(2)
                    
                    Spacer()
                    
                    if cruise.rating > 0 {
                        RatingBadge(rating: cruise.rating)
                    }
                }
                
                // Reederei
                HStack(spacing: 4) {
                    Text(cruise.shippingLineLogo)
                    Text(cruise.shippingLine)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                
                // Details
                VStack(alignment: .leading, spacing: 4) {
                    // Schiff
                    Label(cruise.ship, systemImage: "ferry")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    
                    // Datum
                    Label(
                        "\(dateFormatter.string(from: cruise.startDate)) – \(dateFormatter.string(from: cruise.endDate)) (\(cruise.duration) Tage)",
                        systemImage: "calendar"
                    )
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    
                    // Route
                    if !cruise.route.isEmpty {
                        Label(
                            cruise.route.sorted(by: { $0.sortOrder < $1.sortOrder }).map { $0.name }.joined(separator: " → "),
                            systemImage: "mappin.and.ellipse"
                        )
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                    }
                }
            }
            .padding(.horizontal, 4)
        }
        .padding(.vertical, 8)
    }
}

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

#Preview {
    let cruise = Cruise(
        title: "Mittelmeer Kreuzfahrt",
        startDate: Date(),
        endDate: Date().addingTimeInterval(7 * 24 * 60 * 60),
        shippingLine: "TUI Cruises - Mein Schiff",
        ship: "Mein Schiff 4"
    )
    cruise.rating = 4.5
    
    return List {
        CruiseCardView(cruise: cruise)
            .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
            .listRowSeparator(.hidden)
    }
    .listStyle(.plain)
}
