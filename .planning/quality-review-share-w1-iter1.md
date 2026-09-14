# Review — W1 Share-Export „Kreuzfahrt teilen"

- **Iteration**: 1 / 3
- **Reviewer**: quality-agent (statische Tiefen-Review, KEIN Build/Testlauf — Build-Token beim parallelen Test-Spawn)
- **Datum**: 2026-08-25
- **Diff**: `release/1.8.0..feature/share-export`, HEAD `5974d59`, 4 Dateien / 825 Zeilen, Worktree sauber
- **Verdikt**: **approve (Go, statisch)** — Vorbehalt: der verifizierende Testlauf des parallelen Build-Spawns steht aus und liegt bei Winston
- **Stats**: critical: 0, major: 0, minor: 9 — Blocker: 0, Backlog: 9

## Summary

Der W1-Diff erfüllt die Verträge C1/C4/C5/C10 vollständig und ohne Abweichung. Der
Datenschutz-Kern (Metadaten-Entfernung) ist mechanisch korrekt gelöst: Die Ausgabe entsteht
aus einem nackten `CGImage` plus genau einer selbst gesetzten Eigenschaft — die
Quell-Properties werden nie berührt, ein Passthrough ist strukturell ausgeschlossen. Das
Wiederverwendungs-Gebot ist eingehalten (kein Parallel-Writer), die Aktorgrenzen sind sauber
(kein `@Model` off-main), und `ExportImportService.swift` ist bit-identisch unverändert.

Alle neun Findings sind minor und keines blockiert den Go-Live. Sie gehören in
`.planning/BACKLOG.md` (Zeilen unten fertig zum Übertragen), nicht in einen Fix-Loop.

## Deterministische Checks

```
python3 guard.py sizes --files <die 4 Dateien>
→ sizes: ok (4 geprueft, 0 Soft-Warnungen)   EXIT=0
```

Größte neue Datei: `ExportImportService+ShareExport.swift` 275 Zeilen (Soft-Limit 400).
Die akzeptierte Abweichung (neue Datei statt Einbau in `ExportImportService.swift`) ist
vertragskonform und **kein** Finding. Unlokalisierte `ShareExportError`-Texte sind per
Winston-Entscheid ein W3-Punkt und **kein** Finding.

`ShipTrip.xcodeproj` nutzt `PBXFileSystemSynchronizedRootGroup` (objectVersion 77) — die vier
neuen Dateien werden ohne pbxproj-Änderung ins Target aufgenommen. Kein fehlender
Build-Phase-Eintrag.

## Vertrags-Abgleich (Soll → Ist)

### C4 — `ShareImageTranscoder`

| Anforderung | Ist | OK |
|---|---|---|
| Signatur `downscaledJPEG(from:maxPixelSize:quality:) -> Data?`, Defaults 2048/0.8 | `ShareImageTranscoder.swift:30-34` | ✔ |
| `CGImageSourceGetCount`-Guard (lazy Source liefert auch für Nicht-Bilder ein Objekt) | `:37-40` | ✔ |
| `kCGImageSourceCreateThumbnailWithTransform` (Orientierung eingebrannt) | `:45` | ✔ |
| `kCGImageSourceCreateThumbnailFromImageAlways` | `:44` | ✔ |
| Kein Upscaling | `:43` + empirisch belegt durch `doesNotUpscale` (64×48 → 64×48) — keine Annahme, sondern Test | ✔ |
| Metadaten vollständig entfernt | `:65-69` — `CGImageDestinationAddImage` bekommt das nackte `CGImage` und **ausschließlich** `kCGImageDestinationLossyCompressionQuality`. Die Source ist am Ziel nicht beteiligt, kein `CGImageDestinationCopyImageSource`, kein Property-Merge → EXIF/GPS/IPTC/XMP/MakerNote können strukturell nicht mitwandern | ✔ |
| Kein Orientation-Tag nötig | Drehung in den Pixeln, Test `bakesOrientationIntoPixels` beweist 120×60 (Orientation 6) → 60×120 | ✔ |
| `CGImageDestinationFinalize`-Rückgabe geprüft | `:70-72` | ✔ |

### C5 — `exportCruiseForSharing`

| Anforderung | Ist | OK |
|---|---|---|
| Ablauf MainActor-Snapshot → off-main Spool → Limits über Spool-Größen → `ZipArchiveStreamWriter` | `ExportImportService+ShareExport.swift:61-141`, drei sauber getrennte Phasen | ✔ |
| Off-main garantiert (nicht nur `nonisolated`-Hoffnung) | `:205` `Task.detached(priority:.userInitiated)` — explizit, wie C10 es für die Import-Seite fordert | ✔ |
| Aktorgrenzen: kein `@Model` off-main | `imageSource.data(at:)` synchron auf dem MainActor (`:104`), über die Grenze wandern nur `Data`/`String`/`URL` | ✔ |
| Zähl-Limits **vor** Transcode-Arbeit | `:65-83` (Häfen, Ausgaben, Bilder), `maxDataJSONSize` `:86` | ✔ |
| Größen-Limits über Spool-Größen, exakt statt geschätzt | `:220-252` — STORED ⇒ Payload + Strukturbytes + 22 B EOCD; spiegelt `validateArchiveSize` | ✔ |
| Alles-oder-nichts: Spool weg | `:98` `defer` — greift auf **jedem** Pfad, auch bei Transcode-Abbruch nach n geschriebenen Bildern | ✔ |
| Alles-oder-nichts: Zieldatei weg | `:138-141` `catch` entfernt den ganzen Zielordner; `Task.checkCancellation()` steht innerhalb des `do` (`:136`) und wird mit aufgeräumt | ✔ |
| `share`-Block, alle 4 Felder | `:178-183` | ✔ |
| Fingerprint via `ShareFingerprint` über das kanonische Encoding | `:182` über `base.cruises.first` (genau die exportierte `ExportCruise`) | ✔ |
| `shareFormatVersion` via `ExportShareInfo.currentShareFormatVersion` | `:179` — kein hartkodiertes `1`, Drift-Befund aus W0 ist geschlossen | ✔ |
| `sharedAt` als ISO-8601 mit Fractional Seconds | `:180` über den bestehenden `isoFormatter` → `2026-08-25T12:00:00.000Z` wie im C1-Beispiel | ✔ |
| Dateinamens-Slug nach C5 | `:257-274` — Alphanumerik/Bindestrich, `Any-Latin; Latin-ASCII`, leer → „Kreuzfahrt", frischer Temp-Unterordner gegen Kollisionen | ✔ (Nit: F05) |
| `isDemo` wirft `demoCruise` | `:63` | ✔ |
| `ShareExportError` vollständig und exakt nach C5 | `:22-40` — genau die drei Fälle, keine Erweiterung | ✔ |

**Wiederverwendungs-Gebot:** `buildArchive` (`:150`), `encodeArchive` (`:85`),
`ExportImageSource` (`:77`), `ZipArchiveStreamWriter` (`:137`) — alle genutzt, kein
Parallel-Writer, keine kopierte Envelope-Logik. `git diff` bestätigt:
`ExportImportService.swift` und `+Export.swift` sind unverändert.

**Reihenfolge-Konsistenz (der Punkt, an dem ein stilles Datenloch entstünde):**
`ExportImageSource` schreibt Hafenbilder vor Fotos, mit Indizes über die volle `sortedRoute`;
`makeShareArchive`s `photoEncoder`/`portImageURL` erzeugen exakt dieselben Pfade. Die
ZIP-Einträge werden zudem **namensbasiert** aus dem Spool gelesen (`:130-133`), nicht
indexbasiert — ein Index-Drift ist damit konstruktiv unmöglich. `spooledSizes` ist über
`zip(entryNames, spooledSizes)` korrekt ausgerichtet.

### C10 — Limits (Export-Seite)

Alle sechs `ShareArchiveLimits` sind gebunden: `maxPorts` `:65`, `maxExpenses` `:70`,
`maxPhotos` `:79`, `maxDataJSONSize` `:86`, `maxPayloadSize` `:232`, `maxArchiveFileSize` `:241`.
Gegengeprüft: Share-Deckel (275/250/10 MB) sind durchgehend **strenger** als die
`ZipArchiveReader`-Härtung (550/500/50 MB) — die App kann keine `.shiptrip` erzeugen, die
ihr eigener Reader ablehnt. Kein Selbst-Ablehnungs-Risiko.

### Test-Substanz

| Geforderter Beweis | Ist | Urteil |
|---|---|---|
| Envelope-Vollständigkeit (Häfen/Notizen/Ausgaben/Fotos, leere Sammlungen) | `ShareExportTests.swift:105-146` | substanziell — prüft Feldwerte, Bildreferenz-Pfade, Seetag ohne Bild, ZIP-Einträge |
| GPS-EXIF via `CGImageSourceCopyPropertiesAtIndex` | `ShareImageTranscoderTests.swift:102-137` | trägt — GPS ist im Quell-Fixture **verifiziert vorhanden** und in der Ausgabe abwesend (F01 zur EXIF/TIFF-Hälfte) |
| Regression Voll-Export unverändert | `ShareExportTests.swift:284-317` | substanziell — Originalbytes in DB **und** im Backup-ZIP, `"share"` fehlt im JSON-Text und dekodiert zu `nil` |
| Kompatibilität „Share-Datei ist gültiges Backup" | `ShareExportTests.swift:254-281` | substanziell — echter `importFromZip`-Durchlauf, `imported == 1`, `invalidMedia == 0`, Route/Ausgaben/Fotos zählen, Bild ≠ Original |
| Fingerprint | `ShareExportTests.swift:148-169` | stärker als es aussieht: der Erwartungswert wird über die **aus der Datei dekodierte** `ExportCruise` neu berechnet — der Test beweist damit auch Encode→Decode→Encode-Stabilität |
| Kein Immer-grün-Muster | — | keine reinen Smoke-Asserts, keine Snapshot-Only-Tests; drei Guard-Tests sind aber untypisiert (F02) |

## Findings

| ID | Severity | Blocker | File:Line | Kategorie | Titel |
|---|---|---|---|---|---|
| F01 | minor | nein | `ShipTripTests/ShareImageTranscoderTests.swift:121-136` | tests | EXIF-/TIFF-Assertions ungesichert — Fixture-Vorbedingung nur für GPS geprüft |
| F02 | minor | nein | `ShipTripTests/ShareExportTests.swift:207,225,242` | tests | `#expect(throws: ShareExportError.self)` unterscheidet die drei Fälle nicht |
| F03 | minor | nein | `ShipTrip/Services/ExportImportService+ShareExport.swift:70-83` | tests | Guards `maxExpenses` und `maxPhotos` ungetestet (nur `maxPorts`) |
| F04 | minor | nein | `ShipTrip/Services/ExportImportService+ShareExport.swift:171-175` | error-handling | Unerreichbarer Guard wirft `.limitExceeded` — falsches Fehler-Vokabular |
| F05 | minor | nein | `ShipTrip/Services/ExportImportService+ShareExport.swift:270-273` | correctness | Slug kann nach dem 60-Zeichen-Deckel auf `-` enden |
| F06 | minor | nein | `ShipTrip/Services/ExportImportService+ShareExport.swift:104` | ux | `ExportError.missingMedia` erreicht die Teilen-UI als „Backup abgebrochen: …" |
| F07 | minor | nein | `ShipTrip/Services/ExportImportService+ShareExport.swift:119-125` | handoff | Aufrufer muss den **Elternordner** löschen, C5 sagt „die Datei" |
| F08 | minor | nein | `ShipTrip/Services/ExportImportService+ShareExport.swift:177-181` | correctness | `appVersion`-Fallback `"1.0"` behauptet eine falsche Version |
| F09 | minor | nein | `ShipTrip/Services/ExportImportService+ShareExport.swift:51` | docs | Kommentar dreht die Aktor-Richtung um |

---

### F01 — EXIF-/TIFF-Assertions ungesichert
- **File**: `ShipTripTests/ShareImageTranscoderTests.swift:121-136`
- **Severity**: minor · **Blocker**: nein
- **Problem**: Der Test sichert die Fixture-Vorbedingung nur für GPS ab
  (`sourceProperties.keys.contains(kCGImagePropertyGPSDictionary)`). Ob ImageIO die
  übergebenen `{Exif}`-/`{TIFF}`-Werte tatsächlich ins Fixture-JPEG geschrieben hat, wird
  nicht geprüft — die Assertions in `:130-136` könnten die Abwesenheit von etwas belegen,
  das nie da war. Bewusst **nicht** höher eingestuft: Die eigentliche Leck-Vektor-Zusage
  (GPS) ist beidseitig bewiesen, und ein echter Regress (jemand baut Metadaten-Passthrough
  ein) würde die GPS-Assertion sicher rot färben.
- **Fix**: Vorbedingung symmetrisch machen, zwei Zeilen vor `:125`:
  ```swift
  let srcExif = sourceProperties[kCGImagePropertyExifDictionary] as? [CFString: Any]
  #expect(srcExif?.keys.contains(kCGImagePropertyExifUserComment) == true)
  let srcTiff = sourceProperties[kCGImagePropertyTIFFDictionary] as? [CFString: Any]
  #expect(srcTiff?.keys.contains(kCGImagePropertyTIFFMake) == true)
  ```
  Schlägt eine davon fehl, ist nicht der Transcoder kaputt, sondern der Fixture-Helfer —
  und genau das will man wissen.

### F02 — Guard-Tests unterscheiden die Fehlerfälle nicht
- **File**: `ShipTripTests/ShareExportTests.swift:207,225,242`
- **Severity**: minor · **Blocker**: nein
- **Problem**: Alle drei Sperren-Tests akzeptieren jeden `ShareExportError`.
  `tooManyPortsThrows` bliebe z. B. grün, wenn die Fixture versehentlich `isDemo` trüge und
  der Demo-Guard zuschlüge — der Limit-Guard wäre dann nie durchlaufen. Kein Immer-grün
  (ein Wurf ist weiterhin Pflicht), aber schwächer als der Vertrag.
- **Fix**: `ShareExportError: Equatable` ergänzen (die Payloads sind `String`, Synthese
  genügt) und die Fälle benennen — `await #expect(throws: ShareExportError.demoCruise)`
  bzw. für die parametrierten Fälle do/catch mit `guard case .limitExceeded = error`.

### F03 — Zwei von drei Zähl-Guards ungetestet
- **File**: `ShipTrip/Services/ExportImportService+ShareExport.swift:70-83`
- **Severity**: minor · **Blocker**: nein
- **Problem**: `maxPorts` ist getestet, `maxExpenses` (`:70`) und `maxPhotos` (`:79`) nicht.
  Die drei Guards sind fast identisch, das Regressionsrisiko ist entsprechend gering —
  aber `maxPhotos` zählt über `imageSource.entryNames` (Hafenbilder **plus** Fotos), also
  über eine andere Größe als die anderen beiden. Genau diese Abweichung ist ungeprüft.
- **Fix**: `maxPhotos` mitnehmen — 301 Fotos mit `onePixelPNG` an eine Reise hängen und den
  Wurf **vor** jeder Transcode-Arbeit erwarten (der Guard steht bewusst vor Phase 2).

### F04 — Unerreichbarer Guard wirft das falsche Fehler-Vokabular
- **File**: `ShipTrip/Services/ExportImportService+ShareExport.swift:171-175`
- **Severity**: minor · **Blocker**: nein
- **Problem**: `base.cruises.first == nil` ist bei genau einer übergebenen Reise
  unerreichbar; der Guard existiert korrekt nur, weil Force-Unwraps verboten sind. Er wirft
  aber `.limitExceeded` — feuerte er je, läse der Nutzer „Die Reise überschreitet die
  Grenzen für geteilte Reisen: Die Reise enthält keine übertragbaren Daten." Das ist in
  sich widersprüchlich. C5 sperrt das Enum auf drei Fälle, ein vierter ist also keine
  Option.
- **Fix**: Den Zweig gar nicht erst entstehen lassen — `buildExportCruises` liefert für
  `[cruise]` deterministisch ein Element. Alternative ohne Vertragsbruch: den `reason`-Text
  auf „Interner Fehler beim Aufbau der Reise." ändern, damit die Hülle nicht lügt.
  Backlog, nicht Fix-Loop.

### F05 — Slug kann nach dem Deckel auf `-` enden
- **File**: `ShipTrip/Services/ExportImportService+ShareExport.swift:270-273`
- **Severity**: minor · **Blocker**: nein
- **Problem**: Die Trailing-Dash-Trimmung (`:270`) läuft **vor** `prefix(60)` (`:272`). Ein
  Titel, dessen 61. Slug-Zeichen ein Trennstrich ist, ergibt `Lange-Reise-….shiptrip` mit
  Bindestrich direkt vor der Endung. Kosmetisch, kein Sicherheits- oder Kollisionsproblem
  (Path-Traversal ist durch den Alphanumerik-Filter ausgeschlossen — `.` und `/` werden zu
  `-`, ein führender Bindestrich kann nicht entstehen).
- **Fix**: Reihenfolge tauschen:
  ```swift
  var trimmed = String(slug.prefix(60))
  while trimmed.hasSuffix("-") { trimmed.removeLast() }
  return trimmed.isEmpty ? "Kreuzfahrt" : trimmed
  ```
  (Zeile `:270` entfällt dann.)

### F06 — Backup-Wortlaut in der Teilen-UI
- **File**: `ShipTrip/Services/ExportImportService+ShareExport.swift:104` (Ursprung: `ExportImportService+Export.swift:32`)
- **Severity**: minor · **Blocker**: nein
- **Problem**: Liefert ein referenziertes Bild keine Bytes (Modell zwischenzeitlich geleert,
  externer Speicher unlesbar), wirft `imageSource.data(at:)` `ExportError.missingMedia`.
  Der Wurf propagiert unverändert nach außen; die W3-Hülle „Teilen fehlgeschlagen: %@"
  ergibt dann „Teilen fehlgeschlagen: Backup abgebrochen: Das Bild '…' ist nicht mehr
  lesbar." Verhalten korrekt (Alles-oder-nichts hält, Spool wird per `defer` geräumt), nur
  der Text spricht vom falschen Feature.
- **Fix**: Eine Zeile, ohne das gesperrte C5-Enum zu erweitern — den Aufruf in `:104`
  umschließen und auf den vorhandenen Fall abbilden:
  ```swift
  let raw: Data
  do { raw = try imageSource.data(at: index) }
  catch { throw ShareExportError.transcodeFailed(entryName: name) }
  ```

### F07 — Ordner-Ownership: Übergabepunkt an W3
- **File**: `ShipTrip/Services/ExportImportService+ShareExport.swift:119-125`
- **Severity**: minor · **Blocker**: nein
- **Problem**: Die Rückgabe liegt in einem frischen Temp-Unterordner (richtig so — der
  Anzeigename im Share-Sheet ist der Dateiname). C5 formuliert die Aufräumpflicht aber als
  „Der Aufrufer löscht **die Datei**"; der Doc-Kommentar in `:59` präzisiert korrekt auf
  „bzw. deren Elternordner". Löscht W3 nur die Datei, bleibt ein leerer Ordner zurück
  (harmlos); vergisst W3 das Aufräumen ganz, liegt die vollständige Reise samt Fotos,
  Buchungs- und Kabinennummer im Temp-Verzeichnis, bis das System es räumt. Kein Defekt in
  W1 — aber der Punkt muss in den W3-Brief.
- **Fix**: W3-Completion-Handler löscht `url.deletingLastPathComponent()`, nicht `url`
  (Muster: bestehender ShareSheet-Handler in `SettingsView`). **Nach W3 verifizieren.**

### F08 — `appVersion`-Fallback behauptet eine falsche Version
- **File**: `ShipTrip/Services/ExportImportService+ShareExport.swift:177-181`
- **Severity**: minor · **Blocker**: nein
- **Problem**: Fehlt `CFBundleShortVersionString`, schreibt der Export `"1.0"` in den
  `share`-Block. Das Feld ist rein informativ (die C10-Versionsmatrix wertet es nicht aus),
  aber eine erfundene Versionsnummer ist schlechter als ein ehrliches Unbekannt — sie
  würde bei einer späteren Diagnose in die Irre führen.
- **Fix**: `appVersion ?? "unbekannt"`.

### F09 — Kommentar dreht die Aktor-Richtung um
- **File**: `ShipTrip/Services/ExportImportService+ShareExport.swift:51`
- **Severity**: minor · **Blocker**: nein
- **Problem**: „pro Bild ein kurzer MainActor-Hop für die Roh-Bytes" beschreibt den
  Backup-Pfad, wo der off-main laufende Writer auf den MainActor hopst. Hier ist es
  umgekehrt: `exportCruiseForSharing` läuft auf dem MainActor, liest die Bytes synchron
  (`:104`, kein `await`) und hopst per `Task.detached` **hinaus**. Der Kommentar in `:104`
  („MainActor-Hop") hat denselben Dreher.
- **Fix**: „pro Bild ein Ausflug vom MainActor: die Roh-Bytes werden hier gelesen, der
  Transcode läuft off-main."

## Trigger-Prüfungen

**Security (Angriffsfläche berührt — neue Datei-Ausgabe, neues Austauschformat):**
- Zip-Slip auf der Schreibseite: Eintragsnamen stammen ausschließlich aus
  `cruise.id.uuidString` und Laufindizes, nicht aus Nutzereingaben. Kein `..`, kein
  absoluter Pfad möglich. ✔
- Dateiname aus Nutzertext: `shareFileSlug` lässt nur ASCII-Alphanumerik und `-` durch;
  `.`, `/`, `\` werden zu `-`, ein führender `-` kann konstruktiv nicht entstehen. ✔
- Selbst-DoS / Ressourcen: alle sechs Limits gebunden, Zähl-Limits vor der teuren Arbeit,
  Speicherprofil O(größtes Bild) durch Spool + strömenden Writer. ✔
- Ablage: App-Sandbox-`temporaryDirectory`, nicht der geteilte Container. ✔
- Kein Netzwerk, kein Dritt-SDK, keine Krypto-Eigenbau (SHA-256 via CryptoKit im W0-Seed). ✔

**Privacy/GDPR (Datenverarbeitung berührt — Fotos verlassen das Gerät):**
- Datenminimierung ist der Kern des Features und korrekt umgesetzt: Aufnahmeort (GPS),
  Aufnahmezeit, Kamera-Modell und Maker Notes verlassen das Gerät **nicht**. Das ist der
  eine Punkt, an dem W1 wirklich Schaden hätte anrichten können, und er sitzt.
- Kein Auftragsverarbeiter, kein Drittlandtransfer, kein Tracking — Peer-to-Peer über das
  vom Nutzer gewählte System-Share-Sheet. Rechtsgrundlage = die bewusste Nutzerhandlung.
- **Hinweis (kein Finding, Produktentscheid):** `bookingNumber`, `cabinNumber` und `notes`
  wandern mit. Das entspricht dem Originalauftrag („alle informationen … exportiert") und
  Contract C1. W3 sollte im Teilen-Dialog benennen, was mitgeht — Buchungsnummern sind
  gegenüber der Reederei potenziell kontoführend. Backlog-Zeile unten.

## Backlog-Zeilen (zum Übertragen nach `.planning/BACKLOG.md` durch Winston)

```
- [minor] ShipTripTests/ShareImageTranscoderTests.swift:121-136 — EXIF-/TIFF-Fixture-Vorbedingung ungesichert (nur GPS geprüft)
- [minor] ShipTripTests/ShareExportTests.swift:207,225,242 — Guard-Tests unterscheiden die ShareExportError-Fälle nicht (Equatable + Fall benennen)
- [minor] ShipTrip/Services/ExportImportService+ShareExport.swift:70-83 — Guards maxExpenses/maxPhotos ungetestet
- [minor] ShipTrip/Services/ExportImportService+ShareExport.swift:171-175 — unerreichbarer Guard wirft .limitExceeded (falsches Fehler-Vokabular)
- [minor] ShipTrip/Services/ExportImportService+ShareExport.swift:270-273 — Slug kann nach dem 60-Zeichen-Deckel auf "-" enden
- [minor] ShipTrip/Services/ExportImportService+ShareExport.swift:104 — ExportError.missingMedia erreicht die Teilen-UI als "Backup abgebrochen: …"
- [minor] ShipTrip/Services/ExportImportService+ShareExport.swift:119-125 — W3 muss den Elternordner der Share-Datei loeschen, nicht nur die Datei
- [minor] ShipTrip/Services/ExportImportService+ShareExport.swift:177-181 — appVersion-Fallback "1.0" behauptet eine falsche Version
- [minor] ShipTrip/Services/ExportImportService+ShareExport.swift:51 — Kommentar dreht die Aktor-Richtung um
- [minor] W3-Teilen-UI — benennen, dass Buchungs-/Kabinennummer und Notizen mitgeteilt werden
```

## Go / No-Go

**Go (statisch)** — keine offenen Blocker, 0 critical, 0 major.

**Vorbehalt (liegt bei Winston):** Diese Review ist bewusst ohne Build und ohne Testlauf
gelaufen (Build-Token beim parallelen Test-Spawn). Der Go steht damit unter dem grünen
`gate-run.json` jenes Spawns. Statisch geprüft und für den Testlauf plausibel: alle in den
Tests benutzten Initializer existieren mit den verwendeten Labels (`Cruise(title:startDate:
endDate:shippingLine:ship:)`, `Port(name:country:latitude:longitude:)`,
`Photo(imageData:sortOrder:)`, `Expense(category:amount:description:)`),
`importFromZip(url:modelContext:)` ist synchron und `internal`, `importFromJSONData` ist per
W0-Seed sichtbar, und die vier Dateien werden über die synchronisierten Xcode-Gruppen
automatisch ins Target aufgenommen. Bleibt der Testlauf rot, ist dieser Go hinfällig.
