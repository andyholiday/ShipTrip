//
//  PortMemoryCard.swift
//  ShipTrip
//
//  Welle B7.2 (B2 „PortMemoryCard“, docs/ux-pitch-decks/b6-hafen-momente.html):
//  ersetzt den bisherigen 44x44-Thumbnail + Fließtext-Block in der Route-Sektion
//  von CruiseDetailView durch eine volle-Breite-Karte mit 16:9-Hero-Foto,
//  Liegezeit-Badge und einladendem Zero-State, wenn noch nichts erfasst wurde.
//

import SwiftUI

/// Card-Darstellung der bei einem Hafen erfassten „Momente“ (Hafenbild + Ausflüge).
/// Nutzt ausschließlich bestehende `Port`-Felder (`imageData`, `excursions`,
/// `arrival`/`departure`) – kein Modell-Umbau.
struct PortMemoryCard: View {
    let port: Port

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            hero

            if !port.excursions.isEmpty {
                excursionChips
                    .padding(10)
            }
        }
        .frame(maxWidth: .infinity)
        .background(Color(.tertiarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: DesignRadius.sm))
        .shadow(color: .black.opacity(0.08), radius: 6, y: 3)
    }

    // MARK: - Hero

    /// Erzwingt eine feste 16:9-Bounding-Box, bevor Foto/Zero-State darin platziert werden.
    /// `Color.clear` + `.aspectRatio(_:contentMode: .fit)` liefert zuverlässig genau
    /// `Kartenbreite × Kartenbreite·9/16` (die Karte steckt in einem VStack, dessen
    /// Höhen-Vorschlag großzügiger ist als das Seitenverhältnis). Das verschachtelte
    /// `GeometryReader` liest diese fixe Box aus, damit `AsyncPhotoView` sie exakt über
    /// eine feste `.frame(width:height:)` füllen kann, statt `aspectRatio(.fill)` direkt
    /// auf einer Ansicht mit unbekannter Höhenvorgabe aufzublähen.
    private var hero: some View {
        Color.clear
            .aspectRatio(16.0 / 9.0, contentMode: .fit)
            .overlay {
                GeometryReader { proxy in
                    heroContent(size: proxy.size)
                }
            }
    }

    /// Zielgröße fürs Downsampling des Hero-Fotos (siehe AsyncPhotoView.maxPixelSize) –
    /// deutlich unter Vollauflösung, aber komfortabel über der tatsächlichen Card-Breite
    /// auf allen Gerätegrößen inkl. Retina.
    private static let heroMaxPixelSize: CGFloat = 800

    @ViewBuilder
    private func heroContent(size: CGSize) -> some View {
        if let imageData = port.imageData {
            AsyncPhotoView(imageData: imageData, maxPixelSize: Self.heroMaxPixelSize)
                .frame(width: size.width, height: size.height)
                .clipped()
                .overlay(alignment: .topTrailing) {
                    if let badge = Self.stayBadgeText(for: port) {
                        stayBadge(badge)
                    }
                }
        } else {
            zeroStateHero
                .frame(width: size.width, height: size.height)
        }
    }

    /// Einladender Zero-State (Dashed-Border-Inlay) statt einer leeren grauen Box,
    /// solange noch kein Hafenbild erfasst wurde. Tap zum Erfassen läuft über die
    /// bestehende Navigation der gesamten Hafen-Zeile in CruiseDetailView.
    private var zeroStateHero: some View {
        ZStack {
            RoundedRectangle(cornerRadius: DesignRadius.sm)
                .strokeBorder(style: StrokeStyle(lineWidth: 1, dash: [5, 4]))
                .foregroundStyle(.tertiary)
                .background(Color(.tertiarySystemBackground).opacity(0.5))

            VStack(spacing: 4) {
                Image(systemName: "photo.badge.plus")
                    .font(.title3)
                    .foregroundStyle(.tertiary)
                Text("Foto & Ausflüge erfassen")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: DesignRadius.sm))
    }

    private func stayBadge(_ text: String) -> some View {
        Text(text)
            .font(.caption2.weight(.semibold))
            .foregroundStyle(.white)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(.black.opacity(0.55))
            .clipShape(Capsule())
            .padding(6)
    }

    // MARK: - Ausflüge

    private var excursionChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                ForEach(port.excursions, id: \.self) { excursion in
                    Text(excursion)
                        .font(.caption)
                        .foregroundStyle(.primary)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(Color.oceanBlue.opacity(0.14))
                        .clipShape(Capsule())
                }
            }
        }
    }

    // MARK: - Reine Logik (testbar ohne SwiftUI-Rendering, siehe PortMemoryCardTests)

    /// Liegezeit-Badge-Text „Ankunft–Abfahrt“. Nutzt dieselbe Zeitformatierung, die
    /// zuvor in der Metadaten-Zeile von CruiseDetailView stand (jetzt auf die Karte
    /// verlagert, siehe Gate-Finding in b6-hafen-momente.html). `nil` bei Seetagen,
    /// da eine Liegezeit dort nicht existiert.
    static func stayBadgeText(for port: Port) -> String? {
        guard !port.isSeaDay else { return nil }
        return "\(port.arrival.formatted(date: .omitted, time: .shortened)) – \(port.departure.formatted(date: .omitted, time: .shortened))"
    }

    /// `true`, wenn die Hero-Fläche den Zero-State zeigt, weil noch kein Hafenbild
    /// erfasst wurde (unabhängig von etwaigen Ausflügen, die weiterhin darunter stehen).
    static func showsZeroStateHero(for port: Port) -> Bool {
        port.imageData == nil
    }

    /// `true`, wenn die Route-Sektion für diesen Port überhaupt eine PortMemoryCard zeigen
    /// soll. Echte Häfen zeigen die Karte immer (inkl. einladendem Zero-State). Seetage ohne
    /// erfasste Momente bleiben dagegen kompakt (keine Einladungs-Card) – nur wenn für einen
    /// Seetag bereits ein Foto oder ein Ausflug erfasst wurde, erscheint die Karte auch dort.
    static func shouldRender(for port: Port) -> Bool {
        !port.isSeaDay || port.imageData != nil || !port.excursions.isEmpty
    }
}

// MARK: - Preview

#Preview {
    let withMoments = Port(name: "Civitavecchia", country: "Italien", latitude: 42.09, longitude: 11.79)
    withMoments.excursions = ["Kolosseum", "Vatikan-Tour"]

    let zeroState = Port(name: "Santorini", country: "Griechenland", latitude: 36.39, longitude: 25.46)

    return VStack(spacing: 16) {
        PortMemoryCard(port: withMoments)
        PortMemoryCard(port: zeroState)
    }
    .padding()
}
