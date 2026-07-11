//
//  CruiseDeletionSequenceTests.swift
//  ShipTripTests
//
//  Verhaltens-Check für Task S1.1 (Audit 2026-07-10, H5): beweist, dass ein fehlschlagender
//  Save einen Rollback auslöst und removeReminders NICHT aufgerufen wird (Reise bleibt
//  sichtbar, Erinnerung bleibt bestehen) – ohne echten ModelContext/NotificationService, über
//  die injizierten Seiteneffekte von CruiseDeletionSequence.run.
//

import Testing
@testable import ShipTrip

private struct DeletionTestError: Error {}

@Suite("CruiseDeletionSequence")
struct CruiseDeletionSequenceTests {

    @Test("Erfolgreicher Save: removeReminders wird aufgerufen, kein Rollback")
    func erfolgreicheLoeschungRuftRemoveRemindersAuf() {
        var deleteCalled = false
        var rollbackCalled = false
        var remindersRemoved = false
        var reportedError: Error?

        let succeeded = CruiseDeletionSequence.run(
            delete: { deleteCalled = true },
            save: { },
            rollback: { rollbackCalled = true },
            removeReminders: { remindersRemoved = true },
            onError: { reportedError = $0 }
        )

        #expect(succeeded)
        #expect(deleteCalled)
        #expect(remindersRemoved)
        #expect(!rollbackCalled)
        #expect(reportedError == nil)
    }

    @Test("Fehlgeschlagener Save: Rollback wird aufgerufen, removeReminders bleibt aus")
    func fehlgeschlagenerSaveRuftRollbackAufUndNichtRemoveReminders() {
        var deleteCalled = false
        var rollbackCalled = false
        var remindersRemoved = false
        var reportedError: Error?

        let succeeded = CruiseDeletionSequence.run(
            delete: { deleteCalled = true },
            save: { throw DeletionTestError() },
            rollback: { rollbackCalled = true },
            removeReminders: { remindersRemoved = true },
            onError: { reportedError = $0 }
        )

        #expect(!succeeded)
        #expect(deleteCalled)
        #expect(rollbackCalled)
        #expect(!remindersRemoved)
        #expect(reportedError != nil)
    }
}
