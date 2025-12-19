//
//  PortFormView.swift
//  ShipTrip
//
//  Created by ShipTrip on 18.12.25.
//

import SwiftUI
import SwiftData

/// Formular zum Hinzufügen/Bearbeiten eines Hafens
struct PortFormView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    
    let cruise: Cruise
    let port: Port?
    
    // Form State
    @State private var name = ""
    @State private var country = ""
    @State private var latitude = ""
    @State private var longitude = ""
    @State private var arrival = Date()
    @State private var departure = Date()
    
    // Suggestions
    @State private var searchText = ""
    @State private var showingSuggestions = false
    
    private var isEditing: Bool { port != nil }
    
    private var filteredSuggestions: [PortSuggestion] {
        guard !searchText.isEmpty else { return [] }
        return PortSuggestion.search(searchText).prefix(5).map { $0 }
    }
    
    var body: some View {
        NavigationStack {
            Form {
                // Hafen-Suche mit Vorschlägen
                Section("Hafen") {
                    TextField("Hafen suchen...", text: $searchText)
                        .onChange(of: searchText) { _, newValue in
                            showingSuggestions = !newValue.isEmpty && name.isEmpty
                        }
                    
                    if showingSuggestions && !filteredSuggestions.isEmpty {
                        ForEach(filteredSuggestions) { suggestion in
                            Button {
                                selectSuggestion(suggestion)
                            } label: {
                                HStack {
                                    VStack(alignment: .leading) {
                                        Text(suggestion.name)
                                            .foregroundStyle(.primary)
                                        Text(suggestion.country)
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                    Spacer()
                                    Image(systemName: "arrow.up.left")
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                    
                    if !name.isEmpty {
                        HStack {
                            VStack(alignment: .leading) {
                                Text(name)
                                    .font(.headline)
                                Text(country)
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Button {
                                clearSelection()
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }
                
                // Manuelle Eingabe (falls kein Vorschlag)
                if name.isEmpty {
                    Section("Manuell eingeben") {
                        TextField("Hafenname", text: $name)
                        TextField("Land", text: $country)
                        
                        HStack {
                            TextField("Breitengrad", text: $latitude)
                                .keyboardType(.decimalPad)
                            TextField("Längengrad", text: $longitude)
                                .keyboardType(.decimalPad)
                        }
                    }
                }
                
                // Zeiten
                Section("Ankunft & Abfahrt") {
                    DatePicker("Ankunft", selection: $arrival)
                    DatePicker("Abfahrt", selection: $departure, in: arrival...)
                }
            }
            .navigationTitle(isEditing ? "Hafen bearbeiten" : "Hafen hinzufügen")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Abbrechen") { dismiss() }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("Speichern") { savePort() }
                        .disabled(name.isEmpty || country.isEmpty)
                }
            }
            .onAppear { loadExistingData() }
        }
    }
    
    // MARK: - Actions
    
    private func selectSuggestion(_ suggestion: PortSuggestion) {
        name = suggestion.name
        country = suggestion.country
        latitude = String(suggestion.latitude)
        longitude = String(suggestion.longitude)
        searchText = ""
        showingSuggestions = false
    }
    
    private func clearSelection() {
        name = ""
        country = ""
        latitude = ""
        longitude = ""
        searchText = ""
        showingSuggestions = false
    }
    
    private func loadExistingData() {
        guard let port = port else { return }
        name = port.name
        country = port.country
        latitude = String(port.latitude)
        longitude = String(port.longitude)
        arrival = port.arrival
        departure = port.departure
    }
    
    private func savePort() {
        let lat = Double(latitude) ?? 0
        let lon = Double(longitude) ?? 0
        
        if let existingPort = port {
            // Update
            existingPort.name = name
            existingPort.country = country
            existingPort.latitude = lat
            existingPort.longitude = lon
            existingPort.arrival = arrival
            existingPort.departure = departure
        } else {
            // Create new
            let newPort = Port(
                name: name,
                country: country,
                latitude: lat,
                longitude: lon
            )
            newPort.arrival = arrival
            newPort.departure = departure
            newPort.sortOrder = cruise.route.count
            newPort.cruise = cruise
            modelContext.insert(newPort)
        }
        
        dismiss()
    }
}

#Preview {
    PortFormView(
        cruise: Cruise(
            title: "Test",
            startDate: Date(),
            endDate: Date(),
            shippingLine: "Test",
            ship: "Test"
        ),
        port: nil
    )
    .modelContainer(for: [Cruise.self, Port.self], inMemory: true)
}
