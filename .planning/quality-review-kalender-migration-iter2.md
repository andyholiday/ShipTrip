# Review — Kalender-Migration (Blocker-Fix-Verifikation)

- **Iteration**: 2 / 3 · eng geschnittene Nachprüfung, kein Voll-Review
- **Reviewer**: quality-agent (frischer Spawn)
- **Datum**: 2026-08-04 · **Basis**: HEAD `52b22a9` + uncommitteter Working Tree
- **Verdikt**: approve (GO)
- **Stats**: critical 0, major 2, minor 4 — **Blocker: 0**, Backlog: 6
- **Evidenz**: `.winston-evidence/20260804T161908Z/gate-run.json` (status `verified`, tests exit 0)

## Test-Runde

| Lauf | Kalender-Grant | Ergebnis |
|------|----------------|----------|
| A (Falsch-grün-Probe) | **nein** | exit 65 — genau die 4 Migrationstests failen hart, kein Skip |
| B (Evidenz) | ja (`simctl privacy grant calendar`) | exit 0 — 10 passed / 0 failed / **0 skipped** |

Suiten: `CalendarSyncServiceMigrationTests`, `CalendarTargetChangePlannerTests`,
`CalendarSyncPlannerTests`, `CalendarSyncOperationStateTests`. Wegwerf-Simulator
`ci-calsync-verify` (iPhone 17 / iOS 26.5), trap-Cleanup, danach 0 Reste.
Developer-Artefakt `.winston-evidence/20260804T160953Z` geprüft: existiert, valide,
gleiche Suiten, exit 0 — kein Weichspüler-Kommando.
Statischer Pass `guard.py sizes`: exit 1 wegen `SettingsView.swift` (987 Zeilen) —
vorbestehend und als F10 bereits im Backlog, kein neues Finding.

## Antworten auf die fünf Prüffragen

### 1. Ist F01 zu? — **Nein, nicht vollständig; aber kein neuer Blocker.**
Die Guards in `migrateManagedEvents` (`CalendarSyncService.swift:199-203`) schließen
die *ursächlichen* Fälle aus iter1: fehlender/nicht beschreibbarer Zielkalender und
fehlende Berechtigung. Test 2 belegt das am echten EventStore.
Das Zeitfenster danach bleibt aber offen: Zwischen Guard und `synchronize` gibt es
keine Suspension (alles synchron auf dem MainActor), der Kalender kann also nicht
"dazwischen verschwinden" — wohl aber kann `eventStore.save`/`commit` **innerhalb**
von `synchronize` (`:162`, `:176`) scheitern (CalDAV-/Exchange-Schreibfehler,
Kontingent). Dann ist der Lösch-Commit aus `removeAllManagedEvents` bereits
durch, `eventStore.reset()` holt ihn nicht zurück, und das Mapping ist leer.
Einziges Netz ist dann `restorePreviousCalendarEvents()` in der UI — siehe F11/F12.
Die strukturelle Lösung (create-before-delete umdrehen) steht bereits als
F01-Rest im Backlog; hier wird sie nicht erneut aufgemacht.

### 2. Trägt der F02-Rollback? — **Ja, mit einer stillen Lücke.**
Reihenfolge in `migrateNow` (`SettingsView.swift:438-442`) ist korrekt:
`calendarIdentifier` zurück, dann Restore, **dann** `statusMessage = error.localizedDescription`.
Der Ursprungsfehler wird also nicht überschrieben, und weil der Restore `try?`
benutzt, kann er die Meldung auch nicht verdrängen. `operationState` bleibt sauber
(`defer { operationState.finish() }`), die UI hängt nicht (synchron, kein await).
Lücke: Scheitert der Restore selbst, sind die Termine in beiden Kalendern weg und
der Nutzer sieht nur den ursprünglichen Fehler (F12).

### 3. Ist F09 korrekt gelöst? — **Ja, Performance vertretbar.**
`hasManagedEvents` (`CalendarSyncService.swift:75-77`) nutzt `contains(where:)` und
**bricht beim ersten lebenden Termin ab** — der Normalfall kostet genau einen
`event(withIdentifier:)`-Lookup. Nur wenn *alle* Einträge veraltet sind, läuft das
ganze Mapping durch (Detailmodus, realistisch ~150-200 Einträge, einmalig beim
Picker-Tap). Kein Finding.
Falsch-negativ durch iCloud: unwahrscheinlich. Das Mapping liegt gerätelokal in
`UserDefaults` (nicht in CloudKit), die Termine hat dasselbe Gerät angelegt, und
`event(withIdentifier:)` löst gegen die Datenbank auf. Die realistische Fehlrichtung
ist das Gegenteil — ein *veralteter* Store liefert falsch-positiv (überflüssiger
Dialog, harmlos), weil der Service `EKEventStoreChanged` nie beobachtet (F14,
belegt über Apple-EventKit-Doku „Updating with notifications").

### 4. Sind die neuen Tests echt? — **Ja, und sie können nicht falsch-grün werden.**
Sie prüfen beobachtbares Verhalten (Termin-Anzahl je Kalender, Kalenderzuordnung des
migrierten Termins, Mapping-Stand), nicht Implementierungsdetails. Beide Bedingungen
sind gepaart — `alt == 0` **und** `neu == 1` —, ein Totalausfall kann nicht als
Erfolg durchgehen. `tearDown()` läuft über `defer`, also auch bei rotem Test, und
stellt Testkalender **und** die drei `UserDefaults.standard`-Preferences wieder her
(Schlüssel, die vorher nicht existierten, werden korrekt entfernt).
Falsch-grün ohne Grant ist ausgeschlossen: `MigrationFixture.init` wirft
`FixtureError.notAuthorized`, und ein geworfener Fehler ist in Swift Testing ein
**Fehlschlag, kein Skip** — empirisch belegt durch Lauf A (4/4 rot, 0 skipped).
Echte Lücke ist nicht die Testqualität, sondern die Testauswahl: der Pfad, der den
Datenverlust wirklich verhindert (Fehler **nach** der Löschung + UI-Restore), ist
nicht abgedeckt (F11).

### 5. Regression durch die Fix-Runde? — **Keine gefunden.**
Der entfernte `.onChange(of: calendarIdentifier)` ist an beiden früheren
Auslösepunkten kompensiert: `refreshCalendars` (`:460-462`) und `updateEnabled`
(`:505-507`) synchronisieren jetzt explizit. Der frühere Doppel-Sync beim
Ansichtsaufbau entfällt sogar — Verbesserung. `CalendarSyncObserver` ist unverändert;
dass sein `syncToken` beim Netto-Rollback nicht feuert, ist bewusst und dokumentiert.
Der Ein-/Ausschaltpfad ist unberührt. Picker ist während `isWorking` deaktiviert.
Bestätigt durch 10/10 grüne Tests.

## Neue Findings (alle nicht-blockierend → Backlog)

| ID | Sev | Blocker | File:Line | Kategorie | Titel |
|-----|-------|---------|-----------|-----------|-------|
| F11 | major | nein | `ShipTrip/Views/Settings/SettingsView.swift:440-450` | tests | Rollback-Pfad ist die einzige Datenverlust-Absicherung und ungetestet |
| F12 | major | nein | `ShipTrip/Views/Settings/SettingsView.swift:450` | correctness | Scheitern des Restores bleibt für den Nutzer unsichtbar |
| F13 | minor | nein | `ShipTrip/Views/Settings/SettingsView.swift:434-437` | correctness | `accessDenied`-Zweig macht keinen Restore |
| F14 | minor | nein | `ShipTrip/Services/CalendarSyncService.swift:57` | correctness | `EKEventStoreChanged` wird nie beobachtet, Store kann veralten |
| F15 | minor | nein | `ShipTripTests/CalendarSyncServiceMigrationTests.swift:170-172` | tests | Tests mutieren `UserDefaults.standard` des Test-Hosts |
| F16 | minor | nein | `ShipTripTests/CalendarSyncServiceMigrationTests.swift:133-134` | tests | Testkalender-Leak, wenn `init` nach dem ersten `makeCalendar` wirft |

### F11 — Rollback-Pfad ungetestet
Die vier Tests treffen ausschließlich Guards *vor* der Löschung. Der Fall, der nach
dem Fix noch Daten kosten kann — `synchronize` wirft **nach** erfolgreichem
Lösch-Commit — hat keinen Test, und `restorePreviousCalendarEvents` in der
`SettingsView` hat gar keinen. **Fix**: Test, der den Zielkalender nach dem
Löschen unbeschreibbar macht (z. B. `store.removeCalendar(newCalendar)` zwischen
den Commits über einen injizierten Hook), und ein Test, der nach fehlgeschlagener
Migration die Wiederherstellung im alten Kalender belegt.

### F12 — stilles Scheitern des Restores
`try? CalendarSyncService.shared.synchronize(cruises: cruises)`. Wenn auch der
Restore scheitert, sind die Termine weg, ohne Hinweis. Selbstheilung erst beim
nächsten Observer-Trigger, und der feuert nicht sofort, weil `calendarIdentifier`
netto unverändert bleibt — erst ein `scenePhase`-Wechsel oder eine Reise-Änderung
heilt. **Fix**: Restore-Fehler an die `statusMessage` anhängen (etwa
„… Die Termine konnten nicht wiederhergestellt werden.") statt zu verwerfen.

### F13 — asymmetrischer `accessDenied`-Zweig
Praktisch unerreichbar (Entzug der Kalenderrechte terminiert die App), aber der
generische Zweig restauriert und dieser nicht. **Fix**: `restorePreviousCalendarEvents()`
auch dort aufrufen oder die Asymmetrie mit einem Satz kommentieren.

### F14 — Store-Aktualität
Apple: „If an event was modified or deleted, properties of `EKEvent` … may become
out of date" — der Service beobachtet die Notification nie und `reset()` läuft nur
im Fehlerpfad. Folge ist im schlimmsten Fall ein überflüssiger Umzugsdialog.
**Fix**: `NotificationCenter`-Observer auf `.EKEventStoreChanged` mit `reset()`.

### F15 / F16 — Fixture-Härtung
F15: Der Test-Host startet die App mit; `CalendarSyncObserver` liest dieselben
`UserDefaults.standard`-Schlüssel. Auf dem Wegwerf-Simulator (leerer Store) harmlos,
auf einem Simulator mit App-Daten ein Flake-Risiko. **Fix**: Wegwerf-Simulator als
Vorbedingung dokumentieren oder Preferences injizierbar machen.
F16: Wirft der zweite `makeCalendar`-Aufruf, bleibt der erste Kalender liegen.
**Fix**: `do/catch` mit `removeCalendar` im Fehlerfall.

## Status der iter1-Findings

- **F01** — teilweise gelöst: Ursachen abgesichert und getestet, Umkehr
  create-before-delete weiter offen (bereits als Backlog-Zeile triagiert).
- **F02** — gelöst; Restpunkte als F12/F13 verfolgt.
- **F09** — gelöst; Performance geprüft und vertretbar.
