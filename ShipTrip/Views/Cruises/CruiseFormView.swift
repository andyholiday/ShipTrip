//
//  CruiseFormView.swift
//  ShipTrip
//
//  Created by ShipTrip on 18.12.25.
//

import SwiftUI
import SwiftData
import PhotosUI

/// Temporärer Hafen für das Formular (vor dem Speichern)
struct TempPort: Identifiable {
    let id = UUID()
    var name: String
    var country: String
    var arrival: Date
    var departure: Date
    var latitude: Double?
    var longitude: Double?
    var isSeaDay: Bool = false
}

/// Formular zum Erstellen/Bearbeiten einer Kreuzfahrt
struct CruiseFormView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    
    let cruise: Cruise?
    
    // Form State
    @State private var title = ""
    @State private var startDate = Date()
    @State private var endDate = Date().addingTimeInterval(7 * 24 * 60 * 60)
    @State private var selectedShippingLine: ShippingLine?
    @State private var ship = ""
    @State private var cabinType = ""
    @State private var bookingNumber = ""
    @State private var notes = ""
    @State private var rating: Double = 0
    
    // Ports
    @State private var tempPorts: [TempPort] = []
    @State private var showingAddPortSheet = false
    @State private var editingPortIndex: Int?
    
    // Photos
    @State private var selectedPhotos: [PhotosPickerItem] = []
    @State private var photoDataList: [Data] = []
    @State private var existingPhotos: [Photo] = []
    
    // AI Import
    @State private var showingAISheet = false
    @State private var aiImportText = ""
    @State private var isProcessingAI = false
    @State private var aiError: String?
    
    // Validation
    @State private var showingValidationAlert = false
    
    private var isEditing: Bool { cruise != nil }
    
    var body: some View {
        NavigationStack {
            Form {
                // AI Import Section (nur bei neuen Kreuzfahrten)
                if !isEditing && GeminiService.shared.isConfigured {
                    Section {
                        Button {
                            showingAISheet = true
                        } label: {
                            Label("Mit KI ausfüllen", systemImage: "wand.and.stars")
                        }
                    } footer: {
                        Text("Füge eine Buchungsbestätigung ein und lasse die Daten automatisch extrahieren.")
                    }
                }
                
                // Grunddaten
                Section("Allgemein") {
                    TextField("Titel", text: $title)
                    
                    DatePicker("Startdatum", selection: $startDate, displayedComponents: .date)
                    
                    DatePicker("Enddatum", selection: $endDate, in: startDate..., displayedComponents: .date)
                }
                
                // Schiff & Reederei
                Section("Schiff & Reederei") {
                    Picker("Reederei", selection: $selectedShippingLine) {
                        Text("Wählen...").tag(nil as ShippingLine?)
                        ForEach(ShippingLine.all) { line in
                            Text("\(line.logo) \(line.name)").tag(line as ShippingLine?)
                        }
                    }
                    
                    TextField("Schiffsname", text: $ship)
                }
                
                // Kabine & Buchung
                Section("Buchungsdetails") {
                    TextField("Kabinentyp", text: $cabinType)
                    TextField("Buchungsnummer", text: $bookingNumber)
                }
                
                // Häfen
                Section {
                    ForEach(Array(tempPorts.enumerated()), id: \.element.id) { index, port in
                        HStack {
                            // Seetag-Icon
                            if port.isSeaDay {
                                Image(systemName: "water.waves")
                                    .foregroundStyle(.blue)
                                    .frame(width: 24)
                            } else {
                                Image(systemName: "mappin.circle.fill")
                                    .foregroundStyle(.orange)
                                    .frame(width: 24)
                            }
                            
                            VStack(alignment: .leading, spacing: 2) {
                                Text(port.isSeaDay ? "🌊 Seetag" : port.name)
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                if !port.isSeaDay {
                                    Text(port.country)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                            
                            Spacer()
                            
                            VStack(alignment: .trailing, spacing: 2) {
                                Text(port.arrival.formatted(date: .abbreviated, time: .omitted))
                                    .font(.caption)
                                if !port.isSeaDay {
                                    Text("\(port.arrival.formatted(date: .omitted, time: .shortened)) - \(port.departure.formatted(date: .omitted, time: .shortened))")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                        .contentShape(Rectangle())
                        .onTapGesture {
                            editingPortIndex = index
                        }
                    }
                    .onDelete { indexSet in
                        tempPorts.remove(atOffsets: indexSet)
                    }
                    .onMove { from, to in
                        tempPorts.move(fromOffsets: from, toOffset: to)
                    }
                    
                    Button {
                        showingAddPortSheet = true
                    } label: {
                        Label("Hafen hinzufügen", systemImage: "plus.circle")
                    }
                    
                    Button {
                        addSeaDay()
                    } label: {
                        Label("Seetag hinzufügen", systemImage: "water.waves")
                    }
                } header: {
                    Text("Route (\(tempPorts.count) Einträge)")
                }
                
                // Bewertung
                Section("Bewertung") {
                    RatingInputView(rating: $rating)
                }
                
                // Fotos
                Section("Fotos") {
                    PhotosPicker(selection: $selectedPhotos, maxSelectionCount: 10, matching: .images) {
                        Label("Fotos auswählen", systemImage: "photo.on.rectangle.angled")
                    }
                    
                    let allPhotos = existingPhotos.map { $0.imageData } + photoDataList
                    if !allPhotos.isEmpty {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                ForEach(Array(existingPhotos.enumerated()), id: \.offset) { index, photo in
                                    if let uiImage = UIImage(data: photo.imageData) {
                                        photoThumbnail(uiImage: uiImage) {
                                            existingPhotos.remove(at: index)
                                        }
                                    }
                                }
                                
                                ForEach(Array(photoDataList.enumerated()), id: \.offset) { index, data in
                                    if let uiImage = UIImage(data: data) {
                                        photoThumbnail(uiImage: uiImage) {
                                            photoDataList.remove(at: index)
                                        }
                                    }
                                }
                            }
                            .padding(.vertical, 4)
                        }
                    }
                }
                
                // Notizen
                Section("Notizen") {
                    TextEditor(text: $notes)
                        .frame(minHeight: 100)
                }
            }
            .navigationTitle(isEditing ? "Bearbeiten" : "Neue Kreuzfahrt")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Abbrechen") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("Speichern") {
                        saveCruise()
                    }
                    .disabled(title.isEmpty || ship.isEmpty)
                }
            }
            .onAppear {
                loadExistingData()
            }
            .onChange(of: selectedPhotos) { _, newItems in
                loadPhotos(from: newItems)
            }
            .alert("Fehler", isPresented: $showingValidationAlert) {
                Button("OK", role: .cancel) { }
            } message: {
                Text("Bitte fülle alle Pflichtfelder aus (Titel, Schiff).")
            }
            .sheet(isPresented: $showingAISheet) {
                AIImportSheet(
                    text: $aiImportText,
                    isProcessing: $isProcessingAI,
                    error: $aiError,
                    onImport: processAIImport
                )
            }
            .sheet(isPresented: $showingAddPortSheet) {
                TempPortFormSheet(ports: $tempPorts, editingIndex: nil)
            }
            .sheet(item: $editingPortIndex) { index in
                TempPortFormSheet(ports: $tempPorts, editingIndex: index)
            }
        }
    }
    
    // MARK: - Photo Thumbnail
    
    @ViewBuilder
    private func photoThumbnail(uiImage: UIImage, onDelete: @escaping () -> Void) -> some View {
        Image(uiImage: uiImage)
            .resizable()
            .aspectRatio(contentMode: .fill)
            .frame(width: 80, height: 80)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .overlay(alignment: .topTrailing) {
                Button {
                    onDelete()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.white, .red)
                }
                .offset(x: 4, y: -4)
            }
    }
    
    // MARK: - Data Loading
    
    private func loadExistingData() {
        guard let cruise = cruise else { return }
        
        title = cruise.title
        startDate = cruise.startDate
        endDate = cruise.endDate
        selectedShippingLine = ShippingLine.all.first { $0.name == cruise.shippingLine }
        ship = cruise.ship
        cabinType = cruise.cabinType
        bookingNumber = cruise.bookingNumber
        notes = cruise.notes
        rating = cruise.rating
        existingPhotos = cruise.sortedPhotos
        
        // Load existing ports
        tempPorts = cruise.route.sorted(by: { $0.sortOrder < $1.sortOrder }).map { port in
            TempPort(
                name: port.name,
                country: port.country,
                arrival: port.arrival,
                departure: port.departure,
                latitude: port.latitude,
                longitude: port.longitude,
                isSeaDay: port.isSeaDay
            )
        }
    }
    
    private func loadPhotos(from items: [PhotosPickerItem]) {
        Task {
            for item in items {
                if let data = try? await item.loadTransferable(type: Data.self) {
                    await MainActor.run {
                        photoDataList.append(data)
                    }
                }
            }
            await MainActor.run {
                selectedPhotos = []
            }
        }
    }
    
    private func addSeaDay() {
        // Finde das nächste Datum nach dem letzten Eintrag
        let lastDate = tempPorts.last?.arrival ?? startDate
        let nextDate = Calendar.current.date(byAdding: .day, value: 1, to: lastDate) ?? lastDate
        
        let seaDay = TempPort(
            name: "Seetag",
            country: "",
            arrival: nextDate,
            departure: nextDate,
            isSeaDay: true
        )
        tempPorts.append(seaDay)
    }
    
    // MARK: - AI Import
    
    private func processAIImport() {
        guard !aiImportText.isEmpty else { return }
        
        isProcessingAI = true
        aiError = nil
        
        Task {
            do {
                let extracted = try await GeminiService.shared.extractCruiseData(from: aiImportText)
                
                await MainActor.run {
                    var filledCount = 0
                    print("DEBUG: Processing extracted data...")
                    
                    if let extractedTitle = extracted.title {
                        title = extractedTitle
                        filledCount += 1
                    }
                    
                    if let extractedShippingLine = extracted.shippingLine {
                        selectedShippingLine = ShippingLine.all.first {
                            $0.name.localizedCaseInsensitiveContains(extractedShippingLine) ||
                            extractedShippingLine.localizedCaseInsensitiveContains($0.name)
                        }
                        if selectedShippingLine != nil {
                            filledCount += 1
                        }
                    }
                    
                    if let extractedShip = extracted.ship {
                        ship = extractedShip
                        filledCount += 1
                        
                        // Bug #6 Fix: If no shipping line was detected, try to find it by ship name
                        if selectedShippingLine == nil {
                            if let detectedLine = ShippingLine.findByShipName(extractedShip) {
                                selectedShippingLine = detectedLine
                                filledCount += 1
                            }
                        }
                    }
                    
                    if let extractedCabinType = extracted.cabinType {
                        cabinType = extractedCabinType
                        filledCount += 1
                    }
                    
                    if let extractedBookingNumber = extracted.bookingNumber {
                        bookingNumber = extractedBookingNumber
                        filledCount += 1
                    }
                    
                    // Parse dates
                    let dateFormatter = DateFormatter()
                    dateFormatter.dateFormat = "yyyy-MM-dd"
                    
                    if let startDateStr = extracted.startDate,
                       let parsedStart = dateFormatter.date(from: startDateStr) {
                        startDate = parsedStart
                        filledCount += 1
                    }
                    
                    if let endDateStr = extracted.endDate,
                       let parsedEnd = dateFormatter.date(from: endDateStr) {
                        endDate = parsedEnd
                        filledCount += 1
                    }
                    
                    // Parse ports
                    if let extractedPorts = extracted.ports, !extractedPorts.isEmpty {
                        let timeFormatter = DateFormatter()
                        timeFormatter.dateFormat = "HH:mm"
                        
                        for extractedPort in extractedPorts {
                            var arrivalDate = startDate
                            var departureDate = startDate
                            
                            // Parse arrival date/time
                            if let arrDateStr = extractedPort.arrivalDate,
                               let arrDate = dateFormatter.date(from: arrDateStr) {
                                arrivalDate = arrDate
                            }
                            if let arrTimeStr = extractedPort.arrivalTime,
                               let arrTime = timeFormatter.date(from: arrTimeStr) {
                                let calendar = Calendar.current
                                let timeComponents = calendar.dateComponents([.hour, .minute], from: arrTime)
                                arrivalDate = calendar.date(bySettingHour: timeComponents.hour ?? 8, minute: timeComponents.minute ?? 0, second: 0, of: arrivalDate) ?? arrivalDate
                            }
                            
                            // Parse departure date/time
                            if let depDateStr = extractedPort.departureDate,
                               let depDate = dateFormatter.date(from: depDateStr) {
                                departureDate = depDate
                            } else {
                                departureDate = arrivalDate
                            }
                            if let depTimeStr = extractedPort.departureTime,
                               let depTime = timeFormatter.date(from: depTimeStr) {
                                let calendar = Calendar.current
                                let timeComponents = calendar.dateComponents([.hour, .minute], from: depTime)
                                departureDate = calendar.date(bySettingHour: timeComponents.hour ?? 18, minute: timeComponents.minute ?? 0, second: 0, of: departureDate) ?? departureDate
                            }
                            
                            // Find coordinates from suggestions (skip for sea days)
                            var lat: Double? = nil
                            var lon: Double? = nil
                            let isSeaDay = extractedPort.isSeaDay ?? false
                            
                            if !isSeaDay {
                                // Verwende verbesserte Suche mit Land-Prüfung
                                if let suggestion = PortSuggestion.findBestMatch(
                                    name: extractedPort.name,
                                    country: extractedPort.country
                                ) {
                                    lat = suggestion.latitude
                                    lon = suggestion.longitude
                                }
                            }
                            
                            let tempPort = TempPort(
                                name: isSeaDay ? "Seetag" : extractedPort.name,
                                country: extractedPort.country ?? "",
                                arrival: arrivalDate,
                                departure: departureDate,
                                latitude: lat,
                                longitude: lon,
                                isSeaDay: isSeaDay
                            )
                            tempPorts.append(tempPort)
                        }
                        filledCount += extractedPorts.count
                    }
                    
                    // Show success message
                    if filledCount > 0 {
                        aiError = "✓ \(filledCount) Felder/Häfen ausgefüllt!"
                    } else {
                        aiError = "Keine Daten gefunden."
                    }
                    
                    isProcessingAI = false
                    
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                        showingAISheet = false
                    }
                }
            } catch {
                await MainActor.run {
                    aiError = error.localizedDescription
                    isProcessingAI = false
                }
            }
        }
    }
    
    // MARK: - Save
    
    private func saveCruise() {
        guard !title.isEmpty, !ship.isEmpty else {
            showingValidationAlert = true
            return
        }
        
        let targetCruise: Cruise
        
        if let existingCruise = cruise {
            existingCruise.title = title
            existingCruise.startDate = startDate
            existingCruise.endDate = endDate
            existingCruise.shippingLine = selectedShippingLine?.name ?? ""
            existingCruise.ship = ship
            existingCruise.cabinType = cabinType
            existingCruise.bookingNumber = bookingNumber
            existingCruise.notes = notes
            existingCruise.rating = rating
            existingCruise.updatedAt = Date()
            targetCruise = existingCruise
            
            // Remove all existing ports and re-add
            for port in existingCruise.route {
                modelContext.delete(port)
            }
            
            // Remove deleted photos
            let existingPhotoSet = Set(existingPhotos.map { ObjectIdentifier($0) })
            for photo in existingCruise.photos {
                if !existingPhotoSet.contains(ObjectIdentifier(photo)) {
                    modelContext.delete(photo)
                }
            }
        } else {
            let newCruise = Cruise(
                title: title,
                startDate: startDate,
                endDate: endDate,
                shippingLine: selectedShippingLine?.name ?? "",
                ship: ship
            )
            newCruise.cabinType = cabinType
            newCruise.bookingNumber = bookingNumber
            newCruise.notes = notes
            newCruise.rating = rating
            modelContext.insert(newCruise)
            targetCruise = newCruise
        }
        
        // Add ports
        for (index, tempPort) in tempPorts.enumerated() {
            let port = Port(
                name: tempPort.isSeaDay ? "Seetag" : tempPort.name,
                country: tempPort.country,
                latitude: tempPort.latitude ?? 0,
                longitude: tempPort.longitude ?? 0
            )
            port.arrival = tempPort.arrival
            port.departure = tempPort.departure
            port.sortOrder = index
            port.isSeaDay = tempPort.isSeaDay
            port.cruise = targetCruise
            modelContext.insert(port)
        }
        
        // Add new photos
        let startOrder = existingPhotos.count
        for (index, data) in photoDataList.enumerated() {
            let photo = Photo(imageData: data, sortOrder: startOrder + index)
            photo.cruise = targetCruise
            modelContext.insert(photo)
        }
        
        dismiss()
    }
}

// MARK: - Temp Port Form Sheet

struct TempPortFormSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var ports: [TempPort]
    let editingIndex: Int?
    
    @State private var name = ""
    @State private var country = ""
    @State private var arrivalDate = Date()
    @State private var departureDate = Date()
    @State private var searchText = ""
    
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
                    DatePicker("Abfahrt", selection: $departureDate)
                }
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
                    name = port.name
                    country = port.country
                    searchText = port.name
                    arrivalDate = port.arrival
                    departureDate = port.departure
                }
            }
        }
    }
    
    private func savePort() {
        // Verwende verbesserte Suche mit Land-Prüfung
        var lat: Double? = nil
        var lon: Double? = nil
        if let suggestion = PortSuggestion.findBestMatch(name: name, country: country) {
            lat = suggestion.latitude
            lon = suggestion.longitude
        }
        
        let port = TempPort(
            name: name,
            country: country,
            arrival: arrivalDate,
            departure: departureDate,
            latitude: lat,
            longitude: lon
        )
        
        if let index = editingIndex, index < ports.count {
            ports[index] = port
        } else {
            ports.append(port)
        }
        
        dismiss()
    }
}

// Make Int conform to Identifiable for sheet(item:)
extension Int: @retroactive Identifiable {
    public var id: Int { self }
}

// MARK: - AI Import Sheet

struct AIImportSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var text: String
    @Binding var isProcessing: Bool
    @Binding var error: String?
    var onImport: () -> Void
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                Text("Füge den Text deiner Buchungsbestätigung ein:")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                
                TextEditor(text: $text)
                    .frame(minHeight: 200)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.secondary.opacity(0.3), lineWidth: 1)
                    )
                
                if isProcessing {
                    HStack {
                        ProgressView()
                        Text("Analysiere mit Gemini AI...")
                            .foregroundStyle(.secondary)
                    }
                    .padding()
                }
                
                if let error = error {
                    Text(error)
                        .foregroundStyle(error.contains("✓") ? .green : .red)
                        .font(.callout)
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(error.contains("✓") ? Color.green.opacity(0.1) : Color.red.opacity(0.1))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                }
                
                Spacer()
            }
            .padding()
            .navigationTitle("KI-Import")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Abbrechen") { dismiss() }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("Analysieren") {
                        onImport()
                    }
                    .disabled(text.isEmpty || isProcessing)
                }
            }
        }
    }
}

// MARK: - Rating Input

struct RatingInputView: View {
    @Binding var rating: Double
    
    var body: some View {
        HStack {
            ForEach(1...5, id: \.self) { star in
                Button {
                    withAnimation(.spring(response: 0.3)) {
                        rating = Double(star)
                    }
                } label: {
                    Image(systemName: star <= Int(rating) ? "star.fill" : "star")
                        .font(.title2)
                        .foregroundStyle(star <= Int(rating) ? .yellow : .gray.opacity(0.3))
                }
                .buttonStyle(.plain)
            }
            
            if rating > 0 {
                Text(String(format: "%.0f/5", rating))
                    .foregroundStyle(.secondary)
                    .padding(.leading, 8)
            }
        }
    }
}

#Preview {
    CruiseFormView(cruise: nil)
        .modelContainer(for: [Cruise.self, Photo.self, Port.self], inMemory: true)
}
