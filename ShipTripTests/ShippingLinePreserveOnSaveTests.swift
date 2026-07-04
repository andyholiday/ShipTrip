//
//  ShippingLinePreserveOnSaveTests.swift
//  ShipTripTests
//

import Testing
import Foundation
@testable import ShipTrip

/// Tests für die Preserve-on-save-Auflösung (ADR-006, Abschnitt 5, Fix B3): reine statische
/// Helper auf `CruiseFormView`/`DealFormView`, ohne View-Instanziierung testbar.
@Suite("Preserve-on-save Resolution")
struct ShippingLinePreserveOnSaveTests {

    // MARK: - CruiseFormView.resolvedShippingLineName

    @Test("unberührt (keine Auswahl, nicht geleert) -> existing bleibt erhalten")
    func cruiseLineUntouchedKeepsExisting() {
        let result = CruiseFormView.resolvedShippingLineName(selected: nil, userCleared: false, existing: "AIDA Cruises")
        #expect(result == "AIDA Cruises")
    }

    @Test("aktiv geleert (userCleared) -> leerer String, unabhängig von existing")
    func cruiseLineUserClearedResetsToEmpty() {
        let result = CruiseFormView.resolvedShippingLineName(selected: nil, userCleared: true, existing: "AIDA Cruises")
        #expect(result == "")
    }

    @Test("neue Auswahl -> Name der ausgewählten Option, existing wird verworfen")
    func cruiseLineNewSelectionWins() {
        let selected = ShippingLineOption(id: "msc", source: .catalog, customID: nil, name: "MSC Cruises", logo: "⚓")
        let result = CruiseFormView.resolvedShippingLineName(selected: selected, userCleared: false, existing: "AIDA Cruises")
        #expect(result == "MSC Cruises")
    }

    @Test(".unlisted-Rundlauf: gelöschte Custom-Reederei bleibt beim bloßen Öffnen+Speichern unverändert erhalten")
    func cruiseLineUnlistedRoundTripPreservesDeletedCustomName() {
        // Reise trägt den Namen einer inzwischen gelöschten Custom-Reederei; sie taucht in
        // customLines nicht mehr auf und wird daher von shippingLineOptions als .unlisted
        // synthetisiert (siehe ShippingLineCatalogServiceTests: currentSelection ohne Match).
        let existingName = "Gelöschte Flussperle Reederei"
        let options = ShippingLineCatalogService.shippingLineOptions(
            customLines: [], hidden: [], currentSelection: existingName
        )
        let unlistedSelection = options.first { $0.source == .unlisted }
        #expect(unlistedSelection?.name == existingName)

        // loadExistingData() selektiert exakt diese Option (Abschnitt 5, Punkt 1); Nutzer öffnet
        // und speichert ohne Änderung -> Name darf nicht verloren gehen.
        let result = CruiseFormView.resolvedShippingLineName(selected: unlistedSelection, userCleared: false, existing: existingName)
        #expect(result == existingName)
    }

    // MARK: - CruiseFormView.resolvedShipName

    @Test("unberührt (keine Auswahl, nicht geleert) -> existing bleibt erhalten")
    func cruiseShipUntouchedKeepsExisting() {
        let result = CruiseFormView.resolvedShipName(selected: nil, userCleared: false, existing: "AIDAstella")
        #expect(result == "AIDAstella")
    }

    @Test("aktiv geleert (userCleared) -> leerer String, unabhängig von existing")
    func cruiseShipUserClearedResetsToEmpty() {
        let result = CruiseFormView.resolvedShipName(selected: nil, userCleared: true, existing: "AIDAstella")
        #expect(result == "")
    }

    @Test("neue Auswahl -> Name der ausgewählten Schiff-Option, existing wird verworfen")
    func cruiseShipNewSelectionWins() {
        let selected = ShipOption(id: "aida|aidanova", source: .catalog, lineOptionID: "aida", customID: nil, name: "AIDAnova", isHistorical: false)
        let result = CruiseFormView.resolvedShipName(selected: selected, userCleared: false, existing: "AIDAstella")
        #expect(result == "AIDAnova")
    }

    @Test(".unlisted-Rundlauf: Schiff einer gelöschten Custom-Reederei bleibt beim bloßen Öffnen+Speichern erhalten")
    func cruiseShipUnlistedRoundTripPreservesDeletedCustomName() {
        let existingShipName = "Flussperle I (gelöscht)"
        let options = ShippingLineCatalogService.shipOptions(
            for: "custom:\(UUID().uuidString)", customShips: [], hidden: [], currentSelection: existingShipName
        )
        let unlistedSelection = options.first { $0.source == .unlisted }
        #expect(unlistedSelection?.name == existingShipName)

        let result = CruiseFormView.resolvedShipName(selected: unlistedSelection, userCleared: false, existing: existingShipName)
        #expect(result == existingShipName)
    }

    // MARK: - DealFormView.resolvedShippingLineName

    @Test("unberührt (keine Auswahl, nicht geleert) -> existing bleibt erhalten")
    func dealLineUntouchedKeepsExisting() {
        let result = DealFormView.resolvedShippingLineName(selected: nil, userCleared: false, existing: "AIDA Cruises")
        #expect(result == "AIDA Cruises")
    }

    @Test("unberührt mit existing == nil bleibt nil (neuer Deal ohne bisherige Auswahl)")
    func dealLineUntouchedNilStaysNil() {
        let result = DealFormView.resolvedShippingLineName(selected: nil, userCleared: false, existing: nil)
        #expect(result == nil)
    }

    @Test("aktiv geleert (userCleared) -> nil, unabhängig von existing")
    func dealLineUserClearedResetsToNil() {
        let result = DealFormView.resolvedShippingLineName(selected: nil, userCleared: true, existing: "AIDA Cruises")
        #expect(result == nil)
    }

    @Test("neue Auswahl -> Name der ausgewählten Option, existing wird verworfen")
    func dealLineNewSelectionWins() {
        let selected = ShippingLineOption(id: "msc", source: .catalog, customID: nil, name: "MSC Cruises", logo: "⚓")
        let result = DealFormView.resolvedShippingLineName(selected: selected, userCleared: false, existing: "AIDA Cruises")
        #expect(result == "MSC Cruises")
    }

    @Test(".unlisted-Rundlauf: gelöschte Custom-Reederei bleibt beim bloßen Öffnen+Speichern eines Deals unverändert erhalten")
    func dealLineUnlistedRoundTripPreservesDeletedCustomName() {
        let existingName = "Gelöschte Flussperle Reederei"
        let options = ShippingLineCatalogService.shippingLineOptions(
            customLines: [], hidden: [], currentSelection: existingName
        )
        let unlistedSelection = options.first { $0.source == .unlisted }
        #expect(unlistedSelection?.name == existingName)

        let result = DealFormView.resolvedShippingLineName(selected: unlistedSelection, userCleared: false, existing: existingName)
        #expect(result == existingName)
    }
}
