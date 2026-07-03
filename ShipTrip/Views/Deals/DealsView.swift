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
                } else if filteredDeals.isEmpty {
                    ContentUnavailableView.search(text: searchText)
                } else {
                    dealsList
                }
            }
            .navigationTitle("Wunschreisen")
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
            Label("Keine Einträge", systemImage: "bookmark")
        } description: {
            Text("Speichere interessante Kreuzfahrten als Wunschreisen")
        } actions: {
            Button {
                showingAddSheet = true
            } label: {
                Text("Eintrag hinzufügen")
            }
            .buttonStyle(.borderedProminent)
        }
    }
    
    private var dealsList: some View {
        List {
            if let featuredDeal = filteredDeals.first {
                DealHeroView(deal: featuredDeal)
                    .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 12, trailing: 16))
                    .listRowSeparator(.hidden)
            }

            ForEach(Array(filteredDeals.dropFirst())) { deal in
                DealRowView(deal: deal)
            }
            .onDelete(perform: deleteListDeals)
        }
        .listStyle(.plain)
    }
    
    private func deleteListDeals(at offsets: IndexSet) {
        for index in offsets {
            modelContext.delete(filteredDeals[index + 1])
        }
    }
}

/// Größere Wunschreise-Karte für den besten/obersten Merkliste-Eintrag.
struct DealHeroView: View {
    let deal: Deal

    @State private var showingEditSheet = false

    var body: some View {
        Button {
            showingEditSheet = true
        } label: {
            VStack(alignment: .leading, spacing: 0) {
                coverImage
                    .frame(height: 154)
                    .frame(maxWidth: .infinity)
                    .clipped()
                    .overlay(alignment: .topLeading) {
                        if deal.discountPercent != nil {
                            Text(String(localized: "Beste Option"))
                                .font(.caption2)
                                .fontWeight(.bold)
                                .foregroundStyle(.white)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background(Color.sunsetOrange)
                                .clipShape(Capsule())
                                .padding(12)
                        }
                    }

                VStack(alignment: .leading, spacing: 8) {
                    Text(deal.title)
                        .font(.headline)
                        .lineLimit(2)

                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)

                    HStack(alignment: .lastTextBaseline) {
                        if let discount = deal.discountPercent {
                            Text("-\(discount)%")
                                .font(.caption)
                                .fontWeight(.bold)
                                .foregroundStyle(Color.seaGreen)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background(Color.seaGreen.opacity(0.12))
                                .clipShape(Capsule())
                        }

                        Spacer()

                        if let price = deal.formattedPrice {
                            Text(price)
                                .font(.title3)
                                .fontWeight(.heavy)
                        }
                    }
                }
                .padding(15)
                .background(Color(UIColor.secondarySystemBackground))
            }
            .clipShape(RoundedRectangle(cornerRadius: DesignRadius.lg))
            .shadow(color: .black.opacity(0.10), radius: 16, y: 8)
        }
        .buttonStyle(.plain)
        .sheet(isPresented: $showingEditSheet) {
            DealFormView(deal: deal)
        }
    }

    @ViewBuilder
    private var coverImage: some View {
        if let image = coverAssetImage {
            image
                .resizable()
                .aspectRatio(contentMode: .fill)
        } else {
            Image("cover_ocean_route")
                .resizable()
                .aspectRatio(contentMode: .fill)
        }
    }

    private var coverAssetImage: Image? {
        ShippingLine.coverAssetCandidates(
            shippingLine: deal.shippingLine ?? "",
            ship: deal.ship ?? ""
        )
        .lazy
        .compactMap { UIImage(named: $0) }
        .first
        .map { Image(uiImage: $0) }
    }

    private var subtitle: String {
        [
            deal.ship,
            deal.destination,
            deal.duration.map { "\($0) \(String(localized: "Tage"))" }
        ]
        .compactMap { $0 }
        .filter { !$0.isEmpty }
        .joined(separator: " · ")
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
                    .clipShape(RoundedRectangle(cornerRadius: DesignRadius.sm))
                
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
                            Text("\(duration) \(String(localized: "Tage"))")
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
                    TextField("Aktueller Preis", text: $price)
                        .keyboardType(.decimalPad)

                    TextField("Originalpreis", text: $originalPrice)
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
                        .textInputAutocapitalization(.never)
                }
                
                Section("Notizen") {
                    TextEditor(text: $notes)
                        .frame(minHeight: 80)
                }
            }
            .navigationTitle(isEditing ? "Eintrag bearbeiten" : "Neuer Eintrag")
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
        targetDeal.updatedAt = Date()

        dismiss()
    }
}

#Preview {
    DealsView()
        .modelContainer(for: [Deal.self], inMemory: true)
}
