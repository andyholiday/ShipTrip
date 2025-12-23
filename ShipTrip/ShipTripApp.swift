//
//  ShipTripApp.swift
//  ShipTrip
//
//  Created by Andre Book on 18.12.25.
//

import SwiftUI
import SwiftData

@main
struct ShipTripApp: App {
    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            Cruise.self,
            Port.self,
            Expense.self,
            Deal.self,
            Photo.self
        ])
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
        
        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()
    
    var body: some Scene {
        WindowGroup {
            MainTabView()
        }
        .modelContainer(sharedModelContainer)
        // TODO: CloudKit aktivieren wenn Container konfiguriert ist
        // .modelContainer(for: [...], cloudKitDatabase: .private("iCloud.com.yourteam.ShipTrip"))
    }
}

