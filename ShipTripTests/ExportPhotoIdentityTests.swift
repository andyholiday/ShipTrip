//
//  ExportPhotoIdentityTests.swift
//  ShipTripTests
//
//  Foto-Identität beim Import: stabile `Photo.id` aus der Datei darf nie doppelt vergeben
//  werden — weder über zwei Kreuzfahrten desselben Archivs hinweg noch gegen Fotos, die
//  bereits in der Datenbank liegen (CloudKit-Dedup läuft über genau diese id, ADR-002).
//

import Testing
import Foundation
import SwiftData
@testable import ShipTrip

private typealias CruisePort = ShipTrip.Port

private func makeFullContainer() throws -> ModelContainer {
    let schema = Schema([
        Cruise.self, CruisePort.self, Expense.self, Deal.self, Photo.self,
        CustomShippingLine.self, CustomShip.self, HiddenCatalogItem.self
    ])
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    return try ModelContainer(for: schema, configurations: config)
}

/// Minimales gültiges PNG (1×1 weißes Pixel) — der Import validiert Bilddaten via ImageIO.
private let onePixelPNGBase64 =
    "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8/5+hHgAHggJ/PchI6QAAAABJRU5ErkJggg=="

// Fixture-Literal im Test: die Konstante ist gültiges Base64.
private let onePixelPNG = Data(base64Encoded: onePixelPNGBase64)!

private let photoDataURL = "data:image/png;base64,\(onePixelPNGBase64)"

private func makeExportCruise(title: String, photoIDs: [UUID]) -> ExportCruise {
    ExportCruise(
        id: UUID().uuidString,
        title: title,
        startDate: "2026-04-01",
        endDate: "2026-04-08",
        shippingLine: "AIDA",
        ship: "AIDAnova",
        cabinType: nil,
        cabinNumber: nil,
        bookingNumber: nil,
        notes: nil,
        rating: 4,
        route: [],
        photos: photoIDs.map { ExportPhoto(id: $0.uuidString, ref: photoDataURL) },
        expenses: []
    )
}

/// Schreibt das Archiv als JSON-Datei und gibt die URL zurück (Aufräumen beim Aufrufer).
private func writeArchiveJSON(_ archive: ExportArchive) throws -> URL {
    let url = FileManager.default.temporaryDirectory
        .appendingPathComponent("photo-identity-\(UUID().uuidString).json")
    try JSONEncoder().encode(archive).write(to: url)
    return url
}

@Suite("Import: Foto-Identität bleibt archivweit eindeutig")
struct ExportPhotoIdentityTests {

    /// REPRO (rot vor dem Fix): `seenPhotoIDs` galt nur pro Kreuzfahrt — dieselbe Foto-id in zwei
    /// Reisen desselben Archivs erzeugte zwei Photo-Objekte mit identischer stabiler ID.
    @Test("Gleiche Foto-ID in zwei Reisen desselben Archivs: nur ein Foto behält die Datei-ID")
    @MainActor
    func duplicatePhotoIDAcrossTwoCruisesStaysUnique() throws {
        let sharedPhotoID = UUID()
        let archive = ExportArchive(cruises: [
            makeExportCruise(title: "Erste Reise", photoIDs: [sharedPhotoID]),
            makeExportCruise(title: "Zweite Reise", photoIDs: [sharedPhotoID])
        ])

        let url = try writeArchiveJSON(archive)
        defer { try? FileManager.default.removeItem(at: url) }

        let container = try makeFullContainer()
        let context = container.mainContext

        let result = try ExportImportService.shared.importFromJSON(url: url, modelContext: context)
        #expect(result.imported == 2)
        #expect(result.invalidMedia == 0)

        // Beide Fotos werden importiert — die Kollision kostet nur die Datei-Identität,
        // nicht das Foto.
        let photos = try context.fetch(FetchDescriptor<Photo>())
        #expect(photos.count == 2)
        #expect(Set(photos.map(\.id)).count == 2, "Zwei Fotos dürfen nie dieselbe stabile ID tragen")
        #expect(photos.filter { $0.id == sharedPhotoID }.count == 1)
        #expect(photos.allSatisfy { $0.imageData == onePixelPNG })
    }

    /// REPRO (rot vor dem Fix): das Seen-Set kannte die Datenbank nicht — eine Foto-id, die schon
    /// an einem bestehenden Foto hing, wurde beim Import ein zweites Mal vergeben.
    @Test("Foto-ID kollidiert mit bestehendem DB-Foto: das importierte Foto bekommt eine neue ID")
    @MainActor
    func photoIDCollidingWithExistingDatabasePhotoGetsFreshID() throws {
        let container = try makeFullContainer()
        let context = container.mainContext

        // Bestandsfoto an einer bereits vorhandenen Reise.
        let existingCruise = Cruise(
            title: "Bestandsreise",
            startDate: Date(),
            endDate: Date(),
            shippingLine: "MSC",
            ship: "MSC World Europa"
        )
        context.insert(existingCruise)
        let existingPhoto = Photo(imageData: onePixelPNG, sortOrder: 0)
        existingPhoto.cruise = existingCruise
        context.insert(existingPhoto)
        try context.save()

        let collidingID = existingPhoto.id

        // Fremdes Archiv mit einer anderen Reise, aber derselben Foto-ID.
        let archive = ExportArchive(cruises: [
            makeExportCruise(title: "Fremde Reise", photoIDs: [collidingID])
        ])
        let url = try writeArchiveJSON(archive)
        defer { try? FileManager.default.removeItem(at: url) }

        let result = try ExportImportService.shared.importFromJSON(url: url, modelContext: context)
        #expect(result.imported == 1)

        let photos = try context.fetch(FetchDescriptor<Photo>())
        #expect(photos.count == 2)
        #expect(Set(photos.map(\.id)).count == 2, "Bestehende Foto-ID nie erneut vergeben")
        #expect(photos.filter { $0.id == collidingID }.count == 1)

        // Das Bestandsfoto behält seine ID; das importierte hat eine frische.
        let importedPhoto = try #require(photos.first { $0.cruise?.title == "Fremde Reise" })
        #expect(importedPhoto.id != collidingID)
    }
}
