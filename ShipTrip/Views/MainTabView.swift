//
//  MainTabView.swift
//  ShipTrip
//
//  Created by ShipTrip on 18.12.25.
//

import SwiftUI

/// Haupt-Tab-Navigation der App
struct MainTabView: View {
    @State private var selectedTab = 0
    
    var body: some View {
        TabView(selection: $selectedTab) {
            CruiseListView()
                .tabItem {
                    Label("Reisen", systemImage: "ferry")
                }
                .tag(0)
            
            MapView()
                .tabItem {
                    Label("Karte", systemImage: "map")
                }
                .tag(1)
            
            DealsView()
                .tabItem {
                    Label("Angebote", systemImage: "tag")
                }
                .tag(2)
            
            StatsView()
                .tabItem {
                    Label("Statistik", systemImage: "chart.bar")
                }
                .tag(3)
            
            SettingsView()
                .tabItem {
                    Label("Mehr", systemImage: "ellipsis")
                }
                .tag(4)
        }
        .tint(.accentColor)
    }
}

#Preview {
    MainTabView()
        .modelContainer(for: [Cruise.self, Port.self, Expense.self, Deal.self], inMemory: true)
}
