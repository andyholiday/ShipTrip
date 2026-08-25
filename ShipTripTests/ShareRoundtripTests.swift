//
//  ShareRoundtripTests.swift
//  ShipTripTests
//
//  Der Ende-zu-Ende-Beweis für „Kreuzfahrt teilen" (ZIEL-Kriterium 5): eine Reise mit Fotos
//  verlässt die App über `exportCruiseForSharing` (C5) und kommt in einem frischen App-Zustand
//  über den echten Share-Einstieg `importSharedCruise` (C6/C10) inhaltlich identisch wieder an.
//
//  Abgrenzung zu `ShareExportTests.shareFileImportsThroughExistingBackupPath`: dort wird nur
//  geprüft, dass der *Backup*-Import die Datei überhaupt liest. Hier läuft der Share-Pfad
//  inklusive Preflight, Fingerabdruck-Persistenz und Dedup — und der Abgleich geht über die
//  Zählwerte hinaus bis auf Feldebene.
//

import Testing
import Foundation
import SwiftData
import CoreGraphics
import ImageIO
import UniformTypeIdentifiers
@testable import ShipTrip

private typealias CruisePort = ShipTrip.Port

// MARK: - Fixture-Helfer

private struct RoundtripFixtureError: Error {}

/// Die Archivdatei speichert Reisedaten tagesgenau (`yyyy-MM-dd`, Formatter des Service).
/// Die Fixture-Daten entstehen deshalb über denselben Formatter — dann ist die Gleichheit der
/// `Date`-Werte nach dem Roundtrip eine ehrliche Zusicherung und keine Zeitzonen-Lotterie.
@MainActor
private func makeDate(_ string: String) -> Date {
    ExportImportService.shared.dateFormatter.date(from: string)
        ?? Date(timeIntervalSince1970: 0)
}

/// Ein echtes PNG mit langer Kante > 2048 px — damit die Verkleinerung des Transcoders (C4)
/// am Ergebnis messbar ist und nicht nur „irgendwie anders" aussieht.
private func makePNG(width: Int, height: Int) throws -> Data {
    guard let context = CGContext(
        data: nil,
        width: width,
        height: height,
        bitsPerComponent: 8,
        bytesPerRow: width * 4,
        space: CGColorSpaceCreateDeviceRGB(),
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
    ) else { throw RoundtripFixtureError() }

    context.setFillColor(red: 0.1, green: 0.4, blue: 0.8, alpha: 1)
    context.fill(CGRect(x: 0, y: 0, width: width, height: height))

    guard let image = context.makeImage() else { throw RoundtripFixtureError() }
    let buffer = NSMutableData()
    guard let destination = CGImageDestinationCreateWithData(
        buffer, UTType.png.identifier as CFString, 1, nil
    ) else { throw RoundtripFixtureError() }
    CGImageDestinationAddImage(destination, image, nil)
    guard CGImageDestinationFinalize(destination) else { throw RoundtripFixtureError() }
    return buffer as Data
}

/// Pixelmaße eines Bildes, ohne es zu dekodieren.
private func pixelSize(of data: Data) throws -> (width: Int, height: Int) {
    guard let source = CGImageSourceCreateWithData(data as CFData, nil),
          let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil)
            as? [CFString: Any],
          let width = properties[kCGImagePropertyPixelWidth] as? Int,
          let height = properties[kCGImagePropertyPixelHeight] as? Int
    else { throw RoundtripFixtureError() }
    return (width, height)
}

/// Die Reise, die geteilt wird: jedes Textfeld belegt, Route mit Hafenbild und Seetag,
/// mehrere Ausgaben, mehrere Fotos — damit der Abgleich etwas zu vergleichen hat.
@MainActor
private func makeRoundtripCruise(in context: ModelContext, photo: Data) -> Cruise {
    let cruise = Cruise(
        title: "Westliches Mittelmeer",
        startDate: makeDate("2026-05-01"),
        endDate: makeDate("2026-05-08"),
        shippingLine: "AIDA",
        ship: "AIDAnova"
    )
    cruise.cabinType = "Balkon"
    cruise.cabinNumber = "8210"
    cruise.bookingNumber = "BK-4711"
    cruise.notes = "Balkon backbord, Sonnenuntergänge über Málaga"
    cruise.rating = 4.5
    context.insert(cruise)

    let palma = CruisePort(name: "Palma", country: "Spanien", latitude: 39.57, longitude: 2.65)
    palma.sortOrder = 0
    palma.imageData = photo
    palma.cruise = cruise
    context.insert(palma)

    let seaDay = CruisePort(name: "Seetag", country: "Mittelmeer", latitude: 40.1, longitude: 4.2)
    seaDay.sortOrder = 1
    seaDay.isSeaDay = true
    seaDay.cruise = cruise
    context.insert(seaDay)

    let excursion = Expense(category: .excursion, amount: 89.5, description: "Kathedrale")
    excursion.cruise = cruise
    context.insert(excursion)

    let drinks = Expense(category: .onboard, amount: 12.4, description: "Cortado an Deck")
    drinks.cruise = cruise
    context.insert(drinks)

    for index in 0..<2 {
        let entry = Photo(imageData: photo, sortOrder: index)
        entry.cruise = cruise
        context.insert(entry)
    }

    return cruise
}

// MARK: - Roundtrip

@Suite("Teilen: Ende-zu-Ende-Roundtrip (ZIEL-Kriterium 5)")
@MainActor
struct ShareRoundtripTests {

    /// **Der Beweis für ZIEL-Kriterium 5.**
    ///
    /// Frischer App-Zustand: Der Ziel-`ModelContainer` wird neu und rein in-memory angelegt und
    /// vor dem Import als leer nachgewiesen — er teilt weder Store-Datei noch Kontext mit dem
    /// Sender. Das ist derselbe Ausgangspunkt wie eine frisch installierte App auf dem Gerät des
    /// Empfängers, nur ohne Simulator-Laufzeit.
    @Test("Eine geteilte Reise kommt im frischen App-Zustand inhaltlich identisch an")
    func sharedCruiseArrivesIdenticallyInFreshApp() async throws {
        let photo = try makePNG(width: 2600, height: 40)

        // --- Sender ---
        let source = try makeShareImportContainer()
        let cruise = makeRoundtripCruise(in: source.mainContext, photo: photo)
        // Deal und Reederei-Overlay liegen beim Sender, gehören aber nicht zur Reise:
        // eine `.shiptrip`-Datei trägt genau eine Kreuzfahrt und sonst nichts (C1).
        source.mainContext.insert(Deal(title: "Frühbucher-Rabatt"))
        source.mainContext.insert(CustomShippingLine(name: "Reederei Nord"))
        try source.mainContext.save()

        let expected = CruiseSnapshot(cruise)

        let url = try await ExportImportService.shared.exportCruiseForSharing(cruise)
        defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }

        // --- Frischer App-Zustand des Empfängers ---
        let target = try makeShareImportContainer()
        let context = ModelContext(target)
        let cruisesBefore = try context.fetch(FetchDescriptor<Cruise>())
        let dealsBefore = try context.fetch(FetchDescriptor<Deal>())
        #expect(cruisesBefore.isEmpty)
        #expect(dealsBefore.isEmpty)

        // --- Empfänger: der echte Share-Einstieg, nicht der Backup-Import ---
        let result = try await ExportImportService.shared.importSharedCruise(
            from: url, modelContext: context
        )
        #expect(result.base.imported == 1)
        #expect(result.base.skippedDuplicates == 0)
        #expect(result.base.skippedInvalid == 0)
        #expect(result.base.invalidMedia == 0)
        #expect(result.versionConflict == false)

        let cruises = try context.fetch(FetchDescriptor<Cruise>())
        #expect(cruises.count == 1)
        let arrived = try #require(cruises.first)

        // --- Inhaltlicher Abgleich: Felder ---
        #expect(CruiseSnapshot(arrived) == expected)
        #expect(arrived.isDemo == false)
        // Der Fingerabdruck der Datei ist an der Reise persistiert (C1) — Grundlage des
        // Versionskonflikt-Hinweises bei einem späteren Re-Import.
        #expect(arrived.shareContentFingerprint?.isEmpty == false)

        // --- Häfen ---
        let palma = try #require(arrived.route.first(where: { $0.name == "Palma" }))
        #expect(palma.country == "Spanien")
        #expect(palma.isSeaDay == false)
        #expect(palma.sortOrder == 0)
        #expect(abs(palma.latitude - 39.57) < 0.0001)
        #expect(abs(palma.longitude - 2.65) < 0.0001)
        let seaDay = try #require(arrived.route.first(where: { $0.isSeaDay }))
        #expect(seaDay.name == "Seetag")
        #expect(seaDay.sortOrder == 1)

        // --- Ausgaben ---
        #expect(Set(arrived.expenses.map(\.descriptionText)) == ["Kathedrale", "Cortado an Deck"])
        #expect(abs(arrived.totalExpenses - 101.9) < 0.0001)

        // --- Fotos: Anzahl gleich, Auflösung erwartungsgemäß reduziert (C4) ---
        #expect(arrived.photos.count == 2)
        for entry in arrived.photos {
            let size = try pixelSize(of: entry.imageData)
            #expect(size.width == 2048)
            #expect(size.height < 40)
            #expect(entry.imageData.count < photo.count)
        }
        let portImage = try #require(palma.imageData)
        let portImageSize = try pixelSize(of: portImage)
        #expect(portImageSize.width == 2048)

        // --- Bezüge, die nicht mitreisen: Deals und Katalog-Overlays bleiben beim Sender ---
        let dealsAfter = try context.fetch(FetchDescriptor<Deal>())
        let linesAfter = try context.fetch(FetchDescriptor<CustomShippingLine>())
        #expect(dealsAfter.isEmpty)
        #expect(linesAfter.isEmpty)

        // --- Sender unangetastet: Originalauflösung bleibt lokal erhalten ---
        #expect(cruise.photos.first?.imageData == photo)
    }

    /// Re-Import derselben Datei: Dedup greift, es entsteht keine zweite Reise, und weil der
    /// gespeicherte Fingerabdruck identisch ist, meldet der Import keinen Versionskonflikt.
    @Test("Ein zweiter Import derselben Datei legt keine zweite Reise an")
    func reimportOfSameFileIsDeduplicated() async throws {
        let photo = try makePNG(width: 2600, height: 40)

        let source = try makeShareImportContainer()
        let cruise = makeRoundtripCruise(in: source.mainContext, photo: photo)
        try source.mainContext.save()

        let url = try await ExportImportService.shared.exportCruiseForSharing(cruise)
        defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }

        let target = try makeShareImportContainer()
        let context = ModelContext(target)

        let first = try await ExportImportService.shared.importSharedCruise(
            from: url, modelContext: context
        )
        #expect(first.base.imported == 1)

        let second = try await ExportImportService.shared.importSharedCruise(
            from: url, modelContext: context
        )
        #expect(second.base.imported == 0)
        #expect(second.base.skippedDuplicates == 1)
        #expect(second.versionConflict == false)

        let cruises = try context.fetch(FetchDescriptor<Cruise>())
        #expect(cruises.count == 1)
        #expect(cruises.first?.photos.count == 2)
        #expect(cruises.first?.route.count == 2)
    }
}

// MARK: - Vergleichbarer Feld-Schnappschuss

/// Die Skalarfelder einer Kreuzfahrt als Wertetyp — damit der Abgleich „alles gleich" eine
/// einzige Zusicherung ist und nicht ein Dutzend einzelner.
private struct CruiseSnapshot: Equatable {
    let id: UUID
    let title: String
    let startDate: Date
    let endDate: Date
    let shippingLine: String
    let ship: String
    let cabinType: String
    let cabinNumber: String
    let bookingNumber: String
    let notes: String
    let rating: Double
    let portCount: Int
    let expenseCount: Int
    let photoCount: Int

    @MainActor
    init(_ cruise: Cruise) {
        id = cruise.id
        title = cruise.title
        startDate = cruise.startDate
        endDate = cruise.endDate
        shippingLine = cruise.shippingLine
        ship = cruise.ship
        cabinType = cruise.cabinType
        cabinNumber = cruise.cabinNumber
        bookingNumber = cruise.bookingNumber
        notes = cruise.notes
        rating = cruise.rating
        portCount = cruise.route.count
        expenseCount = cruise.expenses.count
        photoCount = cruise.photos.count
    }
}
