//
//  JournalMoodTests.swift
//  ShipTripTests
//
//  Tests fuer die Anzeige-Abbildung der Stimmungs-Rohwerte
//  (ADR-003 moodRaw-Stabilitaetsvertrag, Contract J4).
//

import Testing
import Foundation
@testable import ShipTrip

@Suite("JournalMood — Rohwerte und Fallback (J4)")
struct JournalMoodTests {

    @Test("Die Rohwerte entsprechen exakt der Skala J4")
    func rawValuesMatchContract() {
        let rawValues = Set(JournalMood.allCases.map(\.rawValue))

        #expect(rawValues == ["great", "good", "okay", "bad", "awful"])
    }

    @Test("Jede Stimmung hat ein Emoji")
    func everyMoodHasAnEmoji() {
        let emptyEmojis = JournalMood.allCases.filter { $0.emoji.isEmpty }

        #expect(emptyEmojis.isEmpty)
    }

    @Test("Bekannter Rohwert wird aufgeloest")
    func knownRawResolves() {
        #expect(JournalMood.known(forRaw: "great") == .great)
        #expect(JournalMood.known(forRaw: "awful") == .awful)
    }

    @Test("Leerer Rohwert bedeutet keine Stimmung")
    func emptyRawIsNoMood() {
        #expect(JournalMood.known(forRaw: "") == nil)
    }

    @Test("Unbekannter Rohwert faellt auf keine Stimmung zurueck (Unknown-Preservation)")
    func unknownRawFallsBack() {
        // Ein Wert aus einer neueren App-Version oder einem Fremd-Import: die UI
        // zeigt den Fallback, der gespeicherte Rohwert bleibt davon unberuehrt.
        #expect(JournalMood.known(forRaw: "ecstatic") == nil)
    }
}
