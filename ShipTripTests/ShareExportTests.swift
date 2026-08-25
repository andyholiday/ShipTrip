//
//  ShareExportTests.swift
//  ShipTripTests
//
//  Export-Seite des Teilens (Contracts C1/C5/C10): Envelope-Vollständigkeit, `share`-Block,
//  Demo-Sperre, Zählgrenzen, Alles-oder-nichts — und die Regressionen, die das bestehende
//  Backup schützen (Originale unangetastet, `share`-Key fehlt im Voll-Export).
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
    df.locale = Locale(identifier: "en_US_POSIX")
    return df.date(from: string) ?? Date(timeIntervalSince1970: 0)
}

private func makeFullContainer() throws -> ModelContainer {
    let schema = Schema([
        Cruise.self, CruisePort.self, Expense.self, Deal.self, Photo.self,
        CustomShippingLine.self, CustomShip.self, HiddenCatalogItem.self
    ])
    return try ModelContainer(
        for: schema, configurations: ModelConfiguration(isStoredInMemoryOnly: true)
    )
}

/// Minimales gültiges PNG (1×1) — der Transcoder braucht echte, dekodierbare Bilddaten.
private let onePixelPNG = Data(base64Encoded:
    "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8/5+hHgAHggJ/PchI6QAAAABJRU5ErkJggg=="
) ?? Data()

/// Reise mit allem, was geteilt wird: Route (inkl. Hafenbild), Notizen, Ausgaben, Fotos.
@MainActor
private func makeRichCruise(title: String, in context: ModelContext) -> Cruise {
    let cruise = Cruise(
        title: title,
        startDate: makeDate("2026-05-01"),
        endDate: makeDate("2026-05-08"),
        shippingLine: "AIDA",
        ship: "AIDAnova"
    )
    cruise.notes = "Balkon backbord, Sonnenuntergänge"
    cruise.cabinType = "Balkon"
    cruise.cabinNumber = "8210"
    cruise.bookingNumber = "BK-4711"
    cruise.rating = 4.5
    context.insert(cruise)

    let palma = CruisePort(name: "Palma", country: "Spanien", latitude: 39.57, longitude: 2.65)
    palma.sortOrder = 0
    palma.imageData = onePixelPNG
    palma.cruise = cruise
    context.insert(palma)

    let seaDay = CruisePort(name: "Seetag", country: "Mittelmeer", latitude: 40.1, longitude: 4.2)
    seaDay.sortOrder = 1
    seaDay.isSeaDay = true
    seaDay.cruise = cruise
    context.insert(seaDay)

    let expense = Expense(category: .excursion, amount: 89.5, description: "Kathedrale")
    expense.cruise = cruise
    context.insert(expense)

    let photo = Photo(imageData: onePixelPNG, sortOrder: 0)
    photo.cruise = cruise
    context.insert(photo)

    return cruise
}

/// Entpackt die `.shiptrip`-Datei und gibt den dekodierten Envelope samt Eintragsnamen zurück.
private func readShareArchive(at url: URL) throws -> (archive: ExportArchive, entries: [String]) {
    let unpacked = FileManager.default.temporaryDirectory
        .appendingPathComponent("share-read-\(UUID().uuidString)")
    try FileManager.default.createDirectory(at: unpacked, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: unpacked) }

    try ZipArchiveReader.extract(from: url, to: unpacked)
    let json = try Data(contentsOf: unpacked.appendingPathComponent("data.json"))

    let files = FileManager.default
        .enumerator(at: unpacked, includingPropertiesForKeys: nil)?
        .compactMap { $0 as? URL }
        .map { $0.path.replacingOccurrences(of: unpacked.path + "/", with: "") } ?? []

    return (try ExportArchive.decode(from: json), files)
}

// MARK: - Envelope + share-Block

@Suite("Share-Export: Envelope und share-Block")
struct ShareExportEnvelopeTests {

    @Test("Envelope trägt genau eine Reise mit Häfen, Notizen, Ausgaben und Fotos")
    @MainActor
    func envelopeIsComplete() async throws {
        let container = try makeFullContainer()
        let cruise = makeRichCruise(title: "Mittelmeer", in: container.mainContext)
        try container.mainContext.save()
        let cruiseID = cruise.id.uuidString

        let url = try await ExportImportService.shared.exportCruiseForSharing(cruise)
        defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }

        let (archive, entries) = try readShareArchive(at: url)

        #expect(archive.formatVersion == ExportArchive.currentFormatVersion)
        #expect(archive.cruises.count == 1)

        let shared = try #require(archive.cruises.first)
        #expect(shared.id == cruiseID)
        #expect(shared.notes == "Balkon backbord, Sonnenuntergänge")
        #expect(shared.cabinNumber == "8210")
        #expect(shared.bookingNumber == "BK-4711")
        #expect(shared.rating == 4.5)
        #expect(shared.route.map(\.name) == ["Palma", "Seetag"])
        #expect(shared.route.first?.imageUrl == "images/\(cruiseID)/ports/0")
        let seaDay = try #require(shared.route.last)
        #expect(seaDay.imageUrl == nil, "Der Seetag hat kein Bild und deshalb keine Referenz")
        #expect(seaDay.isSeaDay == true)
        #expect(shared.expenses.count == 1)
        #expect(shared.expenses.first?.amount == 89.5)
        #expect(shared.photos.count == 1)
        #expect(shared.photos.first?.ref == "images/\(cruiseID)/0")

        // Keine Wunschreisen, kein Katalog-Overlay (C1-Invariante).
        #expect(archive.deals.isEmpty)
        #expect(archive.customShippingLines.isEmpty)
        #expect(archive.customShips.isEmpty)
        #expect(archive.hiddenCatalogItems.isEmpty)

        #expect(entries.contains("data.json"))
        #expect(entries.contains("images/\(cruiseID)/ports/0"))
        #expect(entries.contains("images/\(cruiseID)/0"))
    }

    @Test("share-Block trägt alle vier v1-Pflichtfelder inklusive Fingerprint")
    @MainActor
    func shareBlockIsComplete() async throws {
        let container = try makeFullContainer()
        let cruise = makeRichCruise(title: "Fingerabdruck", in: container.mainContext)
        try container.mainContext.save()

        let url = try await ExportImportService.shared.exportCruiseForSharing(cruise)
        defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }

        let (archive, _) = try readShareArchive(at: url)
        let share = try #require(archive.share)
        let shared = try #require(archive.cruises.first)

        #expect(share.shareFormatVersion == ExportShareInfo.currentShareFormatVersion)
        #expect(!share.sharedAt.isEmpty)
        #expect(!share.appVersion.isEmpty)
        // Sender-berechnet über genau diese Kreuzfahrt (C1) — nachrechenbar aus der Datei.
        let expected = try ShareFingerprint.contentFingerprint(for: shared)
        #expect(share.contentFingerprint == expected)
        #expect(share.contentFingerprint.count == 64)
    }

    @Test("Dateiname ist der Titel-Slug mit .shiptrip-Endung")
    @MainActor
    func fileNameUsesTitleSlug() async throws {
        let container = try makeFullContainer()
        let cruise = makeRichCruise(title: "Nordsee & Fjorde 2026", in: container.mainContext)
        try container.mainContext.save()

        let url = try await ExportImportService.shared.exportCruiseForSharing(cruise)
        defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }

        #expect(url.lastPathComponent == "Nordsee-Fjorde-2026.shiptrip")
    }

    @Test("Slug transliteriert Umlaute und fängt leere Titel ab")
    @MainActor
    func slugRules() {
        // Die Slugs vorab berechnen: `#expect` bekommt nur noch fertige Werte zu sehen,
        // keine Aufrufe, die die Makro-Expansion als potenziell werfend einstuft.
        let umlautSlug = ExportImportService.shareFileSlug(for: "Grönland & Färöer")
        let asciiSlug = ExportImportService.shareFileSlug(for: "Größe")
        let blankSlug = ExportImportService.shareFileSlug(for: "   ")
        let punctuationSlug = ExportImportService.shareFileSlug(for: "…")
        let asciiOnly = asciiSlug.allSatisfy { $0.isASCII }

        #expect(umlautSlug == "Gronland-Faroer")
        #expect(asciiOnly)
        #expect(blankSlug == "Kreuzfahrt")
        #expect(punctuationSlug == "Kreuzfahrt")
    }
}

// MARK: - Sperren und Grenzen

@Suite("Share-Export: Sperren und Grenzen")
struct ShareExportGuardTests {

    @Test("Beispielreise wird nicht geteilt")
    @MainActor
    func demoCruiseThrows() async throws {
        let container = try makeFullContainer()
        let cruise = makeRichCruise(title: "Beispielreise", in: container.mainContext)
        cruise.isDemo = true
        try container.mainContext.save()

        await #expect(throws: ShareExportError.self) {
            _ = try await ExportImportService.shared.exportCruiseForSharing(cruise)
        }
    }

    @Test("Zu viele Häfen brechen vor jeder Transcode-Arbeit ab")
    @MainActor
    func tooManyPortsThrows() async throws {
        let container = try makeFullContainer()
        let cruise = makeRichCruise(title: "Endlose Route", in: container.mainContext)
        for index in 0...ShareArchiveLimits.maxPorts {
            let port = CruisePort(name: "Hafen \(index)", country: "X", latitude: 0, longitude: 0)
            port.sortOrder = index + 10
            port.cruise = cruise
            container.mainContext.insert(port)
        }
        try container.mainContext.save()

        await #expect(throws: ShareExportError.self) {
            _ = try await ExportImportService.shared.exportCruiseForSharing(cruise)
        }
    }

    /// Alles-oder-nichts: ein nicht transkodierbares Bild bricht den Export ab, statt ein
    /// Archiv mit Datenloch zu erzeugen.
    @Test("Nicht transkodierbares Bild bricht den Export ab")
    @MainActor
    func transcodeFailureAbortsExport() async throws {
        let container = try makeFullContainer()
        let cruise = makeRichCruise(title: "Kaputtes Bild", in: container.mainContext)
        let broken = Photo(imageData: Data(repeating: 0x01, count: 128), sortOrder: 1)
        broken.cruise = cruise
        container.mainContext.insert(broken)
        try container.mainContext.save()

        await #expect(throws: ShareExportError.self) {
            _ = try await ExportImportService.shared.exportCruiseForSharing(cruise)
        }
    }
}

// MARK: - Verträglichkeit und Regression

@Suite("Share-Export: Verträglichkeit und Regression")
struct ShareExportCompatibilityTests {

    /// Eine `.shiptrip`-Datei ist ein Backup-Archiv (C1) — der Bestands-Import liest sie.
    @Test("Die Share-Datei ist ein gültiges Backup: der Bestands-Import liest sie")
    @MainActor
    func shareFileImportsThroughExistingBackupPath() async throws {
        let source = try makeFullContainer()
        let cruise = makeRichCruise(title: "Roundtrip", in: source.mainContext)
        try source.mainContext.save()
        let cruiseID = cruise.id

        let url = try await ExportImportService.shared.exportCruiseForSharing(cruise)
        defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }

        let target = try makeFullContainer()
        let result = try ExportImportService.shared.importFromZip(
            url: url, modelContext: target.mainContext
        )

        #expect(result.imported == 1)
        #expect(result.invalidMedia == 0)

        let imported = try target.mainContext.fetch(FetchDescriptor<Cruise>())
        #expect(imported.count == 1)
        #expect(imported.first?.id == cruiseID)
        #expect(imported.first?.route.count == 2)
        #expect(imported.first?.expenses.count == 1)
        #expect(imported.first?.photos.count == 1)
        // Bilder sind komprimiert, also nicht mehr das Original-PNG.
        #expect(imported.first?.photos.first?.imageData != onePixelPNG)
    }

    /// Regression: Der Share-Export fasst weder die Originale noch den Voll-Export an.
    @Test("Originale bleiben unangetastet und der Voll-Export trägt keinen share-Block")
    @MainActor
    func fullExportStaysUnchanged() async throws {
        let container = try makeFullContainer()
        let cruise = makeRichCruise(title: "Regression", in: container.mainContext)
        try container.mainContext.save()

        let shareURL = try await ExportImportService.shared.exportCruiseForSharing(cruise)
        defer { try? FileManager.default.removeItem(at: shareURL.deletingLastPathComponent()) }

        // Originale: verlustfrei in der Datenbank geblieben.
        #expect(cruise.photos.first?.imageData == onePixelPNG)
        #expect(cruise.route.first(where: { $0.name == "Palma" })?.imageData == onePixelPNG)

        // Voll-Export: unverändertes Backup-Format ohne `share`-Key.
        let zipURL = try await ExportImportService.shared.exportToZip(cruises: [cruise])
        defer { try? FileManager.default.removeItem(at: zipURL) }

        let unpacked = FileManager.default.temporaryDirectory
            .appendingPathComponent("backup-read-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: unpacked) }
        try ZipArchiveReader.extract(from: zipURL, to: unpacked)

        let json = try Data(contentsOf: unpacked.appendingPathComponent("data.json"))
        let text = try #require(String(data: json, encoding: .utf8))
        #expect(!text.contains("\"share\""))
        let backupArchive = try ExportArchive.decode(from: json)
        #expect(backupArchive.share == nil)

        // Und die Bilder im Backup sind weiterhin die Originalbytes, nicht die Share-JPEGs.
        let backupPhoto = try Data(contentsOf: unpacked
            .appendingPathComponent("images/\(cruise.id.uuidString)/0"))
        #expect(backupPhoto == onePixelPNG)
    }
}
