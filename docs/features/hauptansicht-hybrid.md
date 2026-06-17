# Hauptansicht Hybrid — „Meine Reisen" Redesign

**Branch:** feature/hauptansicht-hybrid  
**Status:** Abgeschlossen  
**Testsuite:** Build PASS, 52 Unit-Tests PASS, Photo-Hero + Geo-Fallback via Screenshot verifiziert, DE/EN lokalisiert, Light + Dark Mode verifiziert  
**Datum:** 2026-06-17

## Beschreibung

Die Hauptansicht „Meine Reisen" ersetzt die bisherige flache Liste gleichfoermiger
Full-Bleed-Karten durch ein dreischichtiges Layout: ein schlanker Statistik-Strip
(lifetime-Totals: Reisen, Laender, Seetage, Haefen), eine redaktionelle Hero-Card
fuer die Fokus-Reise (laufend > naechste bevorstehende > zuletzt vergangene) mit
Cover-Foto oder Geo-SVG-Fallback, und kompakte Timeline-Zeilen gruppiert nach
Jahrestrennern. Das Redesign aendert kein SwiftData-Modell; alle Aggregatwerte werden
in einer Array-Extension auf `Cruise` berechnet.

---

## Aenderung 1 — Statistik-Strip (`CruiseStatsStripView`)

### Was / Warum

Ein horizontaler Strip oberhalb der Liste zeigt vier lifetime-Kennzahlen der gesamten
Reisehistorie: Gesamtanzahl Reisen, besuchte Laender (dedupliziert), Seetage (Ports
mit `isSeaDay == true`) und Hafen-Stopps. Die Werte werden on-the-fly aus der SwiftData-
Abfrage der `CruiseListView` berechnet — keine separaten Abfragen, kein gecachtes State.

### Beruerhrte Dateien

- `ShipTrip/Views/Cruises/CruiseStatsStripView.swift` (neu)
- `ShipTrip/Models/Cruise.swift` (neue Extension: `uniqueCountryCount`, `totalSeaDays`,
  `totalPortStops` auf `Array where Element == Cruise`)

### Acceptance-Status

Durch `ShipTripTests/CruiseAggregateTests.swift` abgedeckt (Fixtures fuer alle drei
Extension-Properties, je mind. ein Randfall). Build PASS.

---

## Aenderung 2 — Hero-Card mit Photo-Branch und Geo-SVG-Fallback

### Was / Warum

Eine hervorgehobene Karte fuer die Fokus-Reise zeigt das Cover-Foto (`sortedPhotos.first`
→ `UIImage(data:)`) als Hintergrundbild mit Scrim-Overlay, Reisename, Reederei/Schiff,
Datum-Range und einem Countdown-Badge („In X Tagen") fuer bevorstehende Reisen.
Fehlt ein Cover-Foto, rendert `CruiseGeoFallbackView` eine SVG-artige Routenlinie aus
den gespeicherten Port-Koordinaten auf einem Ozeanblau-Verlauf — kein Placeholder-Icon,
sondern eine inhaltsreiche Alternative.

Die Fokus-Reise-Auswahl (`heroCruise`) priorisiert: laufende Reise (`isOngoing`) >
naechste bevorstehende (fruehestes `startDate > today`) > zuletzt vergangene
(groesstes `endDate <= today`). Logik liegt in `CruiseListView`.

### Beruerhrte Dateien

- `ShipTrip/Views/Cruises/CruiseHeroCardView.swift` (neu)
- `ShipTrip/Views/Cruises/CruiseGeoFallbackView.swift` (neu)
- `ShipTrip/Views/Cruises/CruiseListView.swift` (heroCruise-Berechnung, Integration)

### Acceptance-Status

Photo-Hero und Geo-Fallback-Branch durch Screenshots in
`ShipTripUITests/HauptansichtScreenshotTests.swift` verifiziert. Hero-Auswahl-Prioritaet
(ongoing > upcoming > past) durch `ShipTripTests/CruiseAggregateTests.swift`
(`HeroSelectionTests`-Suite) abgedeckt.

---

## Aenderung 3 — Kompakte Timeline mit Jahrestrennern

### Was / Warum

Unterhalb der Hero-Card listet `CruiseListView` die restlichen Reisen als kompakte
Timeline-Zeilen (`CruiseTimelineRowView`), gruppiert nach Reisejahr. Jahresdivider
(`CruiseYearDivider`) werden inline als nicht-interaktive Section-Header gerendert.
Jede Zeile zeigt: Reederei-Logo (falls vorhanden), Reisename, Datum-Range und Dauer
im Format „XdT" (DE) / „Xdd" (EN). Swipe-to-Delete ist pro Zeile verfuegbar.

Ein separater Leer-Zustand erscheint, wenn `filteredCruises.isEmpty` aber `cruises`
nicht leer ist (Suche/Filter ohne Treffer): `ContentUnavailableView.search` mit
lokalisiertem Text „Keine Treffer" / „No results".

### Beruerhrte Dateien

- `ShipTrip/Views/Cruises/CruiseTimelineRowView.swift` (neu, enthaelt `CruiseYearDivider`)
- `ShipTrip/Views/Cruises/CruiseListView.swift` (year-grouped List, filtered-empty state,
  per-cruise swipe delete)

### Acceptance-Status

Screenshot-Tests (`HauptansichtScreenshotTests`) pruefen das Timeline-Layout in
Light und Dark Mode. Build PASS.

---

## Aenderung 4 — Lokalisierung neuer Strings

### Was / Warum

Vier neue String-Catalog-Schuessel wurden hinzugefuegt, alle mit DE- und EN-Uebersetzung:

- `"In %lld Tagen"` / `"In %lld days"` — Countdown-Badge in der Hero-Card
- `"%lldT"` / `"%lldd"` — Dauer-Suffix in der Timeline-Zeile
- `"Details →"` / `"Details →"` — CTA-Link in der Hero-Card
- `"Keine Treffer"` / `"No results"` — Filter-Leer-Zustand

Der Countdown verwendet einen einzigen interpolierten Schuessel (kein String-Fragment-
Concatenation), damit die EN-Uebersetzung korrekt greift.

### Beruerhrte Dateien

- `ShipTrip/Localizable.xcstrings`

### Acceptance-Status

Lokalisierung manuell verifiziert (DE/EN). Countdown-Badge EN-Branch durch
Screenshot-Test in beiden Sprachen gedeckt.

---

## Aenderung 5 — Demo-Daten fuer Cover-Foto-Seeding (DEBUG)

### Was / Warum

`DemoDataService` seedet beim Debug-Lauf ein Gradient-Cover-Foto fuer die
Norwegen-Beispielreise, sodass der Photo-Branch der Hero-Card im Simulator/
Screenshot-Test sichtbar ist. Das Seeding ist idempotent — ein Reset-before-seed-
Muster in `HauptansichtScreenshotTests` stellt sicher, dass ein alter Datensatz
ohne Foto nicht den Guard verhindert.

### Beruerhrte Dateien

- `ShipTrip/Services/DemoDataService.swift` (Cover-Foto-Seed, nur `#if DEBUG`)
- `ShipTripTests/DemoDataServiceTests.swift` (neu — Seeding-Verhalten)

### Acceptance-Status

Unit-Tests in `DemoDataServiceTests` sichern Idempotenz und Reset-Verhalten ab.

---

## Bekannte Einschraenkungen / Offene Punkte

**(a) Seetage-Definition weicht von StatsView ab**  
Der Strip zaehlt Ports mit `isSeaDay == true` (port-basiert, dieses Feature).
`StatsView` summiert die Gesamtdauer der Reisen als „Reisetage" / „Seetage" — eine
andere Definition. Es ist offen, welche Zahl als kanonisch gilt. Produktentscheid
ausstehend.

**(b) `CruiseCardView.swift` ist orphaned**  
`CruiseCardView` wird seit diesem Redesign in der Produktion nicht mehr referenziert.
Die Datei bleibt per Surgical-Changes-Policy ungeanderter in der Codebase und ist fuer
einen kuenftigen Housekeeping-Pass markiert.

---

## Verwandte Entscheidungen

Kein neuer ADR benoetigt. Das Redesign ist eine reine UI-Umstrukturierung, die das
bestehende SwiftData-Modell unveraendert laesst. Alle Aggregatwerte werden aus
vorhandenen Modell-Properties berechnet; keine Architekturentscheidung war erforderlich.

Verwandte bestehende ADRs (Referenz):

- [ADR-001: `isDemo`-Attribut bleibt build-konfigurationsunabhaengig im Schema](../adr/ADR-001-isdemo-in-release-schema.md)
- [ADR-002: CloudKit-Sync, stabile IDs und ZIP-Export](../adr/ADR-002-cloudkit-sync-und-stabile-ids.md)
