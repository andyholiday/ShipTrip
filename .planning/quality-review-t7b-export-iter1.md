# Review — T7b: Journal + Captions in ZIP-Export und .shiptrip-Teilen

- **Iteration**: 1 / 3
- **Reviewer**: quality-agent (frischer Spawn)
- **Datum**: 2026-08-27
- **Branch**: feature/journal-export @ d411b79 · Diff-Basis release/1.8.5 (d8ce9bb)
- **Verdikt**: approve (Go fuer Merge auf release/1.8.5)
- **Stats**: critical: 0, major: 0, minor: 4 — Blocker: 0, Backlog: 4
- **Geladene Skills**: code-review, swift-standards, swiftdata, xctest-ios

## Test-Run-Status

- `evidence_path`: `/Users/andre-studio/Documents/0.Projekte/ShipTrip-worktrees/t7b-journal-export/.winston-evidence/20260827T114116Z/gate-run.json`
- status: `verified` · status_claim: `runtime-verifiziert`
- Gates: `build` (xcodebuild build-for-testing) exit 0 · `tests` (xcodebuild test-without-building, -only-testing:ShipTripTests) exit 0
- Aus dem xcresult (nicht aus stdout): **474 Tests / 485 Test-Runs, 0 failed, 0 skipped, result Passed** — Device ci-t7b (iPhone 17, iOS 26.5, Wegwerf-Klon).
- Statischer Pass: `guard.py sizes --files <10 geaenderte Dateien>` → `ok (10 geprueft, 0 Soft-Warnungen)`.
- Test-Diff 462 Zeilen vs. Code-Diff 208 Zeilen (2,2x). Bei einem Format-Kompatibilitaets-Contract begruendet: der Grossteil sind die 1.8.0-Golden-Fixtures als JSON-Literal, nicht Assertion-Masse.

## Antworten auf die Pruefungsfragen

### 1. Contract-Abweichung (optionale DTO-Felder) — konsistent, Fingerprint stabil

Encode-Pfad: `ExportCruise.journalEntries: [ExportJournalEntry]? = nil` und
`ExportPhoto.caption: String?` haben beide **synthetisiertes** `encode(to:)` →
`encodeIfPresent` → der Schluessel fehlt im Output, wenn nil.
`buildExportJournalEntries` gibt bei leerem Journal explizit `nil` zurueck
(ExportImportService.swift:216), `exportCaption` mappt `""` → `nil`
(ExportImportService+Export.swift:301).

Decode-Pfad: `journalEntries` per synthetisiertem `decodeIfPresent`, im Import
materialisiert als `?? []` (ExportImportService+Import.swift:291). `caption` per
explizitem `decodeIfPresent` im handgeschriebenen `init(from:)`
(ExportImportDTOs.swift:223), inkl. Legacy-Single-Value-Zweig (1.7-Format,
caption = nil, Zeile 217); Import materialisiert `?? ""`
(ExportImportService+Import.swift:248).

Beide Tueren: die neuen Felder sitzen im **gemeinsamen** `buildExportCruises`
bzw. `buildArchive`-Kern; ZIP (+Export.swift:147, :209) und Share
(+ShareExport.swift:172) uebergeben denselben `photoEncoder`-Vertrag, der Import
laeuft fuer beide durch `importFromJSONData`. Keine Asymmetrie gefunden.

Fingerprint: `ShareFingerprint.contentFingerprint` hasht `JSONEncoder` mit
`.sortedKeys` ueber genau dieses `ExportCruise` — fehlt der Schluessel, ist der
Byte-Strom identisch zu 1.8.0, also auch der Hash. Zusaetzlich ist die
Journal-Reihenfolge im Export deterministisch sortiert (entryDate, createdAt,
id) statt SwiftData-Beziehungsreihenfolge — genau richtig fuer einen Hash ueber
das Encoding.

**Beweislage der Legacy-Tests:** `JournalExportLegacyCompatibilityTests` beweist
(a) Decodierbarkeit beider Tueren aus einem echten 1.8.0-Envelope und (b) per
`exportWithoutJournalOmitsNewKeys` die **Schluessel-Abwesenheit**
(`!json.contains("journalEntries")`, `!json.contains("caption")`). Das ist
**keine** Byte-Identitaet gegen eine Golden-Datei und **kein** gepinnter
Golden-Fingerprint — aber bei `.sortedKeys` und ansonsten unveraenderten Feldern
ein tragfaehiger Proxy: kein neuer Schluessel ⇒ gleicher Byte-Strom. Die direkte
Probe fehlt trotzdem → F01 (Backlog).

### 2. `maxJournalEntries = 1000` — beidseitig durchgesetzt, kein stiller Drop

Export: `+ShareExport.swift:82` guardet `cruise.journalEntries.count` und wirft
`ShareExportError.limitExceeded` **vor** dem DTO-Bau.
Import: `SharePreflight.validateArchive` (+ShareImport.swift:199-203) wirft
`ShareImportError.limitExceeded`. Beides Fehler, kein Truncate, kein stiller
Drop — **kein Datenverlust-Risiko, kein Blocker**. Test
`preflightRejectsTooManyJournalEntries` prueft n+1 (wirft) **und** die
Gegenprobe genau an der Grenze (geht durch).
Die ZIP-Backup-Tuer kennt das Limit nicht — konsistent mit `maxPhotos` /
`maxExpenses`, die ebenfalls share-only sind. Bewusst, kein Finding.

### 3. isDemo-Filter — greift

`ExportImportService.swift:63` filtert `cruises.filter { !$0.isDemo }` im
gemeinsamen Archiv-Bau; Journal-Eintraege und Captions sind Kinder der Reise und
fallen mit ihr weg. `JournalEntry` traegt bewusst kein eigenes `isDemo`
(dokumentiert im Modell). Test `demoCruiseWithJournalIsFilteredOut` belegt es
mit Journal-Nutzlast.

### 4. Roundtrip — verlustfrei, beide Formate abgedeckt

`zipRoundtripPreservesJournal` und `shareRoundtripPreservesJournal` fahren
dasselbe Fixture (Seetag-Eintrag ohne Hafen, zweiter Eintrag am selben Tag mit
Hafen + Foto, Folgetag mit unbekanntem `moodRaw`) durch beide Tueren und pruefen
gegen dieselbe Assertion-Funktion: Text, Hafenbezug, Foto-Anhang, Caption,
Stimmung verbatim, Tag-Kanonisierung auf 12:00 UTC, Foto bleibt Reise-Kind.
Der ZIP-Fall prueft zusaetzlich LWW-Stabilitaet (`updatedAt` < 2 ms Drift).
Randfaelle separat: Import-Normalisierung eines unnormalisierten `entryDate`,
stilles Verwerfen unaufloesbarer Hafen-/Foto-IDs. Coverage auf dem Diff ist
vollstaendig.

### 5. Swift 6 / SwiftData — sauber

Keine Force-Unwraps im Produktivcode des Diffs (der Share-Export haelt seinen
`guard` sogar explizit statt eines Force-Unwrap). Keine `@Model`-Objekte ueber
Aktorgrenzen: der Journal-Import laeuft synchron im selben `ModelContext` wie
der uebrige Import-Kern; die einzige Aktorgrenze im Share-Export (Transcode-
Spool) beruehrt nur `Data`, nicht die neuen Pfade. Build unter Swift 6 strict
concurrency ohne Warnung (Gate `build` exit 0). Schreibpfade gehen ueber die
J2a-Setter (`setEntryDate(normalizingImported:)`, `setPort`, `attach`), nur
`photo.caption` und die LWW-Zeitstempel werden direkt gesetzt — mit Begruendung
am Ort (frisches Objekt, Datei-Fassung 1:1).

## Findings

| ID  | Severity | Blocker | File:Line | Kategorie | Titel |
|-----|----------|---------|-----------|-----------|-------|
| F01 | minor | nein | ShipTripTests/JournalExportLegacyCompatibilityTests.swift:158-176 | tests | Fingerprint-Stabilitaet nur indirekt bewiesen |
| F02 | minor | nein | ShipTrip/Services/ExportImportService+JournalImport.swift:52 | robustness | `entryDate` ohne Millisekunden faellt still unter den Tisch |
| F03 | minor | nein | ShipTrip/Services/ExportImportService+JournalImport.swift:69-70 | robustness | `updatedAt < createdAt` moeglich, wenn nur `createdAt` unparsbar ist |
| F04 | minor | nein | ShipTripTests/JournalExportLegacyCompatibilityTests.swift:18 | style | Force-Unwrap im Test-Fixture |

### F01 — Fingerprint-Stabilitaet nur indirekt bewiesen
- **File**: `ShipTripTests/JournalExportLegacyCompatibilityTests.swift:158-176`
- **Problem**: `exportWithoutJournalOmitsNewKeys` prueft Schluessel-Abwesenheit im
  Backup-JSON. Die eigentliche Release-Zusage ist aber „der `contentFingerprint`
  einer journallosen Reise ist derselbe wie unter 1.8.0" — die wird nirgends
  direkt geprueft. Bricht jemand spaeter die `encodeIfPresent`-Synthese (z. B.
  durch ein handgeschriebenes `encode(to:)` in `ExportCruise`), faellt es hier
  nicht auf.
- **Fix**: Ein Test, der den 64-stelligen Hex-Fingerprint einer journal- und
  captionlosen Fixture-Reise gegen einen gepinnten Golden-Wert prueft
  (`#expect(try ShareFingerprint.contentFingerprint(for: shared) == "<hex>")`).
- **Backlog**: `- [minor] ShipTripTests/JournalExportLegacyCompatibilityTests.swift:158 — Golden-Fingerprint fuer journallose Reise pinnen`

### F02 — `entryDate` ohne Millisekunden faellt still unter den Tisch
- **File**: `ShipTrip/Services/ExportImportService+JournalImport.swift:52`
- **Problem**: `isoFormatter` ist mit `[.withInternetDateTime, .withFractionalSeconds]`
  konfiguriert (ExportImportService.swift:51) und parst `"2026-05-03T12:00:00Z"`
  (ohne Millisekunden) **nicht**. Der `guard ... else { continue }` verwirft
  solche Eintraege still, ohne `skippedInvalid` zu erhoehen — der Nutzer sieht
  „importiert: 1", das Journal ist aber leer.
- **Warum kein Blocker**: eigene Dateien schreiben immer fraktionale Sekunden;
  betroffen sind nur hand-editierte oder fremd erzeugte Dateien. Kein Verlust
  von Nutzerdaten am eigenen Bestand.
- **Fix**: Fallback-Parse mit `[.withInternetDateTime]` versuchen, bevor
  verworfen wird — oder den Verwurf wenigstens in `skippedInvalid` zaehlen.
- **Backlog**: `- [minor] ShipTrip/Services/ExportImportService+JournalImport.swift:52 — entryDate ohne Millisekunden wird still verworfen`

### F03 — `updatedAt < createdAt` moeglich
- **File**: `ShipTrip/Services/ExportImportService+JournalImport.swift:69-70`
- **Problem**: Ist `createdAt` unparsbar, `updatedAt` aber parsbar, bleibt
  `entry.createdAt` auf „jetzt" (Init-Wert) und `entry.updatedAt` uebernimmt den
  aelteren Datei-Wert → invariantenverletzendes Paar, das der spaetere
  LWW-Merge falsch gewichtet.
- **Fix**: `entry.updatedAt = max(entry.createdAt, updatedAt ?? entry.createdAt)`.
- **Backlog**: `- [minor] ShipTrip/Services/ExportImportService+JournalImport.swift:69 — updatedAt kann unter createdAt rutschen`

### F04 — Force-Unwrap im Test-Fixture
- **File**: `ShipTripTests/JournalExportLegacyCompatibilityTests.swift:18`
- **Problem**: `Data(base64Encoded: ...)!` auf Dateiebene. Kommentiert und
  ueber einem Literal, also unkritisch — aber die Projektregel „keine
  Force-Unwraps" kennt keine Test-Ausnahme.
- **Fix**: `Data(base64Encoded:) ?? Data()` mit `#expect(!journalFixturePNG.isEmpty)`
  in einem Setup-Test, oder die Ausnahme nach CLAUDE.md-Regel taggen.
- **Backlog**: `- [minor] ShipTripTests/JournalExportLegacyCompatibilityTests.swift:18 — Force-Unwrap im Fixture`

## Verdikt

**Go.** Keine offenen Blocker, keine critical/major Findings. Volle Unit-Suite
runtime-verifiziert gruen (474/474, 485 Runs), Size-Guard sauber, Contract in
beiden Tueren symmetrisch umgesetzt, Fingerprint-Stabilitaet strukturell
gesichert. Die vier Minor-Findings gehoeren ins BACKLOG (Winston traegt ein) und
blockieren den Merge auf release/1.8.5 nicht.
