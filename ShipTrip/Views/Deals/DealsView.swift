//
//  DealsView.swift
//  ShipTrip
//
//  Created by ShipTrip on 18.12.25.
//

import SwiftUI
import SwiftData

/// Ansicht für gespeicherte Kreuzfahrt-Angebote
struct DealsView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Deal.createdAt, order: .reverse) private var deals: [Deal]
    
    @State private var showingAddSheet = false
    @State private var searchText = ""
    
    private var filteredDeals: [Deal] {
        guard !searchText.isEmpty else { return deals }
        return deals.filter {
            $0.title.localizedCaseInsensitiveContains(searchText) ||
            ($0.destination?.localizedCaseInsensitiveContains(searchText) ?? false) ||
            ($0.shippingLine?.localizedCaseInsensitiveContains(searchText) ?? false)
        }
    }
    
    var body: some View {
        NavigationStack {
            Group {
                if deals.isEmpty {
                    emptyStateView
                } else {
                    dealsList
                }
            }
            .navigationTitle("Angebote")
            .searchable(text: $searchText, prompt: "Suchen...")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showingAddSheet = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showingAddSheet) {
                DealFormView(deal: nil)
            }
        }
    }
    
    private var emptyStateView: some View {
        ContentUnavailableView {
            Label("Keine Angebote", systemImage: "tag")
        } description: {
            Text("Speichere interessante Kreuzfahrt-Angebote hier")
        } actions: {
            Button {
                showingAddSheet = true
            } label: {
                Text("Angebot hinzufügen")
            }
            .buttonStyle(.borderedProminent)
        }
    }
    
    private var dealsList: some View {
        List {
            ForEach(filteredDeals) { deal in
                DealRowView(deal: deal)
            }
            .onDelete(perform: deleteDeals)
        }
        .listStyle(.plain)
    }
    
    private func deleteDeals(at offsets: IndexSet) {
        for index in offsets {
            modelContext.delete(filteredDeals[index])
        }
    }
}

/// Zeile für ein einzelnes Angebot
struct DealRowView: View {
    let deal: Deal
    
    @State private var showingEditSheet = false
    
    var body: some View {
        Button {
            showingEditSheet = true
        } label: {
            HStack(spacing: 12) {
                // Logo
                Text(deal.shippingLineLogo)
                    .font(.title)
                    .frame(width: 44, height: 44)
                    .background(Color.secondary.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                
                // Content
                VStack(alignment: .leading, spacing: 4) {
                    Text(deal.title)
                        .font(.headline)
                        .lineLimit(1)
                    
                    HStack(spacing: 8) {
                        if let destination = deal.destination {
                            Text(destination)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        
                        if let duration = deal.duration {
                            Text("\(duration) Tage")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                
                Spacer()
                
                // Price
                VStack(alignment: .trailing, spacing: 2) {
                    if let price = deal.formattedPrice {
                        Text(price)
                            .font(.headline)
                            .foregroundStyle(.primary)
                    }
                    
                    if let discount = deal.discountPercent {
                        Text("-\(discount)%")
                            .font(.caption)
                            .fontWeight(.bold)
                            .foregroundStyle(.white)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(.red)
                            .clipShape(Capsule())
                    }
                }
            }
            .padding(.vertical, 4)
        }
        .buttonStyle(.plain)
        .sheet(isPresented: $showingEditSheet) {
            DealFormView(deal: deal)
        }
    }
}

/// Formular für Angebote
struct DealFormView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    
    let deal: Deal?
    
    @State private var title = ""
    @State private var shippingLine: ShippingLine?
    @State private var price = ""
    @State private var originalPrice = ""
    @State private var destination = ""
    @State private var ship = ""
    @State private var url = ""
    @State private var notes = ""
    @State private var startDate = Date()
    @State private var endDate = Date().addingTimeInterval(7 * 24 * 60 * 60)
    @State private var hasDateRange = false
    
    private var isEditing: Bool { deal != nil }
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Allgemein") {
                    TextField("Titel", text: $title)
                    
                    Picker("Reederei", selection: $shippingLine) {
                        Text("Wählen...").tag(nil as ShippingLine?)
                        ForEach(ShippingLine.all) { line in
                            Text("\(line.logo) \(line.name)").tag(line as ShippingLine?)
                        }
                    }
                    
                    TextField("Schiff", text: $ship)
                    TextField("Zielregion", text: $destination)
                }
                
                Section("Preis") {
                    TextField("Aktueller Preis (€)", text: $price)
                        .keyboardType(.decimalPad)
                    
                    TextField("Originalpreis (€)", text: $originalPrice)
                        .keyboardType(.decimalPad)
                }
                
                Section {
                    Toggle("Reisezeitraum", isOn: $hasDateRange)
                    
                    if hasDateRange {
                        DatePicker("Start", selection: $startDate, displayedComponents: .date)
                        DatePicker("Ende", selection: $endDate, displayedComponents: .date)
                    }
                }
                
                Section("Link") {
                    TextField("URL zur Buchungsseite", text: $url)
                        .keyboardType(.URL)
                        .autocapitalization(.none)
                }
                
                Section("Notizen") {
                    TextEditor(text: $notes)
                        .frame(minHeight: 80)
                }
            }
            .navigationTitle(isEditing ? "Angebot bearbeiten" : "Neues Angebot")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Abbrechen") { dismiss() }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("Speichern") { saveDeal() }
                        .disabled(title.isEmpty)
                }
            }
            .onAppear { loadExistingData() }
        }
    }
    
    private func loadExistingData() {
        guard let deal = deal else { return }
        
        title = deal.title
        shippingLine = ShippingLine.all.first { $0.name == deal.shippingLine }
        price = deal.price.map { String(format: "%.2f", $0) } ?? ""
        originalPrice = deal.originalPrice.map { String(format: "%.2f", $0) } ?? ""
        destination = deal.destination ?? ""
        ship = deal.ship ?? ""
        url = deal.url ?? ""
        notes = deal.notes ?? ""
        
        if let start = deal.startDate, let end = deal.endDate {
            hasDateRange = true
            startDate = start
            endDate = end
        }
    }
    
    private func saveDeal() {
        let targetDeal = deal ?? Deal(title: title)
        
        if deal == nil {
            modelContext.insert(targetDeal)
        }
        
        targetDeal.title = title
        targetDeal.shippingLine = shippingLine?.name
        targetDeal.price = Double(price.replacingOccurrences(of: ",", with: "."))
        targetDeal.originalPrice = Double(originalPrice.replacingOccurrences(of: ",", with: "."))
        targetDeal.destination = destination.isEmpty ? nil : destination
        targetDeal.ship = ship.isEmpty ? nil : ship
        targetDeal.url = url.isEmpty ? nil : url
        targetDeal.notes = notes.isEmpty ? nil : notes
        targetDeal.startDate = hasDateRange ? startDate : nil
        targetDeal.endDate = hasDateRange ? endDate : nil
        
        dismiss()
    }
}

#Preview {
    DealsView()
        .modelContainer(for: [Deal.self], inMemory: true)
}
