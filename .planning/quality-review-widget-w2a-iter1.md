# Review — Widget 1.9.0, Welle 2a (T3 Publisher/Hook + W1-Fix)

- **Iteration**: 1 / 3
- **Reviewer**: quality-agent (frischer Spawn)
- **Datum**: 2026-09-03
- **Scope**: Worktree `/Users/andre-studio/Documents/0.Projekte/ShipTrip-worktrees/widget-1.9.0`,
  HEAD `bed8003`. Commits `926e723` (T3) und `c2c6382`+`bed8003` (W1-Fix).
  `ShipTripWidget/` (T4) ausdruecklich **nicht** im Scope.
- **Geladene Skills**: `code-review`, `swift-standards`, `swiftdata`, `xctest-ios`
- **Verdict**: **GO-mit-Backlog** (approve)
- **Stats**: critical 0, major 1, minor 5 — Blocker 0, Backlog 6

## Summary

Der W1-Fix sitzt. F01, F02, F03 und F07 sind **alle vier erledigt** und in
eigenen, adversarialen Proben bestaetigt — nicht nur „Test gruen", sondern die
konkreten Zahlen aus dem W1-Report (P7, P8) drehen sich jetzt ins Erwartete.
Der Publisher aus T3 ist handwerklich sauber: die Isolation stimmt (kein
`@Model` verlaesst den MainActor), der Writer-Aktor serialisiert wirklich,
die Entprellung koalesziert nachweislich, und der Bestandsschutz in
`ShipTripApp.swift` ist rein additiv — 69 Zeilen `+`, **null** `-`.

Der eine offene Punkt ist kein Bug im Gelesenen, sondern eine **Luecke im
Beweis**: kein Test und kein Lauf deckt ab, ob beim *Erststart ohne
Bearbeitung* ueberhaupt ein Snapshot entsteht. Alle drei Trigger haengen an
einem Ereignis, das in diesem Fall vielleicht nie kommt. Das blockiert W2a
nicht — T4/T5 stehen noch aus —, gehoert aber vor die T5-Abnahme.

## Test-Lauf (ein Gate-Lauf, Wegwerf-Sim `ci-q-w2a`, iPhone 17 / iOS 26.5)

- `evidence_path`:
  `/Users/andre-studio/Documents/0.Projekte/ShipTrip-worktrees/widget-1.9.0/.winston-evidence/20260903T153457Z/gate-run.json`
- `build` (`xcodebuild build-for-testing -scheme ShipTrip`): **exit 0**.
  **Null Warnungen in den Scope-Dateien** (`WidgetSnapshot*`, `WidgetState*`,
  `WidgetTimeline*`, `ShipTripApp`) — geprueft per Grep ueber `build.log`.
  Die 158 Warnungen im Log stammen samt und sonders aus Altbestand
  (`ShippingLine*Tests`, `TempPortCoordinatesTests`,
  `CruiseGeoFallbackView.swift:68`) und sind nicht W2a.
- `tests`: **exit 0**, **46 total / 46 passed / 0 failed / 0 skipped**.
  Davon 38 Produktivtests (Store 6, Resolver 18, Planner 6, Publisher 8) und
  8 eigene Probe-Faelle — **alle acht Proben gruen**, also keine der
  Erwartungen aus dem Pruefauftrag verletzt.
- Statischer Pass `guard.py sizes` ueber alle 8 geaenderten Dateien:
  `ok (8 geprueft, 0 Soft-Warnungen)`. Groesster Brocken:
  `ShipTripApp.swift` 354 Zeilen (unter dem 400er-Soft-Limit).
- Probe-Datei `ShipTripTests/QualityW2aProbeTests.swift` nach dem Lauf
  geloescht, `build/dd` + `build/q2a.xcresult` entfernt, Simulator via `trap`
  weg, `git status` leer. Nichts committet.

### Eigene Proben — Erwartung vs. Ist

| # | Fall | Erwartung | Ist |
|---|------|-----------|-----|
| QP1 | aktiv, 10 Stopps, `now` = Tag 3 | 12 Eintraege, streng aufsteigend, max. Luecke <= 25 h, letzter >= now+24 h | **wie erwartet** |
| QP2 | Countdown 40 Tage | genau 12 Eintraege, letzter = Mitternacht Tag 11 | **wie erwartet** (`dates.last == startOfDay(now+11d)`) |
| QP3 | **drei** Stopps am selben Tag | nach allen: C/D · vor allen: A/B · zwischen B und C: B/C | **wie erwartet** |
| QP4 | zwei Stopps am selben Tag, der zweite ist Routenende | current = „B", next = `nil`, `isAfterLastStop == true` | **wie erwartet** |
| QP5 | 60 Stopps, `now` am Stopp 50 | Fenster `Hafen 20…59`, enthaelt 50 **und** alle Nachfolger 51–59; Resolver findet current=50, next=51 | **wie erwartet** |
| QP6 | Fehlerpfad-Store `/dev/null/...` | wirft **wirklich**; Gegenprobe: blosses Fehlen eines Verzeichnisses wirft **nicht** | **wie erwartet** — Injektion ist echt |
| QP7 | 8x `publish()`, dann 1x `publish()` | 1 Reload, danach 2 — kein Double-Reload, Cancel greift | **wie erwartet** |
| QP8 | nur die Beispielreise im Store | Snapshot leer | **wie erwartet** |

## Findings

| ID  | Severity | Blocker | File:Line | Kategorie | Titel |
|-----|----------|---------|-----------|-----------|-------|
| F01 | major    | nein    | `ShipTrip/ShipTripApp.swift:293-322` + `ShipTripTests/WidgetSnapshotPublisherTests.swift:271-280` | tests | Erststart ohne Bearbeitung: kein Beweis, dass ueberhaupt ein Snapshot entsteht |
| F02 | minor    | nein    | `ShipTrip/Services/WidgetSnapshotPublisher.swift:63-69` | design/docs | `publishNow()` hat keinen Produktiv-Aufrufer; der Doc-Kommentar behauptet einen |
| F03 | minor    | nein    | `ShipTrip/Services/WidgetSnapshotPublisher.swift:207-212` | correctness | `anchorIndex` traegt genau die Tages-Tie-Schwaeche, die W1-F02 im Resolver behoben hat |
| F04 | minor    | nein    | `ShipTrip/Services/WidgetSnapshotPublisher.swift:105` | robustness | `Calendar.current` in der Auswahl — Zeitzonenwechsel zwischen Schreiben und Lesen |
| F05 | minor    | nein    | `ShipTrip/WidgetShared/WidgetTimelinePlanner.swift:19` | docs | `minimumHorizon` wird nur noch vom Test durchgesetzt, nicht mehr vom Code |
| F06 | minor    | nein    | `ShipTripTests/WidgetSnapshotPublisherTests.swift:219-243` | tests | Fehlerpfad-Test belegt den Reload-Ausfall, nicht den Dateizustand |

---

### F01 — Erststart ohne Bearbeitung ist unbewiesen (major, kein Blocker)

- **File**: `ShipTrip/ShipTripApp.swift:293-322`,
  `ShipTripTests/WidgetSnapshotPublisherTests.swift:271-280`
- **Kategorie**: tests / ZIEL K3
- **Problem**: Es gibt genau drei Trigger — `ModelContext.didSave`
  (`:299-306`), `.NSPersistentStoreRemoteChange` (`:310-317`) und
  `scenePhase == .active` (`:320-322`). Bei einem **Kaltstart im Release ohne
  Nutzer-Bearbeitung** feuert keiner davon sicher: `didSave` braucht einen
  Save (die Demo-/UI-Test-Saves im `init` stehen alle unter `#if DEBUG`),
  Remote-Change braucht einen CloudKit-Merge, und `.onChange(of: scenePhase)`
  feuert per Definition nur bei einer **Aenderung** — ist `scenePhase` bei der
  ersten Body-Auswertung schon `.active`, gibt es keine.

  Der Test `initDoesNotPublish` (`:271-280`) zementiert diese Kante sogar:
  er belegt, dass die Konstruktion nichts schreibt — er belegt aber nicht,
  dass irgendetwas anderes es im Erstlauf tut. Faellt der Fall durch, sieht
  ein Nutzer, der die App nur oeffnet und liest, im Widget dauerhaft
  „keine Daten". Ich konnte das weder widerlegen noch belegen: es haengt an
  SwiftUI-Laufzeitverhalten, das nur ein Geraete-/UI-Lauf zeigt — und den
  gibt es in T3 nicht. **Kein Blocker fuer W2a** (T4 und der Geraetebeweis in
  T5 stehen noch aus), aber ein Muss vor der T5-Abnahme.
- **Fix** (zwei Zeilen, macht die Frage gegenstandslos und erledigt F02 mit):

  ```swift
  // ShipTripApp.swift, an der Modifier-Kette neben den drei .onReceive/.onChange:
  .task { await widgetPublisher?.publishNow() }
  ```

  Danach ist der Erstlauf bedingungslos gedeckt, `publishNow()` hat einen
  Produktiv-Aufrufer, und `initDoesNotPublish` bleibt gueltig (die
  Konstruktion schreibt weiterhin nichts). Ergaenzend im T5-Geraetebeweis
  explizit den Fall „frische Installation, Widget hinzufuegen, App einmal
  oeffnen **ohne** zu bearbeiten" abklappern.

### F02 — `publishNow()` ohne Produktiv-Aufrufer (minor)

- **File**: `ShipTrip/Services/WidgetSnapshotPublisher.swift:63-69`
- **Kategorie**: design / docs
- **Problem**: Der Doc-Kommentar sagt „Fuer `scenePhase`-Uebergaenge und
  Tests" — der scenePhase-Zweig ruft aber `publish()`
  (`ShipTripApp.swift:321`). `publishNow()` wird ausschliesslich von den
  Tests benutzt (9 Aufrufe). Das ist kein Test-Flag und kein `#if DEBUG`,
  also keine Hintertuer im engeren Sinne, und der Produktivpfad `publish()`
  ist eigenstaendig getestet (`repeatedPublishCoalescesIntoOneReload`, plus
  meine Probe QP7) — aber der Kommentar beschreibt Code, den es nicht gibt.
- **Fix**: Mit dem F01-Fix bekommt `publishNow()` seinen echten Aufrufer;
  dann stimmt der Kommentar. Andernfalls den Kommentar auf „Fuer Tests und
  Aufrufer, die auf den Schreibvorgang warten muessen" kuerzen.

### F03 — `anchorIndex` mit derselben Tages-Tie-Schwaeche wie W1-F02 (minor)

- **File**: `ShipTrip/Services/WidgetSnapshotPublisher.swift:207-212`
- **Kategorie**: correctness
- **Problem**: `stops.firstIndex { startOfDay($0.arrival) == today }` nimmt
  bei zwei Stopps am selben Kalendertag den **ersten** — exakt das Muster,
  das W1-F02 im Resolver (`WidgetStateResolver.swift:168-172`) behoben hat.
  Beide Dateien behaupten im Kommentar „identisch zu `WidgetStateResolver`"
  (`:187-189`), sind es an dieser Stelle aber nicht mehr.
  **Folgenlos in der Sache**: der Anker steuert nur das 40er-Fenster, das
  5 Eintraege zurueck und ~35 nach vorn reicht — ein Versatz um einen Slot
  faellt nicht auf. Es ist eine Konsistenz-, keine Verhaltensschuld.
- **Fix**: dieselbe Auswahl wie im Resolver spiegeln:

  ```swift
  let todays = stops.indices.filter { calendar.startOfDay(for: stops[$0].arrival) == today }
  if let started = todays.last(where: { stops[$0].arrival <= now }) { return started }
  if let first = todays.first { return first }
  ```

### F04 — `Calendar.current` in der Auswahl (minor)

- **File**: `ShipTrip/Services/WidgetSnapshotPublisher.swift:105`
- **Kategorie**: robustness / LE 2
- **Problem**: Schreiber und Leser rechnen Kalendertage in **verschiedenen
  Momenten** — die App beim Speichern, das Widget beim Rendern. T3 nennt
  `Calendar.current` bewusst, und fuer den **Fensterschnitt ist das Risiko
  nicht real**: Anker plus 5 Slots Vorlauf und ~35 Nachlauf schlucken jede
  Tagesverschiebung um +/-1 muehelos (in QP5 belegt: Fenster 20–59 bei Anker
  50). Rest-Risiko liegt allein in der **Reisenauswahl**: springt die
  Zeitzone zwischen Schreiben und Lesen ueber eine Mitternacht, kann die
  Publisher-Seite eine heute endende Reise als „vergangen" einstufen und sie
  aus den drei Kandidaten kippen. Selbstheilend beim naechsten Vordergrund
  (`scenePhase`-Hook) — deshalb minor.
- **Fix**: kein Codefix noetig; eine Zeile Kommentar an `:105`, die genau das
  festhaelt („Fenster toleriert Tagesversatz, Auswahl heilt ueber den
  scenePhase-Hook"), damit die Entscheidung nicht spaeter neu verhandelt wird.

### F05 — `minimumHorizon` nur noch testseitig durchgesetzt (minor)

- **File**: `ShipTrip/WidgetShared/WidgetTimelinePlanner.swift:19`
- **Kategorie**: docs
- **Problem**: Nach dem F01-Fix referenziert **kein Produktivcode** die
  Konstante mehr; einzig `WidgetTimelinePlannerTests.swift:129` prueft sie.
  Der Doc-Kommentar („So weit reicht die Timeline mindestens") liest sich
  wie eine Zusicherung des Planers, ist aber nur noch eine Zusicherung des
  Tests. Der Horizont wird faktisch eingehalten (12 Tagesmitternachte
  reichen weit ueber 24 h) — das ist Formulierung, nicht Verhalten.
- **Fix**: Kommentar auf „Zusicherung, die die Tests pruefen — der Planer
  erfuellt sie ueber die Tagesmitternachte" umstellen.

### F06 — Fehlerpfad-Test prueft den Dateizustand nicht (minor)

- **File**: `ShipTripTests/WidgetSnapshotPublisherTests.swift:219-243`
- **Kategorie**: tests
- **Problem**: Der Test belegt `saved == 2` und `calls == 0`. Dass danach
  **keine halb geschriebene Datei** zurueckbleibt, prueft er nicht. Die
  Fehlerinjektion selbst ist einwandfrei — ich habe sie gegengeprueft (QP6):
  `/dev/null/shiptrip-widget` laesst `createDirectory` mit `ENOTDIR`
  scheitern, und die Gegenprobe zeigt, dass ein blosses **fehlendes**
  Verzeichnis eben *nicht* wirft (der Store legt es an). Der Test misst also
  wirklich einen Schreibfehler, nicht eine Attrappe.
- **Fix**: eine Zeile ergaenzen: `#expect(store.load() == .missing)`.

## Status der W1-Findings

| W1-ID | Status | Beleg |
|-------|--------|-------|
| F01 (critical, Timeline-Luecke) | **resolved** | Fix ist exakt der vorgeschlagene: `dailyMidnights(after:count:)` speist die Mitternachte als Kandidaten ein (`WidgetTimelinePlanner.swift:44-48, 82-95`), der Deckel greift erst nach dem Sortieren. QP1: 12 Eintraege, max. Luecke <= 25 h. QP2 (das ehemalige P8, jetzt 40 statt 30 Tage): **genau 12 Eintraege, letzter = Mitternacht Tag 11** statt der drei von damals. |
| F02 (major, Tages-Ties) | **resolved** | `WidgetStateResolver.swift:168-172`: `todays.last(where: arrival <= now)`, Rueckfall auf `todays.first`. QP3 mit **drei** Stopps am selben Tag (haerter als die Dev-Fixture): nach allen → C/D, vor allen → A/B, dazwischen → B/C. QP4: der letzte Tagesstopp als Routenende ergibt korrekt `isAfterLastStop == true`. Kein Rueckschritt fuer den Normalfall „ein Stopp pro Tag" (18 Resolver-Tests gruen). |
| F03 (major, Test prueft die Regel nicht) | **resolved** | Zwei echte Luecken-Tests ergaenzt — `countdownFarAheadHasNoGaps` und `activeWithDistantEndHasNoGaps` (`WidgetTimelinePlannerTests.swift:110-144`), beide mit `maximumGap(in:) <= 25 h` **und** `count == maxEntries`. Der Helfer `maximumGap` (`:32-35`) prueft die Regel, nicht den Buchstaben. Zusaetzlich zwei Bestandstests auf `prefix(4)` + `count == maxEntries` nachgezogen. |
| F07 (minor, irrefuehrender Kommentar) | **resolved** | `WidgetTimelinePlanner.swift:50-52`: „Der Deckel greift erst nach dem Sortieren: die nahen Ankunfts- und Abfahrtszeiten ueberleben ihn, nur ferne Mitternachte fallen weg." Die falsche „hoechstens sechs Kandidaten"-Begruendung ist weg. |

## Beantwortung der Prueffragen

**1. W1-Fix verifiziert?** Ja, alle vier — siehe Tabelle oben, eigene Proben
QP1–QP4. Beide im Auftrag genannten Proben treffen punktgenau: Countdown
40 Tage → 12 Eintraege, letzter = Tag 11 Mitternacht; aktive Reise mit
10 Stopps, `now` Tag 3 → keine Luecke ueber 25 h.

**2. Bestandsschutz — eingehalten.**
`git diff 6547753..bed8003 -- ShipTrip/ShipTripApp.swift`: **69 Zeilen `+`,
0 Zeilen `-`.** Rein additiv.
- Store-Konfiguration (`ShipTripCloudSync.persistentConfiguration`,
  In-Memory-Fallback, `modelContainer = nil`-Zweig): **unveraendert**; die
  einzige Ergaenzung im `init` ist die Zuweisung `widgetPublisher = …`
  (`:79-82`) **nach** dem `do/catch`.
- CloudKit-Setup: unveraendert (`ShipTripCloudSync.swift` nicht im Diff).
- Reminder-/Kalender-/`onOpenURL`-Aufrufe: unveraendert. Die drei neuen
  Modifier stehen **zwischen** `.onOpenURL` und der Cover-Praesentation;
  `.onReceive`/`.onChange` veraendern die Umgebung nicht, die Begruendung
  „Praesentation bewusst nach `.modelContainer`" bleibt also intakt.
- `didSave`-Observer **mit** `object: container.mainContext` —
  `ShipTripApp.swift:301-303`. ✔
- `publish()` laeuft **nie** bei: `modelContainer == nil` oder
  `usingTemporaryStore` (`:109`, ein Guard fuer beide), UI-Test-Argument
  (`:110-112`, `hasPrefix("-uiTesting")` deckt alle vier Varianten ab),
  fehlendem App-Group-Container (`:113-116`, protokolliert, kein
  Startfehler). Ist eine dieser Bedingungen wahr, ist `widgetPublisher` `nil`
  und alle drei Hooks laufen ins Leere (`widgetPublisher?.publish()`).

**3. Failure-Injection real? Ja.** QP6 belegt beides: `/dev/null/shiptrip-widget`
laesst `FileManager.createDirectory` mit `ENOTDIR` scheitern (echter
Schreibfehler), waehrend ein blosses **fehlendes** Verzeichnis nicht wirft —
der Store legt es selbst an (`WidgetSnapshotStore.swift:88-91`). Der Test
misst also keinen Attrappen-Fehler. Kein Throw nach aussen
(`WidgetSnapshotPublisher.swift:89-94` faengt und protokolliert), Save der App
weiterhin ok (`saved == 2`), Reload 0. Einzige Luecke: F06.

**4. Koaleszierung + Isolation — sauber.**
- *Debounce*: `schedule()` (`:71-83`) cancelt `pending` **vor** dem Ersetzen;
  der Nachfolger steigt sowohl beim `Task.sleep`-Throw als auch ueber
  `!Task.isCancelled` aus. QP7 belegt: 8 Aufrufe → **1** Reload, ein
  weiterer Aufruf danach → **2**. Kein Double-Reload, kein verschlucktes
  Update.
- *`@Model` bleibt auf dem MainActor*: `makeSnapshot` (`:100-118`) ist
  `private` auf einer `@MainActor final class`; Fetch und die komplette
  Abbildung `Cruise`/`Port` → `CruiseSummary`/`StopSummary` laufen ohne ein
  einziges `await`. Ab `:88` traegt nur noch `WidgetSnapshot` (Sendable) die
  Grenze zum Aktor. Unter `SWIFT_STRICT_CONCURRENCY = complete` haette der
  Compiler alles andere abgefangen — **0 Warnungen** im Scope.
- *Writer-Aktor*: `actor WidgetSnapshotWriter` mit einer einzigen `save`
  (`WidgetSnapshotWriter.swift:16-28`) serialisiert; `WidgetSnapshotStore`
  ist ein zustandsloser `Sendable`-Struct. Kein `@unchecked Sendable` im
  Produktivcode.
- *Retain-Zyklen / Doppel-Registrierung*: **kein einziges
  `NotificationCenter.addObserver`** — beide Hooks sind SwiftUI-`.onReceive`
  ueber Combine-Publisher, deren Abo an der View haengt. Kein Token, das
  leaken koennte, kein manuelles Aufraeumen noetig, kein Zyklus (die App ist
  ein `struct`, der Publisher haelt keine Rueckreferenz). Szenen-Neuaufbau
  erneuert das Abo statt es zu verdoppeln; eine zweite Szene gaebe es nur bei
  `TARGETED_DEVICE_FAMILY != 1` (hier `= 1`, iPhone), und selbst dann
  koalesziert die Entprellung. Die `Task`s in `publish()`/`schedule()` halten
  `[weak self]`.
- *Klein*: `pending` wird nach Abschluss nicht auf `nil` gesetzt — ein
  beendeter Task bleibt bis zum naechsten `publish()` referenziert. Folgenlos,
  kein Finding.

**5. Auswahl LE 2 — erfuellt.** Hoechstens drei Reisen (aktiv/naechste/juengste,
`select` `:125-146`, `prefix(maxCruises)`), Demo raus (`#Predicate<Cruise> {
$0.isDemo == false }`, `:102`; QP8: nur Beispielreise → Snapshot leer),
Route <= 40 mit Fenster (`capped` `:198-203`). **Eigene Probe QP5**
(60 Stopps, `now` am Stopp 50): Fenster ist `Hafen 20 … Hafen 59` — enthaelt
Stopp 50 **und alle** Nachfolger 51–59; der Resolver liest daraus current =
Hafen 50, next = Hafen 51. Die Klemmung ist auch an den Raendern sicher: wegen
`guard stops.count > limit` ist `upper - limit >= 0`, ein negativer
Slice-Index kann nicht entstehen. **Zeitzonen-Risiko fuer den Fensterschnitt:
nicht real** — Begruendung und das verbleibende Rest-Risiko in F04.

**6. Remote-Change — Entwarnung, mit Vorbehalt.**
Recherche ueber Apple-Doku und Developer-Forum (kein Modellwissen):
- In **Core Data** ist `NSPersistentStoreRemoteChangeNotificationPostOptionKey`
  tatsaechlich ein Opt-in — „In the persistent container, set the
  `NSPersistentStoreRemoteChangeNotificationPostOptionKey` option to `true` to
  enable listening for remote change notifications."
  (<https://developer.apple.com/documentation/coredata/consuming-relevant-store-changes>,
  <https://developer.apple.com/documentation/CoreData/NSPersistentStoreRemoteChangeNotificationPostOptionKey>)
- Fuer **SwiftData** sagt Apple-DTS (Ziqiao Chen, Apple WWDR) woertlich:
  „SwiftData + CloudKit turns on
  `NSPersistentStoreRemoteChangeNotificationPostOptionKey` automatically, and
  you can observe the `.NSPersistentStoreRemoteChange` notification in the
  same way as you do with Core Data."
  (<https://developer.apple.com/forums/thread/761875>, deckungsgleicher
  Erfahrungsbericht: <https://developer.apple.com/forums/thread/732951>)
- ShipTrip erfuellt die Bedingung: `ShipTripCloudSync.swift:19-25` setzt im
  Produktivlauf `cloudKitDatabase: .private("iCloud.com.andre.ShipTrip")`
  (nur unter XCTest/UI-Test `.none`).
- `ModelContext.didSave` ist ausdruecklich **kein** Ersatz: es feuert bei
  Context-Saves, nicht bei Remote-Merges
  (<https://developer.apple.com/documentation/swiftdata/modelcontext/didsave>).
  Der zweite Hook ist also nicht redundant.

**Vorbehalt, der ins Backlog gehoert**: das ist eine Forums-Aussage, kein
Vertrag in der API-Referenz. Der Code behandelt den Fall aber ohnehin
defensiv richtig — faellt die Notification aus, faengt der
`scenePhase`-Hook den Merge beim naechsten Vordergrund. Kein Finding.
*(Nebenbei: der Remote-Change-Observer filtert bewusst **nicht** ueber
`object:` — bei SwiftData gibt es keinen Zugriff auf den Coordinator, und die
App fuehrt genau einen Store. Kosten eines Fehlalarms: ein entprelltes
Schreiben. Korrekt so.)*

**7. Groessen und Deckel.**
- `guard.py sizes --files` ueber alle 8 geaenderten Dateien: **exit 0**,
  0 Soft-Warnungen. Groesste Datei `ShipTripApp.swift` mit 354 Zeilen.
- **T3**: Code 318 Zeilen (Publisher 220 + Writer 29 + App 69) vs. Test 281 →
  Test **<=** Code. ✔
- **W1-Fix**: Code +49/-16 (2 Dateien) vs. Test +66/-2. Test > Code —
  **akzeptabel**: der Ueberhang ist exakt der Rot-Beweis, den W1-F03 als
  eigenes Finding eingefordert hat (zwei Luecken-Tests plus der
  Tages-Tie-Test). Ein Bugfix, dessen fehlende Abdeckung selbst das Finding
  war, darf mehr Test als Code tragen; die Testumfangs-Leiter verlangt beim
  Bugfix ausdruecklich den Repro-Test.

## Backlog-Kandidaten (kein Fix-Auftrag in diesem Lauf)

- [major] ShipTrip/ShipTripApp.swift:293-322 — Erststart ohne Bearbeitung: keiner der drei Trigger feuert sicher; `.task { await widgetPublisher?.publishNow() }` ergaenzen und den Fall im T5-Geraetebeweis abklappern (F01)
- [minor] ShipTrip/Services/WidgetSnapshotPublisher.swift:63-69 — `publishNow()` ohne Produktiv-Aufrufer; Doc-Kommentar behauptet den scenePhase-Pfad, der `publish()` nutzt (F02)
- [minor] ShipTrip/Services/WidgetSnapshotPublisher.swift:207-212 — `anchorIndex` traegt die Tages-Tie-Schwaeche, die W1-F02 im Resolver behoben hat; Kommentar „identisch zu WidgetStateResolver" stimmt nicht mehr (F03)
- [minor] ShipTrip/Services/WidgetSnapshotPublisher.swift:105 — `Calendar.current` in der Auswahl: Fensterschnitt unkritisch, Reisenauswahl kann bei Zeitzonensprung ueber Mitternacht kippen (selbstheilend); Entscheidung am Code festhalten (F04)
- [minor] ShipTrip/WidgetShared/WidgetTimelinePlanner.swift:19 — `minimumHorizon` wird nach dem F01-Fix nur noch vom Test durchgesetzt; Doc-Kommentar entsprechend umstellen (F05)
- [minor] ShipTripTests/WidgetSnapshotPublisherTests.swift:219-243 — Fehlerpfad-Test prueft den Dateizustand nicht; `#expect(store.load() == .missing)` ergaenzen (F06)

## Verdict

**GO-mit-Backlog.** Keine offenen Blocker. Der W1-Fix ist vollstaendig und
belastbar — die vier Findings aus Welle 1 sind erledigt, in eigenen,
haerteren Proben bestaetigt, und der Fix ist genau der vorgeschlagene, ohne
Kollateralschaden (alle 18 Resolver- und 6 Planner-Tests gruen). T3 haelt
Bestandsschutz, Isolation und Koaleszierung sauber ein und ist rein additiv.

T4 (Provider) darf auf `WidgetTimelinePlanner.entryDates` in dieser Form
aufsetzen — die API ist jetzt stabil und die Zusagen sind regelgeprueft.

**Ein Punkt reist mit**: F01 muss vor der T5-Abnahme geschlossen sein, sonst
faellt der Widget-Erstlauf ohne Bearbeitung durchs Netz. Der Fix ist zwei
Zeilen; die Alternative ist, ihn auf dem Geraet zu suchen.
