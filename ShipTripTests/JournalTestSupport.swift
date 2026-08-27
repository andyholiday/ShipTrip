//
//  JournalTestSupport.swift
//  ShipTripTests
//
//  Gemeinsame Fixture-Helfer der Journal-Tests (ADR-003, T7).
//

import Foundation
import SwiftData
@testable import ShipTrip

/// Modelle exakt so registriert wie in `ShipTripApp.init` — `JournalEntry`
/// kommt transitiv über die Beziehungen dazu.
func makeJournalAppSchema() -> Schema {
    Schema([
        Cruise.self, ShipTrip.Port.self, Expense.self, Deal.self, Photo.self,
        CustomShippingLine.self, CustomShip.self, HiddenCatalogItem.self
    ])
}

func makeJournalContainer() throws -> ModelContainer {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    return try ModelContainer(for: makeJournalAppSchema(), configurations: config)
}

func makeJournalCruise(
    _ context: ModelContext,
    title: String = "Nordland-Reise"
) -> Cruise {
    let cruise = Cruise(
        title: title,
        startDate: Date(timeIntervalSince1970: 1_780_000_000),
        endDate: Date(timeIntervalSince1970: 1_780_600_000),
        shippingLine: "AIDA Cruises",
        ship: "AIDAsol"
    )
    context.insert(cruise)
    return cruise
}

func makeJournalPort(
    _ context: ModelContext,
    cruise: Cruise,
    name: String = "Bergen"
) -> ShipTrip.Port {
    let port = ShipTrip.Port(name: name, country: "Norwegen", latitude: 60.39, longitude: 5.32)
    port.cruise = cruise
    context.insert(port)
    return port
}

func makeJournalPhoto(
    _ context: ModelContext,
    cruise: Cruise,
    sortOrder: Int = 0
) -> Photo {
    let photo = Photo(imageData: Data([0x01, 0x02]), sortOrder: sortOrder)
    photo.cruise = cruise
    context.insert(photo)
    return photo
}

/// Feste Zeitstempel für die LWW-Matrix — Bumps sind so eindeutig prüfbar.
enum JournalTestClock {
    static let insert = Date(timeIntervalSince1970: 1_780_000_000)
    static let firstEdit = Date(timeIntervalSince1970: 1_780_003_600)
    static let secondEdit = Date(timeIntervalSince1970: 1_780_007_200)
}
