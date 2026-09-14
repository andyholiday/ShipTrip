# Review — QF2: Schalter-Freigabe in der Sitzung + hermetischer UI-Test

- **Iteration**: 2 / 3
- **Reviewer**: quality-agent (frischer Spawn, read-only, kein Build-Token)
- **Datum**: 2026-09-02
- **Worktree**: `/Users/andre-studio/Documents/0.Projekte/ShipTrip-worktrees/kalender-1.8.7` — HEAD `975bae5`, Diff `72f680f..975bae5` (3 Dateien, +32/-9)
- **Verdict**: approve (Go mit Backlog)
- **Stats**: critical 0, major 1, minor 3 — Blocker: 0, Backlog: 4
- **Evidenz**: `.winston-evidence/20260902T153039Z/gate-run.json` — `commit: 975bae5` = HEAD, build/tests/uitest Exit 0, alle drei `log_sha256` nachgerechnet und passend; `tests.log:4159` „Test run with 580 tests in 123 suites passed"; `uitest.log` 1/1, zwei App-Starts (t=0.02 s, t=16.08 s), `** TEST EXECUTE SUCCEEDED **`. Kommandos sind der Kanon (`build-for-testing` + `test-without-building`, dieselbe Trennung wie `.github/workflows/ci.yml`), keine Weichspüler.

## Zusammenfassung

Beide Findings der Iteration 1 sind geschlossen. F01 ist am **Normalpfad** dicht: Der
Erfolgszweig von `updateEnabled` liest nach `performSynchronization()` beide
Sperr-Gründe neu, und `synchronize` ruft `migrateSyncModeIfNeeded()` als **erste**
Anweisung — vor dem `isEnabled`-Guard —, die Migration hat zum Zeitpunkt des
Neu-Lesens also garantiert entschieden. F02 ist besser gelöst als vorgeschlagen: Die
DEBUG-Naht macht den Test unabhängig vom Restzustand, statt ihn nur zu grünen. Kein
neuer Blocker. Was bleibt, sind zwei Randpfade mit falscher Fußnote und die fehlende
Absicherung des Fixes selbst — alles Backlog.

## Findings

| ID  | Severity | Blocker | File:Line | Kategorie | Titel |
|-----|----------|---------|-----------|-----------|-------|
| F07 | major | nein | `ShipTrip/Views/Settings/CalendarSyncSettingsView.swift:375-380` | tests | Der F01-Fix selbst ist unbewacht — Rückbau bleibt grün |
| F08 | minor | nein | `ShipTrip/Views/Settings/CalendarSyncSettingsView.swift:366-370` | UX | Zugriff erteilt, kein Standardkalender → Fußnote behauptet fehlenden Zugriff |
| F09 | minor | nein | `ShipTrip/Views/Settings/CalendarSyncSettingsView.swift:229-231` | robustness | Kein `scenePhase`-Refresh: Rückkehr aus den System-Einstellungen verlässt sich auf den OS-Kill |
| F10 | minor | nein | `ShipTripUITests/KalenderUmfangUITests.swift:31-37` | tests | Reset lässt das Termin-Mapping stehen (ehrliches Rot, kein falsches Grün) |

### F07 — Der Fix selbst ist unbewacht

- **File**: `ShipTrip/Views/Settings/CalendarSyncSettingsView.swift:375-380`
- **Severity**: major · Blocker: nein
- **Problem**: Der UI-Test setzt den Kalenderzugriff **vor** dem Start
  (`simctl privacy grant`), die Migration settelt daher schon im `.task` →
  `refreshCalendars`. Der Pfad, den F01 repariert (Zugriff erst in der offenen
  Ansicht erteilt), wird von keinem Test berührt. Ein Rückbau der beiden neuen
  Zeilen lässt 580/580 Unit-Tests **und** den UI-Test grün.
- **Fix (Backlog)**: UI-Test mit `simctl privacy … reset calendar` vor dem Lauf plus
  `addUIInterruptionMonitor` auf den System-Dialog — bekannt flaky, deshalb kein
  Fix-Auftrag in diesem Run. Der Fix ist zwei Zeilen und statisch nachvollziehbar.

### F08 — Zugriff erteilt, kein Standardkalender: Fußnote lügt weiter

- **File**: `ShipTrip/Views/Settings/CalendarSyncSettingsView.swift:366-370`
- **Severity**: minor · Blocker: nein
- **Failure-Szenario**: `requestAccess()` liefert `true` (Nutzer hat gerade erlaubt),
  `selectDefaultCalendarIfNeeded()` liefert `nil` (kein beschreibbarer
  Standardkalender). Der `guard` kehrt **vor** den neuen Zeilen 379/380 zurück,
  `hasCalendarAccess` bleibt `false` → Umfangs-Fußnote sagt „… sobald der
  Kalenderzugriff erteilt ist", obwohl er erteilt ist. Die Sperre selbst ist korrekt
  (die Migration hat mangels Sync nicht entschieden), nur die Begründung ist falsch.
  Gleiche Klasse wie F04 aus Iteration 1 (`.writeOnly`), schmaler Pfad.
- **Fix**: `hasCalendarAccess = true` direkt nach dem geglückten `requestAccess()`
  setzen (Zeile 363), die Migrations-Neulesung bleibt hinten stehen.

### F09 — Kein `scenePhase`-Refresh

- **File**: `ShipTrip/Views/Settings/CalendarSyncSettingsView.swift:229-231`
- **Severity**: minor · Blocker: nein
- **Problem**: Erteilt der Nutzer den Zugriff über „Einstellungen öffnen" in den
  iOS-Einstellungen, gibt es keinen Hook, der beim Zurückkommen neu liest. In der
  Praxis beendet iOS die App beim Ändern einer Privacy-Berechtigung, der Neustart
  lässt `.task` erneut laufen — deshalb kein Normalpfad-Schaden. Bleibt die App
  wider Erwarten am Leben, sind die Schalter für die Sitzung grau; Ausweg ist
  Zurück + erneutes Öffnen.
- **Fix (Backlog)**: `.onChange(of: scenePhase)` → `await refreshCalendars()` bei
  `.active`.

### F10 — Reset-Naht deckt das Mapping nicht ab

- **File**: `ShipTripUITests/KalenderUmfangUITests.swift:31-37`,
  `ShipTrip/ShipTripApp.swift:159-167`
- **Severity**: minor · Blocker: nein
- **Problem**: Zurückgesetzt werden `calendarSyncMode` und
  `calendarSyncModeMigratedV2`, nicht `calendarSyncManagedEventIdentifiers`. Liegt
  auf dem Simulator noch ein lebender `/trip`-Termin aus einem anderen Test, wählt
  die Migration `tripOnly` → die Ausgangs-Assertion (`itinerary == "1"`) wird **rot**.
  Das ist ehrliches Rot, kein falsches Grün — der Fehler von Iteration 1 ist damit
  strukturell weg. Auf dem Wegwerf-Simulator (Neuinstallation) tritt es nicht auf.

## Antworten auf die Prüffragen

1. **F01 — alle Pfade?** Sync-Toggle an: ja (`:379-380`, nach `performSynchronization`).
   „Jetzt synchronisieren" und Kalenderwechsel: kein Neulesen nötig — beide sind nur
   erreichbar, wenn `.task` mit Vollzugriff lief, und dort settelt `refreshCalendars`
   (`:321-324`) die Migration bereits; mit Vollzugriff settelt `run()` immer. Rückkehr
   aus den System-Einstellungen: kein expliziter Hook (F09, OS-Kill deckt es). Offen
   bleibt nur der Randpfad „kein Standardkalender" (F08) — kein Normalpfad, kein Blocker.
2. **Migration übersprungen oder Mode-Key vor dem Settle geschrieben?** Nein. Die neuen
   Zeilen sind reine Lesungen; `synchronize(cruises:allowMarkerSearch:)` ruft
   `migrateSyncModeIfNeeded()` vor dem `isEnabled`-Guard, `performSynchronization()`
   läuft synchron vor dem Neulesen, und Schreibpfade auf `calendarSyncMode` bleiben
   `CalendarSyncModeMigration.run` und `apply(itinerary:trip:)` hinter den gesperrten
   Togglern. Andres Regel (Bestand mit `/trip`-Termin → `tripOnly`) bleibt intakt.
3. **DEBUG-Naht sauber?** Ja. Aufruf in `#if DEBUG` (`ShipTripApp.swift:27-31`), die
   Funktion selbst im DEBUG-Block `:126-180` → keine Release-Nutzlast. Reihenfolge
   korrekt: Der Reset läuft als erstes in `init()`, vor `ModelContainer` und vor jeder
   View; die Migration läuft erst beim Erscheinen der Kalender-Einstellungen bzw. beim
   Sync — sie findet also einen leeren `modeKey` und entscheidet neu.
4. **UI-Test plausibel grün?** Ja, gegen den Code: Reset → `.task` mit Vollzugriff →
   `hasManagedEvents` → `run()` mit `modeKey == nil`, leerem Mapping →
   `itineraryOnly` + Marker → Schalter frei, `1`/`0` wie erwartet. Der zweite Start ist
   eine **neue** `XCUIApplication` ohne das Reset-Argument (`:69-71`) — dass die
   Assertion `trip == "1"` grün ist, beweist genau das. Ohne Kalender-Grant liefe der
   Test in den Timeout (ehrliches Rot), das Grün belegt die Voraussetzung also selbst.
5. **Evidenz?** Exit 0/0/0, `commit` = HEAD, alle `log_sha256` nachgerechnet, Kanon-Gates.
   Der `simctl privacy grant`-Schritt steht nicht in `gate-run.json` (er ist auch in der
   CI ein eigener Schritt) — unkritisch, siehe (4).
6. **Neue Blocker?** Nein.

`guard.py sizes --files` (3 geänderte Dateien): Exit 0, eine Soft-Warnung —
`CalendarSyncSettingsView.swift` 407 Zeilen (> 400 soft, < 500 hard), gewachsen von
401. Backlog, kein Blocker.

**GDPR/Security**: nicht ausgelöst — keine neue Datenverarbeitung, keine neue
Angriffsfläche, Kalenderdaten bleiben auf dem Gerät; die Test-Naht ist DEBUG-only.

## Status der Iteration 1

- F01 (Blocker): **resolved** — Restrisiken nur auf Randpfaden (F08/F09).
- F02: **resolved** — DEBUG-Reset statt Restzustands-Abhängigkeit; das Aufräum-Flip am
  Ende ist entfernt, der Dateikopf ist korrigiert.
- F03 / F04 / F05 / F06: triagiert im Backlog, hier nicht erneut gemeldet (F07 ist die
  Fortschreibung von F03 auf den neuen Code, F08 die Schwester von F04).

## Backlog-Vorschläge (`.planning/BACKLOG.md`)

```
- [major] ShipTrip/Views/Settings/CalendarSyncSettingsView.swift:375 — kein Test deckt die Schalter-Freigabe nach In-Session-Grant
- [minor] ShipTrip/Views/Settings/CalendarSyncSettingsView.swift:366 — Zugriff erteilt, kein Standardkalender: Fussnote behauptet fehlenden Zugriff
- [minor] ShipTrip/Views/Settings/CalendarSyncSettingsView.swift:229 — kein scenePhase-Refresh nach Rueckkehr aus den System-Einstellungen
- [minor] ShipTripUITests/KalenderUmfangUITests.swift:31 — Reset-Naht laesst calendarSyncManagedEventIdentifiers stehen
- [minor] ShipTrip/Views/Settings/CalendarSyncSettingsView.swift:1 — 407 Zeilen ueber Soft-Limit 400 (war 401)
```

## Go / No-Go

**Go** — kein offener Blocker. Der Erstnutzer-Pfad ist bedienbar, der Bestandsschutz
unangetastet, der UI-Test bewacht die Voreinstellung jetzt echt. F07–F10 reiten im
Backlog mit.
