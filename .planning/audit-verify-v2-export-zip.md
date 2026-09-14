# Audit-Verifikation v2: Export/ZIP-Befunde (H3, H8, M1, M3)

Bezug: Voll-Audit 2026-07-10, Commit 687657c. Verifiziert read-only am aktuellen
Working-Tree-Stand (main, gleicher Commit — keine uncommitted Changes an den
Zieldateien).

---

## H3 — Koordinatenloser Hafen wird beim Import zum Seetag

**Urteil: CONFIRMED**

- Import-Heuristik: `ShipTrip/Services/ExportImportService.swift:357-359`
  ```swift
  let isSeaDay = exportPort.name.lowercased() == "seetag" ||
                 exportPort.name.lowercased() == "sea day" ||
                 exportPort.lat == nil
  ```
  Jeder Hafen ohne `lat` im DTO wird zum Seetag erklärt — unabhängig vom Namen.
  Betrifft **beide** Import-Pfade: `importFromZip` und `importFromJSON` rufen
  beide dieselbe `importFromJSONData` (Zeilen 234-277), es gibt keinen
  separaten Web-JSON-Zweig mit anderer Logik.
- `isSeaDay` wird **nicht** explizit im DTO transportiert. `ExportPort` (Zeilen
  32-42) hat kein `isSeaDay`-Feld; es wird bei Export UND Import ausschließlich
  aus `name`/`lat` abgeleitet.
- Export-Seite: `buildExportCruises`, Zeilen 180-191:
  ```swift
  ExportPort(
      id: port.id.uuidString,
      name: port.isSeaDay ? "Seetag" : port.name,
      country: port.isSeaDay ? nil : port.country,
      lat: port.isSeaDay ? nil : String(...port.latitude),
      lng: port.isSeaDay ? nil : String(...port.longitude),
      ...
  )
  ```
  Solange die Quelle eine ShipTrip-eigene ZIP/JSON ist, ist das intern
  konsistent (ein Port hat `isSeaDay == false` nur mit echten, nie-nil
  Koordinaten, da `Port.latitude/longitude` in `Port.swift:27,30` nicht
  optional sind). Der Bruch entsteht bei **fremden** Quellen (Web-App-Export,
  hand-editiertes `data.json`, ältere Formate), die einen benannten Hafen ohne
  aufgelöste Koordinaten liefern können, ohne einen Seetag zu meinen.
- **Ist der Schaden durch Roundtrip wirklich permanent?** Ja, aber differenziert:
  - Beim Import selbst bleibt der Name im lokalen `Port`-Objekt korrekt
    erhalten (`Port(name: exportPort.name, ...)`, Zeile 364-369) — nur das
    Flag `isSeaDay` wird fälschlich `true` gesetzt (Zeile 379).
  - Der eigentliche, irreversible Verlust tritt beim **nächsten Export** dieses
    Ports ein: Da `isSeaDay == true`, überschreibt `buildExportCruises`
    Zeile 183 den echten Namen mit `"Seetag"` und verwirft `country`/`lat`/`lng`
    im neuen Exportfile. Ab diesem Zeitpunkt ist der Originalname nur noch in
    der lokalen SwiftData-DB vorhanden, nicht mehr in irgendeinem Backup/Export.
    Ein Restore aus genau diesem späteren Backup verfestigt den Verlust
    endgültig.
  - Abweichung vom Audit-Claim: Die Verfestigung passiert nicht "beim Import"
    selbst, sondern erst beim darauffolgenden Export-Zyklus. Für die
    Praxisrelevanz (Restore-Szenario, Geräte-Wechsel via Backup) ist das
    gleichwertig gefährlich.

**Fix-Hinweis:** `isSeaDay` explizit als eigenes Feld im DTO transportieren statt
es aus `lat == nil` zu raten; Fallback-Heuristik nur für Alt-Formate ohne dieses
Feld anwenden. Tests: `PortImageRoundtripTests` und ein neuer Test
"Hafen ohne Koordinaten aber mit Namen bleibt kein Seetag" sind nötig; bestehende
Duplicate-Port-Tests sind nicht betroffen.

---

## H8 — Beschädigte ZIPs als teilweise erfolgreicher Restore

**Urteil: CONFIRMED** (alle vier Teil-Behauptungen einzeln bestätigt)

| Teil-Check | Ergebnis | Evidenz |
|---|---|---|
| CRC-32 wird geprüft? | **Nein** | `ZipArchiveReader.swift` enthält keinerlei CRC-Referenz (grep bestätigt: 0 Treffer). CRC wird nur in `ZipArchiveWriter.swift:63,99,147` berechnet/geschrieben, beim Lesen nie zurückgelesen oder verglichen. |
| Local-Header-Signatur geprüft? | **Nein** | `ZipArchiveReader.swift:158-162`: `localHeaderOffset` wird direkt verwendet um `localNameLength`/`localExtraLength` zu lesen — kein Vergleich mit der 4-Byte-Signatur `0x50 0x4B 0x03 0x04`, wie sie beim Central-Directory-Eintrag (Zeile 110) geprüft wird. |
| Local-/Central-Name-Konsistenz geprüft? | **Nein** | Der lokale Dateiname wird an `localHeaderOffset` nie gelesen/verglichen; nur der Central-Directory-Name (Zeile 122-123) bestimmt den Zielpfad. Ein Local-Header mit abweichendem Namen bliebe unbemerkt. |
| Entry-Anzahl (`numEntries`) geprüft? | **Nein** | Die Schleife `for _ in 0..<numEntries` (Zeile 107) bricht bei defekter Central-Directory-Signatur oder Off-Bounds-Offset einfach mit `break` ab (Zeilen 108, 110) — es gibt keinen Vergleich "tatsächlich verarbeitete Einträge == deklariertes `numEntries`" und keinen Fehler/Wurf bei vorzeitigem Abbruch. Eine abgeschnittene/korrupte Central Directory führt so zu stillem Partial-Extract statt einem Fehler. |
| Fehlende Medien werden still übersprungen? | **Ja, bestätigt** | `ExportImportService.swift:389-394` (Port-Bild) und `:412-423` (Foto): jeweils `try?` mit Kommentar "Fehlende(s) Bild(datei): ... wird übersprungen, Cruise wird trotzdem importiert". `ImportResult` (Zeilen 56-60) hat **kein** Feld für übersprungene/fehlende Medien — der Verlust wird der UI (`SettingsView.swift:574-585`) nicht mitgeteilt, die Erfolgsmeldung zeigt nur `imported`/`skippedDuplicates`/`skippedInvalid`. |
| Test setzt CRC bewusst auf 0? | **Ja, bestätigt** | `ExportImportHardeningTests.swift:53` (Kommentar) + Zeile 86 `archive.appendUInt32LE(0) // CRC-32 (ungeprüft vom Parser)` im hauseigenen Test-ZIP-Builder — deckt sich exakt mit der fehlenden CRC-Prüfung im Reader. |

**Fix-Hinweis:** CRC-32 pro Eintrag nach dem Schreiben der Datei verifizieren
(Wert liegt bereits im Central-Directory-Header vor); Local-Header-Signatur +
Namenskonsistenz vor dem Datenzugriff prüfen; nach der Schleife
`processedEntries == numEntries` erzwingen und bei Abweichung werfen statt
`break`. `ImportResult` um `skippedMissingMedia: Int` erweitern und in der
SettingsView-Erfolgsmeldung anzeigen. Betroffene Tests: alle
`ZipSlipHardeningTests`/`DecompressionBombHardeningTests` bauen ZIPs über
`buildTestZip` mit CRC=0 — sobald CRC geprüft wird, muss der Test-Builder eine
echte CRC-32 berechnen (sonst schlagen bestehende grüne Tests künftig fehl).

---

## M1 — „Datenexport" unvollständig & nicht voll ID-stabil

**Urteil: CONFIRMED**

- `SettingsView.swift` `DataManagementView` queried fünf Entitäten (Zeilen
  396-400: `cruises`, `deals`, `customShippingLines`, `customShips`,
  `hiddenCatalogItems`), aber `exportData()` (Zeile 518) ruft nur
  `ExportImportService.shared.exportToZip(cruises: cruises)` (Zeile 523) auf.
  `Deal`, `CustomShippingLine`, `CustomShip`, `HiddenCatalogItem` fließen
  **nicht** in den Export. Bestätigt per Grep: keine Erwähnung von
  `Deal`/`CustomShippingLine`/`CustomShip`/`HiddenCatalog` in
  `ExportImportService.swift` — es gibt weder ein DTO noch Export-/Import-Code
  dafür.
- App-Einstellungen (z. B. Benachrichtigungs-Settings, ausgeblendete Katalog-
  Einträge als Nutzer-Präferenz) sind ebenfalls nicht Teil irgendeines DTOs.
- **Foto-ID nicht stabil, bestätigt:** `Photo` (Model, `Photo.swift:15`) hat
  ein `id: UUID`-Feld, aber `ExportCruise.photos` ist nur `[String]`
  (Base64 oder Pfadreferenz, keine ID). Beim Import (Zeilen 401-424) wird
  `Photo(imageData:sortOrder:)` ohne jede ID-Übernahme instanziiert — jedes
  Foto bekommt bei jedem Import eine frische Zufalls-UUID. Damit ist ein
  Re-Import (Restore, Duplikat-Erkennung, künftiges CloudKit-Merge) für Fotos
  nicht idempotent, im Gegensatz zu Cruise/Port/Expense, die ihre ID explizit
  übernehmen (Zeilen 336-339, 383-386, 442-445).
- **Zeitstempel teilweise, bestätigt:** `Expense.createdAt` wird exportiert
  (ISO8601, Zeile 202) und `expenseDate` optional (Zeile 201). Aber
  `Cruise.createdAt`/`updatedAt` (`Cruise.swift:50,53`),
  `Photo.createdAt`/`updatedAt` (`Photo.swift:28,31`) und
  `Port.updatedAt` (`Port.swift:52`) fehlen komplett in den jeweiligen DTOs
  (`ExportCruise`/`ExportPort` haben keine entsprechenden Felder).

**Fix-Hinweis:** Export/Import um Deal/CustomShippingLine/CustomShip/
HiddenCatalogItem-DTOs erweitern (jeweils mit stabiler ID); `ExportPhoto`-DTO
mit `id`/`createdAt`/`updatedAt` einführen statt reinem String; Cruise/Photo/
Port-Zeitstempel konsistent mit aufnehmen. Migrations-Risiko: bestehende
Legacy-JSON-Exporte (Base64-Photos ohne ID) müssen als Fallback ohne ID
importierbar bleiben (Web-App-Kompatibilität, Kommentar Zeile 273/403);
`PortImageRoundtripTests`/`DuplicateCruiseIDHardeningTests` sind direkt
betroffen, sobald sich das DTO-Format ändert.

---

## M3 — Import/Export überlastet Main Actor & Speicher

**Urteil: CONFIRMED**

- **Actor-Isolation:** `ExportImportService.swift:64` — `@MainActor class
  ExportImportService` — die Annotation gilt klassenweit, alle Methoden
  (`exportToZip`, `importFromZip`, `importFromJSONData` etc.) laufen zwingend
  auf dem Main Actor. Aufrufer in `SettingsView.swift` (`exportData()` Zeile
  518-537, `handleImport` Zeile 539-599) verwenden einen einfachen `Task { }`
  (kein `Task.detached`), was ohnehin nichts ändert, da die Methodenaufrufe
  selbst durch die `@MainActor`-Annotation an den Main Actor gebunden sind.
  Die komplette ZIP-Konstruktion/-Extraktion inkl. aller Datei-I/O läuft damit
  auf dem UI-Thread.
- **Speicher-Hotspot Export:** `exportToZip` (Zeilen 119-165) sammelt in
  `zipEntries: [(name: String, data: Data)]` **alle** Roh-Bilddaten (Ports +
  Fotos, Zeilen 142-156) im Speicher, bevor `ZipArchiveWriter.build(entries:)`
  daraus ein einziges zusammenhängendes `Data`-Archiv baut (komplett im
  Speicher materialisiert, `ZipArchiveWriter.swift:36-186`) und dieses erst
  danach auf Platte schreibt (Zeile 162). Peak-Memory ≈ 2× Gesamtgröße aller
  Fotos/Bilder einer Kreuzfahrt-Auswahl.
- **Doppeltes Lesen beim Import, bestätigt:** `ZipArchiveReader.extract`
  (Zeilen 66-82) liest die Quelldatei komplett via `Data(contentsOf:
  sourceURL)` (Zeile 75), schreibt sie 1:1 nach `tempZipPath` (Zeile 76-77)
  und ruft dann `parseAndExtractZip`, das dieselben Bytes über
  `Data(contentsOf: zipURL)` (Zeile 85) **erneut** vollständig einliest. Das
  ist ein echtes doppeltes Voll-Einlesen ohne funktionalen Zweck (die
  Zwischenkopie nach `tempZipPath` dient keinem erkennbaren Zweck außer als
  Kopie).
- **550-MB-Limit, bestätigt exakt:** `ZipArchiveReader.swift:24`
  `maxArchiveFileSize = 550 * 1024 * 1024`, geprüft in `extract()` Zeile
  69-73 — vor dem ersten `Data(contentsOf:)`-Read, aber danach wird die volle
  Datei trotzdem zweimal eingelesen (s.o.).

**Fix-Hinweis:** Export/Import-Kernarbeit (ZIP-Bau/-Parsing, Datei-I/O) von
`@MainActor` lösen — nur die abschließende SwiftData-`modelContext`-Mutation
muss auf dem Main Actor laufen (SwiftData `ModelContext` ist i. d. R. nicht
Sendable/actor-gebunden an den Context, der sie erstellt hat — Migration
erfordert Prüfung, ob `modelContext` hier zwingend MainActor-gebunden ist).
Den redundanten zweiten Vollzugriff in `extract()`/`parseAndExtractZip`
eliminieren (direkt von `sourceURL` parsen statt über `tempZipPath`-Kopie).
Bei einer Actor-Änderung müssen alle `@MainActor func ...Tests()` in
`ExportImportHardeningTests.swift` (durchgängig `@MainActor` annotiert)
gegengeprüft werden, ob sie noch mit `await` kompilieren.

---

## Geladene Skills

swiftdata, swift-standards (beide SKILL.md unter ~/.claude/skills/ als
Domänen-Referenz konsultiert, keine wörtliche Übernahme von Snippets nötig für
diese Verifikation).
