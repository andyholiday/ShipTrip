//
//  PortCountryCatalogTests.swift
//  ShipTripTests
//

import Foundation
import Testing
@testable import ShipTrip

@Suite("Ländercodes der Hafen-Referenzdaten")
struct PortCountryCatalogTests {

    /// Bewusst nicht gemappte Bestandsnamen – siehe ADR-008.
    private static let documentedFallbacks: Set<String> = [
        "Antikes Athen", "Byzantinisches Reich", "Britisch-Hongkong", "China", "Bonaire"
    ]

    @Test("Bestandsnamen liefern den erwarteten ISO-3166-Alpha-2-Code")
    func mapsLegacyNamesToRegionCodes() {
        #expect(PortCountryCatalog.regionCode(for: "Spanien") == "ES")
        #expect(PortCountryCatalog.regionCode(for: "Deutschland") == "DE")
        // Aliasse, die nicht dem ICU-Namen entsprechen:
        #expect(PortCountryCatalog.regionCode(for: "USA") == "US")
        #expect(PortCountryCatalog.regionCode(for: "Großbritannien") == "GB")
        #expect(PortCountryCatalog.regionCode(for: "VAE") == "AE")
        // Umgebender Whitespace darf den Treffer nicht verhindern:
        #expect(PortCountryCatalog.regionCode(for: "  Italien  ") == "IT")
    }

    @Test("Nicht zuordenbare Namen liefern keinen Code")
    func returnsNilForUnmappedNames() {
        #expect(PortCountryCatalog.regionCode(for: "Antikes Athen") == nil)
        #expect(PortCountryCatalog.regionCode(for: "China") == nil)
        #expect(PortCountryCatalog.regionCode(for: "Phantasieland") == nil)
        #expect(PortCountryCatalog.regionCode(for: "") == nil)
        #expect(PortCountryCatalog.regionCode(for: "   ") == nil)
    }

    @Test("Anzeigename fällt ohne Code auf den Bestandsnamen zurück")
    func fallsBackToLegacyName() {
        #expect(PortCountryCatalog.localizedName(for: "Antikes Athen") == "Antikes Athen")
        #expect(PortCountryCatalog.localizedName(for: "China") == "China")
        #expect(PortCountryCatalog.localizedName(for: "Phantasieland") == "Phantasieland")
        #expect(PortCountryCatalog.localizedName(for: "") == "")
    }

    @Test("Anzeigename kommt bei vorhandenem Code aus der Geräte-Locale")
    func usesLocaleForMappedNames() {
        let expected = Locale.current.localizedString(forRegionCode: "ES")
        #expect(expected != nil)
        #expect(PortCountryCatalog.localizedName(for: "Spanien") == expected)
    }

    @Test("Alle hinterlegten Codes sind gültige ISO-3166-Regionen")
    func tableContainsOnlyValidRegionCodes() {
        let known = Set(Locale.Region.isoRegions.map(\.identifier))
        for (name, code) in PortCountryCatalog.regionCodesByLegacyName {
            #expect(code.count == 2, "Kein Alpha-2-Code für \(name): \(code)")
            #expect(known.contains(code), "Unbekannte Region für \(name): \(code)")
        }
    }

    @Test("Jeder Hafen der Referenzdaten hat einen Code oder einen dokumentierten Fallback")
    func everyPortCountryIsCoveredOrDocumented() {
        let uncovered = Set(
            PortSuggestion.popular
                .map(\.country)
                .filter { PortCountryCatalog.regionCode(for: $0) == nil }
        ).subtracting(Self.documentedFallbacks)

        #expect(uncovered.isEmpty, "Ohne Ländercode und ohne ADR-Eintrag: \(uncovered.sorted())")
    }

    @Test("PortSuggestion reicht Code und Anzeigename durch")
    func suggestionExposesRegionCodeAndLocalizedCountry() throws {
        let barcelona = try #require(PortSuggestion.findBestMatch(name: "Barcelona"))
        #expect(barcelona.country == "Spanien")
        #expect(barcelona.regionCode == "ES")
        #expect(barcelona.localizedCountry == PortCountryCatalog.localizedName(for: "Spanien"))
    }
}
