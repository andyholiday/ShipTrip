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
    /// `internal`, weil `ZipArchiveStreamWriter` (strömender Export) exakt dieselben
    /// Bausteine verwendet — ein zweites ZIP-Format im Projekt wäre eine Fehlerquelle
    /// in einem Backup-Feature.
    struct ZipEntryMeta {
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
            let meta = try makeEntryMeta(name: name, data: fileData, localHeaderOffset: archive.count)
            metas.append(meta)
            archive.append(localFileHeader(for: meta, dosDate: dosDate, dosTime: dosTime))
            archive.append(fileData)                                        // File data
        }

        guard archive.count <= Int(UInt32.max) else {
            throw ZipWriterError.archiveTooLarge(archive.count)
        }
        let centralDirOffset = archive.count

        // Zweiter Durchlauf: Central Directory aus dem Cache schreiben.
        // Kein erneuter Zugriff auf fileData; alle Werte kommen aus ZipEntryMeta.
        for meta in metas {
            archive.append(centralDirectoryEntry(for: meta, dosDate: dosDate, dosTime: dosTime))
        }

        let centralDirSize = archive.count - centralDirOffset
        guard centralDirSize <= Int(UInt32.max) else {
            throw ZipWriterError.archiveTooLarge(archive.count)
        }

        archive.append(endOfCentralDirectory(
            entryCount: UInt16(entries.count),
            centralDirSize: UInt32(centralDirSize),
            centralDirOffset: UInt32(centralDirOffset)
        ))

        return archive
    }

    // MARK: - Byte-Bausteine (geteilt mit ZipArchiveStreamWriter)

    /// Berechnet CRC-32, Größe und Namens-Bytes eines Eintrags und prüft die ZIP32-Grenzen.
    static func makeEntryMeta(name: String, data: Data, localHeaderOffset: Int) throws -> ZipEntryMeta {
        guard let nameData = name.data(using: .utf8) else {
            throw ZipWriterError.invalidEntryName(name)
        }
        guard data.count <= Int(UInt32.max) else {
            throw ZipWriterError.entryTooLarge(name: name, size: data.count)
        }
        guard localHeaderOffset <= Int(UInt32.max) else {
            throw ZipWriterError.archiveTooLarge(localHeaderOffset)
        }
        return ZipEntryMeta(
            nameData: nameData,
            crc: CRC32.checksum(data),
            size: UInt32(data.count),
            localHeaderOffset: UInt32(localHeaderOffset)
        )
    }

    /// Local File Header (ohne die anschließenden Nutzdaten).
    /// Offset  Länge  Bedeutung
    ///  0       4     Signatur 0x04034B50
    ///  4       2     Version needed (20 = 2.0)
    ///  6       2     General purpose bit flag
    ///  8       2     Compression method (0 = STORED)
    /// 10       2     Last mod file time (DOS)
    /// 12       2     Last mod file date (DOS)
    /// 14       4     CRC-32
    /// 18       4     Compressed size
    /// 22       4     Uncompressed size
    /// 26       2     File name length
    /// 28       2     Extra field length
    /// 30       n     File name
    /// 30+n     m     Extra field (leer)
    /// 30+n+m   s     File data (folgt direkt, hier nicht enthalten)
    static func localFileHeader(for meta: ZipEntryMeta, dosDate: UInt16, dosTime: UInt16) -> Data {
        var header = Data()
        header.append(contentsOf: [0x50, 0x4B, 0x03, 0x04])               // Signatur
        header.appendUInt16LE(20)                                           // Version needed
        header.appendUInt16LE(0)                                            // Bit flag
        header.appendUInt16LE(0)                                            // Compression: STORED
        header.appendUInt16LE(dosTime)                                      // Mod time
        header.appendUInt16LE(dosDate)                                      // Mod date
        header.appendUInt32LE(meta.crc)                                     // CRC-32
        header.appendUInt32LE(meta.size)                                    // Compressed size
        header.appendUInt32LE(meta.size)                                    // Uncompressed size
        header.appendUInt16LE(UInt16(meta.nameData.count))                  // Name length
        header.appendUInt16LE(0)                                            // Extra field length
        header.append(meta.nameData)                                        // File name
        return header
    }

    /// Central Directory File Header.
    /// Offset  Länge  Bedeutung
    ///  0       4     Signatur 0x02014B50
    ///  4       2     Version made by (20)
    ///  6       2     Version needed (20)
    ///  8       2     General purpose bit flag
    /// 10       2     Compression method
    /// 12       2     Last mod file time
    /// 14       2     Last mod file date
    /// 16       4     CRC-32
    /// 20       4     Compressed size
    /// 24       4     Uncompressed size
    /// 28       2     File name length
    /// 30       2     Extra field length
    /// 32       2     File comment length
    /// 34       2     Disk number start
    /// 36       2     Internal file attributes
    /// 38       4     External file attributes
    /// 42       4     Relative offset of local header
    /// 46       n     File name
    static func centralDirectoryEntry(for meta: ZipEntryMeta, dosDate: UInt16, dosTime: UInt16) -> Data {
        var entry = Data()
        entry.append(contentsOf: [0x50, 0x4B, 0x01, 0x02])                // Signatur
        entry.appendUInt16LE(20)                                            // Version made by
        entry.appendUInt16LE(20)                                            // Version needed
        entry.appendUInt16LE(0)                                             // Bit flag
        entry.appendUInt16LE(0)                                             // Compression: STORED
        entry.appendUInt16LE(dosTime)                                       // Mod time
        entry.appendUInt16LE(dosDate)                                       // Mod date
        entry.appendUInt32LE(meta.crc)                                      // CRC-32
        entry.appendUInt32LE(meta.size)                                     // Compressed size
        entry.appendUInt32LE(meta.size)                                     // Uncompressed size
        entry.appendUInt16LE(UInt16(meta.nameData.count))                   // Name length
        entry.appendUInt16LE(0)                                             // Extra field length
        entry.appendUInt16LE(0)                                             // Comment length
        entry.appendUInt16LE(0)                                             // Disk number start
        entry.appendUInt16LE(0)                                             // Internal attributes
        entry.appendUInt32LE(0)                                             // External attributes
        entry.appendUInt32LE(meta.localHeaderOffset)                        // Local header offset
        entry.append(meta.nameData)                                         // File name
        return entry
    }

    /// End of Central Directory (EOCD).
    /// Offset  Länge  Bedeutung
    ///  0       4     Signatur 0x06054B50
    ///  4       2     Disk number
    ///  6       2     Disk with start of central directory
    ///  8       2     Number of entries on this disk
    /// 10       2     Total number of entries
    /// 12       4     Size of central directory
    /// 16       4     Offset of central directory
    /// 20       2     Comment length
    static func endOfCentralDirectory(
        entryCount: UInt16,
        centralDirSize: UInt32,
        centralDirOffset: UInt32
    ) -> Data {
        var eocd = Data()
        eocd.append(contentsOf: [0x50, 0x4B, 0x05, 0x06])                 // Signatur
        eocd.appendUInt16LE(0)                                              // Disk number
        eocd.appendUInt16LE(0)                                              // Start disk
        eocd.appendUInt16LE(entryCount)                                     // Entries on disk
        eocd.appendUInt16LE(entryCount)                                     // Total entries
        eocd.appendUInt32LE(centralDirSize)                                 // CD size
        eocd.appendUInt32LE(centralDirOffset)                               // CD offset
        eocd.appendUInt16LE(0)                                              // Comment length
        return eocd
    }

    // MARK: - DOS-Datum/Zeit-Konvertierung

    /// Gibt das aktuelle Datum und die aktuelle Zeit im DOS-Format zurück.
    ///
    /// DOS-Zeit (Bits 15-11: Stunden, 10-5: Minuten, 4-0: Sekunden/2)
    /// DOS-Datum (Bits 15-9: Jahr-1980, 8-5: Monat, 4-0: Tag)
    static func currentDosDateTime() -> (date: UInt16, time: UInt16) {
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

// MARK: - Strömender ZIP-Writer (off-main)

/// Schreibt ein STORED-ZIP-Archiv Eintrag für Eintrag direkt in eine Datei.
///
/// Zwei Unterschiede zu `ZipArchiveWriter.build`, beide für den Foto-Export relevant:
/// 1. Das Archiv wird nie als Ganzes im Speicher gehalten, sondern über einen `FileHandle`
///    fortgeschrieben. Im Speicher bleiben nur der aktuelle Eintrag und das Central Directory
///    (46 Bytes + Name pro Eintrag).
/// 2. Die Nutzdaten liefert `Entry.body` erst im Moment des Schreibens. Für Fotos ist das ein
///    kurzer Hop auf den MainActor pro Bild (SwiftData-Objekte dürfen die Aktorgrenze nicht
///    überqueren), sodass der Spitzenverbrauch bei O(größtes Bild) statt O(Bibliothek) liegt.
///
/// Als `actor` deklariert, damit der Aufruf aus dem MainActor den Main-Thread garantiert
/// verlässt — unabhängig davon, wie das Projekt die Isolation nicht-isolierter async-Funktionen
/// konfiguriert.
actor ZipArchiveStreamWriter {
    /// Ein Eintrag, dessen Bytes erst beim Schreiben beschafft werden.
    struct Entry: Sendable {
        let name: String
        let body: @Sendable () async throws -> Data
    }

    /// Schreibt das Archiv oder hinterlässt nichts.
    ///
    /// Jeder Fehler — ein werfender `Entry.body`, ein Schreibfehler, ein Abbruch
    /// (`CancellationError`) — räumt die angefangene Zieldatei weg und wird propagiert. Eine
    /// halbe ZIP darf nicht liegen bleiben: sie sähe aus wie ein gültiges Backup.
    func write(entries: [Entry], to url: URL) async throws {
        guard entries.count <= Int(UInt16.max) else {
            throw ZipWriterError.tooManyEntries(entries.count)
        }

        try Data().write(to: url)
        let handle = try FileHandle(forWritingTo: url)
        do {
            try await appendArchive(entries: entries, using: handle)
            // Abschlussfehler (Flush/Close) propagieren statt schlucken — ein `try?` hier könnte
            // ein unvollständig geschriebenes Archiv als Erfolg melden.
            try handle.close()
        } catch {
            try? handle.close()                 // nur der Fehlerpfad ist best-effort
            try? FileManager.default.removeItem(at: url)
            throw error
        }
    }

    /// Der eigentliche Schreibdurchlauf. Kennt keine Aufräumlogik — die liegt in `write`.
    private func appendArchive(entries: [Entry], using handle: FileHandle) async throws {
        let (dosDate, dosTime) = ZipArchiveWriter.currentDosDateTime()

        var offset = 0
        var metas: [ZipArchiveWriter.ZipEntryMeta] = []
        metas.reserveCapacity(entries.count)

        for entry in entries {
            try Task.checkCancellation()
            let fileData = try await entry.body()
            // Zweiter Check: `body` ist der einzige Suspensionspunkt der Schleife, ein Abbruch
            // während des Bild-Hops darf nicht noch einen Eintrag schreiben.
            try Task.checkCancellation()
            let meta = try ZipArchiveWriter.makeEntryMeta(
                name: entry.name, data: fileData, localHeaderOffset: offset
            )
            let header = ZipArchiveWriter.localFileHeader(for: meta, dosDate: dosDate, dosTime: dosTime)
            try handle.write(contentsOf: header)
            try handle.write(contentsOf: fileData)
            offset += header.count + fileData.count
            metas.append(meta)
        }

        guard offset <= Int(UInt32.max) else {
            throw ZipWriterError.archiveTooLarge(offset)
        }
        let centralDirOffset = offset

        var centralDirectory = Data()
        for meta in metas {
            centralDirectory.append(
                ZipArchiveWriter.centralDirectoryEntry(for: meta, dosDate: dosDate, dosTime: dosTime)
            )
        }
        guard centralDirectory.count <= Int(UInt32.max) else {
            throw ZipWriterError.archiveTooLarge(offset + centralDirectory.count)
        }

        // Letzter Check vor dem Abschluss: ab hier wäre die Datei ein gültiges Archiv, ein danach
        // erkannter Abbruch würde also ein „fertiges" Backup zurücklassen.
        try Task.checkCancellation()

        try handle.write(contentsOf: centralDirectory)
        try handle.write(contentsOf: ZipArchiveWriter.endOfCentralDirectory(
            entryCount: UInt16(entries.count),
            centralDirSize: UInt32(centralDirectory.count),
            centralDirOffset: UInt32(centralDirOffset)
        ))
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
            return String(localized: "ZIP-Eintragsname konnte nicht als UTF-8 kodiert werden: \(name)")
        case .tooManyEntries(let count):
            return String(localized: "Zu viele ZIP-Einträge (\(count)); Maximum ist \(UInt16.max)")
        case .entryTooLarge(let name, let size):
            return String(localized: "ZIP-Eintrag '\(name)' ist zu groß (\(size) Bytes); Maximum ohne ZIP64 ist \(UInt32.max) Bytes")
        case .archiveTooLarge(let size):
            return String(localized: "ZIP-Archiv zu groß (\(size) Bytes); Maximum ohne ZIP64 ist \(UInt32.max) Bytes")
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
