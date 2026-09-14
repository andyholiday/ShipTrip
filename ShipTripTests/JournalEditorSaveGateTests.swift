//
//  JournalEditorSaveGateTests.swift
//  ShipTripTests
//
//  Tests fuer das Save-Gate von Schritt 1 „Erinnerung"
//  (ADR-003, Contract J2 Schritt 1).
//

import Testing
@testable import ShipTrip

@Suite("JournalEditorDefaults.canSave — Save-Gate (J2 Schritt 1)")
struct JournalEditorSaveGateTests {

    @Test("Leerer Eintrag ohne Fotos ist nicht speicherbar")
    func emptyEntryBlocked() {
        #expect(
            JournalEditorDefaults.canSave(
                hasText: false, pendingPhotoCount: 0,
                attachedPhotoCount: 0, photoLoadsInFlight: 0
            ) == false
        )
    }

    @Test("Text allein reicht; ein Foto allein reicht ebenfalls")
    func textOrPhotoUnlocks() {
        #expect(
            JournalEditorDefaults.canSave(
                hasText: true, pendingPhotoCount: 0,
                attachedPhotoCount: 0, photoLoadsInFlight: 0
            )
        )
        #expect(
            JournalEditorDefaults.canSave(
                hasText: false, pendingPhotoCount: 1,
                attachedPhotoCount: 0, photoLoadsInFlight: 0
            )
        )
        #expect(
            JournalEditorDefaults.canSave(
                hasText: false, pendingPhotoCount: 0,
                attachedPhotoCount: 1, photoLoadsInFlight: 0
            )
        )
    }

    /// Repro der Foto-Verlust-Race: der Picker laedt noch, `canSave` war aber
    /// schon durch den Text erfuellt — der User konnte speichern und dismissen,
    /// bevor die gewaehlten Fotos im View-State ankamen. Sie gingen still
    /// verloren, weil `save()` den Transfer nicht abwartet.
    @Test("Laufender Foto-Transfer sperrt das Speichern")
    func loadingBlocksSave() {
        #expect(
            JournalEditorDefaults.canSave(
                hasText: true, pendingPhotoCount: 0,
                attachedPhotoCount: 0, photoLoadsInFlight: 1
            ) == false
        )
        #expect(
            JournalEditorDefaults.canSave(
                hasText: false, pendingPhotoCount: 0,
                attachedPhotoCount: 1, photoLoadsInFlight: 1
            ) == false
        )
    }

    @Test("Nach Abschluss aller Transfers ist wieder speicherbar")
    func saveUnlocksAfterLoading() {
        #expect(
            JournalEditorDefaults.canSave(
                hasText: true, pendingPhotoCount: 1,
                attachedPhotoCount: 0, photoLoadsInFlight: 0
            )
        )
    }
}
