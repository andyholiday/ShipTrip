# Welle B4 — Karten-Überarbeitung

**Status:** B4.3a (Konsistenz-Fix) abgeschlossen — B4.3b (Mutige Richtung) offen
**Testsuite:** `MapMarkerPlannerTests.swift`, 14 Unit-Tests, Teil der 164/164-Gesamtsuite
**Quelle:** [Umsetzungsplan Audit 2026-07](../umsetzungsplan-audit-2026-07.md#welle-b4--karten-überarbeitung-feedback-route-stops-nicht-erkennbar-m-hafennamen-fehlen-teils-m-start-endhafen-nicht-unterscheidbar-m--quelle-testflight-feedback-2026-07-03-design-welle-benchmark-vor-umsetzung),
TestFlight-Feedback 2026-07-03 (Route-Stopps nicht erkennbar, Hafennamen fehlen
teils, Start-/Endhafen nicht unterscheidbar)

## Beschreibung

Welle B4 überarbeitet die Kartendarstellung (`MapView`) in zwei Sprints: ein
kleiner Konsistenz-Fix (B4.3a, dieser Stand) und eine größere „mutige Richtung"
mit nummerierten Wegpunkt-Badges, Zwei-Stufen-Zoom und synchronisierter
Bottom-Sheet-Stopliste (B4.3b, noch offen). Design-Benchmark und Mockups liegen
im HTML-Deck [`docs/ux-pitch-decks/b4-karten-redesign.html`](../ux-pitch-decks/b4-karten-redesign.html)
(B4.1/B4.2). Andres Entscheid 2026-07-04: die mutige Richtung wird **nativ**
umgesetzt (MapKit/SwiftUI, kein Fremd-SDK) statt mit einer Fertiglösung — Details
und Abwägung im Research-Brief
[`.planning/b4-fertigloesungen-research.md`](../../.planning/b4-fertigloesungen-research.md).

## B4.3a — Konsistenz-Fix

### Was / Warum

`MapView` nutzte bisher eine eigene, von der Detailansicht losgelöste
`routeMarker()`-Logik: Start-/Endhafen waren nicht optisch von Zwischenstopps zu
unterscheiden, `markerPorts()` kappte Mehrfachrouten auf `[first, last]` (Tester-
Feedback „Route-Stopps nicht erkennbar" — Zwischenstopps fehlten schlicht auf der
Karte), und eine Rundreise mit identischem Start-/Endhafen erzeugte zwei
überlagerte Pins statt eines Kombi-Markers.

Neu: `MapView.swift` nutzt jetzt

- **`MapMarkerPlanner`** (reiner, SwiftUI-freier Helper-Enum direkt in
  `MapView.swift`) — leitet aus einer Portliste die Kartenmarker-Rollen ab:
  filtert Seetage sowie Ports mit fehlenden, out-of-range oder nicht-endlichen
  (NaN/Infinity) Koordinaten heraus (`validPorts(in:)`), sortiert nach
  `sortOrder`, und weist Rollen zu (`markerRoles(for:)`). Erkennt den
  Rundreise-Sonderfall (Start- und Endkoordinate identisch innerhalb einer
  Toleranz von `0.0001°`, ~11 m — deckt Rundungsdrift zwischen zwei unabhängig
  erfassten Einträgen desselben Hafens ab) und erzeugt dafür **einen** Marker
  (Rolle `.homePort`) statt zweier überlappender Pins.
- **`PortPinView`-Rollensystem** (bereits aus der Detail-Route bekannt: Start =
  Heimathafen orange, Hafen blau, Endpunkt grün, Seetag Wellen) statt der
  eigenen `routeMarker()`-Darstellung — Pins auf der Karte sind damit optisch
  identisch zur Reise-Detailansicht.
- **Keine `[first, last]`-Kappung mehr**: `markerPorts()` wurde entfernt,
  `markerRoles(for:)` gibt alle validen Zwischenstopps zurück, auch bei mehreren
  gleichzeitig angezeigten Routen.

### Berührte Dateien

- `ShipTrip/Views/Map/MapView.swift` — `MapMarkerPlanner`-Enum,
  `MapPortRole`-Struct, `markerView(for:)` nutzt `PortPinView` statt
  `routeMarker()`; `validPorts(for:)` delegiert an `MapMarkerPlanner.validPorts(in:)`.
- `ShipTrip/Components/PortPinView.swift` — unverändert wiederverwendet
  (Rollensystem existierte bereits für die Detail-Route).

### Known Limitation

Auf der „Alle Reisen"-Karte (mehrere Routen gleichzeitig sichtbar) sind
Zwischenstopp-Pins jetzt zwar vollständig sichtbar (keine `[first,last]`-Kappung
mehr), aber **einfarbig** (`Color.portPin`, oceanBlue) statt in der jeweiligen
Routenfarbe — die Per-Route-Farbe (`Color.routeColor(at:)`) bleibt nur noch auf
den Polylines erhalten. Bei mehreren gleichzeitig angezeigten Routen mit nahe
beieinanderliegenden Häfen (z. B. mehrere Mittelmeer-Routen mit Stopp in Palma)
stapeln sich dadurch gleichfarbige Pins, ohne dass erkennbar ist, welcher Pin zu
welcher Reise gehört (verifiziert per Screenshot,
`audit/screenshots/weltkarte-all-{light,dark}.png`). Das ist ein bewusst in Kauf
genommener Zwischenschritt: die „Alle Reisen"-Ansicht ist ohne Auswahl die
Default-Ansicht beim Öffnen des Karte-Tabs, der Zustand ist also live auf
TestFlight sichtbar. Die geplante Lösung ist **B4.3b** (Zwei-Stufen-Zoom +
Bottom-Sheet-Stopliste statt permanenter Einzel-Pins bei mehreren Routen) — im
Quality-Review als Merge-Blocker verneint, aber mit der Empfehlung,
B4.3b im nächsten Sprint zu priorisieren statt zu verschieben.

### Acceptance-Status

Erfüllt (für den in B4.3a definierten Scope). Abgesichert durch
`MapMarkerPlannerTests.swift` (14 Unit-Tests): Rollenzuweisung Start/Hafen/
Endpunkt, Rundreise-Erkennung innerhalb/außerhalb der Toleranz (inkl. Grenzfälle
knapp unter/über `0.0001°`), Ein-Hafen- und Leer-Routen, Seetag-Filterung sowie
Filterung von (0,0)-, Out-of-Range- und NaN/Infinity-Koordinaten.

## Nächster Schritt

**B4.3b** (`docs/umsetzungsplan-audit-2026-07.md`, Welle B4): nummerierte
Wegpunkt-Badges, Zwei-Stufen-Zoom über `.onMapCameraChange` +
`MKCoordinateRegion.span`-Schwelle, Bottom-Sheet-Stopliste bidirektional mit der
Karte synchronisiert (laut Research-Brief der größte Aufwandstreiber — reine
SwiftUI-State-Synchronisation, kein MapKit-Feature), Tap-Callout mit Foto,
Bezier-Kurvenrouten um Landmassen. Rein natives MapKit/SwiftUI, kein Fremd-SDK
(Research-Brief-Fazit: kein Baustein der mutigen Richtung profitiert von einem
Fremd-SDK gegenüber nativen Mitteln). Startet im selben Datei-Scope
(`MapView.swift`) nach B4.3a.

## Related Decisions

- [Design-Deck: Karten-Redesign (B4.1/B4.2)](../ux-pitch-decks/b4-karten-redesign.html)
- [Fertiglösungen-Research (native-first)](../../.planning/b4-fertigloesungen-research.md)
