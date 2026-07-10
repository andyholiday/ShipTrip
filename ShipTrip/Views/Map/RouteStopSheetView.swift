//
//  RouteStopSheetView.swift
//  ShipTrip
//
//  Bottom-Sheet für die Routen-Details (Karten-Redesign v2 „Journal Atlas", B4.3b-2).
//

import SwiftUI

/// Inhalt des Routen-Sheets: Peek zeigt Titel + Substats, Medium ergänzt eine scrollbare
/// Stop-Liste mit gepunkteter Timeline, Large ergänzt den „Öffnen"-CTA zur vollen
/// `CruiseDetailView`. Reine Präsentation — Kamera-Sprung und Navigation laufen über die
/// übergebenen Closures, das Sheet kennt `MapView`s State nicht direkt.
struct RouteStopSheetView: View {
    let cruise: Cruise
    let ports: [MapPortRole]
    let routeColor: Color
    @Binding var selectedStopID: UUID?
    @Binding var detent: PresentationDetent
    let onStopTap: (Port) -> Void
    let onOpen: () -> Void

    /// F3 (Design-Politur Welle C): treibt die Pin-Platzhalter-Kontrastfarben — Fill+Rand
    /// brauchen unterschiedliche Werte in Light/Dark (siehe `pinPlaceholderFill`/-`Border`).
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        VStack(spacing: 0) {
            header
                .padding(.horizontal, 20)
                .padding(.top, 12)
                .padding(.bottom, 12)

            if detent != .height(140) {
                stopList
            }

            if detent == .large {
                openButton
                    .padding(.horizontal, 20)
                    .padding(.bottom, 16)
            }
        }
    }

    // MARK: - Peek: Titel + Substats

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(cruise.title)
                .font(.headline)
                .lineLimit(1)
            Text(substats)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var substats: String {
        let countries = Set(ports.map(\.port.country)).filter { !$0.isEmpty }.count
        return "\(cruise.duration) \(String(localized: "Tage")) · \(ports.count) \(String(localized: "Häfen")) · \(countries) \(String(localized: "Länder"))"
    }

    // MARK: - Medium: Stop-Liste mit gepunkteter Timeline

    private var stopList: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                ForEach(Array(ports.enumerated()), id: \.element.id) { index, role in
                    stopRow(role, isLast: index == ports.count - 1)
                }
            }
            .padding(.horizontal, 20)
        }
        // F3: verhindert Rubber-Banding bei kurzen Listen, das sonst zusätzlich mit dem
        // Sheet-Drag um denselben Touch konkurriert (zusammen mit `.presentationContentInteraction(.resizes)`
        // am `.sheet{}`-Aufruf in MapView.swift).
        .scrollBounceBehavior(.basedOnSize)
    }

    private func stopRow(_ role: MapPortRole, isLast: Bool) -> some View {
        let isSelected = selectedStopID == role.port.id

        return Button {
            selectedStopID = role.port.id
            onStopTap(role.port)
        } label: {
            HStack(spacing: 12) {
                ZStack {
                    if !isLast {
                        TimelineConnectorShape()
                            .stroke(Color.journalTimeline, style: StrokeStyle(lineWidth: 2, dash: [3, 5]))
                    }
                    leadingBadge(for: role, isSelected: isSelected)
                }
                .frame(width: 32)

                VStack(alignment: .leading, spacing: 2) {
                    Text(role.port.name)
                        .font(.body.weight(.semibold))
                        .foregroundStyle(.primary)
                    Text(role.port.country)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                trailingThumbnail(for: role.port)
            }
            .padding(.vertical, 10)
            .frame(minHeight: 56)
            // F3: Chip statt Full-Bleed-Wash — 4pt Inset gegenüber der Row-Kante lässt die
            // Auswahl als schwebendes Element statt als screen-breiten Wisch wirken; Rand
            // kommuniziert die Routenfarbe zusätzlich zum Fill.
            .background(
                RoundedRectangle(cornerRadius: DesignRadius.sm)
                    .fill(isSelected ? routeColor.opacity(0.12) : Color.clear)
                    .overlay(
                        RoundedRectangle(cornerRadius: DesignRadius.sm)
                            .strokeBorder(isSelected ? routeColor.opacity(0.35) : Color.clear, lineWidth: 1)
                    )
                    .padding(.horizontal, 4)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private func leadingBadge(for role: MapPortRole, isSelected: Bool) -> some View {
        if role.type == .port {
            MapStopBadgeView(number: role.stopNumber, color: routeColor, isSelected: isSelected)
        } else {
            PortPinView(type: role.type)
                .padding(4)
                .background(Circle().fill(Color.journalSurface))
                // Spiegelt das bestehende Selected-Highlight der Karten-Pins (siehe
                // `MapView.markerView(for:isSelected:)`), das `Color.oceanBlue` nutzt, nicht `.white`.
                .overlay(Circle().strokeBorder(Color.oceanBlue, lineWidth: isSelected ? 3 : 0))
        }
    }

    @ViewBuilder
    private func trailingThumbnail(for port: Port) -> some View {
        if let imageData = port.imageData {
            AsyncPhotoView(imageData: imageData, maxPixelSize: 80)
                .frame(width: 40, height: 40)
                .clipShape(RoundedRectangle(cornerRadius: 8))
        } else {
            Image(systemName: "mappin")
                .foregroundStyle(.secondary)
                .frame(width: 40, height: 40)
                .background(pinPlaceholderFill)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .strokeBorder(pinPlaceholderBorder, lineWidth: 1)
                )
                .clipShape(RoundedRectangle(cornerRadius: 8))
        }
    }

    /// F3: reine Hairline ohne Fill hatte auf dem hellen `journalSurface`-Ton bei Sonnenlicht zu
    /// wenig Kontrast (Gemini-Gate #5a) — ersetzt `Color.gray.opacity(0.15)`. Opacity-Werte in
    /// `MapPinPlaceholderTokens` (Color+Theme.swift), damit `MapPinPlaceholderContrastTests`
    /// dieselben Werte verifizieren kann, die hier tatsächlich gerendert werden.
    private var pinPlaceholderFill: Color {
        colorScheme == .dark
            ? Color.white.opacity(MapPinPlaceholderTokens.fillOpacityDark)
            : Color.navyDark.opacity(MapPinPlaceholderTokens.fillOpacityLight)
    }

    /// Werte per Hand gegen die sRGB-Relativluminanz-Formel nachgerechnet (Gate #5b): 0.14/0.16
    /// ergeben nur ~1.3:1 Kontrast gegen `journalSurface`, auch 0.30 bleibt bei ~1.8:1 unter dem
    /// 3:1-Ziel — erst ab ~0.5–0.55 (Light) bzw. ~0.35–0.4 (Dark) wird 3:1 überschritten. Jetzt
    /// zusätzlich per `MapPinPlaceholderContrastTests` gegen die echten `Color+Theme.swift`-
    /// Konstanten verifiziert (Fix-Runde 1, F03a) statt nur behauptet.
    private var pinPlaceholderBorder: Color {
        colorScheme == .dark
            ? Color.white.opacity(MapPinPlaceholderTokens.borderOpacityDark)
            : Color.navyDark.opacity(MapPinPlaceholderTokens.borderOpacityLight)
    }

    // MARK: - Large: „Öffnen"-CTA

    private var openButton: some View {
        Button(action: onOpen) {
            Text(String(localized: "Öffnen"))
                .font(.headline)
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(Color.oceanBlue)
                .clipShape(RoundedRectangle(cornerRadius: DesignRadius.md))
        }
    }
}

/// Senkrechte Verbindungslinie zwischen zwei Stop-Rows (Grundlage für die gepunktete Timeline).
private struct TimelineConnectorShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.midX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.midX, y: rect.maxY))
        return path
    }
}

// MARK: - Preview

#Preview {
    @Previewable @State var selectedStopID: UUID?
    @Previewable @State var detent: PresentationDetent = .medium

    let cruise = Cruise(title: "Mittelmeer-Route", startDate: .now, endDate: .now.addingTimeInterval(7 * 86_400), shippingLine: "AIDA", ship: "AIDAcosma")
    let ports = [
        MapPortRole(id: UUID(), port: Port(name: "Barcelona", country: "Spanien", latitude: 41.38, longitude: 2.17), type: .homePort, stopNumber: 1),
        MapPortRole(id: UUID(), port: Port(name: "Marseille", country: "Frankreich", latitude: 43.30, longitude: 5.37), type: .port, stopNumber: 2),
        MapPortRole(id: UUID(), port: Port(name: "Genua", country: "Italien", latitude: 44.41, longitude: 8.93), type: .endPort, stopNumber: 3),
    ]

    return RouteStopSheetView(
        cruise: cruise,
        ports: ports,
        routeColor: .oceanBlue,
        selectedStopID: $selectedStopID,
        detent: $detent,
        onStopTap: { _ in },
        onOpen: {}
    )
}
