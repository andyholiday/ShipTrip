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
    
    // MARK: - Body
    
    var body: some View {
        NavigationStack {
            Group {
                if cruises.isEmpty {
                    emptyStateView
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
        }
    }
    
    // MARK: - Subviews
    
    private var cruiseList: some View {
        List {
            ForEach(filteredCruises) { cruise in
                NavigationLink(value: cruise) {
                    CruiseCardView(cruise: cruise)
                }
                .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                .listRowSeparator(.hidden)
            }
            .onDelete(perform: deleteCruises)
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
    
    private func deleteCruises(at offsets: IndexSet) {
        for index in offsets {
            let cruise = filteredCruises[index]
            modelContext.delete(cruise)
        }
    }
}

#Preview {
    CruiseListView()
        .modelContainer(for: [Cruise.self, Port.self, Expense.self, Deal.self], inMemory: true)
}
