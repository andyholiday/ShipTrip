//
//  JournalExcerptTests.swift
//  ShipTripTests
//
//  Tests fuer die „Weiterlesen“-Regel der Eintragszeile (Contract J3neu (c)):
//  laenger als 160 Zeichen oder mehr als 3 Zeilenumbrueche.
//

import Testing
import Foundation
@testable import ShipTrip

@Suite("JournalExcerpt.needsReadMore — Auszug-/Weiterlesen-Regel (J3neu (c))")
struct JournalExcerptTests {

    private func text(ofLength length: Int) -> String {
        String(repeating: "a", count: length)
    }

    @Test("Leerer Text braucht kein Weiterlesen")
    func emptyTextNeedsNoReadMore() {
        #expect(!JournalExcerpt.needsReadMore(""))
    }

    @Test("Genau 160 Zeichen bleiben unter der Schwelle (Regel ist „laenger als“)")
    func exactlyThresholdIsNotEnough() {
        #expect(!JournalExcerpt.needsReadMore(text(ofLength: 160)))
    }

    @Test("161 Zeichen loesen Weiterlesen aus")
    func oneCharacterOverThresholdTriggers() {
        #expect(JournalExcerpt.needsReadMore(text(ofLength: 161)))
    }

    @Test("Genau 3 Umbrueche bleiben unter der Schwelle")
    func threeLineBreaksAreNotEnough() {
        #expect(!JournalExcerpt.needsReadMore("a\nb\nc\nd"))
    }

    @Test("4 Umbrueche loesen Weiterlesen aus, auch bei kurzem Text")
    func fourLineBreaksTrigger() {
        #expect(JournalExcerpt.needsReadMore("a\nb\nc\nd\ne"))
    }

    @Test("Leerzeilen zaehlen als Umbrueche")
    func blankLinesCountAsLineBreaks() {
        #expect(JournalExcerpt.needsReadMore("\n\n\n\n"))
    }

    @Test("CRLF zaehlt als ein Umbruch, nicht als zwei")
    func crlfCountsAsSingleLineBreak() {
        // 3 × CRLF = 3 Umbrueche → unter der Schwelle. Zaehlte man die Skalarwerte,
        // waeren es 6 und der Test schlaege fehl.
        #expect(!JournalExcerpt.needsReadMore("a\r\nb\r\nc\r\nd"))
        #expect(JournalExcerpt.needsReadMore("a\r\nb\r\nc\r\nd\r\ne"))
    }

    @Test("Emoji zaehlen als ein Zeichen (Grapheme-Cluster, nicht Skalarwerte)")
    func emojiCountAsSingleCharacter() {
        // 160 Familien-Emoji sind als Unicode-Skalare ein Vielfaches davon —
        // die Regel misst aber, was der Nutzer als Zeichen sieht.
        let emojiText = String(repeating: "👩‍👩‍👧‍👦", count: 160)
        #expect(!JournalExcerpt.needsReadMore(emojiText))
        #expect(JournalExcerpt.needsReadMore(emojiText + "👩‍👩‍👧‍👦"))
    }

    @Test("Langer Text ohne Umbrueche loest allein ueber die Zeichenzahl aus")
    func longSingleLineTriggersViaCharacterCount() {
        #expect(JournalExcerpt.needsReadMore(text(ofLength: 400)))
    }

    @Test("Die veroeffentlichten Schwellen entsprechen dem Contract")
    func publishedThresholdsMatchContract() {
        #expect(JournalExcerpt.characterThreshold == 160)
        #expect(JournalExcerpt.lineBreakThreshold == 3)
        #expect(JournalExcerpt.lineLimit == 3)
    }
}
