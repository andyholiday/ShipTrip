//
//  ZipArchiveWriter.swift
//  ShipTrip
//
//  Created by ShipTrip on 19.12.25.
//

import Foundation

// MARK: - ZIP Writer (Method 0 / STORED, kein Deflate)

/// Baut ZIP-Archive für `ExportImportService.exportToZip` (Compression Method 0 / STORED, kein Deflate).
enum ZipArchiveWriter {
    /// Baut ein ZIP-Archiv aus einer Liste von (Name, Daten)-Einträgen.
    ///
    /// Format: Compression Method 0 (STORED). Jeder Eintrag enthält:
    /// - Local File Header (30 Bytes + Name)
    /// - Datei-Daten (unkomprimiert)
    ///
    /// Nach allen Einträgen folgen:
    /// - Central Directory (46 Bytes + Name pro Eintrag)
    /// - End of Central Directory (22 Bytes)
    ///
    /// CRC-32 wird nach dem IEEE 802.3-Polynom (0xEDB88320, reflected) berechnet.
    ///
    /// ANNAHME (Größenbeschränkung): Alle Größen und Offsets passen in UInt32 (<4 GB).
    /// Für Kreuzfahrt-Exporte realistisch; kein ZIP64-Support.
    /// Gecachte Metadaten eines ZIP-Eintrags nach dem ersten Durchlauf.
    private struct ZipEntryMeta {
        let nameData: Data
        let crc: UInt32
        let size: UInt32
        let localHeaderOffset: UInt32
    }

    static func build(entries: [(name: String, data: Data)]) throws -> Data {
        // ZIP-Überlaufschutz: UInt16 begrenzt die Eintragsanzahl, UInt32 die Einzelgröße.
        // Lieber explizit werfen als still truncaten — das ist ein Backup-Feature.
        guard entries.count <= Int(UInt16.max) else {
            throw ZipWriterError.tooManyEntries(entries.count)
        }
        for (name, data) in entries where data.count > Int(UInt32.max) {
            throw ZipWriterError.entryTooLarge(name: name, size: data.count)
        }

        var archive = Data()

        // Modifiziertes Datum/Zeit für alle Einträge (aktuell, DOS-Format)
        let (dosDate, dosTime) = currentDosDateTime()

        // Erster Durchlauf: Local File Headers schreiben und Metadaten cachen.
        // CRC-32 und Größe werden hier EINMALIG berechnet und im Cache gehalten,
        // damit der Central-Directory-Durchlauf dieselben Werte verwendet —
        // keine zweite Berechnung, kein möglicher Widerspruch.
        var metas: [ZipEntryMeta] = []
        metas.reserveCapacity(entries.count)

        for (name, fileData) in entries {
            guard let nameData = name.data(using: .utf8) else {
                throw ZipWriterError.invalidEntryName(name)
            }

            let crc = CRC32.checksum(fileData)
            let size = UInt32(fileData.count)
            guard archive.count <= Int(UInt32.max) else {
                throw ZipWriterError.archiveTooLarge(archive.count)
            }
            let localHeaderOffset = UInt32(archive.count)

            metas.append(ZipEntryMeta(
                nameData: nameData,
                crc: crc,
                size: size,
                localHeaderOffset: localHeaderOffset
            ))

            // Local File Header
            // Offset  Länge  Bedeutung
            //  0       4     Signatur 0x04034B50
            //  4       2     Version needed (20 = 2.0)
            //  6       2     General purpose bit flag
            //  8       2     Compression method (0 = STORED)
            // 10       2     Last mod file time (DOS)
            // 12       2     Last mod file date (DOS)
            // 14       4     CRC-32
            // 18       4     Compressed size
            // 22       4     Uncompressed size
            // 26       2     File name length
            // 28       2     Extra field length
            // 30       n     File name
            // 30+n     m     Extra field (leer)
            // 30+n+m   s     File data
            archive.append(contentsOf: [0x50, 0x4B, 0x03, 0x04])          // Signatur
            archive.appendUInt16LE(20)                                      // Version needed
            archive.appendUInt16LE(0)                                       // Bit flag
            archive.appendUInt16LE(0)                                       // Compression: STORED
            archive.appendUInt16LE(dosTime)                                 // Mod time
            archive.appendUInt16LE(dosDate)                                 // Mod date
            archive.appendUInt32LE(crc)                                     // CRC-32
            archive.appendUInt32LE(size)                                    // Compressed size
            archive.appendUInt32LE(size)                                    // Uncompressed size
            archive.appendUInt16LE(UInt16(nameData.count))                  // Name length
            archive.appendUInt16LE(0)                                       // Extra field length
            archive.append(nameData)                                        // File name
            archive.append(fileData)                                        // File data
        }

        guard archive.count <= Int(UInt32.max) else {
            throw ZipWriterError.archiveTooLarge(archive.count)
        }
        let centralDirOffset = archive.count

        // Zweiter Durchlauf: Central Directory aus dem Cache schreiben.
        // Kein erneuter Zugriff auf fileData; alle Werte kommen aus ZipEntryMeta.
        for meta in metas {
            let nameData = meta.nameData
            let crc = meta.crc
            let size = meta.size
            let localOffset = meta.localHeaderOffset
            // Central Directory File Header
            // Offset  Länge  Bedeutung
            //  0       4     Signatur 0x02014B50
            //  4       2     Version made by (20)
            //  6       2     Version needed (20)
            //  8       2     General purpose bit flag
            // 10       2     Compression method
            // 12       2     Last mod file time
            // 14       2     Last mod file date
            // 16       4     CRC-32
            // 20       4     Compressed size
            // 24       4     Uncompressed size
            // 28       2     File name length
            // 30       2     Extra field length
            // 32       2     File comment length
            // 34       2     Disk number start
            // 36       2     Internal file attributes
            // 38       4     External file attributes
            // 42       4     Relative offset of local header
            // 46       n     File name
            archive.append(contentsOf: [0x50, 0x4B, 0x01, 0x02])          // Signatur
            archive.appendUInt16LE(20)                                      // Version made by
            archive.appendUInt16LE(20)                                      // Version needed
            archive.appendUInt16LE(0)                                       // Bit flag
            archive.appendUInt16LE(0)                                       // Compression: STORED
            archive.appendUInt16LE(dosTime)                                 // Mod time
            archive.appendUInt16LE(dosDate)                                 // Mod date
            archive.appendUInt32LE(crc)                                     // CRC-32
            archive.appendUInt32LE(size)                                    // Compressed size
            archive.appendUInt32LE(size)                                    // Uncompressed size
            archive.appendUInt16LE(UInt16(nameData.count))                  // Name length
            archive.appendUInt16LE(0)                                       // Extra field length
            archive.appendUInt16LE(0)                                       // Comment length
            archive.appendUInt16LE(0)                                       // Disk number start
            archive.appendUInt16LE(0)                                       // Internal attributes
            archive.appendUInt32LE(0)                                       // External attributes
            archive.appendUInt32LE(localOffset)                             // Local header offset
            archive.append(nameData)                                        // File name
        }

        let centralDirSize = archive.count - centralDirOffset
        guard centralDirSize <= Int(UInt32.max) else {
            throw ZipWriterError.archiveTooLarge(archive.count)
        }
        let numEntries = UInt16(entries.count)

        // End of Central Directory (EOCD)
        // Offset  Länge  Bedeutung
        //  0       4     Signatur 0x06054B50
        //  4       2     Disk number
        //  6       2     Disk with start of central directory
        //  8       2     Number of entries on this disk
        // 10       2     Total number of entries
        // 12       4     Size of central directory
        // 16       4     Offset of central directory
        // 20       2     Comment length
        archive.append(contentsOf: [0x50, 0x4B, 0x05, 0x06])              // Signatur
        archive.appendUInt16LE(0)                                           // Disk number
        archive.appendUInt16LE(0)                                           // Start disk
        archive.appendUInt16LE(numEntries)                                  // Entries on disk
        archive.appendUInt16LE(numEntries)                                  // Total entries
        archive.appendUInt32LE(UInt32(centralDirSize))                      // CD size
        archive.appendUInt32LE(UInt32(centralDirOffset))                    // CD offset
        archive.appendUInt16LE(0)                                           // Comment length

        return archive
    }

    // MARK: - DOS-Datum/Zeit-Konvertierung

    /// Gibt das aktuelle Datum und die aktuelle Zeit im DOS-Format zurück.
    ///
    /// DOS-Zeit (Bits 15-11: Stunden, 10-5: Minuten, 4-0: Sekunden/2)
    /// DOS-Datum (Bits 15-9: Jahr-1980, 8-5: Monat, 4-0: Tag)
    private static func currentDosDateTime() -> (date: UInt16, time: UInt16) {
        let now = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute, .second], from: Date())
        let year = UInt16(max(0, (now.year ?? 1980) - 1980))
        let month = UInt16(now.month ?? 1)
        let day = UInt16(now.day ?? 1)
        let hour = UInt16(now.hour ?? 0)
        let minute = UInt16(now.minute ?? 0)
        let second = UInt16((now.second ?? 0) / 2)

        let dosDate = (year << 9) | (month << 5) | day
        let dosTime = (hour << 11) | (minute << 5) | second
        return (dosDate, dosTime)
    }
}

enum ZipWriterError: LocalizedError {
    case invalidEntryName(String)
    /// ZIP-Format unterstützt maximal 65.535 Einträge (UInt16).
    case tooManyEntries(Int)
    /// Ein einzelner Eintrag überschreitet die UInt32-Größenbeschränkung (kein ZIP64-Support).
    case entryTooLarge(name: String, size: Int)
    /// Das kumulierte Archiv überschreitet 4 GB; ZIP32-Offsets würden überlaufen (kein ZIP64-Support).
    case archiveTooLarge(Int)

    var errorDescription: String? {
        switch self {
        case .invalidEntryName(let name):
            return "ZIP-Eintragsname konnte nicht als UTF-8 kodiert werden: \(name)"
        case .tooManyEntries(let count):
            return "Zu viele ZIP-Einträge (\(count)); Maximum ist \(UInt16.max)"
        case .entryTooLarge(let name, let size):
            return "ZIP-Eintrag '\(name)' ist zu groß (\(size) Bytes); Maximum ohne ZIP64 ist \(UInt32.max) Bytes"
        case .archiveTooLarge(let size):
            return "ZIP-Archiv zu groß (\(size) Bytes); Maximum ohne ZIP64 ist \(UInt32.max) Bytes"
        }
    }
}

// MARK: - Data Helpers (Little-Endian Append)

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
