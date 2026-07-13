//
//  CalendarSyncOperationStateTests.swift
//  ShipTripTests
//

import Testing
@testable import ShipTrip

@Suite("Kalender-Sync UI-Status")
@MainActor
struct CalendarSyncOperationStateTests {

    @Test("Laufender Status bleibt beobachtbar und verhindert einen Doppelstart")
    func runningStateRemainsObservableAndPreventsDuplicateStart() async {
        var state = CalendarSyncOperationState()

        #expect(state.phase == .idle)
        let didBegin = state.begin()
        #expect(didBegin)
        #expect(state.phase == .running)

        await Task.yield()

        #expect(state.phase == .running)
        let didBeginAgain = state.begin()
        #expect(!didBeginAgain)

        state.finish()
        #expect(state.phase == .idle)
    }
}
