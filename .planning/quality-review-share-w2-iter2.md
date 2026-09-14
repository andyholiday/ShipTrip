# Review — Feature „Kreuzfahrt teilen", W2 Import-Flow (Fix-Runde 3)

- **Iteration**: 2 / 3 (Re-Review nach Codex-Gate #2; Codex-Ersatz-Spawn)
- **Reviewer**: quality-agent (statisch, kein Build/Testlauf — Build-Token liegt beim parallelen Test-Build-Spawn)
- **Datum**: 2026-08-25
- **Diff**: `21fe5fe..763b71f` (089a43b = Tests/Rot-Beweis, 763b71f = Fix)
- **Worktree**: `/Users/andre-studio/Documents/0.Projekte/ShipTrip-worktrees/w2-share-import`
- **Verdikt**: **approve / Go** — unter Vorbehalt des grünen Laufs beim parallelen Test-Build-Spawn
- **Stats**: critical: 0, major: 0 (neu), minor: 3 — Blocker: 0, Backlog: 3 (+1 vorbestehend, bereits gelistet)

## Summary

Alle drei Codex-Findings (B1, B2, M1) sind behoben, contract-treu nach Rev. 5
und ohne erkennbare Kollateralschäden. Der Fix verschiebt die
Fingerabdruck-Persistenz vom Wrapper in den Import-Kern und macht damit die
C1-Zusage „empfänger-persistiert in JEDEM Einstiegspfad" strukturell wahr statt
pfad-lokal. Der Rot-Beweis ist substanziell: genau die vier neuen Tests waren
rot, 22 von 26 grün — kein Blindschuss. Bemerkenswert sauber: der Test-Commit
089a43b hat `usesZipContainer` **verhaltensgleich** (`== "zip"`) extrahiert,
erst 763b71f hat sie geweitet — der Rot-Beweis der Extraktions-Naht ist damit
echt und nicht durch die Extraktion selbst erzeugt.

## Findings-Status B1 / B2 / M1

| ID | Befund (Codex Gate #2) | Behoben | Beleg |
|----|------------------------|---------|-------|
| B1 | manueller `.shiptrip`-Import landet im JSON-Importer | **ja** | `SettingsView.swift:800-802` + `:992` |
| B2 | Fingerprint nur im Wrapper, nach Save, `try?`-verschluckt | **ja** | `ExportImportService+Import.swift:157-159`; Alt-Block in `+ShareImport.swift` entfernt |
| M1 | ungültige Cruise-UUID passiert Preflight | **ja** | `ExportImportService+ShareImport.swift:178-180` |

### B1 — Code-Trace des manuellen Pfads

`ShipTrip-Info.plist:20-25` deklariert `public.filename-extension = shiptrip`
für `com.andre.shiptrip.cruise`; `SettingsView.swift:930` nimmt
`.shipTripCruise` in `allowedContentTypes` — die Datei ist im Picker also
wählbar. Vorher entschied `url.pathExtension.lowercased() == "zip"` → `false`
→ `importFromJSON` (Base64-Legacy) → ZIP-Bytes im JSON-Decoder, Import scheitert.
Jetzt: `Self.usesZipContainer(url)` (`:992`) → `["zip","shiptrip"].contains(...)`
(`:802`) → `true` → `importFromZip` (`:1002`) → `importFromJSONData` →
`SharePreflight.validateArchive` (`+Import.swift:75`) vor jeder Mutation.
Semantik entscheidet weiterhin allein der `share`-Block (C1/C6, Rev. 5 (3)) —
die Endung steuert nur den Container-Leser. **`.zip`-Backups verhaltensgleich:**
für `pathExtension == "zip"` liefert die neue Funktion identisch `true`; für
`.json` identisch `false`. Kein weiterer Endungs-Dispatcher im Produktivcode
betroffen — `IncomingLinkRouter.swift:39` (Share-Einstieg, verlangt weiterhin
strikt `.shiptrip`) bleibt unberührt.

### B2 — Fingerprint vor dem atomaren Save, in jedem Einstiegspfad

Gesetzt wird an der frisch angelegten Cruise (`+Import.swift:157-159`), also
**nach** dem Duplikat-`continue` (`:130-133`) und **vor** dem einen
`modelContext.save()` (`:280`) samt Rollback-Zweig (`:284-285`). Fehler
propagieren jetzt (`throw error`, `:285`) statt in `try?` zu verschwinden; der
Nachtrags-Save im Wrapper ist ersatzlos entfallen. Vollständigkeit der Pfade
per Aufrufer-Enumeration verifiziert — es gibt genau zwei Einstiege, beide
laufen durch den Kern:
`SettingsView.swift:1002/1007` (manuell, ZIP **und** Legacy-JSON) und
`ShareImportCoordinator.swift:79 → importSharedCruise → +ShareImport.swift:277`.
Kein dritter Aufrufer, kein zweiter Parser.
`grep shareContentFingerprint` bestätigt genau **eine** Schreibstelle
(`+Import.swift:158`) und eine Lesestelle (`+ShareImport.swift:268`).
**Kein Pfad ohne Fingerprint:** `ExportShareInfo.contentFingerprint` ist
nicht-optional (`ExportImportDTOs.swift:110`) — existiert ein `share`-Block, ist
der Wert da. **Kein Fingerprint zu viel:** ohne `share`-Block bleibt das Feld
`nil` (Backup-Semantik), und `validateArchive` erzwingt für Share-Archive genau
1 Cruise — ein Fingerprint kann konstruktiv nie auf mehrere Reisen gestempelt
werden.
**Konflikt-Vergleich unverändert korrekt:** `+ShareImport.swift:265-272` läuft
weiterhin **vor** dem Kern-Aufruf (`:277`), liest also den Vor-Import-Zustand
und vergleicht ausschließlich persistierte Werte gegen den Datei-Wert (C1).
Auch das Duplikat-Verhalten ist identisch zu vorher: alt war der Schreibvorgang
an `base.imported > 0` gebunden, neu am `continue` — ein Duplikat bleibt in
beiden Fassungen unangetastet (kein Merge, kein Überschreiben).

### M1 — UUID-Guard wirkt per Konstruktion in beiden Schichten

Der Guard (`+ShareImport.swift:178-180`) steht in `validateArchive`, nicht in
einer der beiden Aufrufhüllen. Nachvollzogen statt geglaubt:
Stufe A ruft `validateArchive` in `extractAndValidate` (`:136`), der
Import-Kern ruft dieselbe `static`-Funktion (`+Import.swift:75`) — eine
Definition, zwei Aufrufstellen, keine Kopie. Im Kern steht der Aufruf vor jedem
`insert`, die Nicht-Mutation ist also strukturell und nicht nur getestet.
Der Guard ist zudem die Voraussetzung für B2: ohne gültige UUID würde
`+Import.swift:143-146` die Datei-ID nicht übernehmen und die spätere
Konflikterkennung liefe ins Leere.

## Test-Substanz (Rot-Beweis gegengelesen)

Evidenz `\.winston-evidence/20260825T201447Z/gate-run.json` — `status: failed`,
`exit_code: 65`, `commit: 089a43b`. `log_sha256` nachgerechnet und **identisch**
(`523bf4ef…c23e`), das Artefakt ist unverfälscht. Der Lauf zeigt
„26 tests in 3 suites failed … with 8 issues" — rot waren **genau die vier
neuen** Tests, die übrigen 22 grün:

| Test | rot am Ist-Stand | prüft |
|------|------------------|-------|
| `invalidCruiseIDIsRejected` | ja (2 issues) | M1, Archiv-Ebene, inkl. Leerstring |
| `invalidCruiseIDIsRejectedInBothLayers` | ja (3 issues) | M1 in Stufe A **und** Kern + Nicht-Mutation |
| `manualPickerRoutesShareFileThroughZipReader` | ja (2 issues) | B1-Zuordnung, inkl. `.SHIPTRIP` und `.json`-Negativfall |
| `manualZipImportPersistsFingerprint` | ja (1 issue) | B1+B2 zusammen: echter `importFromZip`-Lauf, Fingerprint am Objekt |

Kein Weichspüler: `manualZipImportPersistsFingerprint` fährt den realen
`importFromZip` über eine echte, geschriebene `.shiptrip`-ZIP-Datei
(`writeShareFile` → `ZipArchiveWriter.build`) und liest das Ergebnis aus dem
`ModelContext` — kein Mock, kein Interna-Assert.
`backupImportLeavesFingerprintEmpty` war erwartungsgemäß schon vorher grün: es
ist kein Defekt-Beweis, sondern die **Nicht-Regressions-Sicherung** des
Backup-Pfads gegen genau die neue Kern-Schreibstelle — richtig eingeordnet.

## Kollateralschäden / Allowlist

- `ExportImportService.swift` **unberührt** (Diff: nur `+Import.swift`,
  `+ShareImport.swift`, `SettingsView.swift`, 3 Testdateien).
- Seed-Artefakte (C0) unberührt; die Änderung an `+Import.swift` ist durch
  Rev. 5 (1) ausdrücklich zugelassen, die an `SettingsView.swift` durch
  Rev. 5 (3).
- Keine Orphans: `fileFingerprint` (`:260`) und `sharedCruiseID` (`:261`)
  werden von der Konfliktberechnung weiter gebraucht, `existingCruise` (`:284`)
  hat mit `:267` weiterhin einen Aufrufer.
- Kommentare wurden am Fix-Ort aktualisiert statt stehengelassen — der
  Kommentar an `+ShareImport.swift:274-276` beschreibt jetzt korrekt, wer
  persistiert.

## Neue Findings (alle Nicht-Blocker → Backlog)

| ID | Severity | Blocker | File:Line | Titel |
|-----|----------|---------|-----------|-------|
| F01 | minor | nein | `ShipTrip/Views/Settings/SettingsView.swift:1012-1026` | Manueller `.shiptrip`-Import zeigt keinen Versionskonflikt-Hinweis |
| F02 | minor | nein | `ShipTrip/Services/ExportImportService+ShareImport.swift:78-95` | Transport-Limits greifen auf dem manuellen Pfad nicht |
| F03 | minor | nein | `ShipTripTests/ShareImportPreflightTests.swift:257-268` | B1-Test prüft die Funktion, nicht die Verdrahtung |

### F01 — Manueller `.shiptrip`-Import zeigt keinen Versionskonflikt-Hinweis
`versionConflict` entsteht nur in `importSharedCruise`. Wer dieselbe geteilte
Reise in zweiter Senderfassung über den Datei-Picker öffnet, sieht künftig
„· 1 Duplikate übersprungen" statt des C8-Hinweises. **Contract-konform** —
C6 sagt ausdrücklich „`SettingsView` selbst braucht keine Share-Logik", und der
Hinweis hängt am `ShareImportCoordinator`. Erst durch B1 ist dieser Pfad
überhaupt erreichbar geworden, deshalb erwähnenswert. Kein Datenverlust, kein
Merge — reine UX-Lücke. Fix (später): `handleImport` bei `share`-Block auf
`importSharedCruise` umleiten, oder bewusst als Grenze dokumentieren.

### F02 — Transport-Limits greifen auf dem manuellen Pfad nicht
Stufe A (`maxArchiveFileSize`, `maxPayloadSize`, `maxDataJSONSize`) läuft nur am
Share-Einstieg. Der manuelle Pfad ist durch die `ZipArchiveReader`-Härtung
(Zip-Slip, CRC, Entry-/Archiv-Limit) und die C10-Zählgrenzen aus
`validateArchive` gedeckt, nicht durch die Share-Transportdeckel. Das ist die
**bewusste** Contract-Aufteilung (C10: Stufe A = Share-Einstieg, Archiv-Preflight
= jeder Pfad) und gegenüber vorher keine Verschlechterung — vorher las
`importFromJSON` die Datei ohnehin vollständig in `Data`. Nur als bekannte
Asymmetrie festhalten.

### F03 — B1-Test prüft die Funktion, nicht die Verdrahtung
`manualPickerRoutesShareFileThroughZipReader` assertet auf `usesZipContainer`,
nicht darauf, dass `handleImport` sie benutzt. Die Verdrahtung ist hier nur
statisch belegt (einzige Aufrufstelle `SettingsView.swift:992`). In einer
`fileImporter`-Closure ohne Testnaht ist das der pragmatisch richtige Schnitt,
und `manualZipImportPersistsFingerprint` deckt die Zielseite end-to-end ab —
deshalb minor, kein Fix-Auftrag.

## Vorbestehend, bereits im Backlog — kein neuer Eintrag

`guard.py sizes` (exit 1): `ShipTrip/Views/Settings/SettingsView.swift`
**1115 Zeilen > 500 (hart)**. Vorbestehend (vor dem Diff 1105), der Diff fügt
10 Zeilen hinzu. Bereits zweifach in `.planning/BACKLOG.md` gelistet (F10 sowie
der 1010-Zeilen-Eintrag) — kein Blocker, keine Dublette angelegt. Die übrigen
fünf geänderten Dateien sind unauffällig.

## Go / No-Go

**Go** — keine offenen Blocker. Vorbehalt: der Verdikt-Anspruch „grün" ist
statisch nicht einlösbar; der Grün-Lauf desselben `-only-testing`-Umfangs
(`ShareImportResultTests`, `ShareArchivePreflightTests`,
`ShareImportEntryPathTests`) auf `763b71f` muss aus dem parallelen
Test-Build-Spawn als `gate-run.json` mit `status: passed` vorliegen, bevor
gemerged wird. Bleibt dort etwas rot, kippt dieses Go.
