# Review — Re-Review Fix-Runden 2 + 3 gegen Codex-Gate-#3 (Widget 1.9.0)

- **Iteration**: 1 / 3 (Ersatz fuer den zweiten Codex-Pass)
- **Reviewer**: quality-agent (frischer Spawn)
- **Datum**: 2026-09-03
- **Scope**: `git diff 085c5c3..3d4d5a1` im Worktree
  `/Users/andre-studio/Documents/0.Projekte/ShipTrip-worktrees/widget-1.9.0` (HEAD 3d4d5a1)
- **Geladene Skills**: code-review, swift-standards, swiftdata (+ xctest-ios als Test-Lens)
- **Verdict**: **approve — GO mit Backlog**
- **Stats**: critical 0, major 2, minor 4 — Blocker 0, Backlog 6
- **Testlauf**: kein eigener Lauf (Token-Auflage: kein xcodebuild/Simulator). Bewertet wurden
  die Developer-Artefakte `.winston-evidence/20260903T160134Z/gate-run.json` (45/45, Exit 0/0,
  status `verified`) und `.winston-evidence/20260903T161424Z/gate-run.json` (49/49, Exit 0/0,
  status `verified`) samt Logs. Statischer Pass:
  `guard.py sizes --files <12 geaenderte Swift-Dateien>` → `ok (12 geprueft, 0 Soft-Warnungen)`, Exit 0.

## Summary

Alle neun Codex-Findings der Liste sind erledigt — sieben davon durch einen Test belegt, der
die *Regel* trifft und nicht nur die Implementierung. Der Rot-Beweis existiert nicht als
Artefakt, ist aber in beiden Test-Commits mit konkreten Ist-/Soll-Werten je rotem Test
dokumentiert und deckt sich mit meiner Nachrechnung gegen den Vor-Zustand. Keine Regression an
ZIEL-K1. Offen bleiben zwei Release-Hygiene-Punkte (Doku-Stand, Evidenz-Commit-Stempel) und
vier Kleinigkeiten fuer das Backlog.

## Codex-Findings — Soll/Ist

| ID | Thema | Stand | Umsetzung | Beleg |
|----|-------|-------|-----------|-------|
| a1 F1 | Idle/Unavailable-Horizont >= 24 h, Luecken <= 24 h auch am DST-Tag | **erledigt** | `WidgetTimelinePlanner.swift:41-43` (Idle/Unavailable durch `filled`), `:64` (Active/Countdown), `:78-90` (`filled`), `:94-97` (`dayLater` ueber den Kalender) | `WidgetTimelinePlannerTests`: `idleAndUnavailable`, `idleOnShortDayStillCoversHorizon` (29.03., 23-h-Tag), `dstFallBackDayGetsIntermediateEntry` (25.10., 25-h-Tag) |
| a1 F3 | Stopp-Fenster halboffen `[arrival, departure)`, bei gleichzeitigem Beginn der kanonisch letzte | **erledigt** | `WidgetStateResolver.swift:164-167` — `firstIndex` → `lastIndex`, `now <= departure` → `now < departure`; Regel im Doc-Kommentar `:150-158` | `WidgetStateResolverTests`: `seamlessStopsSwitchAtDeparture`, `overlappingStopsUseCanonicallyLast`, `currentStopAtItsArrival`, Tie-Test `:160-170` auf dieselbe Regel gezogen |
| a1 F6 | Testsatz: `maximumGap <= 24 h` strikt, `now == departure`, `now == arrival`, Idle-Horizont, Stale-Grenze, Decoder-Toleranz | **erledigt** (6/6) | — | `WidgetTimelinePlannerTests:126,143` (`<= minimumHorizon` statt 25 h); `seamlessStopsSwitchAtDeparture`; `currentStopAtItsArrival`; `idleAndUnavailable`; `staleBoundary` (jetzt inkl. **exakt** 14 Tage); `WidgetSnapshotStoreTests.unknownFieldsAreIgnored` |
| a2 F1 | Snapshot aus separatem Lesekontext (nur persistierter Stand) | **erledigt** | `WidgetSnapshotPublisher.swift:127-136` — `ModelContext(container)` je Aufruf, `autosaveEnabled = false` | `WidgetSnapshotPublisherTests.unsavedChangesStayOutOfSnapshot` prueft Insert **und** Edit **und** Delete jeweils ungespeichert |
| a2 F2 | Fetch-Fehler → kein Write, kein Reload, Last-known-good bleibt | **erledigt** | `:105` (`guard let snapshot … else { return }`), `:131-136` (`nil` statt leerem Snapshot) | `fetchFailureKeepsLastKnownGood` — prueft beides: Store unveraendert **und** `spy.count == 0` |
| a2 F3 | Generationsnummer bis in den Writer, veraltete Writes + Reload verworfen | **erledigt** | `:103-104,107,113` (Publisher), `WidgetSnapshotWriter.swift:20,32-34` (`lastAccepted`-Guard) | `overlappingPublishesReloadOnce` (genau ein Reload bei zwei parallelen `publishNow()`), `writerDiscardsStaleGeneration` (Actor direkt) |

**Bewusst offen (bestaetigt, nicht nachgefordert):** a1 F2 (Tages-Eintrag vor Ankunft = ZIEL-Regel),
a1 F4/F5, a2 F4/F5/F6.

### Treffen die Tests die Regel?

Ja, mit einer Ausnahme (siehe N5). Stichproben:
- `dstFallBackDayGetsIntermediateEntry` behauptet nicht nur „Luecke <= 24 h", sondern verlangt
  konkret `dates.contains(at(10, 25, 23))` — den Zwischeneintrag, den die Regel erzwingt.
- `seamlessStopsSwitchAtDeparture` prueft 13:59 **und** 14:00 — die Grenze selbst, nicht nur eine
  Seite; zusaetzlich `nextStop == nil` und `isAfterLastStop == true`.
- `unsavedChangesStayOutOfSnapshot` haette gegen den Ist-Stand in allen drei Zweigen anders
  gelesen; `context.rollback()` zwischen den Zweigen haelt sie unabhaengig.

### Rot-Beweis

Kein Artefakt eines roten Laufs vorhanden (siehe N2). Dokumentiert ist er in den Commit-Messages,
mit Ist/Soll je Test:
- `d70e44c` (Fix 2, nur Test-Dateien, `--stat`: 3 Test-Dateien, +121/-17): „Lauf mit 45 Tests:
  39 gruen, 6 rot" — u. a. `maximumGap 90000.0 <= 86400.0`, `currentStop "Bergen" == "Tromsoe"`.
- `3735daf` (Fix 3): 4 Tests, 6 Issues, mit Werten (`afterDelete → [] == ["Nordland"]`,
  `spy.count → 2 == 1`). Der Commit enthaelt bewusst die **zwei Naehte** (`fetchCruises`,
  `save(_:generation:)`) — ohne sie kompiliert der Rot-Beweis nicht. Beide sind in dieser Fassung
  wirkungslos (`generation: 0`, Default-Fetch weiterhin auf `container.mainContext`), der
  Rot-Zustand also echt.

Nachgerechnet gegen den Vor-Zustand: alle sechs bzw. vier genannten Tests muessen dort rot sein.
Plausibel.

## Regressionen

**Keine gefunden.**

- **ZIEL-K1 „Eintrag am heutigen Kalendertag ist aktuell":** unveraendert. Der Kalendertag-Zweig
  `WidgetStateResolver.swift:170-176` ist byte-identisch zum Vor-Zustand; nur der Fenster-Zweig
  davor wurde angefasst.
- **`now == departure` ohne Nachfolger (letzter Stopp):** korrekt. Das Fenster trifft nicht mehr,
  der Kalendertag-Zweig uebernimmt (`todays.last(where: arrival <= now)`) und liefert denselben
  Stopp; `next == nil` ⇒ `isAfterLastStop == true` (`:109`). Die Regel steht als Fallkaskade im
  Doc-Kommentar `:150-152` und in `docs/features/widget.md` — aber ohne eigenen Test (→ N5).
- **Randfall Abfahrt exakt auf Mitternacht:** ab 00:00 gilt nicht mehr der alte Stopp, sondern der
  Eintrag des neuen Kalendertags. Das ist genau die K1-Tagesregel, also konsistent — kein
  Rueckschritt, aber erwaehnenswert.
- Keine weiteren Aufrufer betroffen: `WidgetSnapshotWriter.save` wird ausschliesslich vom
  Publisher (`:107`) und einem Test aufgerufen; der Writer gehoert exklusiv einer
  Publisher-Instanz (`:60`), Zaehler und `lastAccepted` laufen also im selben Bezugsrahmen.

## Lesekontext (Prueffrage 3)

Alles erfuellt: frischer `ModelContext(container)` je `publish` (`:128`), `autosaveEnabled = false`
(`:129`), Kontext ist eine lokale Variable in der **synchronen** `makeSnapshot` auf dem `@MainActor`
(`:26`, `:127`) — er wird nirgends gespeichert, ueberlebt den Aufruf nicht und erreicht den
`WidgetSnapshotWriter`-Aktor nie. Ueber die Aktorgrenze geht nur der `Sendable`-Wert
`WidgetSnapshot` (`:107`). `Cruise`-Instanzen verlassen den MainActor nicht (Abbildung `:140-148`).
Deckt sich mit der swiftdata-Regel „`ModelContext` ist nicht `Sendable` und darf keine Aktorgrenze
kreuzen".

**Kosten:** ein Kontext + ein ungecachter Fetch je Veroeffentlichung. Bei 1 s Debounce, hoechstens
drei ausgewaehlten Reisen und einem Fetch mit `isDemo == false`-Praedikat ist das vertretbar; der
Aufbau eines `ModelContext` oeffnet keinen Store neu.

## Generation (Pruefrage 4)

Monotoner `UInt64` je Publisher-Instanz, Fortschaltung mit `&+` (`:103`) — Overflow praktisch
ausgeschlossen und ohne Absturzrisiko. Der `lastAccepted`-Guard im Aktor (`WidgetSnapshotWriter.swift:33`)
macht die **Ankunftsreihenfolge** irrelevant: erreicht der aeltere Auftrag den Writer zuerst, wird er
geschrieben und danach vom neueren ueberschrieben; kommt er zuletzt an, wird er verworfen. In beiden
Faellen steht am Ende der juengste Snapshot auf der Platte und genau ein Reload feuert — belegt durch
`overlappingPublishesReloadOnce`. Der neueste Write geht nie verloren.

Eine Luecke bleibt (→ N3): der Zaehler zaehlt **Versuche**, das Reload-Gate setzt aber
**angenommene Writes** voraus.

## Findings

| ID | Severity | Blocker | Datei:Zeile | Kategorie | Titel |
|----|----------|---------|-------------|-----------|-------|
| N1 | major | nein | `docs/features/widget.md:98-106` | docs | Acceptance-Tabelle steht noch auf dem Fix-2-Stand |
| N2 | major | nein | `.winston-evidence/20260903T160134Z/gate-run.json`, `…161424Z/gate-run.json` | evidence | Gruener Lauf traegt den Commit des Rot-Beweises; kein Artefakt auf HEAD |
| N3 | minor | nein | `ShipTrip/Services/WidgetSnapshotPublisher.swift:103-113` | correctness | Abgebrochener juengerer Lauf unterdrueckt den Reload eines erfolgreichen aelteren |
| N4 | minor | nein | `ShipTrip/Services/WidgetSnapshotPublisher.swift:25` | docs | Typ-Kommentar behauptet noch `mainContext` |
| N5 | minor | nein | `ShipTripTests/WidgetStateResolverTests.swift` | tests | `now == departure` beim letzten Stopp ohne Test |
| N6 | minor | nein | `ShipTrip/WidgetShared/WidgetTimelinePlanner.swift:78-90` | performance | `filled` fuellt vor dem Deckel — Leerlauf bei fernem Kandidaten |

### N1 — Acceptance-Tabelle steht noch auf dem Fix-2-Stand
- **Datei**: `docs/features/widget.md:98-106`
- **Problem**: Die Doku beschreibt den neuen Stand fachlich vollstaendig — halboffenes Fenster
  (`:31-32`), separater Lesekontext + Fetch-Abbruch + Generationsnummer (`:63-68`), Horizont und
  Luecken von 24 h (`:77-78`). Nur der Beleg-Block hinkt Fix 3 hinterher: er zitiert „45/45" und
  `.winston-evidence/20260903T160134Z` (den **Fix-2**-Lauf) und fuehrt
  `WidgetSnapshotPublisherTests (9)`. Ist-Stand: 49/49, `.winston-evidence/20260903T161424Z`,
  und die Suite hat 13 `@Test` (Resolver 21 ✓, Planner 8 ✓, Store 7 ✓ stimmen).
- **Fix**: drei Zeilen — „45/45"→„49/49", Evidenzpfad auf `20260903T161424Z`, K3-Zeile auf
  `WidgetSnapshotPublisherTests (13)`. Sinnvollerweise zusammen mit dem T5c-Lauf (N2), dann steht
  gleich der finale Pfad drin.

### N2 — Gruener Lauf traegt den Commit des Rot-Beweises
- **Dateien**: `.winston-evidence/20260903T160134Z/gate-run.json`,
  `.winston-evidence/20260903T161424Z/gate-run.json`
- **Problem**: Beide Artefakte sind sauber (Kommandos aus dem Kanon, `test-without-building` auf
  einer eigenen Simulator-UDID, Exit 0/0, `status: verified`, Logs mit `Test run with 45/49 tests …
  passed`) — aber ihr `commit`-Feld nennt `d70e44c` bzw. `3735daf`, also genau die Commits, deren
  eigene Message den Lauf als **rot** ausweist. Die Zeitstempel loesen den Widerspruch auf: der
  Fix-2-Lauf endete 16:02:03Z, `eecefe8` wurde 16:03:16Z committet; der Fix-3-Lauf endete 16:14:52Z,
  `3d4d5a1` um 16:15:20Z. Gelaufen wurde also jeweils mit dem Fix im nicht committeten Arbeitsbaum.
  Folge: **kein gruenes Artefakt ist auf HEAD `3d4d5a1` gestempelt**, und die Zuordnung
  Artefakt→Commit ist irrefuehrend, falls jemand spaeter nur die JSON liest.
- **Kein Blocker**, weil der Lauf sachlich stattgefunden hat und der Baum plausibel dem HEAD
  entspricht — aber nicht beweisbar.
- **Fix**: im T5c-Release-Gate die vier Widget-Suiten einmal auf sauberem HEAD fahren und die
  Evidenz mit dem tatsaechlichen Commit stempeln; `docs/features/widget.md` dann auf diesen Pfad
  ziehen (deckt N1 gleich mit ab). Fuer die Zukunft: `evidence.py` erst nach dem Fix-Commit
  aufrufen, nicht davor.

### N3 — Abgebrochener juengerer Lauf unterdrueckt den Reload eines erfolgreichen aelteren
- **Datei**: `ShipTrip/Services/WidgetSnapshotPublisher.swift:103-113`
- **Problem**: `generation` wird bei **jedem** `write()` hochgezaehlt (`:103`), auch wenn der Lauf
  danach am Fetch-Fehler (`:105`) oder am Schreibfehler (`:110`) abbricht. Der aeltere, bereits
  erfolgreich geschriebene Lauf faellt dann am Gate `guard mine == generation` (`:113`) durch und
  reloadet nicht — der neuere reloadet aber auch nicht, weil er abgebrochen ist. Ergebnis: ein
  frischer Snapshot liegt auf der Platte, das Widget zeigt bis zum naechsten Trigger den alten
  Stand. Braucht zwei ueberlappende Laeufe **und** einen Fehler, ist also selten; der
  Last-known-good bleibt korrekt, es geht nur ein Reload verloren.
- **Fix**: `WidgetSnapshotWriter.save` die Annahme zurueckmelden lassen
  (`@discardableResult func save(…) throws -> Bool`) und im Publisher auf `accepted` statt auf
  `mine == generation` reloaden; alternativ `generation` beim Abbruch wieder zuruecknehmen.

### N4 — Typ-Kommentar behauptet noch `mainContext`
- **Datei**: `ShipTrip/Services/WidgetSnapshotPublisher.swift:25`
- **Problem**: `/// Schreibt den Widget-Snapshot koalesziert aus dem `mainContext`.` — genau das
  tut die Klasse seit `3d4d5a1` nicht mehr. Der ausfuehrliche Kommentar an `makeSnapshot`
  (`:117-126`) sagt es richtig; die Kurzfassung oben widerspricht ihm.
- **Fix**: „… aus einem eigenen Lesekontext auf dem persistierten Stand."

### N5 — `now == departure` beim letzten Stopp ohne Test
- **Datei**: `ShipTripTests/WidgetStateResolverTests.swift` (Ergaenzung neben `afterLastStop`)
- **Problem**: Das halboffene Fenster laesst diesen Fall bewusst durchfallen; dass der
  Kalendertag-Zweig ihn korrekt auffaengt, ist nirgends festgenagelt. Ein spaeterer Eingriff in den
  Tagesbereich koennte ihn still kaputtmachen.
- **Fix**: ein Test auf der `standardCruise()`-Route zum Abfahrtszeitpunkt des letzten Stopps mit
  `currentStop?.name == <letzter Stopp>`, `nextStop == nil`, `isAfterLastStop == true`.

### N6 — `filled` fuellt vor dem Deckel
- **Datei**: `ShipTrip/WidgetShared/WidgetTimelinePlanner.swift:78-90`, Aufruf `:64`
- **Problem**: `filled(dates…)` laeuft vor `prefix(maxEntries)`. Liegt ein ferner Kandidat in der
  Liste — bei `.countdown` ist das `info.startDate`, potenziell Jahre voraus — erzeugt die innere
  `while`-Schleife einen Eintrag pro Tag bis dorthin, die alle unmittelbar danach weggeschnitten
  werden. Terminiert sicher (`dayLater` schreitet immer 24 h fort) und kostet nur Rechenzeit; der
  Horizont selbst bleibt korrekt, weil die zwoelf Tagesmitternachte (`:52`) ihn immer decken.
- **Fix**: die Auffuellung auf `maxEntries` Ergebniseintraege klemmen (`while result.count <
  maxEntries && …`) oder vor dem Fuellen deckeln.

## Backlog-Kandidaten (nicht in den Fix-Lauf)

```
- [major] docs/features/widget.md:98-106 — Acceptance-Tabelle auf 49/49 und Evidenz 20260903T161424Z ziehen, K3 auf 13 Tests
- [major] .winston-evidence/*/gate-run.json — gruene Widget-Evidenz auf HEAD stempeln (mit T5c erledigen)
- [minor] ShipTrip/Services/WidgetSnapshotPublisher.swift:103-113 — Reload-Gate an angenommene Writes statt an Versuchszaehler haengen
- [minor] ShipTrip/Services/WidgetSnapshotPublisher.swift:25 — Typ-Kommentar nennt noch den mainContext
- [minor] ShipTripTests/WidgetStateResolverTests.swift — Test fuer now == departure beim letzten Stopp
- [minor] ShipTrip/WidgetShared/WidgetTimelinePlanner.swift:78-90 — Auffuellung vor dem Deckel klemmen
```

## Verdikt

**GO mit Backlog.** Keine offenen Blocker: alle neun gelisteten Codex-Findings sind erledigt und
testbelegt, keine Regression an K1 oder am Kern-Flow, `guard.py sizes` gruen. N1 und N2 sind
Release-Hygiene und im T5c-Gate in einem Aufwasch zu erledigen.
