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
    
    // Developer Mode
    @State private var versionTapCount = 0
    @State private var showingDeveloperSettings = false
    
    var body: some View {
        NavigationStack {
            List {
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
                        footer: Text("Deine Daten werden automatisch mit iCloud synchronisiert.")) {
                    HStack {
                        Label("iCloud Sync", systemImage: "icloud")
                        Spacer()
                        Text("Aktiv")
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
                
                // Info
                Section("Info") {
                    HStack {
                        Text("Version")
                        Spacer()
                        Text("1.0.0")
                            .foregroundStyle(.secondary)
                            .onTapGesture {
                                versionTapCount += 1
                                if versionTapCount >= 5 {
                                    showingDeveloperSettings = true
                                    versionTapCount = 0
                                }
                            }
                    }
                    
                    Link(destination: URL(string: "https://github.com")!) {
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
            .sheet(isPresented: $showingDeveloperSettings) {
                DeveloperSettingsView()
            }
            .onAppear {
                hasApiKey = GeminiService.shared.isConfigured
            }
            .preferredColorScheme(colorSchemeValue)
        }
    }
    
    private var colorSchemeValue: ColorScheme? {
        switch colorScheme {
        case "light": return .light
        case "dark": return .dark
        default: return nil
        }
    }
}

/// API-Key Eingabe Sheet
struct ApiKeySheet: View {
    @Environment(\.dismiss) private var dismiss
    var onSaved: () -> Void
    
    @State private var inputKey = ""
    @State private var isValidating = false
    @State private var validationMessage = ""
    
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
                
                if !validationMessage.isEmpty {
                    Section {
                        Text(validationMessage)
                            .foregroundStyle(validationMessage.contains("✓") ? .green : .red)
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
        validationMessage = ""
        
        GeminiService.shared.setApiKey(inputKey)
        
        Task {
            do {
                let valid = try await GeminiService.shared.validateApiKey()
                await MainActor.run {
                    isValidating = false
                    if valid {
                        validationMessage = "✓ API-Key gültig"
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                            onSaved()
                            dismiss()
                        }
                    }
                }
            } catch {
                await MainActor.run {
                    isValidating = false
                    validationMessage = "✗ \(error.localizedDescription)"
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
                    Stepper("\(reminderDaysBefore) Tage vorher", value: $reminderDaysBefore, in: 1...30)
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
    
    @State private var showingDeleteAlert = false
    
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
                    Text("Angebote")
                    Spacer()
                    Text("\(deals.count)")
                        .foregroundStyle(.secondary)
                }
            }
            
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
                deleteAllData()
            }
        } message: {
            Text("Diese Aktion kann nicht rückgängig gemacht werden. Alle Kreuzfahrten und Angebote werden gelöscht.")
        }
    }
    
    private func deleteAllData() {
        for cruise in cruises {
            modelContext.delete(cruise)
        }
        for deal in deals {
            modelContext.delete(deal)
        }
    }
}

/// Developer-Einstellungen (versteckt)
struct DeveloperSettingsView: View {
    @AppStorage("developerApiOverride") private var apiOverride = ""
    
    var body: some View {
        NavigationStack {
            Form {
                Section(header: Text("API Override"),
                        footer: Text("Überschreibt die Standard-API-URL für Entwicklungszwecke.")) {
                    TextField("Backend-URL", text: $apiOverride)
                        .textInputAutocapitalization(.never)
                        .keyboardType(.URL)
                }
            }
            .navigationTitle("Developer")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

#Preview {
    SettingsView()
        .modelContainer(for: [Cruise.self, Deal.self], inMemory: true)
}
