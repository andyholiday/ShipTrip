//
//  RouteCollapsePlanner.swift
//  ShipTrip
//
//  Klapp-Zustandsmaschine des Route-Abschnitts (ADR-003, Contract J3neu (b)).
//

import Foundation

/// Phase der Reise, aus der sich der Klapp-Automatik-Default ergibt.
/// Vergleich als Tag-Tripel im Geraete-Kalender (Zeitzonen-Vertrag).
enum CruisePhase: Equatable, Sendable {
    /// heute < Starttag
    case beforeStart
    /// Starttag ≤ heute ≤ Endtag
    case active
    /// heute > Endtag
    case afterEnd

    /// - Parameters:
    ///   - today: „heute" als lokaler Zeitstempel.
    ///   - startDate: `cruise.startDate` (lokaler Ereignis-Zeitstempel).
    ///   - endDate: `cruise.endDate` (lokaler Ereignis-Zeitstempel).
    static func phase(
        today: Date,
        startDate: Date,
        endDate: Date,
        calendar: Calendar = .current
    ) -> CruisePhase {
        let todayKey = RouteDayKey.localDay(today, calendar: calendar)
        if todayKey < RouteDayKey.localDay(startDate, calendar: calendar) { return .beforeStart }
        if todayKey > RouteDayKey.localDay(endDate, calendar: calendar) { return .afterEnd }
        return .active
    }
}

/// Der Automatik-Default der Klapp-Maschine: welche Stopps sind ohne manuelle
/// Uebersteuerung aufgeklappt (J3neu (b))?
///
/// | Phase | Default |
/// |---|---|
/// | Vor Reisebeginn | alle Stopps aufgeklappt |
/// | Aktiv | nur Stopps des aktuellen Tages aufgeklappt |
/// | Nach Reiseende | alle Stopps aufgeklappt |
///
/// Fallback in Phase „Aktiv": hat der aktuelle Tag **keinen** Route-Stopp,
/// bleiben alle Stopps zugeklappt — es wird kein fremder Tag ersatzweise
/// geoeffnet.
///
/// Der Sammelblock „Weitere Eintraege" ist von der Maschine ausgenommen: er hat
/// keinen Klapp-Kopf und taucht folglich nie als Stopp-ID auf.
struct RouteCollapseDefaults: Equatable, Sendable {
    let phase: CruisePhase
    /// Stopps, die ohne Uebersteuerung aufgeklappt sind.
    let expandedStopIDs: Set<UUID>

    /// Berechnet Phase + Defaults. Aufzurufen beim Erscheinen der View, beim
    /// App-Start und bei jedem Tageswechsel (J3neu (b), Ereignis-Tabelle).
    static func make(
        stops: [RouteStopInput],
        today: Date,
        startDate: Date,
        endDate: Date,
        calendar: Calendar = .current
    ) -> RouteCollapseDefaults {
        let phase = CruisePhase.phase(
            today: today, startDate: startDate, endDate: endDate, calendar: calendar
        )
        switch phase {
        case .beforeStart, .afterEnd:
            return RouteCollapseDefaults(phase: phase, expandedStopIDs: Set(stops.map(\.id)))
        case .active:
            let todayKey = RouteDayKey.localDay(today, calendar: calendar)
            let openIDs = stops
                .filter { RouteDayKey.localDay($0.arrival, calendar: calendar) == todayKey }
                .map(\.id)
            // Leer = kein Stopp am heutigen Tag → alles bleibt zu (Fallback).
            return RouteCollapseDefaults(phase: phase, expandedStopIDs: Set(openIDs))
        }
    }

    /// Automatik-Default eines einzelnen Stopps.
    func isExpandedByDefault(stopID: UUID) -> Bool {
        expandedStopIDs.contains(stopID)
    }
}

/// Die manuellen Uebersteuerungen der Klapp-Maschine.
///
/// Effektiver Zustand = `Uebersteuerung ?? Automatik-Default`.
///
/// **Persistenz: keine.** Der Zustand lebt nur im View-Leben (`@State`, T8b) —
/// kein neues persistentes Feld, kein Schema-/CloudKit-Eingriff (J3neu (b)).
/// Eine frische Ansicht kehrt zum Automatik-Default zurueck.
struct RouteCollapseState: Equatable, Sendable {
    /// `port.id` → manuell gesetzter Zustand. Fehlt der Eintrag, gilt der Default.
    private var overrides: [UUID: Bool] = [:]

    init() {}

    /// Effektiver Klapp-Zustand eines Stopps.
    func isExpanded(stopID: UUID, defaults: RouteCollapseDefaults) -> Bool {
        overrides[stopID] ?? defaults.isExpandedByDefault(stopID: stopID)
    }

    /// Manuelles Tippen auf einen Stopp-Kopf: Uebersteuerung = Negation des
    /// **effektiven** Zustands (nicht des Defaults).
    mutating func toggle(stopID: UUID, defaults: RouteCollapseDefaults) {
        overrides[stopID] = !isExpanded(stopID: stopID, defaults: defaults)
    }

    /// „Alle aufklappen" aus dem Route-Header — jederzeit verfuegbar.
    mutating func expandAll(stopIDs: some Sequence<UUID>) {
        setAll(stopIDs: stopIDs, to: true)
    }

    /// „Alle zuklappen" aus dem Route-Header.
    mutating func collapseAll(stopIDs: some Sequence<UUID>) {
        setAll(stopIDs: stopIDs, to: false)
    }

    /// Tageswechsel 0:00 lokale Geraetezeit (`NSCalendarDayChanged` bzw.
    /// Reaktivierung der Szene an einem neuen Tag): **alle** Uebersteuerungen
    /// loeschen — sonst hielte eine gestrige Uebersteuerung den neuen aktiven Tag
    /// zu. Die Defaults berechnet der Aufrufer im selben Zug neu.
    mutating func resetForDayChange() {
        overrides.removeAll()
    }

    private mutating func setAll(stopIDs: some Sequence<UUID>, to isExpanded: Bool) {
        for stopID in stopIDs { overrides[stopID] = isExpanded }
    }
}
