//
//  WidgetSnapshot.swift
//  ShipTrip
//
//  Datenschema der Snapshot-Datei, die die App fuer das Home-Screen-Widget in
//  den App-Group-Container schreibt (Taskplan 1.9.0, Leitentscheidung 2).
//
//  Regeln fuer den Ordner `WidgetShared` (Leitentscheidung 1): ausschliesslich
//  `Foundation`, kein SwiftData, kein SwiftUI, kein WidgetKit, keine
//  lokalisierten Strings. Alles sind reine `Sendable`-Werte; `Calendar` und
//  `TimeZone` werden nie hier verankert, sondern beim Lesen injiziert.
//

import Foundation

// MARK: - Snapshot

/// Momentaufnahme der fuer das Widget relevanten Reisedaten.
///
/// Alle `Date`-Werte sind absolute Zeitpunkte (UTC-Instant). Kalendertage
/// rechnet erst der Leser in der Geraetezeitzone.
///
/// - Important: Die Datei wird mit `JSONEncoder.dateEncodingStrategy = .iso8601`
///   geschrieben. Dieses Format kennt **keine Sekundenbruchteile** — ein
///   `Date` mit Nachkommastellen kommt beim Lesen auf volle Sekunden gerundet
///   zurueck. Fuer `generatedAt` und die Stale-Regel ist das unerheblich,
///   fuer Gleichheitsvergleiche ueber einen Schreib-/Lesezyklus nicht.
struct WidgetSnapshot: Codable, Sendable, Equatable {

    /// Aktuelle Schema-Version des Dateiformats. Liest der Store eine andere
    /// Version, gilt die Datei als unlesbar — nie als Absturz.
    static let current = 1

    /// Hoechstzahl Reisen im Snapshot: die aktive, die naechste geplante und
    /// die juengste vergangene. Die Auswahl trifft die App-Seite.
    static let maxCruises = 3

    /// Hoechstzahl Routeneintraege je Reise. Bei laengeren Routen schneidet
    /// die App-Seite ein Fenster um den aktuellen Stopp heraus.
    static let maxRouteStops = 40

    /// Schema-Version, mit der diese Datei geschrieben wurde.
    var schemaVersion: Int

    /// Zeitpunkt der Erzeugung. Grundlage der Stale-Regel im Resolver.
    var generatedAt: Date

    /// Hoechstens `maxCruises` Reisen, ohne Demo-Reisen.
    var cruises: [CruiseSummary]

    init(
        schemaVersion: Int = WidgetSnapshot.current,
        generatedAt: Date,
        cruises: [CruiseSummary]
    ) {
        self.schemaVersion = schemaVersion
        self.generatedAt = generatedAt
        self.cruises = cruises
    }
}

// MARK: - Reise

/// Eine Reise, reduziert auf das, was das Widget anzeigt. Keine Bilder, keine
/// Koordinaten, keine Ausgaben, keine Journaleintraege.
struct CruiseSummary: Codable, Sendable, Equatable {

    var id: UUID
    var title: String
    var ship: String
    var startDate: Date
    var endDate: Date

    /// Routeneintraege in kanonischer Ordnung (`sortOrder`, bei Gleichstand
    /// `arrival`, dann `id`), hoechstens `WidgetSnapshot.maxRouteStops`.
    var route: [StopSummary]

    init(
        id: UUID,
        title: String,
        ship: String,
        startDate: Date,
        endDate: Date,
        route: [StopSummary]
    ) {
        self.id = id
        self.title = title
        self.ship = ship
        self.startDate = startDate
        self.endDate = endDate
        self.route = route
    }
}

// MARK: - Routeneintrag

/// Ein Hafen oder Seetag der Route.
///
/// `arrival` und `departure` sind bewusst nicht optional — sie spiegeln die
/// Pflichtfelder des Datenmodells. Ob ein Eintrag als *zeitlos* gilt, leitet
/// der Resolver ab (`arrival` ausserhalb des Reisezeitraums), nicht das Schema.
struct StopSummary: Codable, Sendable, Equatable {

    var id: UUID
    var name: String

    /// Land des Hafens; `nil`, wenn im Datenmodell leer (etwa bei Seetagen).
    var country: String?

    var arrival: Date
    var departure: Date
    var sortOrder: Int
    var isSeaDay: Bool

    init(
        id: UUID,
        name: String,
        country: String?,
        arrival: Date,
        departure: Date,
        sortOrder: Int,
        isSeaDay: Bool
    ) {
        self.id = id
        self.name = name
        self.country = country
        self.arrival = arrival
        self.departure = departure
        self.sortOrder = sortOrder
        self.isSeaDay = isSeaDay
    }
}
