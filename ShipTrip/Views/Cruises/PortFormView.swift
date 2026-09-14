//
//  PortFormView.swift
//  ShipTrip
//
//  Created by ShipTrip on 18.12.25.
//

import SwiftUI
import SwiftData

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

/// Locale-toleranter Parser für Breiten-/Längengrad: akzeptiert Komma und Punkt als
/// Dezimaltrennzeichen (M5). Gibt `nil` bei ungültiger Eingabe zurück statt still auf 0.
func parseCoordinate(_ text: String) -> Double? {
    let trimmed = text.trimmingCharacters(in: .whitespaces)
    guard !trimmed.isEmpty else { return nil }
    let formatter = NumberFormatter()
    formatter.numberStyle = .decimal
    formatter.usesGroupingSeparator = false
    for separator in [",", "."] {
        formatter.decimalSeparator = separator
        if let number = formatter.number(from: trimmed) {
            return number.doubleValue
        }
    }
    return nil
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

    /// Ob die manuelle Eingabe-Section sichtbar ist – expliziter Modus statt `if
    /// name.isEmpty` (H2), sonst verschwindet sie beim ersten getippten Zeichen.
    @State private var isManualEntry = false

    // Hafenbild
    @State private var imageData: Data?

    // Ausflüge
    @State private var excursions: [String] = []

    // Suggestions
    @State private var searchText = ""
    @State private var showingSuggestions = false
    
    private var isEditing: Bool { port != nil }

    private var filteredSuggestions: [PortSuggestion] {
        guard !searchText.isEmpty else { return [] }
        return PortSuggestion.search(searchText).prefix(5).map { $0 }
    }

    /// Leere Felder sind erlaubt; nur nicht-leere, unparsbare Eingaben blockieren (M5).
    private var isCoordinateValid: Bool {
        (latitude.isEmpty || parseCoordinate(latitude) != nil)
            && (longitude.isEmpty || parseCoordinate(longitude) != nil)
    }
    
    var body: some View {
        NavigationStack {
            Form {
                // Hafen-Suche mit Vorschlägen (nur im Such-Modus; s. isManualEntry)
                if !isManualEntry {
                    Section("Hafen") {
                        TextField("Hafen suchen...", text: $searchText)
                            .onChange(of: searchText) { _, newValue in
                                showingSuggestions = !newValue.isEmpty
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
                                            Text(suggestion.localizedCountry)
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
                                    Text(PortCountryCatalog.localizedName(for: country))
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
                        } else {
                            Button {
                                isManualEntry = true
                            } label: {
                                Label(String(localized: "Manuell eingeben"), systemImage: "square.and.pencil")
                            }
                        }
                    }
                }

                // Manuelle Eingabe (H2); Bestandsport startet hier direkt, s. loadExistingData().
                if isManualEntry {
                    Section("Manuell eingeben") {
                        TextField("Hafenname", text: $name)
                        TextField("Land", text: $country)

                        HStack {
                            TextField("Breitengrad", text: $latitude)
                                .keyboardType(.decimalPad)
                            TextField("Längengrad", text: $longitude)
                                .keyboardType(.decimalPad)
                        }
                        if !isCoordinateValid {
                            Text(String(localized: "Ungültige Koordinate – bitte z. B. „53,5“ oder „53.5“ eingeben"))
                                .font(.caption)
                                .foregroundStyle(.red)
                        }

                        // Rückweg ohne Reset (Codex-Gate #2): nur Moduswechsel, Eingaben bleiben
                        // erhalten. Der "X"-Button oben bleibt der einzige echte Reset-Pfad.
                        Button {
                            isManualEntry = false
                        } label: {
                            Label(String(localized: "Zur Suche"), systemImage: "magnifyingglass")
                        }
                    }
                }
                
                // Zeiten
                Section("Ankunft & Abfahrt") {
                    DatePicker("Ankunft", selection: $arrival)
                    DatePicker("Abfahrt", selection: $departure, in: arrival...)
                }

                HafenMomenteSection(imageData: $imageData, excursions: $excursions)
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
                        // Zusätzlich gesperrt bei ungültiger Koordinaten-Eingabe (M5).
                        .disabled(name.isEmpty || !isCoordinateValid)
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
        isManualEntry = false
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
        isManualEntry = true // Bestandsport direkt korrigierbar (H2), nicht nur via "X"-Reset
    }

    private func savePort() {
        // Leer = bewusst keine Koordinate (0/0); Save-Button sperrt unparsbare Eingaben bereits.
        let lat = latitude.isEmpty ? 0 : (parseCoordinate(latitude) ?? 0)
        let lon = longitude.isEmpty ? 0 : (parseCoordinate(longitude) ?? 0)

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
