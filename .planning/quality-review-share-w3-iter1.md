# Review — W3 Teilen-UI „Kreuzfahrt teilen"

- **Iteration**: 1 / 3
- **Reviewer**: quality-agent (statische Tiefen-Review, kein eigener Testlauf — Auftrag)
- **Datum**: 2026-08-25
- **Diff**: `c14a18a..0e0c662` (Worktree `ShipTrip-worktrees/w3-share-ui`)
- **Verdikt**: **approve — Go**
- **Stats**: critical: 0, major: 1, minor: 3 — **Blocker: 0**, Backlog: 4
- **evidence_path**: `/Users/andre-studio/Documents/0.Projekte/ShipTrip-worktrees/w3-share-ui/.winston-evidence/20260825T204058Z/gate-run.json`
- **Geladene Skills**: swift-standards, swiftui, code-review

## Summary

Der W3-Diff erfüllt C7, C8 und C9 vollständig und hält die Schreib-Allowlist exakt ein
(6 Dateien, keine App-Verdrahtung, keine Seed-Artefakte berührt). Die Teilen-Logik liegt
sauber ausgelagert in `CruiseShareAction.swift`; die Detailansicht bekommt nur einen
Menüeintrag und einen Modifier. Die beiden W1-Übergabepunkte (F06 Fehlerpräsentation,
F07 Temp-Hygiene) sind korrekt geschlossen. Der Roundtrip-Beweis für ZIEL-Kriterium 5
ist substanziell und kein Zähl-Theater. Es bleiben vier Nicht-Blocker fürs Backlog.

## Evidenz-Prüfung (Artefakt statt Prosa)

`gate-run.json` valide (schema_version 1, commit `0e0c662`, status `verified`), drei
Kommandos, **alle exit_code 0**, alle mit Log + SHA-256. Kommandos sind kanonisch
(`xcodebuild build-for-testing` / `test-without-building`), keine Weichspüler.
Log-Gegenprobe: `✔ Test run with 412 tests in 83 suites passed`, darin
`✔ Suite "Teilen: Ende-zu-Ende-Roundtrip (ZIEL-Kriterium 5)" passed`; UI-Log zeigt beide
`ReiseTeilenUITests`-Fälle `passed`.

**Verifikationslücke des Laufs (kein Finding, aber notiert):** Der Build lief mit
`SWIFT_EMIT_LOC_STRINGS=NO`, d. h. der Lauf hat *nicht* maschinell geprüft, dass die
Code-Literale exakt den Katalog-Keys entsprechen. Ich habe das ersatzweise per
Byte-Vergleich gegen `Localizable.xcstrings` getan — **alle 6 Keys stimmen exakt**,
inklusive des mehrzeiligen Nachrichtentexts mit `\`-Fortsetzung.

## Contract-Abgleich

| Kriterium | Ergebnis | Beleg |
|---|---|---|
| C7 Teilen-Aktion in Detailansicht | erfüllt | `CruiseDetailView.swift:76-84` (Toolbar-Menü `.primaryAction`) |
| C7 isDemo → nicht sichtbar | erfüllt, doppelt abgesichert | UI: `if !cruise.isDemo` umschließt den Button — der Eintrag wird gar nicht erst gebaut (`CruiseDetailView.swift:76`). Service: `guard !cruise.isDemo else { throw .demoCruise }` (`+ShareExport.swift:68`) |
| C7 Share-Items `[fileURL, text]` über Bestands-`ShareSheet` | erfüllt, Reihenfolge korrekt | `CruiseShareAction.swift:110` → `ShareSheet` aus `SettingsView.swift:1097` (unverändert wiederverwendet) |
| C7 Text enthält `shiptrip://import` | erfüllt | `CruiseShareAction.swift:70-77` |
| C7/F07 Temp-Hygiene: **Elternordner**, Erfolg wie Abbruch | erfüllt | `finish()` löscht `item.url.deletingLastPathComponent()` (`CruiseShareAction.swift:61`). Elternordner ist nachweislich der dedizierte `share-<UUID>`-Unterordner (`+ShareExport.swift:126-130`), **nicht** `temporaryDirectory` selbst — kein Kollateralschaden. `completionWithItemsHandler` feuert auch bei Abbruch/Swipe-Dismiss (`SettingsView.swift:1103`) |
| F06 Fehlerhülle „Teilen fehlgeschlagen: %@" | erfüllt | `CruiseShareAction.swift:46-48`; `String.LocalizationValue`-Interpolation eines `String` erzeugt `%@` → Key `Teilen fehlgeschlagen: %@` (im Katalog, DE/EN) |
| F06 `ExportError.missingMedia` nicht mehr als „Backup abgebrochen" | erfüllt, und die Behauptung „nur dieser Fall erreichbar" stimmt | `shareFailureReason` (`CruiseShareAction.swift:85-90`) mappt auf `ShareExportError.transcodeFailed`. Gegenprobe: `entryTooLarge`/`payloadTooLarge`/`archiveTooLarge` werden ausschließlich in `validateArchiveSize` (`+Export.swift:260-282`) geworfen, das der Share-Pfad nicht aufruft (er nutzt `validateShareArchiveSize`); `ZipArchiveStreamWriter` wirft kein `ExportError`. `missingMedia` entsteht in `imageSource.data(at:)` (`+Export.swift:108`) und ist damit der einzig erreichbare Fall |
| errorDescription-L10n type-aware, DE/EN | erfüllt | 3 Keys mit `%@` bzw. ohne Platzhalter, alle mit `"state": "translated"` EN |
| C8-Deckel: genau 6 neue Keys | erfüllt | Katalog-Diff enthält **nur** Additionen, exakt 6 Einträge; keine bestehende Entry verändert. Alert-Titel `"Info"` und `"OK"` sind Bestands-Keys (Katalog geprüft), erzeugen keinen 7. Key |
| C9 `cruiseDetail.shareButton` | erfüllt | `CruiseDetailView.swift:83`, im UI-Test als Query verwendet und grün |
| Allowlist | erfüllt | `git diff --stat`: exakt die 6 genannten Dateien. `+ShareExport.swift`-Diff = 3× `errorDescription` + der Doc-Kommentar, der genau diese Änderung erklärt — innerhalb der freigegebenen Ausnahme |

## Nebenläufigkeit / MainActor

`CruiseShareModel` ist `@MainActor @Observable final class` — korrekt für UI-State
(swift-standards §5). `share(_:)` startet einen unstrukturierten `Task`, der die
MainActor-Isolation erbt; `exportCruiseForSharing` ist auf dem ebenfalls MainActor-
isolierten `ExportImportService` (`ExportImportService.swift:28-30`), die eigentliche
ImageIO-Arbeit verlässt den Main-Thread über `Task.detached` im Service
(`+ShareExport.swift:210`). Aus der View blockiert also nichts: jeder `await` gibt den
MainActor frei.

Zustandsführung ist dicht: `guard !isPreparing, shareItem == nil` (Doppel-Tap-Riegel,
härter als das nur kosmetische `.disabled`), `defer { isPreparing = false }` läuft
**nach** dem Setzen von `shareItem`, sodass die Wiedereintritts-Sperre nahtlos vom
Flag auf das Sheet übergeht. Fehlerpfad lässt `shareItem == nil` → Retry möglich.
Keine Force-Unwraps, kein `@unchecked Sendable`, kein `DispatchQueue`.

## Test-Substanz

**Roundtrip (`ShareRoundtripTests.swift`) — trägt.** Frischer Container ist echt frisch:
`makeShareImportContainer()` erzeugt pro Aufruf einen eigenen `ModelContainer` mit
`isStoredInMemoryOnly: true` (`ShareImportFixtures.swift:21-28`), und die Leere wird vor
dem Import *bewiesen* (`:155-158`), nicht angenommen. Import läuft über
`importSharedCruise` (`:161`), also den echten Share-Einstieg mit Preflight — nicht über
den Backup-Pfad. Verglichen wird auf Feldebene: 11 Skalarfelder + 3 Zähler über
`CruiseSnapshot` als *eine* Gleichheitszusicherung (`:257-289`), Häfen inkl.
Koordinaten/`sortOrder`/`isSeaDay` (`:182-189`), Ausgaben als Menge + Summe (`:193-194`),
Fotos mit **echten Pixelmaßen** via `CGImageSourceCopyPropertiesAtIndex` (2600 px →
exakt 2048 px, `:197-206`), Fingerprint-Persistenz (`:179`), Nicht-Mitreisen von Deal und
Reederei-Overlay (`:209-212`) und Unversehrtheit des Senderbildes (`:215`). Der
Dedup-Fall ist substanziell (zweiter Import → `imported == 0`, `skippedDuplicates == 1`,
`versionConflict == false`, danach weiterhin genau 1 Reise mit 2 Fotos + 2 Häfen).

**UI-Tests — kein Immer-grün-Muster.** Der isDemo-Abwesenheitsbeweis ist echt zweistufig:
erst wird bewiesen, dass das Menü *offen* ist (`app.buttons["Bearbeiten"]`,
`ReiseTeilenUITests.swift:71-74`), dann die Abwesenheit geprüft (`:75-78`) — genau die
Falle, in die ein naives `XCTAssertFalse(...exists)` läuft, ist adressiert. Der
Positiv-Test legt eine echte Nicht-Demo-Reise über die UI an und wartet über
`XCTNSPredicateExpectation` (kein `sleep`) auf das Activity-Sheet mit zwei gleichwertigen
Ankern. Beide Tests würden bei entfernter Aktion rot.

## Findings

| ID | Severity | Blocker | File:Line | Kategorie | Titel |
|---|---|---|---|---|---|
| F01 | major | nein | `ShipTrip/Views/Cruises/CruiseShareAction.swift:85-90` | tests | Kein Unit-Test für die `missingMedia`→`transcodeFailed`-Abbildung (F06-Regressionsschutz) |
| F02 | minor | nein | `ShipTrip/Views/Cruises/CruiseShareAction.swift:36-52` | correctness | Export-`Task` ist an keine View-Lebensdauer gebunden → verwaister Temp-Ordner bei Navigation während des Exports |
| F03 | minor | nein | `ShipTrip/Views/Cruises/CruiseShareAction.swift:59-63` | tests | `finish()` (Temp-Hygiene F07) ist von keinem Test abgedeckt |
| F04 | minor | nein | `CruiseShareAction.swift:74,82` · `ReiseTeilenUITests.swift:37,42,52` | style | 5 Zeilen über 100 Zeichen |

### F01 — Kein Unit-Test für die Fehler-Abbildung
- **File**: `ShipTrip/Views/Cruises/CruiseShareAction.swift:85-90`
- **Severity**: major · **Blocker**: nein
- **Problem**: `shareFailureReason(for:)` ist die einzige Stelle, die verhindert, dass im
  Teilen-Kontext der Wortlaut „Backup abgebrochen: …" erscheint (W1-Übergabepunkt F06).
  Die Funktion ist rein, `static`, ohne Abhängigkeiten — also trivial testbar — und hat
  null Abdeckung. Eine Regression (jemand entfernt den `if case`, weil er „redundant"
  aussieht) fällt heute durch alle 412 Tests und beide UI-Tests durch.
- **Warum kein Blocker**: Das Verhalten ist statisch verifiziert (siehe Contract-Abgleich
  oben), der Schaden wäre rein kosmetisch (irreführender Text), kein Datenverlust, kein
  Sicherheitsrisiko.
- **Fix**: eine `@Test`-Funktion in `ShipTripTests`:
  ```swift
  @Test("Der Teilen-Alert nennt nie den Backup-Wortlaut")
  @MainActor func missingMediaWirdAufDieShareFormulierungAbgebildet() {
      let text = CruiseShareModel.shareFailureReason(
          for: ExportError.missingMedia(entryName: "images/x/0")
      )
      #expect(text.contains("images/x/0"))
      #expect(!text.contains("Backup"))
      #expect(text == ShareExportError.transcodeFailed(entryName: "images/x/0").localizedDescription)
  }
  ```

### F02 — Export-Task überlebt die Ansicht
- **File**: `ShipTrip/Views/Cruises/CruiseShareAction.swift:36-52`
- **Severity**: minor · **Blocker**: nein
- **Problem**: Der `Task` in `share(_:)` ist unstrukturiert und hängt an keinem
  `.task`-Modifier. Verlässt der Nutzer die Detailansicht, während der Export läuft
  (bei vielen Fotos durchaus Sekunden), läuft der Export zu Ende und setzt `shareItem`
  an einem Model, dessen Präsentation nicht mehr hängt → `finish()` feuert nie → der
  `share-<UUID>`-Ordner bleibt liegen.
- **Warum kein Blocker**: Der Ordner liegt unter `NSTemporaryDirectory()`, das iOS
  selbst räumt; kein Datenverlust, keine Nutzersichtbarkeit, kein Leak über einen
  App-Neustart hinaus. Der Fall setzt zudem Navigation *während* des Exports voraus.
- **Fix**: Task-Handle halten und beim Verschwinden abräumen —
  `private var exportTask: Task<Void, Never>?` in `CruiseShareModel`, in
  `CruiseSharePresentation.body` ein `.onDisappear { model.cancelPending() }`, wobei
  `cancelPending()` den Task cancelt und ein bereits erzeugtes `shareItem` über
  `finish()` aufräumt. Die vorhandenen `try Task.checkCancellation()`-Punkte im Service
  (`+ShareExport.swift:108,141`) greifen dann bereits.

### F03 — `finish()` ohne Testabdeckung
- **File**: `ShipTrip/Views/Cruises/CruiseShareAction.swift:59-63`
- **Severity**: minor · **Blocker**: nein
- **Problem**: Die Temp-Hygiene (F07) ist drei Zeilen, aber sie ist der Unterschied
  zwischen „Ordner weg" und „Ordner bleibt". Der UI-Test kann das Dateisystem nicht
  beobachten, ein Unit-Test schon.
- **Fix**: Test, der einen Ordner mit Datei anlegt, `shareItem` darauf setzt, `finish()`
  ruft und `FileManager.default.fileExists(atPath: dir.path) == false` prüft. Setzt
  voraus, dass `shareItem` von außen setzbar bleibt (ist es, `var`).

### F04 — Zeilenbreite
- **File**: `CruiseShareAction.swift:74` (103), `:82` (102); `ReiseTeilenUITests.swift:37` (101), `:42` (101), `:52` (101)
- **Severity**: minor · **Blocker**: nein
- **Problem**: swift-standards-Limit ist 100 Zeichen. `:74` ist Inhalt des lokalisierten
  Nachrichtentexts (eine weitere `\`-Fortsetzung würde den Key ändern — Katalog
  mitziehen), der Rest sind Kommentare/Assert-Meldungen.
- **Fix**: Kommentare und Assert-Meldungen umbrechen; die Literal-Zeile in Ruhe lassen
  oder Key + Katalog gemeinsam anpassen.

## Statischer Pass

`guard.py sizes` über die 5 geänderten Swift-Dateien:

```
FAIL  ShipTrip/Views/Cruises/CruiseDetailView.swift: 679 Zeilen (> 500 hart)
sizes: 1 Datei(en) ueber Hard-Limit — major-Finding (mehrere: critical)
```

**Keine Dublette, kein neues Finding**: Die Überschreitung ist vorbestehend (W3 fügt
netto +15 Zeilen hinzu und hat die Teilen-Logik bereits in eine eigene Datei
ausgelagert) und steht bereits als `.planning/BACKLOG.md:152`. Die vier neuen Dateien
liegen alle deutlich unter dem Limit (max. 290 Zeilen), keine Funktion über 50 Zeilen.

## Nicht ausgelöste Prüfungen

- **GDPR**: keine neue Datenverarbeitung. Das Teilen ist nutzerinitiiert, geht über das
  System-Share-Sheet, und die Metadaten-Entfernung (inkl. GPS) sitzt in W1s
  `ShareImageTranscoder` — von W3 unberührt. Kein Trigger.
- **Security**: keine neue Angriffsfläche in W3. Der eingehende Pfad (Preflight,
  Limits, Zip-Härtung) ist W2; W3 schreibt nur ausgehend in ein frisches Temp-Verzeichnis
  mit UUID-Namen. Kein Trigger.

## Backlog-Zeilen (bitte übernehmen — ich schreibe laut Auftrag nur diese Datei)

```
- [major] ShipTrip/Views/Cruises/CruiseShareAction.swift:85 — kein Unit-Test für shareFailureReason (missingMedia→transcodeFailed, F06-Regressionsschutz)
- [minor] ShipTrip/Views/Cruises/CruiseShareAction.swift:40 — Export-Task an keine View-Lebensdauer gebunden; verwaister Temp-Ordner bei Navigation während des Exports
- [minor] ShipTrip/Views/Cruises/CruiseShareAction.swift:59 — finish() (Temp-Hygiene F07) ohne Testabdeckung
- [minor] ShipTrip/Views/Cruises/CruiseShareAction.swift:74 — 5 Zeilen über 100 Zeichen (auch ReiseTeilenUITests.swift:37,42,52)
```

## Verdikt

**Go.** Keine offenen Blocker, kein critical. C7/C8/C9 erfüllt, beide W1-Übergabepunkte
geschlossen, Allowlist eingehalten, ZIEL-Kriterium 5 durch einen Roundtrip belegt, der
tatsächlich auf Feldebene und auf Pixelmaßen prüft. Die vier Findings sind
Härtungs-/Abdeckungsarbeit und gehören ins Backlog, nicht in eine weitere Iteration.
