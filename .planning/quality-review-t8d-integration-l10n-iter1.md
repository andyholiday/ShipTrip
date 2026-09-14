# Review — T8d (Integration Route↔Journal + L10n/A11y/UI-Tests)

- **Iteration**: 1 / 3
- **Reviewer**: quality-agent (statische Tiefenpruefung, keine eigene Test-Runde)
- **Datum**: 2026-08-27
- **Diff**: `git diff 8f1df20..f426573` (release/1.8.5, Worktree `merge`)
- **Verdikt**: approve (GO-mit-Backlog)
- **Stats**: critical: 0, major: 2, minor: 5 — Blocker: 0, Backlog: 7

## Summary
Der T8d-Gesamtdiff haelt. Das Wiring T8b↔T8c ist korrekt und minimal, der
JournalDeletePaths-Fix ist im UI-Code vollstaendig, der Rot-Beweis ist echt und
trifft eine wirklich geaenderte Zeile, der Katalog ist lueckenlos. Kein Finding
blockiert den Go-Live.

## Evidenz-Pruefung
- `…/t8d1-integration/.winston-evidence/20260827T132014Z/gate-run.json` —
  build + tests exit 0, `tests.log`: „Test run with 549 tests in 116 suites
  passed". Commit `7f0b84b`. **Anmerkung:** `build.log` ist leer
  (sha256 = `e3b0c442…b855` = Leer-String) — Folge von `-quiet`, Exit-Code 0
  ist protokolliert. Kein Weichspueler-Kommando; `tool_versions` fehlt (F07).
- `…/t8d2-l10n-uitests/.winston-evidence/20260827T134315Z/gate-run.json` —
  build + tests exit 0, „Executed 4 tests, with 0 failures". Commit `6e891c8`,
  Xcode 26.6. Beide Kommandos sind reguläre `xcodebuild`-Gates.
- Rot-Beweis `16f347c` → `7f0b84b`: Der Test-only-Commit zitiert die reale
  Fehlermeldung mit Werten (`stored.updatedAt > JournalTestClock.insert`).
  Nachvollzogen: `reconcileRoute(existingPorts:[port], tempPorts:[])` baut
  `existingByID` aus **existingPorts**, `tempIDs` ist leer → die zweite
  Loesch-Schleife (CruiseFormView.swift:87) laeuft. Der Test trifft also
  genau die geaenderte Zeile. Rot-Beweis gueltig.

## Delete-Audit (repo-weit)
`grep -rn --include="*.swift" "\.delete(" ShipTrip/` — **kein direkter
`Port`-Delete mehr ausserhalb `JournalDeletePaths`.** Verbleibende Treffer sind
vertragsfremd (Cruise, Deal, Expense, CustomShippingLine, HiddenCatalogItem,
Keychain) oder Katalog-Dedup. Einzige `Photo`-Ausnahme: F06.

## Wiring-Pruefung (J3neu)
- `onOpenEntry` → `journalNavigation.openEntry(id:)` →
  `.navigationDestination(item:)` → Push `JournalEntryDetailView` ✓
- `onAddEntry` → `.sheet(item:)` → `JournalEntryEditorView(prefill:)` ✓
- Prefill-Herkunft korrekt: `RouteStopCard` gibt `onAddEntry(port)` mit dem
  **eigenen** Port (RouteJournalSection.swift:131), der Sammelblock
  `onAddEntry(nil)` (:60) → `.noStop`. `stop(portID:arrival:)` nimmt
  `port.arrival` des richtigen Stopps.
- `EditorRequest` mit eigener `id` loest das `.sheet(item:)`-Problem bei
  wiederholtem Aufruf desselben Stopps sauber.
- Kein `navigationDestination`-Typkonflikt: `UUID?` wird nur hier registriert
  (CruiseListView nutzt `for: Cruise.self`, MapView `item:` mit `Cruise`).
- J3neu (c)/(d) eingehalten: Bearbeiten/Loeschen existieren nur in
  `JournalEntryDetailView`, nicht in der Zeile.

## Konsolidierung
`RouteJournalMood` → `JournalMood`: Emoji und Labels **identisch** zum
Altstand (verifiziert gegen `git show 8f1df20:…/RouteJournalMood.swift`), keine
Restreferenz im Repo. `RouteJournalEntryRow.dayText` → `JournalEntryDayDisplay`.
`ExpenseSorting` unveraendert ausgelagert (Zeile-fuer-Zeile identisch).
Migrierte Tests liegen in `JournalMoodTests` / `JournalEntryDayDisplayTests`.

## Katalog
32 neue Keys (Spec sagte 31), 0 geaenderte. `sourceLanguage: de` → fehlende
`de`-Eintraege sind korrekt (Key = deutsche Quelle). Alle 429 uebersetzbaren
Keys haben EN im State `translated`; die 8 ohne EN sind Format-/Symbol-Keys mit
`shouldTranslate: false` (`%@ - %@`, `+%lld`, `🌊` …). Type-aware: `Tag %lld`
korrekt `%lld`, `%lld Fotos` als echte Plural-Variation in **beiden** Sprachen
(`one: %lld Foto` / `one: %lld photo`). Keine `Text(variable)`-Falle: alle
Literale in den Journal-Views sind `LocalizedStringKey` und im Katalog
aufgeloest (Stichprobe „Hafen bearbeiten" → „Edit Port", „Weiterlesen" →
„Read more", „Noch keine Häfen hinzugefügt" → „No ports added yet").
EN-Qualitaet stichprobenhaft gut; einzige Nuance: `Schlecht` → `Awful` ist
staerker als das deutsche Wort — im 5-Punkte-Verlauf (Great/Good/Okay/Not so
good/Awful) aber stimmig.

## A11y-Substanz
Substanziell, nicht kosmetisch: Zeile bekommt `.isButton` **plus** Hint,
dekoratives Chevron `accessibilityHidden(true)`, Kopfzeile mit
`accessibilityValue` aufgeklappt/zugeklappt + Hint, Eckdaten-Block
`children: .combine`, Mood-Auswahl mit `.isSelected`-Trait. Der neue
`editPortButton` schliesst die T9b-F03-Luecke (Seetag/Hafen ohne Momente hatte
nur das Kontextmenue).

## Findings

| ID  | Sev.  | Blocker | Datei:Zeile | Kategorie | Titel |
|-----|-------|---------|-------------|-----------|-------|
| F01 | major | nein | ShipTrip/Views/Cruises/CruiseFormView.swift:792 | tests | `deletePhoto`-Bindung ohne Test |
| F02 | major | nein | ShipTrip/Views/Cruises/CruiseFormView.swift:1-954 | size | Ueber 500-Zeilen-Hardlimit (Bestand) |
| F03 | minor | nein | ShipTripUITests/JournalRouteFadenUITests.swift:133-142 | tests | `value`-Assertion direkt nach `tap()` ohne Expectation |
| F04 | minor | nein | ShipTripUITests/JournalRouteFadenUITests.swift:96,210,239,254 | tests | Label-basierte Anker brechen unter EN-Locale |
| F05 | minor | nein | ShipTrip/Views/Cruises/RouteStopCard.swift:127,145,160 | tests | A11y-Identifier interpoliert `port.name` — Seetage kollidieren |
| F06 | minor | nein | ShipTrip/Services/DemoDataService.swift:78 | correctness | Letzter direkter `Photo`-Delete am Vertrag vorbei |
| F07 | minor | nein | .winston-evidence/20260827T132014Z/gate-run.json | evidence | Leeres `build.log` (`-quiet`), `tool_versions` leer |

### F01 — `deletePhoto`-Bindung ohne Test
Von den vier geaenderten Loesch-Aufrufstellen ist nur `reconcileRoute`
(CruiseFormView.swift:87) rot-bewiesen getestet. CruiseDetailView.swift:423 ist
immerhin durch `testSammelblockFaengtEintragOhneStoppAuf` verhaltensmaessig
abgedeckt (Stopp loeschen → Eintrag ueberlebt im Sammelblock), der Bump selbst
aber nicht. `JournalDeletePaths.deletePhoto` an CruiseFormView.swift:792 hat
**keinen** Test. **Fix:** Testfall in `JournalDeletePathBindingTests` analog zu
`removingPortViaReconcileBumpsJournalEntries`: Foto an Eintrag haengen, Foto aus
`existingPhotos` entfernen, speichern, `#expect(entry.updatedAt > insert)`.

### F02 — Dateigroesse
`guard.py sizes` Exit 1: CruiseFormView 954 Zeilen, CruiseDetailView 595. Beide
**Bestand**, nicht durch diesen Diff erzeugt — CruiseDetailView schrumpft sogar
615 → 595 (ExpenseSorting ausgelagert), CruiseFormView waechst 950 → 954. Kein
neues Finding, aber CruiseFormView gehoert wie CruiseDetailView ins Backlog.

### F03 — Fehlende Expectation nach `tap()`
`kopfMorgen.tap()` → sofort `XCTAssertEqual(kopfMorgen.value as? String, …)`.
`value` ist ein Snapshot ohne Retry; eine langsamere Klapp-Animation flakt.
**Fix:** `XCTNSPredicateExpectation(format: "value == 'aufgeklappt'")` + `wait`.

### F04 — Label-Anker unter EN
`app.buttons["Löschen"]`, `["Neue Reise"]`, `["Hafen hinzufügen"]`,
`["Reisen"]`, `["Speichern"]` sowie die Werte `"aufgeklappt"`/`"zugeklappt"`
sind deutsche Wortlaute. Gerade T8d-2 macht den EN-Lauf erst moeglich; die Suite
wuerde dort komplett rot. **Fix:** `-AppleLanguages (de)` in `launchArguments`
festnageln (billig) oder die verbleibenden Anker auf Identifier ziehen.

### F05 — Identifier aus Nutzerdaten
`"routeStop.header.\(port.name)"` — alle Seetage heissen `"Seetag"`
(CruiseFormView.swift:96), mehrere Seetage erzeugen also identische Identifier.
Fuer VoiceOver harmlos, als Testanker mehrdeutig. **Fix:** `port.id.uuidString`
verwenden; die Tests greifen ohnehin ueber `BEGINSWITH`-Praedikat bzw. koennen
den Namen als Label-Filter behalten.

### F06 — Direkter `Photo`-Delete
`removeDemoCruisePhotos` loescht `cruise.photos` per `context.delete`. Aktuell
harmlos (DemoDataService erzeugt **keine** `JournalEntry`, verifiziert), aber
die einzige Stelle, die den J2a-Vertrag fuer `Photo` umgeht. **Fix:**
`JournalDeletePaths.deletePhoto(photo, in: context)`.

## Triage der vier Dev-Hinweise (Auftrag)
1. **Dynamic Type nur strukturell** — Backlog. Der `#Preview("Große Schrift")`
   mit `.accessibility3` ist ein legitimer struktureller Nachweis; ein
   Pixel-Beweis ist kein Go-Live-Kriterium.
2. **Edit-Test prueft Enthaltensein statt Reihenfolge** — akzeptiert, kein
   Backlog. Die Cursor-Position im `TextEditor` ist Systemverhalten; der Test
   sichert das eigentliche Risiko (Textverlust) korrekt ab.
3. **Leere Route ohne Erfassungs-Einstieg** — bestaetigt
   (RouteJournalSection.swift:44-46 zeigt nur den Hinweis, der Sammelblock
   erscheint nur bei vorhandenen Eintraegen). Echte Produkt-Luecke, aber mit
   trivialem Ausweg (Hafen anlegen). Backlog, kein Blocker.
4. **`umsetzungsplan-audit-2026-07.md:159` „Tagebuch-Strang"** — Doku-Altlast
   ausserhalb T8; `docs/features/journal.md` erklaert die Contract-Revision
   explizit. Backlog.

## Sonstiges (kein Finding)
`JournalMoodTests.unknownRawFallsBack` hat bei der Konsolidierung die
Case-Sensitivity-Assertion (`known(rawValue: "GREAT") == nil`) verloren; die
`""`- und `"ecstatic"`-Faelle sind erhalten. Vernachlaessigbar.
