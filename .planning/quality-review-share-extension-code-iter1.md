# Review — Share-Extension `ShipTripShare` (Code-Review, statisch)

- **Iteration**: 1 / 3
- **Reviewer**: quality-agent (read-only, kein Build/Test — Build-Token liegt bei einem parallelen Test-Build-Spawn)
- **Datum**: 2026-09-10
- **Diff**: `f8b44ec..4093851` (Branch `feature/share-extension`, Worktree `ShipTrip-worktrees/widget-1.9.0`)
- **Verdikt (Code)**: **approve** — 0 Blocker
- **Verdikt (Go-Live)**: **offen** — kein gruenes Artefakt vorhanden (`gate-run.json` fehlt; ZIEL #7/#8/#9 offen)
- **Stats**: critical 0 · major 1 · minor 6 — **Blocker 0**, Backlog 7
- **Geladene Skills**: code-review · swift-standards · swift-ios · owasp-security · xctest-ios · context7-query (nicht benoetigt — SDK-Header lokal verifiziert)

## Summary

Der Diff setzt ADR-010 und den Handoff-Contract sauber um. Beide Gate-#4-Auflagen sind
**im Code erfuellt** (A1: `.onDisappear`, A2: `usingTemporaryStore`-Guard). Die
pbxproj-Abnahmeliste #1–#15 ist vollstaendig, die Build-Settings sind 1:1 vom
Widget geklont (nur die drei vorgesehenen Abweichungen), Plist-Schluessel und
Aktivierungspraedikat entsprechen H4 exakt, Entitlements H6, Fastfile H6.
Loeschregel, Pfadbehandlung und Groessenlimit halten der Sicherheitspruefung stand.
Der einzige `major` ist Doku-Drift: Contract H3 wurde nie mit dem A1/A2-Wortlaut
nachgezogen und widerspricht jetzt dem Code. Kein Finding blockiert den Go-Live.

**Wichtiger Vorbehalt:** Commit 4093851 (App-Seite + Tests) und e9e043e (Extension)
sind laut Spawn-Auftrag **nie kompiliert** worden. Dieses Review ist rein statisch;
die Compile-/Signing-Risiken wurden gegen die lokalen SDK-Interfaces geprueft
(siehe „Verifizierte Apple-Fakten"), koennen einen Build aber nicht ersetzen.

## Findings

| ID  | Severity | Blocker | Datei:Zeile | Kategorie | Titel |
|-----|----------|---------|-------------|-----------|-------|
| Q01 | major    | nein    | `docs/architecture/contracts/share-extension-handoff.md:136-138` · `docs/adr/ADR-010-…:56-58` | docs | Contract/ADR nie mit A1/A2 nachgezogen — widerspricht jetzt dem Code |
| Q02 | minor    | nein    | `docs/architecture/contracts/share-extension-handoff.md` (H4, Absatz „Anhang waehlen und laden") | docs | „unverifiziert" zum Loeschverhalten ist jetzt verifiziert (SDK-Header) |
| Q03 | minor    | nein    | `ShipTripShare/ShareViewController.swift:155-162` | robustness | `closeTapped` nicht gegen Doppeltipp gesichert — `completeRequest` koennte zweimal laufen |
| Q04 | minor    | nein    | `ShipTrip/ShipTripApp.swift:1-417` | size | 417 Zeilen, ueber dem 400er-Soft-Limit (guard.py: WARN, Exit 0) |
| Q05 | minor    | nein    | `ShipTripTests/ShareImportHandoffScanTests.swift:64-92` | tests | Loeschung der **defekten** Uebergabedatei nicht getestet (nur Erfolgspfad) |
| Q06 | minor    | nein    | `ShipTrip/ShareShared/ShareHandoffStore.swift:22` | style | `Sendable` auf einem fall-losen Enum ist Dekoration ohne Wirkung |
| Q07 | minor    | nein    | `docs/SETUP.md:187-189` | docs | Umformulierter Satz sprengt die Zeilenbreite der Datei |

### Q01 — Contract/ADR nie mit A1/A2 nachgezogen
- **Datei**: `docs/architecture/contracts/share-extension-handoff.md:136-138` (H3, Verdrahtung, Punkt 3) und `docs/adr/ADR-010-share-extension-app-group-handoff.md:56-58`
- **Severity**: major · **Blocker: nein** (der Code ist korrekt, die Doku ist alt)
- **Problem**: Gate #4 (`quality-review-share-extension-gate4-iter2.md:247-255`) gab sein Go
  ausdruecklich unter der Bedingung, dass A1 und A2 als je ein Satz in H3 landen
  („Werden A1/A2 nicht eingetragen, ist dieses Go hinfaellig"). Beides ist **nicht**
  geschehen: `grep -n "onDisappear\|usingTemporaryStore" contract adr` liefert keine
  Treffer. H3 Punkt 3 sagt weiterhin „Nach `shareImportCoordinator.dismiss()` im
  Ergebnis-Sheet (beide `dismiss`-Stellen)" — genau die Variante, die G01 als
  Coordinator-Falle identifiziert hat. Der A2-Guard fehlt in beiden Dokumenten
  vollstaendig; ADR-010:56-58 beschreibt den Trigger weiterhin ohne Ausnahme.
  Der **Code** macht es richtig (`ShipTripApp.swift:238-250` Guard, `:325` `.onDisappear`),
  d. h. das Risiko hat sich nur als Doku-Drift materialisiert — aber Gate #6 prueft
  ADR gegen Diff, und dort faellt es auf.
- **Fix**: H3 Punkt 3 durch den A1-Wortlaut aus `quality-review-share-extension-gate4-iter2.md:120-128`
  ersetzen; den A2-Satz (`:145-150`) als eigenen Absatz an H3 anhaengen; in ADR-010
  hinter „(`scenePhase == .active`, zusaetzlich einmalig beim Szenenaufbau und nach dem
  Schliessen des Ergebnis-Sheets)" den Halbsatz „— nicht jedoch, solange die App auf
  dem Wegwerf-Store laeuft" ergaenzen.

### Q02 — Verifikationsstand H4 ist ueberholt
- **Datei**: `docs/architecture/contracts/share-extension-handoff.md`, H4, Absatz „Anhang waehlen und laden"
- **Severity**: minor · **Blocker: nein**
- **Problem**: Der Contract sagt, fuer die **typisierte** `loadFileRepresentation`-Variante
  sei das Loeschverhalten der Temp-Datei „nicht in der Referenz belegt (unverifiziert)".
  Das ist inzwischen belegt — Apple-Header, iOS 26.5 SDK,
  `UniformTypeIdentifiers.framework/Headers/NSItemProvider+UTType.h:105-107`:
  „This temporary file will be deleted once your completion handler returns. To keep a
  copy of this file, move or copy it into another directory before returning from the
  completion handler." Derselbe Absatz (`:112`) haelt fest: „The completion handler may
  be scheduled on an arbitrary queue."
- **Fix**: „(unverifiziert)" durch „(verifiziert, `NSItemProvider+UTType.h`)" ersetzen.
  Die Implementierung (`ShareViewController.swift:133-136`, synchrone Kopie im Handler,
  UI-Update per `Task { @MainActor in }`) ist dadurch bestaetigt, nicht geaendert.

### Q03 — `closeTapped` nicht gegen Doppeltipp gesichert
- **Datei**: `ShipTripShare/ShareViewController.swift:155-162`
- **Severity**: minor · **Blocker: nein**
- **Problem**: Der Schliessen-Knopf bleibt nach dem ersten Tipp aktiv und
  `extensionContext` bleibt non-nil. Ein zweiter Tipp waehrend der Dismiss-Animation
  ruft `completeRequest`/`cancelRequest` ein zweites Mal auf. In der Praxis dismissed
  der Host sofort, das Fenster ist schmal — deshalb minor, nicht major.
- **Fix**: Erste Zeile in `closeTapped`: `closeButton.isEnabled = false`.

### Q04 — `ShipTripApp.swift` ueber dem Soft-Limit
- **Datei**: `ShipTrip/ShipTripApp.swift` (417 Zeilen, +41 durch diesen Diff)
- **Severity**: minor · **Blocker: nein**
- **Statischer Pass**: `guard.py sizes --files <7 geaenderte .swift>` → `sizes: ok
  (7 geprueft, 1 Soft-Warnungen)`, **Exit 0**. Hard-Limit 500 nicht erreicht,
  also kein `major` nach der Regel.
- **Fix**: Backlog. Kandidat: die Share-/Widget-Verdrahtung als eigenen
  `ViewModifier` aus dem `WindowGroup`-Body ziehen — bewusst **nicht** in diesem Run.

### Q05 — Defekte Uebergabedatei nicht getestet
- **Datei**: `ShipTripTests/ShareImportHandoffScanTests.swift:64-92`
- **Severity**: minor · **Blocker: nein**
- **Problem**: Die vier vom Contract geforderten Scan-Tests sind alle da (gueltige Datei
  importiert + geloescht · leerer Ordner · Ergebnis steht an ⇒ kein Import · `inbox: nil`).
  Die Zusicherung „eine defekte Uebergabedatei wird ebenfalls entfernt, kein
  Endlos-Fehlschlag bei jedem Vordergrund-Wechsel" (Doc-Kommentar
  `ShareImportCoordinator.swift:167-169`) ist dagegen nur durch das gemeinsame `defer`
  (`:126-131`) gedeckt, nicht durch einen Test. Falsch-gruen-Risiko gering, aber die
  Aussage steht unbewiesen im Code.
- **Fix**: Ein Test — Datei mit Muell-Bytes und gueltigem Namen ablegen, scannen,
  `settle`, `#expect` auf `.failed` **und** `exists(file) == false`. Backlog.

### Q06 — `Sendable` auf fall-losem Enum
- **Datei**: `ShipTrip/ShareShared/ShareHandoffStore.swift:22`
- **Severity**: minor · **Blocker: nein**
- **Problem**: `enum ShareHandoffStore: Sendable` — ein Enum ohne Faelle ist
  uninhabitiert; die Conformance sichert nichts zu und ist nicht angefordert
  (CLAUDE.md §2 „nichts Spekulatives"). Vergleichspunkt: `ShareArchiveLimits`
  (gleiches Muster, gleiche Rolle) kommt ohne aus.
- **Fix**: `: Sendable` streichen. Backlog.

### Q07 — Zeilenbreite in SETUP.md
- **Datei**: `docs/SETUP.md:187-189`
- **Severity**: minor · **Blocker: nein**
- **Fix**: Nach „`com.andre.ShipTrip.Share`)." umbrechen. Backlog.

## Contract-/ADR-Abgleich (Gate-#6-Vorpruefung)

| Vertrag | Stand |
|---|---|
| **H2** Store: groupID · Ordner · Namensschema · tmp+move · nicht-rekursiver Scan · Sortierung · 24-h-Regel · 275-MB-Limit vor dem Kopieren | **erfuellt** |
| **H3** `shouldRemoveAfterImport(_:inbox:)` · `importPendingHandoffIfIdle(modelContext:inbox:)` · drei Aufrufstellen · Single-Flight · kein neuer Zustand/String | **erfuellt** (Aufrufstelle 3 = `.onDisappear`, siehe Q01) |
| **H4** Plist-Schluessel (4 Stueck, exakt) · Praedikat wortgleich · UTI-Deklaration deckungsgleich mit `ShipTrip-Info.plist:10-29` · verbotene Schluessel abwesend · Anhang per Typ, nie per Index · typisiertes Laden | **erfuellt** |
| **H5** Reihenfolge 1–4 · nur `.authorized` · Identifier `share.handoff` (kein `reminder.`-Praefix) · `trigger: nil` · `cancelRequest` bei Fehler/zu gross | **erfuellt** |
| **H6** Bundle-ID · Entitlements nur App-Groups · Build-Settings 1:1 Widget (Debug+Release, nur die drei vorgesehenen Abweichungen, `CURRENT_PROJECT_VERSION = 30` = App/Widget) · pbxproj #1–#15 vollstaendig · Fastfile-Block · SETUP.md · ExportOptions.plist | **erfuellt** |
| **A1** Re-Scan in `.onDisappear`, nicht im Sheet-Binding | **erfuellt** (`ShipTripApp.swift:325`) |
| **A2** kein Scan bei `usingTemporaryStore` | **erfuellt** (`ShipTripApp.swift:246`) |
| **Abweichung** | Contract H3 / ADR-010 dokumentieren A1/A2 nicht → **Q01** |
| **Abweichung** | H4-Verifikationsstand ueberholt → **Q02** |

`build/ExportOptions.plist` traegt den dritten `provisioningProfiles`-Eintrag, ist aber
per `.gitignore:11` untracked — Bestand, kein Befund dieses Diffs.

## Sicherheits-/Datenverlust-Pass (Angriffsflaeche beruehrt: Dateiannahme aus fremden Hosts)

- **Pfad-Traversal**: ausgeschlossen. `isValidHandoffName` prueft rein auf dem String
  (Laenge 45, `UUID(uuidString:)` auf Zeichen 1–36, Endung case-insensitiv) —
  `/`, `\` und `..` sind per Konstruktion unmoeglich; die Ziel-URL entsteht nie aus
  fremdem Input, sondern aus `contentsOfDirectory` + Namensfilter. Getestet
  (`ShareHandoffStoreTests.swift:50-65`).
- **Symlinks**: `pendingFiles` verlangt `isRegularFile == true` **und**
  `isSymbolicLink != true`; Test mit Symlink nach aussen vorhanden (`:84-99`).
- **Loeschregel / Datenverlust**: Geloescht wird nur unterhalb `Documents/Inbox`,
  `tmp` und des uebergebenen Uebergabeordners — jeweils mit abschliessendem Trenner,
  also kein `ShareInbox2/`-Treffer. In-Place-Dateien des Nutzers bleiben unangetastet;
  beide Faelle sind getestet (`ShareImportCleanupTests.swift:44-89`). Der A2-Guard
  verhindert genau den Fall „importiert in den Wegwerf-Store, Uebergabedatei
  trotzdem geloescht".
- **Endlosschleife**: ausgeschlossen — das `defer` in `startImport`
  (`ShareImportCoordinator.swift:124-131`) loescht Erfolg **wie** Fehler; siehe
  aber Q05 (untestiert).
- **Groessenlimit**: `storeHandoff` stat't **vor** `copyItem`
  (`ShareViewController.swift:41-44`), Grenze `ShareArchiveLimits.maxArchiveFileSize`
  (275 MB). Fehlgeschlagener Move raeumt die `.tmp` weg (`:62-64`).
- **Atomizitaet**: `<UUID>.tmp` → `moveItem` auf `<UUID>.shiptrip`; ein paralleler
  Scan sieht die `.tmp` nie (falscher Name). Getestet (`ShareHandoffStoreTests.swift:71-82`).
- **Kein neuer URL-Parameter, kein Router-Fall** — Angriffsflaeche waechst nicht.
  Der volle C10-Preflight laeuft unveraendert auf jeder importierten Datei.
- **GDPR**: keine neue Datenverarbeitung, kein Netzwerk, keine Telemetrie, keine
  Logs mit Nutzerdaten. Die Mitteilung enthaelt keine Reisedaten (feste Strings).
  Pruefung entfaellt nach Trigger-Regel.

## Concurrency-Pass (Swift 6, `SWIFT_STRICT_CONCURRENCY = complete`)

- `ShareViewController` erbt die `@MainActor`-Isolation von `UIViewController` und ist
  damit implizit `Sendable`; die Capture von `self` im `@Sendable`
  Completion-Handler (`:133-136`) ist zulaessig. Der Handler laeuft laut Apple auf
  „an arbitrary queue" — der Sprung zurueck via `Task { @MainActor in self.show(…) }`
  ist korrekt und noetig.
- `storeHandoff` ist eine nonisolated freie Funktion, `HandoffOutcome: Sendable` —
  die Uebergabe ueber die Isolationsgrenze ist sauber.
- `show(_:)` kann nur einmal laufen (Guard-Else-Pfad **oder** Handler, nie beides).
- App-Seite: `App` ist im SDK `@preconcurrency @MainActor` deklariert
  (`SwiftUI.swiftinterface:8157`), `scanShareHandoff` erbt die Isolation. `.task` traegt
  `@_inheritActorContext` (`:4921`), der synchrone Aufruf ohne `await` ist korrekt.
  `ModelContainer` ist `Sendable`.
- Doppelter Scan bei Kaltstart (`.task` **und** `scenePhase == .active`) ist durch
  `guard state == .idle` entschaerft — der zweite Aufruf ist ein No-op.

## Simplicity / Surgical

Keine Fremd-Aenderungen im Diff, keine spekulativen Abstraktionen. Die zwei neuen
Parameter (`inbox:`, `handoffInbox:`) tragen jeweils einen Default und sind vom
Contract als Test-Naht vorgeschrieben — begruendet, nicht spekulativ. Test-Diff
(318 Zeilen) < Code-Diff (~430 Zeilen) — kein Maximal-Testen. Einzige
Simplicity-Notiz: Q06.

## Test-Run-Status

**Kein Test gefahren** — Auftragsvorgabe (Build-Token liegt bei einem parallelen
Test-Build-Spawn). Statischer Pass gefahren: `guard.py sizes` → Exit 0
(1 Soft-Warnung, Q04); Extension-`Localizable.xcstrings` per JSON-Parse geprueft:
alle 7 Schluessel, DE **und** EN, Status `translated`, Wortlaut identisch mit der
H5-Tabelle. **`evidence_path`: nicht vorhanden.**

## Go-Live-Triage

- **Blocker aus diesem Review: 0.** Q01 ist Doku-Nachzug, Q02–Q07 sind Backlog.
- **Der Go-Live bleibt trotzdem gesperrt** — nicht wegen eines Findings, sondern weil
  ZIEL #7 (E2E im Simulator + `gate-run.json` Exit 0), #8 (Geraetebestaetigung Andre)
  und #9 (CHANGELOG, `docs/features/kreuzfahrt-teilen.md:84-89`, CLAUDE.md) offen sind
  und der Code nie kompiliert wurde. Ein Go ohne gruenes Artefakt waere unzulaessig.
- **Empfehlung an Winston**: Q01 vor Gate #6 nachziehen (5 Minuten, reine Doku, kein
  Developer-Spawn noetig). Q02–Q07 ins Backlog. Danach entscheidet allein das
  Ergebnis des laufenden Test-Build-Spawns ueber Go/No-Go.

## Backlog-Kandidaten (Einzeiler fuer `.planning/BACKLOG.md`)

- `[minor] docs/architecture/contracts/share-extension-handoff.md — H4-Verifikationsstand zu loadFileRepresentation ist ueberholt (jetzt verifiziert)`
- `[minor] ShipTripShare/ShareViewController.swift:155 — closeTapped nicht gegen Doppeltipp gesichert`
- `[minor] ShipTrip/ShipTripApp.swift:1 — 417 Zeilen, ueber dem 400er-Soft-Limit`
- `[minor] ShipTripTests/ShareImportHandoffScanTests.swift:64 — Loeschung der defekten Uebergabedatei untestiert`
- `[minor] ShipTrip/ShareShared/ShareHandoffStore.swift:22 — Sendable auf fall-losem Enum ohne Wirkung`
- `[minor] docs/SETUP.md:187 — Zeilenbreite gesprengt`
