//
//  SettingsView.swift
//  ShipTrip
//
//  Created by ShipTrip on 18.12.25.
//

import SwiftUI
import SwiftData
import UIKit

/// Einstellungen und Mehr
struct SettingsView: View {
    @AppStorage("colorScheme") private var colorScheme = "system"
    @AppStorage(CalendarSyncPreferences.enabledKey) private var calendarSyncEnabled = false

    @State private var showingApiKeySheet = false
    @State private var isValidatingKey = false
    @State private var keyValidationResult: Bool?
    @State private var hasApiKey = false
    @State private var cloudSyncStatus: ShipTripCloudSync.AccountStatus = .loading

    @Environment(\.modelContext) private var modelContext
    @State private var hasDemoData = false
    
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
                
                // Beispielreise – auch im Release verfügbar, jederzeit entfernbar
                Section(header: Text(String(localized: "Beispielreise")),
                        footer: Text(demoSectionFooter)) {
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

                // Info
                Section("Info") {
                    HStack {
                        Text("Version")
                        Spacer()
                        Text(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0")
                            .foregroundStyle(.secondary)
                    }

                    // Setzt nur den Erststart-Schalter zurueck; praesentiert wird
                    // das Onboarding vom `fullScreenCover` in `ShipTripApp`.
                    Button {
                        OnboardingPresentation.requestReplay(in: .standard)
                    } label: {
                        Label(String(localized: "Intro erneut zeigen"), systemImage: "sparkles")
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
                hasDemoData = DemoDataService.hasDemoData(in: modelContext)
            }
            .task {
                cloudSyncStatus = await ShipTripCloudSync.accountStatus()
            }
            .preferredColorScheme(colorSchemeValue)
        }
    }

    /// Erklärt, dass Beispielinhalte markiert, export-frei und entfernbar sind.
    private var demoSectionFooter: String {
        String(localized: """
            Beispielinhalte zum Ausprobieren. Sie sind als Demo markiert, landen \
            nie in Export- oder Backup-Dateien und lassen sich jederzeit wieder \
            entfernen.
            """)
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

/// Datenverwaltung
struct DataManagementView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var cruises: [Cruise]
    @Query private var deals: [Deal]
    @Query private var customShippingLines: [CustomShippingLine]
    @Query private var customShips: [CustomShip]
    @Query private var hiddenCatalogItems: [HiddenCatalogItem]

    @State private var showingDeleteAlert = false
    @State private var showingResetAlert = false
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

    /// Export, Import und „Alle Daten löschen" arbeiten auf demselben Datenbestand und dürfen sich
    /// nicht überlappen — ein Löschen während eines laufenden Exports würde dem Export die Modelle
    /// unter den Händen wegziehen. Solange eine der Aktionen läuft, sind die anderen gesperrt.
    /// Als `static` ausgelagert, damit die Bedingung ohne View-Aufbau testbar bleibt.
    static func isDataActionBlocked(isExporting: Bool, isImporting: Bool) -> Bool {
        isExporting || isImporting
    }

    /// Welchen Container-Leser die manuell ausgewählte Datei braucht: ZIP-Archiv oder
    /// Base64-JSON. Eine `.shiptrip`-Datei **ist** ein ZIP-Archiv (Contract C1) und gehört
    /// deshalb hierher — nur das Base64-Legacy-Format ist kein ZIP. Ob das Archiv
    /// anschließend Share- oder Backup-Semantik hat, entscheidet allein der `share`-Block
    /// darin (C1/C10), nicht diese Zuordnung und nicht die Endung.
    /// Als `static` ausgelagert, damit die Zuordnung ohne View-Aufbau testbar bleibt.
    static func usesZipContainer(_ url: URL) -> Bool {
        ["zip", "shiptrip"].contains(url.pathExtension.lowercased())
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
                ) || Self.isDataActionBlocked(isExporting: isExporting, isImporting: isImporting))
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
                .disabled(Self.isDataActionBlocked(isExporting: isExporting, isImporting: isImporting))
            }

            // Löschen
            Section {
                Button("Alle Daten löschen", role: .destructive) {
                    showingDeleteAlert = true
                }
                .disabled(Self.isDataActionBlocked(isExporting: isExporting, isImporting: isImporting))
            }

            // App zurücksetzen: dasselbe Löschen wie oben, zusätzlich KI-API-Key,
            // Einstellungen und Erststart-Schalter — die App steht danach wieder
            // wie frisch installiert da. Dieselbe gegenseitige Sperre gegen
            // Export/Import.
            Section(footer: Text(String(localized: "Löscht alle Daten, deinen KI-API-Key und alle Einstellungen und zeigt das Intro wieder wie beim ersten Öffnen — die App steht danach wie frisch installiert da."))) {
                Button("App zurücksetzen", role: .destructive) {
                    showingResetAlert = true
                }
                .disabled(Self.isDataActionBlocked(isExporting: isExporting, isImporting: isImporting))
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
        .alert("App zurücksetzen?", isPresented: $showingResetAlert) {
            Button("Abbrechen", role: .cancel) { }
            Button("Zurücksetzen", role: .destructive) {
                resetApp()
            }
        } message: {
            Text("Diese Aktion kann nicht rückgängig gemacht werden. Alle Reisen, dein KI-API-Key und alle Einstellungen werden gelöscht, das Intro startet neu.")
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
            allowedContentTypes: [.zip, .json, .shipTripCruise],
            allowsMultipleSelection: false
        ) { result in
            handleImport(result: result)
        }
    }
    
    private func exportData() {
        // Der `.disabled`-Modifier ist nur die sichtbare Sperre; ein zweiter Tap kann ihn bei
        // schnellem Tippen unterlaufen. Der harte Riegel steht hier.
        guard !Self.isDataActionBlocked(isExporting: isExporting, isImporting: isImporting) else {
            return
        }
        isExporting = true

        Task {
            do {
                // Demo-Daten filtert der Service selbst — hier bewusst die vollständigen
                // Query-Ergebnisse übergeben. Der Aufruf ist `await`: Snapshot, Grenzprüfung und
                // JSON-Serialisierung (`encodeArchive`) laufen auf dem MainActor, das Schreiben
                // des Archivs samt CRC-32 off-main — der Spinner bleibt währenddessen
                // flüssig (C4).
                let url = try await ExportImportService.shared.exportToZip(
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
            guard !Self.isDataActionBlocked(isExporting: isExporting, isImporting: isImporting) else {
                return
            }

            isImporting = true
            
            // Security-scoped resource access
            guard url.startAccessingSecurityScopedResource() else {
                alertMessage = String(localized: "Zugriff auf Datei nicht möglich")
                showingAlert = true
                isImporting = false
                return
            }
            
            let isZip = Self.usesZipContainer(url)
            
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
    /// Gibt zurück, ob gespeichert werden konnte — „App zurücksetzen" hängt den
    /// Erststart-Schalter daran, damit ein fehlgeschlagenes Löschen nicht in
    /// einer frisch wirkenden App mit alten Daten endet.
    @discardableResult
    private func deleteAllData(alsoDeleteApiKey: Bool) -> Bool {
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
            return false
        }

        NotificationService.shared.removeAllPendingNotifications()
        if alsoDeleteApiKey {
            GeminiService.shared.clearApiKey()
        }
        return true
    }

    /// „App zurücksetzen": die App steht danach wie frisch installiert da.
    /// Derselbe Lösch-Pfad wie „Alle Daten löschen" — hier immer **mit** dem
    /// KI-API-Key aus der Keychain —, danach die Schritte ausserhalb des
    /// Stores (`AppReset`).
    private func resetApp() {
        guard deleteAllData(alsoDeleteApiKey: true) else { return }
        AppReset.run(calendarSync: .shared, defaults: .standard)
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
