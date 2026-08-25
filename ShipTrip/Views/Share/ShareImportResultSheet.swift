//
//  ShareImportResultSheet.swift
//  ShipTrip
//
//  Ergebnis-Praesentation des Share-Imports (Contract C6/C8/C9). Der Zustand des
//  `ShareImportCoordinator` wird in `ShareImportPresentation` uebersetzt — eine reine
//  Abbildung, die ohne SwiftUI testbar ist.
//

import SwiftUI

// MARK: - Ableitung aus dem Coordinator-Zustand

/// Was gezeigt wird. `nil` (siehe `init?`) heisst: nichts zeigen.
struct ShareImportPresentation: Identifiable, Equatable {

    enum Kind: String, Equatable {
        case result
        case linkHint

        /// Accessibility-Identifier nach Contract C9.
        var accessibilityIdentifier: String {
            switch self {
            case .result: "shareImport.resultSheet"
            case .linkHint: "shareImport.linkHintSheet"
            }
        }
    }

    let kind: Kind
    /// Bereits lokalisierter Text — wird als `String` angezeigt, nicht als Schluessel.
    let message: String
    let symbolName: String

    var id: String { "\(kind.rawValue)|\(message)" }

    /// `nil` fuer `.idle`/`.importing` — waehrend des Imports steht kein Sheet an.
    init?(state: ShareImportCoordinator.State) {
        switch state {
        case .idle, .importing:
            return nil

        case .linkHint:
            kind = .linkHint
            message = String(
                localized: "Öffne die angehängte .shiptrip-Datei, um die Reise zu importieren."
            )
            symbolName = "link"

        case .failed(let reason):
            kind = .result
            message = String(localized: "Import fehlgeschlagen: \(reason)")
            symbolName = "exclamationmark.triangle"

        case .finished(let imported, let skippedDuplicates, _, _, let versionConflict):
            kind = .result
            if imported > 0 {
                message = String(localized: "Reise importiert")
                symbolName = "checkmark.circle"
            } else if skippedDuplicates > 0 {
                // Konflikt heisst: dieselbe Reise, aber eine andere Senderfassung als die
                // damals empfangene (C1). Zusammengefuehrt wird trotzdem nichts.
                message = versionConflict
                    ? String(
                        localized: "Diese Reise ist bereits vorhanden — die geteilte Fassung weicht von deiner ab."
                    )
                    : String(localized: "Diese Reise ist bereits vorhanden.")
                symbolName = versionConflict ? "exclamationmark.circle" : "info.circle"
            } else {
                // Weder importiert noch als Duplikat erkannt: die Datei trug nichts
                // Verwertbares (z. B. unplausible Datumsangaben).
                message = ShareImportError.notAShareFile.errorDescription ?? ""
                symbolName = "exclamationmark.triangle"
            }
        }
    }
}

// MARK: - Sheet

struct ShareImportResultSheet: View {
    let presentation: ShareImportPresentation
    let onDismiss: () -> Void

    var body: some View {
        VStack(spacing: 24) {
            Image(systemName: presentation.symbolName)
                .font(.system(size: 44))
                .foregroundStyle(.tint)
                .accessibilityHidden(true)

            Text(presentation.message)
                .font(.body)
                .multilineTextAlignment(.center)

            Button("OK", action: onDismiss)
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
        }
        .padding(32)
        .presentationDetents([.medium])
        .accessibilityIdentifier(presentation.kind.accessibilityIdentifier)
    }
}

// MARK: - Preview

#Preview("Importiert") {
    if let presentation = ShareImportPresentation(
        state: .finished(imported: 1, skippedDuplicates: 0, skippedInvalid: 0,
                         invalidMedia: 0, versionConflict: false)
    ) {
        ShareImportResultSheet(presentation: presentation) {}
    }
}

#Preview("Versionskonflikt") {
    if let presentation = ShareImportPresentation(
        state: .finished(imported: 0, skippedDuplicates: 1, skippedInvalid: 0,
                         invalidMedia: 0, versionConflict: true)
    ) {
        ShareImportResultSheet(presentation: presentation) {}
    }
}
