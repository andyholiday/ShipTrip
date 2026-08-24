# Export & Backup

**Status:** Aktiv (1.8.0, Task C4)
**Code:** `ShipTrip/Services/ExportImportService+Export.swift`,
`ShipTrip/Services/ZipArchiveWriter.swift`, `ShipTrip/Services/ZipArchiveReader.swift`
**Tests:** `ExportRoundtripTests`, `ExportLegacyCompatibilityTests`,
`ExportImportHardeningTests`, `ExportPhotoIdentityTests`, `ExportStreamingTests`

## Format

Der Export schreibt ein ZIP-Archiv (Compression Method 0 / STORED, kein Deflate,
CRC-32 nach IEEE 802.3):

- `data.json` — der vollständige Envelope: Kreuzfahrten mit Route, Ausgaben und
  Foto-Referenzen, Wunschreisen, eigene Reedereien/Schiffe und ausgeblendete
  Katalog-Einträge. IDs sind stabil (siehe
  [ADR-002](../adr/ADR-002-cloudkit-sync-und-stabile-ids.md)).
- `images/<cruiseId>/ports/<index>` — Hafenbilder, Rohbytes ohne Re-Encoding.
- `images/<cruiseId>/<index>` — Reisefotos, Rohbytes ohne Re-Encoding.

Demo-Daten (`isDemo`) filtert der Service selbst und landen nie in einem Backup.
Der JSON-Export (`exportToJSON`) besteht als Referenz für ältere Backups fort;
er bettet Bilder Base64-kodiert inline ein und hat keine UI-Aufrufstelle mehr.

## Speicher- und Nebenläufigkeitsprofil (C4)

`exportToZip` läuft in zwei Phasen:

1. **MainActor, synchron:** Aus den SwiftData-`@Model`-Objekten entsteht der
   Sendable-Snapshot — `data.json` als fertige Bytes plus eine
   `ExportImageSource`, die nur die Eintragsnamen kennt. Bild-Bytes werden hier
   bewusst *nicht* eingesammelt. Das ist die harte SwiftData-Regel: `@Model`-
   Objekte dürfen die Aktorgrenze nicht überqueren.
2. **Off-main:** `ZipArchiveStreamWriter` (ein `actor`) schreibt das Archiv
   Eintrag für Eintrag über einen `FileHandle` in die Zieldatei und fordert jedes
   Bild einzeln über einen kurzen MainActor-Hop an.

Ergebnis: JSON-Serialisierung, CRC-32 und Dateischreiben blockieren die UI nicht
mehr, und der Spitzenverbrauch liegt bei O(größtes Bild) statt O(Bibliothek) —
vorher lagen erst alle Bilder als Eintragsliste und dann das gesamte Archiv
gleichzeitig im Speicher (~2× Bibliothek).

`ExportStreamingTests` fixiert das beobachtbar: die Zieldatei wächst zwischen
zwei Eintrags-Anforderungen, und `ExportImageSource` gibt Bytes ausschließlich
einzeln und auf Anforderung heraus.

## Importgrenzen

| Grenze | Wert | Ort |
|---|---|---|
| Einzelner Eintrag (unkomprimiert) | 50 MB | `ZipArchiveReader.maxEntryUncompressedSize` |
| Alle Einträge kumuliert | 500 MB | `ZipArchiveReader.maxTotalUncompressedSize` |
| ZIP-Datei selbst | 550 MB | `ZipArchiveReader.maxArchiveFileSize` |

**Warum 550 MB (in 1.8.0 bewusst bestätigt, nicht geerbt):** Die 500 MB Nutzlast
sind die Obergrenze dessen, was ein Backup an Bildern tragen darf — bei rund 3 MB
je Foto etwa 160 000 Bilder und damit weit jenseits einer realistischen
Reise-Fotobibliothek. Da STORED unkomprimiert schreibt, kommen nur die
ZIP-Strukturen obendrauf (Local Header 30 B + Name, Central Directory 46 B + Name,
dazu `data.json`); 10 % Aufschlag decken das mit Reserve ab.

Der Lesepfad ist — anders als der Schreibpfad — noch nicht strömend: `extract`
legt die Arbeitskopie zwar auf Dateiebene an (`copyItem` statt
`Data(contentsOf:)` + `write`, sonst läge das Archiv doppelt im Speicher), liest
sie zum Parsen aber vollständig ein. Der Import-Spitzenverbrauch entspricht damit
ungefähr der Archivgröße. 550 MB bleiben auf iOS-18-Geräten im Rahmen; höher zu
gehen wäre ein Jetsam-Risiko, niedriger würde legitime Backups beim
Wiederherstellen abweisen — und genau dort ist Großzügigkeit wichtiger als
Sparsamkeit.

**Wer die Grenze anheben will, macht zuerst den Lesepfad strömend.**

Zusätzlich gelten die ZIP32-Grenzen des Writers (kein ZIP64): maximal 65 535
Einträge, jeder Eintrag und das Gesamtarchiv unter 4 GB.
