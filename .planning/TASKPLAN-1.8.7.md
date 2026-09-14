# TASKPLAN 1.8.7 — Kalender-Paket

Stand 2026-09-02 · Basis release/1.8.6 = f6cdf05 · Integrations-Branch
`feature/kalender-paket-1.8.7` (Worktree `../ShipTrip-worktrees/kalender-1.8.7`).
Ziel: `.planning/ZIEL.md` v4 (verifiziert, go-mit-Korrekturen eingearbeitet).

## Tier & Engines

- **Tier: Medium** (1 Domain Kalender-Sync, 2 Dev-Wellen, parallele Devs →
  Pre-Run-Gate: Einzel-Agents, Teams-Env nicht gesetzt).
- Codex-Budget 3: Gate #1 (Plan) · Gate #3 (2 Scopes: Service-Härtung+Ort /
  Modus+Settings). **Pro Diff eine tiefe Prüfung = Quality (Opus)** mit
  eigenen Reproduktionen — Codex bleibt für #1/#3.
- Fable: Orchestrierung + Evaluate. Alle Spawns `model: opus`.
- Kein Gate #4: keine Architektur-/Datenmodell-Entscheidung (Präferenz-Enum
  wächst um einen Fall, kein SwiftData-Schema-Change).

## Codex Gate #1 (2026-09-02): no-go → Plan-Revision v2

Findings eingearbeitet (Thread 01a0625b): (1) `.none`-Fall + Service-Tests
für structuredLocation/isDemo/Opt-in-Reconcile; (2) Bestands-Migration über
live Trip-Marker; (3) breite Dedup-Suche nur im Sync-Kontext, nie während
Migration, nie Umhängen; (4) persistentes Migrations-Journal; (5) T2 in T1
gefaltet, T1-UI als Nachwelle, Datei-Eigentümer je Welle; (6) EventStore-
Fassade + injizierbarer Reconcile-Trigger; (7) Gate #6 definiert.
Re-Prüfung des revidierten Plans: frischer Opus-Reviewer gegen die
Codex-Findings → go-mit-Korrekturen, eingearbeitet als v3 (Codex-Budget
bleibt für Gate #3).

## Fachliche Leitentscheidungen v3 (für alle Devs verbindlich; v2 + Opus-Plan-Review 2026-09-02)

1. **Modus-Modell:** `CalendarSyncMode` bekommt `itineraryOnly` (= neuer
   Default) und `none` (beide Schalter aus → keine Events, verwaiste werden
   entfernt; UI-Hinweis „Es werden keine Einträge angelegt"). **Es gibt genau
   EINEN Default-Leseort: `CalendarSyncPreferences.mode`** — Settings-
   AppStorage und `CalendarSyncObserver` lesen ohne eigenen Default-Wert
   darüber (T1 passt Observer an; der AppStorage-Default in
   `CalendarSyncSettingsView` wird von T5 gestrichen, nicht von T1). UI:
   zwei Schalter „Stopps eintragen" / „Gesamte Reise als Eintrag",
   Abbildung auf die vier Enum-Fälle. Key `calendarSyncMode` bleibt.
2. **Bestands-Migration (einmalig, idempotent, Marker-Key
   `calendarSyncModeMigratedV2`), läuft im Kopf von `synchronize` UND von
   `hasManagedEvents`/Settings-Öffnen — nie an Aufrufstellen:** Mode-Key
   gesetzt → unverändert, Marker setzen. Nicht gesetzt → Bestandsnachweis
   **ausschließlich über das persistierte Mapping**: existiert ein Key mit
   Suffix `/trip`, dessen `event(withIdentifier:)` noch ein Event liefert
   (egal in welchem Kalender) → `tripOnly`; sonst `itineraryOnly`. **Kein
   EventKit-Predicate, kein Zeitfenster** (Predicate ist auf 4 Jahre
   gekappt). Kein Zugriffsrecht → keine Entscheidung, Marker nicht setzen.
3. **Ort:** `CalendarEventDraft.coordinate: CLLocationCoordinate2D?` (nil
   bei Null-Insel/Seetag/Trip). Service setzt `EKStructuredLocation`
   (title = bisheriger Text, `geoLocation = CLLocation`), sonst
   `event.location = text`.
4. **Sync-Loop ohne Umhängen:** `event.calendar = targetCalendar` nur noch
   für **neu erzeugte** Events (`EKEvent(eventStore:)` braucht einen
   Kalender). Ein per Mapping/Marker gefundenes Event in einem **anderen**
   Kalender wird ignoriert: neues Event im Ziel anlegen, alten Identifier ins
   Journal (5), nach Commit löschen. **Dedup:** Ziel-Kalender-Suche wie
   bisher; breite Marker-Suche über alle beschreibbaren Kalender nur im
   `synchronize`-Kontext (nie in `migrateManagedEvents`) und nur für Keys
   ohne Mapping-Eintrag.
5. **Journal (ein Mechanismus für Kalenderwechsel UND Fremd-Kalender-
   Events):** neue Events im Ziel anlegen + committen → alte Identifier in
   UserDefaults-Key `calendarSyncPendingRemovalIdentifiers` journalisieren
   und **aus dem Mapping entfernen** → löschen + committen → Journal leeren.
   Nachlauf beim nächsten Service-Start zuerst; idempotent (nil-Lookup =
   erledigt). Scheitert das Anlegen, bleibt der Bestand unangetastet.
6. **EventStore-Fassade (Wrapper, keine Fabrik-Attrappe):** Protokoll
   `CalendarEventStoring` mit genau den genutzten Methoden: `calendars(for:)`,
   `calendar(withIdentifier:)`, `defaultCalendarForNewEvents`,
   `events(matching:)`, `predicateForEvents(withStart:end:calendars:)`,
   `event(withIdentifier:)`, `save(_:span:commit:)`, `remove(_:span:commit:)`,
   `commit()`, `reset()`, `requestFullAccessToEvents()`, `authorizationStatus`.
   `EKEventStore` erfüllt es per Extension. Test-Double = Wrapper um einen
   **echten** `EKEventStore` (Objekt-Fabrik für `EKEvent`/`eventIdentifier`),
   der nur save/remove/commit auf Befehl scheitern lässt. Service-Init
   nimmt `any CalendarEventStoring`. `EKEvent(eventStore:)` braucht weiter
   den echten Store → Fassade bietet `makeEvent()`.
7. **Rollback sichtbar:** Migrations-/Rollback-Ablauf aus `migrateNow` in
   `CalendarMigrationCoordinator` (Services/), testbar mit der Fassade;
   Rollback-Fehler → Alert in der View (String Catalog DE/EN).
8. **Erinnerungs-Reconcile:** `NotificationSettingsView` bekommt einen
   injizierten `reconcile: () async -> Void` (Default = bestehender
   `NotificationReconciler`-Lauf wie CruiseListView:121) und ruft ihn bei
   Änderung der drei Erinnerungs-Keys. Rot-Beweis über Test-Double-Closure.

## DAG / Wellen v2 (Wave = Anzeige, `needs:` entscheidet)

| ID | Task | needs | Dateien (alleiniger Eigentümer in der Welle) | Tests | Build-Token |
|----|------|-------|-----------------------------------------------|-------|-------------|
| **T0** | Refactor: `CalendarSyncSettingsView` (+OperationState) und `NotificationSettingsView` in eigene Dateien, kein Verhaltens-Change | – | SettingsView.swift, Views/Settings/CalendarSyncSettingsView.swift (neu), Views/Settings/NotificationSettingsView.swift (neu) | keine neuen; Suite grün vor/nach (TB0) | nein |
| **T3** | Service-Härtung: Fassade (6) + Sync-Loop ohne Umhängen + Dedup (4) + Journal (5) + F15/F16 | – | CalendarSyncService.swift, Services/CalendarEventStoring.swift (neu), CalendarSyncServiceMigrationTests.swift, Tests/CalendarEventStoreDouble.swift (neu), neue CalendarSyncHardeningTests.swift | Rot-Beweise: Duplikat nach Mapping-Verlust · Datenverlust bei fehlschlagendem Neu-Anlegen · Journal-Nachlauf nach Abbruch | **ja** |
| **TB0** | Merge T0+T3 → Integration, volle Unit-Suite | T0,T3 | – | evidence.py | ja |
| **Q0** | Quality T0/T3 mit eigenen Repros | TB0 | – | – | nein |
| **T1** | Modus (1) + Bestands-Migration (2) + Ort (3) + Service-Tests structuredLocation/isDemo/Opt-in-Reconcile — **ohne UI** | TB0 | CalendarEventPlanner.swift, CalendarSyncService.swift, CalendarSyncObserver.swift, CalendarSyncPlannerTests.swift, neue CalendarSyncModeMigrationTests.swift | Default itineraryOnly · Migration 4 Fälle (Key gesetzt / live Trip-Marker / kein Marker / kein Zugriff) · Koordinate/Fallback · isDemo-Filter · Modus-Wechsel entfernt/erzeugt Events | nein |
| **T4** | Rollback-Coordinator (7) + Erinnerungs-Reconcile (8) | TB0 | Services/CalendarMigrationCoordinator.swift (neu), CalendarSyncSettingsView.swift, NotificationSettingsView.swift, Localizable.xcstrings, neue Tests | Rollback ok/fehlgeschlagen (Fassade) · Rot-Beweis Reconcile bei Toggle/Offset | **ja** |
| **TB1** | Merge T1+T4, volle Unit-Suite | T1,T4 | – | evidence.py | ja |
| **T5** | Settings-UI: zwei Schalter + Hinweis + Strings (1) | TB1 | CalendarSyncSettingsView.swift, Localizable.xcstrings | UI-Durchklick im TB2 | nein |
| **TB2** | Merge T5, volle Unit-Suite + Kalender-UI-Durchklick (bestehender XCUITest Kalenderdialog + neuer Schalter-Durchklick) | T5 | – | evidence.py | ja |
| **Q1** | Quality T1/T4/T5 mit eigenen Repros | TB2 | – | – | nein |
| **K** | Knowledge incremental: CHANGELOG [Unreleased], docs/features/kalender-sync.md, CLAUDE.md-Check | Q0 (parallel zu T1/T4), Nachtrag nach Q1 | docs/, CHANGELOG.md | – | nein |
| **G3** | Codex Gate #3, 2 Scopes (Service-Härtung+Modus / Coordinator+UI) | Q1, K | – | – | nein |
| **G6** | **Knowledge Gate #6** = Winston prüft: CLAUDE.md aktuell · CHANGELOG-Eintrag vorhanden · Feature-MD-Acceptance-Status = realer Stand · kein ADR nötig (keine Architektur-Entscheidung; Fassade ist Test-Naht) | K, G3 | – | – | nein |
| **R** | Release 1.8.7 (Version, Changelog-Schnitt, Build-Nr.) — **nur auf Andres Zuruf** | G6 | – | volle Suite | ja |

**Serielle Kanten, begründet:** T1/T4 → TB0: beide bauen auf der Fassade
(T3) und den extrahierten Views (T0). T5 → TB1: T5 schreibt dieselbe View wie
T4 und dieselben Strings — Eigentümer-Wechsel erst nach Merge. Test-Builds
seriell (Ledger). Parallel: T0 ∥ T3 (disjunkte Dateien), T1 ∥ T4 (disjunkte
Dateien; T4 ist alleiniger xcstrings-Eigentümer in Wave 1), K ∥ T1/T4.

**Tier-Hinweis:** 2 Dev-Wellen + eine Mini-Nachwelle (T5, ~50 Zeilen) —
bleibt Medium; Codex-Budget 3 (1 verbraucht).

**Worktrees:** Branch `kp/<id>` ab Integrations-Branch, Pfad
`../ShipTrip-worktrees/kp-<id>` (absolut im Prompt). Devs committen, pushen nie.
kp-t2 wird entfernt (T2 in T1 gefaltet).

**Skills je Dev-Spawn:** swift-ios, swift-standards, swiftui, xctest-ios.
Quality: code-review, xctest-ios. Test-Build: xctest-ios + Projekt-Kanon
(build-for-testing / test-without-building, `simctl privacy grant calendar`).

## Statusvokabular-Ziel

Ergebnis „runtime-verifiziert" (TB1 + Q1 grün mit gate-run.json). Release
„release-verifiziert" erst nach R.

## Backlog-Kandidaten (kein Fix in diesem Run, außer billig im Scope)

F06 Alert über Picker · F07 Plural · F08 Doc-Kommentar · F13 accessDenied
ohne Restore · F14 EKEventStoreChanged · `CalendarSyncObserver` schluckt
Fehler mit `try?` (neu gesehen, Explore-Karte).

## Status 2026-09-02 (Run-Ende, Session 11)

Alle Tasks T0–T5, TB0–TB2, Q0/Q1a/Q1b, K/K2/K3, G3 (2 Scopes), FIX1+FIX2
(Codex-Blocker: Schalter vor Migrations-Entscheidung bedienbar) erledigt.
Integrations-Branch `feature/kalender-paket-1.8.7` = **975bae5** (23 Commits
ab f6cdf05, nicht gepusht). Endstand: Unit 580/580, `KalenderUmfangUITests`
1/1, Evidenz `.winston-evidence/20260902T153039Z/gate-run.json` →
**runtime-verifiziert**. Gate #6 grün. Codex-Budget 3/3 verbraucht.
Offen: R (Release-Schnitt 1.8.7, Build 28) nur auf Andres Zuruf; UI-Durchklick
auf echtem Gerät nicht gelaufen (nur Sim).

## Release 2026-09-02 (Andre-Zuruf)

Schnitt **6547753** = `release/1.8.7` = Tag **v1.8.7** (1.8.7 / Build 28).
Release-Gate: 580/580 Unit, UI 28/0/11 (Skips dokumentiert, keine Flake),
Evidenz `.winston-evidence/20260902T173349Z/gate-run.json`. Archiv/Export
(manuelles Signing, Profil „ShipTrip App Store 1785864156") + pilot-Upload
71 s, ASC buildUploads 1.8.7/28 COMPLETE → **release-verifiziert**.
Offen (Andre): `git push origin release/1.8.7 v1.8.7` (Classifier blockt
Winston-Push); ASC-Processing sichten; What-to-Test-Text optional.
