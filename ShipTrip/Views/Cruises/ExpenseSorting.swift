//
//  ExpenseSorting.swift
//  ShipTrip
//
//  Aus CruiseDetailView.swift ausgelagert (T8d-1), damit die Detailansicht
//  durch das Journal-Wiring nicht weiter wächst. Inhalt unverändert.
//

import Foundation

/// Sortiert Ausgaben chronologisch aufsteigend nach Datum. Ausgaben ohne Datum
/// stehen am Ende. Reine Funktion (kein SwiftData-Zugriff) – testbar in
/// ShipTripTests/ExpenseSortingTests.swift.
enum ExpenseSorting {
    static func sorted(_ expenses: [Expense]) -> [Expense] {
        expenses.sorted { lhs, rhs in
            switch (lhs.expenseDate, rhs.expenseDate) {
            case let (l?, r?):
                if l != r { return l < r }
            case (nil, .some):
                return false
            case (.some, nil):
                return true
            case (nil, nil):
                break
            }
            // Stabiler Tie-Breaker bei gleichem/fehlendem Datum: Erstellungszeitpunkt,
            // zuletzt die UUID (deterministisch statt undefinierter Sortierreihenfolge).
            if lhs.createdAt != rhs.createdAt { return lhs.createdAt < rhs.createdAt }
            return lhs.id.uuidString < rhs.id.uuidString
        }
    }
}
