# Review — W0 Naht-Seed „Kreuzfahrt teilen"

- **Iteration**: 1 / 3
- **Reviewer**: quality-agent (frischer Spawn)
- **Datum**: 2026-08-25
- **Basis**: `release/1.8.0...feature/share-seed` @ `d8f54d2`
  (Worktree `/Users/andre-studio/Documents/0.Projekte/ShipTrip-worktrees/w0-share-seed`)
- **Soll**: Contract C0 Rev. 4 (`docs/architecture/contracts/share-cruise-contracts.md`),
  Detailwerte aus C1, C2, C3, C10
- **Geladene Skills**: swift-standards, code-review
- **Verdikt**: **approve / Go**
- **Stats**: critical: 0, major: 0, minor: 2 — Blocker: 0, Backlog: 2

## Summary

Der Diff umfasst exakt sechs Dateien und keine Zeile darüber hinaus. Alle sechs
C0-Artefakte sind vorhanden und contract-konform, inklusive der Rev.-4-Konstante
`ExportShareInfo.currentShareFormatVersion = 1`. Die abschließende Aufzählung ist
eingehalten: keine W1-/W2-Symbole (`ShareExportError`, `ShareImportError`,
`SharePreflight`, `ShareImportCoordinator`, `IncomingLinkRouter`,
`ShareImageTranscoder`, `Cruise.shareContentFingerprint` — alle abwesend), keine
Tests, keine neuen String-Katalog-Keys. Der Build ist grün (Exit 0), der
Größen-Guard sauber. Beide Findings sind kosmetisch und blockieren den Go-Live nicht.

## Verifikation

| Gate | Ergebnis |
|---|---|
| `xcodebuild build -scheme ShipTrip -destination 'generic/platform=iOS Simulator'` | **Exit 0** |
| `guard.py sizes` (5 geänderte Swift-Dateien) | ok — 5 geprüft, 0 Soft-Warnungen |
| `xcodebuild clean` nach dem Lauf | ausgeführt (Exit 0) |

`evidence_path`:
`/Users/andre-studio/Documents/0.Projekte/ShipTrip-worktrees/w0-share-seed/.winston-evidence/20260825T191626Z/gate-run.json`
(`status: verified`, `gates.build: 0`)

Testumfang nach der Leiter: C0 deckelt hart auf „keine Tests außer kompiliert" —
Roundtrip-/Regressionstests sind vertraglich W1/W2. Fehlende Tests sind hier
deshalb kein Finding. Genau ein Build als verifizierende Runde, kein Simulator.

## Contract-Abgleich C0 (Soll ⇄ Ist)

| # | C0-Artefakt | Soll | Ist | Status |
|---|---|---|---|---|
| 1 | `UTType+ShipTrip.swift` | `UTType(exportedAs: "com.andre.shiptrip.cruise")` | Zeile 16, identisch; Default `conformingTo: .data` deckt sich mit der Plist-Deklaration | ✅ |
| 2 | `ShipTrip-Info.plist` | UTExportedTypeDeclarations + CFBundleDocumentTypes (C2) + CFBundleURLTypes (C3) | alle drei vorhanden, Details unten | ✅ |
| 3 | `ShareArchiveLimits.swift` | 6 Konstanten aus C10, keine Logik | 6/6 exakt, reines `enum` mit `static let` | ✅ |
| 4 | `ShareFingerprint.swift` | kanonisches Encoding + SHA-256-Hex, reine Funktion, CryptoKit | `enum ShareFingerprint`, `outputFormatting = [.sortedKeys]`, `SHA256.hash` → Hex | ✅ |
| 5 | DTO-Erweiterung | `ExportShareInfo` (4 Pflichtfelder) + `share`-Optional + Sendable (10 DTOs) + `currentShareFormatVersion` | vollständig, Details unten | ✅ |
| 6 | Sichtbarkeitszeile | `importFromJSONData` `private` → `internal` | genau eine Zeile geändert (`ExportImportService+Import.swift:65`) | ✅ |

### C2/C3 — Info.plist im Detail

| Vertrag | Soll | Ist (`ShipTrip-Info.plist`) |
|---|---|---|
| UTI-Identifier | `com.andre.shiptrip.cruise` | ✅ Zeile 12 |
| Endung | `shiptrip` | ✅ via `UTTypeTagSpecification` / `public.filename-extension`, Zeile 20-26 |
| Conforms to | `public.data`, **nicht** `com.pkware.zip-archive` | ✅ nur `public.data`, Zeile 17-19 — der ZIP-Typ taucht nirgends auf |
| `CFBundleDocumentTypes` | `LSItemContentTypes = [com.andre.shiptrip.cruise]`, Role `Viewer`, Rank `Owner` | ✅ Zeile 30-42 |
| `LSSupportsOpeningDocumentsInPlace` | `false` | ✅ `<false/>`, Zeile 44-45 (Top-Level, korrekt platziert) |
| `CFBundleURLTypes` | Scheme `shiptrip` | ✅ Zeile 46-56 |

Verdrahtung geprüft: `GENERATE_INFOPLIST_FILE = YES` **und** `INFOPLIST_FILE =
"ShipTrip-Info.plist"` (pbxproj Z. 400/401, 443/444). Kein `INFOPLIST_KEY_*`
kollidiert mit einem der neuen Keys — die Merge-Semantik überschreibt nichts. Die
drei neuen Swift-Dateien brauchen keinen pbxproj-Eintrag, weil das Target
`fileSystemSynchronizedGroups` nutzt; das bestätigt auch der grüne Build.

### C1 — DTO-Erweiterung im Detail

- `ExportShareInfo` (`ExportImportDTOs.swift:98-112`) trägt **exakt** die vier
  Pflichtfelder `shareFormatVersion: Int`, `sharedAt: String`, `appVersion: String`,
  `contentFingerprint: String` — keine Zusatzfelder, keine CodingKeys nötig
  (Feldnamen = JSON-Keys aus C1).
- `currentShareFormatVersion = 1` (`:101`) — statisch, `Int`, Rev.-4-konform.
- `ExportArchive.share: ExportShareInfo?` (`:33`), CodingKey `.share` (`:42`),
  `decodeIfPresent` (`:74`), Init-Default `nil` (`:52`).
- **Backup-Byte-Identität (am Code nachvollzogen, kein Testlauf):** Die Datei
  enthält **kein** custom `encode(to:)` (verifiziert per Grep) — für
  `ExportArchive` wird der Encoder synthetisiert, und die Synthese emittiert für
  Optional-Properties `encodeIfPresent`. Bei `share == nil` fehlt der Key im
  Output vollständig. Der einzige Backup-Erzeuger `buildArchive`
  (`ExportImportService.swift:88`) nutzt den Init-Default `nil`; der Legacy-Pfad
  `ExportArchive.decode` (`ExportImportDTOs.swift:87`) ebenso. `encodeArchive`
  bleibt bei `[.prettyPrinted, .sortedKeys]`, also alphabetischer Key-Reihenfolge —
  selbst die Position wäre irrelevant. **Backup-Encoding bleibt byte-identisch.**
- **Sendable-Liste C0 — 10/10 explizit deklariert:** `ExportArchive:33`(decl. `:20`),
  `ExportShareInfo:98`, `ExportCruise:115`, `ExportPort:135`, `ExportPhoto:157`,
  `ExportExpense:187`, `ExportDeal:201`, `ExportCustomShippingLine:221`,
  `ExportCustomShip:229`, `ExportHiddenCatalogItem:239`. Alle sind reine Wertetypen
  über `String`/`Int`/`Double`/`Bool?`/Arrays — die Konformität ist inhaltlich
  gedeckt, nicht nur deklariert. Damit steht die Grundlage für
  `SharePreflightResult: Sendable` und den `Task.detached`-Übergang aus C10.

### C1/C10 — ShareFingerprint & Limits

- `ShareFingerprint.contentFingerprint(for:)` (`ShareFingerprint.swift:26-33`):
  `outputFormatting = [.sortedKeys]` — **kein** `.prettyPrinted`, exakt wie C1 es
  vorschreibt (und bewusst abweichend von `encodeArchive`, das prettyPrinted
  nutzt). `enum` ohne Cases, keine gespeicherten Zustände, keine Aktor-Isolation,
  keine Force-Unwraps, `throws` statt `try!`. swift-standards-konform.
- `ShareArchiveLimits` (`ShareArchiveLimits.swift:16-34`): `maxArchiveFileSize`
  275 MB, `maxPayloadSize` 250 MB, `maxDataJSONSize` 10 MB, `maxPorts` 100,
  `maxPhotos` 300, `maxExpenses` 1000 — 6/6 Werte deckungsgleich mit der
  C10-Tabelle. Nur Konstanten, keine Logik.

### Negativabgleich — „nicht mehr als diese sechs"

Gesucht und **nicht gefunden** (korrekt, gehört zu W1/W2/W3):
`ShareExportError`, `exportCruiseForSharing`, `ShareImageTranscoder`,
`ShareImportError`, `SharePreflight`, `SharePreflightResult`,
`ShareImportResult`, `ShareImportCoordinator`, `IncomingLink(Router)`,
`Cruise.shareContentFingerprint`, `ExportImportService+ShareImport.swift`,
Archiv-Preflight-Guard in `importFromJSONData`, `.shipTripCruise` in
`SettingsView.fileImporter`, `onOpenURL` in `ShipTripApp`.
Ebenso keine neuen String-Katalog-Einträge und keine Testdatei im Diff.

## Findings

| ID | Severity | Blocker | File:Line | Kategorie | Titel |
|---|---|---|---|---|---|
| F01 | minor | nein | `ShipTrip-Info.plist:14-16`, `:32-34` | i18n | `UTTypeDescription` / `CFBundleTypeName` nur auf Deutsch |
| F02 | minor | nein | `ShipTrip-Info.plist:20-26` | robustness | Kein `public.mime-type`-Tag in der `UTTypeTagSpecification` |

### F01 — Dokumenttyp-Beschreibung nur auf Deutsch
- **File**: `ShipTrip-Info.plist:14-16` (`UTTypeDescription = "ShipTrip-Reise"`),
  `:32-34` (`CFBundleTypeName = "ShipTrip-Reise"`)
- **Severity**: minor · **Blocker**: nein
- **Problem**: Die App ist seit Phase 1 zweisprachig (DE/EN). Beide Strings
  erscheinen user-sichtbar in der Files-App und im „Öffnen mit"-Menü, bleiben aber
  auf einem englischen Gerät deutsch.
- **Warum kein Blocker**: rein kosmetisch, keine Funktionsauswirkung; die
  Zuordnung läuft über den UTI, nicht über den Anzeigenamen.
- **Warum kein Fix in W0**: Die Lokalisierung von Info.plist-Werten läuft über
  `InfoPlist.strings`-Dateien, nicht über den String-Katalog — das wäre ein
  siebtes Artefakt und damit ein C0-Verstoß. Gehört als eigener kleiner Schritt
  hinter W3.
- **Fix (später)**: `InfoPlist.strings` (de/en) mit den Keys `UTTypeDescription`
  und `CFBundleTypeName` anlegen; Werte in der Plist als Lookup-Keys belassen.

### F02 — Kein MIME-Type-Tag am exportierten UTI
- **File**: `ShipTrip-Info.plist:20-26`
- **Severity**: minor · **Blocker**: nein
- **Problem**: Die `UTTypeTagSpecification` deklariert nur
  `public.filename-extension`. Kommt die Datei über einen Transportweg an, der
  einen MIME-Type mitschickt (Mail-Anhang, manche Messenger-Web-Bridges), kann
  LaunchServices die Datei über den MIME-Type nicht auf
  `com.andre.shiptrip.cruise` abbilden und fällt auf `public.data` /
  ZIP-Erkennung zurück — der Doppeltipp landet dann nicht bei ShipTrip.
- **Warum kein Blocker für W0**: C2 fordert den Tag nicht, und der Hauptpfad
  (Nachrichten/WhatsApp/AirDrop) mappt über die Endung. Die Auswirkung zeigt
  sich erst mit der realen Teilen-UI in W3.
- **Fix (Backlog, vor W3-Abnahme evaluieren)**: in der
  `UTTypeTagSpecification` ergänzen:
  ```xml
  <key>public.mime-type</key>
  <array>
      <string>application/x-shiptrip-cruise</string>
  </array>
  ```
  Achtung: Das ist eine Änderung an einem Seed-Artefakt und geht laut C0
  über Winston, nicht still per W3-Diff.

## Backlog-Kandidaten (nicht von mir geschrieben — Quality ändert keine Dateien)

Für `.planning/BACKLOG.md`, Eintrag durch Winston:
```
- [minor] ShipTrip-Info.plist:14 — UTTypeDescription/CFBundleTypeName nicht lokalisiert (InfoPlist.strings DE/EN)
- [minor] ShipTrip-Info.plist:20 — public.mime-type-Tag am UTI fehlt; vor W3-Abnahme evaluieren (Seed-Änderung → über Winston)
```

## Go / No-Go

**Go.** Keine offenen Blocker, keine critical- oder major-Findings, Build grün mit
Evidenz-Artefakt (Exit 0), Größen-Guard sauber. W1 und W2 können auf diesem Seed
parallel starten — alle Symbole, die beide brauchen, existieren und kompilieren.
