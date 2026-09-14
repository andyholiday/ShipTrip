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
struct ExportArchive: Codable, Sendable {
    /// Version des Backup-Formats. 1 = 1.7-Top-Level-Array, 2 = Envelope ab 1.8.
    static let currentFormatVersion = 2
    static let legacyFormatVersion = 1

    let formatVersion: Int
    let cruises: [ExportCruise]
    let deals: [ExportDeal]
    let customShippingLines: [ExportCustomShippingLine]
    let customShips: [ExportCustomShip]
    let hiddenCatalogItems: [ExportHiddenCatalogItem]
    /// Nur in geteilten Reisen (`.shiptrip`) gesetzt; in Backups `nil` und damit beim
    /// Encoden weggelassen — Backup-Dateien bleiben byte-identisch (ADR-007 / Contract C1).
    let share: ExportShareInfo?

    enum CodingKeys: String, CodingKey {
        case formatVersion
        case cruises
        case deals
        case customShippingLines
        case customShips
        case hiddenCatalogItems
        case share
    }

    init(
        formatVersion: Int = ExportArchive.currentFormatVersion,
        cruises: [ExportCruise] = [],
        deals: [ExportDeal] = [],
        customShippingLines: [ExportCustomShippingLine] = [],
        customShips: [ExportCustomShip] = [],
        hiddenCatalogItems: [ExportHiddenCatalogItem] = [],
        share: ExportShareInfo? = nil
    ) {
        self.formatVersion = formatVersion
        self.cruises = cruises
        self.deals = deals
        self.customShippingLines = customShippingLines
        self.customShips = customShips
        self.hiddenCatalogItems = hiddenCatalogItems
        self.share = share
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
        share = try container.decodeIfPresent(ExportShareInfo.self, forKey: .share)
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

// MARK: - Share-Block

/// Kennzeichnet ein Archiv als geteilte Kreuzfahrt (`.shiptrip`, Contract C1).
///
/// Alle vier Felder sind in einer Share-Datei v1 Pflicht; in Backups fehlt der ganze Block.
struct ExportShareInfo: Codable, Sendable {
    /// Aktuelle Version des Share-Blocks — einzige Quelle der Share-Formatversion
    /// (Contract C0). Schreiber setzen `shareFormatVersion` hierauf, Leser vergleichen dagegen.
    static let currentShareFormatVersion = 1

    /// Version des Share-Blocks (v1).
    let shareFormatVersion: Int
    /// Zeitpunkt des Teilens, String des Export-`dateFormatter`.
    let sharedAt: String
    /// App-Version des Senders.
    let appVersion: String
    /// SHA-256-Hex der geteilten Kreuzfahrt, sender-berechnet (`ShareFingerprint`).
    let contentFingerprint: String
}

// MARK: - Kreuzfahrt

/// Exportierbare Kreuzfahrt-Daten
struct ExportCruise: Codable, Sendable {
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
    /// Journal-Einträge der Reise (ADR-003, T7b-Contract). Optional + `var` wie
    /// `ExportPort.isSeaDay`: Swifts Codable-Synthese löst die fehlende Property in
    /// 1.8.0-Dateien per `decodeIfPresent` zu `nil` auf (Import materialisiert `?? []`)
    /// und lässt sie beim Encoden weg, solange die Reise kein Journal hat. Damit bleiben
    /// Dateien journalloser Reisen byte-identisch zu 1.8.0 — und ihr `contentFingerprint`
    /// (C1) stabil, sonst meldete jeder Re-Share an einen Bestands-Empfänger einen
    /// Versionskonflikt, obwohl sich am Inhalt nichts geändert hat.
    var journalEntries: [ExportJournalEntry]? = nil
}

/// Ein Journal-Eintrag im Export (ADR-003 → „Export- und Teilen-Integration").
///
/// Die Bezüge zu Hafen und Fotos reisen als **stabile UUID-Strings** mit; der Import
/// rekonstruiert sie innerhalb derselben Reise und verwirft nicht auflösbare IDs still.
struct ExportJournalEntry: Codable, Sendable {
    /// `JournalEntry.id`.
    let id: String
    let text: String
    /// Kalendertag als ISO-8601-Zeitstempel (`isoFormatter`, also UTC) — bewusst **nicht**
    /// über den `dateFormatter`: der trägt die Geräte-Zeitzone und würde den auf 12:00 UTC
    /// verankerten Date-only-Wert bei großen Offsets auf den Nachbartag kippen
    /// (Zeitzonen-Vertrag). Der Import normalisiert zusätzlich auf 12:00 UTC.
    let entryDate: String
    /// Stimmung als Roh-String, `""` = keine. Passiert Export/Import verbatim (J4).
    let moodRaw: String
    let createdAt: String
    let updatedAt: String
    /// `Port.id` des optionalen Hafen-Bezugs.
    let portId: String?
    /// `Photo.id`s der angehängten Fotos (die Fotos bleiben zugleich Reise-Kinder).
    let photoIds: [String]
}

struct ExportPort: Codable, Sendable {
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
struct ExportPhoto: Codable, Sendable {
    /// `Photo.id`; `nil` in 1.7-Dateien.
    let id: String?
    /// Base64-Data-URL (`data:image/png;base64,…`) oder ZIP-Pfad (`images/<cruiseId>/<index>`).
    let ref: String
    /// Bildunterschrift (ADR-003, T7b-Contract). `nil` in Dateien bis 1.8.0 und in Dateien
    /// neuerer Stände, deren Foto keine Unterschrift trägt — der Import materialisiert dann
    /// `""`. Weglassen statt leerem String hält Dateien ohne Captions byte-identisch zu 1.8.0
    /// (siehe `ExportCruise.journalEntries`).
    let caption: String?

    enum CodingKeys: String, CodingKey {
        case id
        case ref
        case caption
    }

    init(id: String?, ref: String, caption: String? = nil) {
        self.id = id
        self.ref = ref
        self.caption = caption
    }

    init(from decoder: any Decoder) throws {
        // 1.7: nackter String statt Objekt.
        if let single = try? decoder.singleValueContainer(),
           let legacyReference = try? single.decode(String.self) {
            id = nil
            ref = legacyReference
            caption = nil
            return
        }
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeIfPresent(String.self, forKey: .id)
        ref = try container.decode(String.self, forKey: .ref)
        caption = try container.decodeIfPresent(String.self, forKey: .caption)
    }
}

struct ExportExpense: Codable, Sendable {
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
struct ExportDeal: Codable, Sendable {
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
struct ExportCustomShippingLine: Codable, Sendable {
    let id: String
    let name: String
    let logo: String?
    let createdAt: String?
    let updatedAt: String?
}

struct ExportCustomShip: Codable, Sendable {
    let id: String
    let name: String
    /// Katalog-Reederei (`"aida"`) oder eigene Reederei (`"custom:<UUID>"`).
    let lineOptionID: String
    let createdAt: String?
    let updatedAt: String?
}

/// Ausgeblendeter Katalog-Eintrag (`shipKey == nil` = ganze Reederei ausgeblendet).
struct ExportHiddenCatalogItem: Codable, Sendable {
    let id: String
    let lineID: String
    let shipKey: String?
    let createdAt: String?
}
