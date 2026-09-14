# Review — Reset-Komplettierung (Delta-Re-Review)

- **Iteration**: 2 / 3
- **Reviewer**: quality-agent (frischer Spawn)
- **Datum**: 2026-08-25
- **Prüfgegenstand**: Worktree `ShipTrip-worktrees/fix-reset-complete`, Branch `fix/reset-complete`, Delta `92ac699..fe2b897`
- **Verdikt**: approve
- **Stats**: critical 0, major 0 (neu), minor 3 — Blocker 0, Backlog 3

## Summary

Fokussiertes Delta-Review, kein Voll-Re-Review. Beide Blocker aus Iteration 1 sind
tragfähig behoben; das Delta bricht nichts. Der deklarierte Refactor (`AppReset`)
ist verhaltensgleich, verdrahtet und im Umfang angemessen. Eine eigene,
change-scoped Regressionsrunde auf einem Wegwerf-Simulator ist grün.

## Status der Findings aus Iteration 1

| ID (iter1) | Status | Beleg |
|-----|--------|-------|
| F01 Kalendertermine verwaist | **resolved** | `ShipTrip/Utilities/AppReset.swift:28` — `try? calendarSync.removeAllManagedEvents()` **vor** `AppPreferencesReset.run`; neuer Test `AppResetCalendarCleanupTests` rot→grün |
| F02 Alert verschweigt Key/Einstellungen | **resolved** | `SettingsView.swift:891` + `Localizable.xcstrings` — DE-Key ersetzt, EN `state: translated`, kein verwaister Key, konsistent mit Footer `SettingsView.swift:865` |
| F03–F06 | unverändert im Backlog | keine Regression durch das Delta |

## Bewertung der deklarierten Abweichung (Extraktion statt Einzeiler)

**(a) Verhaltensgleich — ja.** Der Test-Commit `ded0449` legt `AppReset.run` als
exakt `AppPreferencesReset.run(in: defaults)` an, 1:1 der alte `resetApp()`-Ablauf;
`fe2b897` ergänzt ausschließlich die eine Zeile davor. Nichts verloren. Reihenfolge
korrekt und im Doc-Kommentar (`AppReset.swift:18-21`) begründet: Der Präferenz-Reset
entfernt `CalendarSyncPreferences.enabledKey`, danach räumt niemand mehr ab. Das
Onboarding-Flag bleibt auf `false` — es läuft weiter über
`OnboardingPresentation.requestReplay` in `AppPreferencesReset.run`, unberührt.

**(b) Verdrahtet — ja.** `SettingsView.swift:1081` ruft
`AppReset.run(calendarSync: .shared, defaults: .standard)`; kein toter Testpfad.
`AppPreferencesReset.run` hat außerhalb von `AppReset` keinen weiteren Produktivaufrufer.

**(c) Scope — angemessen.** 31 Zeilen, ein Enum, eine Funktion, keine Zusatz-API,
kein Protokoll, keine Injektionsschicht. Die Begründung trägt: `resetApp()` ist
`private` in einer View und wäre nur über den langsamen UI-Pfad prüfbar — die
Reihenfolgen-Zusage ist genau das, was ein Unit-Test halten muss. Kein Über-Refactoring.

## Neue Findings (alle Backlog, kein Blocker)

| ID  | Sev   | Blocker | File:Line | Kategorie | Titel |
|-----|-------|---------|-----------|-----------|-------|
| G01 | minor | nein | `ShipTrip/Views/Settings/SettingsView.swift:865,891` | UX / Ehrlichkeit | Alert und Footer nennen die Kalender-Aufräumung nicht |
| G02 | minor | nein | `ShipTrip/Utilities/AppReset.swift:28` | correctness / Edge | Bei entzogenem Kalenderzugriff bleibt die Termin-Zuordnung stehen |
| G03 | minor | nein | `ShipTrip/Utilities/AppReset.swift:27` | tests | Produktions-Verdrahtung (`.shared` / `.standard`) nicht behavioral gedeckt |

### G01 — Alert und Footer nennen die Kalender-Aufräumung nicht
Der Reset entfernt jetzt Termine aus dem **Kalender des Nutzers**, also Daten außerhalb
der App. Alert („Alle Reisen, dein KI-API-Key und alle Einstellungen") und Footer
schweigen dazu. „wie frisch installiert" deckt es implizit; explizit wäre ehrlicher.
Fix: Halbsatz „… und die ShipTrip-Termine verschwinden aus deinem Kalender" in beiden
Strings, EN nachziehen.

### G02 — Termin-Zuordnung überlebt einen Reset ohne Kalenderzugriff
`CalendarSyncService.removeAllManagedEvents()` wirft bei
`authorizationStatus != .fullAccess` **vor** `managedEventIdentifiers = [:]`
(`CalendarSyncService.swift:210,222`); `try?` schluckt das. `AppPreferencesReset`
klammert die Zuordnung bewusst aus („Buchhaltung, keine Einstellung"). Nach einem
Reset ohne Zugriff bleiben also Einträge auf gelöschte Cruise-UUIDs stehen. Folgenlos,
solange `synchronize` verwaiste Einträge nicht wiederbelebt — aber unsauber.
Fix-Idee: Zuordnung im `catch`/`defer` in `AppReset` leeren.

### G03 — Verdrahtung nicht behavioral gedeckt
`AppResetCalendarCleanupTests` injiziert Fixture-Service und -Defaults; dass die
Produktion `.shared`/`.standard` reicht, prüft kein Test. Ein sichtbarer Einzeiler —
tragbar, aber notiert.

### Vorbestand (nicht durch das Delta verursacht)
`guard.py sizes` → `SettingsView.swift: 1105 Zeilen (> 500 hart)`. Das Delta ändert
8 Zeilen, netto ±0. Bereits als Backlog-Eintrag F05 („1106 Zeilen") geführt — kein
neues Finding.

## Evidenz

**Developer-Artefakte geprüft (Zahlen aus den Logs, nicht aus Prosa):**
- Rot: `.winston-evidence/20260825T182527Z/gate-run.json` — commit `ded0449`,
  `status: failed`, exit **65**. Log: `Expectation failed:
  (fixture.eventCount(...) → 1) == 0` an `CalendarSyncServiceMigrationTests.swift:103`
  und `.isEmpty → false` an `:107`. **Verhaltens-Rot, kein Compile-Rot** — der
  Repro-Test greift genau F01.
- Grün: `.winston-evidence/20260825T182715Z/gate-run.json` — commit `fe2b897`,
  `status: verified`, exit **0**, 23 Tests in 4 Suiten + 2 UI-Tests.
- Beide Kommandos sind `xcodebuild test-without-building -xctestrun …` mit
  explizit selektierten Suiten. Kein Weichspüler-Kommando, kein `-scheme`-Test.

**Eigene Regressionsrunde (einmal, change-scoped):**
- `evidence_path`: `/Users/andre-studio/Documents/0.Projekte/ShipTrip-worktrees/fix-reset-complete/.winston-evidence/20260825T183233Z/gate-run.json`
- `regression` exit **0**, `status: verified`.
- Swift Testing: **23 Tests in 4 Suiten** grün (App-Reset — Kalender-Spiegelung,
  Kalender-Migration, Onboarding – Sichtbarkeit, Onboarding – Flow und Soft-Ask).
- XCTest: **2 von 2** `AppResetUITests` grün (beide Methoden einzeln selektiert,
  gegen den stillen `-only-testing`-Verwurf aus F06).
- Wegwerf-Simulator `ci-quality-reset2` (iPhone 17 / iOS 26.5), eigens erstellt,
  `privacy grant calendar`, danach gelöscht; `simctl --set testing delete all` und
  DerivedData bereinigt.

## Triage-Ergebnis

Kein offener Blocker. G01–G03 gehen ins Backlog, nicht in eine Fix-Runde.

**Go/No-Go: GO.**
