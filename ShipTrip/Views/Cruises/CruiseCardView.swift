//
//  CruiseCardView.swift
//  ShipTrip
//
//  Created by ShipTrip on 18.12.25.
//

import SwiftUI

/// Foto-zentrierte Card für eine Kreuzfahrt in der Liste.
/// Das Cover-Foto (oder ein Farbverlauf-Fallback) füllt die gesamte Karte;
/// der Text liegt als dunkles Overlay über dem unteren Bereich.
struct CruiseCardView: View {
    let cruise: Cruise

    private let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "dd.MM.yyyy"
        return formatter
    }()

    var body: some View {
        ZStack(alignment: .bottom) {
            // MARK: Hintergrundbild oder Farbverlauf-Fallback
            if let firstPhoto = cruise.sortedPhotos.first,
               let imageData = firstPhoto.thumbnailData ?? firstPhoto.imageData as Data?,
               let uiImage = UIImage(data: imageData) {
                Image(uiImage: uiImage)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } else {
                LinearGradient(
                    colors: [Color.oceanBlue, Color.navyDark],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .overlay {
                    Image(systemName: "ferry")
                        .font(.system(size: 48))
                        .foregroundStyle(.white.opacity(0.35))
                }
            }

            // MARK: Dunkler Scrim für Text-Lesbarkeit
            LinearGradient(
                colors: [.black.opacity(0.0), .black.opacity(0.65)],
                startPoint: .center,
                endPoint: .bottom
            )

            // MARK: Text-Overlay unten
            VStack(alignment: .leading, spacing: 4) {
                Text(cruise.title)
                    .font(.headline)
                    .foregroundStyle(.white)
                    .lineLimit(2)

                HStack(spacing: 4) {
                    Text(cruise.shippingLineLogo)
                    Text(cruise.shippingLine)
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.85))
                }

                Label(cruise.ship, systemImage: "ferry")
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.85))

                Text(
                    "\(dateFormatter.string(from: cruise.startDate)) – \(dateFormatter.string(from: cruise.endDate)) (\(cruise.duration) \(String(localized: "Tage")))"
                )
                .font(.caption)
                .foregroundStyle(.white.opacity(0.75))
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(12)
        }
        .frame(height: 210)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        // MARK: Badges oben rechts
        .overlay(alignment: .topTrailing) {
            HStack(spacing: 6) {
                if cruise.isUpcoming {
                    Text(String(localized: "Coming Soon"))
                        .font(.caption2)
                        .fontWeight(.semibold)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(.blue.opacity(0.85))
                        .foregroundStyle(.white)
                        .clipShape(Capsule())
                }

                if cruise.rating > 0 {
                    RatingBadge(rating: cruise.rating)
                }
            }
            .padding(10)
        }
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
