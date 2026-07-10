# Karten-Redesign v2 — „Journal Atlas"

**Status:** geliefert (GO, Quality-Review Iteration 2/3), löst B4.3b-2 und
B4.3b-3 vollständig ein
**Testsuite:** `MapRouteCurveSamplerTests.swift` (8 Unit-Tests) +
`MapRouteVisibilityPlannerTests.swift` (10 Unit-Tests), zusätzlich zu den
bestehenden `MapMarkerPlannerTests.swift` (19) und `MapZoomAndSelectionTests.swift`
(12) — 232/232 der Gesamtsuite grün (nach Fix-Runde 2)
**Quelle:** [`.planning/karten-redesign-v2-spec.md`](../../.planning/karten-redesign-v2-spec.md)
(Design-Spec, verbindliche Tokens), Design-Deck
[`docs/ux-pitch-decks/karten-redesign-v2-richtungen.html`](../ux-pitch-decks/karten-redesign-v2-richtungen.html)
(3 Richtungen, Richtung 2 „Journal Atlas" gewählt), Quality-Review
[`.planning/quality-review-karten-v2.md`](../../.planning/quality-review-karten-v2.md)

## Beschreibung

Kompletter Umbau der Weltkarte (`MapView`) auf die „Journal Atlas"-Richtung:
kurvige Catmull-Rom-Routen mit Farbschatten-Underlay statt gerader Liniensegmente,
ein solides Navy-Chrome (kein Glasmorphismus mehr) mit Burger-Menü oben rechts für
die Routenauswahl (inkl. „alle ausblenden"), und ein Bottom-Sheet mit
Peek/Medium/Large-Detents, das eine synchronisierte Stop-Timeline zeigt und die
frühere Bottom-Card ersetzt. Damit sind die beiden zuvor offenen Teilschritte von
Welle B4.3b — Bottom-Sheet-Stopliste (B4.3b-2) und Bezier-/Spline-Kurvenrouten
(B4.3b-3) — vollständig geliefert, siehe
[`karten-redesign-b4.md`](karten-redesign-b4.md).

## Berührte Dateien

- `ShipTrip/Views/Map/MapView.swift` (407 Zeilen, vorher 543 vor dieser Welle,
  zwischenzeitlich 638 vor der Extraktion) — Chrome-Buttons, Burger-Menü
  (`burgerMenu`, `routeMenuItems`), Bottom-Sheet-Wiring (`isSheetPresented`,
  `sheetDetent`, `.sheet(...)`), `allRoutesHidden`-State, „Alle
  ausgeblendet"-Leerzustand-Overlay (`allRoutesHiddenOverlay`).
- `ShipTrip/Views/Map/MapView+RouteInteraction.swift` (neu, 144 Zeilen) —
  Kartenlinien-/Marker-Rendering (`routeContent(for:)`, `markerContent(for:routeIndex:)`,
  `worldDotView`, `markerView(for:isSelected:)`) und Linien-Tap-Hit-Testing
  (`handleMapTap(at:using:)`, `nearestRouteID(to:using:)`) — aus `MapView.swift`
  ausgelagert, um das 500-Zeilen-Limit einzuhalten (siehe „Bekannte
  Einschränkungen").
- `ShipTrip/Views/Map/MapRouteCurveSampler.swift` (neu) — `RouteCurveSampler`,
  reine SwiftUI-freie Catmull-Rom-Spline-Logik durch geordnete, valide
  Hafen-Koordinaten; Punkte-Budget adaptiv gedeckelt (`clamp(280 /
  Gesamtsegmentanzahl, 6, 24)`), Randsegmente über gespiegelte Stützpunkte,
  degenerierte Fälle (0/1/2 Punkte) ohne Crash.
- `ShipTrip/Views/Map/MapRouteVisibilityPlanner.swift` (neu) — reiner Helper für
  die `allRoutesHidden`/`activeRouteIDs`-Zustandsmaschine (Alle-ein/ausblenden,
  Einzel-Toggle mit Guard gegen „letzte Route per Einzel-Tap abwählen").
- `ShipTrip/Views/Map/RouteStopSheetView.swift` (neu, 189 Zeilen) —
  Bottom-Sheet-Inhalt: Peek (Titel + Substats), Medium (scrollbare Stop-Liste mit
  Timeline-Linie), Large (+ „Öffnen"-Button zu `CruiseDetailView`); Stop-Tap
  springt die Kamera und kollabiert das Sheet auf Peek.
- `ShipTrip/Views/Map/MapMarkerPlanner.swift`, `MapSelectionPlanner.swift`,
  `MapZoomBucketPlanner.swift` — in dieser Welle als eigene Dateien aus
  `MapView.swift` extrahiert (vorher inline, siehe
  [`karten-redesign-b4.md`](karten-redesign-b4.md)); Logik selbst unverändert.
- `ShipTrip/Utilities/Color+Theme.swift` — neue Tokens `journalSurface`(`Light`/`Dark`)
  und `journalTimeline`, adaptiv über `Color(uiColor:)`/`UITraitCollection`.
- `ShipTrip/Localizable.xcstrings` — neue Strings: „Alle ausblenden"/"Hide all",
  „Alle Routen ausgeblendet"/"All routes hidden", „Tippe auf das Menü, um Routen
  einzublenden"/"Tap the menu to show routes", A11y-Label „Routenauswahl"/"Route
  selection".
- `ShipTripUITests/HauptansichtScreenshotTests.swift` — an neue Screenshot-Namen
  angepasst; Assertion in `testScreenshot_MapAllTrips_Light/Dark` auf
  `app.buttons["Routenauswahl"]` (Burger-Button-Label) umgestellt, beide Tests
  grün.
- `ShipTripTests/MapRouteCurveSamplerTests.swift`,
  `ShipTripTests/MapRouteVisibilityPlannerTests.swift` (neu).

## Was fällt weg

- Filter-Menü oben links (`line.3.horizontal.decrease.circle`) — ersatzlos
  entfernt, Funktion geht im neuen Burger-Menü (oben rechts) auf.
- Bottom-Info-Card (`routeSelectionCard`, `.ultraThinMaterial`-Overlay) —
  vollständig ersetzt durch den Sheet-Peek-Zustand.
- „Routen"-Capsule-Button innerhalb der alten Bottom-Card — entfällt, Funktion
  geht im Burger-Menü auf.

Der Recenter-Button bleibt erhalten, wandert aber von oben rechts nach oben
links (macht Platz für den neuen Burger-Button).

## Akzeptanzkriterien-Status

Aus `.planning/karten-redesign-v2-spec.md`, gegengeprüft mit dem Quality-Review:

| # | Kriterium | Status |
|---|---|---|
| 1 | Kurvige Routen (Catmull-Rom) statt gerader Segmente | Erfüllt — Code, Unit-Tests, Screenshot verifiziert |
| 2 | Burger-Menü oben rechts, Default „alle sichtbar", Alle-ausblenden-Toggle | Erfüllt (Logik) — Button sichtbar/korrekt positioniert, Toggle vollständig unit-getestet; interaktive UI-Bedienung nicht live verifizierbar (Tooling-Grenze, kein Feature-Zweifel) |
| 3 | Einzel-Route ab-/anwählbar, Guard gegen letzte Route | Erfüllt — vollständig unit-getestet + Code-Review |
| 4 | Tap auf Route (Linie/Marker) öffnet Sheet Peek/Medium/Large, Karte bis Medium bedienbar | Erfüllt — Marker-Pfad live verifiziert, Linien-Pfad code-verifiziert (kompiliert, Logik korrekt) |
| 5 | Stop-Tap im Sheet springt Kamera + kollabiert auf Peek | Erfüllt (Code-Review) — Medium-Zustand nicht live erreichbar ohne Drag-Geste |
| 6 | Recenter-Button weiterhin erreichbar (oben links) | Erfüllt — Screenshot + Tap verifiziert |
| 7 | Hell/Dunkel beide geprüft (journalSurface/journalTimeline, Pin-Halo, Chrome) | Erfüllt — beide Modi live gescreenshottet |
| 8 | Bestehende + neue Unit-Tests grün | Erfüllt — 232/232 Gesamtsuite (nach Fix-Runde 2), alle Unit-Tests grün |

### Quality-Findings-Status (Fix-Runde 2)

| ID | Severity | Status |
|---|---|---|
| F01 | major | fixed — `MapView.swift` auf 407 Zeilen reduziert (Extraktion `MapView+RouteInteraction.swift` + 3 Planner-Dateien) |
| F02 | major | fixed — Screenshot-Assertion auf Burger-Button-Label umgestellt |
| F03 | major | accepted-as-documented — vorbestehende Test-Flakiness außerhalb Redesign-Scope |
| F04 | minor | fixed — verwaister Localizable-Key entfernt |
| F05 | minor | fixed — Chrome-Button-Hit-Area auf 44pt angehoben (`.contentShape`) |
| F06 | minor | fixed — Sheet-Badge-Ring auf `Color.oceanBlue` vereinheitlicht |
| F07 | minor | fixed — Whitespace-Diff-Rauschen zurückgenommen |
| F08 | minor | accepted-as-documented — Antimeridian-Backlog-Notiz, kein aktueller Fall betroffen |

## Bekannte Einschränkungen

- **Antimeridian-Routen ohne Spezialbehandlung** (vorbestehend, nicht neu durch
  diese Welle): `RouteCurveSampler` interpoliert Lat/Lon unabhängig — bei einer
  hypothetischen Transpazifik-Route (Longitude-Sprung über ±180°) würde die
  Spline durch den falschen Globus-Teil laufen. Kein aktueller ShipTrip-Fall
  betroffen.
- **Burger-Menü und Sheet-Drag-Interaktionen nur code-/unit-verifiziert**: Die
  Quality-Verifikation per synthetischen System-Events-Klicks konnte SwiftUI-
  `Menu`-Präsentation und Drag-Gesten (Sheet-Hochziehen, präziser Linien-Tap)
  nicht zuverlässig simulieren — reine Tooling-Grenze, die Logik selbst ist
  durch `MapRouteVisibilityPlannerTests` (10/10) und Code-Review abgedeckt.
  Empfehlung aus dem Quality-Review: manueller QA-Pass auf echtem Gerät vor
  GoLive.
- **`.presentationBackground(.regularMaterial)` statt vollem
  `journalSurface`-Solid**: bewusster v1-Kompromiss aus der Spec — reduziert das
  Risiko gegenüber einem Custom-Solid-`.presentationBackground` (u. a.
  Dynamic-Type-Randfälle), ist aber optisch nicht das volle „warme Papier"-Ziel.
- Restliche offene Quality-Findings (F03 Test-Flakiness, F08
  Antimeridian-Backlog) sind beide als „accepted-as-documented" eingestuft —
  siehe Tabelle oben und Details im Quality-Review
  (`.planning/quality-review-karten-v2.md`).

## Related Decisions

- [Design-Spec „Journal Atlas"](../../.planning/karten-redesign-v2-spec.md)
- [Design-Deck: 3 Richtungen](../ux-pitch-decks/karten-redesign-v2-richtungen.html)
- [Quality-Review](../../.planning/quality-review-karten-v2.md)
- [Vorgänger-Welle B4](karten-redesign-b4.md)
