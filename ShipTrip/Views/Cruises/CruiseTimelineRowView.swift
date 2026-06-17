//
//  CruiseTimelineRowView.swift
//  ShipTrip
//

import SwiftUI
import SwiftData

// MARK: - CruiseTimelineRowView

/// Kompakte Zeile für eine Kreuzfahrt in einer Timeline-Listenansicht.
/// Kein NavigationLink enthalten – die übergeordnete View übernimmt die Navigation.
struct CruiseTimelineRowView: View {
    let cruise: Cruise

    // MARK: Body

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            // MARK: Spine-Punkt
            spineDot

            // MARK: Textblock
            textBlock

            Spacer(minLength: 0)

            // MARK: Thumbnail + Bewertung
            VStack(alignment: .trailing, spacing: 4) {
                thumbnail
                if cruise.rating > 0 {
                    Text("★ \(cruise.rating, format: .number.precision(.fractionLength(1)))")
                        .font(.caption2)
                        .foregroundStyle(Color.seaGreen)
                }
            }
        }
        .padding(.vertical, 6)
    }

    // MARK: Subviews

    /// Kleiner gefüllter Kreis als visueller Ankerpunkt
    private var spineDot: some View {
        let color: Color = {
            if cruise.isUpcoming { return Color.sunsetOrange }
            if cruise.rating > 0 { return Color.oceanBlue }
            return Color.gray
        }()
        return Circle()
            .fill(color)
            .frame(width: 10, height: 10)
    }

    /// Zweizeiliger (plus optionaler dritter Zeile) Textblock
    private var textBlock: some View {
        let nonSeaDayPorts = cruise.route
            .filter { !$0.isSeaDay }
            .sorted { $0.sortOrder < $1.sortOrder }
        let portPreview = nonSeaDayPorts
            .prefix(2)
            .map(\.name)
            .joined(separator: " · ")

        return VStack(alignment: .leading, spacing: 2) {
            Text(cruise.title)
                .font(.subheadline)
                .fontWeight(.bold)
                .lineLimit(1)

            Text("\(cruise.shippingLine) 🚢 · \(String(localized: "\(cruise.duration)T")) · \(cruise.countriesVisited.filter { !$0.isEmpty }.count) \(String(localized: "Länder"))")
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)

            if !portPreview.isEmpty {
                Text(portPreview)
                    .font(.caption2)
                    .foregroundStyle(Color.seaGreen)
                    .lineLimit(1)
            }
        }
    }

    /// ~34 pt Thumbnail: Foto oder Farbverlauf-Fallback mit Reederei-Logo
    private var thumbnail: some View {
        Group {
            if let photo = cruise.sortedPhotos.first,
               let data = photo.thumbnailData ?? photo.imageData as Data?,
               let uiImage = UIImage(data: data) {
                Image(uiImage: uiImage)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } else {
                LinearGradient(
                    colors: [Color.navyDark, Color.oceanBlue],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .overlay {
                    Text(cruise.shippingLineLogo)
                        .font(.system(size: 16))
                }
            }
        }
        .frame(width: 34, height: 34)
        .clipShape(RoundedRectangle(cornerRadius: 6))
    }
}

// MARK: - CruiseYearDivider

/// Kleiner Abschnitts-Header mit Jahreszahl und horizontaler Trennlinie.
struct CruiseYearDivider: View {
    let year: Int

    var body: some View {
        HStack(spacing: 8) {
            Text(verbatim: "\(year)")
                .font(.caption)
                .fontWeight(.heavy)
                .foregroundStyle(.secondary)
                .padding(.leading, 10)

            Divider()
                .frame(height: 0.5)
        }
        .padding(.top, 6)
        .padding(.bottom, 4)
        .padding(.trailing, 16)
    }
}

// MARK: - Preview

#Preview {
    let schema = Schema([Cruise.self, Port.self, Photo.self])
    let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: schema, configurations: config)
    let ctx = container.mainContext

    // Kreuzfahrt 1: bevorstehend, kein Foto
    let upcoming = Cruise(
        title: "Norwegen Fjorde",
        startDate: Date().addingTimeInterval(30 * 24 * 60 * 60),
        endDate: Date().addingTimeInterval(40 * 24 * 60 * 60),
        shippingLine: "AIDA Cruises",
        ship: "AIDAmar"
    )
    let port1a = Port(name: "Bergen", country: "Norwegen", latitude: 60.39, longitude: 5.32)
    port1a.sortOrder = 1
    let port1b = Port(name: "Flåm", country: "Norwegen", latitude: 60.86, longitude: 7.12)
    port1b.sortOrder = 2
    port1b.isSeaDay = false
    upcoming.route = [port1a, port1b]
    ctx.insert(upcoming)

    // Kreuzfahrt 2: vergangen, bewertet, mit Häfen
    let rated = Cruise(
        title: "Mittelmeer Klassiker",
        startDate: Date().addingTimeInterval(-200 * 24 * 60 * 60),
        endDate: Date().addingTimeInterval(-186 * 24 * 60 * 60),
        shippingLine: "MSC Cruises",
        ship: "MSC Bellissima"
    )
    rated.rating = 4.5
    let port2a = Port(name: "Barcelona", country: "Spanien", latitude: 41.38, longitude: 2.17)
    port2a.sortOrder = 1
    let port2b = Port(name: "Neapel", country: "Italien", latitude: 40.85, longitude: 14.26)
    port2b.sortOrder = 2
    rated.route = [port2a, port2b]
    ctx.insert(rated)

    // Kreuzfahrt 3: vergangen, kein Rating, keine Häfen
    let plain = Cruise(
        title: "Karibik Entdecker",
        startDate: Date().addingTimeInterval(-400 * 24 * 60 * 60),
        endDate: Date().addingTimeInterval(-386 * 24 * 60 * 60),
        shippingLine: "TUI Cruises - Mein Schiff",
        ship: "Mein Schiff 4"
    )
    ctx.insert(plain)

    return List {
        CruiseYearDivider(year: Calendar.current.component(.year, from: upcoming.startDate))
        CruiseTimelineRowView(cruise: upcoming)
            .listRowSeparator(.hidden)

        CruiseYearDivider(year: Calendar.current.component(.year, from: rated.startDate))
        CruiseTimelineRowView(cruise: rated)
            .listRowSeparator(.hidden)
        CruiseTimelineRowView(cruise: plain)
            .listRowSeparator(.hidden)
    }
    .listStyle(.plain)
    .modelContainer(container)
}
