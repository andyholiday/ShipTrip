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

    // MARK: - Aufraeumen

    /// Darf die Quelldatei nach dem Import geloescht werden?
    ///
    /// Seit `LSSupportsOpeningDocumentsInPlace` reicht die Dateien-App die
    /// **Originaldatei des Nutzers** herein (iCloud Drive, Anhang-Ablage,
    /// fremder File Provider). Geloescht wird deshalb nur, was die App selbst
    /// als Kopie bekommen hat: `Documents/Inbox` (Kopie beim Oeffnen ohne
    /// In-Place), das `tmp`-Verzeichnis des Containers (Arbeitskopie) und der
    /// Uebergabeordner der Share-Extension (ADR-010, H3) — dort liegt
    /// ausschliesslich eine Kopie, die die Extension fuer genau diesen Import
    /// abgelegt hat. Alles andere bleibt liegen — im Zweifel lieber eine Datei
    /// zu viel.
    ///
    /// - Parameter inbox: Uebergabeordner; `nil` heisst „kein App-Group-
    ///   Container" und faellt auf das bisherige Verhalten zurueck. Der
    ///   Parameter ist zugleich die Test-Naht (Wegwerf-Ordner).
    static func shouldRemoveAfterImport(
        _ url: URL,
        inbox: URL? = ShareHandoffStore.inboxURL()
    ) -> Bool {
        let candidate = normalizedPath(url)
        let documentsInbox = normalizedPath(URL.documentsDirectory.appending(
            path: "Inbox", directoryHint: .isDirectory
        ))
        let temporary = normalizedPath(FileManager.default.temporaryDirectory)

        if candidate.hasPrefix(documentsInbox + "/") || candidate.hasPrefix(temporary + "/") {
            return true
        }
        // Der abschliessende Trenner ist entscheidend: ein Geschwister-Ordner
        // mit gleichem Praefix (`ShareInbox2/`) darf nicht mitgeloescht werden.
        guard let handoffInbox = inbox else { return false }
        return candidate.hasPrefix(normalizedPath(handoffInbox) + "/")
    }

    /// Vergleichbarer Pfad: Symlinks aufgeloest (`/var` → `/private/var`),
    /// `..`/`.` entfernt, kein abschliessender Trenner.
    private static func normalizedPath(_ url: URL) -> String {
        let path = url.resolvingSymlinksInPath().standardizedFileURL.path(percentEncoded: false)
        return path.count > 1 && path.hasSuffix("/") ? String(path.dropLast()) : path
    }

    // MARK: - Import

    /// Startet den Import und haelt den Zustand nach; Fehler enden in `.failed`.
    ///
    /// - Parameter handoffInbox: Uebergabeordner fuer die Loeschregel. Der
    ///   Vordergrund-Scan reicht **den** Ordner durch, den er gerade gelesen
    ///   hat — sonst entschiede ueber das Loeschen ein zweites Mal ausgewertetes
    ///   `inboxURL()` und die Regel waere im Test nicht nachweisbar.
    private func startImport(
        of fileURL: URL,
        modelContext: ModelContext,
        handoffInbox: URL? = ShareHandoffStore.inboxURL()
    ) {
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
                // Nur App-eigene Kopien entfernen — Erfolg wie Fehler.
                if Self.shouldRemoveAfterImport(fileURL, inbox: handoffInbox) {
                    try? FileManager.default.removeItem(at: fileURL)
                }
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

// MARK: - Vordergrund-Scan des Uebergabeordners (ADR-010, H3)

// Bewusst in derselben Datei: `startImport(of:modelContext:)` ist `private` und
// damit dateiprivat — eine Extension anderswo kaeme nicht heran, und die
// Sichtbarkeit dafuer zu oeffnen waere teurer als diese Naehe.
extension ShareImportCoordinator {

    /// Importiert hoechstens **eine** anstehende Uebergabedatei der
    /// Share-Extension — der einzige Import-Trigger fuer diesen Weg.
    ///
    /// Aufgerufen beim Wechsel in den Vordergrund, beim Szenenaufbau und nach
    /// dem Schliessen des Ergebnis-Sheets. Single-Flight (C10) bleibt streng:
    /// steht der Coordinator nicht auf `.idle` — laeuft also ein Import oder
    /// steht ein Ergebnis (`.finished`/`.failed`/`.linkHint`) auf dem Schirm —
    /// wird der Scan verworfen. Die naechste Datei kommt beim naechsten Anlauf
    /// dran; liegen bleiben kann sie hoechstens bis zur 24-h-Regel der
    /// Extension.
    ///
    /// Die importierte Datei wird anschliessend entfernt (Erfolg wie Fehler,
    /// `shouldRemoveAfterImport`) — sonst wuerde eine defekte Datei bei jedem
    /// Vordergrund-Wechsel erneut fehlschlagen.
    ///
    /// - Parameter inbox: Uebergabeordner; `nil` (kein App-Group-Container)
    ///   oder leer heisst: nichts tun. Zugleich die Test-Naht.
    func importPendingHandoffIfIdle(
        modelContext: ModelContext,
        inbox: URL? = ShareHandoffStore.inboxURL()
    ) {
        guard state == .idle else { return }
        guard let inbox else { return }
        guard let pending = ShareHandoffStore.pendingFiles(in: inbox).first else { return }

        startImport(of: pending, modelContext: modelContext, handoffInbox: inbox)
    }
}
