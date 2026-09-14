# Quality Review — Welle B6 + B4.3a (Iteration 1)

**Scope:** ungestagter Diff auf `main` — B6.1 (Ausflug-Lösch-Button + Save-Disabled-Bugfix
in `PortFormView.swift`), B6.3 (Settings-Footer-Hinweise), B4.3a (`MapMarkerPlanner` +
`PortPinView`-Rollensystem in `MapView.swift`). Reviewer hat keine Tests selbst
ausgeführt; Testlauf-Logs (164/164 Unit, 21/21 UI, beide `** TEST SUCCEEDED **`) wurden
gelesen und stichprobenartig gegen den Code verifiziert.

## Verdikt: **GO**

Beide Kernfixes sind echte Bugs mit korrekten, minimalinvasiven Fixes und passender
Testabdeckung (Unit *und* UI, End-to-End über den tatsächlichen Button-Zustand, nicht nur
Modell-Ebene). Ein Punkt (Marker-Farbverlust auf der Alle-Reisen-Karte) ist ein bewusst in
Kauf genommener Trade-off mit bereits eingeplantem Follow-up (B4.3b) — kein Blocker, aber
mit Priorisierungsempfehlung unten.

## Findings

### Major

1. **Marker-Farbverlust + Pin-Überlappung auf der „Alle Reisen"-Karte (MapView.swift:99,
   173-183)** — Vorher wurden bei `displayedRoutes.count > 1` nur Start/Ende pro Route
   gezeigt (`markerPorts()`-Kappung), Zwischenstopps entfielen; die gezeigten Marker
   benutzten aber `Color.routeColor(at: index)` fürs jeweilige Regel-Pin. Jetzt zeigt
   `MapMarkerPlanner.markerRoles` **alle** Zwischenstopps aller Routen gleichzeitig, aber
   jeder normale Stopp bekommt dieselbe feste Farbe (`Color.portPin` = oceanBlue) unabhängig
   von der Route. Verifiziert per Screenshot (`audit/screenshots/weltkarte-all-{light,dark}.png`):
   auf der „Alle Reisen"-Karte stapeln sich mehrere gleichfarbige blaue Pins sichtbar
   übereinander (z. B. rechter Rand, Cluster bei Palma), ohne dass erkennbar ist, welcher
   Pin zu welcher Reise gehört. Das ist der im Auftrag genannte Trade-off.
   **Einschätzung:** vertretbar als Zwischenschritt — B4.3a ist explizit als kleiner
   Konsistenz-Fix vor B4.3b („Mutige Richtung", laut `docs/umsetzungsplan-audit-2026-07.md`
   bereits mit Bottom-Sheet/Zwei-Stufen-Zoom/Wegpunkt-Badges als Lösung für genau dieses
   Problem geplant) deklariert, und Task #13 existiert bereits dafür. Kein Merge-Blocker,
   aber Empfehlung: B4.3b im nächsten Sprint priorisieren statt zu verschieben, da der
   Zustand in der Zwischenzeit live auf TestFlight sichtbar ist (Default-Ansicht beim
   Öffnen des Karte-Tabs ohne Auswahl zeigt „Alle Reisen").

### Minor

2. ~~`docs/umsetzungsplan-audit-2026-07.md`: B6.1/B6.3/B4.3a-Checkboxen noch `[ ]`~~ —
   **erledigt.** Zum Zeitpunkt dieses Reviews noch offen, inzwischen auf `[x]` gesetzt
   (verifiziert: Zeilen 170, 194, 204 zeigen `[x] ... ✅ 2026-07-04`).
3. **Neue user-sichtbare Strings fehlen im `Localizable.xcstrings`** (z. B. „Ausflug
   entfernen", die drei neuen Footer-Texte). Das ist aber ein bereits vor diesem Diff
   bestehendes Verhalten des Projekts — auch länger vorhandene Strings wie „Alle Reisen
   anzeigen" (MapView, unverändert) fehlen im Katalog; Sync passiert offenbar nur beim
   Öffnen/Bauen in der Xcode-IDE, nicht über CLI-`xcodebuild test`. Keine Regression dieses
   Diffs, nur zur Kenntnisnahme.
4. **`PortFormView.swift:216`-Kommentar ist lang** (7 Zeilen Begründung für eine
   Ein-Zeilen-Änderung) — inhaltlich korrekt und hilfreich für die Nachvollziehbarkeit des
   Bugs, aber an der Grenze zum Aufblähen. Kein Fix nötig, nur Stilhinweis.

## Positiv hervorzuheben

- **B6.1-Fix ist ein echter, gut belegter Bug:** `country`-Feld ist nur sichtbar, solange
  `name.isEmpty` (`PortFormView.swift:119`); ein bestehender Port mit leerem Land (möglich,
  da `TempPortFormSheet` nie ein Land erzwungen hat, `CruiseFormView.swift:1138`
  `.disabled(name.isEmpty)`) konnte über `PortFormView` (`loadExistingData()`,
  `PortFormView.swift:257-258`) nie wieder gespeichert werden — auch keine anderen Edits
  (Ausflug löschen, Datum ändern etc.), weil der Speichern-Button dauerhaft disabled blieb.
  Der Fix (`.disabled(name.isEmpty)`) ist korrekt und minimal.
- **Kein Wildwuchs bei der Land-Pflicht:** `MapView.swift:188` und `StatsView.swift:240`
  filtern leere Länder bereits konsequent heraus (`.filter { !$0.isEmpty }`),
  `ExportImportService.swift:184/366` behandelt `country: nil`/`""` bereits robust. Kein
  Ort im Code verlangt einen nicht-leeren Country-String zwingend.
- **Testabdeckung trifft den echten Bug, nicht nur das Modell:** Der UI-Test
  `AusflugLoeschenUITests.testAusflugLoeschenUeberSichtbareSchaltflaeche` legt den Hafen
  bewusst *ohne* Land über `TempPortFormSheet` an, öffnet danach echt über
  `CruiseDetailView` → `PortFormView` (den Pfad mit dem vormals kaputten Save-Button) und
  verifiziert den kompletten Save-Roundtrip über echte Button-Taps — das hätte den
  Original-Bug tatsächlich rot gemacht. Ergänzt durch die Unit-Test-Suite „Ausflug entfernen
  (B6.1)" (Index- vs. String-basiertes Löschen, beide Datenpfade PortFormView/reconcileRoute,
  je mit „letzter Ausflug entfernt → leere Liste"-Fall).
- **B4.3a-Tests (`MapMarkerPlannerTests.swift`, 14 Tests):** decken Normalfall,
  Rundreise exakt/knapp-unter/knapp-über Toleranz, unterschiedliche nahe Häfen, Ein-Port-Route,
  leere Route, Seetage, (0,0)-Koordinaten, Out-of-Range- und NaN/Infinity-Koordinaten sowie
  Sortierung ab — solide und liest sich wie eine echte Grenzwertanalyse, nicht nur
  Show-Tests.
- **Surgical Changes eingehalten:** `git diff --stat` zeigt ausschließlich Dateien im
  Scope von B6.1/B6.3/B4.3a plus Screenshot-Regenerierung, Doku-Update und die neuen
  Testdateien — keine Nebenbaustellen. `PortPinView.swift` selbst unverändert, wie im
  Auftrag vermerkt.
- **Keine neuen Force-Unwraps/`try!`/`as!`** im Diff gefunden.
- **Rollen-Semantik-Unterschied MapView vs. CruiseDetailView bei Rundreisen ist bewusst
  und sinnvoll:** `CruiseDetailView` zeigt bei einer Rundreise weiterhin zwei getrennte
  Routen-Zeilen (Start als Heimathafen, derselbe Hafen am Ende als Endhafen) — das ist dort
  richtig, weil es eine chronologische Tagebuch-Liste ist, kein überlappendes Karten-Pin.
  `MapMarkerPlanner` kombiniert nur auf der Karte, wo zwei exakt übereinanderliegende Pins
  tatsächlich ein Darstellungsproblem wären. Kein Inkonsistenz-Bug, unterschiedliche
  Kontexte rechtfertigen unterschiedliches Verhalten.

## GDPR-Check

Nicht einschlägig — keine neuen personenbezogenen Daten, keine neuen Speicher-/
Übertragungspfade. Bestehende Port-Daten (Name/Land/Ausflüge) werden nur anders angezeigt/
gelöscht, keine neue Datenkategorie.

## OWASP-Security-Check

Nicht einschlägig — reiner UI-/Client-Code ohne Netzwerk, ohne Eingabe-Sanitisierung-relevante
neue Angriffsfläche, keine neuen Dependencies. `MapMarkerPlanner` ist reine, seiteneffektfreie
Berechnung auf bereits validierten Modell-Properties.

## Test-Run-Status (vom Orchestrator geliefert, hier verifiziert gelesen)

- Unit: 164/164 grün (`unit-test-final-b6.log`, `** TEST SUCCEEDED **`)
- UI: 21/21 grün (`ui-test-final2-b6.log`, `** TEST SUCCEEDED **`)
- Keine Coverage-Zahl in den Logs enthalten (kein `-enableCodeCoverage`-Report im Log
  sichtbar) — falls eine Prozentzahl fürs Gate benötigt wird, müsste sie separat aus dem
  `.xcresult` gezogen werden.

## Go/No-Go

**GO.** Kein Critical, ein Major (bekannter, bereits eingeplanter Trade-off, kein Blocker),
zwei Minor verbleibend (String-Catalog-Sync, langer Kommentar — beide vorbestehend/
kosmetisch); der dritte Minor-Punkt (Plan-Checkboxen) ist seit diesem Review erledigt.
