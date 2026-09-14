//
//  ExportImportService+ShareImport.swift
//  ShipTrip
//
//  Share-Einstieg des Teilens (Contract C10): zweistufiges Ausfuehrungsmodell.
//  Stufe A (`SharePreflight.run`) ist eine synchrone, zustandslose Funktion ueber
//  `URL`/`Data`/Export-DTOs — kein `@Model`, kein `ModelContext`; der Aufrufer
//  fuehrt sie via `Task.detached` off-main aus. Stufe B mutiert synchron auf dem
//  MainActor ueber den **bestehenden** Import-Kern `importFromJSONData` (Dedup,
//  Validierung, Rollback inklusive) — hier entsteht kein zweiter Parser.
//

import Foundation
import SwiftData

// MARK: - Fehler

/// Ablehnungsgruende des Share-Preflights (C10). Sendable: Enum mit `String`-Payload.
enum ShareImportError: LocalizedError, Sendable {
    /// `share`-Block fehlt (am Share-Einstieg), `share`-Block mit unplausibler Version
    /// (`shareFormatVersion < 1` oder `formatVersion < 2`), mehr als 1 Kreuzfahrt oder
    /// nicht-leere Sammlungen (Invarianten C1 + Versionsmatrix C10). Auch ein defektes
    /// oder manipuliertes Archiv landet hier — es ist keine gueltige geteilte Reise.
    case notAShareFile
    /// `formatVersion > 2` oder `shareFormatVersion > 1` bei vorhandenem `share`-Block.
    case unsupportedVersion
    /// Eine `ShareArchiveLimits`-Grenze verletzt. `reason` ist eine interne Diagnose
    /// und erscheint nicht in der Oberflaeche.
    case limitExceeded(reason: String)

    var errorDescription: String? {
        switch self {
        case .notAShareFile:
            return String(localized: "Diese Datei ist keine gültige geteilte Reise.")
        case .unsupportedVersion:
            return String(localized: "Diese Datei benötigt eine neuere Version von ShipTrip.")
        case .limitExceeded:
            return String(localized: "Die Datei überschreitet die Grenzen für geteilte Reisen.")
        }
    }
}

// MARK: - Ergebnis des Share-Einstiegs

/// Bestehendes `ImportResult` + Konflikt-Signal (C1-Fingerabdruck).
struct ShareImportResult {
    let base: ImportResult
    /// `true` = Kreuzfahrt-id existiert bereits UND an der lokalen Kreuzfahrt ist ein
    /// `shareContentFingerprint` persistiert, der vom `share.contentFingerprint` der Datei
    /// abweicht (Senderfassung ≠ damals empfangene Fassung, C1). Kein persistierter Wert
    /// (nie share-importiert) ⇒ `false` — dann nur „bereits vorhanden".
    let versionConflict: Bool
}

// MARK: - Stufe A: Preflight (zustandslos, off-main aufrufbar)

/// Uebergabetyp ueber die Aktorgrenze — nur Wertetypen.
struct SharePreflightResult: Sendable {
    /// Bytes der `data.json` aus dem Archiv.
    let dataJSON: Data
    /// Wurzel der entpackten Arbeitskopie; zugleich Basis der Bildpfade.
    /// Der Aufrufer loescht dieses Verzeichnis nach Abschluss (Erfolg wie Fehler).
    let imagesDir: URL
    /// Bereits dekodierter Envelope — Grundlage von Versionsmatrix und Konfliktpruefung.
    let envelope: ExportArchive
}

enum SharePreflight {

    // MARK: Transport-Preflight (Stufe A, nur Share-Einstieg)

    /// Schritte 1–7 der C10-Reihenfolge. Wirft vor jeder Datenbank-Beruehrung.
    ///
    /// Bewusste Verengung gegenueber dem manuellen Backup-Import: `data.json` muss in der
    /// Archiv-Wurzel liegen. Geteilte Reisen sind maschinenerzeugt (C1) und legen sie dort
    /// ab; ein verschachteltes Archiv ist am Share-Einstieg keine gueltige geteilte Reise.
    /// Der manuelle Import bleibt unveraendert tolerant.
    static func run(_ url: URL) throws(ShareImportError) -> SharePreflightResult {
        // 1. Dateigroesse (Stat, vor Extraktion)
        guard let fileSize = Self.fileSize(at: url) else { throw ShareImportError.notAShareFile }
        guard fileSize <= ShareArchiveLimits.maxArchiveFileSize else {
            throw ShareImportError.limitExceeded(reason: "archiveFileSize=\(fileSize)")
        }

        let workingDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("shiptrip-share-import-\(UUID().uuidString)")

        do {
            return try Self.extractAndValidate(url, into: workingDirectory)
        } catch {
            // Arbeitskopie auch im Fehlerfall nicht liegen lassen.
            try? FileManager.default.removeItem(at: workingDirectory)
            throw error
        }
    }

    private static func extractAndValidate(
        _ url: URL,
        into workingDirectory: URL
    ) throws(ShareImportError) -> SharePreflightResult {
        // 2. Extraktion ueber den bestehenden ZipArchiveReader (Zip-Slip, CRC, Entry-Limit)
        do {
            try FileManager.default.createDirectory(
                at: workingDirectory, withIntermediateDirectories: true
            )
            try ZipArchiveReader.extract(from: url, to: workingDirectory)
        } catch let error as ExportImportService.ImportError {
            throw Self.mapped(error)
        } catch {
            throw ShareImportError.notAShareFile
        }

        // 3. Summe der entpackten Eintraege
        let payloadSize = Self.payloadSize(of: workingDirectory)
        guard payloadSize <= ShareArchiveLimits.maxPayloadSize else {
            throw ShareImportError.limitExceeded(reason: "payloadSize=\(payloadSize)")
        }

        // 4. data.json-Deckel, erst dann JSONDecoder
        let dataJSONPath = workingDirectory.appendingPathComponent("data.json")
        guard let dataJSONSize = Self.fileSize(at: dataJSONPath) else {
            throw ShareImportError.notAShareFile
        }
        guard dataJSONSize <= ShareArchiveLimits.maxDataJSONSize else {
            throw ShareImportError.limitExceeded(reason: "dataJSONSize=\(dataJSONSize)")
        }
        guard let dataJSON = try? Data(contentsOf: dataJSONPath),
              let envelope = try? ExportArchive.decode(from: dataJSON) else {
            throw ShareImportError.notAShareFile
        }

        // 5.–7. Archiv-Preflight. Am Share-Einstieg ist der share-Block Pflicht:
        // ein Backup-Archiv wuerde hier sonst massenimportiert (C10-Versionsmatrix,
        // Zeile „share fehlt").
        guard envelope.share != nil else { throw ShareImportError.notAShareFile }
        try Self.validateArchive(envelope)

        return SharePreflightResult(
            dataJSON: dataJSON, imagesDir: workingDirectory, envelope: envelope
        )
    }

    // MARK: Archiv-Preflight (bindet an den share-Block, gilt in JEDEM Pfad)

    /// Versionsmatrix, Invarianten und Zaehlgrenzen eines Archivs (C10, Schritte 5–7).
    ///
    /// Archiv-gebunden statt pfad-gebunden: Ohne `share`-Block behaelt die Datei
    /// unveraendert Backup-Semantik und die Funktion tut nichts. Mit `share`-Block gilt
    /// die Share-Invariante — egal ob die Datei ueber `onOpenURL`, den manuellen
    /// `fileImporter` oder den Legacy-JSON-Import hereinkommt. Der Import-Kern
    /// `importFromJSONData` ruft sie genau einmal, vor jeder Mutation.
    static func validateArchive(_ archive: ExportArchive) throws(ShareImportError) {
        guard let share = archive.share else { return }

        // Versionsmatrix als Totalfunktion ueber (formatVersion, shareFormatVersion).
        guard archive.formatVersion == ExportArchive.currentFormatVersion else {
            // > 2: neuere Huelle, wir koennen sie nicht deuten.
            // < 2: `share` existiert erst ab Envelope 2 — nur manipuliert erreichbar.
            throw archive.formatVersion > ExportArchive.currentFormatVersion
                ? ShareImportError.unsupportedVersion
                : ShareImportError.notAShareFile
        }
        guard share.shareFormatVersion == ExportShareInfo.currentShareFormatVersion else {
            // < 1: unterhalb von v1 existiert kein legitimer Wert — „neuere Version
            // noetig" waere gelogen, deshalb bewusst `notAShareFile`.
            throw share.shareFormatVersion > ExportShareInfo.currentShareFormatVersion
                ? ShareImportError.unsupportedVersion
                : ShareImportError.notAShareFile
        }

        // Invarianten: genau 1 Kreuzfahrt, keine Nebensammlungen (verhindert Massenimport).
        guard archive.cruises.count == 1, let cruise = archive.cruises.first else {
            throw ShareImportError.notAShareFile
        }
        // Eine gueltige Kreuzfahrt-UUID ist Teil der Invariante: ohne sie greifen weder
        // Fingerabdruck-Persistenz noch Konflikterkennung (beide arbeiten ueber die id).
        // Die Schreibseite erzeugt immer eine — fehlt sie, ist die Datei manipuliert.
        guard UUID(uuidString: cruise.id) != nil else {
            throw ShareImportError.notAShareFile
        }
        guard archive.deals.isEmpty,
              archive.customShippingLines.isEmpty,
              archive.customShips.isEmpty,
              archive.hiddenCatalogItems.isEmpty else {
            throw ShareImportError.notAShareFile
        }

        // Zaehlgrenzen der einen Kreuzfahrt.
        guard cruise.route.count <= ShareArchiveLimits.maxPorts else {
            throw ShareImportError.limitExceeded(reason: "ports=\(cruise.route.count)")
        }
        let imageCount = cruise.photos.count + cruise.route.filter { $0.imageUrl != nil }.count
        guard imageCount <= ShareArchiveLimits.maxPhotos else {
            throw ShareImportError.limitExceeded(reason: "photos=\(imageCount)")
        }
        guard cruise.expenses.count <= ShareArchiveLimits.maxExpenses else {
            throw ShareImportError.limitExceeded(reason: "expenses=\(cruise.expenses.count)")
        }
        // Ohne diesen Deckel waere die Journal-Sammlung die einzige unbegrenzte Kollektion
        // aus einer Fremddatei (ADR-003, T7b-Contract).
        let journalCount = (cruise.journalEntries ?? []).count
        guard journalCount <= ShareArchiveLimits.maxJournalEntries else {
            throw ShareImportError.limitExceeded(reason: "journalEntries=\(journalCount)")
        }
    }

    // MARK: Helfer

    /// ZIP-Fehler des Bestands-Readers auf die drei Share-Gruende abbilden: Groessen-
    /// verletzungen bleiben Groessenverletzungen, alles andere (Zip-Slip, CRC, defekte
    /// Struktur) ist schlicht keine gueltige geteilte Reise.
    private static func mapped(_ error: ExportImportService.ImportError) -> ShareImportError {
        switch error {
        case .entryTooLarge(let name, let size):
            return .limitExceeded(reason: "entry=\(name) size=\(size)")
        case .archiveTooLarge(let size):
            return .limitExceeded(reason: "archiveUncompressed=\(size)")
        default:
            return .notAShareFile
        }
    }

    private static func fileSize(at url: URL) -> Int? {
        let values = try? url.resourceValues(forKeys: [.fileSizeKey])
        return values?.fileSize
    }

    /// Summe der Dateigroessen unterhalb von `directory` (rekursiv).
    private static func payloadSize(of directory: URL) -> Int {
        guard let enumerator = FileManager.default.enumerator(
            at: directory,
            includingPropertiesForKeys: [.fileSizeKey, .isRegularFileKey]
        ) else { return 0 }

        var total = 0
        for case let url as URL in enumerator {
            let values = try? url.resourceValues(forKeys: [.fileSizeKey, .isRegularFileKey])
            guard values?.isRegularFile == true, let size = values?.fileSize else { continue }
            total += size
        }
        return total
    }
}

// MARK: - Stufe B: Mutation auf dem MainActor

extension ExportImportService {

    /// Automatischer Share-Einstieg: Preflight off-main, Mutation auf dem MainActor.
    ///
    /// `@Model`/`ModelContext` ueberqueren nie eine Aktorgrenze — ueber die Grenze wandern
    /// nur `URL` und `SharePreflightResult`. Die entpackte Arbeitskopie wird in jedem Fall
    /// wieder geloescht; die eingehende Datei selbst gehoert dem Aufrufer.
    func importSharedCruise(
        from url: URL, modelContext: ModelContext
    ) async throws -> ShareImportResult {
        // Stufe A — der Off-Main-Transfer ist explizit; `nonisolated` allein garantiert
        // keinen Off-Main-Executor.
        let preflight = try await Task.detached(priority: .userInitiated) {
            try SharePreflight.run(url)
        }.value

        // Fortsetzung wieder auf dem MainActor (diese Methode ist MainActor-isoliert).
        defer { try? FileManager.default.removeItem(at: preflight.imagesDir) }

        let fileFingerprint = preflight.envelope.share?.contentFingerprint
        let sharedCruiseID = preflight.envelope.cruises.first.flatMap { UUID(uuidString: $0.id) }

        // Konflikt VOR der Mutation bestimmen — danach existiert die Kreuzfahrt immer.
        // Verglichen werden ausschliesslich gespeicherte Werte, es wird nichts neu berechnet.
        let versionConflict: Bool
        if let sharedCruiseID,
           let existing = existingCruise(id: sharedCruiseID, modelContext: modelContext),
           let storedFingerprint = existing.shareContentFingerprint {
            versionConflict = storedFingerprint != fileFingerprint
        } else {
            versionConflict = false
        }

        // Stufe B: der bestehende Import-Kern (Dedup, Validierung, Rollback). Er
        // persistiert den Fingerabdruck selbst — im selben atomaren Save wie die Reise
        // und damit in jedem Einstiegspfad gleich (C1).
        let base = try importFromJSONData(
            data: preflight.dataJSON, imagesDir: preflight.imagesDir, modelContext: modelContext
        )

        return ShareImportResult(base: base, versionConflict: versionConflict)
    }

    private func existingCruise(id: UUID, modelContext: ModelContext) -> Cruise? {
        var descriptor = FetchDescriptor<Cruise>(predicate: #Predicate { $0.id == id })
        descriptor.fetchLimit = 1
        return (try? modelContext.fetch(descriptor))?.first
    }
}
