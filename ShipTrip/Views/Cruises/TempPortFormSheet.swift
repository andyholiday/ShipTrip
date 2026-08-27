//
//  TempPortFormSheet.swift
//  ShipTrip
//
//  Welle D2: aus `CruiseFormView` herausgelöst, Verhalten unverändert. Die
//  "Hafen-Momente"-Section kommt jetzt aus `HafenMomenteSection` statt aus einer
//  eigenen, mit `PortFormView` wortgleichen Kopie.
//

import SwiftUI

// MARK: - Temp Port Form Sheet

/// Erzwingt Abfahrt ≥ Ankunft als Sicherheitsnetz zum `DatePicker(in: arrivalDate...)`-
/// Constraint: ändert sich `arrivalDate`, nachdem `departureDate` schon gesetzt wurde, bleibt
/// der gespeicherte Hafen dennoch konsistent (M5 Teil 2, Muster: PortFormView Zeile 140).
func clampedDeparture(arrival: Date, departure: Date) -> Date {
    max(arrival, departure)
}

struct TempPortFormSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var ports: [TempPort]
    let editingIndex: Int?
    /// Startdatum der Kreuzfahrt – Fallback für das Auto-Datum, wenn noch kein Hafen existiert.
    let cruiseStartDate: Date

    @State private var name = ""
    @State private var country = ""
    @State private var arrivalDate = Date()
    @State private var departureDate = Date()
    @State private var searchText = ""

    // Hafenbild
    @State private var imageData: Data?

    // Ausflüge
    @State private var excursions: [String] = []

    /// Der bearbeitete Hafen im Original-Zustand, um beim Speichern `id` und `isSeaDay`
    /// zu erhalten (siehe reconcileRoute-Kontext).
    @State private var originalPort: TempPort?

    private var isEditing: Bool { editingIndex != nil }

    private var filteredSuggestions: [PortSuggestion] {
        guard !searchText.isEmpty else { return [] }
        return PortSuggestion.popular.filter { $0.name.localizedCaseInsensitiveContains(searchText) }.prefix(5).map { $0 }
    }

    var body: some View {
        NavigationStack {
            Form {
                // Search / Suggestions
                Section("Hafen suchen") {
                    TextField("Hafenname eingeben...", text: $searchText)
                        .onChange(of: searchText) { _, newValue in
                            if name.isEmpty || name != newValue {
                                name = newValue
                            }
                        }

                    ForEach(filteredSuggestions) { suggestion in
                        Button {
                            name = suggestion.name
                            country = suggestion.country
                            searchText = suggestion.name
                        } label: {
                            VStack(alignment: .leading) {
                                Text(suggestion.name)
                                    .foregroundStyle(.primary)
                                Text(suggestion.country)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }

                // Manual entry
                Section("Details") {
                    TextField("Hafenname", text: $name)
                    TextField("Land", text: $country)
                }

                // Times
                Section("Zeiten") {
                    DatePicker("Ankunft", selection: $arrivalDate)
                    DatePicker("Abfahrt", selection: $departureDate, in: arrivalDate...)
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
                    Button("Speichern") {
                        savePort()
                    }
                    .disabled(name.isEmpty)
                }
            }
            .onAppear {
                if let index = editingIndex, index < ports.count {
                    let port = ports[index]
                    originalPort = port
                    name = port.name
                    country = port.country
                    searchText = port.name
                    arrivalDate = port.arrival
                    departureDate = port.departure
                    imageData = port.imageData
                    excursions = port.excursions
                } else {
                    // Neuer Hafen: Ankunft auf den Folgetag des letzten Eintrags vorbelegen (A5.3).
                    let defaultDate = defaultArrivalDate(afterLastOf: ports, fallback: cruiseStartDate)
                    arrivalDate = defaultDate
                    departureDate = defaultDate
                }
            }
        }
    }

    /// Vergleicht ein Formularfeld mit seinem Ausgangswert – ohne umgebende Leerzeichen
    /// und ohne Groß-/Kleinschreibung. Reine Tipp-Kosmetik („Kiel " statt „kiel") darf
    /// die Katalogsuche nicht anstoßen, weil ein unscharfer Treffer sonst manuell
    /// gesetzte Koordinaten überschreibt. Ohne `original` – also beim Neuanlegen –
    /// gilt das Feld als geändert, damit der Katalog wie bisher greift.
    static func fieldChanged(original: String?, current: String) -> Bool {
        guard let original else { return true }
        let trimmedOriginal = original.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedCurrent = current.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmedOriginal.caseInsensitiveCompare(trimmedCurrent) != .orderedSame
    }

    /// Ermittelt die Koordinaten des zu speichernden Hafens (Audit-Finding 1.2/H-A).
    /// Der Katalog überschreibt nur, wenn Name oder Land geändert wurden und es dafür
    /// tatsächlich einen Treffer gibt. Sonst bleiben die vorhandenen – ggf. selbst
    /// gesetzten – Koordinaten erhalten, statt wortlos zu verschwinden.
    static func resolvedCoordinates(
        existing: (latitude: Double?, longitude: Double?),
        nameChanged: Bool,
        countryChanged: Bool,
        catalogMatch: PortSuggestion?
    ) -> (latitude: Double?, longitude: Double?) {
        guard nameChanged || countryChanged, let catalogMatch else { return existing }
        return (catalogMatch.latitude, catalogMatch.longitude)
    }

    private func savePort() {
        // Katalog-Abgleich (verbesserte Suche mit Land-Prüfung) nur, wenn sich Name oder
        // Land gegenüber dem bearbeiteten Hafen geändert haben – sonst bleiben dessen
        // Koordinaten unangetastet (1.2/H-A).
        let nameChanged = Self.fieldChanged(original: originalPort?.name, current: name)
        let countryChanged = Self.fieldChanged(original: originalPort?.country, current: country)
        let catalogMatch = (nameChanged || countryChanged)
            ? PortSuggestion.findBestMatch(name: name, country: country)
            : nil
        let coordinates = Self.resolvedCoordinates(
            existing: (latitude: originalPort?.latitude, longitude: originalPort?.longitude),
            nameChanged: nameChanged,
            countryChanged: countryChanged,
            catalogMatch: catalogMatch
        )

        // Abfahrt ≥ Ankunft erzwingen (M5 Teil 2) – Sicherheitsnetz zum DatePicker-Constraint
        // oben, falls arrivalDate sich änderte, nachdem departureDate schon gesetzt war.
        let safeDepartureDate = clampedDeparture(arrival: arrivalDate, departure: departureDate)

        // Beim Bearbeiten vom Original ausgehen, damit id und isSeaDay erhalten bleiben;
        // die im Sheet editierbaren Felder (inkl. Bild/Ausflüge) werden überschrieben.
        var port = originalPort ?? TempPort(
            name: name,
            country: country,
            arrival: arrivalDate,
            departure: safeDepartureDate,
            latitude: coordinates.latitude,
            longitude: coordinates.longitude
        )
        port.name = name
        port.country = country
        port.arrival = arrivalDate
        port.departure = safeDepartureDate
        port.latitude = coordinates.latitude
        port.longitude = coordinates.longitude
        port.imageData = imageData
        port.excursions = excursions

        if let index = editingIndex, index < ports.count {
            ports[index] = port
        } else {
            ports.append(port)
        }

        dismiss()
    }
}
