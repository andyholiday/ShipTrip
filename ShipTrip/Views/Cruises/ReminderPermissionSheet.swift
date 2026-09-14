//
//  ReminderPermissionSheet.swift
//  ShipTrip
//
//  Welle D2: aus `CruiseFormView` herausgelöst, Verhalten unverändert.
//

import SwiftUI

// MARK: - Reminder Permission Sheet

/// Kontext-Sheet vor der System-Berechtigungsabfrage für Benachrichtigungen (A2.1): erklärt
/// kurz den Nutzen, bevor der native Prompt erscheint, statt ihn kommentarlos zu zeigen.
struct ReminderPermissionSheet: View {
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
