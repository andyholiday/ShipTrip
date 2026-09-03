//
//  WidgetState.swift
//  ShipTrip
//
//  Zustand, den das Home-Screen-Widget anzeigt (Taskplan 1.9.0,
//  Leitentscheidung 4). Ausschliesslich rohe Daten — Dates, Namen, Zahlen.
//  Wortlaut und Formatierung entstehen erst im Widget.
//
//  Regeln fuer den Ordner `WidgetShared` (Leitentscheidung 1): nur
//  Foundation, kein SwiftData, kein SwiftUI, keine lokalisierten Strings.
//

import Foundation

// MARK: - Grund fuer einen leeren Zustand

/// Warum das Widget gerade keine Reiselage zeigen kann.
enum WidgetUnavailableReason: Sendable, Equatable {
    /// Die App hat noch nie einen Snapshot geschrieben.
    case missing
    /// Snapshot vorhanden, aber nicht verwertbar (kaputt oder fremdes Schema).
    case unreadable
    /// Snapshot aelter als `WidgetStateResolver.staleAfterDays` Tage.
    case stale
}

// MARK: - Aufgeloester Routeneintrag

/// Ein Routeneintrag, wie ihn das Widget zeigt.
///
/// Gegenueber `StopSummary` ist zweierlei bereits entschieden:
/// - `day` ist der aufgeloeste Kalendertag (Tagesbeginn in der Zeitzone des
///   uebergebenen `Calendar`),
/// - `arrival`/`departure` sind optional. Bei einem *zeitlosen* Eintrag
///   (Ankunft ausserhalb des Reisezeitraums) gibt es keine Uhrzeiten; sein
///   Tag ergibt sich aus `startDate` der Reise plus Index in der kanonischen
///   Ordnung.
///
/// Deshalb reicht der Resolver nicht die rohe `StopSummary` durch: deren
/// `arrival`/`departure` sind bei zeitlosen Eintraegen bedeutungslos und
/// duerfen nie angezeigt werden.
struct WidgetStopInfo: Sendable, Equatable {

    var id: UUID
    var name: String
    var country: String?
    var isSeaDay: Bool

    /// Tagesbeginn des Kalendertags, an dem der Eintrag liegt.
    var day: Date

    /// Ankunft; `nil` bei einem zeitlosen Eintrag.
    var arrival: Date?

    /// Abfahrt; `nil` bei einem zeitlosen Eintrag.
    var departure: Date?
}

// MARK: - Zustandsdaten

/// Laufende Reise: aktueller Eintrag mit Zeiten plus Nachfolger.
struct ActiveInfo: Sendable, Equatable {

    var title: String
    var ship: String
    var cruiseStart: Date
    var cruiseEnd: Date

    /// Aktueller Eintrag der kanonischen Ordnung. `nil` bei einer Reise ohne
    /// Route und solange der erste Eintrag noch bevorsteht — dann zeigt das
    /// Widget Titel, Schiff und Zeitraum.
    var currentStop: WidgetStopInfo?

    /// Nachfolger in der kanonischen Ordnung; `nil` nach dem letzten Eintrag.
    var nextStop: WidgetStopInfo?

    /// Der aktuelle Eintrag ist der letzte der Route — das Widget zeigt
    /// statt eines naechsten Stopps das Reiseende (`cruiseEnd`).
    var isAfterLastStop: Bool
}

/// Geplante Reise: Countdown bis zum Start.
struct CountdownInfo: Sendable, Equatable {

    var title: String
    var ship: String
    var startDate: Date

    /// Ganze Kalendertage zwischen heute und dem Starttag (0 = heute,
    /// 1 = morgen). Grundlage fuer den Wortlaut im Widget.
    var daysUntilStart: Int
}

/// Weder eine aktive noch eine geplante Reise.
struct IdleInfo: Sendable, Equatable {

    /// Juengste vergangene Reise; alle drei Felder sind `nil`, wenn es
    /// ueberhaupt keine Reise gibt.
    var lastCruiseTitle: String?
    var lastCruiseEnd: Date?

    /// Ganze Kalendertage seit dem Ende der juengsten Reise.
    var daysSinceLastCruise: Int?
}

// MARK: - Zustand

/// Ergebnis der Zustandsableitung: genau einer dieser Faelle gilt.
enum WidgetState: Sendable, Equatable {
    case active(ActiveInfo)
    case countdown(CountdownInfo)
    case idle(IdleInfo)
    case unavailable(WidgetUnavailableReason)
}
