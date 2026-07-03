//
//  ExpenseFormView.swift
//  ShipTrip
//
//  Created by ShipTrip on 18.12.25.
//

import SwiftUI
import SwiftData

/// Formular zum Hinzufügen/Bearbeiten einer Ausgabe
struct ExpenseFormView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    
    let cruise: Cruise
    let expense: Expense?
    
    // Form State
    @State private var category: ExpenseCategory = .cruise
    @State private var amount: Double = 0
    @State private var descriptionText = ""
    @State private var expenseDate: Date = Date()
    @State private var hasDate: Bool

    private var isEditing: Bool { expense != nil }

    init(cruise: Cruise, expense: Expense?) {
        self.cruise = cruise
        self.expense = expense
        // Neue Ausgaben starten mit Datum an (heute); beim Bearbeiten übernimmt
        // loadExistingData() den tatsächlichen Stand, ohne heimlich ein Datum zu setzen.
        _hasDate = State(initialValue: expense == nil)
    }

    var body: some View {
        NavigationStack {
            Form {
                // Kategorie
                Section("Kategorie") {
                    Picker("Kategorie", selection: $category) {
                        ForEach(ExpenseCategory.allCases) { cat in
                            Label(cat.displayName, systemImage: cat.icon)
                                .tag(cat)
                        }
                    }
                    .pickerStyle(.navigationLink)
                }
                
                // Betrag
                Section("Betrag") {
                    amountField
                }
                
                // Beschreibung
                Section("Beschreibung") {
                    TextField("Optional", text: $descriptionText)
                }
                
                // Datum
                Section {
                    Toggle("Datum angeben", isOn: $hasDate)
                    
                    if hasDate {
                        DatePicker("Datum", selection: $expenseDate, displayedComponents: .date)
                    }
                }
            }
            .navigationTitle(isEditing ? "Ausgabe bearbeiten" : "Ausgabe hinzufügen")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Abbrechen") { dismiss() }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("Speichern") { saveExpense() }
                        .disabled(amount <= 0)
                }
            }
            .onAppear { loadExistingData() }
        }
    }

    /// Betragsfeld: Currency-Format, falls die Geräte-Locale eine Währung kennt;
    /// sonst neutrales Zahlenformat statt eines hartkodierten EUR-Fallbacks.
    @ViewBuilder
    private var amountField: some View {
        if let currencyCode = Locale.current.currency?.identifier {
            TextField("Betrag", value: $amount, format: .currency(code: currencyCode))
                .keyboardType(.decimalPad)
        } else {
            TextField("Betrag", value: $amount, format: .number.precision(.fractionLength(2)))
                .keyboardType(.decimalPad)
        }
    }

    // MARK: - Data
    
    private func loadExistingData() {
        guard let expense = expense else { return }
        category = expense.category
        amount = expense.amount
        descriptionText = expense.descriptionText
        if let date = expense.expenseDate {
            expenseDate = date
            hasDate = true
        }
    }

    private func saveExpense() {
        guard amount > 0 else { return }

        let now = Date()

        if let existingExpense = expense {
            // Update
            existingExpense.category = category
            existingExpense.amount = amount
            existingExpense.descriptionText = descriptionText
            existingExpense.expenseDate = hasDate ? expenseDate : nil
            existingExpense.updatedAt = now
        } else {
            // Create new
            let newExpense = Expense(category: category, amount: amount, description: descriptionText)
            newExpense.expenseDate = hasDate ? expenseDate : nil
            newExpense.cruise = cruise
            modelContext.insert(newExpense)
        }

        // Eltern-Kreuzfahrt als geändert markieren (Last-Writer-Wins unter CloudKit)
        cruise.updatedAt = now

        dismiss()
    }
}

#Preview {
    ExpenseFormView(
        cruise: Cruise(
            title: "Test",
            startDate: Date(),
            endDate: Date(),
            shippingLine: "Test",
            ship: "Test"
        ),
        expense: nil
    )
    .modelContainer(for: [Cruise.self, Expense.self], inMemory: true)
}
