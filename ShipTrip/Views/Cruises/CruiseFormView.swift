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
    /// Stabile ID: bei neu angelegten Häfen frisch vergeben, bei bestehenden Häfen von
    /// `Port.id` übernommen, damit `reconcileRoute` sie beim Speichern wiedererkennt.
    var id = UUID()
    var name: String
    var country: String
    var arrival: Date
    var departure: Date
    var latitude: Double?
    var longitude: Double?
    var isSeaDay: Bool = false
    var excursionsRaw: String = ""
    var imageData: Data? = nil

    /// Ausflüge als Array – Format identisch zu `Port.excursions` (kommasepariert), damit
    /// `reconcileRoute` `excursionsRaw` unverändert durchreichen kann.
    var excursions: [String] {
        get { excursionsRaw.isEmpty ? [] : excursionsRaw.components(separatedBy: ", ") }
        set { excursionsRaw = newValue.joined(separator: ", ") }
    }
}

/// Ermittelt das Standard-Ankunftsdatum für einen neuen Hafen im Routen-Formular: der Tag
/// nach dem letzten Eintrag der aktuellen (bereits in Anzeigereihenfolge vorliegenden)
/// Routenliste, sonst das Startdatum der Kreuzfahrt. Analog zu `addSeaDay()`.
func defaultArrivalDate(afterLastOf ports: [TempPort], fallback: Date, calendar: Calendar = .current) -> Date {
    guard let lastArrival = ports.last?.arrival else {
        return fallback
    }
    return calendar.date(byAdding: .day, value: 1, to: lastArrival) ?? lastArrival
}

/// Gleicht die bearbeitete Route (`tempPorts`) mit den bestehenden `Port`-Objekten einer
/// Kreuzfahrt ab, statt sie beim Speichern zu löschen und neu anzulegen. Bestehende Ports
/// werden anhand ihrer `id` in-place aktualisiert (Referenz, `excursionsRaw`, `imageData`
/// und `updatedAt` bleiben dabei erhalten bzw. werden nur bei tatsächlicher Änderung
/// aktualisiert), nur wirklich entfernte IDs werden gelöscht, neue Einträge werden angelegt.
/// So bleiben importierte Ausflüge/Hafenbilder erhalten und die ID-Stabilität für
/// CloudKit-Last-Writer-Wins (ADR-002) bleibt gewahrt.
@discardableResult
func reconcileRoute(
    existingPorts: [Port],
    tempPorts: [TempPort],
    cruise: Cruise,
    modelContext: ModelContext
) -> [Port] {
    // Toleranter Aufbau: im Altbestand kamen real doppelte Port-UUIDs vor (siehe
    // IdBackfill). Der erste Treffer je ID gewinnt deterministisch, alle weiteren
    // Duplikate unter derselben ID werden unten wie nicht mehr referenzierte Ports
    // behandelt und gelöscht (Dedup als Nebeneffekt, kein Crash durch uniqueKeysWithValues).
    var existingByID: [UUID: Port] = [:]
    for port in existingPorts where existingByID[port.id] == nil {
        existingByID[port.id] = port
    }
    for port in existingPorts {
        if let kept = existingByID[port.id], kept !== port {
            modelContext.delete(port)
        }
    }

    // Doppelte IDs in tempPorts (z. B. inkonsistenter Zwischenzustand) deterministisch
    // deduplizieren, damit nie zwei neue Ports mit derselben stabilen ID entstehen.
    var seenTempIDs = Set<UUID>()
    var dedupedTempPorts: [TempPort] = []
    dedupedTempPorts.reserveCapacity(tempPorts.count)
    for tempPort in tempPorts where seenTempIDs.insert(tempPort.id).inserted {
        dedupedTempPorts.append(tempPort)
    }

    let tempIDs = Set(dedupedTempPorts.map { $0.id })

    for port in existingByID.values where !tempIDs.contains(port.id) {
        modelContext.delete(port)
    }

    var result: [Port] = []
    result.reserveCapacity(dedupedTempPorts.count)

    for (index, tempPort) in dedupedTempPorts.enumerated() {
        let name = tempPort.isSeaDay ? "Seetag" : tempPort.name
        let latitude = tempPort.latitude ?? 0
        let longitude = tempPort.longitude ?? 0

        if let existing = existingByID[tempPort.id] {
            var changed = false
            if existing.name != name { existing.name = name; changed = true }
            if existing.country != tempPort.country { existing.country = tempPort.country; changed = true }
            if existing.latitude != latitude { existing.latitude = latitude; changed = true }
            if existing.longitude != longitude { existing.longitude = longitude; changed = true }
            if existing.arrival != tempPort.arrival { existing.arrival = tempPort.arrival; changed = true }
            if existing.departure != tempPort.departure { existing.departure = tempPort.departure; changed = true }
            if existing.isSeaDay != tempPort.isSeaDay { existing.isSeaDay = tempPort.isSeaDay; changed = true }
            if existing.excursionsRaw != tempPort.excursionsRaw { existing.excursionsRaw = tempPort.excursionsRaw; changed = true }
            if existing.imageData != tempPort.imageData { existing.imageData = tempPort.imageData; changed = true }
            if existing.sortOrder != index { existing.sortOrder = index; changed = true }
            if changed { existing.updatedAt = Date() }
            result.append(existing)
        } else {
            let port = Port(name: name, country: tempPort.country, latitude: latitude, longitude: longitude)
            port.id = tempPort.id
            port.arrival = tempPort.arrival
            port.departure = tempPort.departure
            port.sortOrder = index
            port.isSeaDay = tempPort.isSeaDay
            port.excursionsRaw = tempPort.excursionsRaw
            port.imageData = tempPort.imageData
            port.cruise = cruise
            modelContext.insert(port)
            result.append(port)
        }
    }

    return result
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
    @State private var cabinNumber = ""
    @State private var bookingNumber = ""
    @State private var notes = ""
    @State private var rating: Double = 0
    
    // Ports
    @State private var tempPorts: [TempPort] = []
    @State private var showingAddPortSheet = false
    @State private var editingPortIndex: PortEditIndex?
    
    // Photos
    @State private var selectedPhotos: [PhotosPickerItem] = []
    @State private var photoDataList: [Data] = []
    @State private var existingPhotos: [Photo] = []
    
    // AI Import
    @State private var showingAISheet = false
    @State private var aiImportText = ""
    @State private var isProcessingAI = false
    @State private var aiFeedback: FeedbackStatus?
    
    // Validation
    @State private var showingValidationAlert = false
    @State private var validationMessage = ""

    // Verhindert Doppel-Save waehrend des Notification-Permission-Tails nach dem Save
    @State private var isSaving = false

    // Notification Permission (A2.1): kontextuelles Sheet vor dem nativen Prompt
    // bzw. dezenter Hinweis, wenn der Nutzer bereits abgelehnt hat.
    @State private var showingReminderPermissionSheet = false
    @State private var showingDeniedHint = false
    @State private var pendingReminderCruiseID: String?
    @State private var pendingReminderTitle: String?
    @State private var pendingReminderStartDate: Date?

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
                    .onChange(of: selectedShippingLine) { _, newValue in
                        // Schiff zurücksetzen wenn Reederei gewechselt wird
                        if let line = newValue, !line.ships.contains(ship) {
                            ship = ""
                        }
                    }
                    
                    // Schiff Picker wenn Reederei gewählt, sonst TextField.
                    // Beim Bearbeiten: historisches Schiff (nicht in ships) als Extra-Option ergänzen.
                    if let shippingLine = selectedShippingLine, !shippingLine.ships.isEmpty {
                        let pickerOptions: [String] = shippingLine.ships.contains(ship) || ship.isEmpty
                            ? shippingLine.ships
                            : shippingLine.ships + [ship]
                        Picker("Schiff", selection: $ship) {
                            Text("Wählen...").tag("")
                            ForEach(pickerOptions, id: \.self) { shipName in
                                Text(shipName).tag(shipName)
                            }
                        }
                    } else {
                        TextField("Schiffsname", text: $ship)
                    }
                }
                
                // Kabine & Buchung
                Section("Buchungsdetails") {
                    TextField("Kabinentyp", text: $cabinType)
                    TextField("Kabinennummer", text: $cabinNumber)
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
                                Text(port.isSeaDay ? String(localized: "🌊 Seetag") : port.name)
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
                            editingPortIndex = PortEditIndex(id: index)
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
                    Text("Route (\(tempPorts.count) \(String(localized: "Einträge")))")
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
                                    if let uiImage = UIImage(data: photo.thumbnailData ?? photo.imageData) {
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
                    .disabled(isSaving)
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Speichern") {
                        saveCruise()
                    }
                    .disabled(title.isEmpty || ship.isEmpty || isSaving)
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
                Text(validationMessage)
            }
            .sheet(isPresented: $showingAISheet) {
                AIImportSheet(
                    text: $aiImportText,
                    isProcessing: $isProcessingAI,
                    feedback: $aiFeedback,
                    onImport: processAIImport
                )
            }
            .sheet(isPresented: $showingAddPortSheet) {
                TempPortFormSheet(ports: $tempPorts, editingIndex: nil, cruiseStartDate: startDate)
            }
            .sheet(item: $editingPortIndex) { editIndex in
                TempPortFormSheet(ports: $tempPorts, editingIndex: editIndex.id, cruiseStartDate: startDate)
            }
            .sheet(isPresented: $showingReminderPermissionSheet) {
                ReminderPermissionSheet(
                    onEnable: handleReminderPermissionEnable,
                    onLater: handleReminderPermissionLater
                )
                .interactiveDismissDisabled()
            }
            .alert("Erinnerungen deaktiviert", isPresented: $showingDeniedHint) {
                Button("Einstellungen öffnen") {
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        UIApplication.shared.open(url)
                    }
                    finishAfterDeniedHint()
                }
                Button("Weiter", role: .cancel) {
                    finishAfterDeniedHint()
                }
            } message: {
                Text("Benachrichtigungen sind für ShipTrip deaktiviert. Aktiviere sie in den Systemeinstellungen, um Reise-Erinnerungen zu erhalten.")
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
            .clipShape(RoundedRectangle(cornerRadius: DesignRadius.sm))
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
        cabinNumber = cruise.cabinNumber
        bookingNumber = cruise.bookingNumber
        notes = cruise.notes
        rating = cruise.rating
        existingPhotos = cruise.sortedPhotos
        
        // Load existing ports
        tempPorts = cruise.route.sorted(by: { $0.sortOrder < $1.sortOrder }).map { port in
            TempPort(
                id: port.id,
                name: port.name,
                country: port.country,
                arrival: port.arrival,
                departure: port.departure,
                latitude: port.latitude,
                longitude: port.longitude,
                isSeaDay: port.isSeaDay,
                excursionsRaw: port.excursionsRaw,
                imageData: port.imageData
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
        aiFeedback = nil
        
        Task {
            do {
                let extracted = try await GeminiService.shared.extractCruiseData(from: aiImportText)
                
                await MainActor.run {
                    var filledCount = 0
                    
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
                    
                    if let extractedCabinNumber = extracted.cabinNumber {
                        cabinNumber = extractedCabinNumber
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
                        let message = "✓ \(filledCount) " + String(localized: "Felder/Häfen ausgefüllt!")
                        aiFeedback = .success(message)
                        AccessibilityNotification.Announcement(message).post()
                    } else {
                        let message = String(localized: "Keine Daten gefunden.")
                        aiFeedback = .failure(message)
                        AccessibilityNotification.Announcement(message).post()
                    }

                    isProcessingAI = false

                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                        showingAISheet = false
                    }
                }
            } catch {
                await MainActor.run {
                    let message = error.localizedDescription
                    aiFeedback = .failure(message)
                    AccessibilityNotification.Announcement(message).post()
                    isProcessingAI = false
                }
            }
        }
    }
    
    // MARK: - Save
    
    private func saveCruise() {
        guard !title.isEmpty, !ship.isEmpty else {
            validationMessage = String(localized: "Bitte fülle alle Pflichtfelder aus (Titel, Schiff).")
            showingValidationAlert = true
            return
        }

        guard endDate >= startDate else {
            validationMessage = String(localized: "Das Enddatum darf nicht vor dem Startdatum liegen.")
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
            existingCruise.cabinNumber = cabinNumber
            existingCruise.bookingNumber = bookingNumber
            existingCruise.notes = notes
            existingCruise.rating = rating
            existingCruise.updatedAt = Date()
            targetCruise = existingCruise

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
            newCruise.cabinNumber = cabinNumber
            newCruise.bookingNumber = bookingNumber
            newCruise.notes = notes
            newCruise.rating = rating
            newCruise.updatedAt = Date()
            modelContext.insert(newCruise)
            targetCruise = newCruise
        }

        // Route abgleichen: bestehende Ports per ID in-place aktualisieren, entfernte
        // löschen, neue anlegen (statt delete-and-recreate → siehe reconcileRoute).
        reconcileRoute(
            existingPorts: cruise?.route ?? [],
            tempPorts: tempPorts,
            cruise: targetCruise,
            modelContext: modelContext
        )

        // Neue Fotos anlegen; Thumbnail synchron erzeugen (Downsampling eines Bildes
        // ist schnell und vermeidet das Lost-Write-Risiko eines Fire-and-forget-Tasks)
        let startOrder = existingPhotos.count
        for (index, data) in photoDataList.enumerated() {
            let photo = Photo(imageData: data, sortOrder: startOrder + index)
            photo.thumbnailData = ImageDownsampler.thumbnail(from: data)
            photo.cruise = targetCruise
            modelContext.insert(photo)
        }

        // Cruise dauerhaft speichern, damit persistentModelID final ist
        isSaving = true
        do {
            try modelContext.save()
        } catch {
            // Gestagte Route-/Cruise-/Foto-Änderungen zurücknehmen, damit ein späterer
            // Save sie nicht doch noch persistiert.
            modelContext.rollback()
            isSaving = false
            validationMessage = String(localized: "Speichern fehlgeschlagen: ") + error.localizedDescription
            showingValidationAlert = true
            return
        }

        // Wertdaten synchron auf dem MainActor lesen – kein @Model über Aktorgrenzen
        let cruiseID = String(describing: targetCruise.persistentModelID)
        let cruiseTitle = targetCruise.title
        let cruiseStart = targetCruise.startDate
        let wasEditing = cruise != nil

        Task {
            if wasEditing {
                await NotificationService.shared.removeReminders(cruiseID: cruiseID)
            }

            // Ohne gewünschte Erinnerung oder bei bereits vergangenem Startdatum gibt es
            // nichts zu planen und nichts zu erfragen – Formular wie bisher schließen.
            guard NotificationService.shared.remindersEnabledInSettings, cruiseStart > Date() else {
                await MainActor.run { dismiss() }
                return
            }

            let status = await NotificationService.shared.authorizationStatus()

            switch status {
            case .authorized, .provisional, .ephemeral:
                await NotificationService.shared.scheduleAllReminders(
                    cruiseID: cruiseID,
                    title: cruiseTitle,
                    startDate: cruiseStart
                )
                await MainActor.run { dismiss() }

            case .notDetermined:
                // Erst Kontext-Sheet zeigen, dann ggf. den nativen Prompt – das Formular
                // bleibt dafür bewusst offen (robuster als ein Sheet auf dem
                // präsentierenden Kontext nach dem Dismiss zu koordinieren).
                await MainActor.run {
                    pendingReminderCruiseID = cruiseID
                    pendingReminderTitle = cruiseTitle
                    pendingReminderStartDate = cruiseStart
                    showingReminderPermissionSheet = true
                }

            case .denied:
                await MainActor.run {
                    if UserDefaults.standard.bool(forKey: "hasShownNotificationDeniedHint") {
                        dismiss()
                    } else {
                        showingDeniedHint = true
                    }
                }

            @unknown default:
                await MainActor.run { dismiss() }
            }
        }
    }

    // MARK: - Notification Permission Flow (A2.1)

    private func handleReminderPermissionEnable() {
        let cruiseID = pendingReminderCruiseID
        let cruiseTitle = pendingReminderTitle
        let cruiseStart = pendingReminderStartDate
        resetPendingReminderState()

        guard let cruiseID, let cruiseTitle, let cruiseStart else {
            dismiss()
            return
        }

        Task {
            let granted = await NotificationService.shared.requestAuthorization()
            if granted {
                await NotificationService.shared.scheduleAllReminders(
                    cruiseID: cruiseID,
                    title: cruiseTitle,
                    startDate: cruiseStart
                )
            }
            await MainActor.run { dismiss() }
        }
    }

    private func handleReminderPermissionLater() {
        resetPendingReminderState()
        dismiss()
    }

    private func resetPendingReminderState() {
        showingReminderPermissionSheet = false
        pendingReminderCruiseID = nil
        pendingReminderTitle = nil
        pendingReminderStartDate = nil
    }

    private func finishAfterDeniedHint() {
        UserDefaults.standard.set(true, forKey: "hasShownNotificationDeniedHint")
        showingDeniedHint = false
        dismiss()
    }
}

// MARK: - Reminder Permission Sheet

/// Kontext-Sheet vor der System-Berechtigungsabfrage für Benachrichtigungen (A2.1): erklärt
/// kurz den Nutzen, bevor der native Prompt erscheint, statt ihn kommentarlos zu zeigen.
private struct ReminderPermissionSheet: View {
    let onEnable: () -> Void
    let onLater: () -> Void

    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "bell.badge")
                .font(.system(size: 44))
                .foregroundStyle(Color.oceanBlue)
                .padding(.top, 32)

            Text("Erinnerung aktivieren?")
                .font(.title2)
                .fontWeight(.bold)

            Text("Wir erinnern dich rechtzeitig vor der Abreise – dafür brauchen wir deine Erlaubnis für Benachrichtigungen.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)

            Spacer()

            Button {
                onEnable()
            } label: {
                Text("Erinnerungen aktivieren")
                    .fontWeight(.semibold)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .padding(.horizontal, 24)

            Button("Später") {
                onLater()
            }
            .padding(.bottom, 24)
        }
        .presentationDetents([.height(320)])
    }
}

// MARK: - Temp Port Form Sheet

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
    @State private var selectedPhotoItem: PhotosPickerItem?

    // Ausflüge
    @State private var excursions: [String] = []
    @State private var newExcursionText = ""

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
                    DatePicker("Abfahrt", selection: $departureDate)
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
                    ForEach(Array(excursions.enumerated()), id: \.offset) { _, excursion in
                        Text(excursion)
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
            .onChange(of: selectedPhotoItem) { _, newItem in
                loadImage(from: newItem)
            }
        }
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
        // Verwende verbesserte Suche mit Land-Prüfung
        var lat: Double? = nil
        var lon: Double? = nil
        if let suggestion = PortSuggestion.findBestMatch(name: name, country: country) {
            lat = suggestion.latitude
            lon = suggestion.longitude
        }

        // Beim Bearbeiten vom Original ausgehen, damit id und isSeaDay erhalten bleiben;
        // die im Sheet editierbaren Felder (inkl. Bild/Ausflüge) werden überschrieben.
        var port = originalPort ?? TempPort(
            name: name,
            country: country,
            arrival: arrivalDate,
            departure: departureDate,
            latitude: lat,
            longitude: lon
        )
        port.name = name
        port.country = country
        port.arrival = arrivalDate
        port.departure = departureDate
        port.latitude = lat
        port.longitude = lon
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

// Wrapper, damit sheet(item:) einen Häfen-Index adressieren kann
private struct PortEditIndex: Identifiable {
    let id: Int
}

// MARK: - AI Import Sheet

/// Ergebnis einer Validierung/Aktion: Status + Anzeige-Text statt String-Sniffing auf "✓".
private enum FeedbackStatus {
    case success(String)
    case failure(String)

    var message: String {
        switch self {
        case .success(let text), .failure(let text): return text
        }
    }

    var isSuccess: Bool {
        if case .success = self { return true }
        return false
    }
}

struct AIImportSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var text: String
    @Binding var isProcessing: Bool
    @Binding fileprivate var feedback: FeedbackStatus?
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
                        RoundedRectangle(cornerRadius: DesignRadius.sm)
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
                
                if let feedback {
                    Text(feedback.message)
                        .foregroundStyle(feedback.isSuccess ? .green : .red)
                        .font(.callout)
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(feedback.isSuccess ? Color.green.opacity(0.1) : Color.red.opacity(0.1))
                        .clipShape(RoundedRectangle(cornerRadius: DesignRadius.sm))
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
