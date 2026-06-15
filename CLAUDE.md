# CLAUDE.md

Behavioral guidelines to reduce common LLM coding mistakes. Merge with project-specific instructions as needed.

**Tradeoff:** These guidelines bias toward caution over speed. For trivial tasks, use judgment.

## 1. Think Before Coding

**Don't assume. Don't hide confusion. Surface tradeoffs.**

Before implementing:
- State your assumptions explicitly. If uncertain, ask.
- If multiple interpretations exist, present them - don't pick silently.
- If a simpler approach exists, say so. Push back when warranted.
- If something is unclear, stop. Name what's confusing. Ask.

## 2. Simplicity First

**Minimum code that solves the problem. Nothing speculative.**

- No features beyond what was asked.
- No abstractions for single-use code.
- No "flexibility" or "configurability" that wasn't requested.
- No error handling for impossible scenarios.
- If you write 200 lines and it could be 50, rewrite it.

Ask yourself: "Would a senior engineer say this is overcomplicated?" If yes, simplify.

## 3. Surgical Changes

**Touch only what you must. Clean up only your own mess.**

When editing existing code:
- Don't "improve" adjacent code, comments, or formatting.
- Don't refactor things that aren't broken.
- Match existing style, even if you'd do it differently.
- If you notice unrelated dead code, mention it - don't delete it.

When your changes create orphans:
- Remove imports/variables/functions that YOUR changes made unused.
- Don't remove pre-existing dead code unless asked.

The test: Every changed line should trace directly to the user's request.

## 4. Goal-Driven Execution

**Define success criteria. Loop until verified.**

Transform tasks into verifiable goals:
- "Add validation" → "Write tests for invalid inputs, then make them pass"
- "Fix the bug" → "Write a test that reproduces it, then make it pass"
- "Refactor X" → "Ensure tests pass before and after"

For multi-step tasks, state a brief plan:
```
1. [Step] → verify: [check]
2. [Step] → verify: [check]
3. [Step] → verify: [check]
```

Strong success criteria let you loop independently. Weak criteria ("make it work") require constant clarification.

---

**These guidelines are working if:** fewer unnecessary changes in diffs, fewer rewrites due to overcomplication, and clarifying questions come before implementation rather than after mistakes.

---

# Projekt: ShipTrip

Kreuzfahrt-Tagebuch-App (iOS). Produktrichtung „Travel Journal" (Premium-Reisetagebuch
mit Freemium-Abo), erreicht über schrittweise visuelle Politur. Roadmap und Phasenplan
liegen im Projektgedächtnis (`memory/shiptrip-roadmap.md`); der Voll-Audit unter
`audit/audit-2026-06-13.html`.

## Stack & Plattform

- **Sprache/UI:** Swift 6, SwiftUI
- **Persistenz:** SwiftData (`@Model`), Bilder via `@Attribute(.externalStorage)`
- **Ziel:** iOS 18.5+, Bundle `com.andre.ShipTrip`
- **Tests:** Swift Testing (`@Test`) für Unit-Tests, XCTest für UI-Tests
- **Karten/Charts:** MapKit, Swift Charts (nativ, kein Fremd-Code)

## Projektstruktur

- `ShipTrip/Models/` — SwiftData-Modelle (Cruise, Port, Expense, Deal, Photo) +
  Referenzdaten (PortSuggestion ~1.800 Häfen, ShippingLine)
- `ShipTrip/Services/` — ExportImportService, GeminiService (KI-Erfassung),
  KeychainService, NotificationService, DemoDataService (nur `#if DEBUG`)
- `ShipTrip/Views/` — nach Feature gegliedert (Cruises, Deals, Map, Stats, Settings)
- `ShipTrip/Utilities/` — Color+Theme, Date+Extensions
- `ShipTripTests/` — Unit-Tests · `ShipTripUITests/` — UI-Tests
- `docs/` — Architektur, Features, ADRs (`docs/adr/`) · `CHANGELOG.md` (Keep a Changelog)

## Konventionen

- **Sprache:** UI war ursprünglich rein Deutsch; ab Phase 1 zweisprachig (DE/EN) über
  String Catalog. Neue user-sichtbare Strings als `String(localized:)`.
- **Währung:** an die Geräte-Locale gebunden (kein hartkodiertes EUR mehr).
- **Demo-Daten:** mit `isDemo`-Tag, sauber entfernbar; Demo-Schalter nur in Debug-Builds.
- **Codestil:** bestehenden Stil spiegeln (deutsche Doc-Kommentare, `// MARK:`-Gliederung).

## Build & Test

- Build/Test bevorzugt über die Xcode-MCP-Tools (`BuildProject`, `RunAllTests`) oder
  `xcodebuild -scheme ShipTrip`. Test-Builds laufen strikt seriell.

## CloudKit-Hinweis

SwiftData+CloudKit erfordert: alle nicht-optionalen Attribute mit Default-Wert, optionale
Relationships, **keine** `@Attribute(.unique)`-Constraints. Dedup daher app-seitig über
stabile `id: UUID`. Siehe `docs/adr/ADR-002-*`.
