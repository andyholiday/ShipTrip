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
    // B7.1/A2 (Gate #2 Fix, Plan B): natives List-EditMode zeigt die Reorder-Griffe in der
    // echten Form/List zuverlässig NICHT (zweifach per UI-Test widerlegt, s. Team-Report).
    // Ersetzt durch explizite Auf-/Ab-Buttons pro Zeile im Reorder-Modus – kein EditMode nötig.
    @State private var isReorderingExcursions = false

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

                hafenMomenteSection
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

    /// Fügt einen vordefinierten Ausflug-Chip hinzu (B7.1/A2). Erlaubt bewusst Duplikate
    /// (derselbe Chip mehrfach antippbar) – konsistent mit dem Freitext-Pfad, der
    /// gleichnamige Ausflüge schon immer zuließ (siehe `RemoveExcursionTests`, Index-Löschung).
    private func addExcursion(_ suggestion: String) {
        excursions.append(suggestion)
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

    // MARK: - Hafen-Momente (B7.1/A2)
    //
    // Hafenbild + Ausflüge als ein geführter Erfassungsschritt statt zwei generischer
    // Formularfelder (Design-Vorschlag A2, docs/ux-pitch-decks/b6-hafen-momente.html).
    // In eigene Sub-Views zerlegt (Compiler-Fix Gate #2): eine einzelne, große
    // ViewBuilder-Expression in `body` überforderte den Type-Checker.

    /// Die komplette "Hafen-Momente"-Section: Cover-Foto, Chip-Schnellauswahl,
    /// Ausflugsliste (mit Reorder/Delete) und Freitext-Eingabe.
    private var hafenMomenteSection: some View {
        Section(String(localized: "Hafen-Momente")) {
            coverPhotoTile
            excursionChipScroller
            excursionList
            excursionReorderToggle
            addExcursionRow
        }
    }

    /// Kreuzfahrt-typische Schnellauswahl für Ausflüge – reduziert Tipparbeit an Bord
    /// (oft schlechtes Netz/wenig Zeit), Freitext bleibt daneben weiterhin möglich.
    private var excursionSuggestions: [String] {
        [
            String(localized: "Stadtbummel"),
            String(localized: "Strand"),
            String(localized: "Wanderung"),
            String(localized: "Bootstour"),
            String(localized: "Museum"),
            String(localized: "Shopping")
        ]
    }

    @ViewBuilder
    private var coverPhotoTile: some View {
        if let imageData, let uiImage = UIImage(data: imageData) {
            VStack(alignment: .leading, spacing: 8) {
                Image(uiImage: uiImage)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(maxWidth: .infinity, minHeight: 160, maxHeight: 160)
                    .clipShape(RoundedRectangle(cornerRadius: DesignRadius.md))
                    .clipped()

                HStack {
                    PhotosPicker(selection: $selectedPhotoItem, matching: .images) {
                        Label(String(localized: "Bild ersetzen"), systemImage: "photo.on.rectangle.angled")
                    }
                    Spacer()
                    Button(role: .destructive) {
                        self.imageData = nil
                        selectedPhotoItem = nil
                    } label: {
                        Label(String(localized: "Entfernen"), systemImage: "trash")
                    }
                }
                .font(.subheadline)
            }
        } else {
            PhotosPicker(selection: $selectedPhotoItem, matching: .images) {
                VStack(spacing: 8) {
                    Image(systemName: "photo.badge.plus")
                        .font(.system(size: 32))
                    Text(String(localized: "Cover-Foto hinzufügen"))
                        .font(.subheadline)
                }
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, minHeight: 140)
                .background(Color(.secondarySystemBackground))
                .clipShape(RoundedRectangle(cornerRadius: DesignRadius.md))
            }
            .buttonStyle(.plain)
        }
    }

    private var excursionChipScroller: some View {
        ScrollView(.horizontal) {
            HStack(spacing: 8) {
                ForEach(excursionSuggestions, id: \.self) { suggestion in
                    Button {
                        addExcursion(suggestion)
                    } label: {
                        Text(suggestion)
                            .font(.subheadline)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(Color.accentColor.opacity(0.15))
                            .foregroundStyle(Color.accentColor)
                            .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                    // Gesten-Konflikt vermeiden: ohne festen contentShape kollidiert der Tap
                    // sonst mit dem vertikalen Scroll-Gesture des umgebenden Form (Gate-Hinweis
                    // aus dem Design-Deck, s6).
                    .contentShape(Rectangle())
                }
            }
        }
        .scrollIndicators(.hidden)
    }

    /// Ausflugsliste. Reorder erfolgt über `excursionMoveButtons` in `excursionRow`, nicht
    /// über natives List-EditMode (Plan B, s. `isReorderingExcursions`).
    private var excursionList: some View {
        ForEach(Array(excursions.enumerated()), id: \.offset) { index, excursion in
            excursionRow(index: index, excursion: excursion)
        }
        .onDelete { excursions.remove(atOffsets: $0) }
    }

    private func excursionRow(index: Int, excursion: String) -> some View {
        HStack {
            Text(excursion)
            Spacer()
            if isReorderingExcursions {
                excursionMoveButtons(index: index)
            } else {
                excursionDeleteButton(index: index)
            }
        }
    }

    private func excursionDeleteButton(index: Int) -> some View {
        Button {
            excursions.remove(at: index)
        } label: {
            Image(systemName: "minus.circle.fill")
                .foregroundStyle(.red)
        }
        .buttonStyle(.plain)
        // .plain entfernt die Standard-Polsterung des Buttons; ohne festen Frame +
        // contentShape bliebe die tatsächlich tappbare Fläche auf die reinen
        // Glyphen-Pixel beschränkt (unzuverlässig, ~44pt-Mindestgröße laut HIG
        // unterschritten).
        .frame(width: 44, height: 44)
        .contentShape(Rectangle())
        .accessibilityLabel(String(localized: "Ausflug entfernen"))
    }

    /// Auf-/Ab-Buttons statt nativem List-EditMode (Gate #2 Fix, Plan B): die native
    /// Reorder-Affordance über `.environment(\.editMode, …)` rendert in der echten Form/List
    /// zuverlässig KEINE Move-Griffe (zweifach per UI-Test belegt). Index-basiertes
    /// `swapAt`, oberste Zeile ohne "Nach oben", unterste ohne "Nach unten".
    private func excursionMoveButtons(index: Int) -> some View {
        HStack(spacing: 4) {
            Button {
                excursions.swapAt(index, index - 1)
            } label: {
                Image(systemName: "chevron.up")
            }
            .buttonStyle(.plain)
            .frame(width: 44, height: 44)
            .contentShape(Rectangle())
            .accessibilityLabel(String(localized: "Nach oben"))
            .accessibilityIdentifier("excursion-\(index)-moveUp")
            .disabled(index == 0)

            Button {
                excursions.swapAt(index, index + 1)
            } label: {
                Image(systemName: "chevron.down")
            }
            .buttonStyle(.plain)
            .frame(width: 44, height: 44)
            .contentShape(Rectangle())
            .accessibilityLabel(String(localized: "Nach unten"))
            .accessibilityIdentifier("excursion-\(index)-moveDown")
            .disabled(index == excursions.count - 1)
        }
    }

    /// Umschalter für den Reorder-Modus – erst ab zwei Ausflügen sinnvoll.
    @ViewBuilder
    private var excursionReorderToggle: some View {
        if excursions.count > 1 {
            Button {
                isReorderingExcursions.toggle()
            } label: {
                Label(
                    isReorderingExcursions ? String(localized: "Fertig") : String(localized: "Reihenfolge ändern"),
                    systemImage: "arrow.up.arrow.down"
                )
            }
            .buttonStyle(.plain)
            .font(.subheadline)
        }
    }

    private var addExcursionRow: some View {
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
