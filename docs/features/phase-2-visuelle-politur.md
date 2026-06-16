# Phase 2 — Visuelle Politur

**Status:** In Arbeit (Welle 1–3 abgeschlossen, Build verifiziert)
**Datum:** 2026-06-16

## Beschreibung

Phase 2 hebt ShipTrip vom funktionalen Reisetagebuch zur Premium-App, indem
jede Listenzeile und jede Detailansicht das eigene Foto der Reise in den
Vordergrund stellt. Leitgedanke: Fotos dominieren den ersten Blick; Metadaten
treten als dezentes Overlay dahinter. Wo kein Foto vorhanden ist, greift ein
atmosphärischer oceanBlue-navy-Verlauf als Fallback. Die Änderungen berühren
ausschließlich View-Schicht und Farbsystem — keine Modell- oder
Service-Änderungen.

---

## History

### 2026-06-16 — Welle 3: Hero-Header im Reise-Detail

Großer Hero-Header in `CruiseDetailView` (280 pt Foto-Pager /
220 pt Verlauf-Fallback). Titel-Overlay erscheint einmal, nicht pro
Pager-Seite. Neue Eckdaten-Zeile mit vier Kern-Zahlen direkt unter dem Header:
Reisetage, Häfen, Länder, Gesamtausgaben (Geräte-Locale-Währung).

### 2026-06-16 — Welle 2: Foto-zentrierte Reise-Karten

Vollflächiges Cover-Foto (210 pt) in `CruiseCardView` via
`thumbnailData ?? imageData`. Text-Overlay (Titel, Reederei, Schiff, Datum)
auf dunklem Scrim. Rating- und „Coming Soon"-Badge oben rechts unverändert.
Fallback: oceanBlue → navy mit Ferry-Symbol.

### 2026-06-16 — Welle 1: Einheitlicher Hafen-Pin und Schiffslisten

Neue `PortPinView`-Komponente (gemeinsam für Karte und Detailansicht).
Semantische Farbtoken `portPin`, `homePortPin`, `seaDayPin` in `Color+Theme`.
Schiffslisten auf Stand Juni 2026 gebracht; ausgeschiedene Schiffe in
`historicalShips`-Liste ausgelagert.

---

## Berührte Dateien

### Welle 1

- `ShipTrip/Components/PortPinView.swift` (neu)
- `ShipTrip/Utilities/Color+Theme.swift`
- `ShipTrip/Models/ShippingLine.swift`

### Welle 2

- `ShipTrip/Views/Cruises/CruiseCardView.swift`

### Welle 3

- `ShipTrip/Views/Cruises/CruiseDetailView.swift`

---

## Acceptance-Status

- Build: **grün** (BUILD SUCCEEDED, alle Wellen)
- Codex-Gate 2: **bestanden**
- Screenshots: vorhanden (Verlauf-Fallback sichtbar; Demo-Daten enthalten
  keine Fotos, Cover-Foto-Pfad nur kompiliert/Codex-geprüft)

---

## Bekannte Einschränkungen

- **Cover-Foto nur kompiliert/Codex-geprüft**: Die Demo-Datenbasis
  (`DemoDataService`) erzeugt keine Fotos, daher ist in Screenshots nur der
  ozeanblau-navy-Verlaufs-Fallback sichtbar. Der Foto-Pfad
  (`thumbnailData ?? imageData`) ist korrekt implementiert und baut fehlerfrei,
  wurde aber nicht visuell mit echten Fotos im Simulator getestet.
- **Keine Unit-Tests für View-Logik**: Eckdaten-Berechnung (Tage, Häfen,
  Länder, Ausgaben) liegt direkt in der View; kein isolierter Test vorhanden.

---

## Verwandte Entscheidungen

- [ADR-001: `isDemo`-Attribut bleibt build-konfigurationsunabhängig](../adr/ADR-001-isdemo-in-release-schema.md)
- [ADR-002: CloudKit-Sync, stabile IDs und ZIP-Export](../adr/ADR-002-cloudkit-sync-und-stabile-ids.md)

## UX-Pitch-Deck

[Phase-2-Visuelle-Politur Pitch-Deck](../ux-pitch-decks/phase-2-visuelle-politur.html)
