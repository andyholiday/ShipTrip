//
//  StatsView.swift
//  ShipTrip
//
//  Created by ShipTrip on 18.12.25.
//

import SwiftUI
import SwiftData
import Charts

/// Statistik-Dashboard
struct StatsView: View {
    @Query private var cruises: [Cruise]
    @Query private var expenses: [Expense]
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // Quick Stats Grid
                    quickStatsGrid
                    
                    // Cruises per Year Chart
                    if !cruises.isEmpty {
                        cruisesPerYearChart
                    }
                    
                    // Expenses by Category Chart
                    if !expenses.isEmpty {
                        expensesByCategoryChart
                    }
                    
                    // Top Shipping Lines
                    if !cruises.isEmpty {
                        topShippingLinesSection
                    }
                }
                .padding()
            }
            .navigationTitle("Statistik")
            .background(Color(.systemGroupedBackground))
        }
    }
    
    // MARK: - Quick Stats
    
    private var quickStatsGrid: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
            StatCard(
                icon: "ferry",
                title: "Kreuzfahrten",
                value: "\(cruises.count)",
                color: .blue
            )
            
            StatCard(
                icon: "calendar",
                title: "Reisetage",
                value: "\(totalSeaDays)",
                color: .cyan
            )
            
            StatCard(
                icon: "mappin.and.ellipse",
                title: "Häfen",
                value: "\(uniquePorts)",
                color: .orange
            )
            
            StatCard(
                icon: "globe",
                title: "Länder",
                value: "\(uniqueCountries)",
                color: .green
            )
            
            StatCard(
                icon: "eurosign.circle",
                title: "Ausgaben",
                value: totalExpenses.formatted(.currency(code: "EUR")),
                color: .purple
            )
            
            StatCard(
                icon: "star.fill",
                title: "Ø Bewertung",
                value: averageRating > 0 ? String(format: "%.1f", averageRating) : "-",
                color: .yellow
            )
        }
    }
    
    // MARK: - Cruises per Year Chart
    
    private var cruisesPerYearChart: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Kreuzfahrten pro Jahr")
                .font(.headline)
            
            if cruisesPerYear.isEmpty {
                Text("Keine Daten")
                    .foregroundStyle(.secondary)
                    .frame(height: 200)
                    .frame(maxWidth: .infinity)
            } else {
                Chart(cruisesPerYear, id: \.year) { item in
                    BarMark(
                        x: .value("Jahr", String(item.year)),
                        y: .value("Anzahl", item.count)
                    )
                    .foregroundStyle(.blue.gradient)
                    .cornerRadius(4)
                }
                .frame(height: 200)
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
    
    // MARK: - Expenses by Category Chart
    
    private var expensesByCategoryChart: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Ausgaben nach Kategorie")
                .font(.headline)
            
            let validExpenses = expensesByCategory.filter { $0.total > 0 }
            
            if validExpenses.isEmpty {
                Text("Keine Ausgaben")
                    .foregroundStyle(.secondary)
                    .frame(height: 200)
                    .frame(maxWidth: .infinity)
            } else {
                Chart(validExpenses, id: \.category) { item in
                    SectorMark(
                        angle: .value("Betrag", item.total),
                        innerRadius: .ratio(0.5),
                        angularInset: 1.5
                    )
                    .foregroundStyle(by: .value("Kategorie", item.category.rawValue))
                    .cornerRadius(4)
                }
                .frame(height: 200)
                
                // Legend
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                    ForEach(validExpenses, id: \.category) { item in
                        HStack(spacing: 4) {
                            Image(systemName: item.category.icon)
                                .font(.caption)
                            Text(item.category.rawValue)
                                .font(.caption)
                            Spacer()
                            Text(item.total.formatted(.currency(code: "EUR")))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
    
    // MARK: - Top Shipping Lines
    
    private var topShippingLinesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Top Reedereien")
                .font(.headline)
            
            ForEach(topShippingLines.prefix(5), id: \.name) { item in
                HStack {
                    Text(ShippingLine.all.first { $0.name == item.name }?.logo ?? "🛳️")
                    Text(item.name)
                        .font(.subheadline)
                    Spacer()
                    Text("\(item.count) Reisen")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
    
    // MARK: - Computed Stats
    
    private var totalSeaDays: Int {
        cruises.reduce(0) { $0 + $1.duration }
    }
    
    private var uniquePorts: Int {
        Set(cruises.flatMap { $0.route.map { $0.name } }).count
    }
    
    private var uniqueCountries: Int {
        Set(cruises.flatMap { $0.route.filter { !$0.country.isEmpty }.map { $0.country } }).count
    }
    
    private var totalExpenses: Double {
        expenses.reduce(0) { $0 + $1.amount }
    }
    
    private var averageRating: Double {
        let rated = cruises.filter { $0.rating > 0 }
        guard !rated.isEmpty else { return 0 }
        return rated.reduce(0) { $0 + $1.rating } / Double(rated.count)
    }
    
    private var cruisesPerYear: [(year: Int, count: Int)] {
        let grouped = Dictionary(grouping: cruises, by: { $0.year })
        return grouped.map { (year: $0.key, count: $0.value.count) }
            .sorted { $0.year < $1.year }
    }
    
    private var expensesByCategory: [(category: ExpenseCategory, total: Double)] {
        let grouped = Dictionary(grouping: expenses, by: { $0.category })
        return grouped.map { (category: $0.key, total: $0.value.reduce(0) { $0 + $1.amount }) }
            .sorted { $0.total > $1.total }
    }
    
    private var topShippingLines: [(name: String, count: Int)] {
        let grouped = Dictionary(grouping: cruises, by: { $0.shippingLine })
        return grouped.map { (name: $0.key, count: $0.value.count) }
            .sorted { $0.count > $1.count }
    }
}

/// Statistik-Karte
struct StatCard: View {
    let icon: String
    let title: String
    let value: String
    let color: Color
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(color)
            
            Text(value)
                .font(.title2)
                .fontWeight(.bold)
            
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

#Preview {
    StatsView()
        .modelContainer(for: [Cruise.self, Expense.self], inMemory: true)
}
