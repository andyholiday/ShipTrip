# Kreuzfahrt teilen

**Stand:** Vollständig — W1 (Share-Export, C4/C5), W2 (Import-Flow, C3/C6/C10)
und W3 (Teilen-Aktion, C7/C8/C9) sind gemergt; seit 1.9.0 kommt die
Share-Extension als Empfangsweg dazu (ADR-010).
**Code:** `ShipTrip/Services/ExportImportService+ShareExport.swift`,
`ShipTrip/Services/ShareImageTranscoder.swift`,
`ShipTrip/Services/ExportImportService+ShareImport.swift`,
`ShipTrip/Utilities/IncomingLinkRouter.swift`,
`ShipTrip/Views/Share/ShareImportCoordinator.swift`,
`ShipTrip/Views/Cruises/CruiseShareAction.swift`,
`ShipTrip/ShareShared/ShareHandoffStore.swift`,
`ShipTripShare/ShareViewController.swift`, `ShipTrip/ShipTripApp.swift`
**Tests:** `ShareExportTests`, `ShareImageTranscoderTests`, `IncomingLinkRouterTests`,
`ShareImportPreflightTests`, `ShareImportResultTests`, `ShareRoundtripTests`,
`ShareHandoffStoreTests`, `ShareImportHandoffScanTests`, `ShareImportCleanupTests`,
`ReiseTeilenUITests` (UI)

## Übergabe aus dem Teilen-Sheet

Seit der Share-Extension `ShipTripShare` erscheint ShipTrip im iOS-Teilen-Sheet,
sobald genau eine `.shiptrip`-Datei geteilt wird — aus iMessage, Mail, WhatsApp
oder der Dateien-App. Der Weg ist bewusst zweistufig:

1. Der Nutzer wählt im Teilen-Sheet „ShipTrip". Die Extension kopiert die Datei
   atomar nach `<AppGroup>/ShareInbox/<UUID>.shiptrip` und meldet „An ShipTrip
   übergeben". Sie importiert nichts, öffnet keinen SwiftData-Store und versucht
   nicht, die App zu öffnen (dafür gibt es keine unterstützte API, ADR-010).
2. Beim nächsten Wechsel in den Vordergrund — Szenenaufbau, `scenePhase ==
   .active` oder Schließen des Ergebnis-Sheets — scannt
   `ShareImportCoordinator` den Ordner und importiert die älteste Datei über den
   bestehenden Pfad (Preflight, Dedup, Ergebnis-Sheet). Danach wird sie
   gelöscht, bei Erfolg wie bei Fehlschlag. Im Wegwerf-Store („Daten nicht
   verfügbar") unterbleibt der Scan, die Datei bleibt für den nächsten gesunden
   Start liegen.

Als Abkürzung plant die Extension nach erfolgreicher Ablage eine lokale
Mitteilung („Reise bereit zum Import"), aber nur, wenn die Berechtigung bereits
erteilt ist; fehlt sie, unterbleibt die Mitteilung still. Liegengebliebene
Dateien räumt die Extension nach 24 Stunden weg.

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
  (`ShareRoundtripTests`); der Tipp auf eine Datei ist seit dem Fix-Run vom
  2026-09-10 zusätzlich im Simulator nachgestellt (Dateien-App → `.shiptrip` →
  Import mit Ergebnis-Sheet). Die Abnahme auf einem physischen Gerät steht
  weiterhin aus.
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

### Share-Extension (Run 2026-09-10)

Kriterien aus `.planning/ZIEL.md` (Run „Share-Extension"). Verifikationsstand:
Test-Build 59/59 grün, Code-Review ohne Blocker.

| Nr. | Kriterium (Kurzfassung) | Status |
|---|---|---|
| 1 | Target `ShipTripShare`, Prädikat-Regel, „ShipTrip" im Teilen-Sheet | Erfüllt |
| 2 | Extension kopiert atomar in die App Group, kein SwiftData, kein App-Öffnen | Erfüllt |
| 3 | Vordergrund-Scan importiert über `ShareImportCoordinator`, Unit-Test vorher rot | Erfüllt |
| 4 | `shouldRemoveAfterImport` kennt den Übergabeordner, Unit-Test vorher rot | Erfüllt |
| 5 | ADR-010 samt Contract, Gate #4 grün | Erfüllt |
| 6 | `fetch_profile` und Signing-Wege um `ShipTripShare` ergänzt | Erfüllt |
| 7 | E2E im Simulator: Teilen → ShipTrip → Reise importiert | Simulator-E2E läuft |
| 8 | Geräte-Abnahme iMessage-Anhang (Build 31, TestFlight) | Offen — Andre |
| 9 | Changelog, Feature-Doku, CLAUDE.md nachgezogen | Erfüllt |

- **1:** `NSExtensionActivationRule` als Prädikat auf `com.andre.shiptrip.cruise`
  (kein `TRUEPREDICATE`, kein `…SupportsFileWithMaxCount` — sonst stünde ShipTrip
  bei jedem Dateityp im Sheet); der Sheet-Name kommt aus
  `INFOPLIST_KEY_CFBundleDisplayName = ShipTrip`.
- **2:** `ShareViewController` kopiert synchron im Completion-Handler nach
  `ShareInbox/<UUID>.shiptrip` (`.tmp` + `moveItem`), prüft
  `ShareArchiveLimits.maxArchiveFileSize` vorher und plant die Mitteilung nur bei
  bereits erteilter Berechtigung.
- **3/4:** `ShareImportHandoffScanTests` und `ShareImportCleanupTests` decken
  Scan, Single-Flight, `inbox: nil` und die erweiterte Löschregel ab;
  `ShareHandoffStoreTests` prüft Namensschema, Ordner-Scan und 24-h-Regel.
- **7:** Der Simulator-Nachweis läuft zum Zeitpunkt dieses Eintrags noch (wird
  nach Abschluss hier nachgezogen).
- **8:** Nur am Gerät prüfbar — der Simulator hat kein iMessage; offen sind damit
  die Prädikat-Verifikation an Nachrichten-Anhängen und die Zustellung der
  Mitteilung.

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
- **Die App muss nach dem Teilen geöffnet werden:** Eine Share-Extension darf
  ihre Container-App nicht öffnen (keine unterstützte API, ADR-010). Nach „Teilen
  → ShipTrip" liegt die Reise im Übergabeordner und wird erst beim nächsten
  Öffnen der App importiert.
- **Das Antippen der Mitteilung ist unverifiziert:** Ob eine Share-Extension die
  Benachrichtigungs-Berechtigung der App nutzen darf und ob das Antippen ShipTrip
  in den Vordergrund holt, ist nicht durch Apple-Referenzdoku belegt. Bleibt die
  Mitteilung aus, ändert sich am Import-Weg nichts — nur der Abschlusstext der
  Extension weist dann auf das Öffnen hin.
- **Nur eine Datei je Aktivierung:** Der Scan importiert die älteste wartende
  Datei. Werden zwei Reisen kurz hintereinander geteilt, kommt die zweite beim
  nächsten Vordergrund-Wechsel oder nach dem Schließen des Ergebnis-Sheets dran.

## Related Decisions

- [ADR-007: Kreuzfahrt-Teilen als `.shiptrip`-Datei](../adr/ADR-007-kreuzfahrt-teilen.md)
- [ADR-010: Share-Extension mit App-Group-Übergabe](../adr/ADR-010-share-extension-app-group-handoff.md)
- [Contracts H1–H6 der Share-Extension](../architecture/contracts/share-extension-handoff.md)
- [Design „Kreuzfahrt teilen"](../architecture/share-cruise-design.md)
- [Contracts C0–C10](../architecture/contracts/share-cruise-contracts.md)
- [Export & Backup](export-backup.md) — Container, Härtung und Grenzen des Basisformats
