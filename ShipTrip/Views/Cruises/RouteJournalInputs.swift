//
//  RouteJournalInputs.swift
//  ShipTrip
//
//  Werte-Eingaben des Route-Journal-Fadens (ADR-003, Contract J3neu).
//

import Foundation

/// Ein Route-Stopp als reiner Wert — Seetage eingeschlossen (sie sind nach
/// J3neu (a) normale Traeger).
///
/// Die Planer arbeiten bewusst auf Werten statt auf `Port`: `@Model`-Objekte
/// sind nicht `Sendable` und zwingen Tests an einen `ModelContainer`. Die View
/// (T8b) mappt am Rand: `RouteStopInput(id: port.id, sortOrder: port.sortOrder,
/// arrival: port.arrival)`.
struct RouteStopInput: Hashable, Sendable {
    /// `port.id` — der stabile Schluessel fuer Zuordnung und Klapp-Uebersteuerung.
    let id: UUID
    /// `port.sortOrder` — regiert „erster Stopp des Tages" (J3neu (a) Regel 2).
    let sortOrder: Int
    /// `port.arrival` — lokaler Ereignis-Zeitstempel (Geraete-Kalender).
    let arrival: Date

    init(id: UUID, sortOrder: Int, arrival: Date) {
        self.id = id
        self.sortOrder = sortOrder
        self.arrival = arrival
    }
}

/// Ein Journal-Eintrag als reiner Wert — nur die fuer die Zuordnung
/// relevanten Felder (Text, Stimmung und Fotos braucht erst die Darstellung).
struct JournalEntryInput: Hashable, Sendable {
    /// `entry.id`
    let id: UUID
    /// `entry.port?.id` — `nil` = kein Hafen-Bezug.
    let portID: UUID?
    /// `entry.entryDate` — Date-only-Wert, kanonisch 12:00 UTC (Zeitzonen-Vertrag).
    let entryDate: Date
    /// `entry.createdAt` — Zweitschluessel der Sortierung innerhalb eines Tages.
    let createdAt: Date

    init(id: UUID, portID: UUID?, entryDate: Date, createdAt: Date) {
        self.id = id
        self.portID = portID
        self.entryDate = entryDate
        self.createdAt = createdAt
    }
}
