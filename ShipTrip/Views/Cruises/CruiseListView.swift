//
//  CruiseListView.swift
//  ShipTrip
//
//  Created by ShipTrip on 18.12.25.
//

import SwiftUI
import SwiftData

/// Hauptansicht: Liste aller Kreuzfahrten
struct CruiseListView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Cruise.startDate, order: .reverse) private var cruises: [Cruise]
    
    @State private var searchText = ""
    @State private var showingAddSheet = false
    @State private var selectedYear: Int?
    @State private var selectedShippingLine: String?
    
    // MARK: - Computed Properties
    
    private var filteredCruises: [Cruise] {
        var result = cruises
        
        // Textsuche
        if !searchText.isEmpty {
            result = result.filter {
                $0.title.localizedCaseInsensitiveContains(searchText) ||
                $0.ship.localizedCaseInsensitiveContains(searchText) ||
                $0.shippingLine.localizedCaseInsensitiveContains(searchText)
            }
        }
        
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

    /// Schwerpunkt-Reise: laufende Reise zuerst, dann nächste bevorstehende, sonst zuletzt vergangene.
    private var heroCruise: Cruise? {
        filteredCruises.first { $0.isOngoing }
            ?? filteredCruises.filter { $0.isUpcoming }.min { $0.startDate < $1.startDate }
            ?? filteredCruises.first { !$0.isUpcoming }
            ?? filteredCruises.first
    }

    /// Übrige Reisen für den Zeitstrahl (ohne die Hero-Reise), nach Jahr gruppiert (neueste zuerst).
    private var timelineCruises: [Cruise] {
        guard let hero = heroCruise else { return filteredCruises }
        return filteredCruises.filter { $0.id != hero.id }
    }

    // MARK: - Body
    
    var body: some View {
        NavigationStack {
            Group {
                if cruises.isEmpty {
                    emptyStateView
                } else if filteredCruises.isEmpty {
                    ContentUnavailableView.search(text: searchText.isEmpty ? String(localized: "Keine Treffer") : searchText)
                } else {
                    cruiseList
                }
            }
            .navigationTitle("Meine Reisen")
            .searchable(text: $searchText, prompt: "Suchen...")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showingAddSheet = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }
                
                if !cruises.isEmpty {
                    ToolbarItem(placement: .navigationBarLeading) {
                        filterMenu
                    }
                }
            }
            .sheet(isPresented: $showingAddSheet) {
                CruiseFormView(cruise: nil)
            }
            // Einmalige Start-Reparaturen (Altdaten-Migration):
            // 1. IdBackfill: korrigiert UUID-Kollisionen aus Lightweight-Migration v1.5.0
            // 2. ThumbnailBackfill: setzt thumbnailData für Fotos ohne Vorschaubild
            .task {
                IdBackfill.run(context: modelContext)
                await ThumbnailBackfill.run(context: modelContext)
            }
        }
    }
    
    // MARK: - Subviews
    
    private var cruiseList: some View {
        List {
            // 1. Stats-Strip: immer mit dem vollständigen Cruise-Set (Lifetime-Totals)
            Section {
                CruiseStatsStripView(cruises: cruises)
                    .listRowInsets(EdgeInsets())
                    .listRowSeparator(.hidden)
            }

            // 2. Hero-Karte
            if let hero = heroCruise {
                Section {
                    NavigationLink(value: hero) {
                        CruiseHeroCardView(cruise: hero)
                    }
                    .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                    .listRowSeparator(.hidden)
                    .swipeActions(edge: .trailing) {
                        Button(role: .destructive) {
                            deleteCruise(hero)
                        } label: {
                            Label("Löschen", systemImage: "trash")
                        }
                    }
                }
            }

            // 3. Zeitstrahl: nach Jahr gruppiert, neueste zuerst
            let yearGroups = Dictionary(grouping: timelineCruises, by: { $0.year })
            let sortedYears = yearGroups.keys.sorted(by: >)
            ForEach(sortedYears, id: \.self) { year in
                Section(header: CruiseYearDivider(year: year).listRowInsets(EdgeInsets())) {
                    ForEach(yearGroups[year] ?? []) { cruise in
                        NavigationLink(value: cruise) {
                            CruiseTimelineRowView(cruise: cruise)
                        }
                        .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
                        .listRowSeparator(.hidden)
                        .swipeActions(edge: .trailing) {
                            Button(role: .destructive) {
                                deleteCruise(cruise)
                            } label: {
                                Label("Löschen", systemImage: "trash")
                            }
                        }
                    }
                }
            }
        }
        .listStyle(.plain)
        .navigationDestination(for: Cruise.self) { cruise in
            CruiseDetailView(cruise: cruise)
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
            Menu("Jahr") {
                Button("Alle Jahre") {
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
            Menu("Reederei") {
                Button("Alle Reedereien") {
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
                Button("Filter zurücksetzen", role: .destructive) {
                    selectedYear = nil
                    selectedShippingLine = nil
                }
            }
        } label: {
            Image(systemName: hasActiveFilters ? "line.3.horizontal.decrease.circle.fill" : "line.3.horizontal.decrease.circle")
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
