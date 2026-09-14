//
//  WidgetSnapshotStoreTests.swift
//  ShipTripTests
//
//  Contract-Tests des Widget-Snapshot-Stores (Taskplan 1.9.0, T0):
//  Lesefaelle (fehlend/unlesbar/gueltig), Toleranz gegenueber unbekannten
//  Feldern, Roundtrip am Maximalbestand mit Groessenbudget und
//  Last-known-good beim gescheiterten Schreiben.
//

import Testing
import Foundation
@testable import ShipTrip

// MARK: - Testhilfen

/// Frisches, leeres Verzeichnis je Test.
private func makeTempDirectory() throws -> URL {
    let url = FileManager.default.temporaryDirectory
        .appendingPathComponent("widget-snapshot-tests", isDirectory: true)
        .appendingPathComponent(UUID().uuidString, isDirectory: true)
    try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
    return url
}

/// Zeitpunkt auf volle Sekunden — ISO-8601 kennt keine Sekundenbruchteile.
private func widgetTestDate(_ day: Int, hour: Int) -> Date {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(identifier: "Europe/Berlin") ?? .gmt
    var components = DateComponents()
    components.year = 2026
    components.month = 6
    components.day = day
    components.hour = hour
    return calendar.date(from: components) ?? Date(timeIntervalSince1970: 0)
}

/// Snapshot am Maximalbestand: `maxCruises` Reisen mit je `maxRouteStops`
/// Eintraegen und realistisch langen Namen.
private func makeMaximalSnapshot() -> WidgetSnapshot {
    let cruises = (0..<WidgetSnapshot.maxCruises).map { cruiseIndex in
        let route = (0..<WidgetSnapshot.maxRouteStops).map { stopIndex in
            StopSummary(
                id: UUID(),
                name: "Santa Cruz de Tenerife (Kanarische Inseln) \(stopIndex)",
                country: stopIndex.isMultiple(of: 3) ? nil : "Spanien",
                arrival: widgetTestDate(1 + stopIndex % 28, hour: 8),
                departure: widgetTestDate(1 + stopIndex % 28, hour: 18),
                sortOrder: stopIndex,
                isSeaDay: stopIndex.isMultiple(of: 5)
            )
        }
        return CruiseSummary(
            id: UUID(),
            title: "Grosse Kanaren-Rundreise mit Madeira \(cruiseIndex)",
            ship: "AIDAnova",
            startDate: widgetTestDate(1, hour: 17),
            endDate: widgetTestDate(28, hour: 8),
            route: route
        )
    }
    return WidgetSnapshot(generatedAt: widgetTestDate(3, hour: 12), cruises: cruises)
}

// MARK: - Store-Contract

@Suite("WidgetSnapshotStore — Lesefaelle, Roundtrip, Last-known-good (LE 2/3)")
struct WidgetSnapshotStoreTests {

    // MARK: Lesen

    @Test("Ohne Datei meldet der Store `missing`")
    func missingFile() throws {
        let store = WidgetSnapshotStore(containerURL: try makeTempDirectory())
        #expect(store.load() == .missing)
    }

    @Test("Kaputtes JSON meldet `unreadable`")
    func brokenJSON() throws {
        let store = WidgetSnapshotStore(containerURL: try makeTempDirectory())
        try Data("{ das ist kein JSON".utf8).write(to: store.fileURL)
        #expect(store.load() == .unreadable)
    }

    @Test("Gueltiges JSON mit falscher Struktur meldet `unreadable`")
    func wrongShape() throws {
        let store = WidgetSnapshotStore(containerURL: try makeTempDirectory())
        try Data(#"["kein Objekt, sondern ein Array"]"#.utf8).write(to: store.fileURL)
        #expect(store.load() == .unreadable)
    }

    @Test("Fremde Schema-Version meldet `unreadable` statt sie zu deuten")
    func foreignSchemaVersion() throws {
        let store = WidgetSnapshotStore(containerURL: try makeTempDirectory())
        var snapshot = makeMaximalSnapshot()
        snapshot.schemaVersion = WidgetSnapshot.current + 1
        try store.save(snapshot)
        #expect(store.load() == .unreadable)
    }

    @Test("Unbekannte Zusatzfelder werden ueberlesen, nicht als Fehler gewertet")
    func unknownFieldsAreIgnored() throws {
        let store = WidgetSnapshotStore(containerURL: try makeTempDirectory())
        let snapshot = makeMaximalSnapshot()
        let encoded = try WidgetSnapshotStore.makeEncoder().encode(snapshot)

        // Ein spaeteres Schema derselben Version darf Felder ergaenzen, ohne
        // dass die aktuelle App-Version die Datei fuer unlesbar haelt.
        guard var object = try JSONSerialization.jsonObject(with: encoded) as? [String: Any],
              var cruises = object["cruises"] as? [[String: Any]],
              var route = cruises[0]["route"] as? [[String: Any]] else {
            Issue.record("Snapshot-JSON hat nicht die erwartete Struktur")
            return
        }
        route[0]["tenderPort"] = true
        cruises[0]["route"] = route
        cruises[0]["bookingNumber"] = "AIDA-4711"
        object["cruises"] = cruises
        object["writtenBy"] = "1.9.1"
        try JSONSerialization.data(withJSONObject: object).write(to: store.fileURL)

        #expect(store.load() == .snapshot(snapshot))
    }

    // MARK: Roundtrip

    @Test("Maximalbestand kommt unveraendert zurueck und bleibt unter 64 KB")
    func roundtripAtMaximum() throws {
        // Unterverzeichnis existiert nicht: `save` muss es anlegen.
        let container = try makeTempDirectory().appendingPathComponent("group", isDirectory: true)
        let store = WidgetSnapshotStore(containerURL: container)
        let snapshot = makeMaximalSnapshot()

        try store.save(snapshot)

        #expect(store.load() == .snapshot(snapshot))

        let attributes = try FileManager.default.attributesOfItem(atPath: store.fileURL.path)
        let size = (attributes[.size] as? NSNumber)?.intValue ?? Int.max
        print("Snapshot-Dateigroesse am Maximalbestand "
              + "(\(WidgetSnapshot.maxCruises) Reisen x \(WidgetSnapshot.maxRouteStops) Stopps): "
              + "\(size) Bytes")
        #expect(size < 64 * 1024)
    }

    @Test("Gescheitertes Schreiben laesst die alte Datei unveraendert")
    func failedSaveKeepsLastKnownGood() throws {
        let container = try makeTempDirectory()
        let store = WidgetSnapshotStore(containerURL: container)
        let good = makeMaximalSnapshot()
        try store.save(good)

        // Verzeichnis nur noch lesbar -> der atomare Write kann nicht landen.
        let fileManager = FileManager.default
        try fileManager.setAttributes([.posixPermissions: 0o500], ofItemAtPath: container.path)
        defer {
            try? fileManager.setAttributes(
                [.posixPermissions: 0o700],
                ofItemAtPath: container.path
            )
        }

        var replacement = good
        replacement.generatedAt = widgetTestDate(9, hour: 9)
        #expect(throws: (any Error).self) { try store.save(replacement) }

        #expect(store.load() == .snapshot(good))
    }
}
