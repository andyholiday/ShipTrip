//
//  ExportImportDTOs.swift
//  ShipTrip
//
//  Codable-Datenstrukturen des Backup-Formats. Bis 1.7 war das Format ein nacktes
//  `[ExportCruise]`-Array auf Top-Level; ab 1.8 ist es ein Envelope (`ExportArchive`), der
//  zusätzlich Wunschreisen und das Katalog-Overlay (ADR-006) trägt. Der Decoder akzeptiert
//  weiterhin beide Formen — siehe `ExportArchive.decode(from:)`.
//

import Foundation

// MARK: - Archiv-Envelope

/// Top-Level-Struktur des Exports ab 1.8.
///
/// Alle Sammlungen werden beim Dekodieren per `decodeIfPresent` aufgelöst und fehlen sie,
/// bleiben sie leer — ältere Dateien (und Dateien künftiger Versionen mit unbekannten Feldern)
/// bleiben damit lesbar.
struct ExportArchive: Codable {
    /// Version des Backup-Formats. 1 = 1.7-Top-Level-Array, 2 = Envelope ab 1.8.
    static let currentFormatVersion = 2
    static let legacyFormatVersion = 1

    let formatVersion: Int
    let cruises: [ExportCruise]
    let deals: [ExportDeal]
    let customShippingLines: [ExportCustomShippingLine]
    let customShips: [ExportCustomShip]
    let hiddenCatalogItems: [ExportHiddenCatalogItem]

    init(
        formatVersion: Int = ExportArchive.currentFormatVersion,
        cruises: [ExportCruise] = [],
        deals: [ExportDeal] = [],
        customShippingLines: [ExportCustomShippingLine] = [],
        customShips: [ExportCustomShip] = [],
        hiddenCatalogItems: [ExportHiddenCatalogItem] = []
    ) {
        self.formatVersion = formatVersion
        self.cruises = cruises
        self.deals = deals
        self.customShippingLines = customShippingLines
        self.customShips = customShips
        self.hiddenCatalogItems = hiddenCatalogItems
    }

    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        formatVersion = try container.decodeIfPresent(Int.self, forKey: .formatVersion)
            ?? ExportArchive.currentFormatVersion
        cruises = try container.decodeIfPresent([ExportCruise].self, forKey: .cruises) ?? []
        deals = try container.decodeIfPresent([ExportDeal].self, forKey: .deals) ?? []
        customShippingLines = try container
            .decodeIfPresent([ExportCustomShippingLine].self, forKey: .customShippingLines) ?? []
        customShips = try container.decodeIfPresent([ExportCustomShip].self, forKey: .customShips) ?? []
        hiddenCatalogItems = try container
            .decodeIfPresent([ExportHiddenCatalogItem].self, forKey: .hiddenCatalogItems) ?? []
    }

    /// Dual-Decoder: 1.8-Envelope (JSON-Objekt) ODER 1.7-Top-Level-Array `[ExportCruise]`.
    ///
    /// Unterschieden wird am ersten Nicht-Whitespace-Byte statt über einen `try?`-Fallback:
    /// ein Decode-Fehler *innerhalb* eines 1.8-Envelopes soll als solcher gemeldet werden und
    /// nicht als irreführender Legacy-Array-Fehler.
    static func decode(from data: Data) throws -> ExportArchive {
        let decoder = JSONDecoder()
        let jsonWhitespace: Set<UInt8> = [0x20, 0x09, 0x0A, 0x0D]
        if data.first(where: { !jsonWhitespace.contains($0) }) == UInt8(ascii: "[") {
            let legacyCruises = try decoder.decode([ExportCruise].self, from: data)
            return ExportArchive(formatVersion: legacyFormatVersion, cruises: legacyCruises)
        }
        return try decoder.decode(ExportArchive.self, from: data)
    }
}

// MARK: - Kreuzfahrt

/// Exportierbare Kreuzfahrt-Daten
struct ExportCruise: Codable {
    let id: String
    let title: String
    let startDate: String
    let endDate: String
    let shippingLine: String
    let ship: String
    let cabinType: String?
    let cabinNumber: String?
    let bookingNumber: String?
    let notes: String?
    /// Bewertung inklusive halber Sterne. Bis 1.7 war das Feld `Int` — der Export trunkierte
    /// damit 4,5 auf 4. JSON-Ganzzahlen aus 1.7-Dateien dekodieren unverändert als `Double`.
    let rating: Double
    let route: [ExportPort]
    let photos: [ExportPhoto]
    let expenses: [ExportExpense]
}

struct ExportPort: Codable {
    let id: String
    let name: String
    let country: String?
    let lat: String?
    let lng: String?
    let arrival: String
    let departure: String
    let imageUrl: String?
    let excursions: [String]
    /// Explizites Seetag-Flag (H3-Fix). Optional + `var` statt `let`, damit Swifts Codable-Synthese
    /// die fehlende Property in Alt-ZIPs/Legacy-JSON per `decodeIfPresent` zu `nil` auflöst, statt den
    /// Decode abzubrechen; der Import fällt für `nil` auf die Namens-Heuristik zurück.
    var isSeaDay: Bool? = nil
}

/// Foto-Referenz im Export.
///
/// Ab 1.8 ein Objekt mit stabiler `id` (`Photo.id`), damit die Foto-Identität den Roundtrip
/// überlebt und zwei Geräte, die dasselbe Backup einspielen, keine Dubletten erzeugen
/// (CloudKit-Dedup läuft über die stabile `id`, ADR-002). 1.7 schrieb an dieser Stelle einen
/// nackten String — `init(from:)` akzeptiert beides.
struct ExportPhoto: Codable {
    /// `Photo.id`; `nil` in 1.7-Dateien.
    let id: String?
    /// Base64-Data-URL (`data:image/png;base64,…`) oder ZIP-Pfad (`images/<cruiseId>/<index>`).
    let ref: String

    init(id: String?, ref: String) {
        self.id = id
        self.ref = ref
    }

    init(from decoder: any Decoder) throws {
        if let single = try? decoder.singleValueContainer(),
           let legacyReference = try? single.decode(String.self) {
            self.init(id: nil, ref: legacyReference)
            return
        }
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try container.decodeIfPresent(String.self, forKey: .id)
        self.ref = try container.decode(String.self, forKey: .ref)
    }
}

struct ExportExpense: Codable {
    let id: String
    let cruiseId: String
    let category: String
    let description: String?
    let amount: Double
    let expenseDate: String?
    let createdAt: String
}

// MARK: - Wunschreisen

/// Exportierbares Angebot (`Deal`). Bis auf `id` und `title` alles optional — fehlende Felder
/// dekodieren zu `nil`, statt den Import abzubrechen.
struct ExportDeal: Codable {
    let id: String
    let title: String
    let shippingLine: String?
    let ship: String?
    let destination: String?
    let price: Double?
    let originalPrice: Double?
    let startDate: String?
    let endDate: String?
    let url: String?
    let notes: String?
    let createdAt: String?
    let updatedAt: String?
}

// MARK: - Katalog-Overlay (ADR-006)

/// Eigene Reederei. Die `id` ist Teil des Vertrags: `ExportCustomShip.lineOptionID` referenziert
/// sie als `"custom:<UUID>"` — beim Import wird die UUID deshalb übernommen, nicht neu vergeben.
struct ExportCustomShippingLine: Codable {
    let id: String
    let name: String
    let logo: String?
    let createdAt: String?
    let updatedAt: String?
}

struct ExportCustomShip: Codable {
    let id: String
    let name: String
    /// Katalog-Reederei (`"aida"`) oder eigene Reederei (`"custom:<UUID>"`).
    let lineOptionID: String
    let createdAt: String?
    let updatedAt: String?
}

/// Ausgeblendeter Katalog-Eintrag (`shipKey == nil` = ganze Reederei ausgeblendet).
struct ExportHiddenCatalogItem: Codable {
    let id: String
    let lineID: String
    let shipKey: String?
    let createdAt: String?
}
