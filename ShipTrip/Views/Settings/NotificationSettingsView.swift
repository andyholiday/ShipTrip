//
//  NotificationSettingsView.swift
//  ShipTrip
//
//  Created by ShipTrip on 02.09.26.
//

import SwiftUI

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
