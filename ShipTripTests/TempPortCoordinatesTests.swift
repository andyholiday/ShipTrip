//
//  TempPortCoordinatesTests.swift
//  ShipTripTests
//
//  Regression zu Audit-Finding 1.2/H-A: Beim Bearbeiten eines Hafens im Reise-Formular
//  (`TempPortFormSheet.savePort`) dürfen selbst gesetzte Koordinaten nicht verschwinden,
//  nur weil der Hafenname nicht im Katalog (`PortSuggestion`) steht.
//

import Testing
@testable import ShipTrip

@Suite("TempPort-Koordinaten beim Bearbeiten")
struct TempPortCoordinatesTests {

    private static let katalogTreffer = PortSuggestion(
        name: "Hamburg",
        country: "Deutschland",
        latitude: 53.5,
        longitude: 9.9
    )

    @Test("Name und Land unverändert: selbst gesetzte Koordinaten bleiben erhalten")
    func keepsManualCoordinatesWhenNothingChanged() {
        let result = TempPortFormSheet.resolvedCoordinates(
            existing: (latitude: 12.34, longitude: 56.78),
            nameChanged: false,
            countryChanged: false,
            catalogMatch: nil
        )

        #expect(result.latitude == 12.34)
        #expect(result.longitude == 56.78)
    }

    @Test("Name geändert, kein Katalog-Treffer: bestehende Koordinaten werden nicht gelöscht")
    func keepsManualCoordinatesWithoutCatalogMatch() {
        let result = TempPortFormSheet.resolvedCoordinates(
            existing: (latitude: 12.34, longitude: 56.78),
            nameChanged: true,
            countryChanged: false,
            catalogMatch: nil
        )

        #expect(result.latitude == 12.34)
        #expect(result.longitude == 56.78)
    }

    @Test("Name geändert mit Katalog-Treffer: Koordinaten kommen aus dem Katalog")
    func adoptsCatalogCoordinatesWhenNameChanged() {
        let result = TempPortFormSheet.resolvedCoordinates(
            existing: (latitude: 12.34, longitude: 56.78),
            nameChanged: true,
            countryChanged: false,
            catalogMatch: Self.katalogTreffer
        )

        #expect(result.latitude == 53.5)
        #expect(result.longitude == 9.9)
    }

    @Test("Neuanlage ohne Original: Katalog-Koordinaten werden übernommen")
    func adoptsCatalogCoordinatesForNewPort() {
        let nameChanged = TempPortFormSheet.fieldChanged(original: nil, current: "Hamburg")
        let countryChanged = TempPortFormSheet.fieldChanged(original: nil, current: "Deutschland")
        #expect(nameChanged)
        #expect(countryChanged)

        let result = TempPortFormSheet.resolvedCoordinates(
            existing: (latitude: nil, longitude: nil),
            nameChanged: nameChanged,
            countryChanged: countryChanged,
            catalogMatch: Self.katalogTreffer
        )

        #expect(result.latitude == 53.5)
        #expect(result.longitude == 9.9)
    }

    @Test("Nur Land geändert: Katalog-Treffer überschreibt die Koordinaten")
    func adoptsCatalogCoordinatesWhenOnlyCountryChanged() {
        let nameChanged = TempPortFormSheet.fieldChanged(original: "Hamburg", current: "Hamburg")
        let countryChanged = TempPortFormSheet.fieldChanged(
            original: "Österreich",
            current: "Deutschland"
        )
        #expect(!nameChanged)
        #expect(countryChanged)

        let result = TempPortFormSheet.resolvedCoordinates(
            existing: (latitude: 12.34, longitude: 56.78),
            nameChanged: nameChanged,
            countryChanged: countryChanged,
            catalogMatch: Self.katalogTreffer
        )

        #expect(result.latitude == 53.5)
        #expect(result.longitude == 9.9)
    }

    @Test("Name nur in Leerzeichen/Schreibweise geändert: keine Katalogsuche, Koordinaten bleiben")
    func ignoresWhitespaceAndCaseOnlyEdits() {
        let nameChanged = TempPortFormSheet.fieldChanged(original: "Kiel", current: " kiel ")
        let countryChanged = TempPortFormSheet.fieldChanged(
            original: "Deutschland",
            current: "DEUTSCHLAND"
        )
        #expect(!nameChanged)
        #expect(!countryChanged)

        let result = TempPortFormSheet.resolvedCoordinates(
            existing: (latitude: 12.34, longitude: 56.78),
            nameChanged: nameChanged,
            countryChanged: countryChanged,
            catalogMatch: Self.katalogTreffer
        )

        #expect(result.latitude == 12.34)
        #expect(result.longitude == 56.78)
    }
}
