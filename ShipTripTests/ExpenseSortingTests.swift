//
//  ExpenseSortingTests.swift
//  ShipTripTests
//
//  Verifiziert ExpenseSorting.sorted(_:): chronologisch aufsteigend,
//  Ausgaben ohne Datum zuletzt, stabiler Tie-Breaker bei Gleichstand.
//

import Testing
import Foundation
@testable import ShipTrip

@Suite("ExpenseSorting")
struct ExpenseSortingTests {

    private func makeExpense(
        description: String,
        date: Date?,
        createdAt: Date = Date()
    ) -> Expense {
        let expense = Expense(category: .other, amount: 1, description: description)
        expense.expenseDate = date
        expense.createdAt = createdAt
        return expense
    }

    @Test("Sortiert Ausgaben mit Datum chronologisch aufsteigend")
    func sortsByDateAscending() {
        let later = makeExpense(description: "später", date: Date(timeIntervalSince1970: 200))
        let earlier = makeExpense(description: "früher", date: Date(timeIntervalSince1970: 100))

        let result = ExpenseSorting.sorted([later, earlier])

        #expect(result.map(\.descriptionText) == ["früher", "später"])
    }

    @Test("Ausgaben ohne Datum stehen am Ende, unabhängig von der Ausgangsreihenfolge")
    func undatedExpensesGoLast() {
        let undated = makeExpense(description: "ohne Datum", date: nil)
        let dated = makeExpense(description: "mit Datum", date: Date(timeIntervalSince1970: 100))

        let result = ExpenseSorting.sorted([undated, dated])

        #expect(result.map(\.descriptionText) == ["mit Datum", "ohne Datum"])
    }

    @Test("Bei identischem Datum entscheidet der Erstellungszeitpunkt")
    func tieBreaksByCreatedAt() {
        let sameDate = Date(timeIntervalSince1970: 100)
        let createdSecond = makeExpense(description: "zweite", date: sameDate, createdAt: Date(timeIntervalSince1970: 20))
        let createdFirst = makeExpense(description: "erste", date: sameDate, createdAt: Date(timeIntervalSince1970: 10))

        let result = ExpenseSorting.sorted([createdSecond, createdFirst])

        #expect(result.map(\.descriptionText) == ["erste", "zweite"])
    }

    @Test("Bei identischem Datum und Erstellungszeitpunkt entscheidet die ID deterministisch")
    func tieBreaksByIdWhenCreatedAtMatches() {
        let sameDate = Date(timeIntervalSince1970: 100)
        let sameCreatedAt = Date(timeIntervalSince1970: 10)
        let a = makeExpense(description: "a", date: sameDate, createdAt: sameCreatedAt)
        let b = makeExpense(description: "b", date: sameDate, createdAt: sameCreatedAt)

        let expected = [a, b].sorted { $0.id.uuidString < $1.id.uuidString }.map(\.descriptionText)

        let result = ExpenseSorting.sorted([b, a])

        #expect(result.map(\.descriptionText) == expected)
    }

    @Test("Mehrere Ausgaben ohne Datum behalten untereinander eine stabile Reihenfolge")
    func multipleUndatedExpensesStableAmongThemselves() {
        let earlierCreated = makeExpense(description: "zuerst erstellt", date: nil, createdAt: Date(timeIntervalSince1970: 10))
        let laterCreated = makeExpense(description: "danach erstellt", date: nil, createdAt: Date(timeIntervalSince1970: 20))
        let dated = makeExpense(description: "mit Datum", date: Date(timeIntervalSince1970: 5))

        let result = ExpenseSorting.sorted([laterCreated, dated, earlierCreated])

        #expect(result.map(\.descriptionText) == ["mit Datum", "zuerst erstellt", "danach erstellt"])
    }
}
