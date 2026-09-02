//
//  CalendarSyncModeMigrationTests.swift
//  ShipTripTests
//

import EventKit
import Foundation
import Testing
@testable import ShipTrip

/// Der neue Sync-Umfang (1.8.7): neuer Default, Bestands-Migration und der
/// anklickbare Ort. Die reinen Entscheidungspfade laufen gegen ein isoliertes
/// `UserDefaults`-Suite, die Verhaltenstests gegen den echten EventStore des
/// Simulators (Rechte erteilt der Test-Runner vorab).
@Suite("Kalender-Sync Umfang", .serialized)
@MainActor
struct CalendarSyncModeMigrationTests {

    // MARK: - Default

    @Test("Ohne gespeicherte Auswahl gilt „nur Stopps“")
    func defaultModeIsItineraryOnly() throws {
        let suite = try DefaultsSuite(name: #function)
        defer { suite.tearDown() }

        #expect(CalendarSyncPreferences.mode(in: suite.defaults) == .itineraryOnly)
    }

    // MARK: - Bestands-Migration (Entscheidungspfade)

    @Test("Eine bereits getroffene Auswahl bleibt unangetastet")
    func migrationKeepsExplicitChoice() throws {
        let suite = try DefaultsSuite(name: #function)
        defer { suite.tearDown() }
        suite.defaults.set(
            CalendarSyncMode.tripAndItinerary.rawValue,
            forKey: CalendarSyncPreferences.modeKey
        )

        CalendarSyncModeMigration.run(
            in: suite.defaults,
            hasCalendarAccess: true,
            hasLiveTripEvent: false
        )

        #expect(CalendarSyncPreferences.mode(in: suite.defaults) == .tripAndItinerary)
        #expect(CalendarSyncModeMigration.isSettled(in: suite.defaults))
    }

    @Test("Ein lebender Ganzreise-Termin schreibt den Bestand auf „nur Reisen“ fest")
    func migrationDetectsExistingTripEvent() throws {
        let suite = try DefaultsSuite(name: #function)
        defer { suite.tearDown() }

        CalendarSyncModeMigration.run(
            in: suite.defaults,
            hasCalendarAccess: true,
            hasLiveTripEvent: true
        )

        #expect(CalendarSyncPreferences.mode(in: suite.defaults) == .tripOnly)
        #expect(CalendarSyncModeMigration.isSettled(in: suite.defaults))
    }

    @Test("Ohne Ganzreise-Termin gilt der neue Default")
    func migrationWithoutTripEventPicksItineraryOnly() throws {
        let suite = try DefaultsSuite(name: #function)
        defer { suite.tearDown() }

        CalendarSyncModeMigration.run(
            in: suite.defaults,
            hasCalendarAccess: true,
            hasLiveTripEvent: false
        )

        #expect(
            suite.defaults.string(forKey: CalendarSyncPreferences.modeKey)
                == CalendarSyncMode.itineraryOnly.rawValue
        )
        #expect(CalendarSyncModeMigration.isSettled(in: suite.defaults))
    }

    @Test("Ohne Kalenderzugriff fällt keine Entscheidung")
    func migrationWithoutAccessDecidesNothing() throws {
        let suite = try DefaultsSuite(name: #function)
        defer { suite.tearDown() }

        CalendarSyncModeMigration.run(
            in: suite.defaults,
            hasCalendarAccess: false,
            hasLiveTripEvent: false
        )

        #expect(
            suite.defaults.string(forKey: CalendarSyncPreferences.modeKey) == nil,
            "Ohne Zugriff wurde ein Umfang festgeschrieben, der nicht geprüft werden konnte"
        )
        #expect(
            CalendarSyncModeMigration.isSettled(in: suite.defaults) == false,
            "Der Merker steht, obwohl die Entscheidung nachgeholt werden muss"
        )
    }

    // MARK: - Bestands-Migration im Service

    /// Der zentrale Bestandsbeweis: alter Store-Zustand (Mapping mit
    /// Trip-Schlüssel und echtem Termin) ohne gespeicherten Umfang. Nach dem
    /// nächsten Sync steht der Umfang auf `tripOnly` — der Ganzreise-Termin
    /// des Nutzers verschwindet nicht ungefragt.
    @Test("Bestand mit Ganzreise-Termin behält ihn nach dem Update")
    func existingTripEventSurvivesTheUpdate() throws {
        let fixture = try MigrationFixture(name: #function)
        defer { fixture.tearDown() }
        try fixture.syncIntoOldCalendar()

        fixture.defaults.removeObject(forKey: CalendarSyncPreferences.modeKey)
        fixture.defaults.removeObject(forKey: CalendarSyncModeMigration.markerKey)
        _ = try fixture.service.synchronize(cruises: [fixture.cruise])

        #expect(
            fixture.defaults.string(forKey: CalendarSyncPreferences.modeKey)
                == CalendarSyncMode.tripOnly.rawValue
        )
        #expect(
            fixture.eventCount(in: fixture.oldCalendar) == 1,
            "Der Ganzreise-Termin ist beim Update aus dem Kalender verschwunden"
        )
    }

    // MARK: - Verhalten des Service

    @Test("Der Hafen-Termin trägt einen strukturierten Ort mit Koordinate")
    func portEventCarriesStructuredLocation() throws {
        let fixture = try MigrationFixture(name: #function)
        defer { fixture.tearDown() }
        let port = fixture.addPort(
            name: "Lissabon",
            country: "Portugal",
            latitude: 38.7,
            longitude: -9.1
        )

        fixture.setPreferences(
            calendarIdentifier: fixture.oldCalendar.calendarIdentifier,
            mode: .itineraryOnly
        )
        _ = try fixture.service.synchronize(cruises: [fixture.cruise])

        let identifier = try #require(fixture.managedIdentifiers[fixture.routeKey(for: port)])
        let event = try #require(fixture.store.event(withIdentifier: identifier))
        let location = try #require(
            event.structuredLocation,
            "Ohne strukturierten Ort bleibt der Eintrag im Kalender nicht anklickbar"
        )
        #expect(location.title == "Lissabon, Portugal")

        let geoLocation = try #require(location.geoLocation)
        #expect(abs(geoLocation.coordinate.latitude - 38.7) < 0.0001)
        #expect(abs(geoLocation.coordinate.longitude + 9.1) < 0.0001)
    }

    @Test("Die Beispielreise landet nicht im Kalender")
    func demoCruiseIsNotSynchronized() throws {
        let fixture = try MigrationFixture(name: #function)
        defer { fixture.tearDown() }
        fixture.addPort(name: "Nassau", country: "Bahamas", latitude: 25.1, longitude: -77.3)
        fixture.cruise.isDemo = true

        fixture.setPreferences(
            calendarIdentifier: fixture.oldCalendar.calendarIdentifier,
            mode: .tripAndItinerary
        )
        let synchronized = try fixture.service.synchronize(cruises: [fixture.cruise])

        #expect(synchronized == 0)
        #expect(fixture.eventCount(in: fixture.oldCalendar) == 0)
        #expect(fixture.managedIdentifiers.isEmpty)
    }

    @Test("Umfang umschalten entfernt und erzeugt den Ganzreise-Termin")
    func switchingScopeReconcilesTheTripEvent() throws {
        let fixture = try MigrationFixture(name: #function)
        defer { fixture.tearDown() }
        fixture.addPort(name: "Funchal", country: "Portugal", latitude: 32.6, longitude: -16.9)
        let tripKey = "cruise/\(fixture.cruise.id.uuidString)/trip"

        fixture.setPreferences(
            calendarIdentifier: fixture.oldCalendar.calendarIdentifier,
            mode: .tripAndItinerary
        )
        _ = try fixture.service.synchronize(cruises: [fixture.cruise])
        #expect(fixture.eventCount(in: fixture.oldCalendar) == 2)

        fixture.setPreferences(
            calendarIdentifier: fixture.oldCalendar.calendarIdentifier,
            mode: .itineraryOnly
        )
        _ = try fixture.service.synchronize(cruises: [fixture.cruise])
        #expect(
            fixture.managedIdentifiers[tripKey] == nil,
            "Das Opt-in ist aus, der Ganzreise-Termin steht aber noch im Kalender"
        )
        #expect(fixture.eventCount(in: fixture.oldCalendar) == 1)

        fixture.setPreferences(
            calendarIdentifier: fixture.oldCalendar.calendarIdentifier,
            mode: .tripOnly
        )
        _ = try fixture.service.synchronize(cruises: [fixture.cruise])
        #expect(fixture.managedIdentifiers[tripKey] != nil)
        #expect(fixture.eventCount(in: fixture.oldCalendar) == 1)
    }
}

// MARK: - Hilfen

/// Isoliertes `UserDefaults`-Suite je Test — nie `UserDefaults.standard`, den
/// teilt sich der Test-Host mit allen anderen Suiten (F15).
struct DefaultsSuite {
    enum SuiteError: Error {
        case suiteUnavailable
    }

    let defaults: UserDefaults
    private let suiteName: String

    init(name: String) throws {
        let suiteName = "CalendarSyncModeMigrationTests.\(name)"
        guard let defaults = UserDefaults(suiteName: suiteName) else {
            throw SuiteError.suiteUnavailable
        }
        defaults.removePersistentDomain(forName: suiteName)
        self.suiteName = suiteName
        self.defaults = defaults
    }

    func tearDown() {
        defaults.removePersistentDomain(forName: suiteName)
    }
}

extension MigrationFixture {

    /// Hängt einen Hafen mit Liegezeit am ersten Reisetag an die Testreise.
    @discardableResult
    func addPort(name: String, country: String, latitude: Double, longitude: Double) -> Port {
        let port = Port(name: name, country: country, latitude: latitude, longitude: longitude)
        port.arrival = cruise.startDate.addingTimeInterval(9 * 3_600)
        port.departure = cruise.startDate.addingTimeInterval(18 * 3_600)
        port.sortOrder = cruise.route.count
        cruise.route.append(port)
        return port
    }

    func routeKey(for port: Port) -> String {
        "cruise/\(cruise.id.uuidString)/route/\(port.id.uuidString)"
    }
}
