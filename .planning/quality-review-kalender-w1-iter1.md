# Review — Kalender-Paket 1.8.7, Welle 1 (T1 Modus/Migration/Ort + T4 Coordinator/Reconcile)

- **Iteration**: 1 / 3
- **Reviewer**: quality-agent (Q1a, read-only, kein Build-Token)
- **Datum**: 2026-09-02
- **Diff-Basis**: `git diff 188d2c4..aec5263` (T4 0c8f6e8 · T1 59946f6 · K fb93d89 · Compile-Fix aec5263)
- **Verdikt**: approve (Go-mit-Backlog)
- **Stats**: critical 0, major 8, minor 4 — **Blocker 0**, Backlog 12
- **Evidenz**: `.winston-evidence/20260902T143221Z/gate-run.json` — build exit 0, tests exit 0, commit `aec5263` = HEAD, `logs/tests.log` sha256 stimmt mit dem Manifest überein, 576 Tests / 122 Suites grün. Kommandos sind die Kanon-Befehle (`build-for-testing` / `test-without-building`), kein Weichspüler. Statischer Pass: `guard.py sizes` über alle 12 geänderten Swift-Dateien → **ok, exit 0, 0 Soft-Warnungen**.

## Summary

Der fachliche Kern sitzt: Die Modus-Migration läuft an genau der richtigen
Stelle (erste Anweisung von `synchronize`, vor jedem Lesen des Umfangs), sie ist
idempotent, und der Bestandsnachweis über den `/trip`-Mapping-Schlüssel ist
korrekt implementiert. `existingTripEventSurvivesTheUpdate` ist ein echter
Verhaltenstest, der bei einem Rückbau rot wird. Der Rollback-Coordinator hat die
richtige Reihenfolge (erst Zielkalender zurück, dann wiederherstellen) und
hinterlässt keine Journal-Einträge, die später Termine löschen könnten.

Kein Finding blockiert den Wave-1-Gate. Die zwei gewichtigsten (F01/F02) liegen
in `CalendarSyncSettingsView`, die laut TASKPLAN T5 gehört — sie werden zu
Release-Blockern, falls T5 sie nicht schließt. Drei Befunde betreffen Substanz,
die keiner Welle mehr gehört: eine undokumentierte EventKit-Annahme (F03), eine
im Projekt bereits als unzureichend erkannte Koordinatenprüfung (F04) und ein
Reconcile ohne Task-Serialisierung (F05).

## Findings

| ID  | Sev | Blocker | File:Line | Kategorie | Titel |
|-----|-----|---------|-----------|-----------|-------|
| F01 | major | nein (T5 Pflicht) | `ShipTrip/Views/Settings/CalendarSyncSettingsView.swift:42` | correctness | Zweiter Default-Leseort mit **altem** Default `tripOnly` |
| F02 | major | nein (T5 Pflicht) | `ShipTrip/Views/Settings/CalendarSyncSettingsView.swift:129-140` | ui | Picker bietet „Keine Einträge" ohne Hinweis, löscht bei Wahl alles |
| F03 | major | nein | `ShipTrip/Services/CalendarSyncService.swift:239-254` | correctness | Aufräumpfad des Orts beruht auf undokumentierter EventKit-Kopplung |
| F04 | major | nein | `ShipTrip/Services/CalendarEventPlanner.swift:167` | correctness | Koordinaten-Plausibilität schwächer als im eigenen `MapMarkerPlanner` |
| F05 | major | nein | `ShipTrip/Views/Settings/NotificationSettingsView.swift:91-99` | concurrency | Überlappende Reconciles beim Stepper, veralteter Trigger kann gewinnen |
| F06 | major | nein | `ShipTripTests/NotificationSettingsReconcileTests.swift:19-34` | tests | Test prüft nur den Weiterleiter, nicht die `onChange`-Verdrahtung |
| F07 | major | nein | `ShipTripTests/CalendarMigrationCoordinatorTests.swift:38-59` | tests | Rollback-Test trifft die Guard, nie den Abbruch mitten im Anlegen |
| F12 | major | nein | `ShipTrip/Services/CalendarSyncService.swift:272-276` | correctness | Restore ohne Mapping: Bestandsschutz greift nicht, Karteileiche bleibt |
| F08 | minor | nein | `ShipTrip/Services/CalendarSyncService.swift:261-268` | performance | `hasLiveTripEvent` wird auch ohne Kalenderzugriff ausgewertet |
| F09 | minor | nein | `ShipTrip/Views/Settings/CalendarSyncSettingsView.swift:228` | error-handling | Rollback-Fehler wird ersatzlos verworfen |
| F10 | minor | nein | `ShipTrip/Services/CalendarEventPlanner.swift:18` | api | Case `none` kollidiert mit `Optional.none` |
| F11 | minor | nein | `docs/features/kalender-sync.md` (ganze Datei) | docs | Doku widerspricht dem Code-Stand auf HEAD |

---

### F01 — Zweiter Default-Leseort mit altem Default

- **File**: `ShipTrip/Views/Settings/CalendarSyncSettingsView.swift:42`
- **Severity**: major · **Go-Live-Blocker**: nein (T5 ist laut TASKPLAN Eigentümer der Datei)
- **Problem**: `@AppStorage(CalendarSyncPreferences.modeKey) private var modeRawValue = CalendarSyncMode.tripOnly.rawValue` verstößt gegen Leitentscheidung 1 („genau EINEN Default-Leseort") und trägt zusätzlich den **alten** Default. Failure-Szenario: Sync ist ausgeschaltet, Nutzer öffnet die Kalender-Einstellungen. `.task { refreshCalendars() }` ruft `synchronizeIfEnabled()` (Zeile 242), das bei `isEnabled == false` sofort zurückkehrt — die Migration läuft von dieser Seite also nie. Der Umfang-Picker zeigt dauerhaft „Nur Reisen", während der effektive Umfang `itineraryOnly` ist.
- **Fix**: Default auf `""` setzen und den Anzeigewert über `CalendarSyncPreferences.mode(in: .standard)` ableiten — genau wie `CalendarSyncObserver.swift:18` es bereits macht.

### F02 — Picker bietet „Keine Einträge" ohne Hinweis

- **File**: `ShipTrip/Views/Settings/CalendarSyncSettingsView.swift:129-140`
- **Severity**: major · **Go-Live-Blocker**: nein für den Wave-1-Gate, **ja für den Release**
- **Problem**: `ForEach(CalendarSyncMode.allCases)` zieht die zwei neuen Fälle ungefiltert in den bestehenden Picker. Wählt ein Nutzer „Keine Einträge", schreibt das Binding (Zeile 72-80) den Modus und ruft `synchronizeIfEnabled()`; der Sync entfernt daraufhin **alle** verwalteten Termine, während der Haupt-Schalter „Reisen mit Kalender synchronisieren" weiter auf „an" steht. Der Section-Footer (Zeile 139) erklärt weiterhin nur den Detailmodus; der von LE1 geforderte Hinweis „Es werden keine Einträge angelegt" fehlt.
- **Fix**: Gehört zu T5 (zwei Schalter statt Picker + Hinweistext). Bis dahin bewusst als Zwischenstand führen — G3/Q2 muss belegen, dass T5 den Zustand ersetzt hat.

### F03 — Aufräumpfad des Orts beruht auf undokumentierter EventKit-Kopplung

- **File**: `ShipTrip/Services/CalendarSyncService.swift:239-254` (Kommentar 235-238)
- **Severity**: major · **Blocker**: nein
- **Problem**: Der Kommentar behauptet, `event.location = title` überschreibe „den alten strukturierten Ort mitsamt Geo-Position". Gegen die aktuelle Apple-Doku geprüft (context7 `/websites/developer_apple_eventkit`): `EKCalendarItem.location` und `EKEvent.structuredLocation` sind als zwei unabhängige Properties dokumentiert; über die wechselseitige Wirkung des Setters sagt die Doku nichts zu. Failure-Szenario: Ein Hafen verliert seine Koordinaten (Korrektur durch den Nutzer, Import). Der Sync geht in den Text-Zweig, eine veraltete `geoLocation` kann stehen bleiben — der Kalender bietet dann Navigation zum falschen Ort. Symmetrisch im `nil`-Zweig (Zeile 240-243): dort wird nur `structuredLocation` genullt, ein alter Text-`location` auf einem wiederverwendeten Event kann überleben (relevant, wenn ein Hafen zum Seetag wird).
- **Fix**: In beiden Zweigen beides explizit setzen — `event.structuredLocation = nil; event.location = title` bzw. `event.structuredLocation = nil; event.location = nil`. Dazu ein Service-Test, der einen Hafen mit Koordinate synchronisiert, die Koordinate entfernt, erneut synchronisiert und `event.structuredLocation?.geoLocation == nil` prüft.

### F04 — Koordinaten-Plausibilität schwächer als im eigenen MapMarkerPlanner

- **File**: `ShipTrip/Services/CalendarEventPlanner.swift:167` (Prädikat: `ShipTrip/Models/Port.swift:65`)
- **Severity**: major · **Blocker**: nein
- **Problem**: `port.hasValidCoordinates` ist `!isSeaDay && !(latitude == 0 && longitude == 0)` — nur die Null-Insel. Das Projekt weiß bereits, dass das nicht reicht: `ShipTrip/Views/Map/MapMarkerPlanner.swift:38-43` filtert ausdrücklich zusätzlich mit `isFinitePlausible($0.coordinate)`, mit Kommentar. Der Kalender-Planer übernimmt diese Ergänzung nicht. Failure-Szenario: Ein Hafen mit `NaN` oder einer Breite außerhalb ±90 erzeugt eine `CLLocation` mit unsinniger Koordinate; im günstigen Fall zeigt der Kalender einen falschen Pin, im ungünstigen lehnt EventKit den `save` ab — und weil alle Entwürfe in **einem** Commit laufen (Zeile 149-180), scheitert dann der komplette Sync-Lauf, nicht nur dieser eine Termin.
- **Fix**: Dieselbe Prüfung wie in `MapMarkerPlanner` verwenden (Helfer dorthin ziehen oder auf `Port` heben), plus ein Planner-Test mit `latitude = .nan` / `latitude = 999`.

### F05 — Überlappende Reconciles beim Stepper

- **File**: `ShipTrip/Views/Settings/NotificationSettingsView.swift:91-99`
- **Severity**: major · **Blocker**: nein (heilt beim nächsten App-Start)
- **Problem**: Jeder `onChange` startet über `reconcileAfterChange()` einen eigenen, nicht abbrechbaren `Task`. `reminderDaysBefore` hängt an einem Stepper — mehrere Taps in Folge erzeugen mehrere überlappende Läufe. `NotificationReconciler.reconcile` liest erst den Ist-Zustand (`pendingIdentifiers()`) und schreibt danach; da beide Schritte `await`-Punkte sind, kann ein älterer Lauf **nach** dem neueren fertig werden. Ergebnis: der `UNCalendarNotificationTrigger` trägt den vorletzten Vorlauf als letzten Stand — dieselbe Klasse Fehler, die Kriterium 3d gerade beheben soll. Selbstheilend erst beim nächsten Start.
- **Fix**: `onChange` + `Task` durch `.task(id: reminderToken)` ersetzen (`"\(notifyBeforeCruise):\(notifyOnCruiseDay):\(reminderDaysBefore)"`) — SwiftUI bricht den laufenden Task bei Token-Wechsel selbst ab. Alternativ den vorherigen Task in `@State` halten und `cancel()`.

### F06 — Reconcile-Test prüft nur den Weiterleiter

- **File**: `ShipTripTests/NotificationSettingsReconcileTests.swift:19-34`
- **Severity**: major · **Blocker**: nein
- **Problem**: Der Test ruft dreimal `view.settingsChanged(context:)` und zählt die Aufrufe der injizierten Closure. Er ändert keine Einstellung und berührt die `onChange`-Modifier in `NotificationSettingsView.swift:91-93` nicht. Löscht man alle drei Modifier, bleibt der Test **grün** — die eigentliche Regression (F12 aus dem Backlog: „Toggle löst keinen Reconcile aus") ist damit nicht abgesichert. Der Rot-Beweis aus 8df2c30 war ein Compile-Fehler an einer noch nicht existierenden Naht, kein Verhaltensbeweis. Der Testname („Jede Änderung einer Erinnerungs-Einstellung löst genau einen Abgleich aus") und die drei Fehlermeldungen („Toggle vor der Reise gleicht nicht ab" usw.) behaupten mehr, als der Test prüft.
- **Fix**: Testnamen und Meldungen auf das ehrlich Geprüfte zurücknehmen („Der Einstiegspunkt reicht jede Änderung an den Abgleich weiter"). Die tatsächliche Verdrahtung im TB2-UI-Durchklick belegen: Toggle umlegen → Pending-Requests prüfen. Ohne einen der beiden Belege bleibt Kriterium 3d unbewiesen.

### F07 — Rollback-Test trifft die Guard, nicht den Abbruch

- **File**: `ShipTripTests/CalendarMigrationCoordinatorTests.swift:38-59`
- **Severity**: major · **Blocker**: nein
- **Problem**: `failedMigrationRollsBack` migriert nach `"kalender-existiert-nicht"`. Damit wirft `migrateManagedEvents` schon an der Guard `CalendarSyncService.swift:313` (`calendarMissing`) — bevor ein einziges Event angefasst wurde. Geprüft wird also „nichts ist passiert, Identifier steht zurück", nicht der gefährliche Fall: Anlegen im Zielkalender bricht **mitten drin** ab. Diesen streift nur `failedRollbackIsReported`, wo die Wiederherstellung ebenfalls scheitert — der Pfad „Migration scheitert, Rollback gelingt, Bestand ist vollständig zurück" ist damit für einen echten Teilabbruch unbelegt. Ebenfalls ungetestet: der `.accessDenied`-Ausgang (`CalendarMigrationCoordinator.swift:50-55`).
- **Fix**: Variante mit `CalendarEventStoreDouble`, die erst beim **zweiten** `save` (oder beim `commit`) scheitert; danach Ereigniszahl in beidem Kalendern und `managedEventIdentifiers` prüfen. Dazu ein Fall mit entzogenem Zugriff für `.accessDenied`.

### F12 — Restore ohne Mapping: Bestandsschutz greift nicht

- **File**: `ShipTrip/Services/CalendarSyncService.swift:272-276`, Aufräumschleife `:168-174`
- **Severity**: major · **Blocker**: nein (bewusste Grenze aus LE2 — aber undokumentiert)
- **Problem**: `hasLiveTripEvent` prüft ausschließlich das persistierte Mapping. Nach Neuinstallation oder einem Restore ohne die UserDefaults-Domain ist es leer → die Migration entscheidet `itineraryOnly`, obwohl im Kalender Ganzreise-Termine des Nutzers stehen. **Verloren geht nichts**: Die Aufräumschleife iteriert über `identifiers.keys`, und der Trip-Schlüssel steht dort nicht (mehr) — sie kann den Termin also gar nicht löschen. Er bleibt aber als **unverwaltete Karteileiche** stehen: nie wieder aktualisiert, von `removeAllManagedEvents()` nicht erfasst, und bei jedem künftigen Sync unsichtbar. Die breite Marker-Suche (`resolveEvent:214-216`) rettet nur Entwürfe, die überhaupt erzeugt werden — der Trip-Entwurf wird es in `itineraryOnly` gerade nicht.
- **Fix**: Als Known Limitation in `docs/features/kalender-sync.md` aufnehmen (Pflicht, sonst ist Kriterium 1 „Bestand" falsch dokumentiert). Optional als Backlog: für den Bestandsnachweis dieselbe breite Marker-Suche nutzen, die im Sync-Kontext ohnehin erlaubt ist — kostet einen Predicate-Lauf einmalig.

### F08 — `hasLiveTripEvent` läuft auch ohne Zugriff

- **File**: `ShipTrip/Services/CalendarSyncService.swift:261-268`
- **Severity**: minor · **Blocker**: nein
- **Problem**: `hasLiveTripEvent` wird als Argument gebildet und damit **immer** ausgewertet — auch wenn `hasCalendarAccess == false` ist und `CalendarSyncModeMigration.run` die Entscheidung gar nicht trifft. Das ist ein Mapping-weiter Scan mit je einem `event(withIdentifier:)`-Roundtrip pro Eintrag, folgenlos.
- **Fix**: Parameter als `@autoclosure () -> Bool` deklarieren oder den Zugriffscheck vor die Auswertung ziehen.

### F09 — Rollback-Fehler wird verworfen

- **File**: `ShipTrip/Views/Settings/CalendarSyncSettingsView.swift:228`
- **Severity**: minor · **Blocker**: nein
- **Problem**: `case .rollbackFailed(let migrationError, _)` wirft den zweiten Fehler weg. Ausgerechnet im einzigen Fall, in dem der Nutzer Termine verloren haben kann, existiert keine Diagnose — weder Anzeige noch Log.
- **Fix**: `logger.error("Rollback fehlgeschlagen: \(rollbackError, privacy: .private)")` über den bestehenden `CalendarSync`-Logger.

### F10 — Case `none` kollidiert mit `Optional.none`

- **File**: `ShipTrip/Services/CalendarEventPlanner.swift:18`
- **Severity**: minor · **Blocker**: nein
- **Problem**: `CalendarSyncMode.none` schattet `Optional.none`. Auf einem `CalendarSyncMode?` bedeutet `mode == .none` still „ist nil" statt „Umfang aus" — der Compiler meldet nichts. `CalendarSyncMode(rawValue:)` liefert genau so ein Optional (`CalendarSyncPreferences.swift:29`), die Fallgrube liegt also im Weg.
- **Fix**: In `disabled` (oder `off`) umbenennen. Der rawValue ist neu und frei wählbar, kein Bestandsrisiko — anders als bei `tripOnly`/`tripAndItinerary`.

### F11 — Doku widerspricht dem Code-Stand

- **File**: `docs/features/kalender-sync.md` (Kopfzeile, Abschnitt „Verhalten heute", Acceptance-Tabelle)
- **Severity**: minor · **Blocker**: nein (K-Nachtrag nach Q1 ist im TASKPLAN vorgesehen)
- **Problem**: Auf HEAD steht „Welle 1 … ist geplant und noch nicht enthalten", „Default ist heute noch `tripOnly`", „Ein strukturierter, anklickbarer Ort ist Welle 1", und die Kriterien 1 / 2 / 3c / 3d stehen auf „in Arbeit". Der Code sagt an allen vier Stellen etwas anderes. Der CHANGELOG nennt ebenfalls nur Welle 0.
- **Fix (Auftrag an K-Nachtrag)**: Default `itineraryOnly`, die vier Modus-Fälle, `structuredLocation` inkl. Text-Fallback, der Marker-Key `calendarSyncModeMigratedV2` und die Restore-Grenze aus F12 unter „Known Limitations".

---

## Antworten auf die Prüffragen

**(1) Bestandsschutz — Aufrufpfad vor der Migrationsentscheidung?**
Nein, kein Sync-Pfad umgeht sie. `migrateSyncModeIfNeeded()` ist die **erste**
Anweisung von `synchronize(cruises:allowMarkerSearch:)` (`CalendarSyncService.swift:130`),
noch vor der `isEnabled`-Guard und zwölf Zeilen vor dem einzigen
`CalendarSyncPreferences.mode(in:)`-Lesen (`:142`). Beide öffentlichen Einstiege
laufen dort hindurch: `synchronize(cruises:)` (`:119-121`) und
`migrateManagedEvents` (`:317`); `removeAllManagedEvents` liest den Umfang gar
nicht. Damit sind `CalendarSyncObserver.swift:33`, alle Settings-Pfade, der
Coordinator und der App-Start abgedeckt. `hasManagedEvents` (`:64`) ruft sie
zusätzlich, das deckt den Kalenderwechsel aus der View
(`CalendarSyncSettingsView.swift:196`) ab.
**Kein Zugriff beim ersten Start:** Der Fall ist sauber gelöst.
`CalendarSyncModeMigration.swift:55` bricht ohne `fullAccess` **ohne** Marker ab,
die Entscheidung bleibt offen; `synchronize` wirft direkt danach ohnehin
`accessDenied` (`:132`), es wird also auch nichts mit dem Default synchronisiert.
Gewährt der Nutzer den Zugriff später, entscheidet der nächste Sync korrekt
anhand des dann lesbaren Mappings. Einzige Restlücke: schreibt der Nutzer in
diesem Zwischenzustand über den Umfang-Picker selbst einen Modus (bei
eingeschaltetem Sync ist der Picker trotz fehlenden Zugriffs bedienbar), gilt
dieser als bewusste Wahl und die Migration übernimmt ihn — das ist so gewollt.

**(2) Mapping-Erkennung / Restore-Fall.** Der Suffix-Test greift korrekt: Trip-Keys
lauten `cruise/<UUID>/trip` (`CalendarEventPlanner.swift:117`), Route-Keys enden
auf `/route/<UUID>` (`:134`) — keine Kollision. Bei **leerem Mapping nach Restore**
entscheidet die Migration `itineraryOnly`. Der Ganzreise-Termin geht dabei
**nicht verloren**: die Aufräumschleife (`CalendarSyncService.swift:168-174`)
iteriert ausschließlich über `identifiers.keys` und kann einen nicht gemappten
Termin nicht anfassen. Er bleibt aber als unverwaltete Karteileiche liegen —
siehe F12, Dokumentationspflicht.

**(3) `none`-Modus.** Ja, und ja, gewollt (LE1). Bei `.none` liefert
`makeDrafts` eine leere Liste (`CalendarEventPlanner.swift:91-96`, getestet in
`CalendarSyncPlannerTests` → `noneCreatesNoDrafts`), `desiredKeys` ist leer und
die Schleife `:168-174` entfernt sämtliche gemappten Events und leert das
Mapping. Zwei Randnotizen: `synchronize` gibt dann `0` zurück, was in der View
als „0 Kalendereinträge synchronisiert" erscheint (harmlos), und der
Service-seitige Vollabräumer ist noch ungetestet — nur die Planer-Ebene ist
belegt.

**(4) structuredLocation.** Null-Insel-Check ist vorhanden, aber schwächer als
der projekteigene Standard (F04: kein NaN/Range-Check, anders als
`MapMarkerPlanner`). Der Fallback auf Text bei fehlender Koordinate existiert
(`:244-247`) und ist auf Draft-Ebene getestet, auf Service-Ebene nicht.
`geoLocation` wird korrekt als `CLLocation` gesetzt, der Titel ist der bisherige
Text („Lissabon, Portugal") — sinnvoll. `radius` bleibt ungesetzt: richtig, der
zählt nur für ortsbasierte Alarme. Problematisch ist der behauptete Aufräumpfad
(F03), der auf einer von Apple nicht dokumentierten Kopplung zwischen `location`
und `structuredLocation` beruht.

**(5) Coordinator — Reihenfolge und Journal.** Reihenfolge korrekt: erst
`setCalendarIdentifier(previousIdentifier)`, dann `service.synchronize(...)`
(`CalendarMigrationCoordinator.swift:56-58`) — anders herum schriebe die
Wiederherstellung in den falschen Kalender. **Der Rollback kann keine gefährlichen
Journal-Einträge hinterlassen**: Das Journal wird ausschließlich **nach** dem
erfolgreichen `commit()` geschrieben (`CalendarSyncService.swift:185-187`); wirft
irgendetwas davor, verwirft `eventStore.reset()` (`:178`) die Transaktion und die
lokale `replaced`-Liste stirbt mit dem Stack. Wirft es danach, ist die Migration
gelungen und der Nachlauf beim nächsten Start ist genau das gewünschte Verhalten.
Auch `drainPendingRemovals` selbst wirft nicht (es loggt, `:290-294`), kann den
Ausgang also nicht verfälschen. Die T3-Interaktion ist damit sauber. Offen bleibt
nur die Diagnose (F09) und die Testtiefe (F07).

**(6) Reconcile-Closure.** MainActor-sauber: Die Closure ist explizit
`@MainActor (ModelContext) async -> Void`, der Default kapselt den ebenfalls
MainActor-isolierten `NotificationReconciler.run`, und `ModelContext` überquert
keine Aktorgrenze. Kein doppelter Reconcile durch onChange-Ketten — die drei
Modifier hängen an drei unabhängigen Keys, eine Nutzeraktion ändert genau einen,
und keiner der Handler schreibt einen der anderen. **Aber** die Läufe sind nicht
serialisiert: schnelle Stepper-Änderungen erzeugen überlappende Tasks, deren
Reihenfolge nicht garantiert ist (F05).

**(7) Tests / Test-Diff-Verhältnis.** `existingTripEventSurvivesTheUpdate`
(`CalendarSyncModeMigrationTests.swift:112-131`) ist ein echter Verhaltenstest am
Bestand: Er baut über `MigrationFixture` einen realen Vorzustand (Mapping mit
Trip-Schlüssel, Termin im echten EventStore), löscht Modus **und** Marker,
synchronisiert und prüft beides — Modus `tripOnly` **und** Ereigniszahl 1. Bei
einem Rückbau der Migration wird er rot. Die vier Entscheidungspfade
(`:31-101`) sind dagegen reine Tabellen-Tests gegen `run(in:hasCalendarAccess:hasLiveTripEvent:)`;
sie belegen die Entscheidungslogik korrekt, aber nicht ihre Verdrahtung im
Service — die deckt allein der eine Verhaltenstest ab. Das ist vertretbar, weil
er genau die Naht trifft.
**Test-Diff > Code-Diff bei T1 (~350 vs. ~250):** begründet, keine Stapelei. Der
Überhang steckt fast vollständig in Infrastruktur, die pro Test **einmal**
existiert und wiederverwendet wird: `DefaultsSuite` (isolierte UserDefaults, F15)
und die `MigrationFixture`-Erweiterung (~50 Zeilen), plus `sampleCruise` im
Planner-Test. Keine copy-pastierten Testkörper, keine Mega-Asserts; jeder Test
hat eine Aussage. F15/F16 sind eingehalten: keine Suite fasst
`UserDefaults.standard` an, `tearDown` räumt beide Testkalender ab, und der
Init-Fehlerpfad (`CalendarSyncServiceMigrationTests.swift`, F16-Kommentar)
entfernt den ersten Kalender bei einem geworfenen Init.
Lücken: F06 (Reconcile-Verdrahtung), F07 (Rollback-Teilabbruch), Text-Fallback
auf Service-Ebene, `.none` auf Service-Ebene, `.accessDenied` im Coordinator.

**(8) `guard.py sizes`.** Über alle 12 geänderten Swift-Dateien gelaufen:
`sizes: ok (12 geprueft, 0 Soft-Warnungen)`, **exit 0**. Keine Datei nähert sich
der 500-Zeilen-Grenze; die Auslagerung von `CalendarSyncPreferences` und
`CalendarSyncModeMigration` in eigene Dateien hat `CalendarSyncService.swift`
sogar entlastet.

**(9) Doku (K).** Ja, `docs/features/kalender-sync.md` widerspricht dem
Code-Stand auf HEAD an vier Stellen, der CHANGELOG deckt nur Welle 0 ab —
beides ist der im TASKPLAN vorgesehene K-Nachtrag nach Q1, kein Fehler des
Wave-1-Diffs. Der Nachtrag muss zusätzlich die Restore-Grenze (F12) unter
„Known Limitations" aufnehmen; die dort bereits stehenden drei Limitationen
(Zwei-Geräte-Fall, Journal bei Dauerfehler, Source-Grenzen) sind korrekt und
decken sich mit dem Code. Der `CLAUDE.md`-Zusatz (Services-Liste) stimmt.

## Backlog-Vorschlag (alle 12 Findings, kein Blocker)

```
- [major] ShipTrip/Views/Settings/CalendarSyncSettingsView.swift:42 — Zweiter Default-Leseort mit altem Default tripOnly (T5)
- [major] ShipTrip/Views/Settings/CalendarSyncSettingsView.swift:129-140 — Picker bietet "Keine Einträge" ohne Hinweis (T5)
- [major] ShipTrip/Services/CalendarSyncService.swift:239-254 — location/structuredLocation-Aufräumpfad undokumentiert
- [major] ShipTrip/Services/CalendarEventPlanner.swift:167 — Koordinaten ohne NaN/Range-Check (vgl. MapMarkerPlanner)
- [major] ShipTrip/Views/Settings/NotificationSettingsView.swift:91-99 — Reconcile-Tasks nicht serialisiert
- [major] ShipTripTests/NotificationSettingsReconcileTests.swift:19-34 — Test prüft nur den Weiterleiter
- [major] ShipTripTests/CalendarMigrationCoordinatorTests.swift:38-59 — Rollback-Test trifft nur die Guard
- [major] ShipTrip/Services/CalendarSyncService.swift:272-276 — Restore ohne Mapping: Karteileiche, undokumentiert
- [minor] ShipTrip/Services/CalendarSyncService.swift:261-268 — hasLiveTripEvent auch ohne Kalenderzugriff ausgewertet
- [minor] ShipTrip/Views/Settings/CalendarSyncSettingsView.swift:228 — Rollback-Fehler verworfen
- [minor] ShipTrip/Services/CalendarEventPlanner.swift:18 — Case none kollidiert mit Optional.none
- [minor] docs/features/kalender-sync.md — Doku widerspricht Code-Stand (K-Nachtrag)
```

## Empfehlung an Winston

Wave 1 ist freigegeben. Die drei Fixes, die vor dem Release stattfinden sollten
und **keiner** späteren Welle gehören: F03 (zwei Zeilen + Test), F04 (eine
Prüfung angleichen), F05 (`onChange`+`Task` → `.task(id:)`). F01/F02 gehören in
den T5-Auftrag und müssen im Q2-Review namentlich abgehakt werden. F11/F12
gehören in den K-Nachtrag.
