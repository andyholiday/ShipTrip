//
//  SettingsView.swift
//  ShipTrip
//
//  Created by ShipTrip on 18.12.25.
//

import SwiftUI
import SwiftData

/// Einstellungen und Mehr
struct SettingsView: View {
    @AppStorage("colorScheme") private var colorScheme = "system"

    @State private var showingApiKeySheet = false
    @State private var isValidatingKey = false
    @State private var keyValidationResult: Bool?
    @State private var hasApiKey = false

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
                
                // iCloud
                Section(header: Text("Synchronisation"),
                        footer: Text("iCloud-Sync ist für eine zukünftige Version geplant.")) {
                    HStack {
                        Label("iCloud Sync", systemImage: "icloud")
                        Spacer()
                        Text("Geplant")
                            .foregroundStyle(.secondary)
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
            .preferredColorScheme(colorSchemeValue)
        }
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
                        Text("\(reminderDaysBefore) \(String(localized: "Tage vorher"))")
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
                    footer: Text("Exportiert alle Kreuzfahrten als ZIP-Archiv mit externalen Bilddateien.")) {
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
                .disabled(cruises.isEmpty || isExporting)
            }
            
            // Import
            Section(header: Text("Import"),
                    footer: Text("Importiert Kreuzfahrten aus einer ZIP-Datei (Web-App kompatibel).")) {
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
                let url = try ExportImportService.shared.exportToZip(cruises: cruises)
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
