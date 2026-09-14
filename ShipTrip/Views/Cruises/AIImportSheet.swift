//
//  AIImportSheet.swift
//  ShipTrip
//
//  Welle D2: aus `CruiseFormView` herausgelöst, Verhalten unverändert.
//

import SwiftUI

// MARK: - AI Import Sheet

struct AIImportSheet: View {
    /// Ergebnis einer Validierung/Aktion: Status + Anzeige-Text statt String-Sniffing auf "✓".
    /// Bewusst in `AIImportSheet` verschachtelt: `SettingsView` hat einen eigenen,
    /// file-privaten `FeedbackStatus`, ein zweiter interner Typ gleichen Namens wäre auf
    /// Modulebene mehrdeutig.
    enum FeedbackStatus {
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

    @Environment(\.dismiss) private var dismiss
    @Binding var text: String
    @Binding var isProcessing: Bool
    @Binding var feedback: FeedbackStatus?
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

                // Hinweis auf die Datenübertragung an den KI-Dienst – vor dem Senden sichtbar
                Text("Der eingefügte Text wird zur Auswertung an Google Gemini übertragen.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)

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
