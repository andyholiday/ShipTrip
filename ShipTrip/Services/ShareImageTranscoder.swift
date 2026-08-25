//
//  ShareImageTranscoder.swift
//  ShipTrip
//
//  Foto-Kompression für geteilte Kreuzfahrten (Contract C4). Nur der Share-Pfad benutzt
//  diesen Transcoder — Originale und das verlustfreie Voll-Backup bleiben unangetastet.
//

import Foundation
import ImageIO
import UniformTypeIdentifiers

// MARK: - Share-Transcoder

/// Reine, nonisolierte Funktion (`Data` rein, `Data` raus — damit Sendable-sicher und
/// off-main aufrufbar). Aufgebaut nach dem Muster von `ImageDownsampler`.
enum ShareImageTranscoder {

    /// Verkleinert auf max. `maxPixelSize` lange Kante und encodiert als JPEG.
    ///
    /// - Quelle bereits kleiner → **kein Upscaling**, aber Re-Encode als JPEG.
    /// - Das Ausgabe-JPEG trägt **keine** Quell-Metadaten: EXIF (insbesondere GPS), IPTC,
    ///   XMP und Maker Notes bleiben zurück, weil die Ausgabe aus dem nackten `CGImage`
    ///   plus genau einer selbst gesetzten Eigenschaft (Qualität) entsteht — die Quell-
    ///   Properties werden nie übertragen. Die Orientierung ist über
    ///   `…CreateThumbnailWithTransform` in die Pixel eingebrannt, ein Orientation-Tag
    ///   ist damit nicht nötig.
    /// - Returns: `nil`, wenn die Eingabe kein dekodierbares Bild ist oder der Encode
    ///   fehlschlägt.
    static func downscaledJPEG(
        from data: Data,
        maxPixelSize: CGFloat = 2048,
        quality: CGFloat = 0.8
    ) -> Data? {
        // `CGImageSourceCreateWithData` ist lazy und liefert auch für Nicht-Bilder ein
        // Objekt zurück; erst die Bildanzahl beantwortet, ob überhaupt etwas dekodierbar ist.
        guard let source = CGImageSourceCreateWithData(data as CFData, nil),
              CGImageSourceGetCount(source) > 0 else {
            return nil
        }

        let options: [CFString: Any] = [
            kCGImageSourceThumbnailMaxPixelSize: maxPixelSize,
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceShouldCacheImmediately: false
        ]

        guard let cgImage = CGImageSourceCreateThumbnailAtIndex(
            source, 0, options as CFDictionary
        ) else {
            return nil
        }

        let output = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(
            output,
            UTType.jpeg.identifier as CFString,
            1,
            nil
        ) else {
            return nil
        }

        CGImageDestinationAddImage(
            destination,
            cgImage,
            [kCGImageDestinationLossyCompressionQuality: quality] as CFDictionary
        )
        guard CGImageDestinationFinalize(destination) else {
            return nil
        }

        return output as Data
    }
}
