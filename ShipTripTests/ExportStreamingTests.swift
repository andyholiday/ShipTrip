//
//  ExportStreamingTests.swift
//  ShipTripTests
//
//  Speicherprofil des Exports (C4): Das Archiv wird strömend geschrieben, die Bild-Bytes
//  werden pro Eintrag nachgeladen. Beides ist im Unit-Host nicht als RSS-Messung beweisbar,
//  aber am beobachtbaren Verhalten: die Zieldatei wächst zwischen zwei Einträgen, und die
//  Bildquelle gibt Bytes ausschließlich einzeln und auf Anforderung heraus.
//

import Testing
import Foundation
import SwiftData
@testable import ShipTrip

private typealias CruisePort = ShipTrip.Port

/// Protokolliert die Größe der Zieldatei zum Zeitpunkt jeder Eintrags-Anforderung.
private actor OutputSizeLog {
    private(set) var sizes: [Int] = []

    func recordSize(of url: URL) {
        let attributes = try? FileManager.default.attributesOfItem(atPath: url.path)
        sizes.append(attributes?[.size] as? Int ?? 0)
    }
}

@Suite("Export: Streaming-Verhalten")
struct ExportStreamingTests {

    /// Der Beweis fürs Speicherprofil: `ZipArchiveStreamWriter` fordert die Bytes eines
    /// Eintrags erst an, wenn der vorherige bereits auf der Platte liegt. Würde der Writer wie
    /// zuvor erst alle Einträge einsammeln und dann ein `Data`-Archiv bauen, wäre die Zieldatei
    /// bei jeder Anforderung 0 Bytes groß.
    @Test("ZIP wächst zwischen den Einträgen: jeder Eintrag liegt vor dem nächsten auf der Platte")
    func zipIsWrittenIncrementally() async throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("export-streaming-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }

        let zipURL = directory.appendingPathComponent("stream.zip")
        let payload = Data(repeating: 0xAB, count: 256 * 1024)
        let log = OutputSizeLog()

        let entries = (0..<4).map { index in
            ZipArchiveStreamWriter.Entry(name: "images/\(index)") {
                await log.recordSize(of: zipURL)
                return payload
            }
        }

        try await ZipArchiveStreamWriter().write(entries: entries, to: zipURL)

        let sizes = await log.sizes
        #expect(sizes.count == 4)
        #expect(sizes.first == 0, "Vor dem ersten Eintrag ist die Datei leer")
        for index in 1..<sizes.count {
            #expect(
                sizes[index] >= index * payload.count,
                "Vor Eintrag \(index) müssen die \(index) vorherigen Einträge bereits geschrieben sein"
            )
        }

        // Und das Ergebnis ist trotzdem ein gültiges Archiv.
        let written = try Data(contentsOf: zipURL)
        #expect(written.prefix(4) == Data([0x50, 0x4B, 0x03, 0x04]))
        #expect(written.count > 4 * payload.count)
    }

    /// Die Bildquelle ist der Grund, warum der off-main laufende Writer keine `@Model`-Objekte
    /// braucht: sie kennt die Eintragsnamen ohne jedes Byte und liefert die Bytes einzeln nach.
    /// Der Test fixiert zugleich die Reihenfolge, auf die sich die Pfadreferenzen in `data.json`
    /// verlassen: erst die Hafenbilder einer Reise, dann ihre Fotos.
    @Test("ExportImageSource kennt die Einträge ohne Bytes und liefert sie einzeln")
    @MainActor
    func imageSourceHandsOutOneImageAtATime() throws {
        let schema = Schema([
            Cruise.self, CruisePort.self, Expense.self, Deal.self, Photo.self,
            CustomShippingLine.self, CustomShip.self, HiddenCatalogItem.self
        ])
        let container = try ModelContainer(
            for: schema, configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        let context = container.mainContext

        let cruise = Cruise(
            title: "Streaming",
            startDate: Date(timeIntervalSince1970: 0),
            endDate: Date(timeIntervalSince1970: 86_400),
            shippingLine: "AIDA",
            ship: "AIDAnova"
        )
        context.insert(cruise)

        let portImage = Data(repeating: 0x01, count: 128)
        let port = CruisePort(name: "Palma", country: "Spanien", latitude: 39.57, longitude: 2.65)
        port.imageData = portImage
        port.cruise = cruise
        context.insert(port)

        let firstPhotoBytes = Data(repeating: 0x02, count: 256)
        let secondPhotoBytes = Data(repeating: 0x03, count: 512)
        for (order, bytes) in [firstPhotoBytes, secondPhotoBytes].enumerated() {
            let photo = Photo(imageData: bytes, sortOrder: order)
            photo.cruise = cruise
            context.insert(photo)
        }
        try context.save()

        let source = ExportImageSource(cruises: [cruise])
        let cruiseID = cruise.id.uuidString

        #expect(source.entryNames == [
            "images/\(cruiseID)/ports/0",
            "images/\(cruiseID)/0",
            "images/\(cruiseID)/1"
        ])
        #expect(try source.data(at: 0) == portImage)
        #expect(try source.data(at: 1) == firstPhotoBytes)
        #expect(try source.data(at: 2) == secondPhotoBytes)
    }
}
