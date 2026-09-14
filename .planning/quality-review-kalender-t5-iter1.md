# Review — T5 Kalender-Einstellungen: zwei Schalter statt Picker

- **Iteration**: 1 / 3 · **Reviewer**: quality-agent (frischer Spawn)
- **Datum**: 2026-09-02 · **Branch**: `kp/t5` @ `c33d9df` (Diff `aec5263..c33d9df`)
- **Geladene Skills**: code-review, swiftui, xctest-ios
- **Verdikt**: approve (Go-mit-Backlog)
- **Stats**: critical 0, major 4, minor 6 — Blocker 0, Backlog 10
- **evidence_path**: `.winston-evidence/20260902T144947Z/gate-run.json` (build/tests/uitest je exit 0; Unit „Test run with 576 tests in 122 suites passed", UI 1/1; log-sha256 stimmen)

## Summary
T5 setzt die Leitentscheidung um: `CalendarSyncPreferences.mode(in:)` bleibt der
einzige Default-Ort (`.itineraryOnly`), die View liest ihn nur noch ab. Die zwei
Schalter bilden die vier Modi bijektiv ab, ein Tap = genau ein Write. Beide
W1-Findings sind geschlossen. Kein Befund blockiert den Go-Live; die vier
`major` betreffen Anzeige-Timing vor der Bestands-Migration und die Härte des
neuen UI-Tests.

## Antworten auf die Prüffragen

1. **W1-F01 / W1-F02 erledigt?** Beide ja. F01: `modeRawValue` hat jetzt Default
   `""` (`CalendarSyncSettingsView.swift:45`) und dient nur als Auslöser; der
   wirksame Umfang kommt aus `CalendarSyncPreferences.mode`
   (`:77-79`) — ein Leseort, neuer Default. F02: Picker ersetzt, „Keine
   Einträge" ist kein wählbarer Listeneintrag mehr, sondern der erklärende
   Hinweis bei `mode == .none` (`:162-166`).
2. **Abbildung vollständig/umkehrbar?** Ja, Bijektion über alle vier Fälle:
   `apply(itinerary:trip:)` (`:96-105`) deckt (t,t)/(t,f)/(f,t)/(f,f) ab,
   `includesTrip`/`includesItinerary` (`CalendarEventPlanner.swift:23-36`)
   bilden jeden Modus verlustfrei zurück. **Kein Zwischen-Modus**: Beide Setter
   lesen den jeweils *anderen* Schalter aus dem noch ungeänderten `mode` und
   schreiben genau ein `defaults.set` (`:103`). Der Compiler-Switch ist
   exhaustive, ein fünfter Case bräche den Build statt still zu defaulten.
3. **Bedienbar bei Sync aus — löst das Sync/Dialog aus?** Nein. `apply` ruft
   `synchronizeIfEnabled()`, das an `guard isEnabled` scheitert (`:329`); der
   `CalendarSyncObserver` reagiert zwar auf `modeRawValue` (`:25,33`), hat aber
   dieselbe Wache. Es entsteht kein Zugriffsdialog und keine Migration. UX-seitig
   vertretbar (Umfang vorkonfigurieren, bevor man einschaltet), mit zwei Notizen:
   F02 (falsche Basis vor der Bestands-Migration) und F07 (Zielkalender-Picker
   direkt darüber bleibt bei Sync-aus deaktiviert — inkonsistente Affordanz).
4. **Migration zu früh / falsch gesettelt?** Nein. Der Aufruf steht **hinter**
   dem `guard authorizationStatus == .fullAccess` (`:266-275`), `run(...)`
   bekommt also nie `hasCalendarAccess: false`; ohne Zugriff bleibt der Merker
   aus und der nächste Lauf holt es nach. Aber: sie läuft im `.task`, also
   *nach* dem ersten Body — der Kommentar „muss entschieden haben, bevor die
   Schalter einen Umfang zeigen" ist falsch (F01).
5. **Strings?** Sauber. Alle vier neuen Keys mit DE+EN im Katalog. Entfernte
   Keys (`Nur Reisen`, `Reisen, Häfen & Seetage`, `Kalendereinträge`,
   `Im Detailmodus …`) sind nirgends mehr referenziert; `Nur Häfen & Seetage`
   ist ganz aus dem Katalog raus, `Keine Einträge` bleibt zu Recht (noch von
   `DealsView.swift:59` genutzt). Nur F10 als Kosmetik.
6. **UI-Test?** Er prüft Verhalten (Ausgangslage + Opt-in überlebt Relaunch),
   nicht nur Existenz — gut. Schwächen: F03 (nach dem Neustart wird nur der
   Trip-Schalter geprüft), F04 (nicht hermetisch, kein Präferenz-Reset,
   Aufräumen inline statt `tearDown`), F08 (Koordinaten-Tap).
7. **`guard.py sizes`** auf die geänderten Dateien: exit 1, aber der einzige
   Treffer ist `ShipTrip/Localizable.xcstrings` (5069 Zeilen) — generierter
   String-Katalog, kein Quelltext, **kein Finding**. Alle Swift-Dateien liegen
   unter dem Limit (`CalendarSyncSettingsView.swift`: 352 Zeilen).
8. **`CaseIterable, Identifiable`?** Verwaist — `allCases` und `id` haben
   projektweit keinen Aufrufer mehr (einziger war der gelöschte Picker). Nach
   CLAUDE.md §3 („Orphans der eigenen Änderung entfernen") ein Finding, aber
   nur `minor` (F06).

## Findings

| ID  | Sev   | Blocker | File:Line | Kategorie | Titel |
|-----|-------|---------|-----------|-----------|-------|
| F01 | major | nein | `ShipTrip/Views/Settings/CalendarSyncSettingsView.swift:270-275` | correctness | Migration läuft erst im `.task`, Kommentar behauptet „vorher" |
| F02 | major | nein | `ShipTrip/Views/Settings/CalendarSyncSettingsView.swift:154-160` | correctness | Schalter ohne Kalenderzugriff bedienbar → Bestandsnutzer wählt auf falscher Basis |
| F03 | major | nein | `ShipTripUITests/KalenderUmfangUITests.swift:60-70` | tests | Nach dem Neustart nur ein Schalter geprüft — `tripOnly` fiele nicht auf |
| F04 | major | nein | `ShipTripUITests/KalenderUmfangUITests.swift:26-77` | tests | Test nicht hermetisch: kein Präferenz-Reset, Cleanup nicht in `tearDown` |
| F05 | minor | nein | `ShipTrip/Views/Settings/CalendarSyncSettingsView.swift:104` | performance | Doppelter Sync pro Tap (View + `CalendarSyncObserver`) |
| F06 | minor | nein | `ShipTrip/Services/CalendarEventPlanner.swift:14-20` | api | `CaseIterable, Identifiable` + `id` verwaist |
| F07 | minor | nein | `ShipTrip/Views/Settings/CalendarSyncSettingsView.swift:149` vs. `:156,160` | ui | Inkonsistente Deaktivierung bei Sync-aus |
| F08 | minor | nein | `ShipTripUITests/KalenderUmfangUITests.swift:103-105` | tests | Koordinaten-Tap `dx: 0.9` statt `.tap()` auf dem Switch |
| F09 | minor | nein | `.winston-evidence/20260902T144947Z/gate-run.json:4` | process | `commit: aec5263` ≠ geprüfter Stand `c33d9df` |
| F10 | minor | nein | `ShipTrip/Localizable.xcstrings` („Stopps eintragen") | l10n | EN „Add stops" bricht die Title-Case der Nachbarn |

---

### F01 — Migration läuft erst im `.task`, nicht vor der ersten Anzeige
- **File**: `ShipTrip/Views/Settings/CalendarSyncSettingsView.swift:270-275`
- **Severity**: major · **Blocker**: nein
- **Problem**: Der Kommentar sagt „Die Bestands-Migration muss entschieden
  haben, bevor die Schalter einen Umfang zeigen." `.task` läuft aber erst nach
  der ersten Body-Auswertung. Failure-Szenario: Bestandsnutzer mit
  Ganzreise-Termin (effektiv `tripOnly`) öffnet die Kalender-Einstellungen. Der
  erste Frame zeigt den Neu-Default „Stopps an / Gesamtreise aus"; danach
  schreibt die Migration `tripOnly` und beide Schalter springen sichtbar um. Wer
  in diesem Fenster tippt, schreibt auf der falschen Basis.
- **Fix**: Entweder den Kommentar auf das Tatsächliche korrigieren („holt die
  Entscheidung beim Erscheinen nach"), oder die Migration vor dem ersten Body
  auslösen — z. B. im `init` der View bzw. beim Öffnen der Settings-Zeile.

### F02 — Umfangs-Schalter ohne Kalenderzugriff bedienbar
- **File**: `ShipTrip/Views/Settings/CalendarSyncSettingsView.swift:154-160`
- **Severity**: major · **Blocker**: nein (schmaler Pfad)
- **Problem**: `.disabled(!isEnabled || isWorking)` wurde zu `.disabled(isWorking)`.
  Ohne `fullAccess` kehrt `refreshCalendars()` bei `:266` zurück, die Migration
  läuft nicht, und die Schalter zeigen den Neu-Default. Failure-Szenario:
  Bestandsnutzer aus 1.8.6 (Sync an, `tripOnly` implizit) entzieht in den
  iOS-Einstellungen den Kalenderzugriff und öffnet danach die ShipTrip-Kalenderseite.
  Angezeigt wird „Stopps an / Gesamtreise aus". Schaltet er „Stopps" aus, steht
  `.none` in den Defaults; `CalendarSyncModeMigration.run` wertet den nun
  gesetzten `modeKey` als bewusste Wahl (`CalendarSyncModeMigration.swift:51-54`),
  setzt den Merker und der Bestandsschutz greift nie — nach Wiedererteilung des
  Zugriffs räumt der erste Sync alle Termine ab.
- **Fix**: Den Umfangs-Bereich deaktivieren, solange
  `CalendarSyncModeMigration.isSettled(in: .standard) == false` — dann kann
  niemand vor der Entscheidung auf falscher Basis wählen; die
  UI-Test-Bedienbarkeit bleibt erhalten, weil auf frischer Installation nichts
  zu migrieren ist (Merker sofort setzbar).

### F03 — Relaunch-Prüfung deckt nur den halben Modus ab
- **File**: `ShipTripUITests/KalenderUmfangUITests.swift:60-70`
- **Severity**: major · **Blocker**: nein
- **Problem**: Nach dem Neustart wird ausschließlich `tripToggle == "1"`
  geprüft. Der eigentliche Vertrag ist die *Kombination*: erwartet ist
  `tripAndItinerary`. Failure-Szenario: Eine Regression, die beim Tap auf
  „Gesamte Reise" den Itinerary-Schalter mit ausschaltet (also `tripOnly`
  persistiert — exakt der Zustand, den 1.8.7 abschaffen soll), lässt den Test
  grün.
- **Fix**: Direkt nach `:70` ergänzen:
  `XCTAssertEqual(relaunched.switches[itineraryToggle].value as? String, "1", "Die Stopps sind beim Opt-in verlorengegangen")`.

### F04 — UI-Test ist nicht hermetisch
- **File**: `ShipTripUITests/KalenderUmfangUITests.swift:26-77`
- **Severity**: major · **Blocker**: nein
- **Problem**: Der Test behauptet „Ausgangslage einer frischen Installation",
  setzt aber keine Präferenz zurück; er verlässt sich darauf, dass
  `calendarSyncMode` auf dem Simulator ungesetzt ist. Aufgeräumt wird inline in
  `:74-76` — bei `continueAfterFailure = false` bricht der Test bei jedem
  früheren Fehlschlag ab, bevor er dort ankommt. Failure-Szenario: Ein Lauf
  scheitert nach `flip(trip)` (`:45`); `calendarSyncMode = tripAndItinerary`
  bleibt stehen, und der Folgelauf scheitert an `:43` mit einer irreführenden
  Meldung („Die Gesamtreise ist nicht Opt-in").
- **Fix**: Dem Projekt-Idiom folgen und eine Reset-Naht nutzen bzw. ergänzen
  (analog `-uiTestingResetOnboarding` in `ShipTripApp.swift:138`), die
  `CalendarSyncPreferences.modeKey` und `CalendarSyncModeMigration.markerKey`
  vor dem Start entfernt; Cleanup zusätzlich in `tearDownWithError`.

### F05 — Doppelter Sync pro Tap
- **File**: `ShipTrip/Views/Settings/CalendarSyncSettingsView.swift:104`
- **Severity**: minor · **Blocker**: nein
- **Problem**: `apply` ruft `synchronizeIfEnabled()`; parallel enthält
  `CalendarSyncObserver.syncToken` (`CalendarSyncObserver.swift:25`) den
  `modeRawValue`, sodass dessen `.task(id:)` denselben Sync ein zweites Mal
  fährt. Beide laufen auf dem MainActor, also serialisiert und idempotent —
  kein Datenrisiko, aber doppelter EventKit-Durchlauf. (Positiver Nebeneffekt:
  Der Observer fängt den Fall ab, in dem `operationState.begin()` den Sync in
  der View verschluckt.)
- **Fix**: Entweder den Aufruf in `apply` streichen und den Observer die Arbeit
  machen lassen, oder als bewusste Doppelung im Kommentar festhalten.

### F06 — `CaseIterable, Identifiable` verwaist
- **File**: `ShipTrip/Services/CalendarEventPlanner.swift:14-20`
- **Severity**: minor · **Blocker**: nein
- **Problem**: Einziger Nutzer von `allCases` und `id` war der gelöschte
  `ForEach(CalendarSyncMode.allCases)`. Projektweiter grep: kein Treffer mehr,
  auch nicht in den Tests. Orphan der eigenen Änderung (CLAUDE.md §3).
- **Fix**: Konformanzen und `var id: String { rawValue }` entfernen; `String`
  als RawValue bleibt (Persistenz).

### F07 — Inkonsistente Deaktivierung bei ausgeschaltetem Sync
- **File**: `ShipTrip/Views/Settings/CalendarSyncSettingsView.swift:149` vs. `:156,160`
- **Severity**: minor · **Blocker**: nein
- **Problem**: Der Zielkalender-Picker bleibt bei Sync-aus deaktiviert, die
  direkt darunter stehenden Umfangs-Schalter sind es nicht mehr. Der Nutzer
  bekommt keinen Hinweis, dass seine Umfangs-Wahl gerade folgenlos ist.
- **Fix**: Entweder beide Bereiche gleich behandeln oder den Section-Footer bei
  `!isEnabled` um einen Satz ergänzen („Wirkt, sobald die Synchronisation an
  ist.").

### F08 — Koordinaten-Tap statt Element-Tap
- **File**: `ShipTripUITests/KalenderUmfangUITests.swift:103-105`
- **Severity**: minor · **Blocker**: nein
- **Problem**: `coordinate(withNormalizedOffset: CGVector(dx: 0.9, dy: 0.5))`
  ist an das aktuelle Zeilenlayout gebunden. Failure-Szenario: längeres
  Toggle-Label (EN, größere Dynamic-Type-Stufe, iPad-Breite) schiebt den Switch
  aus dem 90-%-Punkt; der Tap landet auf dem Label und der Test wird flaky.
- **Fix**: Erst `element.tap()` versuchen und nur bei unverändertem `value` auf
  den Koordinaten-Tap zurückfallen — oder den Offset am rechten Rand
  (`dx: 0.97`) festmachen und die Begründung im Kommentar behalten.

### F09 — Evidenz-Commit zeigt auf den Basis-Stand
- **File**: `.winston-evidence/20260902T144947Z/gate-run.json:4`
- **Severity**: minor · **Blocker**: nein
- **Problem**: `"commit": "aec5263"` ist der Basis-Commit, geprüft wird
  `c33d9df`. Der Lauf ist echt (der Log enthält `KalenderUmfangUITests`, die es
  nur auf `c33d9df` gibt — die Gates liefen im noch uncommitteten Worktree),
  aber das Artefakt ist nicht mehr eindeutig einem Stand zuzuordnen.
- **Fix**: Gates nach dem Commit fahren oder den Worktree-Zustand
  (`dirty: true` + Basis) im Artefakt vermerken.

### F10 — EN-Groß-/Kleinschreibung
- **File**: `ShipTrip/Localizable.xcstrings`, Key „Stopps eintragen"
- **Severity**: minor · **Blocker**: nein
- **Problem**: „Add stops" neben „Add entire trip as one entry" und „Sync Trips
  with Calendar" — uneinheitlich.
- **Fix**: „Add Stops" bzw. den Katalog einheitlich auf Sentence Case ziehen.

## Test-Run-Status (kein eigener Lauf — Build-Token bei TB2, statische Prüfung)
- `build` — exit 0, 0 Warnungen.
- `tests` (`-only-testing:ShipTripTests`) — exit 0, „Test run with 576 tests in
  122 suites passed". Die Zeile „Executed 0 tests" stammt aus dem leeren
  XCTest-Bucket, die 576 laufen unter Swift Testing — kein Widerspruch.
- `uitest` (`KalenderUmfangUITests`) — exit 0, 1 Test, 29,9 s.
- Kommandos sind die kanonischen `xcodebuild build-for-testing` /
  `test-without-building` — keine Weichspüler. Log-`sha256` stimmen mit den
  Dateien überein. Nicht belegbar: ob die Ziel-UDID ein Wegwerf-Klon war.

## Go/No-Go
**Go** — keine offenen Blocker. F01–F10 gehen ins Backlog; F02 und F03 sind die
zwei, die vor dem 1.8.7-Release am ehesten noch Wert bringen.
