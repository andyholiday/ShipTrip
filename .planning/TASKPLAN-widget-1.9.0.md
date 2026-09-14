# TASKPLAN 1.9.0 — Home-Screen-Widget (v3)

Stand 2026-09-03 · Basis release/1.8.7 = 6547753 · Integrations-Branch
`feature/widget-1.9.0` (Worktree `../ShipTrip-worktrees/widget-1.9.0`,
angelegt). Ziel: `.planning/ZIEL.md` v5.1.

## Tier & Engines

- **Tier: Big** (neues Target + App-Group-Entitlement = Architektur-
  Entscheidung → Gate #4 + ADR; 3 Wellen; parallele Devs in W1 und W2).
  Pre-Run-Gate: Einzel-Agents (Teams-Env nicht gesetzt), Codex `medium`
  als `codex-rescue`-Subagents, Web-Suche aus.
- Codex-Budget Big 6, verbraucht 1 (Gate #1+#4, Job task-mtlhjszu-dctzd7),
  geplant weitere 2: Gate #3 in zwei Scopes (Kern+Publisher /
  Target+Widget-UI). **Pro Diff eine tiefe Prüfung = Quality (Opus)** mit
  eigenen Reproduktionen. Reserve 3.
- Fable: Orchestrierung, Planung, finale Q-Gates (Evaluate nach Gate #3,
  Gate #6). Alle mechanischen Spawns `model: opus`.
- Build-Token: frei · Test-Builds strikt seriell · Wegwerf-Sim im
  Default-Set (nie `--set testing` für xcodebuild) · build-for-testing +
  test-without-building · Codex-Abholung: Companion-Job-ID aus `status`,
  nie die Session-ID.

## Codex Gate #1+#4 (2026-09-03): Plan no-go, Architektur go-mit-Änderungen

Eingearbeitet als v2: (1) T0 liefert die Store-API kompilierbar → T2
baut nur gegen T0, T1 ergänzt Dateien additiv; (2) alle Testnähte
(Kalender/Zeitzone am Resolver **und** Planner, URL-Provider am Store,
Publisher-Protokoll mit Spy) in T0 fixiert; (3) T6 wird Vorgänger von T5,
T3 besitzt die Mutationspfade namentlich — und wird auf **einen**
zentralen Hook umgestellt; (4) T3-Implementierung parallel zu T2, nur der
Test-Build wartet; (5) Publish nur nach erfolgreichem Save, nie bei
`usingTemporaryStore`, Failure-Injection-Test; (6) Stale-Regel + Remote-
Change-Trigger; (7) Writer-Actor, Versions-/Korruptions-Lesestrategie,
Last-known-good; (8) Signing-Gate T7 als Release-Pflichtschritt;
(9) Snapshot auf max. 3 Reisen begrenzt, Reload-Koaleszierung;
(10) Zeitzonenregel + DST-Test + XXL-Abnahme mit adversarial langen Texten.
Opus-Re-Review v2 (2026-09-03): go-mit-Korrekturen → v3: Mutationspfade
korrigiert (Reset-Pfad ist SettingsView.deleteAllData, nicht AppReset;
CruiseListView:395 ist der geteilte CruiseDeletionSequence-Save), T3
besitzt sie exklusiv; Publish-Invariante für scenePhase/Remote-Change;
Route-Kappung 40 + 64-KB-Budget; `modelContainer == nil`-Fall.
`ModelContext.didSave` per Context7 bestätigt (userInfo: inserted/
updated/deletedIdentifiers; Subscription mit `object: mainContext`).

## Fachliche Leitentscheidungen v2 (für alle Devs verbindlich)

1. **Geteilter Code unter `ShipTrip/WidgetShared/`** (Unterordner des
   synchronisierten App-Ordners → kompiliert sofort im App-Target, testbar
   in `ShipTripTests`, keine pbxproj-Änderung). T2 hängt den Ordner ins
   Widget-Target (Exception-Set oder zweite synchronisierte Gruppe); später
   von T1 ergänzte Dateien werden automatisch Mitglied. Regeln für
   WidgetShared: **kein** SwiftData, **kein** SwiftUI, **keine**
   `String(localized:)` — nur Foundation, `Sendable`-Werte, pure
   Funktionen, `Calendar`/`TimeZone` immer injiziert.
2. **Snapshot-Schema `WidgetSnapshot` (Codable, `schemaVersion: Int = 1`,
   T0):** `generatedAt: Date`, `cruises: [CruiseSummary]` — **höchstens 3**
   (die aktive, die nächste geplante, die jüngste vergangene; Demo raus,
   Auswahl auf App-Seite). `CruiseSummary`: `id, title, ship, startDate,
   endDate, route: [StopSummary]`; `StopSummary`: `id, name, country?,
   arrival, departure, sortOrder, isSeaDay`. Keine Bilder, keine
   Koordinaten. `route` je Reise auf **max. 40** `StopSummary` gekappt
   (kanonische Ordnung, für die aktive Reise das Fenster um den aktuellen
   Stopp); Snapshot-Datei < 64 KB, Test am Maximalbestand. Alle Dates
   absolut (UTC-Instant); Kalendertage werden
   **immer in der Gerätezeitzone** des Lesers gerechnet (`Calendar` mit
   `TimeZone` injiziert; Default `.autoupdatingCurrent`). DST-Test: Tag mit
   23/25 Stunden.
3. **Store-API (T0, kompilierbar):** `struct WidgetSnapshotStore:
   Sendable` mit `init(containerURL: URL)`, `static func
   appGroupURL(groupID: String = "group.com.andre.ShipTrip") -> URL?`,
   `func load() -> WidgetSnapshotLoadResult` (`.snapshot(WidgetSnapshot)`
   | `.missing` | `.unreadable` — unbekannte `schemaVersion` oder
   Decode-Fehler = `.unreadable`, nie Crash), `func save(_:) throws`
   (JSON, `.atomic`; scheitert der Write, bleibt die alte Datei = Last-
   known-good). Datei `widget-snapshot.json`. **Serialisierung:** alle
   Writes laufen über `actor WidgetSnapshotWriter` (App-Seite, T3), nie
   direkt.
4. **Zustandsableitung (T1) `WidgetStateResolver.resolve(_ load:
   WidgetSnapshotLoadResult, now: Date, calendar: Calendar) ->
   WidgetState`:** Regeln aus ZIEL K1 (kanonische Ordnung
   `sortOrder`→`arrival`→`id`; zeitlose Einträge; Aktiv bis Ende des
   `endDate`-Tages). `WidgetState` = `.active(ActiveInfo)`,
   `.countdown(CountdownInfo)`, `.idle(IdleInfo)`, `.unavailable(reason:
   .missing | .unreadable | .stale)` — **Stale-Regel:** `generatedAt` älter
   als **14 Tage** → `.unavailable(.stale)` (Widget: „Öffne ShipTrip zum
   Aktualisieren"). Alle Infos sind rohe Daten (Dates, Namen, Int-Tage),
   keine Strings; Wortlaut formatiert das Widget (Countdown-Tabelle von
   `cruiseStartDescription`, Date+Extensions.swift:58, wird im Widget
   nachgebildet — bewusste kleine Duplikation).
5. **Timeline (T1) `WidgetTimelinePlanner.entryDates(for: WidgetState,
   now: Date, calendar: Calendar) -> [Date]`:** Kandidaten = Ankunft/
   Abfahrt des aktuellen und nächsten Stopps, nächste lokale Mitternacht,
   Reisestart, Ende des `endDate`-Tages; sortiert, dedupliziert, `now`
   zuerst, **max. 12**, Horizont ≥ 24 h (auffüllen mit Mitternachten);
   Policy `.after(letzter Eintrag)`. Test: Maximalbestand (3 Reisen × lange
   Route) bleibt ≤ 12 und deckt 24 h.
6. **Publisher (T3, App-Seite):** `protocol WidgetSnapshotPublishing:
   Sendable { func publish() }` (T0, für Spy) · `@MainActor final class
   WidgetSnapshotPublisher: WidgetSnapshotPublishing` mit `init(container:
   ModelContainer, store: WidgetSnapshotStore, reload: @Sendable () ->
   Void)`. **Ein zentraler Hook statt sieben Aufrufstellen:** in
   `ShipTripApp` wird `ModelContext.didSave` beobachtet (per Context7
   dokumentiert; `userInfo` liefert `NotificationKey.inserted/updated/
   deletedIdentifiers`; Subscription **mit `object: container.mainContext`**).
   Offen ist nur, ob sie bei In-Memory-Containern feuert — **T3 weist das
   per Test nach**; feuert sie nicht: Fallback = explizite Aufrufe an
   CruiseFormView.swift:831 (Save), `CruiseDeletionSequence` (CruiseListView.swift:395,
   genutzt von CruiseDetailView.swift:470 und CruiseListView.swift:366),
   ExportImportService+Import.swift:280, DemoDataService.swift:62/:90,
   SettingsView.swift:1050 `deleteAllData` (Alle löschen + App-Reset) —
   **nicht** AppReset.swift (mutiert den Store nicht). Zusätzlich
   `scenePhase == .active` und `NSPersistentStoreRemoteChange`
   (CloudKit-Merge, zu verifizieren). **Invariante:** jeder Trigger
   publiziert erst nach erfolgreichem Save; scenePhase/Remote-Change
   publizieren nur den persistierten Ist-Stand, nie mitten in einem
   offenen Kontext. Alle Trigger laufen durch
   **eine** Koaleszierung (Debounce 1 s, Task-Cancel) → Snapshot bauen
   (Cruises auf MainActor in DTOs mappen) → `WidgetSnapshotWriter.save` →
   `WidgetCenter.shared.reloadAllTimelines()`. **Nie publizieren**, wenn
   `usingTemporaryStore == true` (ShipTripApp.swift:20/:55), `modelContainer
   == nil` (:68) oder in Test-Läufen ohne injiziertes Verzeichnis. Fehler werden geloggt, nie geworfen.
   **Failure-Injection-Test:** Store, dessen `save` wirft → Cruise-Save,
   Export und Reminder-Aufrufe unverändert erfolgreich.
7. **Widget-Target `ShipTripWidget` (T2):** Ordner `ShipTripWidget/`
   (eigene synchronisierte Gruppe), Bundle `com.andre.ShipTrip.Widget`,
   `ShipTripWidget.entitlements` (nur App Group), eigenes
   `Localizable.xcstrings` DE/EN (deutsche Wortlaut-Keys), `Info.plist` mit
   `NSExtensionPointIdentifier = com.apple.widgetkit-extension`, Deployment
   18.5, Swift 6, `DEVELOPMENT_TEAM LH324Y9MG7`, automatisches Signing,
   eingebettet in die App. App-Entitlements + Widget-Entitlements:
   `com.apple.security.application-groups = [group.com.andre.ShipTrip]`.
   `StaticConfiguration`, Familien systemSmall, systemMedium,
   accessoryRectangular, accessoryCircular. Provider liest über
   `WidgetSnapshotStore(containerURL: appGroupURL)` → Resolver → Planner.
8. **Versionierung (T5):** MARKETING_VERSION 1.9.0, CURRENT_PROJECT_VERSION
   29 in **beiden** Targets.
10. **Screenshot-Harness (Winston-Entscheid nach W2b, für ZIEL K2):** Home-
   Screen-Widgets sind im Simulator nicht automatisiert erfassbar. Deshalb
   werden `ShipTripWidget/Views/*.swift`, `WidgetFormatting.swift`,
   `PreviewFixtures.swift` zusätzlich Mitglied des **App-Targets**
   (pbxproj-Exception, `#if DEBUG`-Harness), und die App zeigt unter dem
   Launch-Argument `-widgetPreview` eine Debug-Galerie (Familie × Zustand
   in Widget-Rahmengröße). Ein XCUITest (`WidgetScreenshotUITests`)
   startet sie mit `-UIPreferredContentSizeCategoryName` L und XXL sowie
   Locale de/en, Dark-Mode via `-UIUserInterfaceStyle`... (Fallback:
   `UIView.overrideUserInterfaceStyle` im Harness) und schreibt Bilder nach
   `SHIPTRIP_SCREENSHOT_DIR` (bestehende Konvention). Kontaktbogen per
   `design-sheets`. Harness ist Debug-only und kein Release-Code.
9. **Signing-Gate T7 (Release, nur auf Zuruf):** App Group im Developer-
   Portal an beiden App-IDs, App-Store-Profile für `com.andre.ShipTrip`
   (neu, mit App Group) und `com.andre.ShipTrip.Widget`; vor Upload
   `codesign -d --entitlements :- <App>` und `<Widget.appex>` prüfen, dass
   beide die App Group tragen. Bis dahin sind Simulator-Builds unabhängig.

## DAG v2 (Parallel-First)

| Task | needs | Datei-Eigentum (exklusiv) | Erfolgskriterium |
|------|-------|---------------------------|------------------|
| **T0** Contract | Worktree | `ShipTrip/WidgetShared/WidgetSnapshot.swift`, `WidgetSnapshotStore.swift`, `WidgetSnapshotPublishing.swift` (LE 2, 3, 6-Protokoll) + `ShipTripTests/WidgetSnapshotStoreTests.swift` (load missing/unreadable/v1, save atomic) | Kompiliert im App-Target, Store-Tests grün (Test-Build hält Token), committet |
| **T1** Resolver + Planner | T0 | `ShipTrip/WidgetShared/WidgetStateResolver.swift`, `WidgetTimelinePlanner.swift`, `WidgetState.swift` + `ShipTripTests/WidgetStateResolverTests.swift`, `WidgetTimelinePlannerTests.swift` (**additiv**, T0-Dateien unverändert) | ZIEL K1 + K4 Kanten grün inkl. DST, Stale, Ties, Maximalbestand; returnt `ready_for_test_build` |
| **T2** Target-Scaffold | T0 | `project.pbxproj`, `ShipTrip/ShipTrip.entitlements`, `ShipTripWidget/*` (Bundle, Provider-Stub gegen Store-API, Entitlements, Info.plist, leerer Katalog) | Beide Targets bauen (Sim), Widget zeigt `generatedAt` aus dem Store; WidgetShared Mitglied beider Targets; hält Build-Token W1 |
| **T3** Publisher + Hook | T1 (Impl.), T2 (Test-Build) | `ShipTrip/Services/WidgetSnapshotPublisher.swift`, `WidgetSnapshotWriter.swift`, `ShipTripApp.swift` (Hook + scenePhase), **exklusiv** die Mutationspfade CruiseFormView.swift (Save-Block), CruiseListView.swift (CruiseDeletionSequence + :366), CruiseDetailView.swift:470, ExportImportService+Import.swift (Commit), DemoDataService.swift, SettingsView.swift (`deleteAllData`) — nur falls Fallback nötig, sonst unberührt; `ShipTripTests/WidgetSnapshotPublisherTests.swift` | K3: In-Memory-Container → Save/Delete/Import/Demo/Reset → Snapshot aktuell; didSave-Nachweis; Failure-Injection; Koaleszierung; kein Publish bei Temp-Store |
| **T4** Widget-UI | T1, T2 | `ShipTripWidget/*` (Views, Provider, Katalog) | 4 Familien × 4 Zustände (inkl. unavailable); Previews; DE/EN vollständig; Compile-Smoke nach T3-Token-Rückgabe |
| **T6** Knowledge | T0 (ADR) · Quality-Go W2 (Rest) | `docs/adr/ADR-00N-widget-app-group-snapshot.md`, `CHANGELOG.md`, `docs/features/widget.md`, `CLAUDE.md` | Gate #6 Kern; **Vorgänger von T5** |
| **T5** Integration + Release-Gate | T3, T4, T6 | Version-Bump beide Targets, `.winston-evidence/`, `audit/screenshots/widget-*` | Unit+UI grün mit gate-run.json; 12 DE/Light + EN + Dark + **XXL mit adversarial langen Namen je Familie**; K2, K5 |
| **T7** Signing-Gate + TestFlight | T5, Andre-Zuruf | Portal/Profile, fastlane | LE 9 erfüllt, Upload grün |

**Serielle Kanten, begründet:** T0 → alles: Contract muss kompilierbar
und committet sein (Codex-Blocker 1+2). T1‖T2 parallel (T2 nutzt nur
T0-API). T3 implementiert ab T1, baut/testet erst nach T2 (Compile-Kante
getrennt, Codex 4). T4 nach T2 (Eigentum `ShipTripWidget/*`) und T1
(State). T5 nach T3+T4+T6: einziger Integrations-Build, Gate #6 vorher.

**Build-Token-Reihenfolge:** T0-Test-Build → T2 (Scaffold-Build) →
T1-Test-Spawn → T3 (eigener Unit-Lauf) → T4-Compile-Smoke → T5.

## Prüfungen

- Pro Diff Quality (Opus), frisch, mit eigenen Reproduktionen. Injizierte
  Prüffragen: Bestandsschutz (Store/Schema/Export/Reminder unverändert,
  Failure-Injection real gelaufen?), Swift-6-Isolation (`@Model` nie über
  Aktorgrenzen), Demo-Filter, Zeitzone/DST, Stale, Katalog DE/EN, Datei-
  Eigentum eingehalten, `guard.py sizes`.
- Gate #3 Codex scope-weise: (a) WidgetShared + Publisher + Tests,
  (b) pbxproj/Entitlements + Widget-UI.
- Gate #6 vor T5: CLAUDE.md, ADR, CHANGELOG [1.9.0], Feature-MD.

## Status

- [x] Gate #1+#4 Codex (no-go → v2) · [x] Opus-Re-Review v2 (go-mit-Korrekturen → v3)
- [x] T0 (b241426, 6/6, Snapshot 26 KB; **Abweichung:** `appGroupURL` = Container-Verzeichnis, `store.fileURL` = Dateipfad) · [x] T1 (3769708, 17 Tests, ready) · [x] T2 (1cf5e58) · [x] W1-Testbuild (b8f4055, 27/27) · [x] Quality W1 iter1: NO-GO (F01 Planner-Auffüllung, F02 Tages-Ties von Winston auf Blocker gehoben, F03 Test) → Fix-Spawn läuft; F06 + Import-Fixture ins Backlog · [x] T6 ADR-009 (511c5cb)
- [x] T3 (926e723, ready_for_test_build, kein Fallback laut Doku — didSave-Test entscheidet) · [ ] T4 (läuft; muss F04 Provider-Policy + F05 Katalog abdecken) · [ ] W2-Testbuild · [ ] Quality W2 · [ ] T6 Rest
- [x] Gate #3 (a1) Codex WidgetShared: no-go → Fix-Runde 2 (F1 Idle-Horizont, F3 halboffenes Fenster, F6 Tests); F2 = ZIEL-Regel, F4/F5 Backlog → danach Opus-Re-Review statt 2. Codex-Pass (Budget 2/6 verbraucht)
- [x] T5a (2f391d1/1559a60/085c5c3, 619/619 Unit, Bump 1.9.0/29 beide Targets) · [x] Fix-Runde 2 Kern (d70e44c/eecefe8, 45/45) · [x] Gate #3 (a2) Codex Publisher: no-go → Fix-Runde 3 (F1 Lesekontext, F2 Fetch-Fehler, F3 Generation; F4–F6 Backlog) läuft · [x] Gate #3 (b) Codex Target+UI: no-go, 1 Major = W2b-Finding Rectangular-XXL → von Winston auf Blocker gehoben, Fix im T5b-Screenshot-Spawn (Budget 4/6) · [x] T5b Harness+UITest (ecf818b, ready_for_test_build, 23 Bilder erwartet) · [x] Fix-Runde 3 Publisher (3735daf/3d4d5a1, 49/49) · [x] Opus-Re-Review Fix 2+3: GO-mit-Backlog, 9/9 Codex-Findings erledigt · [x] T5c Rectangular-XXL-Fix + 23 Screenshots (d442c32, UI-Test 4/4) — Sichtprüfung: Small/Medium/Circular K2-Blocker + Idle-Icon fehlt → ZIEL K2 präzisiert (Titel darf kürzen) · [x] Fix UI iter2 (53b0833, 23/23 K2-konform gesichtet) · [x] Kontaktbogen audit/widget-kontaktbogen-1.9.0.html + Artifact · [x] Release-Gate auf 53b0833: Unit 640/640, UI 28/0/15 (Skips env-gated), Evidenz 20260903T164615Z…165816Z · [x] Gate #6 Nachzug (0eb988b) — **Stand: runtime-verifiziert, Release nur auf Zuruf (T7)** · [ ] Gate #3 (b) · [ ] Gate #6 · [ ] T7 (Zuruf)
