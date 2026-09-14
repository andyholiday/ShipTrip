# Review — Widget-Richtung „Dynamic Instrument" (Konzept 03)

- **Iteration**: 1 / 3 (finale Prüfung nach Gate r2)
- **Reviewer**: quality-agent (frischer Spawn)
- **Datum**: 2026-09-13
- **Branch**: `design/widget-dynamic-instrument` @ `8835c23` · Basis `5968854`
- **Worktree**: `/Users/andre-studio/Documents/0.Projekte/ShipTrip-worktrees/widget-dynamic`
- **Verdikt**: **approve** (go-mit-backlog)
- **Stats**: critical: 0, major: 1, minor: 5 — Blocker: 0, ins Backlog: 6

## Summary

Der Diff dient dem Ziel. Beide Blocker aus Gate r2 sind sichtbar behoben: das
XXL-Datum im Mittelformat steht jetzt vollständig („13.09.26"), und der Ring
der Rectangular-Familie ist in allen fünf Bildern ein geschlossener Bogen statt
links flach gekappt. Alle 23 Galerie-PNGs neu erzeugt und einzeln gesichtet —
**0 Bilder mit abgeschnittenem Pflichttext**. Beide Gates grün (Exit 0), Scope
exakt wie vorgegeben. Kein Umweg, kein Überbau von Belang: der Zuwachs liegt
fast vollständig in den vier Familien-Views plus dem Token-/Bausteinsatz, die
Formatierungs-Helfer sind bis auf zwei tote Symbole alle in Gebrauch.

## Kernzahlen

| Größe | Wert |
|---|---|
| Code-Diff Swift unter `ShipTripWidget/` (6 Dateien) | **+1015 / −218** |
| Test-Diff (`ShipTripTests/`, `ShipTripUITests/`) | **+0 / −0** → K6 „Test-Diff ≤ Code-Diff" erfüllt |
| `Localizable.xcstrings` | +445 / −195; 32 → 57 Keys, **alle 57 mit EN, Status `translated`** |
| `project.pbxproj` | genau **1 Zeile** (`Assets.xcassets` in die App-Target-Ausnahmeliste) |
| Binär | 2 Widget-Assets (Hero/Ghost) + Konzept-Ausschnitt + 3× 23 Galerie-Shots |
| `guard.py sizes` | Exit 0 — 1 Soft-Warnung (`MediumWidgetView.swift` 458 > 400), Hard-Limit 500 nicht erreicht |

## Gate-Evidenz

`evidence_path`: `/Users/andre-studio/Documents/0.Projekte/ShipTrip-worktrees/widget-dynamic/.winston-evidence/20260913T141535Z/gate-run.json`
`status: verified` · `commit: 8835c23` · `xcodebuild: Xcode 26.6`

| Gate | Exit | Beleg |
|---|---|---|
| `unit` | **0** | 4 Swift-Testing-Suiten grün: WidgetStateResolver, WidgetTimelinePlanner, WidgetSnapshotStore, WidgetSnapshotPublisher |
| `gallery` | **0** | `Executed 4 tests, with 0 failures` (DE_Dark_L, DE_Light_XXL, DE_Light_L, EN_Light_L) |

**Nicht-geskippt belegt:** genau **23** `[Widget-Screenshot]`-Zeilen im
`gallery.log`, 23 PNG mit frischem Zeitstempel (16:15–16:17) in
`docs/design/directions/shots/dynamic/`. Vorstand nach `dynamic-r2` verschoben.
Kein Weichspüler-Kommando: beide Gates sind unveränderte
`xcodebuild test-without-building`-Läufe gegen den Wegwerf-Simulator.

## K5 — Scope-Befund: sauber

Berührt: `ShipTripWidget/` (6 Swift, Assets, xcstrings), `docs/design/`,
1 Zeile `project.pbxproj`. **Unberührt und verifiziert**: `ShipTrip/WidgetShared/`,
`ShipTripWidget/ShipTripWidget.swift` (Provider/Timeline), `PreviewFixtures.swift`,
`ShipTripUITests/`. `WidgetFormatting.accessibilityLabel(for:)` (`:327`) steht
nicht im Diff — semantisch unverändert, wird weiterhin von allen vier Views
aufgerufen. `ShipTripWidgetEntryView.swift` musste nicht angefasst werden: es
zog schon vorher `WidgetStyle.surface`, deren Neudefinition trägt K3 (Navy in
Hell *und* Dunkel — in `medium-active-light-L` vs. `-dark-L` bestätigt).

**Pflichtinhalt je Familie/Zustand** (Code + Bild geprüft): Titel, aktueller
Stopp, Ankunft/Jetzt/Abfahrt, nächster Stopp, Countdown, Schiff und Datum sind
überall vorhanden. Gegenüber der Basis wurde nichts entfernt — das Mittelformat
zeigt jetzt sogar mehr (Datum mit Jahr, Schiffsname), wo die Basis zwei nackte
Spalten hatte.

## PNG-Sichtung (23/23, Schwellwert „…" = 0)

| Bild | Urteil |
|---|---|
| widget-medium-active-de-light-L | ok |
| widget-medium-active-de-dark-L | ok |
| widget-medium-active-de-light-XXL | **ok — r2-Blocker behoben**, Datum „13.09.26" vollständig |
| widget-medium-countdown-de-light-L | ok |
| widget-medium-countdown-de-light-XXL | ok (Leerband unten, kosmetisch → F05) |
| widget-medium-idle-de-light-L | ok (Leerband unten, kosmetisch → F05) |
| widget-small-active-de-light-L | ok |
| widget-small-active-de-light-XXL | ok |
| widget-small-active-en-light-L | ok — „42 min, 47 sec left", r2-Schnitzer „Still" behoben |
| widget-small-countdown-de-light-L | ok |
| widget-small-countdown-de-light-XXL | ok |
| widget-small-idle-de-light-L | ok |
| widget-small-unavailable-de-light-L | ok |
| widget-rectangular-active-de-light-L | **ok — Ring vollständig** (r2-Blocker behoben) |
| widget-rectangular-active-de-light-XXL | **ok — Ring vollständig** |
| widget-rectangular-countdown-de-light-L | **ok — Ring vollständig** |
| widget-rectangular-countdown-de-light-XXL | **ok — Ring vollständig** |
| widget-rectangular-idle-de-light-L | **ok — Ring vollständig** |
| widget-circular-active-de-light-L | ok |
| widget-circular-active-de-light-XXL | ok |
| widget-circular-countdown-de-light-L | ok |
| widget-circular-countdown-de-light-XXL | ok |
| widget-circular-idle-de-light-L | ok |

**23× ok · 0× „…"** — Schwellwert eingehalten. Kein Text über der Kachelkante,
kein gekapptes Ringmotiv mehr.

## Findings — alle Nicht-Blocker

| ID | Severity | Blocker | File:Line | Kategorie | Titel |
|---|---|---|---|---|---|
| F01 | major | nein | `ShipTripWidget/WidgetFormatting.swift:175-228, 258-281` | tests/wartbarkeit | Doppelte Schwellen-Leitern ohne Test |
| F02 | minor | nein | `ShipTripWidget/WidgetFormatting.swift:288-290` | dead code | `taglineActive` nie verwendet |
| F03 | minor | nein | `ShipTripWidget/Views/WidgetStyle.swift:92` | dead code | `WidgetSymbol.place` nie verwendet |
| F04 | minor | nein | `ShipTripWidget/Views/MediumWidgetView.swift:1-458` | größe | 458 Zeilen über Soft-Limit 400 |
| F05 | minor | nein | `ShipTripWidget/Views/MediumWidgetView.swift:285-292, 373` | design | Leerband in der unteren Kachelhälfte (XXL-Countdown, Idle) |
| F06 | minor | nein | `ShipTripWidget/Views/MediumWidgetView.swift:125` | inhalt | Schiffsname weicht dem Land des aktuellen Stopps |

### F01 — Doppelte Schwellen-Leitern ohne Test
- **Severity**: major · **Blocker**: nein
- **Problem**: `countdownParts(daysUntilStart:dative:)` und `sinceLastCruise(days:)`
  führen die Schwellen von `countdown(daysUntilStart:)` (`:151-170`) bzw.
  `lastCruise(daysSince:)` (`:230-253`) als parallele `switch`-Leitern ein zweites
  Mal. Ich habe sie Grenze für Grenze gegeneinander geprüft — heute stimmen sie
  (`..<2`↔`..<0/0/1`, `2...7`, `8...14`, `15...30`→`nil`, `>30`). Sie können aber
  still divergieren, und kein Test hält sie zusammen. Das ist neue *Logik*, nicht
  View-Code; die Testumfangs-Leiter im Auftrag deckt nur die Views ab.
- **Fix**: eine Swift-Testing-Parametrierung über
  `days ∈ {-1, 0, 1, 2, 7, 8, 13, 14, 15, 30, 31, 59, 60, 90}`, die prüft, dass
  `countdownParts` genau dann `nil` liefert, wenn `countdown` keinen
  Zahl-Einheit-Wortlaut hat, und dass Zahl + Einheit im übrigen Fall im
  `countdown`-Wortlaut enthalten sind. Alternativ die Schwellen in *eine*
  private Funktion ziehen, aus der beide lesen.
- **Triage**: kein Go-Live-Blocker — betroffen ist ein Anzeigetext, kein
  Datenweg, kein Sicherheits- oder Verlustrisiko. Backlog p2.

### F02 — `taglineActive` nie verwendet
- **Problem**: `WidgetFormatting.taglineActive` („GUTE ORTE. BESSERE GESCHICHTEN.")
  ist deklariert und im String-Katalog lokalisiert, wird aber von keiner View
  aufgerufen — der Platz im aktiven Mittelformat trägt stattdessen den Reisetitel
  (`MediumWidgetView.swift:241`). Verifiziert per `grep` über `ShipTripWidget/`,
  `ShipTrip/`, `ShipTripTests/`: genau ein Treffer, die Deklaration selbst.
- **Fix**: Konstante und den zugehörigen Katalog-Key entfernen. Backlog p3.

### F03 — `WidgetSymbol.place` nie verwendet
- **Problem**: `static let place = "mappin.and.ellipse"` ist in dieser Richtung
  neu hinzugekommen (Basis kannte es nicht) und hat null Aufrufer.
- **Fix**: Zeile entfernen. Backlog p3.

### F04 — `MediumWidgetView.swift` über dem Soft-Limit
- **Problem**: 458 Zeilen, Soft-Limit 400. `guard.py sizes` meldet WARN, Exit 0 —
  das Hard-Limit 500 ist nicht erreicht, also kein `major`.
- **Fix**: `countdownContent` + `heroBlock` (Zeilen 253-341) in eine eigene
  `MediumCountdownView.swift` ziehen. Backlog p2 — vor dem nächsten Ausbau
  dieser Datei, sonst reißt der nächste Zustand das Hard-Limit.

### F05 — Leerband in der unteren Kachelhälfte
- **Problem**: bei `medium-countdown` XXL und `medium-idle` L bleibt rund ein
  Drittel der Kachel leer, weil bei `isTight` Bildkreis und Tagline entfallen
  (`:285-292`) bzw. der Idle-Zustand nur drei Zeilen trägt. Rein kosmetisch,
  bereits in r2 als Nicht-Gate-Punkt notiert.
- **Fix**: `Spacer`-Verteilung oder vertikale Zentrierung im engen Fall. Backlog p3.

### F06 — Schiffsname weicht dem Land
- **Problem**: `detail: current.country ?? info.ship` — hat der aktuelle Stopp ein
  Land, verschwindet der Schiffsname, den ZIEL K5 als Pflichtinhalt führt. In der
  Galerie nie sichtbar, weil beide Aktiv-Fixtures kein Land am aktuellen Stopp
  tragen (beide Shots zeigen „Mein Schiff 4" bzw. „AIDAnova").
- **Kein Regress**: die Basis zeigte im bereisten Aktiv-Zustand *gar kein* Schiff.
  Der Diff verbessert die Lage, erfüllt K5 an dieser Stelle aber nur bedingt.
- **Fix**: beides setzen („Mein Schiff 4 · Dänemark") oder das Land in die
  Ausblick-Spalte verschieben. Backlog p2.

## Überbau-Prüfung

Kein nennenswerter Überbau. Die neuen Bausteine in `WidgetStyle.swift`
(`WidgetRing`, `WidgetNumeral`, `WidgetTimeline`, `WidgetTagline`,
`WidgetValueLine`) haben alle echte Aufrufer (1–3 je Typ); `accentSoft` und
`surfaceTop` werden innerhalb der Datei von den Verläufen konsumiert;
`dayWithYear` lebt über `departureLine`. Einzige spekulative Reste sind F02 und
F03 — zwei Zeilen. Die Mehrzeilen gegenüber der Basis sind Layout-Substanz
(Ring, Zeitleiste, Ghost-Maske, Hero-Kreis), kein Abstraktions-Gerüst.

## Go-Live-Triage

Keine offene Blocker-Finding → **Go**. Alle sechs Findings sind
Wartbarkeit/Kosmetik und wandern nach `.planning/BACKLOG.md`.
Offen bleibt ZIEL K8 (Andres Bestätigung am Gerät im nächsten TestFlight-Build) —
bewusst kein Run-Blocker.

## Laufzeit-Ressourcen

Wegwerf-Simulator `ci-widget-quality-dynamic-92065`
(`F57C02DD-54FA-4B66-8A98-481F919AD2C7`): `agent-sim release` meldete
`stale-lease-removed`, deshalb selbst aufgeräumt via `simctl shutdown` + `delete`
sowie `simctl --set testing delete all`. Nachkontrolle: UDID nicht mehr in
`simctl list devices`. **Sauber, keine Leiche.**
