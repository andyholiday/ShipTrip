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
    /// Solange noch ein Picker-Transfer laeuft, bleibt Speichern gesperrt: der
    /// Save-Pfad wartet nicht auf den Transfer, ein Speichern waehrenddessen
    /// verwuerfe die gerade geladenen Fotos still mit dem View-State.
    ///
    /// - Parameter photoLoadsInFlight: Anzahl der noch laufenden Foto-Transfers
    ///   des Pickers.
    static func canSave(
        hasTitle: Bool,
        hasShip: Bool,
        isSaving: Bool,
        photoLoadsInFlight: Int
    ) -> Bool {
        guard photoLoadsInFlight == 0 else { return false }
        return hasTitle && hasShip && !isSaving
    }
}
