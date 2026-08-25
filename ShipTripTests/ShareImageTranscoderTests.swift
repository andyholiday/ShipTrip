//
//  ShareImageTranscoderTests.swift
//  ShipTripTests
//
//  Foto-Kompression fürs Teilen (Contract C4): Maße, Orientierung, kein Upscaling und —
//  die Datenschutz-Zusage — ein metadatenfreies Ausgabe-JPEG.
//

import Testing
import Foundation
import ImageIO
import UniformTypeIdentifiers
@testable import ShipTrip

// MARK: - Fixture-Helfer

/// Erzeugt ein JPEG programmatisch (keine Binär-Fixtures im Repo). `properties` landen
/// unverändert im Ziel — damit lassen sich GPS-/EXIF-/Orientierungs-Fälle bauen.
private func makeJPEG(width: Int, height: Int, properties: [CFString: Any] = [:]) -> Data? {
    guard let context = CGContext(
        data: nil,
        width: width,
        height: height,
        bitsPerComponent: 8,
        bytesPerRow: 0,
        space: CGColorSpaceCreateDeviceRGB(),
        bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue
    ) else { return nil }
    context.setFillColor(red: 0.1, green: 0.4, blue: 0.8, alpha: 1)
    context.fill(CGRect(x: 0, y: 0, width: width, height: height))
    guard let image = context.makeImage() else { return nil }

    let output = NSMutableData()
    guard let destination = CGImageDestinationCreateWithData(
        output, UTType.jpeg.identifier as CFString, 1, nil
    ) else { return nil }

    var merged = properties
    merged[kCGImageDestinationLossyCompressionQuality] = 0.9
    CGImageDestinationAddImage(destination, image, merged as CFDictionary)
    guard CGImageDestinationFinalize(destination) else { return nil }
    return output as Data
}

/// Bild-Eigenschaften der Ausgabe. `CGImageSourceCreateWithData` arbeitet lazy und liefert
/// auch für Datenmüll ein Objekt — deshalb prüft der Helfer zuerst die Bildanzahl.
private func imageProperties(of data: Data) -> [CFString: Any]? {
    guard let source = CGImageSourceCreateWithData(data as CFData, nil),
          CGImageSourceGetCount(source) > 0 else { return nil }
    return CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any]
}

private func pixelSize(of data: Data) -> (width: Int, height: Int)? {
    guard let properties = imageProperties(of: data),
          let width = properties[kCGImagePropertyPixelWidth] as? Int,
          let height = properties[kCGImagePropertyPixelHeight] as? Int else { return nil }
    return (width, height)
}

// MARK: - Tests

@Suite("Share: Foto-Transcoder")
struct ShareImageTranscoderTests {

    @Test("Große Bilder werden auf 2048 px lange Kante verkleinert")
    func downscalesToLongEdge() throws {
        let source = try #require(makeJPEG(width: 3000, height: 1500))
        let output = try #require(ShareImageTranscoder.downscaledJPEG(from: source))

        let size = try #require(pixelSize(of: output))
        #expect(size.width == 2048)
        // Seitenverhältnis bleibt erhalten (Rundung auf ganze Pixel zugelassen).
        #expect(abs(size.height - 1024) <= 1)
    }

    @Test("Kleinere Bilder werden nicht hochskaliert")
    func doesNotUpscale() throws {
        let source = try #require(makeJPEG(width: 64, height: 48))
        let output = try #require(ShareImageTranscoder.downscaledJPEG(from: source))

        let size = try #require(pixelSize(of: output))
        #expect(size.width == 64)
        #expect(size.height == 48)
    }

    /// Orientation 6 = 90° gedreht: 120×60 Speicherpixel werden als 60×120 angezeigt. Die
    /// Ausgabe muss die Drehung in den Pixeln tragen, weil sie kein Orientation-Tag mehr hat.
    @Test("EXIF-Orientierung wird in die Pixel eingebrannt")
    func bakesOrientationIntoPixels() throws {
        let source = try #require(makeJPEG(
            width: 120, height: 60, properties: [kCGImagePropertyOrientation: 6]
        ))
        #expect(imageProperties(of: source)?[kCGImagePropertyOrientation] as? Int == 6)

        let output = try #require(ShareImageTranscoder.downscaledJPEG(from: source))
        let size = try #require(pixelSize(of: output))
        #expect(size.width == 60)
        #expect(size.height == 120)
    }

    /// Pflicht-Test aus Contract C4: geteilte Bilder verraten keinen Aufnahmeort.
    @Test("Alle Quell-Metadaten sind entfernt: kein GPS, keine EXIF-/TIFF-Quellwerte")
    func stripsAllSourceMetadata() throws {
        let source = try #require(makeJPEG(width: 200, height: 150, properties: [
            kCGImagePropertyGPSDictionary: [
                kCGImagePropertyGPSLatitude: 53.5511,
                kCGImagePropertyGPSLatitudeRef: "N",
                kCGImagePropertyGPSLongitude: 9.9937,
                kCGImagePropertyGPSLongitudeRef: "E"
            ] as [CFString: Any],
            kCGImagePropertyExifDictionary: [
                kCGImagePropertyExifDateTimeOriginal: "2026:08:25 12:00:00",
                kCGImagePropertyExifUserComment: "Aufnahmenotiz"
            ] as [CFString: Any],
            kCGImagePropertyTIFFDictionary: [
                kCGImagePropertyTIFFMake: "ShipTrip",
                kCGImagePropertyTIFFModel: "Fixture-Kamera"
            ] as [CFString: Any]
        ]))

        // Der Test wäre wertlos, wenn die Fixture die Metadaten gar nicht erst trüge.
        let sourceProperties = try #require(imageProperties(of: source))
        #expect(sourceProperties.keys.contains(kCGImagePropertyGPSDictionary))

        let output = try #require(ShareImageTranscoder.downscaledJPEG(from: source))
        let properties = try #require(imageProperties(of: output))

        #expect(!properties.keys.contains(kCGImagePropertyGPSDictionary), "GPS-Block muss fehlen")

        let exif = properties[kCGImagePropertyExifDictionary] as? [CFString: Any]
        #expect(exif?.keys.contains(kCGImagePropertyExifDateTimeOriginal) != true)
        #expect(exif?.keys.contains(kCGImagePropertyExifUserComment) != true)

        let tiff = properties[kCGImagePropertyTIFFDictionary] as? [CFString: Any]
        #expect(tiff?.keys.contains(kCGImagePropertyTIFFMake) != true)
        #expect(tiff?.keys.contains(kCGImagePropertyTIFFModel) != true)
    }

    @Test("Nicht dekodierbare Eingabe ergibt nil")
    func returnsNilForNonImage() {
        #expect(ShareImageTranscoder.downscaledJPEG(from: Data("kein Bild".utf8)) == nil)
        #expect(ShareImageTranscoder.downscaledJPEG(from: Data()) == nil)
    }

    @Test("Die Ausgabe ist ein JPEG, nicht das Quellformat")
    func outputIsJPEG() throws {
        // PNG-Quelle (1×1) — die Ausgabe muss trotzdem als JPEG erkannt werden.
        let png = try #require(Data(base64Encoded:
            "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8/5+hHgAHggJ/PchI6QAAAABJRU5ErkJggg=="
        ))
        let output = try #require(ShareImageTranscoder.downscaledJPEG(from: png))

        // JPEG SOI-Marker statt Typ-Abfrage: eindeutig und ohne CF-Bridging.
        #expect(output.prefix(2) == Data([0xFF, 0xD8]))
        #expect(pixelSize(of: output)?.width == 1)
    }
}
