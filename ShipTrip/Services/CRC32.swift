//
//  CRC32.swift
//  ShipTrip
//
//  Created by ShipTrip on 19.12.25.
//

import Foundation

// MARK: - CRC-32 (IEEE 802.3, Polynom 0xEDB88320, reflected)

/// Berechnet CRC-32-Prüfsummen für den ZIP-Export/Import (`ZipArchiveWriter`/`ZipArchiveReader`).
enum CRC32 {
    /// CRC-32-Lookup-Tabelle (einmalig berechnet).
    private static let table: [UInt32] = {
        (0..<256).map { n -> UInt32 in
            var c = UInt32(n)
            for _ in 0..<8 {
                if c & 1 == 1 {
                    c = 0xEDB88320 ^ (c >> 1)
                } else {
                    c = c >> 1
                }
            }
            return c
        }
    }()

    /// Berechnet CRC-32 eines Data-Objekts.
    static func checksum(_ data: Data) -> UInt32 {
        var crc: UInt32 = 0xFFFFFFFF
        for byte in data {
            let index = Int((crc ^ UInt32(byte)) & 0xFF)
            crc = (crc >> 8) ^ CRC32.table[index]
        }
        return crc ^ 0xFFFFFFFF
    }
}
