# Nachtjob-Protokoll: Karten-Redesign v2 „Journal Atlas" + TestFlight 1.7.0 (16)

> Autonomer Lauf 2026-07-10 ~02:00–~03:30, Winston-Orchestrierung, Modus:
> Claude solo (keine Codex-/Gemini-Gates, von Andre vorab entschieden).
> Brief: `.planning/karten-redesign-nachtjob-brief.md`

## Ergebnis in einem Satz

Der Karten-Bereich wurde komplett auf die Design-Richtung „Journal Atlas"
umgebaut (kurvige Routen, Burger-Menü oben rechts, Hochswipe-Sheet mit
Stop-Liste), 232/232 Tests grün, Version 1.7.0 (16) zu TestFlight hochgeladen —
TestFlight-Endstand siehe unten.

## Design: 3 Richtungen, Wahl begründet

Deck (bitte im Browser ansehen): `docs/ux-pitch-decks/karten-redesign-v2-richtungen.html`

1. **Liquid Glass Atlas** — Frosted-Glass-Chrome, dünne Glow-Route. Nah am
   Ist-Zustand, geringste Differenzierung.
2. **Journal Atlas** ← **GEWÄHLT** — flache solide Navy-Chrome-Buttons, dicke
   „Ribbon"-Route mit Farbschatten, warmes Sheet mit gepunkteter Foto-Timeline.
3. **Captain's Chart** — Seekarten-Optik mit Gradnetz und Manifest-Sheet.
   Markenstärkste, aber riskanteste Richtung.

**Warum Richtung 2:** Am nächsten an Andres Referenz (Road-Trip-Planer, flat UI
mit soliden runden Buttons und Timeline-Stop-Liste); fast vollständig mit
nativen Bordmitteln umsetzbar; zahlt direkt auf die beschlossene Produktrichtung
„Travel Journal Premium" ein statt eine vierte visuelle Sprache einzuführen;
das Timeline+Foto-Sheet-Pattern ist über die Benchmark-Apps (Polarsteps,
Roadtrippers) verifiziert. Die Referenz-URL selbst war nicht abrufbar
(HTTP 403 Bot-Schutz) — gearbeitet wurde mit der Beschreibung aus dem Brief +
dem bestehenden B4-Benchmark + Web-Recherche; im Deck transparent vermerkt.

## Was gebaut wurde (Commit 2234878, Release-Commit 17aaeae)

- **Kurvige Routen:** Catmull-Rom-Spline durch alle Hafen-Koordinaten
  (`MapRouteCurveSampler.swift`, 280-Punkte-Budget, degenerierte Fälle
  getestet) + farbiges Schatten-Underlay.
- **Burger-Menü oben rechts** (ersetzt Funnel-Menü links + alte Bottom-Card):
  „Alle ausblenden"/„Alle Reisen anzeigen" mit einem Tipp, Einzel-Routen-Toggles,
  Menü bleibt bei Mehrfach-Auswahl offen. Neues State-Modell
  (`MapRouteVisibilityPlanner.swift`, `allRoutesHidden`), Schutz: letzte Route
  nicht per Einzel-Tap abwählbar. Leerzustand-Hinweis bei „alles ausgeblendet".
- **Hochswipe-Sheet** (`RouteStopSheetView.swift`): Peek (Titel+Substats) /
  Medium (Stop-Liste mit gepunkteter Timeline, Foto-Thumbnails, ≥56pt-Rows) /
  Large (+„Öffnen"-CTA → Reise-Detail). Karte bleibt bis Medium bedienbar.
  Stop-Tap → Kamera springt hin, Sheet kollabiert auf Peek.
- **Sheet-Trigger:** Linien-Tap (MapReader-Hit-Testing, 20pt-Toleranz) UND
  Pin/Badge-Tap — beide gelandet.
- **Chrome:** Recenter links, Burger rechts, 42pt-Navy-Solid-Kreise (44pt
  Hit-Area), neue Tokens `journalSurface`/`journalTimeline`, Pin-Halo adaptiv
  statt hartem Weiß. 4 neue Strings DE+EN im String Catalog.
- **Struktur:** `MapView.swift` von 543 auf 407 Zeilen; Interaktion und die 3
  Planner in eigene Dateien extrahiert (verhaltensneutral, quality-verifiziert).

## Qualität

- **Tests:** 232 passed / 0 failed (Unit + UI, Wegwerf-Sim iPhone 17 / iOS 26.5),
  davon 18 neue Tests (Kurven-Sampler, Sichtbarkeits-Planner).
- **Quality-Review:** 2 Iterationen, finales **GO**. 8 Findings (0 Blocker,
  3 Major, 5 Minor) → 6 gefixt, 2 dokumentiert-akzeptiert (vorbestehende
  Test-Flakiness; Antimeridian-Routen ohne Spezialbehandlung).
  Artefakt: `.planning/quality-review-karten-v2.md`
- **Screenshots** (selbst geprüft): `audit/screenshots/weltkarte-v2-*.png`
  (Welt-Zoom + Sheet-Peek, je hell/dunkel) + regenerierte `weltkarte-all-*.png`.
- **Live verifiziert im Simulator:** Welt-Zoom hell/dunkel, Pin-Tap → Sheet-Peek.

## Restrisiko (für Andres Morgen-Review)

- **Burger-Menü-Tap, Sheet-Drag-Gesten und Linien-Tap konnten nur code- und
  unit-verifiziert werden** — das Simulator-Tooling kann SwiftUI-Menüs und
  Drag-Gesten nicht synthetisch bedienen. Deshalb steht im
  „Was ist zu testen"-Text explizit die Bitte, genau diese Gesten zu prüfen.
  Kurzer manueller QA-Pass auf echtem Gerät empfohlen, bevor breiter verteilt wird.
- `.presentationBackground(.regularMaterial)` statt vollem „Papier"-Solid ist
  der spec-konforme v1-Kompromiss — Politur-Kandidat für eine Folgewelle.
- Antimeridian-Querungen (Transpazifik) zeichnen die Kurve „außen herum"
  (vorbestehende Einschränkung, jetzt dokumentiert).

## Doku

- Feature: `docs/features/karten-redesign-v2-journal-atlas.md`
- B4-Status aktualisiert (B4.3b-2 + B4.3b-3 geliefert): `docs/features/karten-redesign-b4.md`
- `CHANGELOG.md`: Sektion `[1.7.0] – 2026-07-10`

## Release / TestFlight

- Commits `2234878` (Feature) + `17aaeae` (Release) + `ed58c27` (kleine
  read-only `fastlane validate`-Lane als Preflight-Check) auf `main`, gepusht.
- Archiv `build/ShipTrip-16.xcarchive`, Export manuell signiert, Upload via
  `fastlane upload_testflight` (76s), Processing < 5 min bis `VALID`.
- **whatsToTest (de-DE) gesetzt** — bittet die Tester explizit, Burger-Menü und
  Sheet-Wischgesten gründlich zu prüfen (die automatisiert ungetesteten Pfade).
- **Intern („VIP Tester"):** Build 16 zugeordnet — für Andre sofort verfügbar.
- **Extern („VIP Extern"/Stefanie):** Build 16 zugeordnet + Beta-Review
  eingereicht, Zustand per GET verifiziert: **WAITING_FOR_REVIEW**. Stefanie
  bekommt das Build, sobald Apple freigibt (meist Stunden, kann länger dauern).
- Sicherheit: Key nur per Pfad, kein `.inspect`, kein `fastlane run` auf
  ASC-Actions; 11 eigene Spaceship-Logs geprüft (kein Key-Inhalt) und gelöscht.
- Rollback bei Bedarf: `git revert ed58c27 17aaeae 2234878` + Build 16 in ASC
  aus „VIP Extern" nehmen; Build 15 (1.6.3) bleibt in TestFlight verfügbar.

## Nicht angefasst (bewusst)

Vorbestehende Working-Tree-Änderungen außerhalb dieser Welle blieben
uncommitted: `audit/screenshots/meine-reisen-*`, `detail-pins-*`, `geo-hero-*`,
`docs/umsetzungsplan-audit-2026-07.md`, `SESSION-HANDOFF.md`, `.planning/`.
