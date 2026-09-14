# Review — Kalenderwechsel überträgt bestehende Reisetermine

- **Iteration**: 1 / 3
- **Reviewer**: quality-agent (frischer Spawn)
- **Datum**: 2026-08-04
- **Basis**: HEAD `52b22a9` + uncommittete Änderungen (nur Scope-Pfade)
- **Verdikt**: request-changes (GO-WITH-CHANGES — 1 Blocker)
- **Stats**: critical: 0, major: 5, minor: 4 — davon **Blocker: 1**, Backlog: 8
- **Evidenz**: `.winston-evidence/20260804T155612Z/gate-run.json` — build exit 0, tests exit 0

## Summary

Der Fix ist im Kern sauber gebaut: die Entscheidung ist in einen reinen,
testbaren Typ (`CalendarTargetChangePlanner`) ausgelagert, der Picker schreibt
`calendarIdentifier` erst nach Bestätigung, und das alte
`.onChange(of: calendarIdentifier)` ist entfernt — damit sind Kriterium 1, 2
und 4 am Code nachweisbar erfüllt, ohne Rückstell-Loop.

Der eine echte Mangel liegt in `migrateManagedEvents`: die Migration löscht
zuerst alle Termine im alten Kalender (eigener `commit`) und legt sie erst
danach neu an (zweiter `commit`). Zwischen den beiden Commits gibt es keinerlei
Vorbedingungsprüfung — schlägt der zweite Schritt fehl, stehen die Termine in
**keinem** Kalender, und die Identifier-Zuordnung ist leer. Das ist der einzige
Punkt mit echtem Nutzerschaden und der einzige Blocker.

Zweitwichtigster Befund ohne Blocker-Status: die Eingrenzung von
`matchingEvent(for:in:)` auf den Zielkalender nimmt dem normalen Sync-Pfad das
Dedup-Netz nach Neuinstallation/iCloud-Restore.

## Kriterien-Abgleich (gegen `.planning/ZIEL.md`, am Code geprüft)

| # | Kriterium | Urteil | Begründung |
|---|-----------|--------|-----------|
| 1 | Dialog vor jeder Änderung, keine Schreiboperation davor | **erfüllt** | `SettingsView.swift:411-412` setzt im `.confirmMigration`-Zweig nur `pendingCalendarIdentifier`; `calendarIdentifier` wird erst in `migrateNow` (Zeile 429) geschrieben. Kein Pfad schreibt vorher in EventKit. |
| 2 | Abbrechen folgenlos, kein Rückstell-Loop | **erfüllt** | Die Binding-`set` (`:277`) schreibt `calendarIdentifier` nie im Confirm-Fall, also gibt es nichts zurückzustellen; das alte `.onChange` ist entfernt → strukturell kein Loop. UI-Revert selbst nicht durchgeklickt (siehe F06). |
| 3 | Bestätigen migriert vollständig | **erfüllt im Happy Path, nicht robust** | `migrateManagedEvents` (`:190-193`) räumt alt und legt neu an, `managedEventIdentifiers` wird in `synchronize` neu gesetzt. Im Fehlerfall bleibt jedoch ein Zustand ohne Termine zurück → **F01**. |
| 4 | Keine Fehlalarme | **erfüllt** | `refreshCalendars()` (`:449`) schreibt `calendarIdentifier` **direkt**, nicht über `calendarSelection` → der Dialog kann beim Öffnen des Screens nicht feuern. Picker ist `.disabled(!isEnabled ...)` (`:340`), und der Planner liefert `.apply` bei `!isSyncEnabled` oder `!hasManagedEvents` sowie `.ignore` bei unveränderter/leerer Auswahl. |
| 5 | Beweis + Sprache | **teilweise** | Sprache: alle 4 neuen Keys liegen DE (Source) + EN `state: "translated"` vor ✓. Berührte Suite grün ✓ (6 Tests, Exit 0). **Rot-Beweis fehlt** → F05. |

## Findings

| ID | Severity | Blocker | Datei:Zeile | Kategorie | Titel |
|----|----------|---------|-------------|-----------|-------|
| F01 | major | **ja** | `ShipTrip/Services/CalendarSyncService.swift:189-193` | correctness / data loss | Migration löscht, bevor sie prüft, ob das Ziel überhaupt beschreibbar ist |
| F02 | major | nein | `ShipTrip/Views/Settings/SettingsView.swift:433-440` | correctness | Nach fehlgeschlagener Migration löst der Rollback keinen Re-Sync aus |
| F03 | major | nein | `ShipTrip/Services/CalendarSyncService.swift:220-229` | regression | Dedup-Netz nach Neuinstallation/Restore entfällt → Duplikate möglich |
| F04 | major | nein | `ShipTripTests/CalendarTargetChangePlannerTests.swift:1-63` | tests | Getestet ist nur die triviale Entscheidung, nicht der riskante Migrationspfad |
| F05 | major | nein | `.winston-evidence/20260804T154914Z/gate-run.json` | process | Kein Rot-Beweis — der „Repro-Test" testet einen neu eingeführten Typ |
| F06 | minor | nein | `ShipTrip/Views/Settings/SettingsView.swift:381-394` | verification | Dialog-Präsentation über einem gepushten Form-Picker nicht durchgeklickt |
| F07 | minor | nein | `ShipTrip/Localizable.xcstrings:5-15` | l10n | Kein Plural — „1 Kalendereinträge …" |
| F08 | minor | nein | `ShipTrip/Services/CalendarSyncService.swift:70-73` | readability | Doc-Kommentar behauptet Kalenderbezug, den die Property nicht hat |
| F09 | minor | nein | `ShipTrip/Views/Settings/SettingsView.swift:399-441` | fehlalarm | Veraltete Mapping-Einträge lösen einen Dialog ohne echten Umzug aus |

---

### F01 — Migration löscht, bevor sie prüft, ob das Ziel überhaupt beschreibbar ist  ⛔ BLOCKER

- **Datei**: `ShipTrip/Services/CalendarSyncService.swift:189-193`
- **Severity**: major · **Blocker: ja** (destruktiver Pfad, Nutzerschaden, 4-Zeilen-Fix)
- **Problem**: `migrateManagedEvents` besteht aus zwei getrennten EventKit-Transaktionen:
  `removeAllManagedEvents()` committet die Löschung im alten Kalender und setzt
  `managedEventIdentifiers = [:]`; erst danach läuft `synchronize(cruises:)`.
  Laut Apple-Doku (EventKit, „Accessing Calendar Using EventKit and EventKitUI")
  rollt EventKit einen *fehlgeschlagenen* `commit()` automatisch zurück — jede der
  beiden Hälften ist also für sich atomar, die Migration als Ganzes aber **nicht**.
  Schlägt der zweite Schritt fehl (`calendarMissing`, weil der Zielkalender
  zwischenzeitlich verschwand; `isEnabled` inzwischen aus → `synchronize` gibt
  stillschweigend `0` zurück; Schreibfehler beim Commit), ist der Zustand:
  Termine im alten Kalender **gelöscht**, im neuen **nicht angelegt**, Mapping
  **leer**. Der Nutzer verliert alle ShipTrip-Termine inklusive der von ihm selbst
  ergänzten Alarme/Notizen. Die Termine sind zwar aus den Cruises regenerierbar,
  aber nur beim nächsten Sync-Trigger — und den gibt es hier nicht (siehe F02).
  Ein Sonderfall wiegt schwerer: bei `isEnabled == false` meldet der Ablauf sogar
  Erfolg („0 Kalendereinträge in den neuen Kalender übertragen."), obwohl alles
  gelöscht wurde.
- **Fix** (alle Vorbedingungen von `synchronize` vor der Löschung prüfen):
  ```swift
  @discardableResult
  func migrateManagedEvents(cruises: [Cruise]) throws -> Int {
      guard CalendarSyncPreferences.isEnabled else { return 0 }          // nichts löschen
      guard authorizationStatus == .fullAccess else { throw CalendarSyncError.accessDenied }
      guard calendar(withIdentifier: CalendarSyncPreferences.calendarIdentifier) != nil else {
          throw CalendarSyncError.calendarMissing                        // vor der Löschung
      }
      try removeAllManagedEvents()
      return try synchronize(cruises: cruises)
  }
  ```
  Damit ist das realistische Fehlerfenster geschlossen. Wer es ganz dichtmachen
  will, dreht zusätzlich die Reihenfolge (erst im neuen Kalender anlegen +
  committen, dann im alten löschen) — das kostet im Fehlerfall Duplikate statt
  Löschungen, was die deutlich harmlosere Havarie ist. Für diesen Diff genügt der
  Guard oben; die Reihenfolge-Umkehr gehört ins Backlog.

### F02 — Nach fehlgeschlagener Migration löst der Rollback keinen Re-Sync aus

- **Datei**: `ShipTrip/Views/Settings/SettingsView.swift:433-440`
- **Severity**: major · **Blocker: nein** (mit F01 gefixt tritt der Fall praktisch nicht mehr ein)
- **Problem**: Der `catch`-Zweig setzt `calendarIdentifier = previousIdentifier`
  zurück. Da `migrateNow` nach der ersten Zuweisung (`:429`) synchron
  durchläuft, sieht SwiftUI nur den Endwert — `calendarIdentifier` ist netto
  unverändert, der `syncToken` in `ShipTrip/Views/CalendarSyncObserver.swift:18-23`
  ändert sich nicht, `.task(id:)` feuert nicht erneut. Die gelöschten Termine
  bleiben also weg, bis der Nutzer „Jetzt synchronisieren" drückt oder die App
  neu in den Vordergrund kommt.
- **Fix**: im `catch`-Zweig nach dem Rollback `performSynchronization()`
  aufrufen (stellt die Termine im alten Kalender wieder her), statt nur die
  Fehlermeldung zu setzen.

### F03 — Dedup-Netz nach Neuinstallation/Restore entfällt

- **Datei**: `ShipTrip/Services/CalendarSyncService.swift:220-229`
- **Severity**: major · **Blocker: nein**
- **Problem**: `matchingEvent` sucht jetzt mit `calendars: [calendar]` statt
  `calendars: nil`. Der Sinn im Migrationspfad ist richtig, aber die Suche war
  im **normalen** Pfad das Netz für den Fall „Mapping weg, Termine da": Nach
  Neuinstallation oder iCloud-Restore kommen die Cruises über CloudKit zurück,
  die `UserDefaults`-Zuordnung dagegen nicht. `selectDefaultCalendarIfNeeded()`
  wählt dann `defaultCalendarForNewEvents`. Stimmt der nicht mit dem früher
  gewählten Zielkalender überein, findet die eingegrenzte Suche nichts, legt
  alles neu an — und die alten Termine bleiben als Duplikate im anderen Kalender
  liegen. Vorher wurden sie gefunden und per `event.calendar = targetCalendar`
  mitgezogen.
- **Fix** (minimal): die Eingrenzung nur dann anwenden, wenn ein Umzug gerade
  stattgefunden hat — z. B. `synchronize` einen Parameter
  `restrictMatchingToTarget: Bool = false` geben, den `migrateManagedEvents` auf
  `true` setzt. Alternativ die breite Suche behalten (der Migrationspfad löscht
  die alten Termine ja explizit vorher, sie können also gar nicht mehr gefunden
  werden) und nur den dokumentierten Source-Grenzfall im Kommentar festhalten.

### F04 — Getestet ist nur die triviale Entscheidung, nicht der riskante Pfad

- **Datei**: `ShipTripTests/CalendarTargetChangePlannerTests.swift:1-63`
- **Severity**: major · **Blocker: nein**
- **Problem**: Die drei Tests decken die vier Zweige von
  `CalendarTargetChangePlanner.decide` sauber ab (confirm/apply×2/ignore×2) —
  das ist ordentlich, aber es ist eine reine Enum-Entscheidung ohne
  Nebenwirkungen. Der Code, der Nutzerdaten anfasst (`migrateManagedEvents`,
  `hasManagedEvents`, `matchingEvent`), hat **null** Testabdeckung. Der
  Test-Diff (63 Zeilen) liegt korrekt unter dem Code-Diff (~148) — der Deckel
  ist eingehalten, das Gewicht ist nur falsch verteilt.
- **Fix**: `CalendarSyncService` nimmt `defaults:` bereits per Injection
  entgegen. Ein Test mit `UserDefaults(suiteName: #function)` kann ohne
  EventKit-Berechtigung mindestens sicherstellen, dass `hasManagedEvents` das
  persistierte Mapping korrekt spiegelt (leer / befüllt / nach
  `removeAllManagedEvents`). Volle EventKit-Migrationstests brauchen
  Kalenderrechte im Simulator — dafür bewusst kein Auftrag, aber im Backlog
  vermerken.

### F05 — Kein Rot-Beweis

- **Datei**: `.winston-evidence/20260804T154914Z/gate-run.json`
- **Severity**: major · **Blocker: nein**
- **Problem**: ZIEL.md Kriterium 5 verlangt einen Repro-Test, der vor dem Fix
  nachweislich rot war. `CalendarTargetChangePlannerTests` testet einen mit
  diesem Diff **neu eingeführten** Typ — gegen `52b22a9` würde die Suite nicht
  einmal kompilieren, ein Rot-Lauf ist strukturell unmöglich. Im
  Entwickler-Artefakt gibt es entsprechend nur einen grünen Lauf. Der eigentliche
  Bug („Termine bleiben im alten Kalender") ist damit durch keinen Test
  reproduziert.
- **Fix**: Kriterium 5 für diesen Diff als nicht erfüllt vermerken und
  entscheiden — entweder Kriterium anpassen oder mit F04 zusammen einen Test
  nachziehen, der den Bug beschreibt (Mapping nach Migration zeigt auf den neuen
  Kalender).

### F06 — Dialog-Präsentation nicht durchgeklickt

- **Datei**: `ShipTrip/Views/Settings/SettingsView.swift:381-394`
- **Severity**: minor · **Blocker: nein** (unverifiziert, nicht belegt kaputt)
- **Problem**: Der Alert hängt an der `Form`. Ein `Picker` in einer `Form`
  innerhalb eines `NavigationStack` rendert auf iOS standardmäßig als
  `.navigationLink` und pusht einen Detail-Screen; die Auswahl feuert die
  Binding-`set` **auf dem gepushten Screen**. Dass der Alert der Elternansicht
  dabei zuverlässig erscheint, ist nicht „by construction", sondern
  SwiftUI-Präsentationsverhalten — im Regelfall geht es (der Screen popt zurück,
  dann präsentiert der Alert), es ist aber genau die Klasse Detail, die man
  einmal ansieht statt annimmt.
- **Fix / Auflage**: einmaliger Handdurchklick vor Release (Sync an, Kalender
  wechseln → Dialog da? Abbrechen → Auswahl zurück?). Falls der Alert nicht
  erscheint: `.alert` direkt an den `Picker` hängen oder Picker auf
  `.pickerStyle(.menu)` stellen, damit kein Screen gepusht wird.

### F07 — Kein Plural im neuen Statustext

- **Datei**: `ShipTrip/Localizable.xcstrings:5-15`
- **Severity**: minor · **Blocker: nein**
- **Problem**: `"%lld Kalendereinträge in den neuen Kalender übertragen."` hat
  keine Plural-Variation → „1 Kalendereinträge …". Konsistent mit dem
  bestehenden `"%lld Kalendereinträge synchronisiert."` (Zeile 3201), also kein
  neuer Stilbruch — trotzdem falsch.
- **Fix**: für beide Keys eine `variations`/`plural`-Sektion (`one`/`other`) im
  String Catalog nachtragen, DE und EN.

### F08 — Irreführender Doc-Kommentar

- **Datei**: `ShipTrip/Services/CalendarSyncService.swift:70-73`
- **Severity**: minor · **Blocker: nein**
- **Problem**: „Ob ShipTrip aktuell Termine **im eingestellten Zielkalender**
  verwaltet" — die Property liest nur `!managedEventIdentifiers.isEmpty` und
  weiß über keinen Kalender etwas. Genau diese Unschärfe erzeugt F09.
- **Fix**: Kommentar auf „Ob ShipTrip überhaupt Termine verwaltet (persistierte
  Zuordnung nicht leer)." ändern.

### F09 — Fehlalarm bei veraltetem Mapping

- **Datei**: `ShipTrip/Views/Settings/SettingsView.swift:399-414`
- **Severity**: minor · **Blocker: nein**
- **Problem**: `hasManagedEvents` prüft nur die Mapping-Größe, nicht ob die
  Termine noch existieren. Hat der Nutzer die Termine in der Kalender-App
  gelöscht, erscheint der Umzugsdialog trotzdem. Folge ist harmlos (die
  Migration legt sie im neuen Kalender an), widerspricht aber dem Wortlaut von
  Kriterium 4 („keine verwalteten Termine vorhanden").
- **Fix**: optional — in `hasManagedEvents` prüfen, ob mindestens ein Identifier
  über `eventStore.event(withIdentifier:)` auflösbar ist. Kostet einen
  EventKit-Zugriff pro Picker-Interaktion; bewusst als Backlog, nicht als Fix.

## Statische Prüfung

`python3 ~/.claude/skills/winston-orchestrator/guard.py sizes --files
ShipTrip/Services/CalendarTargetChangePlanner.swift
ShipTrip/Services/CalendarSyncService.swift
ShipTrip/Views/Settings/SettingsView.swift
ShipTripTests/CalendarTargetChangePlannerTests.swift` → exit 1:

```
FAIL  ShipTrip/Views/Settings/SettingsView.swift: 977 Zeilen (> 500 hart)
```

**Kein neues Finding** — die Datei war mit 902 Zeilen bereits über dem
Hard-Limit und ist triagiert. Zur Kenntnis: dieser Diff schiebt sie um 75 Zeilen
weiter nach oben; `CalendarSyncSettingsView` ist inzwischen ~290 Zeilen und der
naheliegende Extraktionskandidat, wenn die Datei irgendwann angefasst wird.
`CalendarTargetChangePlanner.swift` (37) und die neue Testdatei (63) sind
unauffällig.

## Test-Run-Status

Änderungsklasse **Bugfix** → berührte Suite, keine Vollsuite.

| Gate | Befehl (aus `swift-standards/assets/gates.yaml`) | Exit |
|------|--------------------------------------------------|------|
| build | `xcodebuild build -scheme ShipTrip -destination id=$SIM_UDID` | 0 |
| tests | `xcodebuild test -scheme ShipTrip -destination id=$SIM_UDID -enableCodeCoverage YES -only-testing:…CalendarTargetChangePlannerTests -only-testing:…CalendarSyncPlannerTests -only-testing:…CalendarSyncOperationStateTests` | 0 |

Grün: `CalendarTargetChangePlannerTests` (3), `CalendarSyncPlannerTests` (2),
`CalendarSyncOperationStateTests` (1). Rot: keine.
Eigenes Artefakt: `.winston-evidence/20260804T155612Z/gate-run.json`
(Wegwerf-Simulator `ci-calsync-review`, trap-Cleanup).

Gegenprüfung des Entwickler-Artefakts `.winston-evidence/20260804T154914Z/gate-run.json`:
existiert, valide, beide Exit-Codes 0, Gate-Befehle entsprechen dem Kanon —
**kein** Weichspüler-Kommando. Einziger Mangel dort: kein Rot-Lauf (F05).

## GDPR / Security

Kein Trigger. Der Diff verarbeitet keine neuen personenbezogenen Daten (die
Kalenderdaten lagen schon vorher lokal im EventStore, kein neuer Empfänger,
kein Netzwerkpfad) und vergrößert keine Angriffsfläche (keine neue Eingabe,
kein neuer Parser, keine neuen Berechtigungen). Kein Logging von PII in den
neuen Zeilen.

## Blocker (Fix vor Merge)

1. **F01** `ShipTrip/Services/CalendarSyncService.swift:189-193` — Vorbedingungen
   (`isEnabled`, `fullAccess`, Zielkalender auflösbar) **vor** der Löschung
   prüfen.

## Backlog-Zeilen (kein Fix-Auftrag in diesem Run)

```
- [major] ShipTrip/Views/Settings/SettingsView.swift:433-440 — Kein Re-Sync nach fehlgeschlagener Migration (Observer-Token netto unverändert)
- [major] ShipTrip/Services/CalendarSyncService.swift:220-229 — matchingEvent nur im Zielkalender: Dedup-Netz nach Restore/Neuinstallation weg
- [major] ShipTripTests/ — Keine Tests für migrateManagedEvents/hasManagedEvents (nur Enum-Entscheidung getestet)
- [major] .planning/ZIEL.md:28 — Rot-Beweis für den Repro-Test fehlt (neuer Typ kann nicht rot gewesen sein)
- [major] ShipTrip/Services/CalendarSyncService.swift:189-193 — Migration create-before-delete umdrehen (echte Atomarität statt Guard)
- [minor] ShipTrip/Views/Settings/SettingsView.swift:381-394 — Alert über gepushtem Form-Picker nicht durchgeklickt
- [minor] ShipTrip/Localizable.xcstrings:5-15 — Plural fehlt („1 Kalendereinträge …"), gleicher Mangel bei Zeile 3201
- [minor] ShipTrip/Services/CalendarSyncService.swift:70-73 — Doc-Kommentar von hasManagedEvents behauptet Kalenderbezug
- [minor] ShipTrip/Views/Settings/SettingsView.swift:399-414 — Umzugsdialog bei veraltetem Mapping ohne existierende Termine
- [minor] ShipTrip/Views/Settings/SettingsView.swift:1 — Datei 977 Zeilen (bereits triagiert); CalendarSyncSettingsView extrahieren
```

## Release-Auflage (nicht-blockierend, 60 Sekunden)

Einmaliger Handdurchklick auf dem Gerät/Simulator: Sync an, Termine vorhanden,
Zielkalender wechseln → Dialog erscheint? Abbrechen → Auswahl steht wieder auf
dem alten Kalender? Bestätigen → alter Kalender leer, neuer voll? Das ist der
einzige Teil des Fixes, den kein Unit-Test berührt.
