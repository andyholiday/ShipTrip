# Kreuzfahrt teilen

**Stand:** W1 (Share-Export, C4/C5) und W2 (Import-Flow, C3/C6/C10) sind gemergt;
die Teilen-Aktion in der Reise-Detailansicht (W3, C7) fehlt noch.
**Code:** `ShipTrip/Services/ExportImportService+ShareExport.swift`,
`ShipTrip/Services/ShareImageTranscoder.swift`,
`ShipTrip/Services/ExportImportService+ShareImport.swift`,
`ShipTrip/Utilities/IncomingLinkRouter.swift`,
`ShipTrip/Views/Share/ShareImportCoordinator.swift`
**Tests:** `ShareExportTests`, `ShareImageTranscoderTests`, `IncomingLinkRouterTests`,
`ShareImportPreflightTests`, `ShareImportResultTests`

## Acceptance-Status

Kriterien aus `.planning/ZIEL.md` (Feature „Kreuzfahrt teilen"):

| Nr. | Kriterium (Kurzfassung) | Status |
|---|---|---|
| 1 | Teilen-Aktion erzeugt `.shiptrip` mit allen Reisedaten, Datei + Link ins Share-Sheet | Teilweise — Datei-Erzeugung steht, Aktion offen |
| 2 | Fotos komprimiert, Originale und Voll-Export unverändert | Erfüllt (service-seitig verifiziert) |
| 3 | Antippen importiert automatisch, sichtbare Bestätigung, keine Duplikate | Erfüllt (service-seitig verifiziert) |
| 4 | `shiptrip://`-Link öffnet die App, Datei bleibt der Träger | Empfangsseite erfüllt, Beigabe im Text offen |
| 5 | Roundtrip-Beweis Export → Import auf frischer Installation | Offen (W3) |

- **1:** `exportCruiseForSharing` schreibt genau eine Reise mit Häfen, Notizen,
  Ausgaben und Fotos in ein Archiv mit `share`-Block. Die Aktion in der
  Detailansicht und die Übergabe von Datei plus Nachrichtentext ans System-Share-Sheet
  kommen mit W3.
- **2:** `ShareImageTranscoder` verkleinert auf maximal 2048 px lange Kante,
  encodiert als JPEG (Qualität 0,8) und gibt das Bild ohne EXIF-, IPTC-, XMP- und
  Maker-Note-Blöcke aus. Ein Regressionstest hält das Backup-`data.json`
  byte-identisch, der `share`-Key fehlt dort weiterhin.
- **3:** `onOpenURL` → `IncomingLinkRouter` → `ShareImportCoordinator` →
  zweistufiger Preflight, danach der bestehende Import-Kern `importFromJSONData`
  mit Dedup über die stabile `id`. Das Ergebnis-Sheet weist eine abweichende
  Senderfassung als Versionskonflikt aus. Nicht verifiziert ist bisher der
  Doppeltipp auf einem echten Gerät — der Nachweis hängt am Roundtrip aus W3.
- **4:** `shiptrip://import` wird geroutet und zeigt den Hinweis auf die
  angehängte Datei; der Link im Nachrichtentext entsteht mit dem Share-Sheet in W3.
- **5:** Der Roundtrip-Integrationstest ist als W3-Testleitplanke geplant. Die
  Beispielreise bleibt ausgenommen: `exportCruiseForSharing` wirft für
  `isDemo`-Reisen `ShareExportError.demoCruise`.

## Known Limitations

- **Alt-Versions-Restrisiko:** 1.8.0-Bestandsinstallationen kennen den
  `share`-Block nicht und importieren eine `.shiptrip`-Datei über den manuellen
  Daten-Import als gewöhnliches Backup. Bei legitimen Dateien (genau eine Reise)
  ist das harmlos und gewollt; eine manipulierte Mehr-Reisen-Datei würde dort
  massenimportiert. Rückwirkend nicht schließbar, bewusst dokumentiert — ab
  dieser Version greift der Archiv-Preflight in allen Pfaden.
- **Der Fingerprint ist unauthentifiziert:** Er wird einmal vom Sender berechnet
  und beim Empfänger persistiert, ist also weder signiert noch nachrechenbar. Ein
  manipulierter Wert führt schlimmstenfalls zu einem falschen oder fehlenden
  Versionskonflikt-Hinweis, nie zu Datenverlust — der Import selbst hängt nicht
  am Fingerprint. Ebenfalls ohne Hinweis bleiben lokale Empfänger-Änderungen nach
  dem Import, Reisen ohne persistierten Wert (nie geteilt empfangen) und reine
  Bildpixel-Änderungen.
- **Die Transportdeckel gelten nur am Share-Einstieg:** Dateigröße, Nutzlast und
  `data.json`-Größe aus `ShareArchiveLimits` binden den automatischen Pfad. Der
  manuelle Import in den Einstellungen bleibt bewusst beim Bestandsschutz des
  `ZipArchiveReader` (50 MB je Eintrag, Zip-Slip-Abwehr, CRC) — die Zählgrenzen
  für Häfen, Fotos und Ausgaben greifen dort über den Archiv-Preflight trotzdem.

## Related Decisions

- [ADR-007: Kreuzfahrt-Teilen als `.shiptrip`-Datei](../adr/ADR-007-kreuzfahrt-teilen.md)
- [Design „Kreuzfahrt teilen"](../architecture/share-cruise-design.md)
- [Contracts C0–C10](../architecture/contracts/share-cruise-contracts.md)
- [Export & Backup](export-backup.md) — Container, Härtung und Grenzen des Basisformats
