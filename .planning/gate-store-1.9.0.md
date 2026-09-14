# Gate — Store-Material 1.9.0 (Screenshots + Metadaten)

- **Datum:** 2026-09-14 · **Prüfer:** quality (frischer Spawn, read-only)
- **Verdikt: go-mit-backlog** — 0 Blocker. Alle 10 Bilder 1320×2868 ohne Alpha, 0 abgeschnittene
  Texte, 0 Limit-Verstöße, Widgets in 02 DE/EN eindeutig Motiv. Zwei Backlog-Punkte (p1: EN-Review-Notes
  nennen falsche Widget-Strings; p1: Reederei-Marken in DE-Keywords als Restrisiko 2.3.7).
- **Geladene Skills:** app-store-submit (+ store-guidelines/common-rejections.md), design-library (SKILL.md)
- **Stats:** critical 0 · major 2 · minor 3 — Blocker 0 · Backlog 5

## Bilder (jedes PNG per Read angesehen)

| # | Datei | Urteil |
|---|-------|--------|
| 1 | de-DE/01-deine-kreuzfahrt.png | ok — 1.7.0-Bild, Headline/Sub/Badge lesbar, Footer „VERSION 1.7" (s. F03) |
| 2 | de-DE/02-widgets.png | ok — Medium (Aktuell in Kopenhagen, Liegezeit-Balken), Small (Noch 1 Woche, AIDAnova) und Lock-Screen-Rectangular klar als Widgets erkennbar; Panels „HOME-BILDSCHIRM"/„SPERRBILDSCHIRM" + App-Icon verorten sie; Headline „Deine Reise / auf einen Blick." + Subhead + Badge „NEU · WIDGETS" lesbar; Brand-Header, Karten-Hintergrund, Weiß/Orange-Typo und Footer „VERSION 1.9" identisch zu 01/04; kein Statusbar-Fake, kein Gerät, keine Fremdlogos |
| 3 | de-DE/03-hafen-momente.png | ok — 1.7.0-Bild, unverändert |
| 4 | de-DE/04-icloud-sync.png | ok — 1.7.0-Bild, unverändert |
| 5 | de-DE/05-reiselogbuch.png | ok — 1.7.0-Bild, unverändert |
| 6 | en-US/01-your-cruise.png | ok — 1.7.0-Bild, unverändert |
| 7 | en-US/02-widgets.png | ok — gleiche Komposition wie DE; Widget-Texte englisch („Currently in", „5 hr, 58 min left in port", „In 1 week", „Next stop: Sea Day", 12h-Zeiten); Fixture-Eigennamen „Mein Schiff 4", „Mittelmeer-Traumreise…", „Ostsee-Rundreise" deutsch (erlaubt lt. Spec, s. F05); Headline „Your voyage / at a glance.", Badge „NEW · WIDGETS" lesbar |
| 8 | en-US/03-port-moments.png | ok — 1.7.0-Bild, unverändert |
| 9 | en-US/04-icloud-sync.png | ok — 1.7.0-Bild, unverändert |
| 10 | en-US/05-travel-logbook.png | ok — 1.7.0-Bild, unverändert |

Design-Urteil zu 02 (design-library, Gestalt/Hierarchie): drei sichtbare Typ-Ebenen (Headline, Subhead,
Panel-Label) — innerhalb der „max. drei Ebenen"-Schwelle; Gruppierung Home vs. Lock Screen durch zwei
Glas-Panels (Gestalt: Common Region) eindeutig; Akzentfarbe Orange nur auf Headline-Zeile 2 und Badge-Punkt
(60-30-10 eingehalten). Widget-Renderings decken sich mit `konzept-03-dynamic-instrument.png` (Ring, Cyan-Akzent,
Liegezeit-Balken) — kein Abweichen vom gelieferten Design.

## Technik

| Datei | Maße | Alpha | SHA-256 = Manifest | byte-identisch 1.7.0 |
|-------|------|-------|--------------------|----------------------|
| de-DE/01 | 1320×2868 | no | ja | ja (= 1.7.0 de/01) |
| de-DE/02 | 1320×2868 | no | ja | neu |
| de-DE/03 | 1320×2868 | no | ja | ja (= 1.7.0 de/02) |
| de-DE/04 | 1320×2868 | no | ja | ja (= 1.7.0 de/03) |
| de-DE/05 | 1320×2868 | no | ja | ja (= 1.7.0 de/04) |
| en-US/01 | 1320×2868 | no | ja | ja (= 1.7.0 en/01) |
| en-US/02 | 1320×2868 | no | ja | neu |
| en-US/03 | 1320×2868 | no | ja | ja (= 1.7.0 en/02) |
| en-US/04 | 1320×2868 | no | ja | ja (= 1.7.0 en/03) |
| en-US/05 | 1320×2868 | no | ja | ja (= 1.7.0 en/04) |

Alle 10 SHA-256 in `asset-manifest.md` stimmen mit den Dateien überein.

## Texte (Zeichen ohne abschließenden Zeilenumbruch)

| Feld | Limit | de-DE | en-US | Widgets | Befund |
|------|------:|------:|------:|---------|--------|
| name | 30 | 28 | 24 | – | ok |
| subtitle | 30 | 28 | 28 | – | ok (ASC-Stand) |
| keywords | 100 | 98 | 98 | – | ok; keine Dopplung mit Name/Untertitel; DE enthält `aida,msc,costa` (F02) |
| promotional_text | 170 | 145 | 136 | ja, erster Satz | ok |
| description | 4000 | 2657 | 2405 | eigener Absatz WIDGETS | ok |
| release_notes | 4000 | 1202 | 1100 | erster Punkt | ok |
| review_notes | – | 1658 | 1494 | Schritt 2 | Weg zu Widget + .shiptrip-Import nachvollziehbar; EN-Strings falsch (F01) |

DE/EN inhaltlich deckungsgleich (Absätze, Bullet-Reihenfolge, Release-Notes-Punkte 1:1). Keine Superlative
außer „wunderschön/beautiful" (unkritisch), keine Preise, keine Fremdplattformen, keine Platzhalter, kein
„Beta". Support-/Privacy-/Marketing-URLs gesetzt.

## Findings + Go-Live-Triage

| ID | Severity | Blocker | Datei | Titel |
|----|----------|---------|-------|-------|
| F01 | major | nein | review/review_notes_en.txt:5 | EN-Review-Notes nennen Widget „Trip Status" und Leertext „No upcoming cruise" — App zeigt „Cruise Status" / „No cruise planned" (`ShipTripWidget/Localizable.xcstrings`) |
| F02 | major | nein | metadata/de-DE/keywords.txt | Reederei-Marken `aida,msc,costa` als Keywords — Restrisiko Guideline 2.3.7 (Trademark-Terms); ASO-Entscheidung 1.8.0, nie von Apple geprüft |
| F03 | minor | nein | screenshots/*/01,03,04,05 | Footer „VERSION 1.7" neben „VERSION 1.9" in Bild 02 — Konsequenz der Byte-identisch-Entscheidung |
| F04 | minor | nein | screenshots/*/02-widgets.png | Panel-Label „SPERRBILDSCHIRM/LOCK SCREEN" zentriert, „HOME-BILDSCHIRM/HOME SCREEN" linksbündig — Ausrichtung uneinheitlich (Gestalt: Alignment) |
| F05 | minor | nein | screenshots/en-US/02-widgets.png | Fixture-Namen deutsch (Mittelmeer-Traumreise…, Ostsee-Rundreise) im EN-Bild — lt. Spec erlaubt, für US-Betrachter aber Fremdsprache im Motiv |

**F01 — Triage:** blockiert nicht (Prüfer findet das einzige ShipTrip-Widget ohnehin), aber 2-Wörter-Fix
im Textfile vor dem Einreichen: „Trip Status" → „Cruise Status", „No upcoming cruise" → „No cruise planned".
DE-Notes stimmen („Reisestatus", „Keine neue Reise geplant").
**F02 — Triage:** blockiert nicht — Begriffe sind für ein Kreuzfahrt-Logbuch relevant (2.3.7 verbietet
irrelevante/fremde App-Namen, nicht relevante Marken), Keywords sind unsichtbar, und eine Beanstandung wäre
Metadata-only ohne neuen Build. Entscheidung Andre/Winston: behalten oder auf generische Begriffe
(„liegezeit,countdown,widget") tauschen.

## Backlog-Zeilen (für `.planning/BACKLOG.md`)

- [major][p1] marketing/release-1.9.0/app-store-connect/review/review_notes_en.txt:5 — Widget-Strings auf „Cruise Status" / „No cruise planned" korrigieren
- [major][p1] marketing/release-1.9.0/app-store-connect/metadata/de-DE/keywords.txt — Reederei-Marken aida/msc/costa: Restrisiko 2.3.7 bewusst entscheiden
- [minor][p2] marketing/release-1.9.0/app-store-connect/screenshots/*/0{1,3,4,5}-*.png — Footer „VERSION 1.7" beim nächsten Screenshot-Refresh angleichen
- [minor][p3] marketing/release-1.9.0/app-store-connect/screenshots/*/02-widgets.png — Lock-Screen-Panel-Label linksbündig wie Home-Panel
- [minor][p3] marketing/release-1.9.0/app-store-connect/screenshots/en-US/02-widgets.png — EN-Fixture mit englischen Reisenamen rendern
