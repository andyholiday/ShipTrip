//
//  RouteMenuPanelView.swift
//  ShipTrip
//
//  Inhalt des Routen-Auswahl-Popovers (Design-Politur Welle C, F2) — reine Präsentations-
//  verschiebung aus `MapView.routeMenuItems`: dieselben Daten (`routableCruises`,
//  `activeRouteIDs`, `toggleAllRoutesVisibility()`, `toggle(route:)`), keine neue Logik in
//  `MapRouteVisibilityPlanner`. Dismiss-Steuerung übernimmt `MapView` über die beiden
//  Closures — dieses View kennt `isRouteMenuOpen` nicht selbst.
//

import SwiftUI

struct RouteMenuPanelView: View {
    let routableCruises: [(index: Int, cruise: Cruise)]
    let activeRouteIDs: Set<UUID>
    let allRoutesCurrentlyVisible: Bool
    let onToggleAll: () -> Void
    let onToggle: ((index: Int, cruise: Cruise)) -> Void

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        VStack(spacing: 0) {
            allRow

            Rectangle()
                .fill(Color.journalTimeline)
                .frame(height: 1)

            ScrollView {
                VStack(spacing: 4) {
                    ForEach(routableCruises, id: \.cruise.id) { route in
                        routeRow(for: route)
                    }
                }
                .padding(.vertical, 4)
            }
        }
    }

    // MARK: - „Alle anzeigen/ausblenden"-Zeile

    private var allRow: some View {
        Button(action: onToggleAll) {
            HStack(spacing: 12) {
                Image(systemName: allRoutesCurrentlyVisible ? "eye.slash.fill" : "eye.fill")
                    .foregroundStyle(Color.oceanBlue)
                Text(allRoutesCurrentlyVisible ? String(localized: "Alle ausblenden") : String(localized: "Alle Reisen anzeigen"))
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 16)
            .frame(minHeight: 44)
            .background(allRowTint)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private var allRowTint: Color {
        Color.oceanBlue.opacity(colorScheme == .dark ? 0.10 : 0.06)
    }

    // MARK: - Routenzeilen

    private func routeRow(for route: (index: Int, cruise: Cruise)) -> some View {
        let isActive = activeRouteIDs.contains(route.cruise.id)

        return Button {
            onToggle(route)
        } label: {
            HStack(spacing: 12) {
                selectionIcon(color: Color.routeColor(at: route.index), isActive: isActive)
                Text(route.cruise.title)
                    .font(.subheadline)
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .foregroundStyle(.primary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(.horizontal, 16)
            .frame(minHeight: 44)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text(routeAccessibilityLabel(title: route.cruise.title, isActive: isActive)))
    }

    /// Ein Icon-*System*, zwei Zustände derselben Form (24pt-Kreis): gefüllt + weißer Checkmark
    /// wenn aktiv, nur 1.5pt-Outline (keine Füllung) wenn inaktiv — kein Formwechsel mehr
    /// zwischen den Zuständen (IST-Kritik F2: `"checkmark"` vs. `"circle"` wirkte unruhig).
    private func selectionIcon(color: Color, isActive: Bool) -> some View {
        Circle()
            .fill(isActive ? color : Color.clear)
            .overlay(Circle().strokeBorder(color, lineWidth: isActive ? 0 : 1.5))
            .overlay {
                if isActive {
                    Image(systemName: "checkmark")
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(.white)
                }
            }
            .frame(width: 24, height: 24)
    }

    private func routeAccessibilityLabel(title: String, isActive: Bool) -> String {
        let state = isActive ? String(localized: "ausgewählt") : String(localized: "nicht ausgewählt")
        return "\(String(localized: "Route")), \(title), \(state)"
    }
}

// MARK: - Preview

#Preview {
    RouteMenuPanelView(
        routableCruises: [
            (index: 0, cruise: Cruise(title: "7 Nächte Norwegen mit Geirangerfjord - ab/bis Kiel", startDate: .now, endDate: .now, shippingLine: "AIDA", ship: "AIDAcosma")),
            (index: 1, cruise: Cruise(title: "14 Nächte - Kanaren, Madeira und marokkanisches Flair", startDate: .now, endDate: .now, shippingLine: "AIDA", ship: "AIDAcosma")),
        ],
        activeRouteIDs: [],
        allRoutesCurrentlyVisible: true,
        onToggleAll: {},
        onToggle: { _ in }
    )
    .frame(maxWidth: 300, maxHeight: 380)
    .background(Color.journalSurface)
}
