# Welle B4 — Karten-Überarbeitung

**Status:** B4.3a (Konsistenz-Fix) + B4.3b-1 (Zwei-Stufen-Zoom, Badges, Callout)
abgeschlossen — B4.3b-2 (Bottom-Sheet-Stopliste) und B4.3b-3
(Bezier-Kurvenrouten) **geliefert in v2**, siehe
[`karten-redesign-v2-journal-atlas.md`](karten-redesign-v2-journal-atlas.md)
**Testsuite:** `MapMarkerPlannerTests.swift` (14 Unit-Tests) + `MapZoomAndSelectionTests.swift`
(12 Unit-Tests), Teil der 202-Unit-Tests-Gesamtsuite
**Quelle:** [Umsetzungsplan Audit 2026-07](../umsetzungsplan-audit-2026-07.md#welle-b4--karten-überarbeitung-feedback-route-stops-nicht-erkennbar-m-hafennamen-fehlen-teils-m-start-endhafen-nicht-unterscheidbar-m--quelle-testflight-feedback-2026-07-03-design-welle-benchmark-vor-umsetzung),
TestFlight-Feedback 2026-07-03 (Route-Stopps nicht erkennbar, Hafennamen fehlen
teils, Start-/Endhafen nicht unterscheidbar)

## Beschreibung

Welle B4 überarbeitet die Kartendarstellung (`MapView`) in zwei Sprints: ein
kleiner Konsistenz-Fix (B4.3a) und eine größere „mutige Richtung" mit
nummerierten Wegpunkt-Badges, Zwei-Stufen-Zoom, Tap-Callout und synchronisierter
Bottom-Sheet-Stopliste (B4.3b — Zoom/Badges/Callout als B4.3b-1 umgesetzt,
Bottom-Sheet-Stopliste und Bezier-Kurvenrouten als B4.3b-2/-3 noch offen).
Design-Benchmark und Mockups liegen
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

### Known Limitation — GELÖST in B4.3b-1

Auf der „Alle Reisen"-Karte (mehrere Routen gleichzeitig sichtbar) waren
Zwischenstopp-Pins zwar vollständig sichtbar (keine `[first,last]`-Kappung
mehr), aber **einfarbig** (`Color.portPin`, oceanBlue) statt in der jeweiligen
Routenfarbe — die Per-Route-Farbe (`Color.routeColor(at:)`) blieb nur noch auf
den Polylines erhalten. Bei mehreren gleichzeitig angezeigten Routen mit nahe
beieinanderliegenden Häfen (z. B. mehrere Mittelmeer-Routen mit Stopp in Palma)
stapelten sich dadurch gleichfarbige Pins, ohne dass erkennbar war, welcher Pin
zu welcher Reise gehört (verifiziert per Screenshot,
`audit/screenshots/weltkarte-all-{light,dark}.png`). Das war ein bewusst in Kauf
genommener Zwischenschritt: die „Alle Reisen"-Ansicht ist ohne Auswahl die
Default-Ansicht beim Öffnen des Karte-Tabs, der Zustand war also live auf
TestFlight sichtbar. Die Limitation ist mit **B4.3b-1** (Welt-Zoom zeigt
routenfarbige Dots statt einfarbiger Pins, siehe unten) vollständig aufgelöst —
unabhängig davon, ob B4.3b-2/-3 umgesetzt werden.

### Acceptance-Status

Erfüllt (für den in B4.3a definierten Scope). Abgesichert durch
`MapMarkerPlannerTests.swift` (14 Unit-Tests): Rollenzuweisung Start/Hafen/
Endpunkt, Rundreise-Erkennung innerhalb/außerhalb der Toleranz (inkl. Grenzfälle
knapp unter/über `0.0001°`), Ein-Hafen- und Leer-Routen, Seetag-Filterung sowie
Filterung von (0,0)-, Out-of-Range- und NaN/Infinity-Koordinaten.

## B4.3b-1 — Zwei-Stufen-Zoom, Wegpunkt-Badges, Tap-Callout

### Was / Warum

Erster Teilschritt der „mutigen Richtung" (Rest von B4.3b: Bottom-Sheet-Stopliste
B4.3b-2, Bezier-Kurvenrouten B4.3b-3, beide noch offen). Löst dabei bereits die
B4.3a-Known-Limitation (einfarbige Zwischenstopp-Pins auf der „Alle Reisen"-Karte)
vollständig auf.

`MapView.swift` unterscheidet jetzt zwei feste Zoom-Zustände statt eines
einheitlichen Pin-Stils über alle Zoomstufen (SwiftUI `Map` bietet aktuell kein
natives Clustering, siehe Research-Brief):

- **`MapZoomBucketPlanner`** (reiner, SwiftUI-freier Helper-Enum) — bildet
  `MKCoordinateRegion.span` auf `MapZoomBucket` (`.world`/`.route`) ab. Schwelle:
  `10°` (größerer der beiden Span-Werte), das geometrische Mittel der beiden
  Design-Deck-Anker (`b4-karten-redesign.html`, Slide 6: Welt-Zoom > 20°,
  Reise-Zoom < 5° → √(5·20) = 10°) statt eines der beiden Extreme.
  `MapView` beobachtet den Kamera-Zustand über `.onMapCameraChange(frequency: .onEnd)`
  und setzt den Bucket synchron auch beim programmatischen `zoomTo(routes:)`
  (verhindert einen kurzen Flash der falschen Zoom-Stufe bei Reisewechsel/Start).
- **Welt-Zoom**: nur kleine, **routenfarbige** Dots (`Color.routeColor(at:)`,
  9pt, weißer Rand) + Polylines — keine Rollen-Pins, keine Labels. Löst die
  B4.3a-Limitation: jede Route behält jetzt auch bei den Zwischenstopp-Dots ihre
  eigene Farbe, keine gleichfarbigen Pins mehr über mehrere Routen hinweg.
- **Reise-Zoom**: volle `PortPinView`-Rollen-Pins (Start/Hafen/Endpunkt/Rundreise,
  aus B4.3a) für Start/Ende, **nummerierte, routenfarbige Wegpunkt-Badges**
  (neu: `MapStopBadgeView.swift`) für alle Zwischenstopps — die Nummer
  entspricht der 1-basierten Position in der Routenreihenfolge (`MapPortRole.stopNumber`).

Weitere neue Bausteine:

- **`MapCalloutView.swift`** — Tap auf einen Pin/Badge zeigt einen Callout mit
  Hafenname und optionalem Foto-Thumbnail (`AsyncPhotoView`, `maxPixelSize: 64`,
  asynchron gedownsampled). Ersetzt ein permanentes Kartenlabel (Polarsteps-Prinzip
  statt MapKit-Default-Label — dafür trägt die `Annotation` bewusst kein
  Text-`label:`, sondern `EmptyView()`).
- **`MapSelectionPlanner`** (reiner Helper-Enum) — Toggle-Logik für
  `selectedStopID`: erneuter Tap auf denselben Stopp hebt die Auswahl auf
  (Callout schließt), Tap auf einen anderen Stopp wechselt sie, ein Wechsel in
  den Welt-Zoom verwirft eine bestehende Auswahl (im Welt-Zoom gibt es nur Dots
  ohne Callout — eine überlebende Auswahl würde sonst ein Phantom-Callout oder,
  später, einen irreführenden Selektionszustand für das **B4.3b-2**-Bottom-Sheet
  vortäuschen). `selectedStopID` ist als Single Source of Truth bewusst schon
  jetzt das Fundament für die Karte↔Liste-Synchronisation von B4.3b-2.

### Berührte Dateien

- `ShipTrip/Views/Map/MapView.swift` — `MapZoomBucket`/`MapZoomBucketPlanner`,
  `MapSelectionPlanner`, `selectedStopID`-State, `.onMapCameraChange`-Handler,
  `markerContent(for:routeIndex:)` (Bucket-abhängige Darstellung),
  `worldDotView(color:)`.
- `ShipTrip/Views/Map/MapStopBadgeView.swift` (neu) — nummeriertes,
  routenfarbiges Wegpunkt-Badge für Zwischenstopps im Reise-Zoom.
- `ShipTrip/Views/Map/MapCalloutView.swift` (neu) — Tap-Callout mit Hafenname +
  Foto-Thumbnail.

### Acceptance-Status

Erfüllt (für den in B4.3b-1 definierten Teil-Scope: Zoom-Stufen, Badges,
Callout, Selektionsfundament). Abgesichert durch `MapZoomAndSelectionTests.swift`
(12 Unit-Tests): Bucket-Zuordnung nahe/knapp unter/knapp über der 10°-Schwelle
sowie maßgeblich der größere der beiden Span-Werte; Tap-Toggle-Selektion
(selektieren, erneuter Tap hebt auf, Wechsel zu anderem Stopp) und
Selektions-Verwerfen/-Erhalten je nach Zielzoomstufe (Welt- vs. Reise-Zoom, mit
und ohne bestehende Auswahl).

### B4.3b-2, B4.3b-3 — geliefert in v2

Bottom-Sheet-Stopliste (B4.3b-2) und Bezier-/Spline-Kurvenrouten (B4.3b-3) waren
hier noch offen — beide sind jetzt Teil der Welle „Karten-Redesign v2 — Journal
Atlas" geliefert: siehe
[`karten-redesign-v2-journal-atlas.md`](karten-redesign-v2-journal-atlas.md) für
Details, berührte Dateien und Akzeptanzkriterien-Status.

## Nächster Schritt

**B4.3b-2 + B4.3b-3 — geliefert**, siehe
[`karten-redesign-v2-journal-atlas.md`](karten-redesign-v2-journal-atlas.md).

## Related Decisions

- [Design-Deck: Karten-Redesign (B4.1/B4.2)](../ux-pitch-decks/b4-karten-redesign.html)
- [Fertiglösungen-Research (native-first)](../../.planning/b4-fertigloesungen-research.md)
