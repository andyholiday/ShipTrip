//
//  NotificationSettingsView.swift
//  ShipTrip
//
//  Created by ShipTrip on 02.09.26.
//

import SwiftData
import SwiftUI

/// Notification-Einstellungen
struct NotificationSettingsView: View {
    @Environment(\.modelContext) private var modelContext
    @AppStorage("notifyBeforeCruise") private var notifyBeforeCruise = true
    @AppStorage("notifyOnCruiseDay") private var notifyOnCruiseDay = true
    @AppStorage("reminderDaysBefore") private var reminderDaysBefore = 7
    
    @State private var isAuthorized = false
    @State private var isCheckingAuth = true

    /// Gleicht die geplanten Erinnerungen gegen den Soll-Zustand ab. Als
    /// Closure injizierbar, damit der Ablauf ohne Notification-Center testbar
    /// bleibt; der Default ist derselbe Lauf wie beim App-Start
    /// (`CruiseListView`), inklusive `isDemo`-Filter.
    private let reconcile: @MainActor (ModelContext) async -> Void

    init(
        reconcile: @escaping @MainActor (ModelContext) async -> Void = {
            await NotificationReconciler.run(context: $0)
        }
    ) {
        self.reconcile = reconcile
    }

    /// Wird nach jeder Änderung einer der drei Erinnerungs-Einstellungen
    /// gerufen und gleicht die geplanten Erinnerungen sofort ab — sonst wirkte
    /// die Änderung erst beim nächsten App-Start.
    ///
    /// Eigene Methode statt Inline-`onChange`, damit der Ablauf ohne
    /// SwiftUI-Laufzeit testbar ist.
    func settingsChanged(context: ModelContext) async {
        await reconcile(context)
    }

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
        .onChange(of: notifyBeforeCruise) { reconcileAfterChange() }
        .onChange(of: reminderDaysBefore) { reconcileAfterChange() }
        .onChange(of: notifyOnCruiseDay) { reconcileAfterChange() }
    }

    private func reconcileAfterChange() {
        Task { await settingsChanged(context: modelContext) }
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
