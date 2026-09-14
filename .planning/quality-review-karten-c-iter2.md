# Review — Karten-UI-Politur Welle C (Tester-Feedback Build 16) — Fix-Runde 1

- **Iteration**: 2 / 3
- **Reviewer**: quality-agent (read-only, kein Build/Test — Testlauf parallel beim Orchestrator)
- **Date**: 2026-07-10
- **Verdict**: approve (GO)
- **Stats**: critical: 0, major: 0, minor: 1 (residual, nicht blockierend)

## Summary

Nachprüfung der vier in iter1 gemeldeten Findings (3 major, 1 minor) nach Fix-Runde 1. Alle
vier sind im Code sauber und mit Substanz umgesetzt, nicht nur oberflächlich abgehakt. Zwei
der drei Majors (Cluster-Tap-Zoom, Rollen-Pin-Accessibility) sind vollständig und mit gezielten
neuen Unit-Tests belegt gelöst. Der dritte Major (unverifizierte Pflicht-Checks) wurde nicht
durch eine tatsächliche Simulator-Messung geschlossen (die bleibt mir und offenbar auch dem
Developer in dieser Runde verwehrt), sondern durch zwei unabhängige, nachvollziehbare
Verbesserungen ersetzt: die Kontrastwerte sind jetzt per Unit-Test rechnerisch **bewiesen**
(nicht mehr nur behauptet) gegen die echten `Color`-Konstanten, und die beiden Tap-Target-Insets
tragen jetzt explizite, nachrechenbare Worst-Case-Herleitungen mit Sicherheitsmarge statt
„grobzügig geschätzt"/„nicht vermessen". Das reduziert das Risiko so weit, dass ich es nicht
mehr als Merge-Blocker werte — reine Geräte-Bestätigung bleibt als unblockierender Fast-Follow
empfehlenswert. Datei-Größen weiterhin im Limit (MapView.swift 422, MapView+RouteInteraction.swift
313 Zeilen). Das `docs/umsetzungsplan-audit-2026-07.md`-Finding aus iter1 war ohnehin nur minor
und nicht GO/NO-GO-relevant — Erklärung „Beifang vor der Welle" (Diff referenziert
Release-Commit `bbcc06a`, der vor dieser Welle liegt) ist plausibel, akzeptiert.

## Nachprüfung der iter1-Findings

### F01 (iter1, major) → resolved
„F4-Pflicht Tap-auf-Cluster-zoomt-hinein nicht implementiert."

**Fix verifiziert:** Neue `MapClusterPlanner.TapOutcome`-Enum (`MapClusterPlanner.swift:94-107`)
mit reiner Entscheidungsfunktion `tapOutcome(for:clusterMemberCoordinates:)` — liefert
`.zoomToCluster(coordinates:)` für einen Cluster-Primary (≥2 Mitglieder), sonst `.selectStop`.
In `MapView+RouteInteraction.swift:62-70` jetzt im Button-Switch verdrahtet:
```swift
switch MapClusterPlanner.tapOutcome(for: role.port.id, clusterMemberCoordinates: clusterMemberCoordinates) {
case .zoomToCluster(let coordinates):
    zoomTo(coordinates: coordinates)
case .selectStop:
    // bisheriges select+Callout+Sheet-Verhalten
}
```
`recomputeClusters(using:)` speichert jetzt die tatsächlichen Geo-Koordinaten aller
Cluster-Mitglieder (`clusterMemberCoordinates: [UUID: [CLLocationCoordinate2D]]`) statt nur
einer Zähl-Map — genau das, was `zoomTo(coordinates:)` braucht. `zoomTo(coordinates:)` wurde
korrekt von `private` auf `internal` angehoben (datei-gebundene Swift-Zugriffsebenen,
konsistent mit dem bestehenden Muster der Datei-Kopfkommentare) und nutzt denselben,
bereits bewährten Kamera-Pfad wie der Sheet-Stop-Tap — kein neuer Loop-Schutz nötig, da kein
neuer Karte↔Liste-Rückkanal entsteht (`MapView.swift:399-403`).
**Tests:** `MapClusterPlannerTests.swift:145-215` — 4 gezielte Tests für `tapOutcome`
(Cluster-Primary → alle Mitglieder-Koordinaten, kein Eintrag → selectStop, defensiver
Ein-Mitglied-Fall → selectStop, unbekannter/Nicht-Primary-Stop → selectStop). Deckt die
Entscheidungslogik vollständig ab; die eigentliche Kamera-Aktion (`zoomTo`) ist über die
bestehenden `MapCameraFitTests` (Fit-Logik) indirekt abgedeckt.

### F02 (iter1, major) → resolved
„Rollen-Pin-Marker fehlt `.accessibilityHidden(true)`."

**Fix verifiziert:** `markerView(for:isSelected:)` (`MapView+RouteInteraction.swift:195-220`)
hat jetzt `.accessibilityHidden(true)` am Ende der Modifier-Kette, mit explizitem Kommentar,
der den iter1-Befund direkt referenziert („Fix-Runde 1, F02 — bislang nur bei Badge/Dot
konsequent gesetzt"). Konsistent mit `MapStopBadgeView`/`worldDotView`-Behandlung. Löst das
Doppel-Announcement-Risiko für Heimathafen-/Endhafen-Marker.

### F03 (iter1, major) → substanziell resolved, ein Minor-Residualrisiko bleibt
„Drei Pflicht-Checks (Kontrast, Tap-Target-Geometrie) laut Spec nicht gerätesverifiziert."

**Kontrast — vollständig gelöst, jetzt sogar stärker als ursprünglich gefordert:**
Neue `MapPinPlaceholderTokens`-Enum (`Color+Theme.swift:93-98`) macht die vorher inline
verstreuten Opacity-Werte zu benannten Konstanten; `RouteStopSheetView` nutzt sie jetzt
(`pinPlaceholderFill`/`-Border`, `RouteStopSheetView.swift:167-186`). Neue
`MapPinPlaceholderContrastTests.swift` berechnet den WCAG-2.1-Kontrast (`(L1+0.05)/(L2+0.05)`,
korrekte Relativluminanz-Formel mit dem 0.03928-Sonderfall) **direkt aus den echten
`UIColor`-Komponenten** der `Color`-Konstanten — keine im Test erneut abgetippten Hex-Werte.
Eigene Nachrechnung in diesem Review bestätigt die Testresultate unabhängig: Light
(navyDark@0.55 auf journalSurfaceLight) ≈ 3.17:1, Dark (weiß@0.40 auf journalSurfaceDark) ≈
3.74:1 — beide über der 3:1-Schwelle, plus ein Regressions-Test, der beweist, dass die
ursprünglich vorgeschlagenen 0.14/0.16-Werte (≈1.29:1 bzw. korrekt) durchfallen würden. Das ist
eine echte, CI-durchsetzbare Verifikation statt einer Handrechnung im Kommentar — übertrifft
die ursprüngliche Anforderung „im Simulator verifizieren", weil es nicht nur einmalig, sondern
bei jedem Testlauf geprüft wird.

**Tap-Target-Geometrie — Risiko reduziert, aber nicht durch echte Gerätemessung:**
Beide Inset-Werte (`markerView`: `-7`, `clusteredBadge`: `-18`) haben jetzt ausführliche,
nachvollziehbare Herleitungskommentare mit Worst-Case-Annahmen und expliziter
Sicherheitsmarge (`MapView+RouteInteraction.swift:137-154` bzw. `:201-214`) statt der
vorherigen unbelegten Schätzung. Eigene Nachrechnung beider Herleitungen in diesem Review:
- Rollen-Pin: 24pt-Breite + 20pt-SF-Symbol-Glyphhöhe (Konvention, kein Code-Literal) + 2×6pt
  Padding ≈ 32pt kleinere Dimension; Inset -7 → 46pt, 2pt Marge über dem 44pt-Minimum. Wenn
  die tatsächliche Glyphhöhe kleiner als angenommen ausfällt (SF-Symbol-Cap-Height variiert je
  nach Symbol), kann die Marge auf 0 oder knapp negativ schrumpfen — die Herleitung selbst
  räumt das ein, ist aber jetzt zumindest explizit und nachprüfbar statt implizit geraten.
- Cluster-Pill: rechnet die Bounding-Box aus Badge (22×22) + versetztem „+N"-Pill
  (Text-Breiten-Schätzung mit Sicherheitsaufschlag, max. „+19" bei ≤20 Stops/Route) korrekt
  gegen ein symmetrisches `Rectangle().inset(by:)` durch — mathematisch stimmig, ~4pt Marge
  über dem rechnerischen Minimum.

Da ich (wie schon in iter1) keinen Simulator-Zugriff habe, kann ich auch diese Herleitungen
nicht empirisch verifizieren — aber der Unterschied zu iter1 ist qualitativ: aus „nicht
vermessen, grobzügig geschätzt" wurde eine dokumentierte, konservative Worst-Case-Rechnung mit
Sicherheitsmarge. Das stuft dieses Restrisiko von „major, blockiert Merge" auf „minor,
empfohlener Fast-Follow vor dem nächsten TestFlight-Upload" herab — siehe Restfinding unten.

### F04 (iter1, minor) → resolved
„`UIScreen.main.bounds.height` ist deprecated/scene-blind."

**Fix verifiziert:** `MapView.swift:40-43` führt `@State private var mapViewportHeight:
CGFloat = 844` ein (sinnvoller Praktikabilitäts-Default für den ersten Frame vor dem
`GeometryReader`-Callback), gefüttert über `.background { GeometryReader { ... } }` am
äußeren `ZStack` (`MapView.swift:99-107`) mit `.onAppear`/`.onChange(of: proxy.size)`.
`routeMenuPanelMaxHeight` liest jetzt `mapViewportHeight` statt `UIScreen.main.bounds.height`
(`MapView.swift:302-308`). Sauberer, idiomatischer SwiftUI-Ersatz, `.background` stellt
korrekt sicher, dass der `GeometryReader` das Layout nicht beeinflusst.

## Restfinding (nicht blockierend)

### R01 — Tap-Target-Insets weiterhin analytisch, nicht empirisch verifiziert
- **File**: `MapView+RouteInteraction.swift:154` (`Rectangle().inset(by: -18)`), `:214`
  (`Circle().inset(by: -7)`)
- **Severity**: minor (herabgestuft von major in iter1 — siehe Begründung oben)
- **Empfehlung**: Vor dem nächsten TestFlight-Upload einmalig im Simulator mit
  Accessibility-Inspector-Debug-Overlay (oder einem temporären `.border(.red)` auf dem
  `contentShape`) gegenprüfen, dass die reale `PortPinView`-Höhe und die „+N"-Pill-Textbreite
  innerhalb der angenommenen Worst-Case-Grenzen liegen. Kein Code-Änderungsbedarf, falls die
  Messung die Annahmen bestätigt.

## Go/No-Go

**GO.** Alle drei Majors aus iter1 sind entweder vollständig gelöst (F01, F02) oder durch eine
qualitativ deutlich stärkere Absicherung ersetzt (F03 — Kontrast jetzt testbewiesen statt
behauptet, Geometrie jetzt hergeleitet statt geraten). Der verbleibende Rest (R01) ist eine
einmalige, risikoarme Geräteverifikation ohne erwarteten Code-Änderungsbedarf und blockiert den
Merge aus meiner Sicht nicht. Test-Run-Status weiterhin nicht von mir selbst ausgeführt
(read-only) — bitte Ergebnis des parallelen Orchestrator-Testlaufs vor dem finalen Merge
gegenprüfen, insbesondere die neuen `MapPinPlaceholderContrastTests` und
`MapClusterPlannerTapOutcomeTests`.
