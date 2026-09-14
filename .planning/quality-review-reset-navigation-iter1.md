# Review — Navigation nach App-Reset (Fix-Runde 3)

- **Iteration**: 1 / 3
- **Reviewer**: quality-agent (frischer Spawn)
- **Datum**: 2026-08-25
- **Prüfgegenstand**: Worktree `ShipTrip-worktrees/fix-reset-navigation`, Branch `fix/reset-navigation`, `fe64080..b570ada`
- **Verdikt**: **approve / GO**
- **Stats**: critical: 0, major: 1, minor: 3 — **Blocker: 0**, Backlog: 4
- **Geladene Skills**: `code-review`, `xctest-ios`, `swift-standards`

## Summary

Der Fix trifft die Ursache genau: Das Onboarding ist ein `.fullScreenCover` **auf**
`MainTabView` (`ShipTripApp.swift:191-198`), nicht dessen Ersatz — deshalb überleben
`selectedTab` und der Einstellungs-`NavigationStack` den Reset, und deshalb braucht es
ein explizites Signal. `SettingsView` hat einen `NavigationStack` **ohne** `path`-Binding
(`SettingsView.swift:52`); `.id()` ist damit tatsächlich der einzige Weg, den Stack ohne
Navigations-Umbau zu leeren. Die Kommentare im Diff beschreiben das korrekt.

Delta ist minimal (3 Dateien, +58/-2), stilkonform, ohne Kollateralschaden. Evidenz des
Developers ist echt: das Rot ist ein **Verhaltens-Rot** (`AppResetUITests.swift:123`,
„Nach dem Reset steht nicht der Reisen-Tab vorn"), kein Compile-Fehler. Eigene
Regressionsrunde grün. Kein Blocker.

Einziger substanzieller Befund: die **zweite Hälfte des Fixes (`settingsIdentity`) ist
faktisch ungetestet** — nachweisbar, nicht vermutet (F01).

## Findings

| ID  | Severity | Blocker | File:Line | Kategorie | Titel |
|-----|----------|---------|-----------|-----------|-------|
| F01 | major | **nein** | ShipTripUITests/AppResetUITests.swift:128-131 | tests | Assertion beweist den Stack-Neuaufbau nicht |
| F02 | minor | nein | ShipTrip/Utilities/AppReset.swift:39 | design | `AppReset.run` ist nicht mehr nebenwirkungsfrei |
| F03 | minor | nein | .winston-evidence/20260825T184959Z/gate-run.json | evidenz | Grün-Artefakt trägt den Repro-Commit |
| F04 | minor | nein | ShipTrip/Views/Settings/SettingsView.swift:1079-1082 | robustheit | `resetApp` ohne Doppel-Tap-Nachgarde |

### F01 — Assertion beweist den Stack-Neuaufbau nicht
- **File**: `ShipTripUITests/AppResetUITests.swift:128-131`
- **Severity**: major · **Blocker: nein** → Backlog
- **Problem**: `XCTAssertFalse(app.navigationBars["Daten verwalten"].exists)` wird
  ausgewertet, **während der Reisen-Tab vorn steht**. Der Inhalt eines nicht gewählten
  `TabView`-Kindes liegt nicht in der Accessibility-Hierarchie — die NavigationBar wäre
  also so oder so weg. Streicht man `.id(settingsIdentity)` (`MainTabView.swift:55`),
  bleibt der Test grün; nur die Tab-Assertion (`119-127`) geht rot. Damit deckt der
  grüne Lauf nur `selectedTab = 0` ab, nicht das Leeren des Stacks.
  `testAppZuruecksetzenSetztDasFarbschemaAufSystemZurueck:84-86` hilft nicht: das
  `if back.waitForExistence(timeout: 3) { back.tap() }` toleriert beide Zustände.
- **Warum kein Blocker**: Der vom Nutzer gemeldete Defekt (nach dem Onboarding direkt
  auf der Reset-Einstellungsseite zu landen) ist behoben und runtime-verifiziert. Die
  ungedeckte Hälfte ist Nachsorge; ihr Ausfallmodus ist ein veralteter Nav-Stack beim
  *späteren* Antippen von „Mehr" — verwirrend, aber kein Datenverlust und kein
  gebrochener Kernfluss.
- **Fix (für den Backlog)**: nach `123-127` ergänzen —
  ```swift
  app.tabBars.buttons["Mehr"].tap()
  XCTAssertTrue(
      app.navigationBars["Einstellungen"].waitForExistence(timeout: 10),
      "Der Einstellungs-Stack wurde nicht auf die Wurzel zurueckgesetzt"
  )
  XCTAssertFalse(
      app.navigationBars["Daten verwalten"].exists,
      "Nach dem Reset liegt wieder die Datenverwaltung obenauf"
  )
  ```

### F02 — `AppReset.run` ist nicht mehr nebenwirkungsfrei
- **File**: `ShipTrip/Utilities/AppReset.swift:39` (Doku-Zusage: `:5-8`)
- **Severity**: minor · Blocker: nein
- **Problem**: Der Dateikopf verspricht eine „UI-freie" Stelle. Seit `b570ada` postet
  `run` auf die prozessglobale `NotificationCenter.default`.
  `ShipTripTests/CalendarSyncServiceMigrationTests.swift:101` ruft `run` direkt auf und
  löst den Post im Test-Host mit aus. Heute folgenlos (kein Observer im Unit-Host),
  aber der Vertrag hat sich verschoben.
- **Fix**: Halbsatz im Dateikopf nachziehen („…und meldet den Abschluss").

### F03 — Grün-Artefakt trägt den Repro-Commit
- **File**: `.winston-evidence/20260825T184959Z/gate-run.json`
- **Severity**: minor · Blocker: nein
- **Problem**: `"commit": "c4e4e27"` (Repro), obwohl der Lauf den Fix im Arbeitsbaum
  hatte. Erklärt und harmlos: Grün endete 20:51:15, `b570ada` wurde 20:51:33 committet
  — 18 s später (test-then-commit). Nicht rekonstruierbar aus dem Artefakt allein.
- **Fix**: erst committen, dann Grün fahren — oder `--commit` explizit setzen.
- **Entkräftet durch**: eigener Lauf auf `b570ada`, grün (siehe unten).

### F04 — `resetApp` ohne Doppel-Tap-Nachgarde
- **File**: `ShipTrip/Views/Settings/SettingsView.swift:1079-1082`
- **Severity**: minor · Blocker: nein
- **Problem**: `exportData:930` und `handleImport:968` garden gegen einen am `.disabled`
  (`:869`) vorbeigerutschten Doppel-Tap nach; `resetApp` vertraut allein auf das
  `.disabled`. Folgenlos, weil der Handler idempotent ist (`selectedTab = 0`,
  `settingsIdentity += 1` zweimal ist derselbe Zustand) — aber die Asymmetrie bleibt.

### Nicht neu, bereits im Backlog
`SettingsView.swift` = 1105 Zeilen (Hard-Limit 500). **Keine** der drei geänderten
Dateien reisst ein Limit: `guard.py sizes` → `ok (3 geprueft, 0 Soft-Warnungen)`, exit 0.

## Prüffragen

**1 — Notification-Kopplung.** `Notification.Name("ShipTrip.appResetDidRun")` ist der
einzige Custom-Name im Repo; `AppReset.swift:39` ist der einzige Poster,
`MainTabView.swift:65` der einzige Observer — keine Kollision, kein zweiter Auslöser.
`MainTabView` existiert genau einmal produktiv (`ShipTripApp.swift:180`; der zweite Treffer
ist `#Preview`) → genau eine Subscription, keine Doppelverarbeitung. Doppeltes Feuern nur
per Doppel-Tap auf „Zurücksetzen" denkbar; der Handler ist idempotent. **Main-Thread ist
gesichert**: `enum AppReset` ist `@MainActor`, `post` stellt synchron auf dem Poster-Thread
zu, `.onReceive` läuft folglich auf Main — korrekt für UI-Mutation.

**2 — `.id()`-Neuaufbau.** Verloren gehen: `showingApiKeySheet`/`inputKey`,
`hasApiKey`, `hasDemoData` (beide in `.onAppear:214-217` neu abgeleitet), alle
Alert-/Sheet-Flags der `DataManagementView` (`761-770`) sowie `cloudSyncStatus` (`:46`),
dessen `.task` einen neuen CloudKit-`accountStatus()`-Roundtrip startet. Nach einem
Komplett-Reset ist **ausnahmslos genau das gewollt** — es ist der Zustand, der ohnehin weg
soll. Seiteneffekt-Risiko bei laufenden Präsentationen: **keins**. Zum Reset-Zeitpunkt kann
nur der eigene Bestätigungs-Alert (`885-892`) offen sein; Export/Import sind über
`.disabled` (`:869`) gesperrt, das API-Key-Sheet liegt auf der Stack-Wurzel und deckt den
Reset-Button ab, alle übrigen Sheets hängen an Geschwister-Zweigen. Dass kein Modal hängen
bleibt, ist belegt, nicht angenommen: die drei grünen UI-Läufe gehen genau diesen Weg und
bedienen danach die Tab-Leiste. Die Reihenfolge in `run` hilft zusätzlich — der
Onboarding-Schalter (`AppPreferencesReset.swift:43`) fällt **vor** dem Post, das Cover steht
also schon, wenn Tab-Wechsel und Neuaufbau dahinter passieren.

**3 — „Intro erneut zeigen".** **Bestätigt: der Fix fasst diesen Pfad nicht an.**
`SettingsView.swift:185-189` ruft `OnboardingPresentation.requestReplay(in: .standard)`
direkt auf, nicht `AppReset.run` → kein Post → kein Tab-Wechsel, kein Neuaufbau. Der
Nutzer landet wie bisher in den Einstellungen. Die Asymmetrie ist sachlich richtig: der
Button sitzt auf der **Wurzel** des Einstellungs-Stacks, es gibt nichts abzuwickeln, und
„Intro nochmal ansehen" ist eine Vorschau — dorthin zurückzukehren, wo man sie gestartet
hat, ist das erwartete Verhalten. Kein Fix.

**4 — Test-Anker.** Ja, ordnungs- und store-unabhängig: `app.tabBars.buttons["Reisen"]` mit
`isSelected == true` (`:112-127`) hängt an der Tab-Leiste, nicht am Empty-State. Der Test
startet nur mit `-uiTestingCompleteOnboarding` (ohne Demo-Daten) und liest keinen
Store-Inhalt — immun gegen den Suite-Reihenfolge-Fehler aus dem bestehenden Backlog-Eintrag
zu `OnboardingSampleTripUITests`. `XCTWaiter` statt `sleep` ist die richtige Form gegen die
Cover-Animation (xctest-ios-Anti-Pattern vermieden).

**5 — Was macht der Fix kaputt?** Nichts Auffindbares, und das ist gemessen: Fix-Runde 1+2
laufen grün mit — Kalender-Spiegelung (`AppResetCalendarCleanupTests`), Präferenzen
(`…SetztDasFarbschemaAufSystemZurueck`), Store + Onboarding-Cover
(`…LeertDieDatenUndZeigtDasOnboardingWieder`), dazu 19 Swift-Testing-Tests inkl.
`OnboardingPresentationTests`/`OnboardingModelTests`. Die Onboarding-Flag-Mechanik ist
unangetastet (`AppPreferencesReset.swift:43` setzt weiter `false` statt zu löschen); der
Keychain-Pfad ebenso (`resetApp:1080` → `deleteAllData(alsoDeleteApiKey: true)`). Kein
Release-Pfad setzt Präferenzen/Onboarding zurück **ohne** zu posten; die drei
`#if DEBUG`-Nahten laufen in `init()`, bevor eine View existiert — dort braucht es kein
Signal.

## Test-Run-Status

Eigene, change-scoped Regression (eine Runde), Wegwerf-Simulator „ci-quality-nav"
(iPhone 17 / iOS 26.5, `privacy grant calendar`), `build-for-testing` +
`test-without-building` über `.xctestrun`:

| Suite | Ergebnis |
|---|---|
| `ShipTripUITests/AppResetUITests` (3 Tests) | 3 passed, 0 failures |
| `AppResetCalendarCleanupTests` + `OnboardingPresentationTests` + `OnboardingModelTests` | 19 Tests in 3 Suites, alle passed |
| Gesamt | `** TEST EXECUTE SUCCEEDED **`, Gate-Exit 0 |

- `evidence_path`: `/Users/andre-studio/Documents/0.Projekte/ShipTrip-worktrees/fix-reset-navigation/.winston-evidence/20260825T185511Z/gate-run.json` (commit `b570ada`, status `verified`)
- Developer-Evidenz geprüft: Rot `…184655Z` exit **65**, Verhaltens-Rot bei
  `AppResetUITests.swift:123` (3 Tests, 1 Failure) — **kein** Compile-Rot. Grün
  `…184959Z` exit **0** (3 UI-Tests + 1 Swift-Testing-Suite). Kommandos stammen aus dem
  Kanon, keine Weichspüler.
- `guard.py sizes --files` (3 geänderte Dateien): exit 0.
- Cleanup: Wegwerf-Sim per `trap` gelöscht, `simctl --set testing delete all`, DerivedData entfernt.

## Verdikt

**GO — 0 Blocker.** Der gemeldete Defekt ist behoben und runtime-verifiziert, die
Fix-Runden 1+2 bleiben intakt. F01–F04 gehen ins Backlog.
