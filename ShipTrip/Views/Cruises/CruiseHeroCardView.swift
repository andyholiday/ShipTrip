//
//  CruiseHeroCardView.swift
//  ShipTrip
//
//  Visuell aufgewertete Hero-Card für eine Kreuzfahrt.
//  Kein NavigationLink — die aufrufende Ebene entscheidet über Navigation.
//

import SwiftUI

/// Zweizonen-Karte: obere Medienzone (~190 pt) + untere Meta-Leiste.
struct CruiseHeroCardView: View {
    let cruise: Cruise

    /// Tage bis zum Start (kalendarisch normalisiert; verhindert „In 0 Tagen" für morgen)
    private var daysUntilStart: Int {
        Calendar.current.dateComponents(
            [.day],
            from: Calendar.current.startOfDay(for: .now),
            to: Calendar.current.startOfDay(for: cruise.startDate)
        ).day ?? 0
    }

    var body: some View {
        VStack(spacing: 0) {
            // MARK: Obere Medienzone
            ZStack(alignment: .bottom) {
                mediaBackground
                    .frame(height: 190)

                // Scrim für Text-Lesbarkeit
                LinearGradient(
                    colors: [.clear, .black.opacity(0.8)],
                    startPoint: .center,
                    endPoint: .bottom
                )

                // Text im Scrim
                VStack(alignment: .leading, spacing: 3) {
                    Text(cruise.title)
                        .font(.title3)
                        .fontWeight(.heavy)
                        .foregroundStyle(.white)
                        .lineLimit(2)

                    Text(subline)
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.8))
                        .lineLimit(1)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 12)
                .padding(.bottom, 12)
            }
            .clipped()
            // Badges oben
            .overlay(alignment: .topLeading) {
                if cruise.isUpcoming {
                    Text(String(localized: "In \(daysUntilStart) Tagen"))
                        .font(.caption2)
                        .fontWeight(.semibold)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.sunsetOrange)
                        .foregroundStyle(.white)
                        .clipShape(Capsule())
                        .padding(10)
                }
            }
            .overlay(alignment: .topTrailing) {
                if cruise.rating > 0 {
                    RatingBadge(rating: cruise.rating)
                        .padding(10)
                }
            }

            // MARK: Untere Meta-Leiste
            HStack {
                Text(metaLine)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)

                Spacer()

                Text(String(localized: "Details →"))
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundStyle(Color.oceanBlue)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(Color(UIColor.secondarySystemBackground))
            .overlay(alignment: .top) {
                Divider()
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    // MARK: - Hilfs-Properties

    @ViewBuilder
    private var mediaBackground: some View {
        if let photo = cruise.sortedPhotos.first,
           let uiImage = UIImage(data: photo.thumbnailData ?? photo.imageData) {
            Image(uiImage: uiImage)
                .resizable()
                .aspectRatio(contentMode: .fill)
        } else {
            CruiseGeoFallbackView(ports: cruise.route)
        }
    }

    private var subline: String {
        let start = cruise.startDate.formatted(date: .abbreviated, time: .omitted)
        let end = cruise.endDate.formatted(date: .abbreviated, time: .omitted)
        return "\(cruise.shippingLineLogo) \(cruise.shippingLine) · \(cruise.ship) · \(start)–\(end)"
    }

    private var metaLine: String {
        let countryCount = cruise.countriesVisited.filter { !$0.isEmpty }.count
        let portCount = cruise.route.filter { !$0.isSeaDay }.count
        let expenses = cruise.totalExpenses.formatted(
            .currency(code: Locale.current.currency?.identifier ?? "EUR")
        )
        return "\(countryCount) \(String(localized: "Länder")) · \(portCount) \(String(localized: "Häfen")) · \(expenses)"
    }
}

// MARK: - Preview

#Preview {
    let upcoming = Cruise(
        title: "Mittelmeer Kreuzfahrt 2027",
        startDate: Calendar.current.date(byAdding: .day, value: 42, to: .now) ?? .now,
        endDate: Calendar.current.date(byAdding: .day, value: 53, to: .now) ?? .now,
        shippingLine: "TUI Cruises - Mein Schiff",
        ship: "Mein Schiff 4"
    )
    let barcelona = Port(name: "Barcelona", country: "Spanien", latitude: 41.38, longitude: 2.18)
    barcelona.sortOrder = 0
    let marseille = Port(name: "Marseille", country: "Frankreich", latitude: 43.30, longitude: 5.37)
    marseille.sortOrder = 1
    let genua = Port(name: "Genua", country: "Italien", latitude: 44.41, longitude: 8.93)
    genua.sortOrder = 2
    upcoming.route = [barcelona, marseille, genua]
    upcoming.rating = 0

    let past = Cruise(
        title: "Norwegen Fjorde 2024",
        startDate: Calendar.current.date(byAdding: .day, value: -200, to: .now) ?? .now,
        endDate: Calendar.current.date(byAdding: .day, value: -186, to: .now) ?? .now,
        shippingLine: "AIDA Cruises",
        ship: "AIDAnova"
    )
    past.rating = 4.8

    return List {
        CruiseHeroCardView(cruise: upcoming)
            .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
            .listRowSeparator(.hidden)
        CruiseHeroCardView(cruise: past)
            .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
            .listRowSeparator(.hidden)
    }
    .listStyle(.plain)
}
