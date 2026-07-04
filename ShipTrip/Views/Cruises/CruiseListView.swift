//
//  CruiseListView.swift
//  ShipTrip
//
//  Created by ShipTrip on 18.12.25.
//

import SwiftUI
import SwiftData
import UIKit

/// Hauptansicht: Liste aller Kreuzfahrten
struct CruiseListView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Cruise.startDate, order: .reverse) private var cruises: [Cruise]
    
    @State private var showingAddSheet = false
    @State private var selectedYear: Int?
    @State private var selectedShippingLine: String?
    @State private var navigationPath = NavigationPath()
    
    // MARK: - Computed Properties
    
    private var filteredCruises: [Cruise] {
        var result = cruises

        // Jahr-Filter
        if let year = selectedYear {
            result = result.filter { $0.year == year }
        }
        
        // Reederei-Filter
        if let line = selectedShippingLine {
            result = result.filter { $0.shippingLine == line }
        }
        
        return result
    }
    
    private var availableYears: [Int] {
        Array(Set(cruises.map { $0.year })).sorted(by: >)
    }
    
    private var availableShippingLines: [String] {
        Array(Set(cruises.map { $0.shippingLine })).sorted()
    }

    /// Schwerpunkt-Reise: laufende Reise zuerst, dann nächste bevorstehende.
    /// Vergangene Reisen bleiben vollständig im nach Jahren gruppierten Reiselogbuch.
    private var heroCruise: Cruise? {
        filteredCruises.first { $0.isOngoing }
            ?? filteredCruises.filter { $0.isUpcoming }.min { $0.startDate < $1.startDate }
    }

    /// Übrige Reisen für den Zeitstrahl (ohne die Hero-Reise), nach Jahr gruppiert (neueste zuerst).
    private var timelineCruises: [Cruise] {
        guard let hero = heroCruise else { return filteredCruises }
        return filteredCruises.filter { $0.id != hero.id }
    }

    private var nextUpcomingCruise: Cruise? {
        cruises.filter(\.isUpcoming).min { $0.startDate < $1.startDate }
    }

    private var appSubline: String {
        if let nextUpcomingCruise {
            let days = Calendar.current.dateComponents(
                [.day],
                from: Calendar.current.startOfDay(for: .now),
                to: Calendar.current.startOfDay(for: nextUpcomingCruise.startDate)
            ).day ?? 0
            return String(localized: "\(cruises.count) Reisen · \(cruises.uniqueCountryCount) Länder · nächste Reise in \(days) Tagen")
        }
        return String(localized: "\(cruises.count) Reisen · \(cruises.uniqueCountryCount) Länder · Reiselogbuch")
    }

    // MARK: - Body
    
    var body: some View {
        NavigationStack(path: $navigationPath) {
            Group {
                if cruises.isEmpty {
                    emptyStateView
                } else if filteredCruises.isEmpty {
                    ContentUnavailableView(String(localized: "Keine Treffer"), systemImage: "line.3.horizontal.decrease.circle")
                } else {
                    cruiseList
                }
            }
            .toolbar(.hidden, for: .navigationBar)
            .sheet(isPresented: $showingAddSheet) {
                CruiseFormView(cruise: nil)
            }
            // Einmalige Start-Reparaturen (Altdaten-Migration):
            // 1. IdBackfill: korrigiert UUID-Kollisionen aus Lightweight-Migration v1.5.0
            // 2. ThumbnailBackfill: setzt thumbnailData für Fotos ohne Vorschaubild
            // 3. ShippingLineCatalogDedup: räumt Cross-Device-Duplikate eigener Reedereien/Schiffe
            //    und Hidden-Einträge auf (ADR-006)
            .task {
                IdBackfill.run(context: modelContext)
                await ThumbnailBackfill.run(context: modelContext)
                ShippingLineCatalogDedup.run(context: modelContext)
            }
        }
    }
    
    // MARK: - Subviews
    
    private var cruiseList: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 14) {
                topActions

                VStack(alignment: .leading, spacing: 5) {
                    Text(String(localized: "Meine Reisen"))
                        .font(.largeTitle)
                        .fontWeight(.heavy)
                        .lineLimit(1)
                        .minimumScaleFactor(0.82)

                    Text(appSubline)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
                .padding(.bottom, 4)

                // 1. Ruhige Lebenszeit-Bilanz
                CruiseStatsStripView(cruises: cruises)
                    .padding(.bottom, 6)

                // 2. Hero-Karte: nur laufende oder nächste Reise
                if let hero = heroCruise {
                    Button {
                        navigationPath.append(hero)
                    } label: {
                        CruiseHeroCardView(cruise: hero)
                    }
                    .buttonStyle(.plain)
                    .contentShape(RoundedRectangle(cornerRadius: DesignRadius.lg))
                    .contextMenu {
                        Button(role: .destructive) {
                            deleteCruise(hero)
                        } label: {
                            Label("Löschen", systemImage: "trash")
                        }
                    }
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel(String(localized: "Reise \(hero.title) öffnen"))
                    .accessibilityIdentifier("heroCard")
                }

                // 3. Reiselogbuch: nach Jahr gruppiert, neueste zuerst
                journalList
            }
            .padding(.horizontal, 20)
            .padding(.top, 10)
            .padding(.bottom, 128)
        }
        .background(Color(UIColor.systemGroupedBackground).ignoresSafeArea())
        .overlay(alignment: .top) {
            Color(UIColor.systemGroupedBackground)
                .frame(height: 62)
                .ignoresSafeArea(edges: .top)
                .allowsHitTesting(false)
        }
        .navigationDestination(for: Cruise.self) { cruise in
            CruiseDetailView(cruise: cruise)
        }
    }

    private var topActions: some View {
        HStack {
            filterMenu

            Spacer()

            Button {
                showingAddSheet = true
            } label: {
                Image(systemName: "plus")
                    .font(.title2.weight(.semibold))
                    .frame(width: 42, height: 42)
                    .background(.ultraThinMaterial)
                    .clipShape(Circle())
                    .shadow(color: Color.navyDark.opacity(0.08), radius: 11, y: 4)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(Text(String(localized: "Neue Reise")))
        }
        .padding(.bottom, 14)
    }

    private var journalList: some View {
        let yearGroups = Dictionary(grouping: timelineCruises, by: { $0.year })
        let sortedYears = yearGroups.keys.sorted(by: >)

        return VStack(alignment: .leading, spacing: 12) {
            Text(String(localized: "Reiselogbuch"))
                .font(.caption)
                .fontWeight(.heavy)
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
                .padding(.top, 14)
                .padding(.bottom, 2)

            ForEach(sortedYears, id: \.self) { year in
                let yearCruises = yearGroups[year] ?? []

                CruiseYearDivider(year: year, count: yearCruises.count)

                ForEach(Array(yearCruises.enumerated()), id: \.element.id) { offset, cruise in
                    Button {
                        navigationPath.append(cruise)
                    } label: {
                        CruiseHeroCardView(cruise: cruise)
                    }
                    .buttonStyle(.plain)
                    .contentShape(RoundedRectangle(cornerRadius: DesignRadius.lg))
                    .contextMenu {
                        Button(role: .destructive) {
                            deleteCruise(cruise)
                        } label: {
                            Label("Löschen", systemImage: "trash")
                        }
                    }

                    if offset < yearCruises.count - 1 {
                        Color.clear
                            .frame(height: 2)
                    }
                }
            }
        }
    }

    private var emptyStateView: some View {
        ContentUnavailableView {
            Label("Keine Kreuzfahrten", systemImage: "ferry")
        } description: {
            Text("Tippe auf + um deine erste Kreuzfahrt hinzuzufügen")
        } actions: {
            Button {
                showingAddSheet = true
            } label: {
                Text("Kreuzfahrt hinzufügen")
            }
            .buttonStyle(.borderedProminent)
        }
    }
    
    private var filterMenu: some View {
        Menu {
            // Jahr-Filter
            Menu(String(localized: "Jahr")) {
                Button(String(localized: "Alle Jahre")) {
                    selectedYear = nil
                }
                Divider()
                ForEach(availableYears, id: \.self) { year in
                    Button {
                        selectedYear = year
                    } label: {
                        HStack {
                            Text(String(year))
                            if selectedYear == year {
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                }
            }
            
            // Reederei-Filter
            Menu(String(localized: "Reederei")) {
                Button(String(localized: "Alle Reedereien")) {
                    selectedShippingLine = nil
                }
                Divider()
                ForEach(availableShippingLines, id: \.self) { line in
                    Button {
                        selectedShippingLine = line
                    } label: {
                        HStack {
                            Text(line)
                            if selectedShippingLine == line {
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                }
            }
            
            if selectedYear != nil || selectedShippingLine != nil {
                Divider()
                Button(String(localized: "Filter zurücksetzen"), role: .destructive) {
                    selectedYear = nil
                    selectedShippingLine = nil
                }
            }
        } label: {
            Image(systemName: hasActiveFilters ? "line.3.horizontal.decrease.circle.fill" : "line.3.horizontal.decrease.circle")
                .font(.title2.weight(.semibold))
                .frame(width: 42, height: 42)
                .background(.ultraThinMaterial)
                .clipShape(Circle())
                .shadow(color: Color.navyDark.opacity(0.08), radius: 11, y: 4)
        }
    }
    
    private var hasActiveFilters: Bool {
        selectedYear != nil || selectedShippingLine != nil
    }
    
    // MARK: - Actions
    
    private func deleteCruise(_ cruise: Cruise) {
        // ID synchron lesen bevor das Objekt gelöscht wird – kein @Model über Aktorgrenzen
        let cruiseID = String(describing: cruise.persistentModelID)
        Task { await NotificationService.shared.removeReminders(cruiseID: cruiseID) }
        modelContext.delete(cruise)
    }
}

#Preview {
    CruiseListView()
        .modelContainer(for: [Cruise.self, Port.self, Expense.self, Deal.self], inMemory: true)
}
