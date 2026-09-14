# Review — T8a: Klapp-/Zuordnungslogik des Route-Journal-Fadens (J3neu)

- **Iteration**: 1 / 3
- **Reviewer**: quality-agent (T9a-Gate)
- **Datum**: 2026-08-27
- **Diff**: `git diff 65c5f32..d438233` — 9 neue Dateien, 1104 Zeilen, keine Bestandsdatei beruehrt
- **Verdict**: approve (GO-mit-Backlog)
- **Stats**: critical: 0, major: 0, minor: 6 — Blocker: 0, ins Backlog: 6
- **Geladene Skills**: code-review, swift-standards, xctest-ios
- **evidence_path**: `/Users/andre-studio/Documents/0.Projekte/ShipTrip-worktrees/merge/.winston-evidence/20260827T124646Z/gate-run.json`

## Summary

Vier reine Wert-Typen (`RouteDayKey`, `RouteJournalInputs`, `RouteJournalPlanner`,
`RouteCollapsePlanner`, `JournalExcerpt`) setzen J3neu (a)/(b)/(c) regelgetreu um,
ohne SwiftUI- oder SwiftData-Abhaengigkeit. Der Zeitzonen-Vertrag aus ADR-003 wird
konsequent ueber `JournalDay` gefuehrt — kein `Date ==`, kein lokales `startOfDay`,
Tag-Tripel immer gregorianisch. 47/47 Tests gruen (eigener Lauf, Wegwerf-Simulator,
Zahlen aus xcresult). Keine Bloecke: alle sechs Befunde sind Nachschaerfungen an
Tests bzw. Auflagen fuer T8b.

**Trigger-Pruefungen:** GDPR **nicht ausgeloest** (reine Anzeige-Logik, keine neue
Persistenz, kein Logging, kein Netz, keine Datenverarbeitung beruehrt).
Security **nicht ausgeloest** (keine I/O, kein Parsing untrusted Input, keine
Angriffsflaeche). Kein Befund stuetzt sich auf eine Annahme ueber eine Library-API,
daher keine context7-Verifikation noetig — `String.count(where:)` (Swift 6) ist
durch den gruenen Build belegt, nicht durch Trainingswissen.

## J3neu-Abgleich, Regel fuer Regel

| Regel (J3neu) | Umgesetzt | Getestet | Befund |
|---|---|---|---|
| (a) 1 — Hafen-Vorrang vor Datum | ja, `RouteJournalPlanner.swift:75-76` | ja, `RouteJournalPlannerTests.swift:18-32` (umdatierter Eintrag) | — |
| (a) 2 — hafenlos → erster Stopp des Tages (`sortOrder`) | ja, `RouteJournalPlanner.swift:64-68,78` | ja, `:34-46`, `:48-62` (verkehrte Uebergabereihenfolge) | — |
| (a) 2 — Seetage sind normale Traeger | ja (Seetag = `RouteStopInput`, kein Sonderpfad) | ja, `:79-92` | — |
| (a) 3 — Tag mit mehreren Stopps | ja (folgt aus 1+2) | ja, `:48-62` + `:64-77` | — |
| (a) 4 — Tag ohne Stopp → Sammelblock, keine synthetischen Zeilen | ja, `RouteJournalPlanner.swift:81-85` | ja, `:94-105`, `:107-118`, `:120-130` | — |
| (a) 4 — verwaiste/genullte `port`-Kante + kein Traeger am Tag | ja (gleicher Pfad) | **nein** | F02 |
| (a) — Sortierung `entryDate` ↑, dann `createdAt` ↑ | ja, `RouteJournalPlanner.swift:99-105` (+ `id`-Tiebreak) | ja, `:164-184`, `:186-198` | F03 (Tiebreak schwach geprueft) |
| (a) — keine Modell-Aenderung | ja (Wert-Eingaben statt `@Model`) | n/a | — |
| (b) — Defaults vor Start / nach Ende: alles auf | ja, `RouteCollapsePlanner.swift:70-71` | ja, `RouteCollapsePlannerTests.swift:106-118` | — |
| (b) — Aktiv: nur Stopps des heutigen Tages auf | ja, `:72-78` | ja, `:120-146` (inkl. zwei Stopps am selben Tag) | — |
| (b) — Fallback: Aktiv-Tag ohne Stopp → alles zu | ja, `:77-78` | ja, `:148-169` (+ leere Route `:171-183`) | — |
| (b) — Phasengrenzen inklusiv (Start-/Endtag aktiv) | ja, `:31-33` | ja, `:54-74`, `:87-96` (Uhrzeit irrelevant) | — |
| (b) — effektiv = Uebersteuerung ?? Automatik | ja, `:102-104` | ja, `:202-209` | — |
| (b) — Tippen negiert den **effektiven** Zustand | ja, `:108-110` | ja, `:211-254` (beide Richtungen, Scope, doppeltes Tippen) | — |
| (b) — „Alle auf/zuklappen" jederzeit | ja, `:113-120` | ja, `:256-278` (auch gegen aktive Phase) | — |
| (b) — 0:00-Wechsel loescht **alle** Uebersteuerungen | ja, `:126-128` | ja, `:280-294` + Defaults-Neuberechnung `:185-192` | — |
| (b) — Persistenz: keine (In-Memory) | ja (`private var overrides`, kein Schema-Eingriff) | ja, `:296-303` | — |
| (b) — Sammelblock ausgenommen von der Maschine | ja (taucht nie als Stopp-ID auf) | implizit | — |
| (c) — „Weiterlesen" > 160 Zeichen **oder** > 3 Umbrueche | ja, `JournalExcerpt.swift:34-37` | ja, `JournalExcerptTests.swift` (160/161, 3/4, CRLF, Emoji, Schwellen) | — |
| (c) — Datum nur bei Abweichung vom `arrival`-Tag / im Sammelblock | **offen (T8b)** | nein | F04 |
| (c)/(d)/(e), Lokalisierung, Accessibility | ausserhalb T8a (T8b) | n/a | F04, F05 als Auflage |

## Bewertung der Dev-Entscheidung (verwaiste `portID` → Datumsregel)

**Traegt.** Begruendung:

1. **Contract-konform.** J3neu (a) Regel 4 nennt den Fall selbst („`port` wurde
   geloescht/genullt und kein Stopp traegt den Tag → Sammelblock") und routet die
   verlorene Hafen-Kante damit genau ueber Datumsregel → Sammelblock. Die
   Implementierung spiegelt das.
2. **Kein Datenverlust, kein unsichtbarer Eintrag.** `assign` ist total: jeder
   Eintrag landet an einem Stopp **oder** im Sammelblock. Die Alternativen waeren
   entweder Verschlucken (Datenverlust in der Anzeige) oder eine synthetische
   Tages-Zeile — letzteres verbietet Regel 4 ausdruecklich.
3. **Defensiv, nicht spekulativ.** Im Live-Store unerreichbar (SwiftData `.nullify`
   auf `Port`-Loeschung, J1), Kosten: drei Zeilen plus Doc-Kommentar. Kein Verstoss
   gegen „Simplicity First".
4. **Restrisiko** liegt nur bei T8b (F05): die Rueckfall-Logik ist genau dann
   harmlos, wenn die View die **vollstaendige** `cruise.route` uebergibt.

## Bewertung Test-Diff (721) > Code-Diff (383)

Verhaeltnis ist **verdient**, kein Befund. Die Testmasse geht in Randfaelle, nicht
in Fuellstoff: 4 Zuordnungsregeln × (Mehrfach-Stopp / Seetag / leere Route /
kein Traeger), 3 Phasen × inklusive Grenztage, Schwellwerte exakt an 160/161 und
3/4 Umbruechen, Grapheme-Cluster (CRLF, Familien-Emoji), Extremzeitzonen und
nicht-gregorianischer Geraete-Kalender. Alle Assertions pruefen beobachtbare
Rueckgabewerte der oeffentlichen API — keine Internals, keine Mocks, keine
Snapshot-Attrappen. Genau ein Test ohne Aussagekraft (F01).

## Statischer Pass

- `guard.py sizes --files <9 geaenderte Dateien>`: **ok**, 0 Soft-Warnungen, Exit 0.
  Groesste Logik-Datei 133 Zeilen (Limit 500).
- swift-standards: Naming, `// MARK:`-Gliederung, deutsche Doc-Kommentare
  projektkonform; keine Force-Unwraps; `?? 0`-Totalfallbacks in `RouteDayKey.swift:47-51`
  mit Begruendung + Projekt-Praezedenz dokumentiert; `Sendable`/`Hashable`/`Equatable`
  bewusst gesetzt; keine SwiftUI-Kopplung in der Logik.

## Test-Run (eigener Lauf, Wegwerf-Simulator)

- Simulator: `ci-t9a-review` (iPhone 17, iOS 26.5), eigens erzeugt, Default-Set,
  Kalender-Privacy gewaehrt, nach dem Lauf geloescht.
- Kommandos aus `gates.yaml`-Muster, kein Weichspueler: `xcodebuild build-for-testing`
  (Exit 0) + `xcodebuild test-without-building -xctestrun …` (Exit 0).
- Umfang change-scoped: die 7 neuen Suiten via `-only-testing:` (Volllauf bleibt T11a).
- **Zahlen aus xcresult**: totalTestCount 47, passed 47, failed 0, skipped 0,
  expectedFailures 0, result Passed. Filter haben nachweislich gegriffen
  (47 = Handzaehlung der neuen Suiten, nicht die Gesamtsuite).
- Evidenz pinnt `commit: d438233` — den geprueften Stand.

### Developer-Evidenz gegengeprueft

`…/ShipTrip-worktrees/t8a-klapp-logik/.winston-evidence/20260827T123855Z/gate-run.json`
existiert, ist valide, beide Gates Exit 0, Kommandos korrekt (kein
`xcodebuild test -scheme`), Log belegt „47 tests in 7 suites passed". **Aber**:
`commit`-Feld = `65c5f32` (Basis), nicht `c30b494` → F06.

## Findings

| ID  | Severity | Blocker | File:Line | Kategorie | Titel |
|-----|----------|---------|-----------|-----------|-------|
| F01 | minor | nein | ShipTripTests/RouteJournalPlannerTests.swift:247-266 | tests | Westliche Zeitzonen-Gegenprobe ohne Unterscheidungskraft |
| F02 | minor | nein | ShipTripTests/RouteJournalPlannerTests.swift:132-142 | tests | Zweiter Zweig des Verwaist-Fallbacks (kein Traeger am Tag) ungetestet |
| F03 | minor | nein | ShipTripTests/RouteJournalPlannerTests.swift:200-214 | tests | id-Tiebreak nur auf Stabilitaet, nicht auf Richtung geprueft |
| F04 | minor | nein | ShipTrip/Views/Cruises/JournalExcerpt.swift:34 (Auflage T8b) | spec | Zweite (c)-Regel „Datum nur bei Abweichung" nicht als reine Funktion extrahiert |
| F05 | minor | nein | ShipTrip/Views/Cruises/RouteJournalPlanner.swift:46-48 | docs | Vorbedingung „vollstaendige Route" des Fallbacks nicht dokumentiert |
| F06 | minor | nein | .winston-evidence/20260827T123855Z/gate-run.json | process | Dev-Evidenz pinnt Basis-Commit statt Feature-Commit |

### F01 — Westliche Zeitzonen-Gegenprobe ohne Unterscheidungskraft
- **File**: `ShipTripTests/RouteJournalPlannerTests.swift:247-266`
- **Severity**: minor · **Blocker**: nein
- **Problem**: `entryDate` ankert auf 12:00 UTC. Jede Zone von UTC-12 bis UTC+11
  liefert dasselbe Tag-Tripel, egal ob lokal oder ueber den UTC-Kalender gelesen.
  Pacific/Midway (UTC-11) kann die Regel also gar nicht brechen — der Test wuerde
  auch bei fehlerhafter lokaler Tag-Extraktion gruen bleiben. (Die Kiritimati-Probe
  `:225-244` ist dagegen echt unterscheidend: UTC+14 verschiebt 12:00 UTC auf den
  Folgetag.)
- **Fix**: als das benennen, was er ist — eine Rand-Stabilitaetsprobe — und auf den
  echten Westrand `Etc/GMT+12` umstellen; Doc-Kommentar auf „Westrand kann den
  Mittags-Anker nicht kippen" korrigieren, statt Symmetrie zu Kiritimati zu suggerieren.

### F02 — Zweiter Zweig des Verwaist-Fallbacks ungetestet
- **File**: `ShipTripTests/RouteJournalPlannerTests.swift:132-142`
- **Severity**: minor · **Blocker**: nein
- **Problem**: Der Test deckt nur „verwaiste `portID`, aber ein Stopp traegt den Tag".
  Der von J3neu (a) Regel 4 woertlich genannte Fall „`port` genullt **und** kein Stopp
  traegt den Tag → Sammelblock" fehlt — also genau die Kombination, die die
  Dev-Entscheidung absichert.
- **Fix**: ein Test nach dem Muster von `danglingPortIDFallsBackToDateRule`, aber mit
  `entryDate` auf einem Tag ohne Stopp; erwartet `unassignedEntryIDs == [entry.id]`
  und `entryIDsByStopID.isEmpty`.

### F03 — id-Tiebreak nur auf Stabilitaet geprueft
- **File**: `ShipTripTests/RouteJournalPlannerTests.swift:200-214`
- **Severity**: minor · **Blocker**: nein
- **Problem**: Der Test vergleicht nur `forward == reversed`. Kehrte der Tiebreak in
  `RouteJournalPlanner.swift:104` die Richtung um, bliebe er gruen — die dokumentierte
  Ordnung (`id.uuidString` aufsteigend) ist damit nicht festgenagelt.
- **Fix**: zusaetzlich gegen die erwartete Reihenfolge assertieren:
  `#expect(forward.unassignedEntryIDs == [a, b].map(\.id).sorted { $0.uuidString < $1.uuidString })`.

### F04 — Zweite (c)-Regel nicht als reine Funktion extrahiert
- **File**: Auflage fuer T8b; Bezug `ShipTrip/Views/Cruises/JournalExcerpt.swift:34`
- **Severity**: minor · **Blocker**: nein
- **Problem**: J3neu (c) enthaelt neben „Weiterlesen" eine zweite deterministische
  Regel: Datum zeigen „nur wenn vom `arrival`-Tag des Stopps abweichend oder im
  Sammelblock". T8a hat nur die erste extrahiert. In View-Code ist das die Stelle, an
  der der Zeitzonen-Vertrag typischerweise bricht (`Date ==`,
  `Calendar.isDate(_:inSameDayAs:)`, lokales `startOfDay`).
- **Fix**: T8b-Auftrag ausdruecklich verpflichten auf
  `RouteDayKey.entryDay(entry.entryDate) != RouteDayKey.localDay(stop.arrival, calendar: …)`
  — oder die Regel als Companion-Funktion neben `needsReadMore` extrahieren und testen.

### F05 — Vorbedingung des Fallbacks nicht dokumentiert
- **File**: `ShipTrip/Views/Cruises/RouteJournalPlanner.swift:46-48`
- **Severity**: minor · **Blocker**: nein
- **Problem**: Der Doc-Kommentar begruendet den Rueckfall, nennt aber nicht die
  Vorbedingung, unter der er harmlos ist: `stops` muss die **vollstaendige**
  `cruise.route` sein. Uebergaebe T8b je eine gefilterte Teilmenge, wanderten
  Eintraege mit gueltigem Hafen-Bezug stillschweigend auf die Datumsregel bzw. in den
  Sammelblock — sichtbar falsch, aber ohne Fehlermeldung.
- **Fix**: eine Satz-Ergaenzung am Doc-Kommentar („`stops` ist immer die vollstaendige
  Route nach `sortOrder`; eine gefilterte Teilmenge verschoebe Eintraege still") und
  derselbe Satz als Auflage im T8b-Auftrag.

### F06 — Dev-Evidenz pinnt Basis-Commit
- **File**: `ShipTrip-worktrees/t8a-klapp-logik/.winston-evidence/20260827T123855Z/gate-run.json`
- **Severity**: minor · **Blocker**: nein
- **Problem**: `commit: 65c5f32` — der Lauf fand vor dem Feature-Commit `c30b494`
  statt. Die Gates selbst sind einwandfrei (richtige Kommandos, Exit 0, 47 Tests,
  Filter wirksam), aber das Artefakt attestiert formal nicht den Baum, der gemergt
  wurde. Kein Blocker: mein eigener Lauf pinnt `d438233` mit demselben Ergebnis.
- **Fix**: Prozess-Regel fuer kommende Developer-Spawns — erst committen, dann
  `evidence.py run`.

## Escalation

Nicht noetig (Iteration 1, keine Blocker).
