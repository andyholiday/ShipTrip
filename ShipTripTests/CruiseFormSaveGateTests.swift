//
//  CruiseFormSaveGateTests.swift
//  ShipTripTests
//
//  Tests fuer das Save-Gate des Reise-Formulars.
//

import Testing
@testable import ShipTrip

@Suite("CruiseFormSaveGate.canSave — Save-Gate des Reise-Formulars")
struct CruiseFormSaveGateTests {

    @Test("Ohne Titel oder ohne Schiff ist nicht speicherbar")
    func requiredFieldsBlock() {
        #expect(
            CruiseFormSaveGate.canSave(
                hasTitle: false, hasShip: true,
                isSaving: false, photoLoadsInFlight: 0
            ) == false
        )
        #expect(
            CruiseFormSaveGate.canSave(
                hasTitle: true, hasShip: false,
                isSaving: false, photoLoadsInFlight: 0
            ) == false
        )
    }

    @Test("Titel und Schiff reichen; ein laufender Save sperrt weiterhin")
    func requiredFieldsUnlockUnlessSaving() {
        #expect(
            CruiseFormSaveGate.canSave(
                hasTitle: true, hasShip: true,
                isSaving: false, photoLoadsInFlight: 0
            )
        )
        #expect(
            CruiseFormSaveGate.canSave(
                hasTitle: true, hasShip: true,
                isSaving: true, photoLoadsInFlight: 0
            ) == false
        )
    }

    /// Repro der Foto-Verlust-Race: der Picker laedt noch, `canSave` war aber
    /// schon durch Titel und Schiff erfuellt — der User konnte speichern und
    /// dismissen, bevor die gewaehlten Fotos im View-State ankamen. Sie gingen
    /// still verloren, weil `saveCruise()` den Transfer nicht abwartet.
    @Test("Laufender Foto-Transfer sperrt das Speichern")
    func loadingBlocksSave() {
        #expect(
            CruiseFormSaveGate.canSave(
                hasTitle: true, hasShip: true,
                isSaving: false, photoLoadsInFlight: 1
            ) == false
        )
    }

    @Test("Nach Abschluss aller Transfers ist wieder speicherbar")
    func saveUnlocksAfterLoading() {
        #expect(
            CruiseFormSaveGate.canSave(
                hasTitle: true, hasShip: true,
                isSaving: false, photoLoadsInFlight: 0
            )
        )
    }
}
