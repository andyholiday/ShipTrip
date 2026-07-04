//
//  PortMemoryCardTests.swift
//  ShipTripTests
//
//  Tests für die reine Logik hinter PortMemoryCard (Welle B7.2, Design-Vorschlag B2
//  aus docs/ux-pitch-decks/b6-hafen-momente.html): Liegezeit-Badge-Formatierung und
//  Zero-State-Bedingung. Reine `Port`-Instanzen ohne ModelContext, analog
//  MapMarkerPlannerTests.swift – kein SwiftData-Persistenz nötig für diese Prüfungen.
//

import Testing
import Foundation
@testable import ShipTrip

private typealias CruisePort = ShipTrip.Port

private func makePort(
    arrival: Date = Date(),
    departure: Date = Date(),
    isSeaDay: Bool = false
) -> CruisePort {
    let port = CruisePort(name: "Civitavecchia", country: "Italien", latitude: 42.09, longitude: 11.79)
    port.arrival = arrival
    port.departure = departure
    port.isSeaDay = isSeaDay
    return port
}

// MARK: - stayBadgeText(for:)

@Suite("PortMemoryCard.stayBadgeText")
@MainActor
struct StayBadgeTextTests {

    @Test("Regulärer Hafen: 'Ankunft – Abfahrt' im selben Zeitformat wie zuvor die Metadaten-Zeile")
    func regularPortFormatsArrivalDashDeparture() {
        let arrival = Date()
        let departure = arrival.addingTimeInterval(10 * 60 * 60) // +10h
        let port = makePort(arrival: arrival, departure: departure)

        let expected = "\(arrival.formatted(date: .omitted, time: .shortened)) – \(departure.formatted(date: .omitted, time: .shortened))"
        #expect(PortMemoryCard.stayBadgeText(for: port) == expected)
    }

    @Test("Ankunft == Abfahrt (kein Aufenthalt erfasst): Badge zeigt trotzdem beide Zeiten, kein Crash")
    func sameArrivalAndDepartureStillFormats() {
        let same = Date()
        let port = makePort(arrival: same, departure: same)

        let expected = "\(same.formatted(date: .omitted, time: .shortened)) – \(same.formatted(date: .omitted, time: .shortened))"
        #expect(PortMemoryCard.stayBadgeText(for: port) == expected)
    }

    @Test("Seetag: kein Badge, da keine Liegezeit existiert")
    func seaDayYieldsNil() {
        let port = makePort(isSeaDay: true)
        #expect(PortMemoryCard.stayBadgeText(for: port) == nil)
    }
}

// MARK: - showsZeroStateHero(for:)

@Suite("PortMemoryCard.showsZeroStateHero")
@MainActor
struct ShowsZeroStateHeroTests {

    @Test("Kein Hafenbild, keine Ausflüge: Zero-State")
    func noImageNoExcursionsShowsZeroState() {
        let port = makePort()
        #expect(PortMemoryCard.showsZeroStateHero(for: port))
    }

    @Test("Kein Hafenbild, aber Ausflüge erfasst: Hero bleibt trotzdem Zero-State (Ausflüge stehen separat darunter)")
    func noImageWithExcursionsStillShowsZeroState() {
        let port = makePort()
        port.excursions = ["Kolosseum", "Vatikan-Tour"]
        #expect(PortMemoryCard.showsZeroStateHero(for: port))
    }

    @Test("Hafenbild vorhanden: kein Zero-State, unabhängig von Ausflügen")
    func imagePresentNeverShowsZeroState() {
        let port = makePort()
        port.imageData = Data([0xAA, 0xBB])
        #expect(!PortMemoryCard.showsZeroStateHero(for: port))

        port.excursions = ["Stadtrundgang"]
        #expect(!PortMemoryCard.showsZeroStateHero(for: port))
    }
}

// MARK: - shouldRender(for:)

@Suite("PortMemoryCard.shouldRender")
@MainActor
struct ShouldRenderTests {

    @Test("Echter Hafen ohne Momente: Karte trotzdem sichtbar (Zero-State-Einladung)")
    func regularPortWithoutMomentsStillRenders() {
        let port = makePort()
        #expect(PortMemoryCard.shouldRender(for: port))
    }

    @Test("Seetag ohne Momente: keine Karte (kompakte Zeile bleibt wie bisher)")
    func seaDayWithoutMomentsDoesNotRender() {
        let port = makePort(isSeaDay: true)
        #expect(!PortMemoryCard.shouldRender(for: port))
    }

    @Test("Seetag mit Hafenbild: Karte erscheint trotzdem")
    func seaDayWithImageRenders() {
        let port = makePort(isSeaDay: true)
        port.imageData = Data([0xAA, 0xBB])
        #expect(PortMemoryCard.shouldRender(for: port))
    }

    @Test("Seetag mit Ausflug: Karte erscheint trotzdem")
    func seaDayWithExcursionRenders() {
        let port = makePort(isSeaDay: true)
        port.excursions = ["Landausflug am Seetag"]
        #expect(PortMemoryCard.shouldRender(for: port))
    }
}
