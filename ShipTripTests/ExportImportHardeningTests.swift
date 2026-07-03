//
//  ExportImportHardeningTests.swift
//  ShipTripTests
//
//  Härtungs-Tests für ExportImportService: Zip-Slip-Schutz, Dekompressionsbomben-Limit,
//  ID-Duplikate innerhalb derselben Import-Datei, Port-Bild-Roundtrip im ZIP-Export.
//

import Testing
import Foundation
import SwiftData
@testable import ShipTrip

private typealias CruisePort = ShipTrip.Port

// MARK: - Fixture-Helfer

private func makeDate(_ string: String) -> Date {
    let df = DateFormatter()
    df.dateFormat = "yyyy-MM-dd"
    df.timeZone = TimeZone(identifier: "UTC")
    return df.date(from: string)!
}

private func makeInMemoryContainer() throws -> ModelContainer {
    let schema = Schema([Cruise.self, CruisePort.self, Expense.self, Deal.self, Photo.self])
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    return try ModelContainer(for: schema, configurations: config)
}

// MARK: - Roh-ZIP-Builder für Angriffsszenarien

/// Ein einzelner Test-ZIP-Eintrag. `declaredUncompressedSize`/`declaredCompressedSize` dürfen vom
/// tatsächlichen `data.count` abweichen, um lügende Header zu simulieren (Bomben-/Mismatch-Tests).
private struct TestZipEntry {
    let name: String
    let data: Data
    var declaredUncompressedSize: Int?
    var declaredCompressedSize: Int?

    init(name: String, data: Data, declaredUncompressedSize: Int? = nil, declaredCompressedSize: Int? = nil) {
        self.name = name
        self.data = data
        self.declaredUncompressedSize = declaredUncompressedSize
        self.declaredCompressedSize = declaredCompressedSize
    }
}

/// Minimaler ZIP-Builder für Tests (Compression Method 0 / STORED), unabhängig von der
/// privaten `buildZip`-Implementierung in ExportImportService. Erlaubt bewusst manipulierte
/// Eintragsnamen (Zip-Slip) sowie Header, deren deklarierte Größen vom tatsächlichen
/// `data.count` abweichen (Dekompressionsbomben-/Mismatch-Tests).
/// CRC-32 wird nicht korrekt berechnet (0), da `parseAndExtractZip` die CRC nicht prüft.
private func buildTestZip(entries: [TestZipEntry]) -> Data {
    struct Meta {
        let nameData: Data
        let actualSize: UInt32
        let declaredUncompressedSize: UInt32
        let declaredCompressedSize: UInt32
        let localOffset: UInt32
    }

    var archive = Data()
    var metas: [Meta] = []

    for entry in entries {
        let nameData = Data(entry.name.utf8)
        let actualSize = UInt32(entry.data.count)
        let declaredUncompressedSize = UInt32(entry.declaredUncompressedSize ?? entry.data.count)
        let declaredCompressedSize = UInt32(entry.declaredCompressedSize ?? entry.data.count)
        let localOffset = UInt32(archive.count)
        metas.append(Meta(
            nameData: nameData,
            actualSize: actualSize,
            declaredUncompressedSize: declaredUncompressedSize,
            declaredCompressedSize: declaredCompressedSize,
            localOffset: localOffset
        ))

        archive.append(contentsOf: [0x50, 0x4B, 0x03, 0x04]) // Local File Header Signatur
        archive.appendUInt16LE(20)  // Version needed
        archive.appendUInt16LE(0)   // Bit flag
        archive.appendUInt16LE(0)   // Compression: STORED
        archive.appendUInt16LE(0)   // Mod time
        archive.appendUInt16LE(0)   // Mod date
        archive.appendUInt32LE(0)   // CRC-32 (ungeprüft vom Parser)
        archive.appendUInt32LE(actualSize) // Compressed size (lokal; wird vom Parser nicht gelesen)
        archive.appendUInt32LE(actualSize) // Uncompressed size (lokal; wird vom Parser nicht gelesen)
        archive.appendUInt16LE(UInt16(nameData.count))
        archive.appendUInt16LE(0)   // Extra field length
        archive.append(nameData)
        archive.append(entry.data) // tatsächliche Bytes — die Extraktion liest exakt `actualSize` Bytes ab hier
    }

    let centralDirOffset = UInt32(archive.count)
    for meta in metas {
        archive.append(contentsOf: [0x50, 0x4B, 0x01, 0x02]) // Central Directory Signatur
        archive.appendUInt16LE(20)  // Version made by
        archive.appendUInt16LE(20)  // Version needed
        archive.appendUInt16LE(0)   // Bit flag
        archive.appendUInt16LE(0)   // Compression: STORED
        archive.appendUInt16LE(0)   // Mod time
        archive.appendUInt16LE(0)   // Mod date
        archive.appendUInt32LE(0)   // CRC-32
        archive.appendUInt32LE(meta.declaredCompressedSize)   // Compressed size — DAS liest der Größen-Limit-Check
        archive.appendUInt32LE(meta.declaredUncompressedSize) // Uncompressed size — DAS liest der Größen-Limit-Check
        archive.appendUInt16LE(UInt16(meta.nameData.count))
        archive.appendUInt16LE(0)   // Extra field length
        archive.appendUInt16LE(0)   // Comment length
        archive.appendUInt16LE(0)   // Disk number start
        archive.appendUInt16LE(0)   // Internal attributes
        archive.appendUInt32LE(0)   // External attributes
        archive.appendUInt32LE(meta.localOffset)
        archive.append(meta.nameData)
    }
    let centralDirSize = UInt32(archive.count) - centralDirOffset

    archive.append(contentsOf: [0x50, 0x4B, 0x05, 0x06]) // EOCD Signatur
    archive.appendUInt16LE(0)
    archive.appendUInt16LE(0)
    archive.appendUInt16LE(UInt16(entries.count))
    archive.appendUInt16LE(UInt16(entries.count))
    archive.appendUInt32LE(centralDirSize)
    archive.appendUInt32LE(centralDirOffset)
    archive.appendUInt16LE(0)

    return archive
}

/// Liest einen benannten Eintrag direkt aus einem STORED-ZIP (wie von `exportToZip` erzeugt), ohne
/// die private App-Extraktionslogik zu verwenden. Nur für Testverifikation der DTO-Inhalte gedacht.
private func extractZipEntry(named targetName: String, from zipData: Data) -> Data? {
    guard zipData.count > 22 else { return nil }

    var eocdOffset: Int?
    for i in stride(from: zipData.count - 22, through: Swift.max(0, zipData.count - 65557), by: -1) {
        if zipData[i] == 0x50 && zipData[i+1] == 0x4B && zipData[i+2] == 0x05 && zipData[i+3] == 0x06 {
            eocdOffset = i
            break
        }
    }
    guard let eocd = eocdOffset else { return nil }

    let cdOffset = Int(zipData[eocd + 16]) | (Int(zipData[eocd + 17]) << 8) | (Int(zipData[eocd + 18]) << 16) | (Int(zipData[eocd + 19]) << 24)
    let numEntries = Int(zipData[eocd + 10]) | (Int(zipData[eocd + 11]) << 8)

    var offset = cdOffset
    for _ in 0..<numEntries {
        guard offset + 46 <= zipData.count else { break }
        guard zipData[offset] == 0x50 && zipData[offset+1] == 0x4B && zipData[offset+2] == 0x01 && zipData[offset+3] == 0x02 else { break }

        let compressedSize = Int(zipData[offset + 20]) | (Int(zipData[offset + 21]) << 8) | (Int(zipData[offset + 22]) << 16) | (Int(zipData[offset + 23]) << 24)
        let nameLength = Int(zipData[offset + 28]) | (Int(zipData[offset + 29]) << 8)
        let extraLength = Int(zipData[offset + 30]) | (Int(zipData[offset + 31]) << 8)
        let commentLength = Int(zipData[offset + 32]) | (Int(zipData[offset + 33]) << 8)
        let localHeaderOffset = Int(zipData[offset + 42]) | (Int(zipData[offset + 43]) << 8) | (Int(zipData[offset + 44]) << 16) | (Int(zipData[offset + 45]) << 24)

        guard offset + 46 + nameLength <= zipData.count else { break }
        let name = String(data: zipData[offset + 46 ..< offset + 46 + nameLength], encoding: .utf8) ?? ""

        if name == targetName {
            guard localHeaderOffset + 30 <= zipData.count else { return nil }
            let localNameLength = Int(zipData[localHeaderOffset + 26]) | (Int(zipData[localHeaderOffset + 27]) << 8)
            let localExtraLength = Int(zipData[localHeaderOffset + 28]) | (Int(zipData[localHeaderOffset + 29]) << 8)
            let dataOffset = localHeaderOffset + 30 + localNameLength + localExtraLength
            guard dataOffset + compressedSize <= zipData.count else { return nil }
            return Data(zipData[dataOffset ..< dataOffset + compressedSize])
        }

        offset += 46 + nameLength + extraLength + commentLength
    }
    return nil
}

private extension Data {
    mutating func appendUInt16LE(_ value: UInt16) {
        append(UInt8(value & 0xFF))
        append(UInt8((value >> 8) & 0xFF))
    }

    mutating func appendUInt32LE(_ value: UInt32) {
        append(UInt8(value & 0xFF))
        append(UInt8((value >> 8) & 0xFF))
        append(UInt8((value >> 16) & 0xFF))
        append(UInt8((value >> 24) & 0xFF))
    }
}

// MARK: - Zip-Slip-Schutz

@Suite("Import-Härtung: Zip-Slip-Schutz")
struct ZipSlipHardeningTests {

    @Test("ZIP-Eintrag mit ../-Traversal wird abgelehnt, nichts wird außerhalb des Zielordners geschrieben")
    @MainActor
    func pathTraversalEntryIsRejectedAndNothingEscapes() throws {
        let maliciousZip = buildTestZip(entries: [
            TestZipEntry(name: "../evil.txt", data: Data("pwned".utf8))
        ])

        let zipURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("ziptest-\(UUID().uuidString).zip")
        try maliciousZip.write(to: zipURL)
        defer { try? FileManager.default.removeItem(at: zipURL) }

        // Ziel, das der ../-Eintrag relativ zum (frisch generierten) Import-Tempordner treffen würde.
        let escapedFile = FileManager.default.temporaryDirectory.appendingPathComponent("evil.txt")
        try? FileManager.default.removeItem(at: escapedFile)

        let container = try makeInMemoryContainer()
        let context = container.mainContext

        #expect(throws: (any Error).self) {
            try ExportImportService.shared.importFromZip(url: zipURL, modelContext: context)
        }

        #expect(
            !FileManager.default.fileExists(atPath: escapedFile.path),
            "Zip-Slip-Eintrag darf niemals außerhalb des Zielordners geschrieben werden"
        )

        try? FileManager.default.removeItem(at: escapedFile)
    }

    @Test(
        "Verschiedene Pfad-Traversal-Varianten werden als ZIP-Eintrag abgelehnt",
        arguments: [
            "/etc/passwd",           // absoluter Pfad
            "./evil.txt",            // "./"-Präfix
            "a/../../evil.txt",      // a/../b-Traversal
            "a//evil.txt",           // leere Komponente (Doppel-Slash)
            "a\\..\\evil.txt"        // Backslash
        ]
    )
    @MainActor
    func variousTraversalVariantsAreRejected(maliciousName: String) throws {
        let maliciousZip = buildTestZip(entries: [
            TestZipEntry(name: maliciousName, data: Data("pwned".utf8))
        ])

        let zipURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("traversal-\(UUID().uuidString).zip")
        try maliciousZip.write(to: zipURL)
        defer { try? FileManager.default.removeItem(at: zipURL) }

        let container = try makeInMemoryContainer()
        let context = container.mainContext

        #expect(throws: (any Error).self) {
            try ExportImportService.shared.importFromZip(url: zipURL, modelContext: context)
        }
    }

    @Test("Bösartige imageUrl in data.json wird abgelehnt; Cruise wird trotzdem importiert, Bild fehlt")
    @MainActor
    func maliciousPortImageUrlIsSkippedButCruiseSurvives() throws {
        let maliciousPort = ExportPort(
            id: UUID().uuidString,
            name: "Palma",
            country: "Spanien",
            lat: "39.50000000",
            lng: "2.60000000",
            arrival: "2025-01-02T08:00:00",
            departure: "2025-01-02T18:00:00",
            imageUrl: "../../evil.png",
            excursions: []
        )
        let cruise = ExportCruise(
            id: UUID().uuidString,
            title: "Bösartiger Bild-Import",
            startDate: "2025-01-01",
            endDate: "2025-01-08",
            shippingLine: "MSC",
            ship: "Seaside",
            cabinType: nil,
            cabinNumber: nil,
            bookingNumber: nil,
            notes: nil,
            rating: 4,
            route: [maliciousPort],
            photos: [],
            expenses: []
        )

        let jsonData = try JSONEncoder().encode([cruise])
        let zipData = buildTestZip(entries: [TestZipEntry(name: "data.json", data: jsonData)])

        let zipURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("evilurl-\(UUID().uuidString).zip")
        try zipData.write(to: zipURL)
        defer { try? FileManager.default.removeItem(at: zipURL) }

        let container = try makeInMemoryContainer()
        let context = container.mainContext

        let result = try ExportImportService.shared.importFromZip(url: zipURL, modelContext: context)
        #expect(result.imported == 1)

        let importedPorts = try context.fetch(FetchDescriptor<CruisePort>())
        #expect(importedPorts.count == 1)
        #expect(importedPorts.first?.imageData == nil)
    }

    @Test("Bösartiger photos[]-Pfad in data.json wird abgelehnt; Cruise wird importiert, Foto fehlt")
    @MainActor
    func maliciousPhotoPathIsSkippedButCruiseSurvives() throws {
        let cruise = ExportCruise(
            id: UUID().uuidString,
            title: "Bösartiger Foto-Import",
            startDate: "2025-03-01",
            endDate: "2025-03-08",
            shippingLine: "AIDA",
            ship: "AIDAmar",
            cabinType: nil,
            cabinNumber: nil,
            bookingNumber: nil,
            notes: nil,
            rating: 4,
            route: [],
            photos: ["../../evil.jpg"],
            expenses: []
        )

        let jsonData = try JSONEncoder().encode([cruise])
        let zipData = buildTestZip(entries: [TestZipEntry(name: "data.json", data: jsonData)])

        let zipURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("evilphoto-\(UUID().uuidString).zip")
        try zipData.write(to: zipURL)
        defer { try? FileManager.default.removeItem(at: zipURL) }

        let container = try makeInMemoryContainer()
        let context = container.mainContext

        let result = try ExportImportService.shared.importFromZip(url: zipURL, modelContext: context)
        #expect(result.imported == 1)

        let importedPhotos = try context.fetch(FetchDescriptor<Photo>())
        #expect(importedPhotos.isEmpty)
    }
}

// MARK: - Dekompressionsbomben-Schutz

@Suite("Import-Härtung: Größen-Limit")
struct DecompressionBombHardeningTests {

    @Test("ZIP-Header mit uncompressedSize > 50 MB wird vor jeder Allokation abgelehnt")
    @MainActor
    func oversizedUncompressedSizeHeaderIsRejectedBeforeAllocation() throws {
        let tinyPayload = Data(repeating: 0x41, count: 16)
        // Header behauptet 60 MB, obwohl real nur 16 Bytes vorhanden sind — der Check muss
        // ausschließlich auf den (gelogenen) Header-Wert reagieren, bevor irgendetwas allokiert wird.
        let lyingZip = buildTestZip(entries: [
            TestZipEntry(name: "data.json", data: tinyPayload, declaredUncompressedSize: 60 * 1024 * 1024)
        ])

        let zipURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("bombtest-\(UUID().uuidString).zip")
        try lyingZip.write(to: zipURL)
        defer { try? FileManager.default.removeItem(at: zipURL) }

        let container = try makeInMemoryContainer()
        let context = container.mainContext

        var caughtError: Error?
        do {
            _ = try ExportImportService.shared.importFromZip(url: zipURL, modelContext: context)
        } catch {
            caughtError = error
        }

        guard let importError = caughtError as? ExportImportService.ImportError else {
            Issue.record("Erwarteter ExportImportService.ImportError, erhalten: \(String(describing: caughtError))")
            return
        }
        guard case .entryTooLarge = importError else {
            Issue.record("Erwartete .entryTooLarge, erhalten: \(importError)")
            return
        }
    }

    @Test("STORED-Eintrag mit kleinem uncompressedSize aber großem compressedSize wird deterministisch abgelehnt")
    @MainActor
    func mismatchedStoredSizeHeaderIsRejectedBeforeWrite() throws {
        let tinyPayload = Data(repeating: 0x42, count: 8)
        // Header behauptet ein kleines uncompressedSize, aber ein compressedSize weit über dem
        // Limit — die Extraktion liest tatsächlich `compressedSize` Bytes und würde das
        // uncompressedSize-Limit sonst umgehen.
        let mismatchedZip = buildTestZip(entries: [
            TestZipEntry(
                name: "data.json",
                data: tinyPayload,
                declaredUncompressedSize: 8,
                declaredCompressedSize: 60 * 1024 * 1024
            )
        ])

        let zipURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("mismatch-\(UUID().uuidString).zip")
        try mismatchedZip.write(to: zipURL)
        defer { try? FileManager.default.removeItem(at: zipURL) }

        let container = try makeInMemoryContainer()
        let context = container.mainContext

        var caughtError: Error?
        do {
            _ = try ExportImportService.shared.importFromZip(url: zipURL, modelContext: context)
        } catch {
            caughtError = error
        }

        guard let importError = caughtError as? ExportImportService.ImportError else {
            Issue.record("Erwarteter ExportImportService.ImportError, erhalten: \(String(describing: caughtError))")
            return
        }
        guard case .entryTooLarge = importError else {
            Issue.record("Erwartete .entryTooLarge (compressedSize-Limit), erhalten: \(importError)")
            return
        }
    }
}

// MARK: - ID-Duplikate innerhalb derselben Import-Datei

@Suite("Import-Härtung: dateiinterne ID-Duplikate")
struct DuplicateCruiseIDHardeningTests {

    @Test("Zwei Cruises mit gleicher id in derselben Datei: nur die erste wird importiert")
    @MainActor
    func duplicateCruiseIDInSameFileImportsOnlyFirst() throws {
        let sharedID = UUID().uuidString

        let cruiseA = ExportCruise(
            id: sharedID,
            title: "Erste Fahrt",
            startDate: "2025-01-01",
            endDate: "2025-01-08",
            shippingLine: "MSC",
            ship: "Seaside",
            cabinType: nil,
            cabinNumber: nil,
            bookingNumber: nil,
            notes: nil,
            rating: 5,
            route: [],
            photos: [],
            expenses: []
        )
        let cruiseB = ExportCruise(
            id: sharedID,
            title: "Zweite Fahrt (gleiche ID)",
            startDate: "2025-02-01",
            endDate: "2025-02-08",
            shippingLine: "AIDA",
            ship: "AIDAmar",
            cabinType: nil,
            cabinNumber: nil,
            bookingNumber: nil,
            notes: nil,
            rating: 3,
            route: [],
            photos: [],
            expenses: []
        )

        let jsonData = try JSONEncoder().encode([cruiseA, cruiseB])
        let jsonURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("duptest-\(UUID().uuidString).json")
        try jsonData.write(to: jsonURL)
        defer { try? FileManager.default.removeItem(at: jsonURL) }

        let container = try makeInMemoryContainer()
        let context = container.mainContext

        let result = try ExportImportService.shared.importFromJSON(url: jsonURL, modelContext: context)

        #expect(result.imported == 1)
        #expect(result.skippedDuplicates == 1)

        let importedCruises = try context.fetch(FetchDescriptor<Cruise>())
        #expect(importedCruises.count == 1)
        #expect(importedCruises.first?.title == "Erste Fahrt")
    }

    @Test("Zwei Ports gleicher id in derselben Cruise: beide bleiben erhalten, zweiter bekommt frische ID")
    @MainActor
    func duplicatePortIDInSameCruiseKeepsBothPortsWithFreshSecondID() throws {
        let sharedPortID = UUID().uuidString

        let portA = ExportPort(
            id: sharedPortID,
            name: "Palma",
            country: "Spanien",
            lat: "39.50000000",
            lng: "2.60000000",
            arrival: "2025-01-02T08:00:00",
            departure: "2025-01-02T18:00:00",
            imageUrl: nil,
            excursions: []
        )
        let portB = ExportPort(
            id: sharedPortID,
            name: "Ibiza",
            country: "Spanien",
            lat: "38.90000000",
            lng: "1.42000000",
            arrival: "2025-01-03T08:00:00",
            departure: "2025-01-03T18:00:00",
            imageUrl: nil,
            excursions: []
        )
        let cruise = ExportCruise(
            id: UUID().uuidString,
            title: "Route mit ID-Duplikat",
            startDate: "2025-01-01",
            endDate: "2025-01-08",
            shippingLine: "MSC",
            ship: "Seaside",
            cabinType: nil,
            cabinNumber: nil,
            bookingNumber: nil,
            notes: nil,
            rating: 4,
            route: [portA, portB],
            photos: [],
            expenses: []
        )

        let jsonData = try JSONEncoder().encode([cruise])
        let jsonURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("dupport-\(UUID().uuidString).json")
        try jsonData.write(to: jsonURL)
        defer { try? FileManager.default.removeItem(at: jsonURL) }

        let container = try makeInMemoryContainer()
        let context = container.mainContext

        let result = try ExportImportService.shared.importFromJSON(url: jsonURL, modelContext: context)
        #expect(result.imported == 1)

        let importedPorts = try context.fetch(FetchDescriptor<CruisePort>())
        #expect(importedPorts.count == 2, "Route muss trotz ID-Duplikat vollständig erhalten bleiben")

        let sharedUUID = UUID(uuidString: sharedPortID)
        let portsWithFileID = importedPorts.filter { $0.id == sharedUUID }
        #expect(portsWithFileID.count == 1, "Nur das erste Vorkommen darf die Datei-ID übernehmen")
        #expect(portsWithFileID.first?.name == "Palma", "Das erste Vorkommen behält die Datei-ID")

        let portWithFreshID = importedPorts.first { $0.name == "Ibiza" }
        #expect(portWithFreshID?.id != sharedUUID, "Das zweite Vorkommen muss eine frische, andere ID bekommen")
    }
}

// MARK: - Port-Bild-Roundtrip (A1.2)

@Suite("Export/Import: Hafen-Bild-Roundtrip")
struct PortImageRoundtripTests {

    @Test("Hafen-Bild überlebt Export→Import im ZIP verlustfrei, Port-UUID bleibt stabil, DTO trägt die erwartete imageUrl")
    @MainActor
    func portImageRoundtripsLosslessInZipExport() throws {
        let sourceContainer = try makeInMemoryContainer()
        let sourceContext = sourceContainer.mainContext

        let cruise = Cruise(
            title: "Karibik",
            startDate: makeDate("2025-06-01"),
            endDate: makeDate("2025-06-10"),
            shippingLine: "MSC",
            ship: "Seaside"
        )
        sourceContext.insert(cruise)

        let port = CruisePort(name: "Nassau", country: "Bahamas", latitude: 25.05, longitude: -77.35)
        let originalImageData = Data((0..<256).map { UInt8($0 % 256) })
        port.imageData = originalImageData
        port.cruise = cruise
        sourceContext.insert(port)

        try sourceContext.save()

        let zipURL = try ExportImportService.shared.exportToZip(cruises: [cruise])
        defer { try? FileManager.default.removeItem(at: zipURL) }

        // DTO direkt aus dem ZIP verifizieren: exakter Pfad "images/<cruiseId>/ports/<index>".
        let zipData = try Data(contentsOf: zipURL)
        guard let dataJSON = extractZipEntry(named: "data.json", from: zipData) else {
            Issue.record("data.json nicht im exportierten ZIP gefunden")
            return
        }
        let exportedCruises = try JSONDecoder().decode([ExportCruise].self, from: dataJSON)
        #expect(exportedCruises.first?.route.first?.imageUrl == "images/\(cruise.id.uuidString)/ports/0")

        let targetContainer = try makeInMemoryContainer()
        let targetContext = targetContainer.mainContext

        let result = try ExportImportService.shared.importFromZip(url: zipURL, modelContext: targetContext)
        #expect(result.imported == 1)

        let importedPorts = try targetContext.fetch(FetchDescriptor<CruisePort>())
        #expect(importedPorts.count == 1)
        #expect(importedPorts.first?.id == port.id)
        #expect(importedPorts.first?.imageData == originalImageData)
    }

    @Test("Legacy-JSON-Export lässt imageUrl weiterhin nil (keine Bild-Pfadreferenz ohne ZIP)")
    @MainActor
    func legacyJSONExportKeepsImageUrlNil() throws {
        let container = try makeInMemoryContainer()
        let context = container.mainContext

        let cruise = Cruise(
            title: "Fjorde",
            startDate: makeDate("2025-07-01"),
            endDate: makeDate("2025-07-10"),
            shippingLine: "AIDA",
            ship: "AIDAprima"
        )
        context.insert(cruise)

        let port = CruisePort(name: "Bergen", country: "Norwegen", latitude: 60.39, longitude: 5.32)
        port.imageData = Data([0x1, 0x2, 0x3])
        port.cruise = cruise
        context.insert(port)

        try context.save()

        let jsonURL = try ExportImportService.shared.exportToJSON(cruises: [cruise])
        defer { try? FileManager.default.removeItem(at: jsonURL) }

        let jsonData = try Data(contentsOf: jsonURL)
        let decoded = try JSONDecoder().decode([ExportCruise].self, from: jsonData)

        #expect(decoded.first?.route.first?.imageUrl == nil)
    }
}
