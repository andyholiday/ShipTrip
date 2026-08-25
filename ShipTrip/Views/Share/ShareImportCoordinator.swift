//
//  ShareImportCoordinator.swift
//  ShipTrip
//
//  Zustand des automatischen Share-Imports (Contract C6). Treibt die Praesentation
//  in `ShipTripApp`: eingehende URL rein, Ergebnis-Zustand raus. Fehler enden immer
//  in `.failed` — nach aussen wirft hier nichts.
//

import Foundation
import SwiftData
import SwiftUI

@MainActor
@Observable
final class ShareImportCoordinator {

    // MARK: - Zustand

    enum State: Equatable {
        case idle
        case importing
        /// Import gelaufen (auch 0 importiert = „bereits vorhanden").
        /// `versionConflict` = Duplikat mit abweichender Senderfassung; das Ergebnis-Sheet
        /// zeigt dann den Konflikt-Hinweis. Weiterhin KEIN Merge.
        case finished(imported: Int, skippedDuplicates: Int, skippedInvalid: Int,
                      invalidMedia: Int, versionConflict: Bool)
        /// Menschlicher Fehlertext (`LocalizedError` des Import-/Preflight-Pfads).
        case failed(message: String)
        /// `shiptrip://import` ohne anstehende Datei — Hinweis zeigen.
        case linkHint
    }

    private(set) var state: State = .idle

    // MARK: - Einstieg

    /// Einstieg fuer `onOpenURL` (Datei ODER Scheme; Kalt- und Warmstart identisch).
    ///
    /// Single-Flight (C10): waehrend `.importing` werden weitere URLs verworfen — kein
    /// zweiter Task, keine Queue. In jedem anderen Zustand ersetzt die neue URL die
    /// aktuelle Praesentation.
    func handleIncomingURL(_ url: URL, modelContext: ModelContext) {
        guard state != .importing else { return }
        guard let link = IncomingLinkRouter.route(url) else { return }

        switch link {
        case .importHint:
            state = .linkHint
        case .shareFile(let fileURL):
            startImport(of: fileURL, modelContext: modelContext)
        }
    }

    /// Setzt den Zustand auf `.idle` (Sheet geschlossen).
    func dismiss() {
        state = .idle
    }

    // MARK: - Import

    private func startImport(of fileURL: URL, modelContext: ModelContext) {
        state = .importing

        // `Task {}` statt `Task.detached`: der Task erbt die MainActor-Isolation dieser
        // Klasse, damit die Mutation (Stufe B) auf dem MainActor landet. Off-main geht
        // ausschliesslich der Preflight — dafuer sorgt `importSharedCruise` selbst.
        Task {
            // Die Files-App liefert security-scoped URLs, die Documents/Inbox nicht;
            // deshalb best-effort statt Pflicht.
            let isSecurityScoped = fileURL.startAccessingSecurityScopedResource()
            defer {
                if isSecurityScoped { fileURL.stopAccessingSecurityScopedResource() }
                // Inbox-/Arbeitskopie in jedem Fall entfernen — Erfolg wie Fehler.
                try? FileManager.default.removeItem(at: fileURL)
            }

            do {
                let result = try await ExportImportService.shared.importSharedCruise(
                    from: fileURL, modelContext: modelContext
                )
                state = .finished(
                    imported: result.base.imported,
                    skippedDuplicates: result.base.skippedDuplicates,
                    skippedInvalid: result.base.skippedInvalid,
                    invalidMedia: result.base.invalidMedia,
                    versionConflict: result.versionConflict
                )
            } catch {
                state = .failed(message: error.localizedDescription)
            }
        }
    }
}
