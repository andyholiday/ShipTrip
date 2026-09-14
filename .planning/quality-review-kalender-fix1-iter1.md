# Review — QF1: Umfangs-Schalter bis zur Migrations-Entscheidung gesperrt

- **Iteration**: 1 / 3
- **Reviewer**: quality-agent (frischer Spawn, read-only)
- **Datum**: 2026-09-02
- **Worktree**: `/Users/andre-studio/Documents/0.Projekte/ShipTrip-worktrees/kalender-1.8.7` — HEAD `b7df530`, Diff `854a4b9..b7df530`
- **Verdict**: request-changes
- **Stats**: critical 0, major 3, minor 3 — Blocker: 1, Backlog: 5
- **Evidenz**: `.winston-evidence/20260902T151450Z/gate-run.json` — build/tests/uitest Exit 0, `log_sha256` aller drei Logs nachgerechnet und passend; `tests.log`: „Test run with 580 tests in 123 suites passed", Suite „Kalender-Umfang: Bedienbarkeit" grün; `uitest.log`: 1/1, `** TEST EXECUTE SUCCEEDED **`. Kommandos sind die Kanon-Gates, keine Weichspüler.

## Zusammenfassung

Der gemeldete Blocker (Tipp vor entschiedener Migration schreibt `calendarSyncMode`
und gibt den Ganzreise-Termin eines Bestandsnutzers zur Löschung frei) ist
**geschlossen**: Es gibt keinen produktiven Schreibpfad auf den Mode-Key mehr, der
vor `CalendarSyncModeMigration.isSettled` liegt. Die Sperre kann außerdem nicht in
die unsichere Richtung veralten — `isScopeMigrationSettled` wird nur je auf `true`
gesetzt.

Dafür entsteht ein **neuer Blocker in der Gegenrichtung**: Wird der Kalenderzugriff
erst in der offenen Ansicht erteilt, aktualisiert nichts die beiden State-Flags. Die
Umfangs-Schalter bleiben für den Rest der Sitzung grau — mit einer Fußnote, die
fehlenden Zugriff behauptet, den der Nutzer soeben erteilt hat. Das ist genau der
Erstnutzer-Pfad des 1.8.7-Features.

## Findings

| ID  | Severity | Blocker | File:Line | Kategorie | Titel |
|-----|----------|---------|-----------|-----------|-------|
| F01 | major | **ja** | `ShipTrip/Views/Settings/CalendarSyncSettingsView.swift:229-230,355-374` | correctness/UX | Zugriff in der Sitzung erteilt → Schalter bleiben gesperrt, Fußnote lügt |
| F02 | major | nein | `ShipTripUITests/KalenderUmfangUITests.swift:26-84` | tests | UI-Test-Grün hängt an Restzustand des Simulators |
| F03 | major | nein | `ShipTrip/Views/Settings/CalendarSyncSettingsView.swift:196,200` | tests | Kein Test bewacht die Verdrahtung `.disabled(!isEditable)` |
| F04 | minor | nein | `ShipTrip/Views/Settings/CalendarSyncSettingsView.swift:57-63` | UX/l10n | `.writeOnly`: dauerhafte Sperre mit irreführender Fußnote |
| F05 | minor | nein | `ShipTrip/Utilities/AppReset.swift:36-38` | data (pre-existing) | Reset ohne Kalenderzugriff lässt Mapping + Marker stehen |
| F06 | minor | nein | `ShipTrip/Views/Settings/CalendarSyncSettingsView.swift:1-401` | size | 401 Zeilen > Soft-Limit 400 (bekannt) |

### F01 — Zugriff in der Sitzung erteilt, Schalter bleiben gesperrt  *(Blocker)*

- **File**: `ShipTrip/Views/Settings/CalendarSyncSettingsView.swift:229-230` (`.task { await refreshCalendars() }`), `:355-374` (`updateEnabled(_:)`)
- **Severity**: major · **Blocker: ja**
- **Problem**: `hasCalendarAccess` und `isScopeMigrationSettled` werden ausschließlich
  im einmaligen `.task` gesetzt (kein `task(id:)`, kein `scenePhase`-Hook —
  `grep` findet genau einen Aufruf von `refreshCalendars`). Erteilt der Nutzer den
  Zugriff über den Sync-Schalter, läuft `updateEnabled` → `requestAccess()` →
  `performSynchronization()` → `migrateSyncModeIfNeeded()`; die Migration **settelt**
  dort korrekt, aber die View erfährt es nicht.
- **Failure-Szenario (Erstinstallation, kein Kalenderzugriff)**: Einstellungen →
  Kalender öffnen (beide Umfangs-Schalter grau, Fußnote „… sobald der
  Kalenderzugriff erteilt ist") → „Reisen mit Kalender synchronisieren" an →
  Zugriff erlauben → Sync läuft, Stopps landen im Kalender → Nutzer will
  zusätzlich „Gesamte Reise als Eintrag": Schalter **weiterhin grau**, Fußnote
  verlangt weiterhin Kalenderzugriff. Ausweg nur über Zurück + erneutes Öffnen der
  Ansicht. Das Feature von 1.8.7 ist in der Sitzung seiner Entdeckung unbedienbar,
  und der angezeigte Grund ist falsch.
- **Fix** (2 Zeilen, im Erfolgszweig von `updateEnabled`, **nach**
  `performSynchronization()` — erst dort hat die Migration entschieden):
  ```swift
  isEnabled = true
  performSynchronization()
  hasCalendarAccess = true
  isScopeMigrationSettled = CalendarSyncModeMigration.isSettled(in: .standard)
  ```
  Alternativ `await refreshCalendars()` statt `performSynchronization()` — spart
  Duplikat-Logik, kostet aber einen zusätzlichen Sync-Durchlauf.
- **Regressionstest**: Unit-Test reicht hier nicht; ein UI-Test mit
  `xcrun simctl privacy <udid> reset calendar <bundle-id>` vor dem Lauf und
  anschließendem Erteilen deckt genau diesen Pfad (siehe F02/F03).

### F02 — UI-Test-Grün hängt am Restzustand des Simulators

- **File**: `ShipTripUITests/KalenderUmfangUITests.swift:26-84`
- **Severity**: major · Blocker: nein
- **Problem**: Der Test startet mit `-uiTestingCompleteOnboarding`, **nicht** mit
  `-uiTestingResetOnboarding` — die `UserDefaults` der Installation überleben also
  jeden Lauf. Sein eigener Aufräumschritt (`:81-83`) schaltet die Gesamtreise
  wieder ab und lässt `calendarSyncMode` damit **gesetzt** zurück. Beim nächsten
  Start greift in `CalendarSyncModeMigration.run` der Zweig „Wer den Umfang schon
  einmal bewusst gewählt hat, behält ihn" → Marker `true` **ohne** Kalenderzugriff
  → Schalter bedienbar. Genau das hat das neue `waitUntilEnabled` grün gemacht
  (`uitest.log` t=12.25 s: Prädikat sofort erfüllt).
- **Failure-Szenario**: Auf einem frischen Wegwerf-Simulator (Neuinstallation, kein
  Kalenderzugriff, kein `calendarSyncMode`) settelt die Migration nie → beide
  Schalter bleiben gesperrt → `waitUntilEnabled` läuft in den 10-s-Timeout → Test
  rot. Die Zusicherung ist also zustandsabhängig; das grüne `uitest.log` belegt den
  Entsperr-Pfad **nicht**.
- **Fix**: Vor dem Lauf Zugriff deterministisch setzen
  (`xcrun simctl privacy <udid> grant calendar com.andre.ShipTrip`) und den App-Start
  auf einen definierten Defaults-Zustand bringen (`-uiTestingResetOnboarding`), oder
  die Behauptung ehrlich umdrehen: ohne Zugriff **gesperrt** erwarten.
- **Nebenbefund**: Der Dateikopf (`:10-11`, „Kein Kalenderzugriff noetig: Die Schalter
  schreiben nur die Praeferenz") beschreibt seit diesem Fix nicht mehr die Realität
  und gehört korrigiert.

### F03 — Keine Absicherung der Verdrahtung

- **File**: `ShipTrip/Views/Settings/CalendarSyncSettingsView.swift:196` und `:200`
- **Severity**: major · Blocker: nein
- **Problem**: Der Rot-Beweis ist ein echter Verhaltenstest der Entscheidungsregel —
  ein Rückbau von `isEditable` auf `!isWorking` macht
  `scopeStaysLockedUntilMigrationSettled` rot (der Test konstruiert
  `isMigrationSettled: false, isWorking: false` und erwartet `!isEditable`). Ein
  Rückbau der **Verdrahtung** `.disabled(!scopeAvailability.isEditable)` →
  `.disabled(isWorking)` lässt dagegen alle 580 Unit-Tests **und** den UI-Test grün.
  Die eigentliche Regression ist damit nicht bewacht.
- **Fix**: UI-Test-Stub `KalenderUmfangUITests.testUmfangBleibtOhneKalenderzugriffGesperrt`:
  Zugriff per `simctl privacy … reset calendar` entziehen, Defaults zurücksetzen,
  Kalender-Einstellungen öffnen, `XCTAssertFalse(app.switches["calendarSync.tripToggle"].isEnabled)`
  und die Fußnote „… sobald der Kalenderzugriff erteilt ist" als sichtbar prüfen.
- **Hinweis Rot-Beweis**: Für `b4cab08` liegt kein Evidenz-Artefakt vor (die vier
  `.winston-evidence`-Läufe stehen auf `188d2c4`, `aec5263`, `e11478a`, `b7df530`).
  Die Rotheit ist hier statisch nachvollziehbar, deshalb nur ein Hinweis — künftig
  gehört der rote Lauf ins Artefakt, nicht nur in die Commit-Message.

### F04 — `.writeOnly`: dauerhafte Sperre, irreführende Fußnote

- **File**: `ShipTrip/Views/Settings/CalendarSyncSettingsView.swift:57-63`, `:311`
- **Severity**: minor · Blocker: nein
- **Problem**: Akzeptiert wird nur `.fullAccess`. Wer in iOS-Einstellungen auf „Nur
  hinzufügen" (`.writeOnly`) heruntersetzt, sieht die Umfangs-Schalter dauerhaft grau
  mit „Der Umfang lässt sich ändern, sobald der Kalenderzugriff erteilt ist." — aus
  seiner Sicht hat er Zugriff erteilt. `requestAccess()` gibt für `.writeOnly` `false`
  zurück (`default`-Zweig), der Sync-Schalter zeigt den Zugriffs-Alert. Verhalten ist
  bestandsgemäß korrekt (Bestandsprüfung braucht Lesezugriff), nur die Formulierung
  ist unscharf.
- **Fix**: Fußnote auf „vollen Kalenderzugriff" präzisieren (DE + EN in
  `Localizable.xcstrings`; die neue Zeichenkette ist dort korrekt zweisprachig
  hinterlegt).

### F05 — Reset ohne Kalenderzugriff (pre-existing, außerhalb des Diffs)

- **File**: `ShipTrip/Utilities/AppReset.swift:36-38`
- **Severity**: minor · Blocker: nein
- **Problem**: `AppReset.run` räumt die Termine „best effort" (`try?`) ab und löscht
  danach `calendarSyncMode`; der Migrations-Marker `calendarSyncModeMigratedV2` bleibt
  bewusst stehen (`AppPreferencesReset:20-31`). Scheitert das Abräumen mangels
  Zugriffs, überlebt das Mapping mitsamt `/trip`-Termin, während die Migration als
  „entschieden" gilt und der Umfang auf den Default `itineraryOnly` zurückfällt →
  beim nächsten aktivierten Sync verschwindet der Ganzreise-Termin ohne Nachfrage.
  Sehr schmaler Pfad (Reset bei entzogenem Zugriff, danach Zugriff + Sync wieder an),
  nicht durch QF1 eingeführt.
- **Fix**: Bei fehlgeschlagenem `removeAllManagedEvents()` zusätzlich
  `calendarSyncModeMigratedV2` entfernen, damit die Migration den Bestand erneut prüft.

### F06 — Dateigröße

`guard.py sizes --files` (3 geänderte Swift-Dateien): Exit 0, eine Soft-Warnung —
`CalendarSyncSettingsView.swift` 401 Zeilen (> 400 soft, < 500 hard). Wie gebrieft:
Backlog, kein Blocker.

## Antworten auf die Prüffragen

1. **Schreibpfade vor `isSettled`?** Nein. Produktiv schreiben den Key nur
   `CalendarSyncModeMigration.run` (`:58`) und `apply(itinerary:trip:)`
   (`CalendarSyncSettingsView:284`) über die beiden jetzt gesperrten Toggles;
   `CalendarSyncObserver:18` liest sein `@AppStorage` nur als Sync-Token,
   `AppPreferencesReset:31` entfernt den Key, und Onboarding, DemoDataService,
   Import/Export sowie `CalendarMigrationCoordinator` fassen ihn nicht an
   (`grep` über `ShipTrip/`).
2. **Settelt die Migration beim Erscheinen?** Bei bereits erteiltem Vollzugriff ja
   (`refreshCalendars` → `hasManagedEvents` → `migrateSyncModeIfNeeded`); wird der
   Zugriff erst danach erteilt, nicht (F01). Bei `.writeOnly` nie (F04).
3. **Rot-Test ein Verhaltenstest?** Ja für die Regel (Rückbau von `isEditable` macht
   ihn rot), nein für die Verdrahtung im View (F03).
4. **UI-Test-Wait?** Sauber: `XCTNSPredicateExpectation` auf `isEnabled == true` mit
   `XCTWaiter`-Timeout 10 s, kein `sleep` (`KalenderUmfangUITests:116-124`).
5. **T5 — Zugriff erteilt, Sync aus?** Schalter bleiben bedienbar und das ist
   konsistent: Das Abschalten des Syncs entfernt zuvor alle verwalteten Termine, die
   Migration findet also keinen `hasLiveTripEvent` und schreibt `itineraryOnly` —
   es gibt nichts mehr zu verlieren.
6. **`guard.py sizes`?** Exit 0, eine Soft-Warnung (401 Zeilen) → Backlog.
7. **Neuer Blocker?** Ja, F01.

## Backlog-Vorschläge (`.planning/BACKLOG.md`)

```
- [major] ShipTripUITests/KalenderUmfangUITests.swift:26 — UI-Test-Gruen haengt am Restzustand des Simulators (kein Defaults-Reset, kein Kalender-Grant)
- [major] ShipTrip/Views/Settings/CalendarSyncSettingsView.swift:196 — kein Test bewacht .disabled(!scopeAvailability.isEditable)
- [minor] ShipTrip/Views/Settings/CalendarSyncSettingsView.swift:57 — .writeOnly: Fusszeile sollte "vollen Kalenderzugriff" nennen
- [minor] ShipTrip/Utilities/AppReset.swift:36 — Reset ohne Kalenderzugriff laesst Mapping und Migrations-Marker inkonsistent stehen
- [minor] ShipTrip/Views/Settings/CalendarSyncSettingsView.swift:1 — 401 Zeilen ueber Soft-Limit 400
```

## Go / No-Go

**No-Go** — ein offener Blocker (F01). Kein Datenverlust, kein Sicherheits- oder
DSGVO-Bezug (Kalenderdaten bleiben auf dem Gerät, keine neue Angriffsfläche, keine
neue Verarbeitung), aber der Erstnutzer-Pfad des Features endet in einem grauen
Schalter mit falscher Begründung. Der Fix ist zwei Zeilen; nach F01 ist aus meiner
Sicht Go, F02–F06 reiten im Backlog mit.
