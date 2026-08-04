//
//  CalendarTargetChangePlannerTests.swift
//  ShipTripTests
//

import Testing
@testable import ShipTrip

@Suite("Kalenderwechsel bei aktivem Sync")
struct CalendarTargetChangePlannerTests {

    @Test("Wechsel mit bestehenden Terminen verlangt eine Bestätigung")
    func changeWithManagedEventsRequiresConfirmation() {
        let decision = CalendarTargetChangePlanner.decide(
            current: "kalender-alt",
            selected: "kalender-neu",
            isSyncEnabled: true,
            hasManagedEvents: true
        )

        #expect(decision == .confirmMigration)
    }

    @Test("Ohne zu übertragende Termine wird direkt übernommen")
    func changeWithoutManagedEventsIsAppliedDirectly() {
        #expect(
            CalendarTargetChangePlanner.decide(
                current: "kalender-alt",
                selected: "kalender-neu",
                isSyncEnabled: true,
                hasManagedEvents: false
            ) == .apply
        )
        #expect(
            CalendarTargetChangePlanner.decide(
                current: "kalender-alt",
                selected: "kalender-neu",
                isSyncEnabled: false,
                hasManagedEvents: true
            ) == .apply
        )
    }

    @Test("Unveränderte oder leere Auswahl löst nichts aus")
    func unchangedSelectionIsIgnored() {
        #expect(
            CalendarTargetChangePlanner.decide(
                current: "kalender-alt",
                selected: "kalender-alt",
                isSyncEnabled: true,
                hasManagedEvents: true
            ) == .ignore
        )
        #expect(
            CalendarTargetChangePlanner.decide(
                current: "kalender-alt",
                selected: "",
                isSyncEnabled: true,
                hasManagedEvents: true
            ) == .ignore
        )
    }
}
