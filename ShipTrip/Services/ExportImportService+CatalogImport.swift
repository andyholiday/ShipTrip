//
//  ExportImportService+CatalogImport.swift
//  ShipTrip
//
//  Import von Wunschreisen und Katalog-Overlay (eigene Reedereien/Schiffe, Ausblendungen,
//  ADR-006). Ab Formatversion 2; 1.7-Dateien enthalten diese Sammlungen nicht.
//

import Foundation
import SwiftData


extension ExportImportService {

    // MARK: - Import: Wunschreisen & Katalog-Overlay

    /// Importiert Wunschreisen. Dedup über die stabile `Deal.id` (ADR-002); Einträge ohne
    /// gültige UUID werden übersprungen, weil ohne stabile ID kein idempotenter Re-Import
    /// möglich ist. Der `guard` am Anfang ist bewusst: 1.7-Dateien enthalten keine Deals und
    /// lösen so auch keinen `Deal`-Fetch aus.
    func importDeals(_ exportDeals: [ExportDeal], modelContext: ModelContext) {
        guard !exportDeals.isEmpty else { return }
        let existing = (try? modelContext.fetch(FetchDescriptor<Deal>())) ?? []
        var knownIDs = Set(existing.map(\.id))

        for exportDeal in exportDeals {
            guard let id = UUID(uuidString: exportDeal.id), !knownIDs.contains(id) else { continue }

            let deal = Deal(title: exportDeal.title)
            deal.id = id
            deal.shippingLine = exportDeal.shippingLine
            deal.ship = exportDeal.ship
            deal.destination = exportDeal.destination
            deal.price = exportDeal.price
            deal.originalPrice = exportDeal.originalPrice
            deal.url = exportDeal.url
            deal.notes = exportDeal.notes
            deal.startDate = exportDeal.startDate.flatMap { dateFormatter.date(from: $0) }
            deal.endDate = exportDeal.endDate.flatMap { dateFormatter.date(from: $0) }
            if let createdAt = exportDeal.createdAt.flatMap({ isoFormatter.date(from: $0) }) {
                deal.createdAt = createdAt
            }
            if let updatedAt = exportDeal.updatedAt.flatMap({ isoFormatter.date(from: $0) }) {
                deal.updatedAt = updatedAt
            }
            modelContext.insert(deal)
            knownIDs.insert(id)
        }
    }

    /// Importiert das Katalog-Overlay (ADR-006). Die Reihenfolge ist Teil des Vertrags: eigene
    /// Schiffe referenzieren ihre eigene Reederei über `lineOptionID == "custom:<UUID>"`, die
    /// Reederei muss also zuerst angelegt sein.
    func importCatalogOverlay(_ archive: ExportArchive, modelContext: ModelContext) {
        let importedLineOptionIDs = importCustomLines(archive.customShippingLines, modelContext: modelContext)
        importCustomShips(
            archive.customShips,
            importedLineOptionIDs: importedLineOptionIDs,
            modelContext: modelContext
        )
        importHiddenCatalogItems(archive.hiddenCatalogItems, modelContext: modelContext)
    }

    /// - Returns: die `lineOptionID`s (`"custom:<UUID>"`) aller nach diesem Aufruf vorhandenen
    ///   eigenen Reedereien — bestehende plus neu importierte.
    private func importCustomLines(
        _ exportLines: [ExportCustomShippingLine],
        modelContext: ModelContext
    ) -> Set<String> {
        guard !exportLines.isEmpty else { return [] }
        let existing = (try? modelContext.fetch(FetchDescriptor<CustomShippingLine>())) ?? []
        var knownIDs = Set(existing.map(\.id))

        for exportLine in exportLines {
            guard let id = UUID(uuidString: exportLine.id), !knownIDs.contains(id) else { continue }

            let line = CustomShippingLine(name: exportLine.name, logo: exportLine.logo ?? "🚢")
            // Die UUID MUSS übernommen werden: eigene Schiffe referenzieren sie als
            // "custom:<UUID>". Eine frische UUID würde die Schiffe verwaisen lassen.
            line.id = id
            if let createdAt = exportLine.createdAt.flatMap({ isoFormatter.date(from: $0) }) {
                line.createdAt = createdAt
            }
            if let updatedAt = exportLine.updatedAt.flatMap({ isoFormatter.date(from: $0) }) {
                line.updatedAt = updatedAt
            }
            modelContext.insert(line)
            knownIDs.insert(id)
        }

        return Set(knownIDs.map { "\(Self.customLinePrefix)\($0.uuidString)" })
    }

    private func importCustomShips(
        _ exportShips: [ExportCustomShip],
        importedLineOptionIDs: Set<String>,
        modelContext: ModelContext
    ) {
        guard !exportShips.isEmpty else { return }
        let existing = (try? modelContext.fetch(FetchDescriptor<CustomShip>())) ?? []
        var knownIDs = Set(existing.map(\.id))

        var knownLineOptionIDs = importedLineOptionIDs
        let existingLines = (try? modelContext.fetch(FetchDescriptor<CustomShippingLine>())) ?? []
        knownLineOptionIDs.formUnion(existingLines.map { "\(Self.customLinePrefix)\($0.id.uuidString)" })

        for exportShip in exportShips {
            guard let id = UUID(uuidString: exportShip.id), !knownIDs.contains(id) else { continue }
            // Keine verwaisten Schiffe: zeigt die lineOptionID auf eine eigene Reederei, muss
            // diese vorhanden sein (aus derselben Datei oder aus dem Bestand). Katalog-Reedereien
            // sind hartkodiert und damit immer auflösbar.
            if exportShip.lineOptionID.hasPrefix(Self.customLinePrefix),
               !knownLineOptionIDs.contains(exportShip.lineOptionID) {
                continue
            }

            let ship = CustomShip(name: exportShip.name, lineOptionID: exportShip.lineOptionID)
            ship.id = id
            if let createdAt = exportShip.createdAt.flatMap({ isoFormatter.date(from: $0) }) {
                ship.createdAt = createdAt
            }
            if let updatedAt = exportShip.updatedAt.flatMap({ isoFormatter.date(from: $0) }) {
                ship.updatedAt = updatedAt
            }
            modelContext.insert(ship)
            knownIDs.insert(id)
        }
    }

    private func importHiddenCatalogItems(
        _ exportItems: [ExportHiddenCatalogItem],
        modelContext: ModelContext
    ) {
        guard !exportItems.isEmpty else { return }
        let existing = (try? modelContext.fetch(FetchDescriptor<HiddenCatalogItem>())) ?? []
        var knownIDs = Set(existing.map(\.id))
        // Zusätzlich zum ID-Dedup ein semantischer Schlüssel: dieselbe Ausblendung darf nicht
        // doppelt entstehen, auch wenn sie auf zwei Geräten mit verschiedenen ids angelegt wurde.
        var knownKeys = Set(existing.map { "\($0.lineID)|\($0.shipKey ?? "")" })

        for exportItem in exportItems {
            let key = "\(exportItem.lineID)|\(exportItem.shipKey ?? "")"
            guard let id = UUID(uuidString: exportItem.id),
                  !knownIDs.contains(id), !knownKeys.contains(key) else { continue }

            let item = HiddenCatalogItem(lineID: exportItem.lineID, shipKey: exportItem.shipKey)
            item.id = id
            if let createdAt = exportItem.createdAt.flatMap({ isoFormatter.date(from: $0) }) {
                item.createdAt = createdAt
            }
            modelContext.insert(item)
            knownIDs.insert(id)
            knownKeys.insert(key)
        }
    }

    /// Präfix einer `lineOptionID`, die auf eine eigene (nicht Katalog-) Reederei zeigt.
    private static let customLinePrefix = "custom:"
}
