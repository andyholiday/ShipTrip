//
//  ShareImportFixtures.swift
//  ShipTripTests
//
//  Contract-Fixtures fuer den Share-Import (ADR-007, C1/C10): Export-DTOs, Envelope und
//  fertige `.shiptrip`-Dateien werden hier programmatisch erzeugt — unabhaengig von der
//  Export-Seite, damit die Import-Tests allein gegen den Vertrag laufen.
//

import Foundation
import SwiftData
@testable import ShipTrip

private typealias FixturePort = ShipTrip.Port

struct ShareFixtureError: Error {}

// MARK: - Container

/// Vollstaendiges Schema — der Import-Kern fasst auch Deals und das Katalog-Overlay an.
func makeShareImportContainer() throws -> ModelContainer {
    let schema = Schema([
        Cruise.self, FixturePort.self, Expense.self, Deal.self, Photo.self,
        CustomShippingLine.self, CustomShip.self, HiddenCatalogItem.self
    ])
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    return try ModelContainer(for: schema, configurations: config)
}

// MARK: - DTO-Fixtures

/// Eine plausible geteilte Kreuzfahrt. Die Zaehlparameter dienen den C10-Grenzwert-Tests.
/// `rawID` ueberschreibt die Kreuzfahrt-id woertlich — fuer manipulierte Dateien mit
/// ungueltiger UUID (C10-Invariante).
func makeShareCruise(
    id: UUID = UUID(),
    rawID: String? = nil,
    title: String = "Nordland-Route",
    portCount: Int = 2,
    portsWithImage: Int = 0,
    photoCount: Int = 0,
    expenseCount: Int = 0,
    notes: String? = nil
) -> ExportCruise {
    let cruiseID = rawID ?? id.uuidString

    let route = (0..<portCount).map { index in
        ExportPort(
            id: UUID().uuidString,
            name: "Hafen \(index)",
            country: "NO",
            lat: "60.39299000",
            lng: "5.32415000",
            arrival: "2026-05-0\((index % 9) + 1)T08:00:00",
            departure: "2026-05-0\((index % 9) + 1)T18:00:00",
            imageUrl: index < portsWithImage ? "images/\(cruiseID)/ports/\(index)" : nil,
            excursions: [],
            isSeaDay: false
        )
    }

    let photos = (0..<photoCount).map { index in
        ExportPhoto(id: UUID().uuidString, ref: "images/\(cruiseID)/\(index)")
    }

    let expenses = (0..<expenseCount).map { index in
        ExportExpense(
            id: UUID().uuidString,
            cruiseId: cruiseID,
            category: "onboard",
            description: "Posten \(index)",
            amount: 12.5,
            expenseDate: "2026-05-02",
            createdAt: "2026-05-02T10:00:00.000Z"
        )
    }

    return ExportCruise(
        id: cruiseID,
        title: title,
        startDate: "2026-05-01",
        endDate: "2026-05-09",
        shippingLine: "AIDA",
        ship: "AIDAsol",
        cabinType: "Balkon",
        cabinNumber: "8042",
        bookingNumber: nil,
        notes: notes,
        rating: 4.5,
        route: route,
        photos: photos,
        expenses: expenses
    )
}

/// Envelope mit `share`-Block. `formatVersion`/`shareFormatVersion` sind bewusst frei
/// setzbar, damit die Versionsmatrix aus C10 zellenweise pruefbar ist.
func makeShareArchive(
    cruises: [ExportCruise],
    formatVersion: Int = ExportArchive.currentFormatVersion,
    shareFormatVersion: Int = ExportShareInfo.currentShareFormatVersion,
    contentFingerprint: String = "0f1e2d3c4b5a69788796a5b4c3d2e1f00f1e2d3c4b5a69788796a5b4c3d2e1f0",
    deals: [ExportDeal] = [],
    customShippingLines: [ExportCustomShippingLine] = []
) -> ExportArchive {
    ExportArchive(
        formatVersion: formatVersion,
        cruises: cruises,
        deals: deals,
        customShippingLines: customShippingLines,
        share: ExportShareInfo(
            shareFormatVersion: shareFormatVersion,
            sharedAt: "2026-08-25T12:00:00.000Z",
            appVersion: "1.8.0",
            contentFingerprint: contentFingerprint
        )
    )
}

/// Envelope OHNE `share`-Block — ein gewoehnliches Backup (Backup-Semantik, C1).
func makeBackupArchive(cruises: [ExportCruise]) -> ExportArchive {
    ExportArchive(formatVersion: ExportArchive.currentFormatVersion, cruises: cruises)
}

func encodeArchiveJSON(_ archive: ExportArchive) throws -> Data {
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.sortedKeys]
    return try encoder.encode(archive)
}

// MARK: - Datei-Fixtures

/// Schreibt eine `.shiptrip`-Datei (ZIP, STORED) in einen frischen Temp-Ordner.
/// `extraEntries` erlaubt manipulierte Eintraege (z. B. Zip-Slip-Pfade).
func writeShareFile(
    archive: ExportArchive,
    extraEntries: [(name: String, data: Data)] = [],
    fileName: String = "reise.shiptrip"
) throws -> URL {
    try writeShareFile(dataJSON: try encodeArchiveJSON(archive),
                       extraEntries: extraEntries, fileName: fileName)
}

func writeShareFile(
    dataJSON: Data,
    extraEntries: [(name: String, data: Data)] = [],
    fileName: String = "reise.shiptrip"
) throws -> URL {
    let zipData = try ZipArchiveWriter.build(
        entries: [(name: "data.json", data: dataJSON)] + extraEntries
    )
    return try writeRawFile(zipData, fileName: fileName)
}

/// Schreibt beliebige Bytes als Datei — fuer defekte Archive.
func writeRawFile(_ data: Data, fileName: String = "reise.shiptrip") throws -> URL {
    let directory = FileManager.default.temporaryDirectory
        .appendingPathComponent("shiptrip-share-fixture-\(UUID().uuidString)")
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    let url = directory.appendingPathComponent(fileName)
    try data.write(to: url)
    return url
}
