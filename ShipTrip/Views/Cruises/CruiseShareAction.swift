//
//  CruiseShareAction.swift
//  ShipTrip
//
//  Teilen-Aktion der Reise-Detailansicht (Contract C7): erzeugt die `.shiptrip`-Datei über
//  `exportCruiseForSharing` (C5) und übergibt sie zusammen mit dem Nachrichtentext (C8) an
//  das System-Share-Sheet. Liegt bewusst neben `CruiseDetailView`, damit die Detailansicht
//  nur den Menüeintrag und einen Modifier dazubekommt.
//

import SwiftUI

// MARK: - Zustand der Teilen-Aktion

/// Hält den Ablauf „Datei bauen → Share-Sheet → aufräumen" für genau eine Reise.
///
/// Eigener Typ statt `@State` in `CruiseDetailView`, weil der auslösende Button im Toolbar-Menü
/// sitzt, die Präsentation (Sheet/Alert) aber an der Detailansicht hängen muss.
@MainActor
@Observable
final class CruiseShareModel {

    /// Fertige `.shiptrip`-Datei. Gesetzt heißt: Share-Sheet zeigen.
    struct ShareItem: Identifiable {
        let id = UUID()
        let url: URL
    }

    var shareItem: ShareItem?
    /// Läuft der Export gerade? Sperrt den Menüeintrag gegen Doppel-Tap.
    private(set) var isPreparing = false
    var isShowingError = false
    private(set) var errorMessage = ""

    /// Baut die Datei und öffnet danach das Share-Sheet. Fehler landen im Alert, nie als Crash.
    func share(_ cruise: Cruise) {
        guard !isPreparing, shareItem == nil else { return }
        isPreparing = true

        Task {
            defer { isPreparing = false }
            do {
                let url = try await ExportImportService.shared.exportCruiseForSharing(cruise)
                shareItem = ShareItem(url: url)
            } catch {
                errorMessage = String(
                    localized: "Teilen fehlgeschlagen: \(Self.shareFailureReason(for: error))"
                )
                isShowingError = true
            }
        }
    }

    /// Wird aufgerufen, wenn die Share-Präsentation abgeschlossen ist (auch bei Abbruch).
    ///
    /// Gelöscht wird der **Elternordner**, nicht nur die Datei: `exportCruiseForSharing` legt für
    /// jeden Export einen frischen Temp-Unterordner an (C5), damit der Anzeigename im Share-Sheet
    /// stimmt. Nur die Datei zu entfernen ließe den leeren Ordner zurück.
    func finish() {
        guard let item = shareItem else { return }
        try? FileManager.default.removeItem(at: item.url.deletingLastPathComponent())
        shareItem = nil
    }

    /// Der Nachrichtentext, der zusammen mit der Datei verschickt wird (C8).
    ///
    /// Der `shiptrip://import`-Link ist die Beigabe, die Datei der Träger (C3): Ein Tipp auf den
    /// Link öffnet nur die App und zeigt den Hinweis, die angehängte Datei zu öffnen. Der Satz
    /// nennt bewusst, dass die komplette Reise mitgeht — geteilt wird ohne Rückfrage alles.
    static var shareMessage: String {
        String(
            localized: """
            Ich habe dir eine Kreuzfahrt aus ShipTrip geschickt — komplett mit Route, Ausgaben \
            und Fotos. Öffne die angehängte .shiptrip-Datei, um sie zu übernehmen: shiptrip://import
            """
        )
    }

    /// Übersetzt den geworfenen Fehler in den Text, der in „Teilen fehlgeschlagen: %@" landet.
    ///
    /// `ExportError` stammt aus dem geteilten Backup-Pfad und formuliert seine Texte als
    /// „Backup abgebrochen: …" — im Teilen-Kontext wäre das irreführend. Aus dem Share-Export
    /// erreichbar ist davon genau `missingMedia` (die Roh-Bytes eines referenzierten Bildes
    /// fehlen); der Fall wird auf die inhaltsgleiche Share-Formulierung abgebildet.
    static func shareFailureReason(for error: Error) -> String {
        if case ExportError.missingMedia(let entryName) = error {
            return ShareExportError.transcodeFailed(entryName: entryName).localizedDescription
        }
        return error.localizedDescription
    }
}

// MARK: - Präsentation

extension View {
    /// Hängt Share-Sheet und Fehler-Alert der Teilen-Aktion an die Ansicht.
    func cruiseSharePresentation(_ model: CruiseShareModel) -> some View {
        modifier(CruiseSharePresentation(model: model))
    }
}

private struct CruiseSharePresentation: ViewModifier {
    @Bindable var model: CruiseShareModel

    func body(content: Content) -> some View {
        content
            .sheet(item: $model.shareItem) { item in
                // Datei + Text gemeinsam: In Nachrichten/WhatsApp/Mail landet der Anhang samt
                // Begleittext, der den Import-Link trägt (C7).
                ShareSheet(items: [item.url, CruiseShareModel.shareMessage]) {
                    model.finish()
                }
            }
            .alert("Info", isPresented: $model.isShowingError) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(model.errorMessage)
            }
    }
}
