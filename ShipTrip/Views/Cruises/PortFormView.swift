//
//  PortFormView.swift
//  ShipTrip
//
//  Created by ShipTrip on 18.12.25.
//

import SwiftUI
import SwiftData
import PhotosUI

/// Ermittelt das Standard-Ankunftsdatum für einen neuen Hafen: der Tag nach dem
/// Ankunftsdatum des letzten Stopps der (nach `sortOrder` sortierten) Route, sonst das
/// Startdatum der Kreuzfahrt. Sortiert bewusst selbst, statt sich auf die ungeordnete
/// SwiftData-Relationship `cruise.route` zu verlassen.
func defaultArrivalDateForNewPort(in cruise: Cruise, calendar: Calendar = .current) -> Date {
    let sortedRoute = cruise.route.sorted { $0.sortOrder < $1.sortOrder }
    guard let lastArrival = sortedRoute.last?.arrival else {
        return cruise.startDate
    }
    return calendar.date(byAdding: .day, value: 1, to: lastArrival) ?? lastArrival
}

/// Bereinigt einen neuen Ausflug-Eintrag: Kommas raus (Format-Trenner von
/// `Port.excursionsRaw`), Leerzeichen/Zeilenumbrüche trimmen. Leere Eingaben ergeben `nil`.
func sanitizedExcursionEntry(_ raw: String) -> String? {
    let cleaned = raw.replacingOccurrences(of: ",", with: "").trimmingCharacters(in: .whitespacesAndNewlines)
    return cleaned.isEmpty ? nil : cleaned
}

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

    // Hafenbild
    @State private var imageData: Data?
    @State private var selectedPhotoItem: PhotosPickerItem?

    // Ausflüge
    @State private var excursions: [String] = []
    @State private var newExcursionText = ""

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

                // Hafenbild
                Section(String(localized: "Hafenbild")) {
                    if let imageData, let uiImage = UIImage(data: imageData) {
                        HStack {
                            Image(uiImage: uiImage)
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .frame(width: 72, height: 72)
                                .clipShape(RoundedRectangle(cornerRadius: DesignRadius.sm))
                            Spacer()
                            Button(role: .destructive) {
                                self.imageData = nil
                                selectedPhotoItem = nil
                            } label: {
                                Label(String(localized: "Entfernen"), systemImage: "trash")
                            }
                        }
                    }

                    PhotosPicker(selection: $selectedPhotoItem, matching: .images) {
                        Label(
                            imageData == nil ? String(localized: "Bild auswählen") : String(localized: "Bild ersetzen"),
                            systemImage: "photo.on.rectangle.angled"
                        )
                    }
                }

                // Ausflüge
                Section(String(localized: "Ausflüge")) {
                    ForEach(Array(excursions.enumerated()), id: \.offset) { index, excursion in
                        HStack {
                            Text(excursion)
                            Spacer()
                            Button {
                                excursions.remove(at: index)
                            } label: {
                                Image(systemName: "minus.circle.fill")
                                    .foregroundStyle(.red)
                            }
                            .buttonStyle(.plain)
                            // .plain entfernt die Standard-Polsterung des Buttons; ohne festen
                            // Frame + contentShape bliebe die tatsächlich tappbare Fläche auf die
                            // reinen Glyphen-Pixel beschränkt (unzuverlässig, ~44pt-Mindestgröße
                            // laut HIG unterschritten).
                            .frame(width: 44, height: 44)
                            .contentShape(Rectangle())
                            .accessibilityLabel(String(localized: "Ausflug entfernen"))
                        }
                    }
                    .onDelete { excursions.remove(atOffsets: $0) }

                    HStack {
                        TextField(String(localized: "Ausflug hinzufügen"), text: $newExcursionText)
                            .onSubmit { addExcursion() }
                        Button {
                            addExcursion()
                        } label: {
                            Image(systemName: "plus.circle.fill")
                        }
                        .accessibilityLabel(String(localized: "Ausflug hinzufügen"))
                        .disabled(sanitizedExcursionEntry(newExcursionText) == nil)
                    }
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
                        // Land bewusst NICHT Pflicht: TempPortFormSheet erlaubt das Speichern
                        // schon immer ohne Land (nur `name.isEmpty` blockt dort). Ein Port mit
                        // leerem Land ist im Rest der App längst ein erwarteter Fall (siehe
                        // MapView/StatsView-Länderzählung, die leere Werte herausfiltern). Vorher
                        // blockte `country.isEmpty` hier zusätzlich Speichern – und weil das
                        // "Land"-Feld nur sichtbar ist, solange `name` leer ist, ließ sich ein
                        // bestehender Port mit leerem Land danach nie wieder speichern (auch keine
                        // anderen Änderungen wie das Löschen eines Ausflugs).
                        .disabled(name.isEmpty)
                }
            }
            .onAppear { loadExistingData() }
            .onChange(of: selectedPhotoItem) { _, newItem in
                loadImage(from: newItem)
            }
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
        guard let port = port else {
            // Neuer Hafen: Ankunft auf den Folgetag des letzten Stopps vorbelegen (A5.3).
            arrival = defaultArrivalDateForNewPort(in: cruise)
            departure = arrival
            return
        }
        name = port.name
        country = port.country
        latitude = String(port.latitude)
        longitude = String(port.longitude)
        arrival = port.arrival
        departure = port.departure
        imageData = port.imageData
        excursions = port.excursions
    }

    private func addExcursion() {
        guard let entry = sanitizedExcursionEntry(newExcursionText) else { return }
        excursions.append(entry)
        newExcursionText = ""
    }

    private func loadImage(from item: PhotosPickerItem?) {
        guard let item else { return }
        Task {
            if let data = try? await item.loadTransferable(type: Data.self) {
                await MainActor.run {
                    imageData = data
                }
            }
        }
    }

    private func savePort() {
        let lat = Double(latitude) ?? 0
        let lon = Double(longitude) ?? 0

        let now = Date()

        if let existingPort = port {
            // Update
            existingPort.name = name
            existingPort.country = country
            existingPort.latitude = lat
            existingPort.longitude = lon
            existingPort.arrival = arrival
            existingPort.departure = departure
            existingPort.imageData = imageData
            existingPort.excursions = excursions
            existingPort.updatedAt = now
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
            newPort.imageData = imageData
            newPort.excursions = excursions
            newPort.cruise = cruise
            modelContext.insert(newPort)
        }

        // Eltern-Kreuzfahrt als geändert markieren (Last-Writer-Wins unter CloudKit)
        cruise.updatedAt = now

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
