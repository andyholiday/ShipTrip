//
//  ImageDownsampler.swift
//  ShipTrip
//

import Foundation
import ImageIO
import UniformTypeIdentifiers

/// Erstellt kompakte Vorschaubilder aus Bilddaten ohne vollständiges Dekodieren.
/// Nutzt ImageIO `CGImageSourceCreateThumbnailAtIndex` – deutlich weniger
/// Speicherbedarf als `UIImage(data:)` für Full-Res-Daten.
enum ImageDownsampler {

    /// Erzeugt ein JPEG-Vorschaubild aus den gegebenen Bilddaten.
    /// - Parameters:
    ///   - data: Vollauflösende Bilddaten (JPEG, PNG, HEIC, …)
    ///   - maxPixelSize: Maximale Kantenlänge des Thumbnails in Punkten (Standard: 600)
    /// - Returns: JPEG-Daten des Thumbnails, oder `nil` bei Fehler.
    static func thumbnail(from data: Data, maxPixelSize: CGFloat = 600) -> Data? {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil) else {
            return nil
        }

        let options: [CFString: Any] = [
            kCGImageSourceThumbnailMaxPixelSize: maxPixelSize,
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceShouldCacheImmediately: false
        ]

        guard let cgImage = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) else {
            return nil
        }

        let destination = NSMutableData()
        guard let dest = CGImageDestinationCreateWithData(
            destination,
            UTType.jpeg.identifier as CFString,
            1,
            nil
        ) else {
            return nil
        }

        CGImageDestinationAddImage(dest, cgImage, [kCGImageDestinationLossyCompressionQuality: 0.75] as CFDictionary)
        guard CGImageDestinationFinalize(dest) else {
            return nil
        }

        return destination as Data
    }
}
