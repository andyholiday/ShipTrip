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
    @State private var amount = ""
    @State private var descriptionText = ""
    @State private var expenseDate: Date = Date()
    @State private var hasDate = false
    
    private var isEditing: Bool { expense != nil }
    
    var body: some View {
        NavigationStack {
            Form {
                // Kategorie
                Section("Kategorie") {
                    Picker("Kategorie", selection: $category) {
                        ForEach(ExpenseCategory.allCases) { cat in
                            Label(cat.rawValue, systemImage: cat.icon)
                                .tag(cat)
                        }
                    }
                    .pickerStyle(.navigationLink)
                }
                
                // Betrag
                Section("Betrag") {
                    HStack {
                        TextField("0,00", text: $amount)
                            .keyboardType(.decimalPad)
                        Text("€")
                            .foregroundStyle(.secondary)
                    }
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
                        .disabled(amount.isEmpty)
                }
            }
            .onAppear { loadExistingData() }
        }
    }
    
    // MARK: - Data
    
    private func loadExistingData() {
        guard let expense = expense else { return }
        category = expense.category
        amount = String(format: "%.2f", expense.amount).replacingOccurrences(of: ".", with: ",")
        descriptionText = expense.descriptionText
        if let date = expense.expenseDate {
            expenseDate = date
            hasDate = true
        }
    }
    
    private func saveExpense() {
        // Parse amount (handle German comma format)
        let normalizedAmount = amount.replacingOccurrences(of: ",", with: ".")
        guard let parsedAmount = Double(normalizedAmount), parsedAmount > 0 else { return }
        
        if let existingExpense = expense {
            // Update
            existingExpense.category = category
            existingExpense.amount = parsedAmount
            existingExpense.descriptionText = descriptionText
            existingExpense.expenseDate = hasDate ? expenseDate : nil
        } else {
            // Create new
            let newExpense = Expense(category: category, amount: parsedAmount, description: descriptionText)
            newExpense.expenseDate = hasDate ? expenseDate : nil
            newExpense.cruise = cruise
            modelContext.insert(newExpense)
        }
        
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
