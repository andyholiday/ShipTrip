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
    var body: some Scene {
        WindowGroup {
            MainTabView()
        }
        .modelContainer(for: [
            Cruise.self,
            Port.self,
            Expense.self,
            Deal.self,
            Photo.self
        ])
        // TODO: CloudKit aktivieren wenn Container konfiguriert ist
        // .modelContainer(for: [...], cloudKitDatabase: .private("iCloud.com.yourteam.ShipTrip"))
    }
}
