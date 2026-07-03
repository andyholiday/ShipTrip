//
//  ZipArchiveReader.swift
//  ShipTrip
//
//  Created by ShipTrip on 19.12.25.
//

import Foundation
import Compression

// MARK: - ZIP Extraction

/// Extrahiert ZIP-Archive für `ExportImportService.importFromZip` (STORED + Deflate, gehärtet
/// gegen Zip-Slip und Dekompressionsbomben).
enum ZipArchiveReader {
    /// Maximale unkomprimierte Größe eines einzelnen ZIP-Eintrags (Dekompressionsbomben-Schutz).
    static let maxEntryUncompressedSize = 50 * 1024 * 1024

    /// Maximale kumulierte unkomprimierte Größe aller Einträge eines Archivs.
    static let maxTotalUncompressedSize = 500 * 1024 * 1024

    /// Maximale Größe der ZIP-Datei selbst (konsistent zum 500-MB-Gesamtlimit + Overhead).
    /// Wird geprüft, BEVOR das Archiv überhaupt in den Speicher gelesen wird.
    static let maxArchiveFileSize = 550 * 1024 * 1024

    /// Löst einen aus dem Archiv bzw. aus `data.json` stammenden, nicht vertrauenswürdigen
    /// relativen Pfad sicher gegen ein Basisverzeichnis auf (Zip-Slip-Schutz).
    /// Lehnt leere/absolute Pfade sowie jede Auflösung außerhalb von `baseURL` ab.
    static func resolveSafePath(_ relativePath: String, in baseURL: URL) throws -> URL {
        guard !relativePath.isEmpty, !relativePath.hasPrefix("/"), !relativePath.hasPrefix("~") else {
            throw ExportImportService.ImportError.unsafePath(relativePath)
        }
        guard !relativePath.contains("\\") else {
            throw ExportImportService.ImportError.unsafePath(relativePath)
        }

        // Rohe POSIX-Komponenten VOR jeder Standardisierung prüfen: Traversal-Aliase wie
        // "foo/../data.json" dürfen nicht erst NACH dem Normalisieren erkannt werden, weil das
        // Ergebnis rein zufällig wieder innerhalb von baseURL landen kann. Ein einzelner
        // Trailing-Slash markiert ein Verzeichnis (ZIP-Konvention) und wird vorher entfernt.
        let trimmed = relativePath.hasSuffix("/") ? String(relativePath.dropLast()) : relativePath
        guard !trimmed.isEmpty else {
            throw ExportImportService.ImportError.unsafePath(relativePath)
        }
        for component in trimmed.split(separator: "/", omittingEmptySubsequences: false) {
            guard !component.isEmpty, component != ".", component != ".." else {
                throw ExportImportService.ImportError.unsafePath(relativePath)
            }
        }

        // Defense-in-Depth: zusätzlich sicherstellen, dass die standardisierte Auflösung
        // innerhalb von baseURL bleibt.
        let base = baseURL.standardizedFileURL
        let candidate = base.appendingPathComponent(relativePath).standardizedFileURL

        let baseComponents = base.pathComponents
        let candidateComponents = candidate.pathComponents
        guard candidateComponents.count > baseComponents.count,
              Array(candidateComponents.prefix(baseComponents.count)) == baseComponents else {
            throw ExportImportService.ImportError.unsafePath(relativePath)
        }

        return candidate
    }

    static func extract(from sourceURL: URL, to destinationURL: URL) throws {
        // Archiv-Dateigröße prüfen, BEVOR irgendetwas in den Speicher gelesen wird (die Datei wird
        // sonst zweimal komplett als Data eingelesen, bevor der Central-Directory-Check greift).
        let attributes = try FileManager.default.attributesOfItem(atPath: sourceURL.path)
        let fileSize = attributes[.size] as? Int ?? 0
        guard fileSize <= ZipArchiveReader.maxArchiveFileSize else {
            throw ExportImportService.ImportError.archiveTooLarge(fileSize)
        }

        let zipData = try Data(contentsOf: sourceURL)
        let tempZipPath = destinationURL.appendingPathComponent("temp.zip")
        try zipData.write(to: tempZipPath)

        try parseAndExtractZip(from: tempZipPath, to: destinationURL)

        try? FileManager.default.removeItem(at: tempZipPath)
    }

    private static func parseAndExtractZip(from zipURL: URL, to destURL: URL) throws {
        guard let data = try? Data(contentsOf: zipURL) else {
            throw ExportImportService.ImportError.invalidFormat
        }

        guard data.count > 22 else { throw ExportImportService.ImportError.invalidFormat }

        var eocdOffset: Int?
        for i in stride(from: data.count - 22, through: Swift.max(0, data.count - 65557), by: -1) {
            if data[i] == 0x50 && data[i+1] == 0x4B && data[i+2] == 0x05 && data[i+3] == 0x06 {
                eocdOffset = i
                break
            }
        }

        guard let eocd = eocdOffset else { throw ExportImportService.ImportError.invalidFormat }

        let cdOffset = Int(data[eocd + 16]) | (Int(data[eocd + 17]) << 8) | (Int(data[eocd + 18]) << 16) | (Int(data[eocd + 19]) << 24)
        let numEntries = Int(data[eocd + 10]) | (Int(data[eocd + 11]) << 8)

        var offset = cdOffset
        var cumulativeUncompressedSize = 0
        var cumulativeCompressedSize = 0
        for _ in 0..<numEntries {
            guard offset + 46 <= data.count else { break }

            guard data[offset] == 0x50 && data[offset+1] == 0x4B && data[offset+2] == 0x01 && data[offset+3] == 0x02 else { break }

            let compressionMethod = Int(data[offset + 10]) | (Int(data[offset + 11]) << 8)
            let compressedSize = Int(data[offset + 20]) | (Int(data[offset + 21]) << 8) | (Int(data[offset + 22]) << 16) | (Int(data[offset + 23]) << 24)
            let uncompressedSize = Int(data[offset + 24]) | (Int(data[offset + 25]) << 8) | (Int(data[offset + 26]) << 16) | (Int(data[offset + 27]) << 24)
            let nameLength = Int(data[offset + 28]) | (Int(data[offset + 29]) << 8)
            let extraLength = Int(data[offset + 30]) | (Int(data[offset + 31]) << 8)
            let commentLength = Int(data[offset + 32]) | (Int(data[offset + 33]) << 8)
            let localHeaderOffset = Int(data[offset + 42]) | (Int(data[offset + 43]) << 8) | (Int(data[offset + 44]) << 16) | (Int(data[offset + 45]) << 24)

            guard offset + 46 + nameLength <= data.count else { break }

            let nameData = data[offset + 46 ..< offset + 46 + nameLength]
            let name = String(data: nameData, encoding: .utf8) ?? ""

            // Größen-Limits: aus dem Header geprüft, bevor irgendetwas dekomprimiert/allokiert/kopiert wird.
            // WICHTIG: die Extraktion liest tatsächlich `compressedSize` Bytes (Data-Kopie) und schreibt
            // sie bei STORED direkt weg — ein Header mit kleinem uncompressedSize, aber großem
            // compressedSize, würde die Limits sonst umgehen. Deshalb wird compressedSize genauso geprüft.
            guard uncompressedSize <= ZipArchiveReader.maxEntryUncompressedSize else {
                throw ExportImportService.ImportError.entryTooLarge(name: name, size: uncompressedSize)
            }
            guard compressedSize <= ZipArchiveReader.maxEntryUncompressedSize else {
                throw ExportImportService.ImportError.entryTooLarge(name: name, size: compressedSize)
            }
            if compressionMethod == 0 {
                // STORED: unkomprimiert, compressedSize muss zwingend uncompressedSize entsprechen.
                guard compressedSize == uncompressedSize else {
                    throw ExportImportService.ImportError.sizeMismatch(name: name)
                }
            }
            cumulativeUncompressedSize += uncompressedSize
            guard cumulativeUncompressedSize <= ZipArchiveReader.maxTotalUncompressedSize else {
                throw ExportImportService.ImportError.archiveTooLarge(cumulativeUncompressedSize)
            }
            cumulativeCompressedSize += compressedSize
            guard cumulativeCompressedSize <= ZipArchiveReader.maxTotalUncompressedSize else {
                throw ExportImportService.ImportError.archiveTooLarge(cumulativeCompressedSize)
            }

            let isDirectory = name.hasSuffix("/")
            let destinationPath = try resolveSafePath(name, in: destURL)

            if isDirectory {
                try FileManager.default.createDirectory(at: destinationPath, withIntermediateDirectories: true)
            } else {
                try FileManager.default.createDirectory(at: destinationPath.deletingLastPathComponent(), withIntermediateDirectories: true)

                guard localHeaderOffset + 30 <= data.count else { continue }
                let localNameLength = Int(data[localHeaderOffset + 26]) | (Int(data[localHeaderOffset + 27]) << 8)
                let localExtraLength = Int(data[localHeaderOffset + 28]) | (Int(data[localHeaderOffset + 29]) << 8)

                let dataOffset = localHeaderOffset + 30 + localNameLength + localExtraLength

                if dataOffset + compressedSize <= data.count {
                    let compressedData = Data(data[dataOffset ..< dataOffset + compressedSize])

                    var fileData: Data?
                    if compressionMethod == 0 {
                        fileData = compressedData
                    } else if compressionMethod == 8 {
                        fileData = decompressDeflate(compressedData, uncompressedSize: uncompressedSize)
                    }

                    if let fileData = fileData {
                        try fileData.write(to: destinationPath)
                    }
                }
            }

            offset += 46 + nameLength + extraLength + commentLength
        }
    }

    private static func decompressDeflate(_ data: Data, uncompressedSize: Int) -> Data? {
        // Verteidigung in der Tiefe: der Aufrufer prüft uncompressedSize bereits gegen
        // maxEntryUncompressedSize, bevor allokiert wird — diese Funktion darf aber nie
        // mit einer untrusted Größe über dem Limit aufgerufen werden.
        guard uncompressedSize > 0, uncompressedSize <= ZipArchiveReader.maxEntryUncompressedSize else { return nil }

        let destBuffer = UnsafeMutablePointer<UInt8>.allocate(capacity: uncompressedSize)
        defer { destBuffer.deallocate() }

        let decodedSize = data.withUnsafeBytes { (srcPtr: UnsafeRawBufferPointer) -> Int in
            guard let baseAddress = srcPtr.baseAddress else { return 0 }
            return compression_decode_buffer(
                destBuffer,
                uncompressedSize,
                baseAddress.assumingMemoryBound(to: UInt8.self),
                data.count,
                nil,
                COMPRESSION_ZLIB
            )
        }

        guard decodedSize > 0 else { return nil }
        return Data(bytes: destBuffer, count: decodedSize)
    }
}
