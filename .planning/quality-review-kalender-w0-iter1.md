# Review — Kalender-Paket 1.8.7, Wave 0 (T0 Refactor + T3 Service-Härtung)

- **Iteration**: 1 / 3
- **Reviewer**: quality-agent (Q0, statisch — kein Build-Token, T4 baut)
- **Datum**: 2026-09-02
- **Diff-Basis**: `git diff f6cdf05..188d2c4` (Branch `feature/kalender-paket-1.8.7`)
- **Verdikt**: **approve** (Go-mit-Backlog)
- **Stats**: critical: 0, major: 2, minor: 6 — Blocker: 0, ins Backlog: 8

## Summary

T3 löst F03 und F01-Rest sauber und auf dem Weg, den Leitentscheidung 4/5
vorschreibt: `event.calendar =` steht nur noch an einer Stelle im ganzen Projekt
(`CalendarSyncService.swift:237`, frisch erzeugtes Event), `migrateManagedEvents`
ist auf ein einziges `synchronize(allowMarkerSearch: false)` reduziert, und das
Journal räumt jeden denkbaren Abbruchpunkt nach. T0 ist ein zeilenweise
verifizierter reiner Move. Evidenz TB0 ist gültig (build 0, tests 0, 560/560),
alle drei Repro-Tests grün. Kein Finding blockiert den Go-Live; die zwei
major-Findings sind ein Altlast-Limit (SettingsView) und ein Mehrgeräte-Randfall.

## Findings

| ID  | Sev   | Blocker | File:Line | Kategorie | Titel |
|-----|-------|---------|-----------|-----------|-------|
| F01 | major | nein | ShipTrip/Views/Settings/SettingsView.swift:1-730 | size | 730 Zeilen über dem 500er-Hard-Limit (guard.py exit 1) |
| F02 | major | nein | ShipTrip/Services/CalendarSyncService.swift:232-239 | correctness | Breite Marker-Suche kann Termine zwischen zwei Geräten hin- und herschieben |
| F03 | minor | nein | ShipTrip/Services/CalendarSyncService.swift:27-31 | dead-code | `CalendarSyncPreferences.isEnabled/.mode/.calendarIdentifier` ohne Aufrufer |
| F04 | minor | nein | ShipTrip/Services/CalendarSyncService.swift:71 | design | `init` löscht Kalendereinträge (Seiteneffekt im Konstruktor) |
| F05 | minor | nein | (Evidenz) | process | Kein Artefakt für den Rot-Lauf — nur die Commit-Message |
| F06 | minor | nein | ShipTripTests/CalendarSyncHardeningTests.swift:44-66 | tests | `failCommit`/`failRemove` des Doubles werden nie gefahren |
| F07 | minor | nein | ShipTrip/Services/CalendarSyncService.swift:252-272 | robustness | Journal räumt sich nie auf, wenn `remove` dauerhaft scheitert |
| F08 | minor | nein | ShipTrip/Services/CalendarSyncService.swift:106,318 | readability | `writableCalendars()` vs. `writableCalendars(besides:)` — Overload mit fremdem Rückgabetyp |

### F01 — SettingsView.swift über dem Hard-Limit
- **Severity**: major · **Blocker: nein** (Altlast, keine Funktionsgefahr)
- **Failure-Szenario**: kein Laufzeitfehler; `python3 guard.py sizes` gibt Exit 1
  zurück und würde ein Größen-Gate rot machen.
- **Kontext**: T0 hat 1115 → 730 gedrückt, also die Richtung ist richtig. Restliche
  Brocken sind Export/Import- und Datenschutz-Abschnitte, nicht Kalender.
- **Fix**: nächste Extraktionsrunde (Export- und Datenschutz-Abschnitt in eigene
  Dateien) — außerhalb dieses Runs, Backlog-Zeile F10 fortschreiben.

### F02 — Breite Marker-Suche schiebt Termine zwischen zwei Geräten
- **File**: `ShipTrip/Services/CalendarSyncService.swift:232-239`
- **Severity**: major · **Blocker: nein**
- **Failure-Szenario**: iPhone + iPad, beide mit ShipTrip (Reisen kommen über
  CloudKit auf beide), gemeinsamer iCloud-Kalender. iPhone syncte nach „Privat",
  iPad wählt beim ersten Öffnen per `selectDefaultCalendarIfNeeded` „Zuhause".
  Das Mapping liegt in `UserDefaults` und wird **nicht** gesynct. iPad: kein
  Mapping-Eintrag → breite Suche findet den Termin des iPhones in „Privat" →
  legt eine Kopie in „Zuhause" an und journalisiert/löscht das Original. Auf dem
  iPhone zeigt das Mapping jetzt auf ein gelöschtes Event → es legt in „Privat"
  neu an. Ergebnis: bei jedem Sync wandert derselbe Termin hin und her.
- **Fix (ein Satz)**: Findet die breite Suche einen Treffer in einem fremden
  Kalender **und** ist das Mapping leer (Restore-Fall), den gefundenen Identifier
  ins Mapping übernehmen statt neu anzulegen und zu löschen — das Umziehen bleibt
  dem expliziten `migrateManagedEvents` vorbehalten.

### F03 — Tote Preferences-Shims
- **File**: `ShipTrip/Services/CalendarSyncService.swift:27-31`
- **Severity**: minor · **Blocker: nein**
- **Failure-Szenario**: kein Laufzeitfehler. Aber: `grep` über `ShipTrip/` und
  `ShipTripTests/` findet **null** Aufrufer der drei statischen Properties — sie
  sind ausschließlich Übrigbleibsel der Umstellung auf `(in: defaults)`. Risiko
  ist die nächste Welle: T1 soll den Observer laut Leitentscheidung 1 auf *einen*
  Leseort ziehen; ein bequemes `CalendarSyncPreferences.mode` verführt dort
  zurück zu `UserDefaults.standard` und hebelt die Injektion (F15) wieder aus.
- **Fix**: die drei `static var` löschen (CLAUDE.md §3: eigene Waisen aufräumen).

### F04 — `init` löscht Kalendereinträge
- **File**: `ShipTrip/Services/CalendarSyncService.swift:71`
- **Severity**: minor · **Blocker: nein**
- **Failure-Szenario**: `CalendarSyncService(...)` zu konstruieren mutiert den
  Kalender des Nutzers. Der Guard `!pending.isEmpty` steht zuerst und ist billig,
  der Normalfall kostet also nur einen UserDefaults-Read — kein Performance-Thema.
  Aber ein Konstruktor mit Löschwirkung ist in einer Preview oder einem künftigen
  `@State`-Init eine Falle.
- **Fix**: den Drain an den Kopf von `synchronize`/`hasManagedEvents` ziehen statt
  in `init` — Achtung, Test 3 hängt am Init-Verhalten und müsste mitgezogen werden.
  Nicht in diesem Run.

### F05 — Kein Rot-Artefakt
- **Severity**: minor · **Blocker: nein**
- **Befund**: Unter `.winston-evidence/` liegen genau zwei Läufe (kp-t3
  `20260902T140819Z`, TB0 `20260902T141209Z`), beide grün, beide Exit 0. Für den
  behaupteten Rot-Lauf (Exit 65, 0/3) existiert kein Artefakt, nur die Message
  von `257a8c0`.
- **Eigene Verifikation (statisch, ersetzt das Artefakt nicht)**: `257a8c0` legt
  die Tests **vor** dem Fix `b637959` an, gegen den ungefixten Service. Damit sind
  alle drei zwingend rot gewesen: (1) altes `matchingEvent` suchte nur im Ziel →
  `eventCount(in: oldCalendar) == 0` scheitert; (2) altes `migrateManagedEvents`
  rief `removeAllManagedEvents()` zuerst, `failSave` trifft nur `save` → der alte
  Termin ist weg, `== 1` scheitert; (3) vor `b637959` gab es keinen Journal-Key,
  `writeJournal` schrieb ins Leere → `== 0` scheitert. Rot-Beweis inhaltlich
  bestätigt.
- **Fix**: künftig auch den Rot-Lauf über `evidence.py` festhalten.

### F06 — `failCommit`/`failRemove` ungenutzt
- **File**: `ShipTripTests/CalendarSyncHardeningTests.swift:44-66`
- **Severity**: minor · **Blocker: nein**
- **Failure-Szenario**: `failSave = true` kippt schon beim ersten Draft. Nicht
  abgedeckt: Scheitern mitten in der Schleife (Draft 3 von 5) und Scheitern erst
  im `commit()` — genau der Pfad, auf dem `eventStore.reset()` beweisen muss, dass
  die bereits gestageten Saves zurückgerollt werden.
- **Fix**: ein vierter Test mit `double.failCommit = true` und zwei Reisen —
  erwartet: wirft, alter Kalender unverändert, `managedIdentifiers` unverändert.

### F07 — Journal ohne Aufgabe-Bedingung
- **File**: `ShipTrip/Services/CalendarSyncService.swift:252-272`
- **Severity**: minor · **Blocker: nein**
- **Failure-Szenario**: Der Nutzer abonniert den alten Kalender nur noch
  read-only (Google-Freigabe entzogen). `remove` wirft dauerhaft →
  `drainPendingRemovals` scheitert bei jedem Start und jedem Sync erneut, der
  Journal-Key wird nie leer, das Mapping nie gefiltert. Kein Datenverlust, aber
  ein stiller Dauerfehler im Log.
- **Fix**: Identifier überspringen und aus dem Journal streichen, wenn
  `event.calendar?.allowsContentModifications == false`.

### F08 — Verwirrender Overload
- **File**: `ShipTrip/Services/CalendarSyncService.swift:106` (`-> [WritableCalendar]`)
  und `:318` (`besides:` `-> [EKCalendar]`)
- **Severity**: minor · **Blocker: nein** · **Fix**: den privaten in
  `writableEKCalendars(besides:)` umbenennen.

## Antworten auf die Pflichtfragen

1. **Wird noch irgendwo ein bestehendes Event umgehängt?** Nein. `grep -rn "\.calendar = " ShipTrip/`
   liefert genau einen Treffer: `CalendarSyncService.swift:237`, direkt nach
   `eventStore.makeEvent()`. Das ausgelagerte `apply(_:to:)` fasst `.calendar`
   nicht mehr an, und beide Rückgabepfade mit bestehenden Events (`mapped` mit
   Ziel-Match, `markerEvent(in: [target])`) liefern per Konstruktion nur Events,
   die bereits im Zielkalender liegen.
2. **Journal idempotent, Key aus dem Mapping?** Ja, beides. `drainPendingRemovals`
   überspringt Identifier ohne Event (`guard let ... else { continue }`), leert
   den Journal-Key **erst nach** erfolgreichem `commit()` und filtert das Mapping
   über den *Wert* (`!removed.contains($0.value)`). Weil `managedEventIdentifiers`
   im Erfolgsfall vorher schon mit den **neuen** Identifiern überschrieben wurde,
   trifft der Filter nur echte Leichen — der Draft-Key überlebt mit neuem Wert.
3. **Kalenderwechsel trotz breiter Suche wirksam?** Ja. Die Suche ist doppelt
   gesperrt: `allowMarkerSearch && mappedIdentifier == nil`. `migrateManagedEvents`
   übergibt `false`, und beim regulären Wechsel existiert ein Mapping-Eintrag.
   Der Bestandstest „Bestätigte Migration verschiebt alle Termine in den neuen
   Kalender" (alt 0 / neu 1 / Event im neuen Kalender) ist in TB0 grün.
4. **Halber Zustand bei `migrateManagedEvents`?** Nein, dauerhaft nicht. Es gibt
   nur noch **einen** Commit; scheitert er, folgt `reset()` + `throw`, und weder
   Journal noch Mapping wurden angefasst. Jeder Crash-Punkt danach heilt beim
   nächsten Lauf: Crash vor dem Journal-Write → Mapping zeigt noch aufs alte
   Event im Fremdkalender, `markerEvent(in: [target])` findet das neue und
   journalisiert das alte. Crash zwischen Journal- und Mapping-Write → der Drain
   löscht das alte Event und entfernt den Key per Wert-Filter, der nächste Sync
   findet das neue über die Ziel-Marker-Suche. Beide Wege enden im Soll-Zustand.
5. **Sind die drei Rot-Tests echte Verhaltens-Tests?** Ja. Sie prüfen
   ausschließlich Beobachtbares am echten `EKEventStore` (Termin-Anzahl je
   Kalender, Mapping-Größe, Journal-Inhalt), kein einziger Zugriff auf ein
   Service-Internum. Beim Rückbau des Fixes würden alle drei wieder rot — siehe
   die Ableitung unter F05. Schwäche: Test 3 schreibt das Journal von Hand statt
   es durch einen echten Abbruch entstehen zu lassen; dass es *geschrieben* wird,
   deckt aber Test 1 mit ab.
6. **T0 verhaltensidentisch?** Ja, zeilenweise verifiziert: Multiset-Vergleich
   aller `-`- gegen alle `+`-Zeilen von `83658b7` ergibt **null** entfernte
   Zeilen ohne Entsprechung und als einzige Zusätze die Dateiköpfe plus Imports.
   Keine Zugriffsmodifier geändert (`struct CalendarSyncOperationState`,
   `struct CalendarSyncSettingsView` bleiben internal), keine Previews betroffen
   (in beiden Dateien gab und gibt es keine). Das entfernte `import EventKit` in
   SettingsView ist korrekt verwaist; die neuen Imports werden alle benutzt
   (`UIKit` für `UIApplication.openSettingsURLString:158`, `SwiftData` für
   `@Query`, `EventKit` für `.fullAccess`).
7. **Datei-Längen (`guard.py sizes`)**: Exit 1 — `SettingsView.swift: 730 Zeilen
   (> 500 hart)` = F01. Alle anderen geänderten Dateien liegen darunter
   (CalendarSyncService 364, CalendarSyncSettingsView 317, MigrationTests 255,
   CalendarEventStoreDouble 101, NotificationSettingsView 86, HardeningTests 83,
   CalendarEventStoring 47).
8. **Swift-6-Concurrency der Fassade**: statisch sauber. `CalendarEventStoring`
   ist `@MainActor` + `AnyObject`, Service und Double sind ebenfalls `@MainActor`,
   die Witnesses aus `EKEventStore` sind nonisolated (zulässige Erweiterung des
   Isolationsraums), und das nicht-`Sendable` `EKEventStore` bleibt hinter
   `any CalendarEventStoring` in einem MainActor-Kontext eingesperrt — keine
   Aktorgrenze wird überschritten. **Caveat**: Der TB0-Build-Log enthält keine
   einzige Compile-Task (warmes DerivedData), „null Warnungen" ist damit *nicht*
   belegt; die Aussage stützt sich auf Lektüre, nicht auf einen frischen Lauf.

## Evidenz

| Lauf | Pfad | build | tests |
|------|------|-------|-------|
| T3 | `ShipTrip-worktrees/kp-t3/.winston-evidence/20260902T140819Z/gate-run.json` | 0 | 0 |
| TB0 | `ShipTrip-worktrees/kalender-1.8.7/.winston-evidence/20260902T141209Z/gate-run.json` | 0 | 0 |

Kommandos sind der Projekt-Kanon (`build-for-testing` / `test-without-building`),
keine Weichspüler. TB0-Log: „Test run with 560 tests in 119 suites passed",
darunter alle drei Härtungs-Tests und die vier Bestands-Kalendertests.

## Backlog-Zeilen (nach `.planning/BACKLOG.md`)

```
- [major] ShipTrip/Views/Settings/SettingsView.swift:1 — 730 Zeilen über dem 500er-Hard-Limit (F10-Fortsetzung)
- [major] ShipTrip/Services/CalendarSyncService.swift:232 — breite Marker-Suche kann Termine zwischen zwei Geräten hin- und herschieben
- [minor] ShipTrip/Services/CalendarSyncService.swift:27 — tote Preferences-Shims (isEnabled/mode/calendarIdentifier) löschen
- [minor] ShipTrip/Services/CalendarSyncService.swift:71 — Journal-Drain aus dem init herausziehen
- [minor] ShipTripTests/CalendarSyncHardeningTests.swift:44 — failCommit/failRemove-Pfade nicht abgedeckt
- [minor] ShipTrip/Services/CalendarSyncService.swift:252 — Journal räumt sich nie auf, wenn remove dauerhaft scheitert
- [minor] ShipTrip/Services/CalendarSyncService.swift:106 — writableCalendars-Overload umbenennen
- [minor] (Prozess) Rot-Lauf künftig ebenfalls über evidence.py festhalten
```

## Hinweis an T1

F03 ist billig und liegt genau auf T1s Weg (Leitentscheidung 1, *ein* Leseort):
Wer den Observer umstellt, sollte die drei toten `static var` gleich mitnehmen.
