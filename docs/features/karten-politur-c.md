# Karten-UI-Politur Welle C — Tester-Feedback Build 16

**Status:** geliefert (GO, Quality-Review Iteration 2/2 — nach einer Fix-Runde)
**Testsuite:** Finaler Volllauf grün — 254 Unit- + 24 UI-Tests, 0 Fehler
(2026-07-10, iPhone-17-Simulator, iOS 26.5). Neu/erweitert in dieser Welle:
`MapClusterPlannerTests.swift`, `MapPinPlaceholderContrastTests.swift`,
`MapCameraFitTests.swift`, `MapAlleRoutenUITests.swift`, sowie erweitertes
`MapZoomAndSelectionTests.swift`.
**Quelle:** [`.planning/design-spec-karten-politur-c.md`](../../.planning/design-spec-karten-politur-c.md)
(Design-Spec, verbindliche Tokens), TestFlight-Feedback-Screenshots
`.planning/testflight-feedback-2026-07-10/2026-07-10-build16-01..04.png`, Quality-Reviews
[`.planning/quality-review-karten-c-iter1.md`](../../.planning/quality-review-karten-c-iter1.md)
(NO-GO, 3 major) und
[`.planning/quality-review-karten-c-iter2.md`](../../.planning/quality-review-karten-c-iter2.md)
(GO nach Fix-Runde 1)

## Beschreibung

Politur-Welle auf Basis von vier Tester-Findings zu Build 16 des Karten-Redesigns v2
„Journal Atlas" ([`karten-redesign-v2-journal-atlas.md`](karten-redesign-v2-journal-atlas.md)):
ein Bugfix für eine komplett weiße Karte nach „Alle anzeigen/ausblenden" (F1), ein Umbau
des Routen-Burger-Menüs von nativem `Menu` auf ein eigenes Popover-Panel mit einheitlichem
Icon-System (F2), optische Politur des Routen-Detail-Sheets inklusive eines
System-API-Fixes für hakeliges Runterswipen (F3), sowie eine latitude-korrigierte
Zoom-Schwelle plus ein neues geografisches Overlap-Clustering für Stops im mittleren
Zoom-Level, das sich per Tap selbst auflöst (F4). Die Umsetzung führt die in der Vorwelle
etablierten Muster fort — reine, SwiftUI-freie Planner-Funktionen
(`MapClusterPlanner`, erweiterter `MapZoomBucketPlanner`) und das bestehende
Farb-/Radius-Token-System (`Color+Theme.swift`) — ohne neue Architektur-Entscheidung; daher
kein eigenes ADR für diese Welle.

## Berührte Dateien

- `ShipTrip/Views/Map/MapView.swift` — Burger-Menü-Button togglet jetzt ein `@State`-Popover
  statt `Menu` zu öffnen; `.menuActionDismissBehavior(.disabled)` (Ursache des
  Weiße-Karte-Bugs, F1) auf die Einzel-Routen-Toggles begrenzt statt aufs ganze Menü;
  `mapViewportHeight`-State via `GeometryReader` ersetzt `UIScreen.main.bounds.height` für
  die Popover-Höhenbegrenzung.
- `ShipTrip/Views/Map/RouteMenuPanelView.swift` (neu) — eigenständiges Popover-Panel-Content
  für die Routenauswahl: opake `journalSurface`-Füllung, max. 300pt Breite, 24pt-Icon-Kreise
  (gefüllt+Checkmark aktiv, Outline inaktiv), einzeilige Titel mit `.truncationMode(.middle)`.
- `ShipTrip/Views/Map/MapView+RouteInteraction.swift` — Cluster-Tap-Entscheidung
  (`MapClusterPlanner.tapOutcome`) in die Marker-Button-Action verdrahtet (zoomt bei
  Cluster-Primary in die Cluster-Mitglieder hinein statt Callout/Sheet zu öffnen); Insets für
  ≥44pt-Tap-Flächen an Welt-Dot, Route-Badge, Rollen-Pin und Cluster-Pill; konsolidiertes
  VoiceOver-Label (Nummer+Name+Land) auf dem äußeren Button, `.accessibilityHidden(true)` auf
  allen internen Marker-Views (Badge, Dot, Rollen-Pin) gegen Doppel-Announcements.
- `ShipTrip/Views/Map/MapClusterPlanner.swift` (neu) — reine, SwiftUI-freie
  Union-Find-Logik: paarweiser Bildschirm-Abstandsvergleich über alle Stops einer Route
  (nicht auf Routenreihenfolge-Nachbarschaft beschränkt, deckt Rundreise-/Kreuzungsfälle ab),
  plus `TapOutcome`-Entscheidungsfunktion (`.zoomToCluster(coordinates:)` vs. `.selectStop`).
- `ShipTrip/Views/Map/MapZoomBucketPlanner.swift` — Schwelle von binär-kompromittierten 10°
  auf den ursprünglichen 20°-Deck-Anker zurückgesetzt, `bucket(for:centerLatitude:)` korrigiert
  den Längengrad-Span jetzt um `cos(centerLatitude)` gegen Mercator-Stauchung in höheren
  Breiten (relevant für Nordnorwegen-Routen).
- `ShipTrip/Views/Map/MKCoordinateRegion+Fit.swift` (neu) — `MKCoordinateRegion(coordinates:)`-
  Initializer, den sowohl der bestehende Stop-Tap-Zoom als auch der neue Cluster-Tap-Zoom
  nutzen.
- `ShipTrip/Views/Map/MapSelectionPlanner.swift` — Anpassung im Zuge der F1/F4-Fixes (siehe
  Diff; keine neue Selection-Kernsemantik, `.world`-Bindung des Selection-Clears bleibt
  laut Design-Spec unverändert Out-of-Scope).
- `ShipTrip/Views/Map/RouteStopSheetView.swift` — Badge-Gradient-Fill statt Flat-Fill,
  Auswahl-Zeile als abgesetzter Chip (Rand + Inset) statt Full-Bleed-Wash, Pin-Platzhalter
  nutzt jetzt `MapPinPlaceholderTokens`, `.presentationContentInteraction(.resizes)` +
  `.scrollBounceBehavior(.basedOnSize)` gegen den ScrollView-vs-Sheet-Drag-Konflikt.
- `ShipTrip/Utilities/Color+Theme.swift` — neues `MapPinPlaceholderTokens`-Enum
  (`fillOpacityLight/Dark`, `borderOpacityLight/Dark` = 0.55/0.40) für den Pin-Platzhalter-Rand.
- `ShipTripTests/MapClusterPlannerTests.swift` (neu), `MapPinPlaceholderContrastTests.swift`
  (neu, berechnet WCAG-Kontrast direkt aus den echten `Color`-Konstanten),
  `MapCameraFitTests.swift` (neu, `MKCoordinateRegion(coordinates:)`),
  `MapZoomAndSelectionTests.swift` (erweitert um Kanaren-Regression + Norwegen-Latitude-Fall).
- `ShipTripUITests/MapAlleRoutenUITests.swift` (neu) — UI-Test für den F1-Regressionsfall
  (Menü-Dismiss-Verhalten nach „Alle anzeigen/ausblenden").

## Akzeptanzkriterien-Status

Gegenübergestellt mit der Akzeptanzkriterien-Matrix aus
[`quality-review-karten-c-iter2.md`](../../.planning/quality-review-karten-c-iter2.md) (GO
nach Fix-Runde 1; iter1 hatte 3 major + 2 minor Findings, alle in Fix-Runde 1 adressiert).

| Finding | Kriterium | Status |
|---|---|---|
| F1 | Weiße Karte nach „Alle anzeigen/ausblenden" tritt nicht mehr auf | erfüllt |
| F2 | Popover ≤ `min(0.45×Bildschirmhöhe, 380pt)`, opak, kein mehrzeiliger Titel, Icon-Kreis in beiden Zuständen, 3× Einzel-Toggle schließt Panel nicht, VoiceOver „Route, {Titel}, {Status}" | erfüllt |
| F3 | Drag resized Sheet bis `.large` ohne Scroll-Konflikt, Badge-Gradient Light+Dark, Chip statt Full-Bleed, kein Akzent-Konflikt mit System-Grabber | erfüllt |
| F3 | Pin-Platzhalter ≥3:1 Kontrast (Light+Dark) | erfüllt — jetzt per Unit-Test rechnerisch bewiesen (`MapPinPlaceholderContrastTests`), nicht mehr nur behauptet: Light ≈ 3.17:1, Dark ≈ 3.74:1 |
| F4 | Span 10–20° (latitude-korrigiert) zeigt Reise-Zoom statt Welt-Dots (Kanaren-Fall) | erfüllt, unit-getestet |
| F4 | Norwegen/hohe Breite fällt nicht vorzeitig in `.world` | erfüllt, unit-getestet |
| F4 | Zwei nah beieinander liegende Stops → 1 Badge + „+1"-Pill, unabhängig von Stop-Reihenfolge | erfüllt, unit-getestet (`MapClusterPlannerTests`) |
| F4 | Tap auf Cluster zoomt hinein und löst ihn auf (kein Callout im geclusterten Zustand) | erfüllt — nach Fix-Runde 1 (iter1-Finding F01), verdrahtet über `MapClusterPlanner.TapOutcome` |
| F4 | Alle vier Marker-Varianten (Welt-Dot, Route-Badge, Rollen-Pin, Cluster-Pill) ≥44×44pt Tap-Fläche | erfüllt — analytisch mit dokumentierter Worst-Case-Herleitung + Sicherheitsmarge (siehe Offene Punkte: reine Geräte-Bestätigung steht noch aus) |
| F4 | VoiceOver liest Nummer+Name+Land in jedem Zoom-Bucket, kein Doppel-Announcement | erfüllt — inkl. Rollen-Pin (`.accessibilityHidden(true)` nachgezogen, iter1-Finding F02) |

## Offene Punkte / Known Limitations

- **Tap-Target-Geometrie nur analytisch, nicht am Gerät gemessen:** die Insets für
  Rollen-Pin (`-7`) und Cluster-Pill (`-18`) in `MapView+RouteInteraction.swift` beruhen auf
  einer dokumentierten Worst-Case-Rechnung mit Sicherheitsmarge, nicht auf einer echten
  Messung im Simulator/Accessibility Inspector. Laut Quality-Review iter2 kein Merge-Blocker
  mehr (herabgestuft von major auf minor), aber empfohlener Fast-Follow vor dem nächsten
  TestFlight-Upload.
- **F2 Truncation-Restrisiko:** zwei Routen mit identischem Präfix UND identischem Suffix
  (z. B. exakt derselbe Reisetitel in zwei Jahren mit identischem Abfahrtshafen) sehen im
  300pt-Panel weiterhin identisch aus — laut Design-Spec ein bekannter, nicht vollständig
  lösbarer Restfall bei der harten Vorgabe „einzeilig".
- **iOS-26-Glass-Kür** für das Routen-Sheet (`.glassEffect()`) wurde wie in der Design-Spec
  als optional markiert bewusst nicht umgesetzt (Deployment-Target bleibt iOS 18.5).
- **Cluster-Pill-Kollision bei 3+ benachbarten, aber getrennten Clustern** auf sehr dichten
  Routen ist laut Design-Spec ein seltener, nicht gesondert gelöster Edge-Case (Datengröße
  ShipTrip: ≤20 Stops/Route).
- Finaler Testlauf der Gesamtsuite: grün (254 Unit + 24 UI, 0 Fehler, 2026-07-10) —
  siehe Testsuite-Zeile im Kopf dieses Dokuments.

## Related Decisions

- [Design-Spec Welle C](../../.planning/design-spec-karten-politur-c.md)
- [Quality-Review iter1 (NO-GO)](../../.planning/quality-review-karten-c-iter1.md)
- [Quality-Review iter2 (GO)](../../.planning/quality-review-karten-c-iter2.md)
- [Vorgänger-Welle: Karten-Redesign v2 „Journal Atlas"](karten-redesign-v2-journal-atlas.md)
