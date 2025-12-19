//
//  CruiseDetailView.swift
//  ShipTrip
//
//  Created by ShipTrip on 18.12.25.
//

import SwiftUI
import SwiftData

/// Detailansicht einer Kreuzfahrt
struct CruiseDetailView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    
    @Bindable var cruise: Cruise
    
    @State private var showingEditSheet = false
    @State private var showingDeleteAlert = false
    @State private var showingAddPortSheet = false
    @State private var showingAddExpenseSheet = false
    @State private var selectedPort: Port?
    @State private var selectedExpense: Expense?
    @State private var refreshID = UUID()
    
    private let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "dd.MM.yyyy"
        return formatter
    }()
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                // Hero Image
                heroImageSection
                
                // Info Section
                infoSection
                
                // Route Section
                routeSection
                
                // Expenses Section
                expensesSection
                
                // Notes Section
                if !cruise.notes.isEmpty {
                    notesSection
                }
            }
            .padding()
        }
        .id(refreshID)
        .navigationTitle(cruise.title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Menu {
                    Button {
                        showingEditSheet = true
                    } label: {
                        Label("Bearbeiten", systemImage: "pencil")
                    }
                    
                    Button(role: .destructive) {
                        showingDeleteAlert = true
                    } label: {
                        Label("Löschen", systemImage: "trash")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }
        }
        .sheet(isPresented: $showingEditSheet) {
            CruiseFormView(cruise: cruise)
        }
        .sheet(isPresented: $showingAddPortSheet, onDismiss: refreshView) {
            PortFormView(cruise: cruise, port: nil)
        }
        .sheet(isPresented: $showingAddExpenseSheet, onDismiss: refreshView) {
            ExpenseFormView(cruise: cruise, expense: nil)
        }
        .sheet(item: $selectedPort, onDismiss: refreshView) { port in
            PortFormView(cruise: cruise, port: port)
        }
        .sheet(item: $selectedExpense, onDismiss: refreshView) { expense in
            ExpenseFormView(cruise: cruise, expense: expense)
        }
        .alert("Kreuzfahrt löschen?", isPresented: $showingDeleteAlert) {
            Button("Abbrechen", role: .cancel) { }
            Button("Löschen", role: .destructive) {
                deleteCruise()
            }
        } message: {
            Text("Diese Aktion kann nicht rückgängig gemacht werden.")
        }
    }
    
    // MARK: - Sections
    
    private var heroImageSection: some View {
        Group {
            if !cruise.photos.isEmpty {
                TabView {
                    ForEach(Array(cruise.sortedPhotos.enumerated()), id: \.offset) { _, photo in
                        if let uiImage = UIImage(data: photo.imageData) {
                            Image(uiImage: uiImage)
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                        }
                    }
                }
                .frame(height: 250)
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .tabViewStyle(.page)
            } else {
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.secondary.opacity(0.2))
                    .frame(height: 200)
                    .overlay {
                        VStack {
                            Image(systemName: "photo.on.rectangle")
                                .font(.largeTitle)
                            Text("Keine Fotos")
                                .font(.caption)
                        }
                        .foregroundStyle(.secondary)
                    }
            }
        }
    }
    
    private var infoSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Rating
            if cruise.rating > 0 {
                HStack {
                    ForEach(1...5, id: \.self) { star in
                        Image(systemName: star <= Int(cruise.rating) ? "star.fill" : "star")
                            .foregroundStyle(.yellow)
                    }
                    Text(String(format: "%.1f", cruise.rating))
                        .foregroundStyle(.secondary)
                }
            }
            
            // Info Cards Grid
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                InfoCard(icon: "ferry", title: "Schiff", value: cruise.ship)
                InfoCard(icon: cruise.shippingLineLogo, title: "Reederei", value: cruise.shippingLine, isEmoji: true)
                InfoCard(icon: "calendar", title: "Zeitraum", value: "\(dateFormatter.string(from: cruise.startDate)) - \(dateFormatter.string(from: cruise.endDate))")
                InfoCard(icon: "clock", title: "Dauer", value: "\(cruise.duration) Tage")
                
                if !cruise.cabinType.isEmpty {
                    InfoCard(icon: "bed.double", title: "Kabine", value: cruise.cabinType)
                }
                
                if !cruise.bookingNumber.isEmpty {
                    InfoCard(icon: "number", title: "Buchung", value: cruise.bookingNumber)
                }
            }
        }
    }
    
    private var routeSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Route")
                    .font(.headline)
                Spacer()
                Button {
                    showingAddPortSheet = true
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .foregroundStyle(Color.accentColor)
                }
            }
            
            if cruise.route.isEmpty {
                Text("Noch keine Häfen hinzugefügt")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 20)
            } else {
                ForEach(cruise.route.sorted(by: { $0.sortOrder < $1.sortOrder })) { port in
                    HStack(spacing: 12) {
                        Circle()
                            .fill(Color.blue)
                            .frame(width: 12, height: 12)
                        
                        VStack(alignment: .leading) {
                            Text(port.name)
                                .font(.subheadline)
                                .fontWeight(.medium)
                            Text(port.country)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        
                        Spacer()
                        
                        Text(port.formattedArrival)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 4)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        selectedPort = port
                    }
                    .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                        Button(role: .destructive) {
                            deletePort(port)
                        } label: {
                            Label("Löschen", systemImage: "trash")
                        }
                    }
                }
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
    
    private var expensesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Ausgaben")
                    .font(.headline)
                Spacer()
                if !cruise.expenses.isEmpty {
                    Text(cruise.totalExpenses.formatted(.currency(code: "EUR")))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                Button {
                    showingAddExpenseSheet = true
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .foregroundStyle(Color.accentColor)
                }
            }
            
            if cruise.expenses.isEmpty {
                Text("Noch keine Ausgaben erfasst")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 20)
            } else {
                ForEach(cruise.expenses) { expense in
                    HStack {
                        Image(systemName: expense.category.icon)
                            .foregroundStyle(.secondary)
                            .frame(width: 24)
                        
                        VStack(alignment: .leading) {
                            Text(expense.category.rawValue)
                                .font(.subheadline)
                            if !expense.descriptionText.isEmpty {
                                Text(expense.descriptionText)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        
                        Spacer()
                        
                        Text(expense.formattedAmount)
                            .font(.subheadline)
                            .fontWeight(.medium)
                    }
                    .padding(.vertical, 4)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        selectedExpense = expense
                    }
                    .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                        Button(role: .destructive) {
                            deleteExpense(expense)
                        } label: {
                            Label("Löschen", systemImage: "trash")
                        }
                    }
                }
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
    
    private var notesSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Notizen")
                .font(.headline)
            Text(cruise.notes)
                .font(.body)
                .foregroundStyle(.secondary)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
    
    // MARK: - Actions
    
    private func deleteCruise() {
        modelContext.delete(cruise)
        dismiss()
    }
    
    private func deletePort(_ port: Port) {
        modelContext.delete(port)
        refreshView()
    }
    
    private func deleteExpense(_ expense: Expense) {
        modelContext.delete(expense)
        refreshView()
    }
    
    private func refreshView() {
        refreshID = UUID()
    }
}

/// Info-Karte für die Detailansicht
struct InfoCard: View {
    let icon: String
    let title: String
    let value: String
    var isEmoji: Bool = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 4) {
                if isEmoji {
                    Text(icon)
                } else {
                    Image(systemName: icon)
                        .foregroundStyle(.secondary)
                }
                Text(title)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Text(value)
                .font(.subheadline)
                .fontWeight(.medium)
                .lineLimit(2)
                .minimumScaleFactor(0.8)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }
}

#Preview {
    NavigationStack {
        CruiseDetailView(cruise: Cruise(
            title: "Mittelmeer Kreuzfahrt",
            startDate: Date(),
            endDate: Date().addingTimeInterval(7 * 24 * 60 * 60),
            shippingLine: "TUI Cruises - Mein Schiff",
            ship: "Mein Schiff 4"
        ))
    }
    .modelContainer(for: [Cruise.self, Port.self, Expense.self], inMemory: true)
}
