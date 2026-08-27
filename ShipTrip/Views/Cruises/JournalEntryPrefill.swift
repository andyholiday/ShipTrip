//
//  JournalEntryPrefill.swift
//  ShipTrip
//
//  Vorbelegung des Journal-Editors aus dem Einstiegspunkt (ADR-003, Contract J3neu (d)).
//

import Foundation

/// Was der Einstiegspunkt dem Editor an Vorbelegung mitgibt.
///
/// J3neu (d) kennt genau zwei Einstiege in die Erfassung:
/// - **aufgeklappter Stopp** → `.stop(portID:arrival:)`: Tag und Hafen des
///   angetippten Stopps (Seetage eingeschlossen — sie sind Route-Stopps),
/// - **Sammelblock „Weitere Einträge"** → `.noStop`: reine J2-Defaults.
///
/// Der Editor-Flow selbst bleibt in beiden Faellen **unveraendert** (Reihenfolge,
/// Pflichtregel, Save-Semantik, J2a) — vorbelegt wird nur Schritt 2, und der User
/// kann dort beides aendern.
struct JournalEntryPrefill: Hashable, Sendable {

    /// `port.id` des angetippten Stopps — `nil` = kein Hafen vorbelegt.
    let portID: UUID?

    /// Lokaler Tag des Stopps (`port.arrival`) — `nil` = J2-Default (heute,
    /// geklemmt auf den Reisezeitraum).
    let localDay: Date?

    /// Einstieg ohne Stopp-Bezug (Sammelblock): der Editor nimmt die J2-Defaults.
    static let noStop = JournalEntryPrefill(portID: nil, localDay: nil)

    /// Einstieg „Tagebuch-Eintrag" an einem aufgeklappten Stopp.
    ///
    /// - Parameter arrival: `port.arrival` als **lokaler** Ereignis-Zeitstempel;
    ///   die Normalisierung auf 12:00 UTC macht erst der Save-Pfad
    ///   (`JournalEntry.setEntryDate(localDay:)`).
    static func stop(portID: UUID, arrival: Date) -> JournalEntryPrefill {
        JournalEntryPrefill(portID: portID, localDay: arrival)
    }
}
