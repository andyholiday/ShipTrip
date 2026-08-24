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
import CoreGraphics
import ImageIO
import UniformTypeIdentifiers
import Compression
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

private struct TestFixtureError: Error {}

/// Erzeugt echte, gültige (2x2 Pixel) PNG-Bytes für Roundtrip-Tests, die den Import durchlaufen —
/// notwendig seit dem Codex-Fix (Major 1), der Bilddaten beim Import inhaltlich via ImageIO
/// validiert. Beliebige Nicht-Bild-Bytes würden von `isValidImageData` verworfen.
private func makeMinimalValidPNGData() throws -> Data {
    let width = 2
    let height = 2
    let colorSpace = CGColorSpaceCreateDeviceRGB()
    guard let context = CGContext(
        data: nil,
        width: width,
        height: height,
        bitsPerComponent: 8,
        bytesPerRow: width * 4,
        space: colorSpace,
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
    ), let cgImage = context.makeImage() else {
        throw TestFixtureError()
    }

    let mutableData = NSMutableData()
    guard let destination = CGImageDestinationCreateWithData(mutableData, UTType.png.identifier as CFString, 1, nil) else {
        throw TestFixtureError()
    }
    CGImageDestinationAddImage(destination, cgImage, nil)
    guard CGImageDestinationFinalize(destination) else {
        throw TestFixtureError()
    }
    return mutableData as Data
}

/// Komprimiert `data` mit demselben Algorithmus (`COMPRESSION_ZLIB`), den `ZipArchiveReader.
/// decompressDeflate` beim Entpacken verwendet — für Tests, die einen echten Deflate-Eintrag
/// (Compression Method 8) brauchen.
private func deflateCompress(_ data: Data) -> Data {
    let destCapacity = data.count + 128
    let destBuffer = UnsafeMutablePointer<UInt8>.allocate(capacity: destCapacity)
    defer { destBuffer.deallocate() }

    let encodedSize = data.withUnsafeBytes { (srcPtr: UnsafeRawBufferPointer) -> Int in
        guard let baseAddress = srcPtr.baseAddress else { return 0 }
        return compression_encode_buffer(
            destBuffer,
            destCapacity,
            baseAddress.assumingMemoryBound(to: UInt8.self),
            data.count,
            nil,
            COMPRESSION_ZLIB
        )
    }

    return Data(bytes: destBuffer, count: encodedSize)
}

// MARK: - Roh-ZIP-Builder für Angriffsszenarien

/// Ein einzelner Test-ZIP-Eintrag. `declaredUncompressedSize`/`declaredCompressedSize` dürfen vom
/// tatsächlichen `data.count` abweichen, um lügende Header zu simulieren (Bomben-/Mismatch-Tests).
/// `crcOverride` erlaubt eine bewusst falsche CRC-32 für Korruptionstests (H8); ohne Override wird
/// die echte CRC-32 aus `data` berechnet, damit alle bestehenden Tests durch die neue
/// CRC-Verifikation nicht betroffen sind. `compressionMethod` erlaubt Deflate-Einträge (8) — dann
/// ist `data` bereits der komprimierte Payload, und `crcOverride` muss die CRC der UNKOMPRIMIERTEN
/// Originaldaten liefern (die CRC wird laut ZIP-Spezifikation immer über die Originaldaten gebildet).
/// `localExtraLengthOverride` schreibt eine gelogene Extra-Feld-Länge NUR in den Local Header, ohne
/// tatsächlich Extra-Bytes zu schreiben (Truncation-Test für ein abgeschnittenes Extra-Feld, H8).
private struct TestZipEntry {
    let name: String
    let data: Data
    var declaredUncompressedSize: Int?
    var declaredCompressedSize: Int?
    var crcOverride: UInt32?
    var compressionMethod: Int
    var localExtraLengthOverride: Int?

    init(
        name: String,
        data: Data,
        declaredUncompressedSize: Int? = nil,
        declaredCompressedSize: Int? = nil,
        crcOverride: UInt32? = nil,
        compressionMethod: Int = 0,
        localExtraLengthOverride: Int? = nil
    ) {
        self.name = name
        self.data = data
        self.declaredUncompressedSize = declaredUncompressedSize
        self.declaredCompressedSize = declaredCompressedSize
        self.crcOverride = crcOverride
        self.compressionMethod = compressionMethod
        self.localExtraLengthOverride = localExtraLengthOverride
    }
}

/// Minimaler ZIP-Builder für Tests (standardmäßig Compression Method 0 / STORED, optional Deflate
/// pro Eintrag), unabhängig von der privaten `buildZip`-Implementierung in ExportImportService.
/// Erlaubt bewusst manipulierte Eintragsnamen (Zip-Slip), Header, deren deklarierte Größen vom
/// tatsächlichen `data.count` abweichen (Dekompressionsbomben-/Mismatch-Tests), sowie eine falsche
/// CRC-32 pro Eintrag (Korruptionstests, H8). `entryCountOverride` schreibt eine von der
/// tatsächlichen Eintragszahl abweichende EOCD-Angabe (Test für "truncated Central Directory", H8).
/// CRC-32 wird standardmäßig korrekt berechnet (Codex-Auflage #5), da `parseAndExtractZip` sie
/// jetzt prüft.
private func buildTestZip(entries: [TestZipEntry], entryCountOverride: Int? = nil) -> Data {
    struct Meta {
        let nameData: Data
        let crc: UInt32
        let declaredUncompressedSize: UInt32
        let declaredCompressedSize: UInt32
        let compressionMethod: UInt16
        let localOffset: UInt32
    }

    var archive = Data()
    var metas: [Meta] = []

    for entry in entries {
        let nameData = Data(entry.name.utf8)
        let actualSize = UInt32(entry.data.count)
        let crc = entry.crcOverride ?? CRC32.checksum(entry.data)
        let declaredUncompressedSize = UInt32(entry.declaredUncompressedSize ?? entry.data.count)
        let declaredCompressedSize = UInt32(entry.declaredCompressedSize ?? entry.data.count)
        let compressionMethod = UInt16(entry.compressionMethod)
        let localOffset = UInt32(archive.count)
        metas.append(Meta(
            nameData: nameData,
            crc: crc,
            declaredUncompressedSize: declaredUncompressedSize,
            declaredCompressedSize: declaredCompressedSize,
            compressionMethod: compressionMethod,
            localOffset: localOffset
        ))

        archive.append(contentsOf: [0x50, 0x4B, 0x03, 0x04]) // Local File Header Signatur
        archive.appendUInt16LE(20)  // Version needed
        archive.appendUInt16LE(0)   // Bit flag
        archive.appendUInt16LE(compressionMethod) // Compression: 0 = STORED, 8 = Deflate
        archive.appendUInt16LE(0)   // Mod time
        archive.appendUInt16LE(0)   // Mod date
        archive.appendUInt32LE(crc) // CRC-32
        archive.appendUInt32LE(actualSize) // Compressed size (lokal; wird vom Parser nicht gelesen)
        archive.appendUInt32LE(actualSize) // Uncompressed size (lokal; wird vom Parser nicht gelesen)
        archive.appendUInt16LE(UInt16(nameData.count))
        archive.appendUInt16LE(UInt16(entry.localExtraLengthOverride ?? 0)) // Extra field length (ggf. gelogen)
        archive.append(nameData)
        archive.append(entry.data) // tatsächliche Bytes — die Extraktion liest exakt `actualSize` Bytes ab hier
    }

    let centralDirOffset = UInt32(archive.count)
    for meta in metas {
        archive.append(contentsOf: [0x50, 0x4B, 0x01, 0x02]) // Central Directory Signatur
        archive.appendUInt16LE(20)  // Version made by
        archive.appendUInt16LE(20)  // Version needed
        archive.appendUInt16LE(0)   // Bit flag
        archive.appendUInt16LE(meta.compressionMethod) // Compression: 0 = STORED, 8 = Deflate
        archive.appendUInt16LE(0)   // Mod time
        archive.appendUInt16LE(0)   // Mod date
        archive.appendUInt32LE(meta.crc) // CRC-32
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

    let declaredEntryCount = UInt16(entryCountOverride ?? entries.count)
    archive.append(contentsOf: [0x50, 0x4B, 0x05, 0x06]) // EOCD Signatur
    archive.appendUInt16LE(0)
    archive.appendUInt16LE(0)
    archive.appendUInt16LE(declaredEntryCount)
    archive.appendUInt16LE(declaredEntryCount)
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
            photos: [ExportPhoto(id: nil, ref: "../../evil.jpg")],
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
    func portImageRoundtripsLosslessInZipExport() async throws {
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
        // Echte PNG-Bytes statt beliebiger Rohdaten (Codex-Fix Major 1: Import validiert Bildinhalte).
        let originalImageData = try makeMinimalValidPNGData()
        port.imageData = originalImageData
        port.cruise = cruise
        sourceContext.insert(port)

        try sourceContext.save()

        let zipURL = try await ExportImportService.shared.exportToZip(cruises: [cruise])
        defer { try? FileManager.default.removeItem(at: zipURL) }

        // DTO direkt aus dem ZIP verifizieren: exakter Pfad "images/<cruiseId>/ports/<index>".
        let zipData = try Data(contentsOf: zipURL)
        guard let dataJSON = extractZipEntry(named: "data.json", from: zipData) else {
            Issue.record("data.json nicht im exportierten ZIP gefunden")
            return
        }
        let exportedCruises = try ExportArchive.decode(from: dataJSON).cruises
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
        let decoded = try ExportArchive.decode(from: jsonData).cruises

        #expect(decoded.first?.route.first?.imageUrl == nil)
    }
}

// MARK: - Seetag-Klassifikation (H3)

@Suite("Import-Härtung: Seetag-Klassifikation")
struct SeaDayClassificationHardeningTests {

    @Test("Alt-Format (kein isSeaDay-Feld): koordinatenloser echter Hafen übersteht Export→Import→Export mit Name und Land intakt")
    @MainActor
    func realPortWithoutCoordinatesSurvivesExportImportExportRoundtrip() throws {
        // Simuliert ein Legacy-JSON (Web-App-Export/Alt-Archiv) ohne isSeaDay-Feld: ein echter,
        // benannter Hafen, dessen Koordinaten (noch) nicht aufgelöst wurden.
        let legacyPort = ExportPort(
            id: UUID().uuidString,
            name: "Kotor",
            country: "Montenegro",
            lat: nil,
            lng: nil,
            arrival: "2025-05-02T08:00:00",
            departure: "2025-05-02T18:00:00",
            imageUrl: nil,
            excursions: []
        )
        let legacyCruise = ExportCruise(
            id: UUID().uuidString,
            title: "Adria",
            startDate: "2025-05-01",
            endDate: "2025-05-08",
            shippingLine: "MSC",
            ship: "Fantasia",
            cabinType: nil,
            cabinNumber: nil,
            bookingNumber: nil,
            notes: nil,
            rating: 4,
            route: [legacyPort],
            photos: [],
            expenses: []
        )

        let jsonData = try JSONEncoder().encode([legacyCruise])
        let jsonURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("legacyport-\(UUID().uuidString).json")
        try jsonData.write(to: jsonURL)
        defer { try? FileManager.default.removeItem(at: jsonURL) }

        let container = try makeInMemoryContainer()
        let context = container.mainContext

        let result = try ExportImportService.shared.importFromJSON(url: jsonURL, modelContext: context)
        #expect(result.imported == 1)

        let importedPorts = try context.fetch(FetchDescriptor<CruisePort>())
        #expect(importedPorts.count == 1)
        let importedPort = try #require(importedPorts.first)
        #expect(importedPort.isSeaDay == false, "Ein benannter Hafen ohne Koordinaten darf kein Seetag werden")
        #expect(importedPort.name == "Kotor")
        #expect(importedPort.country == "Montenegro")

        // Re-Export: darf Name/Land nicht mit "Seetag" überschreiben, da isSeaDay korrekt false ist.
        let cruises = try context.fetch(FetchDescriptor<Cruise>())
        let reExportedURL = try ExportImportService.shared.exportToJSON(cruises: cruises)
        defer { try? FileManager.default.removeItem(at: reExportedURL) }

        let reExportedData = try Data(contentsOf: reExportedURL)
        let reExported = try ExportArchive.decode(from: reExportedData).cruises
        let reExportedPort = try #require(reExported.first?.route.first)
        #expect(reExportedPort.name == "Kotor")
        #expect(reExportedPort.country == "Montenegro")
        #expect(reExportedPort.isSeaDay == false)
    }

    @Test("Alt-Format (kein isSeaDay-Feld): Seetag ohne Koordinaten wird weiterhin per Namens-Fallback erkannt")
    @MainActor
    func legacySeaDayWithoutFlagIsRecognizedByNameFallback() throws {
        let legacySeaDay = ExportPort(
            id: UUID().uuidString,
            name: "Seetag",
            country: nil,
            lat: nil,
            lng: nil,
            arrival: "2025-05-03T00:00:00",
            departure: "2025-05-03T23:59:59",
            imageUrl: nil,
            excursions: []
        )
        let cruise = ExportCruise(
            id: UUID().uuidString,
            title: "Adria mit Seetag",
            startDate: "2025-05-01",
            endDate: "2025-05-08",
            shippingLine: "MSC",
            ship: "Fantasia",
            cabinType: nil,
            cabinNumber: nil,
            bookingNumber: nil,
            notes: nil,
            rating: 4,
            route: [legacySeaDay],
            photos: [],
            expenses: []
        )

        let jsonData = try JSONEncoder().encode([cruise])
        let jsonURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("legacyseaday-\(UUID().uuidString).json")
        try jsonData.write(to: jsonURL)
        defer { try? FileManager.default.removeItem(at: jsonURL) }

        let container = try makeInMemoryContainer()
        let context = container.mainContext

        let result = try ExportImportService.shared.importFromJSON(url: jsonURL, modelContext: context)
        #expect(result.imported == 1)

        let importedPorts = try context.fetch(FetchDescriptor<CruisePort>())
        let importedPort = try #require(importedPorts.first)
        #expect(importedPort.isSeaDay == true)
    }

    @Test("Neu-Format (explizites isSeaDay-Feld): Flag übersteuert die Namens-Heuristik")
    @MainActor
    func explicitIsSeaDayFlagOverridesNameHeuristic() throws {
        // Ein Hafen, der zufällig "Seetag" heißt, aber explizit als Nicht-Seetag markiert ist
        // (z. B. via ZIP-Export dieses Fixes), darf nicht per Namens-Fallback überschrieben werden.
        let portNamedSeaDayButReal = ExportPort(
            id: UUID().uuidString,
            name: "Seetag",
            country: "Fantasialand",
            lat: "12.00000000",
            lng: "34.00000000",
            arrival: "2025-05-04T08:00:00",
            departure: "2025-05-04T18:00:00",
            imageUrl: nil,
            excursions: [],
            isSeaDay: false
        )
        let cruise = ExportCruise(
            id: UUID().uuidString,
            title: "Neues Format",
            startDate: "2025-05-01",
            endDate: "2025-05-08",
            shippingLine: "MSC",
            ship: "Fantasia",
            cabinType: nil,
            cabinNumber: nil,
            bookingNumber: nil,
            notes: nil,
            rating: 4,
            route: [portNamedSeaDayButReal],
            photos: [],
            expenses: []
        )

        let jsonData = try JSONEncoder().encode([cruise])
        let jsonURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("explicitflag-\(UUID().uuidString).json")
        try jsonData.write(to: jsonURL)
        defer { try? FileManager.default.removeItem(at: jsonURL) }

        let container = try makeInMemoryContainer()
        let context = container.mainContext

        let result = try ExportImportService.shared.importFromJSON(url: jsonURL, modelContext: context)
        #expect(result.imported == 1)

        let importedPorts = try context.fetch(FetchDescriptor<CruisePort>())
        let importedPort = try #require(importedPorts.first)
        #expect(importedPort.isSeaDay == false, "Explizites Flag muss den Namens-Fallback übersteuern")
    }

    @Test("Neu-Format (explizites isSeaDay-Feld): echter Seetag wird auch ohne Namens-Match erkannt")
    @MainActor
    func explicitIsSeaDayFlagClassifiesWithoutNameMatch() throws {
        // Deckt ab, dass das Flag auch dann greift, wenn der Name nicht "Seetag"/"Sea Day" lautet
        // (z. B. lokalisierter Platzhalter aus einer anderen Quelle).
        let flaggedSeaDay = ExportPort(
            id: UUID().uuidString,
            name: "Tag auf See",
            country: nil,
            lat: nil,
            lng: nil,
            arrival: "2025-05-05T00:00:00",
            departure: "2025-05-05T23:59:59",
            imageUrl: nil,
            excursions: [],
            isSeaDay: true
        )
        let cruise = ExportCruise(
            id: UUID().uuidString,
            title: "Explizit markierter Seetag",
            startDate: "2025-05-01",
            endDate: "2025-05-08",
            shippingLine: "MSC",
            ship: "Fantasia",
            cabinType: nil,
            cabinNumber: nil,
            bookingNumber: nil,
            notes: nil,
            rating: 4,
            route: [flaggedSeaDay],
            photos: [],
            expenses: []
        )

        let jsonData = try JSONEncoder().encode([cruise])
        let jsonURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("explicitflagtrue-\(UUID().uuidString).json")
        try jsonData.write(to: jsonURL)
        defer { try? FileManager.default.removeItem(at: jsonURL) }

        let container = try makeInMemoryContainer()
        let context = container.mainContext

        let result = try ExportImportService.shared.importFromJSON(url: jsonURL, modelContext: context)
        #expect(result.imported == 1)

        let importedPorts = try context.fetch(FetchDescriptor<CruisePort>())
        let importedPort = try #require(importedPorts.first)
        #expect(importedPort.isSeaDay == true)
        #expect(importedPort.name == "Tag auf See")

        // Re-Export: der individuelle Name eines echten Seetags darf nicht mit "Seetag"
        // überschrieben werden — isSeaDay ist reines Klassifikations-Flag, keine Namensquelle.
        let cruises = try context.fetch(FetchDescriptor<Cruise>())
        let reExportedURL = try ExportImportService.shared.exportToJSON(cruises: cruises)
        defer { try? FileManager.default.removeItem(at: reExportedURL) }

        let reExportedData = try Data(contentsOf: reExportedURL)
        let reExported = try ExportArchive.decode(from: reExportedData).cruises
        let reExportedPort = try #require(reExported.first?.route.first)
        #expect(reExportedPort.name == "Tag auf See")
        #expect(reExportedPort.isSeaDay == true)
    }
}

// MARK: - ZIP-Integrität (H8)

@Suite("Import-Härtung: ZIP-Integrität (H8)")
struct ZipIntegrityHardeningTests {

    @Test("ZIP-Eintrag mit falscher CRC-32 wird mit klarer Fehlermeldung abgelehnt")
    @MainActor
    func corruptCRCEntryIsRejectedWithClearError() throws {
        let corruptZip = buildTestZip(entries: [
            TestZipEntry(name: "data.json", data: Data("{}".utf8), crcOverride: 0x1234_5678)
        ])

        let zipURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("crcmismatch-\(UUID().uuidString).zip")
        try corruptZip.write(to: zipURL)
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
        guard case .crcMismatch(let name) = importError else {
            Issue.record("Erwartete .crcMismatch, erhalten: \(importError)")
            return
        }
        #expect(name == "data.json")
        #expect(importError.errorDescription?.isEmpty == false, "Fehler muss eine klare Meldung liefern")
    }

    @Test("EOCD behauptet mehr Einträge als das Central Directory tatsächlich enthält: klarer Fehler statt stillem Abbruch")
    @MainActor
    func truncatedCentralDirectoryIsRejectedWithClearError() throws {
        let truncatedZip = buildTestZip(
            entries: [TestZipEntry(name: "data.json", data: Data("{}".utf8))],
            entryCountOverride: 3
        )

        let zipURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("truncatedcd-\(UUID().uuidString).zip")
        try truncatedZip.write(to: zipURL)
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
        guard case .truncatedArchive = importError else {
            Issue.record("Erwartete .truncatedArchive, erhalten: \(importError)")
            return
        }
        #expect(importError.errorDescription?.isEmpty == false, "Fehler muss eine klare Meldung liefern")
    }

    @Test("Local-File-Header mit ungültiger Signatur wird abgelehnt")
    @MainActor
    func corruptedLocalHeaderSignatureIsRejected() throws {
        var zipData = buildTestZip(entries: [TestZipEntry(name: "data.json", data: Data("{}".utf8))])
        // Local File Header Signatur beginnt bei Offset 0 mit PK\x03\x04 — letztes Signatur-Byte kippen.
        zipData[3] = 0x00

        let zipURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("badlocalsig-\(UUID().uuidString).zip")
        try zipData.write(to: zipURL)
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
        guard case .invalidLocalHeader = importError else {
            Issue.record("Erwartete .invalidLocalHeader, erhalten: \(importError)")
            return
        }
    }

    @Test("Name im Local-Header weicht vom Central-Directory-Namen ab: wird abgelehnt")
    @MainActor
    func localCentralNameMismatchIsRejected() throws {
        var zipData = buildTestZip(entries: [TestZipEntry(name: "data.json", data: Data("{}".utf8))])
        // Name im Local Header beginnt bei Offset 30 ("data.json"); erstes Zeichen kippen, sodass er
        // vom unveränderten Central-Directory-Namen abweicht, ohne die Namenslänge zu ändern.
        zipData[30] = UInt8(ascii: "x")

        let zipURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("namemismatch-\(UUID().uuidString).zip")
        try zipData.write(to: zipURL)
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
        guard case .nameMismatch = importError else {
            Issue.record("Erwartete .nameMismatch, erhalten: \(importError)")
            return
        }
    }

    @Test("Fehlende Medien (Hafen-Bild + Foto) werden in ImportResult gezählt statt den Import abzubrechen")
    @MainActor
    func missingMediaFilesAreCountedNotFatal() throws {
        let portWithMissingImage = ExportPort(
            id: UUID().uuidString,
            name: "Palma",
            country: "Spanien",
            lat: "39.50000000",
            lng: "2.60000000",
            arrival: "2025-01-02T08:00:00",
            departure: "2025-01-02T18:00:00",
            imageUrl: "images/missing/port.png",
            excursions: []
        )
        let cruise = ExportCruise(
            id: UUID().uuidString,
            title: "Fehlende Medien",
            startDate: "2025-01-01",
            endDate: "2025-01-08",
            shippingLine: "MSC",
            ship: "Seaside",
            cabinType: nil,
            cabinNumber: nil,
            bookingNumber: nil,
            notes: nil,
            rating: 4,
            route: [portWithMissingImage],
            photos: [ExportPhoto(id: nil, ref: "images/missing/photo.png")],
            expenses: []
        )

        let jsonData = try JSONEncoder().encode([cruise])
        // Nur data.json im Archiv — die referenzierten Bilddateien existieren bewusst nicht.
        let zipData = buildTestZip(entries: [TestZipEntry(name: "data.json", data: jsonData)])

        let zipURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("missingmedia-\(UUID().uuidString).zip")
        try zipData.write(to: zipURL)
        defer { try? FileManager.default.removeItem(at: zipURL) }

        let container = try makeInMemoryContainer()
        let context = container.mainContext

        let result = try ExportImportService.shared.importFromZip(url: zipURL, modelContext: context)
        #expect(result.imported == 1, "Kreuzfahrt muss trotz fehlender Medien importiert werden")
        #expect(result.invalidMedia == 2, "Fehlendes Hafen-Bild UND fehlendes Foto müssen gezählt werden")

        let importedPorts = try context.fetch(FetchDescriptor<CruisePort>())
        #expect(importedPorts.first?.imageData == nil)
        let importedPhotos = try context.fetch(FetchDescriptor<Photo>())
        #expect(importedPhotos.isEmpty)
    }

    @Test("Local-File-Header eines Verzeichnis-Eintrags mit ungültiger Signatur wird ebenfalls abgelehnt (Verzeichnisse dürfen die Prüfung nicht umgehen)")
    @MainActor
    func corruptedDirectoryEntryLocalHeaderSignatureIsRejected() throws {
        var zipData = buildTestZip(entries: [TestZipEntry(name: "folder/", data: Data())])
        // Local File Header Signatur beginnt bei Offset 0 mit PK\x03\x04 — letztes Signatur-Byte kippen.
        zipData[3] = 0x00

        let zipURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("baddirsig-\(UUID().uuidString).zip")
        try zipData.write(to: zipURL)
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
        guard case .invalidLocalHeader = importError else {
            Issue.record("Erwartete .invalidLocalHeader, erhalten: \(importError)")
            return
        }
    }

    @Test("Verzeichnis-Eintrag mit von 0/0 abweichender Größenangabe im Central-Directory wird abgelehnt")
    @MainActor
    func directoryEntryWithNonZeroDeclaredSizeIsRejected() throws {
        let zipData = buildTestZip(entries: [
            TestZipEntry(name: "folder/", data: Data(), declaredUncompressedSize: 10, declaredCompressedSize: 10)
        ])

        let zipURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("dirsizemismatch-\(UUID().uuidString).zip")
        try zipData.write(to: zipURL)
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
        guard case .sizeMismatch = importError else {
            Issue.record("Erwartete .sizeMismatch, erhalten: \(importError)")
            return
        }
    }

    @Test("EOCD behauptet weniger Einträge als das Central Directory tatsächlich enthält: zusätzlicher CD-Record wird nicht still ignoriert")
    @MainActor
    func understatedEntryCountWithExtraCentralDirectoryRecordIsRejected() throws {
        let zipData = buildTestZip(
            entries: [
                TestZipEntry(name: "data.json", data: Data("{}".utf8)),
                TestZipEntry(name: "extra.txt", data: Data("extra".utf8))
            ],
            entryCountOverride: 1
        )

        let zipURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("understatedcount-\(UUID().uuidString).zip")
        try zipData.write(to: zipURL)
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
        guard case .truncatedArchive = importError else {
            Issue.record("Erwartete .truncatedArchive, erhalten: \(importError)")
            return
        }
    }

    @Test("Verzeichnis-Eintrag mit abgeschnittenem (gelogenem) Local-Header-Extra-Feld wird abgelehnt")
    @MainActor
    func directoryEntryWithTruncatedLocalExtraFieldIsRejected() throws {
        // Local Header behauptet ein 5.000 Byte großes Extra-Feld, das tatsächlich nicht im Archiv
        // enthalten ist — die Extraktion würde ohne den neuen Check über das Archivende hinauslesen.
        let zipData = buildTestZip(entries: [
            TestZipEntry(name: "folder/", data: Data(), localExtraLengthOverride: 5000)
        ])

        let zipURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("truncatedextra-\(UUID().uuidString).zip")
        try zipData.write(to: zipURL)
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
        guard case .truncatedArchive = importError else {
            Issue.record("Erwartete .truncatedArchive, erhalten: \(importError)")
            return
        }
    }

    @Test("Deflate-Eintrag mit falscher deklarierter uncompressedSize wird trotz korrekter CRC abgelehnt")
    @MainActor
    func deflateEntryWithWrongDeclaredUncompressedSizeIsRejectedDespiteCorrectCRC() throws {
        // Payload lang genug, damit compression_encode_buffer echte Deflate-Bytes erzeugt (nicht nur
        // einen Stored-Block).
        let originalBytes = Data(String(repeating: "ShipTrip Deflate Truncation Test Payload. ", count: 20).utf8)
        let compressedBytes = deflateCompress(originalBytes)
        #expect(!compressedBytes.isEmpty, "Deflate-Kompression der Testdaten darf nicht fehlschlagen")

        // CRC wird korrekt über die ECHTEN (unkomprimierten) Originaldaten berechnet — die
        // deklarierte uncompressedSize im Central-Directory-Eintrag wird bewusst verfälscht.
        let correctCRC = CRC32.checksum(originalBytes)
        let zipData = buildTestZip(entries: [
            TestZipEntry(
                name: "data.json",
                data: compressedBytes,
                declaredUncompressedSize: originalBytes.count + 500,
                crcOverride: correctCRC,
                compressionMethod: 8
            )
        ])

        let zipURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("deflatesizelie-\(UUID().uuidString).zip")
        try zipData.write(to: zipURL)
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
        guard case .sizeMismatch(let name) = importError else {
            Issue.record("Erwartete .sizeMismatch, erhalten: \(importError)")
            return
        }
        #expect(name == "data.json")
    }
}

// MARK: - Bildvalidierung (Codex-Gate #2, Major 1)

@Suite("Import-Härtung: Bildvalidierung")
struct MediaContentValidationHardeningTests {

    @Test("Strukturell valider ZIP-Eintrag mit inhaltlich ungültigen Bilddaten (kein echtes Bild) wird nicht übernommen, sondern als invalidMedia gezählt")
    @MainActor
    func structurallyValidButNonImageMediaFileIsRejectedAndCounted() throws {
        let portWithBogusImage = ExportPort(
            id: UUID().uuidString,
            name: "Palma",
            country: "Spanien",
            lat: "39.50000000",
            lng: "2.60000000",
            arrival: "2025-01-02T08:00:00",
            departure: "2025-01-02T18:00:00",
            imageUrl: "images/bogus.png",
            excursions: []
        )
        let cruise = ExportCruise(
            id: UUID().uuidString,
            title: "Ungültiges Bild",
            startDate: "2025-01-01",
            endDate: "2025-01-08",
            shippingLine: "MSC",
            ship: "Seaside",
            cabinType: nil,
            cabinNumber: nil,
            bookingNumber: nil,
            notes: nil,
            rating: 4,
            route: [portWithBogusImage],
            photos: [ExportPhoto(id: nil, ref: "images/bogus.png")],
            expenses: []
        )

        let jsonData = try JSONEncoder().encode([cruise])
        // "images/bogus.png" ist ein strukturell valider ZIP-Eintrag (korrekte CRC, korrekte Header) —
        // die Bytes sind aber kein dekodierbares Bild (reiner Text). Muss von ImageIO abgelehnt werden,
        // nicht nur vom CRC-/Struktur-Check durchgelassen werden.
        let bogusImageBytes = Data("not actually a png".utf8)
        let zipData = buildTestZip(entries: [
            TestZipEntry(name: "data.json", data: jsonData),
            TestZipEntry(name: "images/bogus.png", data: bogusImageBytes)
        ])

        let zipURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("bogusimage-\(UUID().uuidString).zip")
        try zipData.write(to: zipURL)
        defer { try? FileManager.default.removeItem(at: zipURL) }

        let container = try makeInMemoryContainer()
        let context = container.mainContext

        let result = try ExportImportService.shared.importFromZip(url: zipURL, modelContext: context)
        #expect(result.imported == 1, "Kreuzfahrt muss trotz ungültigem Bildinhalt importiert werden")
        #expect(result.invalidMedia == 2, "Hafen-Bild UND Foto referenzieren dieselbe ungültige Bilddatei — beide müssen gezählt werden")

        let importedPorts = try context.fetch(FetchDescriptor<CruisePort>())
        #expect(importedPorts.first?.imageData == nil, "Inhaltlich ungültige Bilddaten dürfen nicht als Hafen-Bild übernommen werden")
        let importedPhotos = try context.fetch(FetchDescriptor<Photo>())
        #expect(importedPhotos.isEmpty, "Inhaltlich ungültige Bilddaten dürfen nicht als Photo übernommen werden")
    }

    @Test("Base64-kodierte, aber inhaltlich ungültige Bilddaten werden nicht übernommen, sondern als invalidMedia gezählt")
    @MainActor
    func invalidBase64ImageBytesAreRejectedAndCounted() throws {
        let bogusBase64 = Data("this is not image data".utf8).base64EncodedString()
        let cruise = ExportCruise(
            id: UUID().uuidString,
            title: "Ungültiges Base64-Bild",
            startDate: "2025-02-01",
            endDate: "2025-02-08",
            shippingLine: "AIDA",
            ship: "AIDAmar",
            cabinType: nil,
            cabinNumber: nil,
            bookingNumber: nil,
            notes: nil,
            rating: 4,
            route: [],
            photos: [ExportPhoto(id: nil, ref: "data:image/png;base64,\(bogusBase64)")],
            expenses: []
        )

        let jsonData = try JSONEncoder().encode([cruise])
        let jsonURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("bogusbase64-\(UUID().uuidString).json")
        try jsonData.write(to: jsonURL)
        defer { try? FileManager.default.removeItem(at: jsonURL) }

        let container = try makeInMemoryContainer()
        let context = container.mainContext

        let result = try ExportImportService.shared.importFromJSON(url: jsonURL, modelContext: context)
        #expect(result.imported == 1, "Kreuzfahrt muss trotz ungültigem Base64-Bild importiert werden")
        #expect(result.invalidMedia == 1)

        let importedPhotos = try context.fetch(FetchDescriptor<Photo>())
        #expect(importedPhotos.isEmpty, "Ein inhaltlich ungültiges Bild darf nicht als Photo übernommen werden")
    }
}
