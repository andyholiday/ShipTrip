# Review — Widget 1.9.0, Welle 1 (T0 + T1 + T2)

- **Iteration**: 1 / 3
- **Reviewer**: quality-agent (frischer Spawn)
- **Datum**: 2026-09-03
- **Scope**: `git diff 6547753..b8f4055` im Worktree
  `/Users/andre-studio/Documents/0.Projekte/ShipTrip-worktrees/widget-1.9.0`
  (Branch `feature/widget-1.9.0`, HEAD b8f4055)
- **Geladene Skills**: `code-review`, `swift-standards`, `xctest-ios`
- **Verdict**: **NO-GO** (request-changes)
- **Stats**: critical 1, major 2, minor 4 — Blocker 2, Backlog 5

## Summary

Der Kern ist handwerklich stark: `WidgetShared/` haelt die Regel aus LE 1
lueckenlos ein (nur Foundation, alles `Sendable`, kein Force-Unwrap, kein
`try!`, `Calendar`/`Date` immer injiziert), der Store ist gegen jede
getestete Fehlform robust, der pbxproj-Eingriff ist rein additiv und laesst
die App-Target-Settings unangetastet. Die Zustandsableitung trifft in 9 von
10 eigenen Reproduktionen exakt den Wortlaut der Anfrage.

Der Blocker liegt nicht im Resolver, sondern im **Planner**: die
Horizont-Auffuellung wird durch einen weit in der Zukunft liegenden
Kandidaten (Reiseende bzw. Reisestart) ausgehebelt. Ergebnis: die Timeline
enthaelt eine mehrwoechige Luecke, in der das Widget einen veralteten
Hafen/Seetag bzw. einen eingefrorenen Countdown zeigt — genau das, was
ZIEL K4 („ohne Nachhilfe aktuell") verhindern soll. Der vorhandene
Planner-Test deckt das nicht ab, weil er nur Deckel, Sortierung und
`last >= now + 24 h` prueft, nicht die Luecken dazwischen.

## Test-Lauf (ein Gate-Lauf, Wegwerf-Sim `ci-q-w1`, iPhone 17 / iOS 26.5)

- `evidence_path`:
  `/Users/andre-studio/Documents/0.Projekte/ShipTrip-worktrees/widget-1.9.0/.winston-evidence/20260903T151626Z/gate-run.json`
- `build` (`xcodebuild build-for-testing -scheme ShipTrip`): **exit 0** —
  beide Targets bauen, `SWIFT_STRICT_CONCURRENCY = complete`, Swift 6.0.
  Der Build blieb auch mit den parallel entstandenen, fremden T3-Dateien
  (`Services/WidgetSnapshotPublisher.swift`, `WidgetSnapshotWriter.swift`)
  gruen.
- `tests`: **exit 65**, 38 total / 36 passed / 2 failed / 0 skipped.
  **Die 27 Produktivtests (Store 6, Resolver 17, Planner 4) sind
  vollstaendig gruen.** Beide Fehlschlaege stammen aus meiner temporaeren
  Probe-Suite `QualityW1ProbeTests` (10 Faelle) und *sind* die Findings F01
  und F02. Die Probe-Datei ist nach dem Lauf geloescht, nichts committet.
- Statischer Pass `guard.py sizes` ueber alle 11 neuen Dateien:
  `ok (11 geprueft, 0 Soft-Warnungen)`.

### Eigene Reproduktionen — Erwartung vs. Ist

| # | Fall | Erwartung | Ist |
|---|------|-----------|-----|
| P1 | Seetag heute, Hafen morgen | current = Seetag (`isSeaDay`), next = Bergen | wie erwartet |
| P2 | `now` exakt auf `departure` | Fenster inklusiv, current bleibt der Hafen | wie erwartet |
| P3 | Route nur aus Seetagen | current/next = die passenden Seetage | wie erwartet |
| P4 | A endet heute 00:00, B startet morgen | A bleibt aktiv (ZIEL K1: bis Ende des `endDate`-Tages), kein Countdown | wie erwartet |
| P5 | Aktive Reise ohne Route | `.active`, current/next `nil`, `isAfterLastStop == false` | wie erwartet |
| P6a | Hafen ueber Nacht, `now` 02:00 im Fenster | current = Nachthafen | wie erwartet |
| P6b | Hafen ueber Nacht, `now` 09:00 nach Abfahrt | current = Nachthafen (juengster vergangener), next = Tromsoe | wie erwartet |
| P9 | `now` = 23:59 | `now` zuerst, dedupliziert, aufsteigend, `>= now + 24 h`, `<= 12` | wie erwartet |
| P10 | Verzeichnis statt Datei · leere Datei | beides `.unreadable`, kein Crash | wie erwartet |
| **P7** | 2 Stopps am selben Tag, `now` nach beiden | current = „Spaet", next = `nil` | **current = „Frueh", next = „Spaet" (bereits um 20:00 abgefahren)** → F02 |
| **P8** | Countdown 30 Tage voraus | taegliche Eintraege bis zum Deckel | **nur 3 Eintraege: `[now, morgen 00:00, +30 d]`** → F01 |

## Findings

| ID  | Severity | Blocker | File:Line | Kategorie | Titel |
|-----|----------|---------|-----------|-----------|-------|
| F01 | critical | **ja** | `ShipTrip/WidgetShared/WidgetTimelinePlanner.swift:47-54` | correctness | Ferner Kandidat haebelt die Horizont-Auffuellung aus — Timeline friert tagelang ein |
| F02 | major | nein | `ShipTrip/WidgetShared/WidgetStateResolver.swift:165` | correctness | Zwei Stopps am selben Kalendertag: vergangener Stopp erscheint als „naechster" |
| F03 | major | **ja** | `ShipTripTests/WidgetTimelinePlannerTests.swift:60-75` | tests | Maximalbestand-Test prueft Deckel und 24-h-Grenze, aber nicht die Luecken |
| F04 | minor | nein | `ShipTripWidget/ShipTripWidget.swift:43` | correctness | Provider-Stub mit `policy: .never` und einem einzigen Eintrag |
| F05 | minor | nein | `ShipTripWidget/ShipTripWidget.swift:98-99` | i18n | Gallery-Texte hart deutsch, `Localizable.xcstrings` leer |
| F06 | minor | nein | `ShipTrip.xcodeproj/project.pbxproj` (`BF1F290E…`, membershipExceptions) | build | Neue `WidgetShared`-Dateien werden **nicht** automatisch Widget-Target-Mitglied |
| F07 | minor | nein | `ShipTrip/WidgetShared/WidgetTimelinePlanner.swift:52-53` | docs | Kommentar begruendet die Deckel-Sicherheit falsch und hat F01 maskiert |

---

### F01 — Ferner Kandidat haebelt die Horizont-Auffuellung aus (critical, Blocker)

- **File**: `ShipTrip/WidgetShared/WidgetTimelinePlanner.swift:47-54`
- **Kategorie**: correctness / ZIEL K4
- **Problem**: Die Auffuell-Schleife bricht ab, sobald `dates.last >= horizon`.
  `dates.last` ist aber der **groesste** Kandidat — und das ist bei `.active`
  immer `nextMidnight(after: cruiseEnd)` und bei `.countdown` immer
  `info.startDate`. Beide liegen typischerweise Wochen entfernt. Die
  Bedingung ist damit sofort erfuellt und es wird **keine einzige**
  Mitternacht ergaenzt. Die Timeline erfuellt zwar den Buchstaben von K4
  (`<= 12` Eintraege, letzter Eintrag `>= now + 24 h`), verletzt aber dessen
  Zweck („sodass das Widget auch ohne App-Oeffnen von ‚Hafen A' auf ‚Seetag'
  … springt").

  **Reproduziert (Probe P8, Countdown):** `now = 03.06. 10:00`,
  `startDate = 03.07. 17:00` → `entryDates` liefert genau
  `[now, 04.06. 00:00, 03.07. 17:00]`. Ab dem 4. Juni 00:00 zeigt das Widget
  **29 Tage lang unveraendert „In 29 Tagen"**, obwohl der Countdown taeglich
  fallen muesste (ZIEL K1: Wortlaut von `cruiseStartDescription`).

  **Analytisch identisch im `.active`-Zweig** — derselbe Guard, hier mit der
  Fixture des vorhandenen Tests `maximumStockStaysWithinLimits`
  (`WidgetTimelinePlannerTests.swift:39-53`, 40 Tagesstopps,
  `now = 11.06. 10:00`): Kandidaten `> now` sind `11.06. 18:00`,
  `12.06. 00:00`, `12.06. 08:00`, `12.06. 18:00` und `11.07. 00:00`
  (Reiseende-Mitternacht). Ergebnis: 6 Eintraege, letzter `11.07.`, keine
  Auffuellung. **Zwischen dem 12.06. 18:00 und dem 11.07. gibt es keinen
  Eintrag** — das Widget zeigt fast vier Wochen lang Hafen 11 als aktuellen
  und Hafen 12 als naechsten Stopp, waehrend das Schiff 28 weitere Haefen
  anlaeuft. Das ist „falscher Hafen/Seetag" im Sinne der Go-Live-Triage.
- **Fix**: Die Tagesmitternachte als *Kandidaten* einspeisen, statt sie
  hinterher an die Liste zu haengen — dann greifen Sortierung, Deduplikation
  und Deckel gemeinsam und liefern ~11 Tage lueckenlose Tagesaktualitaet:

  ```swift
  static func entryDates(for state: WidgetState, now: Date, calendar: Calendar) -> [Date] {
      switch state {
      case .idle, .unavailable:
          return [now, nextMidnight(after: now, calendar: calendar)]
      case .active, .countdown:
          break
      }

      let midnights = dailyMidnights(after: now, count: maxEntries, calendar: calendar)
      let upcoming = (candidates(for: state, now: now, calendar: calendar) + midnights)
          .filter { $0 > now }
          .sorted()

      var dates = [now]
      for candidate in upcoming where dates.last != candidate {
          dates.append(candidate)
      }
      return Array(dates.prefix(maxEntries))
  }

  /// Die naechsten `count` lokalen Mitternachte nach `date`.
  private static func dailyMidnights(after date: Date, count: Int, calendar: Calendar) -> [Date] {
      var result: [Date] = []
      var cursor = date
      for _ in 0..<count {
          cursor = nextMidnight(after: cursor, calendar: calendar)
          result.append(cursor)
      }
      return result
  }
  ```

  Weil `prefix` nach der Sortierung greift, ueberleben die nahen
  Ankunfts-/Abfahrtszeiten den Deckel; nur die fernen Mitternachte fallen
  weg. `.after(letzter Eintrag)` laedt danach turnusmaessig nach.

### F02 — Vergangener Stopp erscheint als „naechster" (major, kein Blocker)

- **File**: `ShipTrip/WidgetShared/WidgetStateResolver.swift:165`
- **Kategorie**: correctness / ZIEL K1
- **Problem**: `stops.firstIndex(where: { $0.day == today })` nimmt bei
  mehreren datierten Eintraegen am selben Kalendertag immer den **ersten**.
  **Reproduziert (Probe P7):** Stopps „Frueh" (03.06. 06:00–09:00) und
  „Spaet" (03.06. 14:00–20:00), `now = 03.06. 22:00`. Ist: current =
  „Frueh", **next = „Spaet", obwohl dieser Hafen seit zwei Stunden verlassen
  ist**. Erwartet: current = „Spaet", next = `nil` (bzw. der Folgetag).
  Bei einem Stopp pro Tag — dem Normalfall — ist das Verhalten korrekt,
  deshalb kein Blocker; Tenderhafen + Abendhafen an einem Tag ist im
  Datenmodell aber moeglich.
- **Fix**: Unter den Eintraegen des heutigen Tages den letzten waehlen,
  dessen Ankunft schon vorbei ist; nur wenn keiner begonnen hat, den ersten:

  ```swift
  let todays = stops.indices.filter { stops[$0].day == today }
  if let started = todays.last(where: { (stops[$0].arrival ?? today) <= now }) { return started }
  if let first = todays.first { return first }
  return stops.lastIndex { $0.day < today }
  ```

### F03 — Planner-Test prueft die Kernregel nicht (major, Blocker mit F01)

- **File**: `ShipTripTests/WidgetTimelinePlannerTests.swift:60-75`
- **Kategorie**: tests
- **Problem**: `maximumStockStaysWithinLimits` prueft `first == now`,
  `count <= 12`, strenge Monotonie und `last >= now + 24 h`. Genau diese vier
  Zusagen haelt der fehlerhafte Planner ein — die Regel, um die es geht (das
  Widget bleibt *durchgehend* aktuell), ist ungeprueft. Der Test war gruen,
  waehrend F01 vorlag; das ist ein Test, der den Buchstaben statt die Regel
  prueft.
- **Fix**: Zusammen mit dem F01-Fix eine Luecken-Zusicherung ergaenzen, je
  einmal fuer `.active` und `.countdown`:

  ```swift
  @Test("Zwischen zwei Eintraegen liegt hoechstens ein Kalendertag")
  func noMultiDayGaps() {
      let now = plusDays(10, from: at(6, 1, 10))
      let dates = WidgetTimelinePlanner.entryDates(
          for: maximalActiveState(now: now), now: now, calendar: berlin)
      let gaps = zip(dates, dates.dropFirst()).map { $1.timeIntervalSince($0) }
      #expect(gaps.allSatisfy { $0 <= 25 * 3600 })   // 25 h deckt den DST-Tag ab
      #expect(dates.count == WidgetTimelinePlanner.maxEntries)
  }
  ```

## Beantwortung der injizierten Pruefungen

2. **Zeitzone/DST — sauber.** Kein `Calendar.current`, kein `Date()`, kein
   `TimeZone.current`, kein `autoupdatingCurrent` in `ShipTrip/WidgetShared/`
   (verifiziert per Grep). Alle Tagesrechnungen laufen ueber den injizierten
   `Calendar` (`startOfDay`, `date(byAdding:)`, `dateComponents([.day])`);
   Fallbacks bei `nil` sind vorhanden statt Force-Unwraps
   (`WidgetStateResolver.swift:128/190/197`). Die DST-Tests sind echt und
   aussagekraeftig: `Europe/Berlin`, 29.03.2026 (23 h) und 25.10.2026 (25 h),
   feste `DateComponents` statt Zeitstempel-Arithmetik. `Date()` erscheint
   nur im Widget-Target (`ShipTripWidget.swift:32/53`) — dort korrekt, das
   Widget ist der Aufrufer, der „jetzt" liefert.
3. **Planner K4** — `<= 12` ✔, `now` zuerst ✔, alle Kandidaten `> now` ✔,
   dedupliziert ✔ (Sortierung + Nachbarvergleich genuegt), `now` kurz vor
   Mitternacht ✔ (Probe P9). **`>= 24 h` nur formal** — siehe F01.
4. **Store** — `.unreadable` bei allen drei Varianten (kaputtes JSON,
   falsche Struktur, fremde `schemaVersion`) ✔; zusaetzlich von mir belegt:
   leere Datei und Verzeichnis-statt-Datei ergeben `.unreadable` ohne Crash
   (Probe P10). `.atomic` ist real gesetzt (`WidgetSnapshotStore.swift:94`)
   und der Last-known-good-Test erzwingt das Scheitern ueber
   `posixPermissions 0o500` — ein echter Beweis, keine Attrappe.
   Encoder/Decoder sind symmetrisch (`.iso8601` beidseitig); die
   Equatable-Falle ist erkannt und entschaerft: `widgetTestDate` erzeugt
   ausschliesslich volle Sekunden (`WidgetSnapshotStoreTests.swift:25-35`),
   und die Einschraenkung ist im Schema dokumentiert
   (`WidgetSnapshot.swift:23-27`). Groessenbudget am Maximalbestand
   (3 × 40 Stopps) < 64 KB ✔.
5. **Swift 6 / Sendable — sauber.** `WidgetShared` importiert ausschliesslich
   `Foundation`; kein SwiftUI, kein SwiftData, kein WidgetKit, kein
   `String(localized:)`. Alle Typen sind `Sendable`, keine Force-Unwraps,
   kein `try!`, kein `as!`. `JSONEncoder`/`JSONDecoder` werden bewusst pro
   Aufruf erzeugt und der Grund ist am Code notiert
   (`WidgetSnapshotStore.swift:99-101`) — richtig unter
   `SWIFT_STRICT_CONCURRENCY = complete`, das in beiden Targets gesetzt ist.
6. **pbxproj (T2) — additiv, keine Regression.** Der Diff enthaelt genau
   eine `-`-Zeile (den Datei-Header); es wurde nichts entfernt oder
   umgeschrieben. Die `XCBuildConfiguration`-Bloecke des App-Targets sind
   unveraendert. Widget-Target: `IPHONEOS_DEPLOYMENT_TARGET = 18.5` ✔,
   `DEVELOPMENT_TEAM = LH324Y9MG7` ✔, `PRODUCT_BUNDLE_IDENTIFIER =
   com.andre.ShipTrip.Widget` ✔, `SWIFT_VERSION = 6.0` ✔,
   `SKIP_INSTALL = YES` ✔, `CODE_SIGN_STYLE = Automatic` ✔,
   `TARGETED_DEVICE_FAMILY = 1` — identisch zur App ✔.
   **Versionen identisch zur App**: `MARKETING_VERSION 1.8.7` /
   `CURRENT_PROJECT_VERSION 28` in beiden Targets (LE 8 hebt beide in T5
   auf 1.9.0 / 29) ✔. Embed-Phase korrekt (`PBXCopyFilesBuildPhase`,
   `dstSubfolderSpec = 13`, `RemoveHeadersOnCopy`) plus
   `PBXTargetDependency` App → Widget ✔. `Info.plist` traegt
   `NSExtensionPointIdentifier = com.apple.widgetkit-extension` und ist ueber
   `membershipExceptions` korrekt aus der Resources-Phase ausgenommen ✔.
   Entitlements: beide Targets fuehren
   `com.apple.security.application-groups = [group.com.andre.ShipTrip]`; die
   App-Entitlements sind sonst unveraendert (nur 4 additive Zeilen) ✔.
7. **Bestandsschutz — eingehalten.** `git diff --stat 6547753..b8f4055 --
   ShipTrip/ ShipTripTests/` zeigt ausschliesslich neue Dateien plus die
   4 additiven Zeilen in `ShipTrip.entitlements`. Keine bestehende
   Swift-Datei angefasst. `guard.py sizes`: exit 0, 0 Soft-Warnungen.
8. **Testqualitaet — ueberwiegend regelpruefend.** Die Tests arbeiten mit
   festen `DateComponents`, injiziertem Kalender und beobachtbarem Ergebnis;
   sie greifen nie in Internas und benutzen keine Test-Hintertueren. Der
   Last-known-good-Test und der 64-KB-Budget-Test sind echte Beweise. Ein
   Ausreisser: F03. Deckel eingehalten — Code-Diff (WidgetShared 682 Zeilen +
   Widget-Target 120) > Test-Diff (550 Zeilen).

## Backlog-Kandidaten (kein Fix-Auftrag in diesem Lauf)

- [major] ShipTrip/WidgetShared/WidgetStateResolver.swift:165 — Zwei Stopps am selben Kalendertag: vergangener Stopp erscheint als „naechster" (F02)
- [minor] ShipTripWidget/ShipTripWidget.swift:43 — Provider-Stub liefert `policy: .never` und nur einen Eintrag; T4 muss auf `.after(letzter Eintrag)` + `WidgetTimelinePlanner.entryDates` umstellen, sonst aktualisiert das Widget nie (F04)
- [minor] ShipTripWidget/ShipTripWidget.swift:98-99 — `configurationDisplayName`/`description` hart deutsch via `Text(verbatim:)`, `Localizable.xcstrings` leer; ZIEL K5 verlangt DE/EN vor Release (F05)
- [minor] ShipTrip.xcodeproj/project.pbxproj (`BF1F290E…`) — LE 1 behauptet, spaeter ergaenzte `WidgetShared`-Dateien wuerden automatisch Widget-Target-Mitglied; tatsaechlich mussten sie in b8f4055 von Hand in `membershipExceptions` nachgetragen werden. T3/T4 muessen jede neue `WidgetShared`-Datei dort eintragen (bricht sonst den Widget-Build — immerhin selbstentdeckend) (F06)
- [minor] ShipTrip/WidgetShared/WidgetTimelinePlanner.swift:52-53 — Kommentar begruendet die Deckel-Sicherheit mit „hoechstens sechs Kandidaten" und verdeckt damit, dass die Auffuellung gar nicht laeuft; mit dem F01-Fix richtigstellen (F07)

## Verdict

**NO-GO.** Zwei offene Blocker (F01, F03). T3 und T4 duerfen auf T0/T2
aufsetzen — Contract, Store, Entitlements und Target-Geruest sind tragfaehig
—, aber **nicht** auf `WidgetTimelinePlanner` in dieser Form: T4 baut den
Provider direkt auf `entryDates`, ein spaeterer Fix wuerde die
Provider-Tests mitreissen. Der Fix ist klein (eine Hilfsfunktion, ein
umgestellter Aufruf, ein Test) und gehoert vor die T4-Abnahme.

**Die drei wichtigsten Fixes fuer den naechsten Developer-Spawn:**
1. F01 — `WidgetTimelinePlanner.entryDates`: Tagesmitternachte als
   Kandidaten einspeisen statt nachtraeglich anhaengen.
2. F03 — Luecken-Test fuer `.active` **und** `.countdown` ergaenzen
   (max. 25 h zwischen zwei Eintraegen, `count == maxEntries`).
3. F02 — `currentIndex`: unter den Eintraegen des heutigen Tages den letzten
   bereits begonnenen waehlen (nur falls Winston es aus dem Backlog zieht).
