//
//  SettingsView.swift
//  ShipTrip
//
//  Created by ShipTrip on 18.12.25.
//

import SwiftUI
import SwiftData
import EventKit
import UIKit

@MainActor
struct CalendarSyncOperationState {
    enum Phase: Equatable {
        case idle
        case running
    }

    private(set) var phase: Phase = .idle

    var isWorking: Bool {
        phase == .running
    }

    mutating func begin() -> Bool {
        guard phase == .idle else { return false }
        phase = .running
        return true
    }

    mutating func finish() {
        phase = .idle
    }
}

/// Einstellungen und Mehr
struct SettingsView: View {
    @AppStorage("colorScheme") private var colorScheme = "system"
    @AppStorage(CalendarSyncPreferences.enabledKey) private var calendarSyncEnabled = false

    @State private var showingApiKeySheet = false
    @State private var isValidatingKey = false
    @State private var keyValidationResult: Bool?
    @State private var hasApiKey = false
    @State private var cloudSyncStatus: ShipTripCloudSync.AccountStatus = .loading

    #if DEBUG
    @Environment(\.modelContext) private var modelContext
    @State private var hasDemoData = false
    #endif
    
    var body: some View {
        NavigationStack {
            List {
                Section {
                    moreHeader
                        .listRowInsets(EdgeInsets(top: 10, leading: 16, bottom: 10, trailing: 16))
                        .listRowBackground(Color.clear)
                }

                // Erscheinungsbild
                Section("Erscheinungsbild") {
                    Picker("Farbschema", selection: $colorScheme) {
                        Text("System").tag("system")
                        Text("Hell").tag("light")
                        Text("Dunkel").tag("dark")
                    }
                }
                
                // KI-Funktionen
                Section(header: Text("KI-Funktionen"),
                        footer: Text("Mit einem Gemini API-Key können Kreuzfahrt-Daten automatisch aus Text extrahiert werden.")) {
                    HStack {
                        Label("Gemini API", systemImage: "wand.and.stars")
                        Spacer()
                        if hasApiKey {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(.green)
                        } else {
                            Text("Nicht konfiguriert")
                                .foregroundStyle(.secondary)
                        }
                    }
                    
                    Button {
                        showingApiKeySheet = true
                    } label: {
                        Label(hasApiKey ? "API-Key ändern" : "API-Key eingeben", systemImage: "key")
                    }
                    
                    if hasApiKey {
                        Button(role: .destructive) {
                            GeminiService.shared.clearApiKey()
                            hasApiKey = false
                        } label: {
                            Label("API-Key entfernen", systemImage: "trash")
                        }
                    }
                    
                    Link(destination: URL(string: "https://aistudio.google.com/app/apikey")!) {
                        Label("Neuen Key bei Google erstellen", systemImage: "arrow.up.right.square")
                    }
                }
                
                // Synchronisation
                Section(header: Text("Synchronisation"),
                        footer: Text("Reisedaten werden automatisch über deinen privaten iCloud-Account synchronisiert. Die Kalender-Synchronisation ist optional.")) {
                    HStack {
                        Label("iCloud Sync", systemImage: "icloud")
                        Spacer()
                        Text(cloudSyncStatus.label)
                            .foregroundStyle(.secondary)
                    }

                    NavigationLink {
                        CalendarSyncSettingsView()
                    } label: {
                        HStack {
                            Label("Kalender", systemImage: "calendar.badge.plus")
                            Spacer()
                            Text(calendarSyncEnabled ? "Aktiv" : "Aus")
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                
                // Benachrichtigungen
                Section("Benachrichtigungen") {
                    NavigationLink {
                        NotificationSettingsView()
                    } label: {
                        Label("Erinnerungen", systemImage: "bell")
                    }
                }
                
                // Daten
                Section("Daten") {
                    NavigationLink {
                        DataManagementView()
                    } label: {
                        Label("Daten verwalten", systemImage: "externaldrive")
                    }
                }

                // Reedereien & Schiffe (Welle B5)
                Section(header: Text("Reedereien & Schiffe"),
                        footer: Text(String(localized: "Fehlt eine Reederei oder ein Schiff im Katalog? Hier kannst du eigene Einträge anlegen."))) {
                    NavigationLink {
                        ShippingLineManagementView()
                    } label: {
                        Label("Eigene Reedereien & Schiffe", systemImage: "ferry")
                    }
                }
                
                // Demo (nur Debug)
                #if DEBUG
                Section("Demo (nur Debug)") {
                    if hasDemoData {
                        Button(role: .destructive) {
                            DemoDataService.removeDemoData(from: modelContext)
                            hasDemoData = DemoDataService.hasDemoData(in: modelContext)
                        } label: {
                            Label("Beispieldaten entfernen", systemImage: "trash")
                        }
                    } else {
                        Button {
                            DemoDataService.loadDemoData(into: modelContext)
                            hasDemoData = DemoDataService.hasDemoData(in: modelContext)
                        } label: {
                            Label("Beispieldaten laden", systemImage: "square.and.arrow.down")
                        }
                    }
                }
                #endif

                // Info
                Section("Info") {
                    HStack {
                        Text("Version")
                        Spacer()
                        Text(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0")
                            .foregroundStyle(.secondary)
                    }

                    Link(destination: URL(string: "https://github.com/andyholiday/ShipTrip")!) {
                        Label("GitHub", systemImage: "chevron.left.forwardslash.chevron.right")
                    }

                    if let privacyPolicyURL {
                        Link(destination: privacyPolicyURL) {
                            Label("Datenschutzerklärung", systemImage: "hand.raised")
                        }
                    }

                    if let supportURL {
                        Link(destination: supportURL) {
                            Label("Support", systemImage: "questionmark.circle")
                        }
                    }
                }
            }
            .navigationTitle("Einstellungen")
            .sheet(isPresented: $showingApiKeySheet) {
                ApiKeySheet(onSaved: {
                    hasApiKey = GeminiService.shared.isConfigured
                })
            }
            .onAppear {
                hasApiKey = GeminiService.shared.isConfigured
                #if DEBUG
                hasDemoData = DemoDataService.hasDemoData(in: modelContext)
                #endif
            }
            .task {
                cloudSyncStatus = await ShipTripCloudSync.accountStatus()
            }
            .preferredColorScheme(colorSchemeValue)
        }
    }

    /// Datenschutzerklärung – deutsche Fassung nur bei deutscher Gerätesprache.
    private var privacyPolicyURL: URL? {
        let isGerman = Locale.current.language.languageCode?.identifier == "de"
        return URL(string: "https://app-legals.vercel.app/shiptrip/privacy-\(isGerman ? "de" : "en")")
    }

    /// Support-Kanal: Issue-Tracker des Projekts.
    private var supportURL: URL? {
        URL(string: "https://github.com/andyholiday/ShipTrip/issues")
    }

    private var moreHeader: some View {
        VStack(alignment: .leading, spacing: 12) {
            Image(systemName: "ferry.fill")
                .font(.title2)
                .foregroundStyle(.white)
                .frame(width: 54, height: 54)
                .background(
                    LinearGradient(
                        colors: [Color.oceanBlue, Color.navyDark],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .clipShape(RoundedRectangle(cornerRadius: DesignRadius.md))

            Text(String(localized: "Dein Kreuzfahrt-Archiv"))
                .font(.title3)
                .fontWeight(.heavy)

            Text(String(localized: "Archiv, Komfort und Premium-Funktionen an einem Ort."))
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(20)
        .background(
            LinearGradient(
                colors: [Color(UIColor.secondarySystemBackground), Color.oceanBlue.opacity(0.10)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .clipShape(RoundedRectangle(cornerRadius: DesignRadius.lg))
    }
    
    private var colorSchemeValue: ColorScheme? {
        switch colorScheme {
        case "light": return .light
        case "dark": return .dark
        default: return nil
        }
    }
}

/// Optionale Spiegelung aller Reisen in einen auswählbaren Systemkalender.
struct CalendarSyncSettingsView: View {
    @Query(sort: \Cruise.startDate) private var cruises: [Cruise]
    @AppStorage(CalendarSyncPreferences.enabledKey) private var isEnabled = false
    @AppStorage(CalendarSyncPreferences.calendarIdentifierKey) private var calendarIdentifier = ""
    @AppStorage(CalendarSyncPreferences.modeKey) private var modeRawValue = CalendarSyncMode.tripOnly.rawValue

    @State private var calendars: [WritableCalendar] = []
    @State private var operationState = CalendarSyncOperationState()
    @State private var statusMessage = ""
    @State private var showingAccessAlert = false
    @State private var pendingCalendarIdentifier: String?

    private var isWorking: Bool {
        operationState.isWorking
    }

    /// Der Picker schreibt die Auswahl erst nach einer eventuell nötigen
    /// Bestätigung fort. Bis dahin bleibt der bisherige Kalender aktiv, damit
    /// vor dem Umzug nichts in einen Kalender geschrieben wird.
    private var calendarSelection: Binding<String> {
        Binding(
            get: { calendarIdentifier },
            set: { requestCalendarChange(to: $0) }
        )
    }

    private var isConfirmingMigration: Binding<Bool> {
        Binding(
            get: { pendingCalendarIdentifier != nil },
            set: { if !$0 { pendingCalendarIdentifier = nil } }
        )
    }

    private var mode: Binding<String> {
        Binding(
            get: { modeRawValue },
            set: { newValue in
                modeRawValue = newValue
                synchronizeIfEnabled()
            }
        )
    }

    var body: some View {
        Form {
            Section {
                Toggle(
                    "Reisen mit Kalender synchronisieren",
                    isOn: Binding(
                        get: { isEnabled },
                        set: { newValue in
                            startUpdatingEnabled(newValue)
                        }
                    )
                )
                .disabled(isWorking)

                if isWorking {
                    HStack {
                        ProgressView()
                        Text("Kalender wird aktualisiert …")
                            .foregroundStyle(.secondary)
                    }
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel(Text("Kalender wird aktualisiert …"))
                    .accessibilityIdentifier("calendarSyncProgress")
                } else if !statusMessage.isEmpty {
                    Text(statusMessage)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            } footer: {
                Text("ShipTrip aktualisiert angelegte Termine automatisch und entfernt sie wieder, wenn eine Reise gelöscht oder die Synchronisation deaktiviert wird.")
            }

            Section("Zielkalender") {
                if calendars.isEmpty {
                    Text("Kein beschreibbarer Kalender verfügbar")
                        .foregroundStyle(.secondary)
                } else {
                    Picker("Kalender", selection: calendarSelection) {
                        ForEach(calendars) { calendar in
                            Text(calendar.displayName).tag(calendar.id)
                        }
                    }
                    .disabled(!isEnabled || isWorking)
                }
            }

            Section {
                Picker("Kalendereinträge", selection: mode) {
                    ForEach(CalendarSyncMode.allCases) { option in
                        Text(option.displayName).tag(option.rawValue)
                    }
                }
                .pickerStyle(.inline)
                .disabled(!isEnabled || isWorking)
            } header: {
                Text("Umfang")
            } footer: {
                Text("Im Detailmodus erhält jeder Hafen und Seetag einen eigenen Eintrag. Seetage nennen die Häfen davor und danach.")
            }

            if isEnabled {
                Section {
                    Button("Jetzt synchronisieren") {
                        synchronizeIfEnabled()
                    }
                    .disabled(isWorking)
                }
            }
        }
        .navigationTitle("Kalender")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await refreshCalendars()
        }
        .alert("Kalenderzugriff erforderlich", isPresented: $showingAccessAlert) {
            Button("Abbrechen", role: .cancel) { }
            Button("Einstellungen öffnen") {
                guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
                UIApplication.shared.open(url)
            }
        } message: {
            Text("Erlaube ShipTrip den vollständigen Kalenderzugriff, damit du einen Zielkalender auswählen und bestehende ShipTrip-Termine aktualisieren kannst.")
        }
        .alert(
            "Termine in den neuen Kalender übertragen?",
            isPresented: isConfirmingMigration,
            presenting: pendingCalendarIdentifier
        ) { identifier in
            Button("Abbrechen", role: .cancel) {
                pendingCalendarIdentifier = nil
            }
            Button("Übertragen") {
                startMigration(to: identifier)
            }
        } message: { _ in
            Text("Alle bestehenden ShipTrip-Termine werden im neuen Kalender angelegt und im bisherigen Kalender gelöscht.")
        }
    }

    // MARK: - Zielkalender wechseln

    private func requestCalendarChange(to identifier: String) {
        switch CalendarTargetChangePlanner.decide(
            current: calendarIdentifier,
            selected: identifier,
            isSyncEnabled: isEnabled,
            hasManagedEvents: CalendarSyncService.shared.hasManagedEvents
        ) {
        case .ignore:
            break
        case .apply:
            calendarIdentifier = identifier
            synchronizeIfEnabled()
        case .confirmMigration:
            pendingCalendarIdentifier = identifier
        }
    }

    private func startMigration(to identifier: String) {
        pendingCalendarIdentifier = nil
        guard operationState.begin() else { return }
        Task { @MainActor in
            await Task.yield()
            migrateNow(to: identifier)
        }
    }

    private func migrateNow(to identifier: String) {
        defer { operationState.finish() }

        let previousIdentifier = calendarIdentifier
        calendarIdentifier = identifier
        do {
            let count = try CalendarSyncService.shared.migrateManagedEvents(cruises: cruises)
            statusMessage = String(localized: "\(count) Kalendereinträge in den neuen Kalender übertragen.")
        } catch CalendarSyncError.accessDenied {
            calendarIdentifier = previousIdentifier
            isEnabled = false
            showingAccessAlert = true
        } catch {
            calendarIdentifier = previousIdentifier
            restorePreviousCalendarEvents()
            statusMessage = error.localizedDescription
        }
    }

    /// Stellt nach einer fehlgeschlagenen Migration die Termine im bisherigen
    /// Kalender wieder her. Nötig, weil `calendarIdentifier` durch den Rollback
    /// netto unverändert bleibt und `CalendarSyncObserver` deshalb nicht feuert.
    private func restorePreviousCalendarEvents() {
        // Ein Fehler hier bleibt bewusst stumm: Sichtbar ist die Ursache des
        // Fehlschlags, die der Aufrufer direkt danach in `statusMessage` setzt.
        try? CalendarSyncService.shared.synchronize(cruises: cruises)
    }

    private func refreshCalendars() async {
        guard CalendarSyncService.shared.authorizationStatus == .fullAccess else {
            calendars = []
            return
        }
        calendars = CalendarSyncService.shared.writableCalendars()
        calendarIdentifier = CalendarSyncService.shared.selectDefaultCalendarIfNeeded() ?? ""
        if isEnabled {
            synchronizeIfEnabled()
        }
    }

    private func startUpdatingEnabled(_ newValue: Bool) {
        guard operationState.begin() else { return }
        Task { @MainActor in
            await Task.yield()
            await updateEnabled(newValue)
        }
    }

    private func updateEnabled(_ newValue: Bool) async {
        defer { operationState.finish() }

        guard newValue else {
            isEnabled = false
            do {
                try CalendarSyncService.shared.removeAllManagedEvents()
                statusMessage = String(localized: "ShipTrip-Termine wurden entfernt.")
            } catch CalendarSyncError.accessDenied {
                isEnabled = false
                statusMessage = String(localized: "Die Synchronisation ist aus. Erlaube Kalenderzugriff erneut, um vorhandene ShipTrip-Termine zu entfernen.")
                showingAccessAlert = true
            } catch {
                isEnabled = true
                statusMessage = error.localizedDescription
            }
            return
        }

        guard await CalendarSyncService.shared.requestAccess() else {
            isEnabled = false
            showingAccessAlert = true
            return
        }

        calendars = CalendarSyncService.shared.writableCalendars()
        guard let selectedIdentifier = CalendarSyncService.shared.selectDefaultCalendarIfNeeded() else {
            isEnabled = false
            statusMessage = String(localized: "Kein beschreibbarer Kalender verfügbar.")
            return
        }

        calendarIdentifier = selectedIdentifier
        isEnabled = true
        performSynchronization()
    }

    private func synchronizeIfEnabled() {
        guard isEnabled, operationState.begin() else { return }
        Task { @MainActor in
            await Task.yield()
            synchronizeNow()
        }
    }

    private func synchronizeNow() {
        defer { operationState.finish() }
        performSynchronization()
    }

    private func performSynchronization() {
        do {
            let count = try CalendarSyncService.shared.synchronize(cruises: cruises)
            statusMessage = String(localized: "\(count) Kalendereinträge synchronisiert.")
        } catch CalendarSyncError.accessDenied {
            isEnabled = false
            showingAccessAlert = true
        } catch {
            statusMessage = error.localizedDescription
        }
    }
}

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

/// API-Key Eingabe Sheet
struct ApiKeySheet: View {
    @Environment(\.dismiss) private var dismiss
    var onSaved: () -> Void

    @State private var inputKey = ""
    @State private var isValidating = false
    @State private var validationStatus: FeedbackStatus?
    
    var body: some View {
        NavigationStack {
            Form {
                Section(footer: Text("Den API-Key findest du in Google AI Studio.")) {
                    SecureField("API-Key eingeben", text: $inputKey)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                }
                
                if isValidating {
                    Section {
                        HStack {
                            ProgressView()
                            Text("Validiere...")
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                
                if let validationStatus {
                    Section {
                        Text(validationStatus.message)
                            .foregroundStyle(validationStatus.isSuccess ? .green : .red)
                    }
                }
            }
            .navigationTitle("Gemini API-Key")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Abbrechen") { dismiss() }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("Speichern") {
                        saveApiKey()
                    }
                    .disabled(inputKey.isEmpty || isValidating)
                }
            }
        }
    }
    
    private func saveApiKey() {
        isValidating = true
        validationStatus = nil

        GeminiService.shared.setApiKey(inputKey)

        Task {
            do {
                let valid = try await GeminiService.shared.validateApiKey()
                await MainActor.run {
                    isValidating = false
                    if valid {
                        let message = "✓ API-Key gültig"
                        validationStatus = .success(message)
                        AccessibilityNotification.Announcement(message).post()
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                            onSaved()
                            dismiss()
                        }
                    }
                }
            } catch {
                await MainActor.run {
                    isValidating = false
                    let message = "✗ \(error.localizedDescription)"
                    validationStatus = .failure(message)
                    AccessibilityNotification.Announcement(message).post()
                    GeminiService.shared.clearApiKey()
                }
            }
        }
    }
}

/// Notification-Einstellungen
struct NotificationSettingsView: View {
    @AppStorage("notifyBeforeCruise") private var notifyBeforeCruise = true
    @AppStorage("notifyOnCruiseDay") private var notifyOnCruiseDay = true
    @AppStorage("reminderDaysBefore") private var reminderDaysBefore = 7
    
    @State private var isAuthorized = false
    @State private var isCheckingAuth = true
    
    var body: some View {
        Form {
            // Authorization Status
            Section {
                HStack {
                    Label("Benachrichtigungen", systemImage: "bell.badge")
                    Spacer()
                    if isCheckingAuth {
                        ProgressView()
                    } else if isAuthorized {
                        Text("Erlaubt")
                            .foregroundStyle(.green)
                    } else {
                        Text("Deaktiviert")
                            .foregroundStyle(.red)
                    }
                }
                
                if !isAuthorized && !isCheckingAuth {
                    Button("Berechtigung anfordern") {
                        requestAuthorization()
                    }
                }
            }
            
            Section(footer: Text("Du erhältst eine Erinnerung vor deiner Kreuzfahrt.")) {
                Toggle("Erinnerung vor der Reise", isOn: $notifyBeforeCruise)
                    .disabled(!isAuthorized)
                
                if notifyBeforeCruise {
                    Stepper(value: $reminderDaysBefore, in: 1...30) {
                        Text(String(localized: "\(reminderDaysBefore) Tage vorher"))
                    }
                    .disabled(!isAuthorized)
                }
            }
            
            Section(footer: Text("Du erhältst eine Benachrichtigung am Tag der Abreise.")) {
                Toggle("Am Reisetag erinnern", isOn: $notifyOnCruiseDay)
                    .disabled(!isAuthorized)
            }
        }
        .navigationTitle("Erinnerungen")
        .onAppear {
            checkAuthorization()
        }
    }
    
    private func checkAuthorization() {
        isCheckingAuth = true
        Task {
            let authorized = await NotificationService.shared.isAuthorized()
            await MainActor.run {
                isAuthorized = authorized
                isCheckingAuth = false
            }
        }
    }
    
    private func requestAuthorization() {
        Task {
            let granted = await NotificationService.shared.requestAuthorization()
            await MainActor.run {
                isAuthorized = granted
            }
        }
    }
}

/// Datenverwaltung
struct DataManagementView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var cruises: [Cruise]
    @Query private var deals: [Deal]
    @Query private var customShippingLines: [CustomShippingLine]
    @Query private var customShips: [CustomShip]
    @Query private var hiddenCatalogItems: [HiddenCatalogItem]

    @State private var showingDeleteAlert = false
    @State private var showingApiKeyDeleteConfirm = false
    @State private var showingExportSheet = false
    @State private var showingImportPicker = false
    @State private var isExporting = false
    @State private var isImporting = false
    @State private var exportURL: URL?
    @State private var alertMessage = ""
    @State private var showingAlert = false

    /// Ist überhaupt etwas da, das ein Backup sichern würde? Der Export umfasst neben
    /// Kreuzfahrten und Wunschreisen auch eigene Reedereien, eigene Schiffe und ausgeblendete
    /// Katalog-Einträge (ADR-006) — der Button darf deshalb erst sperren, wenn ALLE fünf
    /// Sammlungen leer sind, sonst lässt sich ein reines Katalog-Overlay nicht sichern.
    /// Als `static` ausgelagert, damit die Bedingung ohne View-Aufbau testbar bleibt.
    static func hasExportableData(
        cruises: Int,
        deals: Int,
        customLines: Int,
        customShips: Int,
        hiddenCatalogItems: Int
    ) -> Bool {
        cruises + deals + customLines + customShips + hiddenCatalogItems > 0
    }

    var body: some View {
        Form {
            Section("Übersicht") {
                HStack {
                    Text("Kreuzfahrten")
                    Spacer()
                    Text("\(cruises.count)")
                        .foregroundStyle(.secondary)
                }
                
                HStack {
                    Text("Wunschreisen")
                    Spacer()
                    Text("\(deals.count)")
                        .foregroundStyle(.secondary)
                }
            }
            
            // Export
            Section(header: Text("Export"),
                    footer: Text(String(localized: "Sichert Kreuzfahrten, Wunschreisen, eigene Reedereien und Schiffe sowie ausgeblendete Katalog-Einträge als ZIP-Archiv mit externen Bilddateien. Demo-Daten werden nicht mitexportiert."))) {
                Button {
                    exportData()
                } label: {
                    HStack {
                        Label("Daten exportieren", systemImage: "square.and.arrow.up")
                        Spacer()
                        if isExporting {
                            ProgressView()
                        }
                    }
                }
                .disabled(!Self.hasExportableData(
                    cruises: cruises.count,
                    deals: deals.count,
                    customLines: customShippingLines.count,
                    customShips: customShips.count,
                    hiddenCatalogItems: hiddenCatalogItems.count
                ) || isExporting)
            }

            // Import
            Section(header: Text("Import"),
                    footer: Text(String(localized: "Liest ZIP- und JSON-Backups: Kreuzfahrten, Wunschreisen, eigene Reedereien und Schiffe sowie Ausblendungen. Ältere Backups (bis Version 1.7) bleiben lesbar."))) {
                Button {
                    showingImportPicker = true
                } label: {
                    HStack {
                        Label("Daten importieren", systemImage: "square.and.arrow.down")
                        Spacer()
                        if isImporting {
                            ProgressView()
                        }
                    }
                }
                .disabled(isImporting)
            }
            
            // Löschen
            Section {
                Button("Alle Daten löschen", role: .destructive) {
                    showingDeleteAlert = true
                }
            }
        }
        .navigationTitle("Daten verwalten")
        .alert("Alle Daten löschen?", isPresented: $showingDeleteAlert) {
            Button("Abbrechen", role: .cancel) { }
            Button("Löschen", role: .destructive) {
                if GeminiService.shared.isConfigured {
                    showingApiKeyDeleteConfirm = true
                } else {
                    deleteAllData(alsoDeleteApiKey: false)
                }
            }
        } message: {
            Text("Diese Aktion kann nicht rückgängig gemacht werden. Alle Kreuzfahrten und Wunschreisen werden gelöscht.")
        }
        .alert("KI-API-Key auch löschen?", isPresented: $showingApiKeyDeleteConfirm) {
            Button("Behalten", role: .cancel) {
                deleteAllData(alsoDeleteApiKey: false)
            }
            Button("Löschen", role: .destructive) {
                deleteAllData(alsoDeleteApiKey: true)
            }
        } message: {
            Text("Dein Gemini-API-Key ist separat in der Keychain gespeichert und bleibt sonst erhalten.")
        }
        .alert("Info", isPresented: $showingAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(alertMessage)
        }
        .sheet(isPresented: $showingExportSheet) {
            if let url = exportURL {
                ShareSheet(items: [url]) {
                    // Temp-Export-Datei erst löschen, wenn die Activity-View-Controller-Präsentation
                    // abgeschlossen ist (auch bei Abbruch) — nicht vorzeitig bei Sheet-Disappear.
                    try? FileManager.default.removeItem(at: url)
                    exportURL = nil
                }
            }
        }
        .fileImporter(
            isPresented: $showingImportPicker,
            allowedContentTypes: [.zip, .json],
            allowsMultipleSelection: false
        ) { result in
            handleImport(result: result)
        }
    }
    
    private func exportData() {
        isExporting = true

        Task {
            do {
                // Demo-Daten filtert der Service selbst — hier bewusst die vollständigen
                // Query-Ergebnisse übergeben.
                let url = try ExportImportService.shared.exportToZip(
                    cruises: cruises,
                    deals: deals,
                    customLines: customShippingLines,
                    customShips: customShips,
                    hiddenCatalogItems: hiddenCatalogItems
                )
                await MainActor.run {
                    isExporting = false
                    exportURL = url
                    showingExportSheet = true
                }
            } catch {
                await MainActor.run {
                    isExporting = false
                    alertMessage = String(localized: "Export fehlgeschlagen: ") + error.localizedDescription
                    showingAlert = true
                }
            }
        }
    }
    
    private func handleImport(result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            guard let url = urls.first else { return }
            
            isImporting = true
            
            // Security-scoped resource access
            guard url.startAccessingSecurityScopedResource() else {
                alertMessage = String(localized: "Zugriff auf Datei nicht möglich")
                showingAlert = true
                isImporting = false
                return
            }
            
            let isZip = url.pathExtension.lowercased() == "zip"
            
            Task {
                defer {
                    url.stopAccessingSecurityScopedResource()
                }
                
                do {
                    let result: ImportResult
                    if isZip {
                        result = try ExportImportService.shared.importFromZip(
                            url: url,
                            modelContext: modelContext
                        )
                    } else {
                        result = try ExportImportService.shared.importFromJSON(
                            url: url,
                            modelContext: modelContext
                        )
                    }
                    await MainActor.run {
                        isImporting = false
                        var msg = "✓ \(result.imported) " + String(localized: "importiert")
                        if result.skippedDuplicates > 0 {
                            msg += " · \(result.skippedDuplicates) " + String(localized: "Duplikate übersprungen")
                        }
                        if result.skippedInvalid > 0 {
                            msg += " · \(result.skippedInvalid) " + String(localized: "mit ungültigem Datum übersprungen")
                        }
                        if result.invalidMedia > 0 {
                            msg += " · \(result.invalidMedia) " + String(localized: "Medien fehlten oder waren ungültig")
                        }
                        alertMessage = msg
                        showingAlert = true
                    }
                } catch {
                    await MainActor.run {
                        isImporting = false
                        alertMessage = String(localized: "Import fehlgeschlagen: ") + error.localizedDescription
                        showingAlert = true
                    }
                }
            }
            
        case .failure(let error):
            alertMessage = String(localized: "Dateiauswahl fehlgeschlagen: ") + error.localizedDescription
            showingAlert = true
        }
    }
    
    /// Löscht alle Kreuzfahrten, Wunschreisen sowie eigene Reedereien/Schiffe und ausgeblendete
    /// Katalog-Einträge (ADR-006). Erst nach erfolgreichem Speichern werden
    /// geplante Erinnerungen entfernt und optional der KI-API-Key gelöscht, damit bei einem
    /// fehlgeschlagenen Save keine Seiteneffekte ausgeführt werden.
    private func deleteAllData(alsoDeleteApiKey: Bool) {
        for cruise in cruises {
            modelContext.delete(cruise)
        }
        for deal in deals {
            modelContext.delete(deal)
        }
        for customLine in customShippingLines {
            modelContext.delete(customLine)
        }
        for customShip in customShips {
            modelContext.delete(customShip)
        }
        for hiddenItem in hiddenCatalogItems {
            modelContext.delete(hiddenItem)
        }

        do {
            try modelContext.save()
        } catch {
            // Gestagte Deletes zurücknehmen, damit ein späterer Save sie nicht doch
            // noch persistiert.
            modelContext.rollback()
            alertMessage = String(localized: "Löschen fehlgeschlagen: ") + error.localizedDescription
            showingAlert = true
            return
        }

        NotificationService.shared.removeAllPendingNotifications()
        if alsoDeleteApiKey {
            GeminiService.shared.clearApiKey()
        }
    }
}

/// Share Sheet für Export. `onComplete` feuert erst, wenn die Activity-View-Controller-
/// Präsentation abgeschlossen ist (auch bei Abbruch) — nicht beim Sheet-Disappear.
struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]
    let onComplete: () -> Void

    func makeUIViewController(context: Context) -> UIActivityViewController {
        let controller = UIActivityViewController(activityItems: items, applicationActivities: nil)
        controller.completionWithItemsHandler = { _, _, _, _ in
            onComplete()
        }
        return controller
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

#Preview {
    SettingsView()
        .modelContainer(for: [Cruise.self, Deal.self], inMemory: true)
}
