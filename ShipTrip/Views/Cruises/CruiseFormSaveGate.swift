//
//  CruiseFormSaveGate.swift
//  ShipTrip
//
//  Save-Gate des Reise-Formulars als reine Logik.
//

import Foundation

enum CruiseFormSaveGate {

    /// Pflichtregel des Reise-Formulars: speicherbar, sobald Titel **und**
    /// Schiff gefüllt sind und kein Save laeuft.
    ///
    /// - Parameter photoLoadsInFlight: Anzahl der noch laufenden Foto-Transfers
    ///   des Pickers.
    static func canSave(
        hasTitle: Bool,
        hasShip: Bool,
        isSaving: Bool,
        photoLoadsInFlight: Int
    ) -> Bool {
        // Commit 1 von 2 (Rot-Beweis): extrahiertes Bestands-Verhalten —
        // `photoLoadsInFlight` geht hier bewusst noch **nicht** ein, genau daran
        // haengt der rote Repro-Test der Foto-Verlust-Race.
        hasTitle && hasShip && !isSaving
    }
}
