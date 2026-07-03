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

    /// Skalierte Basis-Höhe der Karte (bleibt pro Rendering stabil, wächst mit Dynamic Type)
    @ScaledMetric(relativeTo: .title) private var heroHeight: CGFloat = 286

    /// Tage bis zum Start (kalendarisch normalisiert; verhindert „In 0 Tagen" für morgen)
    private var daysUntilStart: Int {
        Calendar.current.dateComponents(
            [.day],
            from: Calendar.current.startOfDay(for: .now),
            to: Calendar.current.startOfDay(for: cruise.startDate)
        ).day ?? 0
    }

    var body: some View {
        heroContent
            .frame(height: heroHeight)
            .clipShape(RoundedRectangle(cornerRadius: 30))
            .shadow(color: Color.navyDark.opacity(0.22), radius: 17, y: 10)
    }

    private var heroContent: some View {
        GeometryReader { proxy in
            ZStack(alignment: .bottomLeading) {
                mediaBackground
                    .frame(width: proxy.size.width, height: proxy.size.height)
                    .clipped()

                // Scrim für Text-Lesbarkeit
                LinearGradient(
                    colors: [.clear, .black.opacity(0.84)],
                    startPoint: .center,
                    endPoint: .bottom
                )
                .frame(width: proxy.size.width, height: proxy.size.height)

                // Text im Scrim
                VStack(alignment: .leading, spacing: 12) {
                    if cruise.isUpcoming {
                        Text(String(localized: "In \(daysUntilStart) Tagen"))
                            .font(.caption2)
                            .fontWeight(.bold)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(Color.sunsetOrange)
                            .foregroundStyle(.white)
                            .clipShape(Capsule())
                    }

                    VStack(alignment: .leading, spacing: 5) {
                        Text(cruise.title)
                            .font(.title)
                            .fontWeight(.heavy)
                            .foregroundStyle(.white)
                            .lineLimit(2)
                            .minimumScaleFactor(0.85)

                        Text(subline)
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.8))
                            .lineLimit(1)
                            .minimumScaleFactor(0.85)
                    }

                    HStack {
                        Text(metaLine)
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundStyle(.white.opacity(0.92))
                            .lineLimit(1)
                            .minimumScaleFactor(0.85)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(.white.opacity(0.16))
                            .clipShape(Capsule())

                        Spacer(minLength: 8)

                        HStack(spacing: 5) {
                            Text(String(localized: "Reise öffnen"))
                            Image(systemName: "arrow.right")
                                .font(.caption2.weight(.bold))
                        }
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundStyle(Color.navyDark)
                        .lineLimit(1)
                        .minimumScaleFactor(0.85)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(.white)
                        .clipShape(Capsule())
                    }
                }
                .padding(18)
                .frame(width: proxy.size.width, alignment: .leading)
            }
            // Bewertung oben rechts
            .overlay(alignment: .topTrailing) {
                if cruise.rating > 0 {
                    RatingBadge(rating: cruise.rating)
                        .padding(14)
                }
            }
        }
    }

    // MARK: - Hilfs-Properties

    @ViewBuilder
    private var mediaBackground: some View {
        if let photo = cruise.sortedPhotos.first,
           let uiImage = UIImage(data: photo.thumbnailData ?? photo.imageData) {
            Image(uiImage: uiImage)
                .resizable()
                .aspectRatio(contentMode: .fill)
        } else if let assetImage = coverAssetImage {
            assetImage
                .resizable()
                .aspectRatio(contentMode: .fill)
        } else {
            CruiseGeoFallbackView(ports: cruise.route)
        }
    }

    private var coverAssetImage: Image? {
        ShippingLine.coverAssetCandidates(
            shippingLine: cruise.shippingLine,
            ship: cruise.ship
        )
        .lazy
        .compactMap { UIImage(named: $0) }
        .first
        .map { Image(uiImage: $0) }
    }

    private var subline: String {
        let start = cruise.startDate.formatted(date: .abbreviated, time: .omitted)
        let end = cruise.endDate.formatted(date: .abbreviated, time: .omitted)
        let ports = cruise.route
            .filter { !$0.isSeaDay }
            .sorted { $0.sortOrder < $1.sortOrder }
            .prefix(3)
            .map(\.name)
            .joined(separator: ", ")
        if ports.isEmpty {
            return "\(cruise.ship) · \(start)–\(end)"
        }
        return "\(cruise.ship) · \(start)–\(end) · \(ports)"
    }

    private var metaLine: String {
        let countryCount = cruise.countriesVisited.filter { !$0.isEmpty }.count
        let portCount = cruise.route.filter { !$0.isSeaDay }.count
        return "\(portCount) \(String(localized: "Häfen")) · \(countryCount) \(String(localized: "Länder"))"
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
