# Kreuzfahrt teilen

**Stand:** Vollständig — W1 (Share-Export, C4/C5), W2 (Import-Flow, C3/C6/C10)
und W3 (Teilen-Aktion, C7/C8/C9) sind gemergt.
**Code:** `ShipTrip/Services/ExportImportService+ShareExport.swift`,
`ShipTrip/Services/ShareImageTranscoder.swift`,
`ShipTrip/Services/ExportImportService+ShareImport.swift`,
`ShipTrip/Utilities/IncomingLinkRouter.swift`,
`ShipTrip/Views/Share/ShareImportCoordinator.swift`,
`ShipTrip/Views/Cruises/CruiseShareAction.swift`
**Tests:** `ShareExportTests`, `ShareImageTranscoderTests`, `IncomingLinkRouterTests`,
`ShareImportPreflightTests`, `ShareImportResultTests`, `ShareRoundtripTests`,
`ReiseTeilenUITests` (UI)

## Acceptance-Status

Kriterien aus `.planning/ZIEL.md` (Feature „Kreuzfahrt teilen"):

Verifikationsstand: 412/412 Unit-Tests, `ShareRoundtripTests` 2/2 und
`ReiseTeilenUITests` 2/2 zur Laufzeit grün.

| Nr. | Kriterium (Kurzfassung) | Status |
|---|---|---|
| 1 | Teilen-Aktion erzeugt `.shiptrip` mit allen Reisedaten, Datei + Link ins Share-Sheet | Erfüllt |
| 2 | Fotos komprimiert, Originale und Voll-Export unverändert | Erfüllt |
| 3 | Antippen importiert automatisch, sichtbare Bestätigung, keine Duplikate | Erfüllt (mit Fußnote) |
| 4 | `shiptrip://`-Link öffnet die App, Datei bleibt der Träger | Erfüllt |
| 5 | Roundtrip-Beweis Export → Import auf frischer Installation | Erfüllt |

- **1:** Das Menü der Reise-Detailansicht enthält „Reise teilen"; `CruiseShareModel`
  ruft `exportCruiseForSharing` (genau eine Reise mit Häfen, Notizen, Ausgaben und
  Fotos in einem Archiv mit `share`-Block) und übergibt Datei und Nachrichtentext
  gemeinsam ans System-Share-Sheet. Bei `isDemo`-Reisen fehlt der Eintrag ganz.
  Nach der Präsentation wird der Temp-Ordner der Datei gelöscht.
- **2:** `ShareImageTranscoder` verkleinert auf maximal 2048 px lange Kante,
  encodiert als JPEG (Qualität 0,8) und gibt das Bild ohne EXIF-, IPTC-, XMP- und
  Maker-Note-Blöcke aus. Ein Regressionstest hält das Backup-`data.json`
  byte-identisch, der `share`-Key fehlt dort weiterhin.
- **3:** `onOpenURL` → `IncomingLinkRouter` → `ShareImportCoordinator` →
  zweistufiger Preflight, danach der bestehende Import-Kern `importFromJSONData`
  mit Dedup über die stabile `id`. Das Ergebnis-Sheet weist eine abweichende
  Senderfassung als Versionskonflikt aus. **Fußnote:** Automatischer Import und
  Ergebnis-Sheet sind unit-verifiziert über den echten Share-Einstieg
  (`ShareRoundtripTests`); der physische Doppeltipp auf eine Datei auf einem Gerät
  ist nicht automatisiert getestet — die manuelle Abnahme steht aus.
- **4:** `shiptrip://import` wird geroutet und zeigt den Hinweis auf die
  angehängte Datei. Der Link steckt im Nachrichtentext des Share-Sheets
  (`CruiseShareModel.shareMessage`), Träger der Daten bleibt die Datei.
- **5:** `ShareRoundtripTests` exportiert eine Reise mit Fotos, importiert sie in
  einen frischen Container über den echten Share-Einstieg und vergleicht Felder
  und Foto-Auflösung; ein zweiter Import legt keine zweite Reise an. Die
  Beispielreise bleibt ausgenommen: `exportCruiseForSharing` wirft für
  `isDemo`-Reisen `ShareExportError.demoCruise`.

Aus W3 dazugekommen: sechs neue DE/EN-Schlüssel im String Catalog (C8) — der
Menütitel „Reise teilen", die Fehlerhülle „Teilen fehlgeschlagen: %@", der
Nachrichtentext und die drei nun lokalisierten `ShareExportError`-Texte; der
technische `reason` von `limitExceeded` bleibt unlokalisiert. Für die UI-Tests
tragen drei Elemente stabile Accessibility-IDs (C9): `cruiseDetail.shareButton`,
`shareImport.resultSheet` und `shareImport.linkHintSheet`.

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
