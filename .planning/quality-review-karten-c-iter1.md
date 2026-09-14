# Review — Karten-UI-Politur Welle C (Tester-Feedback Build 16)

- **Iteration**: 1 / 3
- **Reviewer**: quality-agent (read-only, kein Build/Test-Run — parallel durch Orchestrator)
- **Date**: 2026-07-10
- **Verdict**: request-changes (NO-GO für Merge in dieser Form)
- **Stats**: critical: 0, major: 3, minor: 2

## Summary

Review-Gegenstand: uncommittete Änderungen aus Phase 1 (F1-Bugfix Menü-Dismiss) und Phase 2
(F2 Popover-Menü, F3 Sheet-Politur, F4 Zoom-Schwelle + Overlap-Cluster). Die Umsetzung folgt
`.planning/design-spec-karten-politur-c.md` in den meisten Punkten sauber — Tokens stimmen
exakt (Panel 300pt/16pt-Radius, Icon 24pt, Popover-Höhenlimit `min(0.45×H, 380pt)`,
Kontrastwerte 0.55/0.40, Threshold 20° mit Latitude-Korrektur), alte Codepfade (`Menu`,
`menuActionDismissBehavior`, Checkmark/Circle-Formwechsel, 10°-Schwelle) sind vollständig
entfernt, keine Datei über dem 500-Zeilen-Limit, gute Unit-Test-Abdeckung für die reinen
Planner (`MapClusterPlanner`, `MapZoomBucketPlanner`, `MKCoordinateRegion(coordinates:)`).

Der Block bleibt: das zentrale F4-Verhalten „Tap auf einen Cluster zoomt hinein und löst ihn
auf" ist **nicht implementiert** — Cluster-Badges nutzen dieselbe Tap-Action wie normale
Badges (Callout + Sheet statt Zoom). Zusätzlich fehlt am Rollen-Pin-Marker das
`.accessibilityHidden(true)`, das bei Badge/Dot konsequent gesetzt wurde, was für
Heimathafen-/Endhafen-Marker ein doppeltes VoiceOver-Announcement riskiert. Mehrere vom
Design-Spec selbst als „Pflicht vor Merge" markierte manuelle Verifikationen (Tap-Target-Maße
Rollen-Pin/Cluster-Pill, Kontrast-Werte mit Accessibility Inspector) sind laut Code-Kommentar
des Developers noch nicht durchgeführt.

## Findings

| ID  | Severity | File:Line                                              | Category      | Title                                              |
|-----|----------|---------------------------------------------------------|----------------|-----------------------------------------------------|
| F01 | major    | `MapView+RouteInteraction.swift:54-58,111-128`           | correctness    | F4-Pflicht „Tap auf Cluster zoomt hinein" nicht implementiert |
| F02 | major    | `MapView+RouteInteraction.swift:167-178`                 | accessibility  | Rollen-Pin-Marker fehlt `.accessibilityHidden(true)` — Doppel-Announcement-Risiko |
| F03 | major    | `RouteStopSheetView.swift:171-177`, `MapView+RouteInteraction.swift:172-176,392` | a11y/verification | Pflicht-Checks (Kontrast, Tap-Target-Geometrie) laut Spec noch nicht gerätesverifiziert |
| F04 | minor    | `MapView.swift:284-286`                                 | code-quality   | `UIScreen.main.bounds.height` ist deprecated/scene-blind |
| F05 | minor    | `docs/umsetzungsplan-audit-2026-07.md`                   | scope          | Unrelated Doku-Status-Update im selben Diff gebündelt |

### F01 — F4-Pflicht „Tap auf Cluster zoomt hinein" nicht implementiert
- **File**: `ShipTrip/Views/Map/MapView+RouteInteraction.swift:54-58` (Button-Action, gemeinsam für Cluster und Einzel-Badge) und `:111-128` (`clusteredBadge(...)`)
- **Severity**: major
- **Category**: correctness — Design-Spec F4, Akzeptanzkriterium (als „Pflicht, nicht optional" markiert)
- **Problem**: Der Button, der `markerContent(for:routeIndex:)` als Label nutzt, hat exakt eine
  Action — unabhängig davon, ob `markerContent` einen normalen Badge oder (via
  `clusteredBadge`) einen Cluster-Badge+„+N"-Pill rendert:
  ```swift
  Button {
      selectedStopID = MapSelectionPlanner.toggled(current: selectedStopID, tapped: role.port.id)
      primaryCruiseID = cruise.id
      isSheetPresented = true
      sheetDetent = .height(140)
  } label: {
      markerContent(for: role, routeIndex: index)
  }
  ```
  Laut Design-Spec (F4, „Ein Tap-Target pro Cluster") soll ein Tap auf den kombinierten
  Badge+Pill-Bereich stattdessen `zoomTo(coordinate:)`/`MKCoordinateRegion(coordinates:)` über
  die geclusterten Stops auslösen, damit sich der Cluster selbstständig auflöst — „kein
  separater Callout im geclusterten Zustand". Im aktuellen Code passiert genau das Gegenteil:
  Tap auf einen Cluster wählt den Primary-Stop aus, zeigt dessen individuellen `MapCalloutView`
  und öffnet das Sheet — wie ein normaler Einzel-Badge-Tap. Kein Codepfad ruft für den
  Cluster-Fall `zoomTo(coordinate:)` auf.
  Kein Dead-End (die vollständige, ungeclusterte Stop-Liste bleibt über
  `RouteStopSheetView` erreichbar, dessen `onStopTap` weiterhin `zoomTo(coordinate:)` pro Stop
  aufruft), aber das im Spec beschriebene Kern-Verhalten von F4 — „selbstauflösend, keine
  Sackgasse, keine neue Disambiguierungs-UI nötig" direkt auf der Karte — fehlt vollständig.
- **Fix**: In der Button-Action zwischen Cluster- und Einzel-Fall unterscheiden, z. B.:
  ```swift
  Button {
      if let count = clusterMemberCounts[role.port.id], count > 1 {
          zoomTo(coordinate: role.port.coordinate) // oder Bounding-Region über die Cluster-Mitglieder
      } else {
          selectedStopID = MapSelectionPlanner.toggled(current: selectedStopID, tapped: role.port.id)
          primaryCruiseID = cruise.id
          isSheetPresented = true
          sheetDetent = .height(140)
      }
  }
  ```
  Für ein präziseres Zoom-Ziel könnten die tatsächlichen Koordinaten aller Cluster-Mitglieder
  (nicht nur die des Primary) über `MKCoordinateRegion(coordinates:)` gefittet werden, statt nur
  auf den Primary-Stop zu zoomen.

### F02 — Rollen-Pin-Marker fehlt `.accessibilityHidden(true)` — Doppel-Announcement-Risiko
- **File**: `ShipTrip/Views/Map/MapView+RouteInteraction.swift:167-178` (`markerView(for:isSelected:)`)
- **Severity**: major
- **Category**: accessibility — Design-Spec F4 „Konsolidiertes VoiceOver-Label", AC „Kein doppeltes VoiceOver-Announcement"
- **Problem**: `MapStopBadgeView` und `worldDotView` wurden in diesem Diff konsequent mit
  `.accessibilityHidden(true)` versehen, damit das neue, konsolidierte Button-Label
  (`stopAccessibilityLabel(for:totalStops:)`) die einzige Ansage bleibt. `markerView(for:
  isSelected:)` — genutzt für Heimathafen-/Endhafen-Marker via `PortPinView` — bekam dieses
  Hidden-Flag nicht. `PortPinView` selbst setzt aber bereits eine eigene
  `.accessibilityLabel` pro Rolle (`"Heimathafen"`, `"Endhafen"`, siehe
  `ShipTrip/Views/Map/PortPinView.swift:52-58`). Damit trägt der äußere Button jetzt
  `"Heimathafen, Hamburg, Deutschland"`, während der innere `PortPinView`-`Image` weiterhin als
  eigenständiges, potenziell separat fokussierbares Accessibility-Element `"Heimathafen"`
  beisteuert — das genau die Art von Doppel-Announcement, die die F4-Spec explizit beheben
  wollte, bleibt für diese beiden Rollen bestehen.
- **Fix**: `.accessibilityHidden(true)` auch an `markerView(for:isSelected:)` ergänzen, analog zu
  `worldDotView`/`MapStopBadgeView`:
  ```swift
  func markerView(for role: MapPortRole, isSelected: Bool) -> some View {
      PortPinView(type: role.type)
          .padding(6)
          .background(Circle().fill(Color.journalSurface))
          .overlay(Circle().strokeBorder(Color.oceanBlue, lineWidth: isSelected ? 3 : 0))
          .shadow(color: .black.opacity(0.18), radius: 8, y: 4)
          .contentShape(Circle().inset(by: -6))
          .accessibilityHidden(true)
  }
  ```

### F03 — Pflicht-Checks (Kontrast, Tap-Target-Geometrie) laut Spec noch nicht gerätesverifiziert
- **File**: `RouteStopSheetView.swift:171-177` (`pinPlaceholderFill`/`pinPlaceholderBorder`), `MapView+RouteInteraction.swift:172-176` (Rollen-Pin-Inset), `MapView+RouteInteraction.swift:111-126` (Cluster-Pill-`contentShape`)
- **Severity**: major
- **Category**: tests / accessibility — Design-Spec „Offene Punkte" + „Accessibility (Zusammenfassung)"
- **Problem**: Der Developer hat drei Stellen im eigenen Code explizit als „vor Merge mit
  Accessibility Inspector verifizieren" / „nicht exakt im Simulator vermessen" markiert:
  1. `pinPlaceholderBorder` (0.55 Light / 0.40 Dark) — nur handgerechnet gegen die
     sRGB-Relativluminanz-Formel, keine echte Messung.
  2. Rollen-Pin-Inset (`Circle().inset(by: -6)`) — die zugrunde liegende reale Pin-Größe
     („~36×32pt") wurde laut eigenem Kommentar nicht im Simulator vermessen.
  3. Cluster-Pill-`contentShape` (`Rectangle().inset(by: -16)`) — „grobzügig bemessen",
     ebenfalls nicht verifiziert. Eigene Nachrechnung in diesem Review zeigt ein plausibles
     Risiko: die `contentShape`-Rectangle wird symmetrisch um den 22×22pt-Badge-Frame gelegt
     (±16pt → 54×54pt zentriert auf den Badge-Mittelpunkt), während der „+N"-Pill per
     `.offset(x: 14, y: -10)` asymmetrisch nach oben-rechts aus dem Badge herausragt — die
     äußerste Kante des Pills kann dadurch knapp außerhalb der definierten Tap-Fläche liegen.
     Ohne Messung im Simulator/Accessibility Inspector nicht abschließend zu verifizieren.
  Das Design-Spec selbst erklärt diese drei Punkte als „Pflicht-Check", nicht optional
  („Offene Punkte/Risiken" + „Accessibility (Zusammenfassung): ... vor Merge mit Accessibility
  Inspector in Light UND Dark verifiziert, nicht nur behauptet"). Als Reviewer ohne
  Build/Simulator-Zugriff kann ich das nicht nachholen — dieser Punkt ist daher weder
  „erfüllt" noch „nicht erfüllt", sondern **nicht prüfbar ohne Lauf**, muss aber laut Spec vor
  Merge nachgeholt werden.
- **Fix**: Vor Merge im Simulator/Accessibility Inspector verifizieren: (a) Kontrast
  Pin-Platzhalter-Rand in Light+Dark ≥3:1, (b) reale `PortPinView`-Größe messen und Inset ggf.
  nachjustieren, (c) Cluster-Pill-Tap-Fläche mit Debug-Overlay/Accessibility Inspector auf
  vollständige Abdeckung des „+N"-Pills prüfen, ggf. `contentShape` asymmetrisch statt
  symmetrisch um den Badge legen (z. B. via `.alignmentGuide` oder eine eigene `Path`, die den
  tatsächlichen kombinierten Bounding-Box abbildet statt eines uniformen Insets).

### F04 — `UIScreen.main.bounds.height` ist deprecated/scene-blind
- **File**: `ShipTrip/Views/Map/MapView.swift:284-286`
- **Severity**: minor
- **Category**: code-quality
- **Problem**: `routeMenuPanelMaxHeight` nutzt `UIScreen.main.bounds.height`. `UIScreen.main`
  ist auf neueren SDKs als deprecated markiert (Szenen-basierte API bevorzugt) und liefert auf
  Multi-Window/Multi-Scene-Konfigurationen ggf. nicht die tatsächliche Fenstergröße. Kein
  Bestandsmuster im Rest des Repos (neu eingeführt durch diesen Diff) — für eine reine
  iPhone-App aktuell funktional unkritisch, aber neue technische Schuld.
- **Fix**: Optional auf einen szenenbasierten Ansatz umstellen (z. B. `GeometryReader` im
  Popover-Content oder `@Environment(\.displayScale)`-freien Weg über die aktive
  `UIWindowScene`), muss aber kein Merge-Blocker sein.

### F05 — Unrelated Doku-Status-Update im selben Diff gebündelt
- **File**: `docs/umsetzungsplan-audit-2026-07.md`
- **Severity**: minor
- **Category**: scope
- **Problem**: Der Diff enthält eine Statusaktualisierung für B7.3 (TestFlight 1.6.3), die mit
  Welle C (Karten-Feedback Build 16) inhaltlich nichts zu tun hat. Kein funktionales Risiko,
  aber verletzt „Surgical Changes"/kleinstmöglicher Diff pro Feature.
- **Fix**: Falls noch nicht committed, in einen separaten Commit auslagern.

## Akzeptanzkriterien-Matrix

### F2 — Burger-Menü
| Kriterium | Status |
|---|---|
| Popover ≤ `min(0.45×H, 380pt)`, iPhone SE/Mini | erfüllt (Code), **nicht geräteverifiziert** |
| Panel opak, kein Durchscheinen | erfüllt |
| Kein mehrzeiliger Titel | erfüllt |
| Auswahl-Icon Kreis in beiden Zuständen | erfüllt |
| 3× Einzel-Toggle schließt Panel nicht | erfüllt (Code-Logik korrekt, kein dediziertes Automatisierungstest für 3×) |
| VoiceOver „Route, {Titel}, {Status}" | erfüllt |

### F3 — Routen-Sheet
| Kriterium | Status |
|---|---|
| Drag resized Sheet bis `.large` | erfüllt (System-Contract), **nicht geräteverifiziert** |
| Ab `.large` scrollt Liste normal | erfüllt (System-Contract), **nicht geräteverifiziert** |
| Badge-Gradient Light+Dark | erfüllt |
| Chip statt Full-Bleed | erfüllt |
| Pin-Platzhalter ≥3:1 Kontrast | **nicht erfüllt/nicht verifiziert** (F03) |
| Kein Akzent-Konflikt mit System-Grabber | erfüllt |

### F4 — Mittlerer Zoom
| Kriterium | Status |
|---|---|
| Span 10–20° zeigt Reise-Zoom (Kanaren-Fall) | erfüllt + unit-tested |
| Norwegen hohe Breite kein vorzeitiger Welt-Zoom | erfüllt + unit-tested |
| Alle 4 Marker-Varianten ≥44×44pt | Welt-Dot/Route-Badge erfüllt (exakte Geometrie), Rollen-Pin/Cluster-Pill **nicht verifiziert** (F03) |
| 2 nahe Stops → 1 Badge + „+1"-Pill | erfüllt + unit-tested (`MapClusterPlannerTests`) |
| Nicht-konsekutive Stop-Nummern clustern trotzdem | erfüllt + unit-tested |
| Tap auf Cluster zoomt hinein und löst ihn auf | **nicht erfüllt** (F01) |
| VoiceOver liest Nummer+Name+Land in jedem Bucket | erfüllt |
| Kein doppeltes VoiceOver-Announcement | **teilweise erfüllt** (Badge/Dot ja, Rollen-Pin nein — F02) |

## GDPR / OWASP

Nicht anwendbar — reine UI-/Kartenlogik ohne neue Netzwerk-Calls, Persistenz-Änderungen oder
PII-Verarbeitung. Keine neuen Datenflüsse gegenüber dem bestehenden `Port`/`Cruise`-Modell.

## Test-Run-Status

Von mir nicht selbst ausgeführt (read-only, kein Build/Simulator — läuft laut Auftrag parallel
beim Orchestrator). Neue/geänderte Unit-Tests decken die reinen Planner ab:
- `MapClusterPlannerTests.swift` — 7 Tests (Single-Point, weit entfernt, Kollision, Reihenfolge-
  Unabhängigkeit, Rundreise-/Kreuzungsfall, transitive Kette, Exakt-an-Schwelle).
- `MapZoomAndSelectionTests.swift` (erweitert) — 7 `MapZoomBucketPlanner`-Tests inkl. Kanaren-
  Regression und Norwegen-Latitude-Korrektur, plus bestehende `MapSelectionPlanner`-Tests
  unverändert.
- `MapCameraFitTests.swift` — 3 Tests für `MKCoordinateRegion(coordinates:)` (F1-Regression).
- `MapAlleRoutenUITests.swift` — 1 UI-Test für F1 (Menü-Dismiss nach Alle-ausblenden/-anzeigen).

Keine automatisierten Tests für F01 (Cluster-Tap-Zoom, weil nicht implementiert) oder die in
F03 genannten manuellen Verifikationen — erwartbar, da es sich um visuelle/Geometrie-Checks
handelt, die primär im Simulator/Device zu prüfen sind.

## Go/No-Go

**NO-GO.** Kein Sicherheits-/Datenverlust-Risiko, aber ein als „Pflicht" markiertes
F4-Akzeptanzkriterium (Cluster-Tap-Zoom) ist schlicht nicht implementiert, dazu eine
Accessibility-Inkonsistenz (F02) und mehrere vom Spec selbst geforderte Pre-Merge-
Verifikationen, die noch aussstehen (F03). Die drei wichtigsten Fixes für die nächste
Developer-Iteration:

1. **F01** — Cluster-Tap-Action auf `zoomTo(coordinate:)`/Region-Fit umstellen statt
   Callout+Sheet (`MapView+RouteInteraction.swift:54-58`).
2. **F02** — `.accessibilityHidden(true)` an `markerView(for:isSelected:)` ergänzen
   (`MapView+RouteInteraction.swift:167-178`).
3. **F03** — Kontrast- und Tap-Target-Pflicht-Checks im Simulator/Accessibility Inspector
   nachholen (Pin-Platzhalter-Rand Light+Dark, Rollen-Pin- und Cluster-Pill-Geometrie).
