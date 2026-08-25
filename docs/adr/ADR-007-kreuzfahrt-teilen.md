# ADR-007: Kreuzfahrt-Teilen als `.shiptrip`-Datei auf Basis des Backup-Envelopes

**Status:** Accepted (2026-08-25 — Codex Gate #4 Freigabe nach Rev. 3, Iteration 3; siehe Revisionen)
**Datum:** 2026-08-25
**Autor:** Architect (Winston-Run „Kreuzfahrt teilen"), auf Basis von Andres
Clarify-Entscheiden vom 2026-08-25
**Querverweis:** ADR-002 (stabile IDs, CloudKit-Dedup, ZIP-Format)

---

## Kontext

Andre will einzelne Kreuzfahrten per Nachricht an andere ShipTrip-Nutzer
schicken; der Empfänger soll sie durch Antippen automatisch importieren —
mit allen Informationen und Bildern. Drei Entscheide sind bindend vorgegeben:
die Datei ist der Träger (eigener UTType, kein Universal Link in diesem Run,
`shiptrip://`-Link nur als Beigabe), es geht immer alles raus (inklusive
Ausgaben, ohne Nachfrage), und Fotos werden fürs Teilen komprimiert (Richtwert
2048 px), während Originale und Voll-Export unverändert bleiben.

Seit 1.8.0 existiert ein gehärtetes Backup-Format: ZIP (STORED) mit
`data.json`-Envelope (formatVersion 2), strömendem Writer mit
Alles-oder-nichts-Garantie und einem Lesepfad mit Größen-Limits,
Zip-Slip-Abwehr und CRC-Prüfung. Dedup läuft app-seitig über stabile
`id: UUID`, weil CloudKit `@Attribute(.unique)` verbietet (ADR-002). Die App
hat kein Backend und soll keins bekommen; String-Katalog ist gesperrt bis auf
nötige neue Keys. Das Feature soll in parallelen Wellen gebaut werden, was
vorab fixierte Schnittstellen-Contracts verlangt.

## Entscheidung

Wir definieren die `.shiptrip`-Share-Datei als das **bestehende
Backup-Archiv**, eingeschränkt auf genau eine Kreuzfahrt: gleicher
ZIP-Container, gleicher `ExportArchive`-Envelope (formatVersion 2), ergänzt um
einen optionalen `share`-Metablock (`shareFormatVersion: 1`) und mit Bildern,
die als JPEG auf maximal 2048 px lange Kante (Qualität 0,8) transkodiert
werden. Export- und Import-Pfad des `ExportImportService` werden
wiederverwendet; neu sind nur der Bild-Transcoder mit Disk-Spool, der
Einzel-Cruise-Einstiegspunkt `exportCruiseForSharing`, die App-Registrierung
(exportierter UTType `com.andre.shiptrip.cruise` mit Endung `shiptrip`,
Dokumenttyp mit `LSHandlerRank Owner`, URL-Scheme `shiptrip`) und ein
Import-Koordinator hinter `onOpenURL`, der Datei-Öffnen und Scheme-Links über
einen gemeinsamen Router auswertet.

Die Share-Semantik bindet an das **Archiv**, nicht an den Einstiegspfad:
Ein Archiv mit `share`-Block wird in jedem Pfad (onOpenURL, manueller
`fileImporter`, Legacy-JSON-Import) als geteilte Reise behandelt — ein
Archiv-Preflight im Import-Kern erzwingt **vor jeder Mutation** die
Share-Invarianten (genau eine Cruise, keine weiteren Sammlungen), die
Zählgrenzen und eine **totale** Versionsmatrix über
`formatVersion`/`shareFormatVersion` (unbekannte Werte werden abgelehnt,
in beide Richtungen). Archive ohne `share`-Block behalten in jedem Pfad die
unveränderte Backup-Semantik. Der Share-Einstieg deckelt zusätzlich Datei-,
Nutzlast- und Dekodier-Größen (`ShareArchiveLimits`, Transport-Preflight);
der Transcoder entfernt alle Foto-Metadaten (EXIF inkl. GPS). Das
Ausführungsmodell ist zweistufig mit explizitem Übergang: Extraktion,
Decode und Preflight laufen in einem `Task.detached` off-main auf explizit
`Sendable` deklarierten DTOs (eine `nonisolated`-Deklaration allein gilt
nicht als Off-Main-Garantie), die Fortsetzung kehrt in den
`@MainActor`-Koordinator zurück, wo die Mutation über den bestehenden
Import-Kern läuft (`@Model` überquert keine Aktorgrenze); der Koordinator
arbeitet Single-Flight. Ein `@ModelActor`-Zweitkern wird verworfen, weil er
die Dedup-/Rollback-Logik duplizieren würde und die Mutation durch die
Share-Limits klein gebunden ist.

Der Import läuft automatisch ohne Rückfrage und endet in einer sichtbaren
Ergebnis-Meldung; Duplikate werden über die stabile Cruise-`id` erkannt und
übersprungen. Weicht die Senderfassung inhaltlich ab, weist das
Ergebnis-Sheet dies als Versionskonflikt aus — über einen
`contentFingerprint`, den **nur der Sender** berechnet (senderlokal
deterministisch) und den der Empfänger beim Import an der Cruise
persistiert; spätere Vergleiche laufen ausschließlich über gespeicherte
Werte, eine geräteübergreifende Rekanonisierung des JSON-Encodings wird
nicht vorausgesetzt. Geteilte Reisen bleiben Kopien, kein Merge, kein
Sync. Gemeinsame Symbole beider Wellen (UTType, Info.plist-Registrierung,
Limits, Fingerprint-Helfer, Share-DTOs inkl. Sendable-Konformität)
entstehen in einem seriellen Naht-Seed W0 mit abschließender Inhaltsliste
vor den parallelen Wellen. Details und Verträge:
`docs/architecture/share-cruise-design.md` und
`docs/architecture/contracts/share-cruise-contracts.md` (C0–C10).

## Konsequenzen

Positiv:

- Ein Format, ein Parser: jede `.shiptrip`-Datei ist strukturell ein
  gültiges Backup-Archiv; bestehende 1.8.0-Installationen können sie über
  den manuellen Daten-Import lesen (sie ignorieren den `share`-Key und
  importieren als Backup — ehrliche Kehrseite siehe Negativ-Punkt
  Alt-Versions-Restrisiko).
- Die komplette 1.8.0-Härtung (Limits, Zip-Slip, CRC, Bildvalidierung,
  Rollback) gilt automatisch für die neue, exponierteste Importquelle
  (Dateien von Fremden).
- Dedup, id-Stabilität und CloudKit-Konformität sind geerbt (ADR-002), nicht
  neu gebaut.
- Kein Backend, keine Domain, keine laufenden Kosten. Universal Links bleiben
  ein kleiner, lokal begrenzter Nachrüstpfad — ehrlich benannt: Entitlement +
  AASA-Datei **plus** ein `onContinueUserActivity`-Handler und eine
  Router-Zeile, also Code und Konfiguration, kein Umbau (Contract C3).
- Der Archiv-Preflight validiert alles vor der ersten Mutation (Invarianten,
  Zählgrenzen, totale Versionsmatrix) und bindet an den `share`-Block statt
  an den Einstiegspfad — manipulierte Mehr-Reisen-„Share"-Dateien können in
  keiner Tür dieser Version einen Massenimport auslösen; der Share-Einstieg
  deckelt zusätzlich die Transportgrößen.

Negativ:

- Kein Update/Merge beim erneuten Teilen: Änderungen des Absenders erreichen
  einen Empfänger, der die Reise schon hat, nicht — der Import wird
  übersprungen; das Ergebnis-Sheet weist die Abweichung immerhin als
  Versionskonflikt aus (Fingerprint-Vergleich, C1/C6). Ein LWW-Merge über
  `updatedAt` wäre ein späteres, eigenes ADR.
- Der Fingerprint erfasst Feld-/Strukturänderungen der **Senderfassung**
  relativ zur damals empfangenen Fassung — nicht: reine Bildpixel-Änderungen
  (JSON-Pfadreferenzen), lokale Empfänger-Edits nach dem Import, und Reisen
  ohne persistierten Wert (nie share-importiert) liefern gar keinen Hinweis.
  Bewusste Leichtgewichts-Grenzen des gespeicherten Sender-Werts.
- Alt-Versions-Restrisiko: 1.8.0-Bestandsinstallationen kennen den
  `share`-Block nicht und würden eine manipulierte Mehr-Reisen-„Share"-Datei
  beim manuellen Import als Backup massenimportieren — rückwirkend nicht
  schließbar, bewusst dokumentiert (Contract C1); ab dieser Version greift
  der Archiv-Preflight in allen Pfaden.
- Ein als `.shiptrip` umbenanntes Backup wird am Share-Einstieg abgelehnt;
  wer es einspielen will, muss den manuellen Import in den Einstellungen
  nutzen (der unverändert bleibt).
- Der `shiptrip://`-Link ist unverifiziert (jede App kann ein Scheme
  beanspruchen) und kann die Datei nicht transportieren — er bleibt bewusst
  eine Beigabe ohne Daten.
- „Alles, immer" teilt auch Sensibles (Ausgaben, Buchungsnummer) ohne
  Auswahlmöglichkeit; vertretbar, weil nutzerinitiiert, aber eine spätere
  Teil-Auswahl wäre UI-Arbeit auf demselben Format.
- Doppelte Bild-Berührung beim Export (Transcode-Spool auf Disk) kostet
  Temp-Speicher in Archivgröße; dafür bleibt das RAM-Profil bei O(größtes
  Bild) und die Größenvalidierung exakt.

Neutral:

- Schreib- und Leseseite erzwingen dieselben Share-Invarianten (genau eine
  Cruise, leere Sammlungen) und dieselben `ShareArchiveLimits`; die
  Versionsmatrix ist eine Totalfunktion — unbekannte höhere Werte werden mit
  „neuere Version nötig" abgelehnt, unplausible niedrigere (unterhalb der
  ersten Share-Version) als „keine gültige geteilte Reise" (C10).
- Die Cruise erhält ein additives optionales Attribut
  `shareContentFingerprint: String?` (CloudKit-konform, leichtgewichtige
  Migration) — einziger Modell-Eingriff des Features.
- Der Naht-Seed W0 (UTType, Info.plist, Limits, Fingerprint-Helfer,
  Share-DTOs inkl. Sendable-Konformität, eine Sichtbarkeitszeile —
  abschließende Liste in C0) ist ein zusätzlicher serieller Mini-Schritt vor
  den parallelen Wellen — dafür sind W1 und W2 unabhängig kompilierbar.
- Wunschreisen/Deals und das Katalog-Overlay sind nicht Teil der Share-Datei
  (keine Modell-Beziehung zur Reise bzw. Absender-Konfiguration).

## Alternativen

**A: Eigenes, schlankes Share-Format (neues JSON-Schema nur für eine Reise).**
Abgelehnt: zweiter Parser und zweite Sicherheitsfläche für identische Daten;
verliert die Gratis-Kompatibilität mit dem gehärteten Backup-Import.

**B: Universal Links mit Hosting der Datei (Link lädt die Reise).**
Abgelehnt für diesen Run per Clarify-Entscheid: erfordert Domain + Hosting
(Kosten, GDPR-Fläche); die Datei in der Nachricht leistet den Transport ohne
Infrastruktur. Der Router-Schnitt hält den Pfad als reine Konfiguration offen.

**C: CloudKit-CKShare (native Freigabe der Records).**
Abgelehnt: ADR-002 hat CKShare-Logik bereits als Abstraktionsbruch des
SwiftData-Mirrorings verworfen; zudem erreicht es nur iCloud-Nutzer und nicht
den Nachrichten-Flow „Datei + Link".

**D: HEIC statt JPEG für die komprimierten Fotos.**
Abgelehnt: 30–50 % kleinere Dateien wiegen die Nachteile nicht auf — JPEG ist
universell dekodierbar (auch außerhalb von ShipTrip einsehbar), nutzt denselben
ImageIO-Pfad wie `ImageDownsampler`, und die Archiv-Limits sind bei 2048 px
ohnehin weit entfernt.

**E: Import mit Bestätigungs-Dialog statt automatisch.**
Abgelehnt: widerspricht der Original-Anfrage („automatisch importiert"); die
Validierungshärte des Lesepfads plus der C10-Preflight machen den Dialog
sicherheitstechnisch entbehrlich. Die sichtbare Bestätigung ist das
Ergebnis-Sheet.

**F: Share-Import komplett in einem `@ModelActor` (Hintergrund-Mutation).**
Abgelehnt: erforderte einen zweiten Import-Kern (Dedup-, Validierungs- und
Rollback-Logik dupliziert) oder das Reichen von `@Model`-Instanzen über
Aktorgrenzen (verboten). Stattdessen zweistufig: Preflight off-main auf
Sendable-Werten, Mutation über den bestehenden MainActor-Kern — durch
`ShareArchiveLimits` klein gebunden.

**G: UTType-/Info.plist-Deklaration in W1 belassen (statt Naht-Seed W0).**
Abgelehnt: W2 referenziert `.shipTripCruise` und wäre ohne W1 nicht
kompilierbar — die Parallelität der Wellen wäre nur nominell. Der Seed
kostet einen Mini-Commit und löst die Naht vollständig.

**H: Fingerprint-Vergleich per Empfänger-Rekanonisierung (Empfänger
berechnet den Fingerprint seiner lokalen Fassung via `buildArchive` nach).**
Abgelehnt: setzt geräteübergreifend byte-identisches JSON-Encoding voraus
(insbesondere `Double`-Repräsentation über Foundation-Versionen hinweg), das
sich nicht garantieren, nur festschreiben ließe; der einmal vom Sender
berechnete und beim Empfänger persistierte Wert leistet den
Versionskonflikt-Hinweis ohne diese Annahme — um den Preis, dass lokale
Empfänger-Edits und nie share-importierte Reisen keinen Hinweis auslösen
(dokumentierte Grenzen, C1).

## Referenzen

- `docs/architecture/share-cruise-design.md` — Design und Wellen-Schnitt
- `docs/architecture/contracts/share-cruise-contracts.md` — Contracts C1–C9
- `docs/adr/ADR-002-cloudkit-sync-und-stabile-ids.md` — stabile IDs, Dedup, ZIP
- `docs/features/export-backup.md` — Format, Limits, Alles-oder-nichts
- `docs/features/kreuzfahrt-teilen.md` — Umsetzungsstand und bekannte Grenzen
- `.planning/ZIEL-teilen.md`, `.planning/TASKPLAN-teilen.md` — Ziel + Clarify
- `ShipTrip/Services/ExportImportService*.swift`, `ShipTrip/Utilities/ImageDownsampler.swift`

## Revisionen

- **2026-08-25 (Rev. 2, Status weiter Proposed):** Codex-Gate-#4-Findings
  eingearbeitet — (1) Share-Einstieg erzwingt Invarianten vor jeder Mutation
  (Blocker); (2) `ShareArchiveLimits`, Preflight-Reihenfolge, zweistufiges
  Ausführungsmodell, Single-Flight; (3) Versionsmatrix für
  `formatVersion`/`shareFormatVersion`; (4) Versionskonflikt-Hinweis via
  `contentFingerprint` statt stummem Verwerfen; (5) Naht-Seed W0 für
  UTType/Info.plist/gemeinsame Symbole (neue Alternative G); (6)
  Metadaten-Entfernung beim Foto-Transcode; (7) Universal-Link-Pfad ehrlich
  als Code+Konfig-Änderung benannt. Kein Finding verworfen. Contracts
  erweitert um C0 und C10.
- **2026-08-25 (Rev. 3, Status weiter Proposed):** Re-Review-Findings aus
  Codex Gate #4, Iteration 2 eingearbeitet — (1, Blocker) Share-Invariante
  bindet ans Archiv (`share`-Block) statt an den Einstiegspfad: Archiv-
  Preflight als Guard im Import-Kern, gilt in jedem Pfad; Abwärts-
  kompatibilität ehrlich als Alt-Versions-Restrisiko dokumentiert; (2)
  Ausführungsmodell mit explizitem `Task.detached`-Übergang, benannter
  Sendable-DTO-Liste und beschriebenem Rückweg auf den MainActor; (3)
  Versionsmatrix als Totalfunktion — begründete Abweichung: unplausible
  niedrigere Werte melden „keine gültige geteilte Reise" statt „neuere
  Version nötig"; (4) Fingerprint sender-berechnet und empfänger-persistiert
  (`Cruise.shareContentFingerprint`), Rekanonisierung als Alternative H
  verworfen; (5) W0-Seed abschließend inkl. Share-DTOs und
  Sendable-Konformität. Kein Finding verworfen; Leitplanken gefolgt (bei 3
  mit begründeter Teilabweichung).
