# Contracts — Feature „Kreuzfahrt teilen"

**Status:** Verbindlich für Seed W0 + Wellen W1–W3 (Stand 2026-08-25, gehört zu
[ADR-007](../../adr/ADR-007-kreuzfahrt-teilen.md) und
[share-cruise-design.md](../share-cruise-design.md)).
**Rev. 2 (2026-08-25):** Codex-Gate-#4-Findings eingearbeitet — neu C0
(Naht-Seed) und C10 (Share-Import-Preflight); präzisiert C1, C3, C4, C5, C6, C8.
**Rev. 3 (2026-08-25):** Codex-Re-Review-Findings (Gate #4, Iteration 2)
eingearbeitet — (1) archiv-gebundene Share-Invariante statt Einstiegspfad-
Unterscheidung (C1/C6/C10), (2) Ausführungsmodell mit explizitem
`Task.detached`-Übergang + Sendable-DTO-Liste (C0/C10), (3) Versionsmatrix als
Totalfunktion (C10), (4) Fingerprint sender-berechnet + empfänger-persistiert
statt Rekanonisierung (C1/C6), (5) W0-Seed abschließend inkl. Share-DTOs (C0).
**Rev. 4 (2026-08-25, Winston):** C0 ergänzt um
`ExportShareInfo.currentShareFormatVersion` (statische Konstante = 1) —
einzige Quelle der Share-Formatversion; W1-Schreibseite und
W2-Versionsmatrix referenzieren sie statt je eine `1` zu hardcoden
(Drift-Befund aus dem W0-Return).
**Rev. 5 (2026-08-25, Winston — nach Codex-Gate-#2-Findings B1/B2/M1):**
(1) C6/C0-Nachtrag: W2 darf in `ExportImportService+Import.swift` zusätzlich
zum Preflight-Guard die Fingerprint-Persistenz setzen —
`cruise.shareContentFingerprint` aus `archive.share` wird bei neu angelegter
Cruise **vor** dem atomaren Kern-Save gesetzt (wirkt damit in jedem
Einstiegspfad; kein nachgelagerter Save). (2) C10-Invariante ergänzt: die
eine Cruise muss eine **gültige UUID** tragen, sonst `notAShareFile`.
(3) C6: der manuelle Datei-Dispatcher ordnet `.shiptrip` dem ZIP-/Archiv-Pfad
zu; die Share-Semantik entscheidet weiterhin der `share`-Block, nie die
Endung.
Diese Datei ist die Naht: Downstream-Wellen bauen gegen diese Verträge, nicht
gegeneinander. Änderungen an einem Contract gehen über Winston, nicht still
per Diff.

---

## C0 — Naht-Seed W0 (vor W1∥W2, ein kleiner serieller Schritt)

Alle Symbole, die W1 **und** W2 brauchen, entstehen in einem Seed-Commit direkt
auf dem Release-Branch, bevor die parallelen Wellen starten. Damit sind W1 und
W2 unabhängig kompilierbar (Gate-#4-Finding 5).

| Seed-Artefakt | Inhalt |
|---|---|
| `ShipTrip/Utilities/UTType+ShipTrip.swift` | `extension UTType { static let shipTripCruise = UTType(exportedAs: "com.andre.shiptrip.cruise") }` |
| `ShipTrip-Info.plist` | UTExportedTypeDeclarations + CFBundleDocumentTypes (C2) + CFBundleURLTypes für `shiptrip` (C3) |
| `ShipTrip/Services/ShareArchiveLimits.swift` | die Grenzkonstanten aus C10 (nur Konstanten, keine Logik) |
| `ShipTrip/Services/ShareFingerprint.swift` | kanonisches `ExportCruise`-Encoding + SHA-256-Hex (C1) — reine Funktion, CryptoKit |
| `ShipTrip/Services/ExportImportDTOs.swift` (bestehend) | (a) neuer DTO `ExportShareInfo` — die vier Pflichtfelder aus C1 (`shareFormatVersion: Int`, `sharedAt: String`, `appVersion: String`, `contentFingerprint: String`); (b) `ExportArchive.share: ExportShareInfo?` — `decodeIfPresent`, Init-Default `nil`, beim Encoden via Optional weggelassen (Backups bleiben byte-identisch); (c) explizite `Sendable`-Konformität auf allen Export-DTOs (siehe Liste unten); (d) `ExportShareInfo.currentShareFormatVersion: Int` — statische Konstante `= 1`, einzige Quelle der Share-Formatversion (Rev. 4): W1 schreibt sie, die W2-Versionsmatrix (C10) vergleicht gegen sie |
| `ExportImportService+Import.swift` | eine Zeile: `importFromJSONData` von `private` auf `internal` (der Share-Einstieg C10 ruft den bestehenden Import-Kern) |

**Sendable-DTO-Liste (Seed, Grundlage für das Ausführungsmodell C10):**
`ExportArchive`, `ExportShareInfo`, `ExportCruise`, `ExportPort`,
`ExportPhoto`, `ExportExpense`, `ExportDeal`, `ExportCustomShippingLine`,
`ExportCustomShip`, `ExportHiddenCatalogItem` — alle sind reine Wertetypen
aus `String`/`Int`/`Double`/`Bool?`/Arrays; die Konformität wird explizit
deklariert (`: Sendable`), nicht nur angenommen.

**W0 enthält genau diese sechs Artefakte — nicht mehr** (abschließende
Aufzählung; W1-/W2-Schreib-Allowlists werden gegen diese Liste geprüft):
UTType-Extension · `ShipTrip-Info.plist`-Registrierung ·
`ShareArchiveLimits` · `ShareFingerprint` · DTO-Erweiterung
(`ExportShareInfo` + `share`-Feld + Sendable) · Sichtbarkeitszeile
`importFromJSONData`. Kein weiterer Code, keine Tests außer „kompiliert".

W1 und W2 ändern Seed-Symbole nicht. Einzige zugelassene Ausnahme: W2
ergänzt in `ExportImportService+Import.swift` den Archiv-Preflight-Guard
(C10, Rev. 3) — die Seed-Zeile (Sichtbarkeit) bleibt dabei unangetastet.
Sonstiger Änderungsbedarf an Seed-Artefakten = Blocker-Return an Winston.

## C1 — Dateiformat `.shiptrip`

Eine `.shiptrip`-Datei **ist** ein Backup-Archiv im bestehenden ZIP-Format
(siehe `docs/features/export-backup.md`), eingeschränkt und ergänzt:

| Eigenschaft | Wert |
|---|---|
| Container | ZIP, Compression Method 0 (STORED), CRC-32 IEEE 802.3 — identisch zum Backup |
| `data.json` | `ExportArchive`, `formatVersion: 2` — identischer Envelope wie das Backup |
| Kreuzfahrten | **genau 1** `ExportCruise` — Schreibseite erzeugt, **Archiv-Preflight erzwingt in jedem Einstiegspfad** (C10, vor jeder Mutation) |
| `deals` / `customShippingLines` / `customShips` / `hiddenCatalogItems` | leer oder fehlend — Schreibseite erzeugt, **Archiv-Preflight erzwingt in jedem Einstiegspfad** (C10) |
| Bilder | `images/<cruiseId>/<index>` und `images/<cruiseId>/ports/<index>` wie im Backup, aber **komprimiert und metadatenfrei** (siehe C4) |
| Größen-/Zählgrenzen | `ShareArchiveLimits` (C10) binden Export-Validierung und Import-Preflight; die `ZipArchiveReader`-Härtung (Zip-Slip, CRC, Entry-Limit) gilt zusätzlich unverändert |
| Demo | `isDemo == true` wird nie geteilt (Service wirft, UI blendet aus) |

Neuer **optionaler** Top-Level-Key in `data.json` (fehlt in Backups weiterhin;
`decodeIfPresent`, beim Encoden via Optional automatisch weggelassen). In einer
Share-Datei v1 sind **alle vier Felder Pflicht**:

```json
"share": {
  "shareFormatVersion": 1,
  "sharedAt": "2026-08-25T12:00:00.000Z",
  "appVersion": "1.8.0",
  "contentFingerprint": "3f5a…e2 (SHA-256-Hex)"
}
```

**`contentFingerprint` (Rev. 3 — sender-berechnet, empfänger-persistiert,
keine Rekanonisierung):** SHA-256-Hex über das JSON-Encoding des einzelnen
`ExportCruise` (JSONEncoder, nur `.sortedKeys`, ohne `.prettyPrinted`;
Bildreferenzen als ZIP-Pfade wie im Archiv) — **einmal** vom Sender beim
Export über den Seed-Helfer `ShareFingerprint` (C0) berechnet und in der
Datei gespeichert. Determinismus wird nur **senderlokal** benötigt (ein
Prozess, eine Foundation-Version; die Datumsfelder liegen im DTO bereits als
Strings des Export-`dateFormatter` vor) — geräteübergreifend byte-identische
Kanonisierung wird weder benötigt noch behauptet. Der Empfänger berechnet
den Wert **nie** nach: Beim Import wird er an der Cruise persistiert (neues
optionales Attribut `Cruise.shareContentFingerprint: String?` — optional und
damit CloudKit-konform, additive Lightweight-Migration; Eigentümer W2). Bei
einem späteren Duplikat vergleicht der Import ausschließlich gespeicherte
Werte: `share.contentFingerprint` der Datei vs. persistierter Wert (C6).
Grenzen (ehrlich): (a) lokale Empfänger-Änderungen nach dem Import ändern
den gespeicherten Wert nicht — der Hinweis bedeutet „Senderfassung ≠ damals
empfangene Fassung"; (b) Cruises ohne gespeicherten Wert (nie per Share
importiert, z. B. eigene zurückgeteilte Reise) lösen keinen Konflikt-Hinweis
aus, nur „bereits vorhanden"; (c) veränderte Bildpixel bleiben unerkannt
(Pfadreferenzen identisch) — bewusst leichtgewichtig, kein Merge, kein Sync.

**Archiv-gebundene Invariante (Kern des Formats, Rev. 3):** Ob eine Datei
Share- oder Backup-Semantik hat, entscheidet ihr **Inhalt**, nicht der
Einstiegspfad: Ein Archiv **mit** `share`-Block wird in **jedem**
Einstiegspfad (Share-Einstieg via onOpenURL, manueller `fileImporter` in den
Einstellungen, Legacy-JSON-Import) als geteilte Reise behandelt — der
Archiv-Preflight aus C10 (Versionsmatrix, Invarianten, Zählgrenzen) ist
Pflicht und läuft zentral im Import-Kern `importFromJSONData`. Ein Archiv
**ohne** `share`-Block behält in jedem Pfad unverändert die Backup-Semantik;
der bestehende manuelle Backup-Import ändert sich für Backups nicht.
**Ehrliche Einschränkung Abwärtskompatibilität:** 1.8.0-Bestands-
installationen kennen den `share`-Key nicht und importieren eine
`.shiptrip`-Datei manuell als gewöhnliches Backup — bei legitimen Dateien
(genau 1 Reise) harmlos und gewollt; eine manipulierte Mehr-Reisen-Datei
würde dort massenimportiert. Das ist ein bewusst dokumentiertes
Alt-Versions-Restrisiko (rückwirkend nicht schließbar); ab dieser Version
ist die Tür in allen Pfaden zu.

## C2 — UTType + Info.plist (`ShipTrip-Info.plist`)

| Vertrag | Wert |
|---|---|
| UTI-Identifier | `com.andre.shiptrip.cruise` |
| Datei-Endung | `shiptrip` |
| Conforms to | `public.data` (bewusst **nicht** `com.pkware.zip-archive` — sonst beanspruchen ZIP-Handler den Doppeltipp) |
| Deklaration | `UTExportedTypeDeclarations` in `ShipTrip-Info.plist` |
| Dokumenttyp | `CFBundleDocumentTypes`: `LSItemContentTypes = [com.andre.shiptrip.cruise]`, `CFBundleTypeRole = Viewer`, `LSHandlerRank = Owner` |
| Open in Place | `LSSupportsOpeningDocumentsInPlace = false` → System kopiert nach `Documents/Inbox`; die App löscht die Kopie nach dem Import (Erfolg wie Fehler) |
| Swift-Seite | `UTType.shipTripCruise` aus dem Seed (C0) |

`ShipTrip-Info.plist` und die UTType-Konstante entstehen im **Naht-Seed W0**
(C0) — inklusive des Scheme-Eintrags (C3). W1 und W2 fassen die Plist nicht an
(Merge-Konflikt-Regel).

## C3 — URL-Vertrag `shiptrip://` (+ Universal-Link-Zukunftspfad)

| Vertrag | Wert |
|---|---|
| Scheme | `shiptrip` (`CFBundleURLTypes` in `ShipTrip-Info.plist`, Seed W0/C0) |
| v1-URL | `shiptrip://import` — keine Parameter, trägt keine Daten |
| Semantik | öffnet die App; steht kein Datei-Import an, zeigt die App den Hinweis „Öffne die angehängte .shiptrip-Datei" (Link ist Beigabe, die Datei ist der Träger) |
| Unbekannte URLs | werden ignoriert (kein Fehler, kein Crash) |

```swift
/// Eine Auswertungsstelle für alle eingehenden URLs (Datei-Öffnen + Scheme).
enum IncomingLink: Equatable {
    /// file://-URL einer angetippten .shiptrip-Datei (Documents/Inbox oder Files-App).
    case shareFile(URL)
    /// shiptrip://import — nur App öffnen + Hinweis zeigen.
    case importHint
}

enum IncomingLinkRouter {
    /// nil = URL geht uns nichts an (weder .shiptrip-Datei noch bekannte shiptrip://-URL).
    static func route(_ url: URL) -> IncomingLink?
}
```

**Universal-Link-Zukunftspfad — ehrlich benannt: eine kleine Code- UND
Konfig-Änderung, kein reiner Konfigurationsschritt.** Wenn später eine Domain
existiert, braucht es: (a) Associated-Domains-Entitlement
(`applinks:<domain>`), (b) AASA-Datei unter
`/.well-known/apple-app-site-association` auf der Domain, (c) einen
zusätzlichen Handler `onContinueUserActivity(NSUserActivityTypeBrowsingWeb)`
neben dem bestehenden `onOpenURL` in `ShipTripApp`, und (d) eine neue
Router-Zeile, die `https://<domain>/import` auf `.importHint` mappt. Der
Router-Schnitt hält die Änderung klein und lokal — aber (c) und (d) sind
Code.

## C4 — Foto-Kompression (`ShareImageTranscoder`)

```swift
/// Reine, nonisolierte Funktion (Data rein, Data raus — Sendable-sicher, off-main aufrufbar).
enum ShareImageTranscoder {
    /// Verkleinert auf max. `maxPixelSize` lange Kante und encodiert als JPEG.
    /// Quelle bereits kleiner → kein Upscaling, aber Re-Encode als JPEG.
    /// Das Ausgabe-JPEG trägt KEINE Quell-Metadaten (siehe unten).
    /// nil = Eingabe ist kein dekodierbares Bild oder Encode fehlgeschlagen.
    static func downscaledJPEG(
        from data: Data,
        maxPixelSize: CGFloat = 2048,
        quality: CGFloat = 0.8
    ) -> Data?
}
```

- Zielformat **JPEG** (nicht HEIC — Begründung in ADR-007), via ImageIO nach
  dem Muster von `ImageDownsampler` (inkl. `…ThumbnailWithTransform` für die
  EXIF-Rotation).
- **Metadaten werden vollständig entfernt (Datenschutz beim Teilen):** Das
  Ausgabe-JPEG enthält keine EXIF- (insbesondere kein GPS), IPTC-, XMP- oder
  Maker-Note-Blöcke der Quelle. Die Orientierung ist in die Pixel eingebrannt
  (Thumbnail-with-Transform), ein Orientation-Tag ist nicht nötig.
  **Testanforderung (W1):** Fixture-Bild mit GPS-EXIF → Ausgabe hat via
  `CGImageSourceCopyPropertiesAtIndex` weder `{GPS}` noch `{Exif}`/`{TIFF}`-
  Quellwerte.
- Gilt für Reisefotos **und** Hafenbilder. Originale und Voll-Export bleiben
  unangetastet.
- Transcode-Fehler bei referenziertem Bild bricht den Share-Export ab
  (Alles-oder-nichts, analog `ExportError.missingMedia`).
- Der Empfänger-Import erzeugt Thumbnails wie bisher selbst
  (`ImageDownsampler.thumbnail`).

## C5 — Service-API Export-Seite (W1)

```swift
enum ShareExportError: LocalizedError {
    /// Die Beispielreise (isDemo) wird nicht geteilt.
    case demoCruise
    /// Ein Bild ließ sich nicht als Share-JPEG transkodieren — kein halbes Archiv.
    case transcodeFailed(entryName: String)
    /// Die Reise überschreitet die Share-Grenzen aus ShareArchiveLimits (C10).
    case limitExceeded(reason: String)
}

extension ExportImportService {
    /// Erzeugt die .shiptrip-Datei für genau eine Kreuzfahrt im Temp-Verzeichnis.
    ///
    /// Ablauf (siehe Design-Doc §4): MainActor-Snapshot (buildArchive mit share-Block
    /// inkl. contentFingerprint via ShareFingerprint (C0/C1), encodeArchive) → off-main
    /// Transcode-Spool auf Disk → Größen-/Zählvalidierung gegen ShareArchiveLimits (C10)
    /// über die Spool-Größen → ZipArchiveStreamWriter liest die Einträge aus dem Spool.
    /// Alles-oder-nichts wie exportToZip; Spool + Zieldatei werden im Fehlerfall gelöscht.
    ///
    /// Dateiname: "<Titel-Slug>.shiptrip" (Slug: Alphanumerik/Bindestrich, Umlaute
    /// transliteriert, leer → "Kreuzfahrt"), in einem frischen Temp-Unterordner,
    /// damit der Anzeigename im Share-Sheet stimmt und Kollisionen ausscheiden.
    /// Der Aufrufer löscht die Datei nach Abschluss der Share-Präsentation
    /// (Muster: bestehender ShareSheet-Completion-Handler in SettingsView).
    func exportCruiseForSharing(_ cruise: Cruise) async throws -> URL
}
```

Wiederverwendung (verbindlich): `buildArchive` + `encodeArchive` +
`ExportImageSource` (Roh-Bytes-Lieferant, MainActor) + `ZipArchiveStreamWriter`.
Die Größenvalidierung läuft gegen `ShareArchiveLimits` (C10), nicht gegen die
weiteren Backup-Grenzen. Neu sind nur Transcode-Spool, `share`-Metadaten,
Einzel-Cruise-Zuschnitt und Dateiname.

## C6 — Import-Seite (W2)

```swift
/// Ergebnis des Share-Einstiegs: bestehender ImportResult + Konflikt-Signal (C1-Fingerprint).
struct ShareImportResult {
    let base: ImportResult
    /// true = Cruise-id existiert bereits UND an der lokalen Cruise ist ein
    /// shareContentFingerprint persistiert, der vom share.contentFingerprint der
    /// Datei abweicht (Senderfassung ≠ damals empfangene Fassung, C1 Rev. 3).
    /// Kein persistierter Wert (nie share-importiert) ⇒ false — nur „bereits vorhanden".
    let versionConflict: Bool
}

/// Zustand des automatischen Imports; treibt die Präsentation in ShipTripApp.
@MainActor @Observable
final class ShareImportCoordinator {
    enum State: Equatable {
        case idle
        case importing
        /// Import gelaufen (auch 0 importiert = „bereits vorhanden").
        /// versionConflict = Duplikat mit abweichender Senderfassung → Ergebnis-Sheet
        /// zeigt den Versionskonflikt-Hinweis (C8). Weiterhin KEIN Merge.
        case finished(imported: Int, skippedDuplicates: Int, skippedInvalid: Int,
                      invalidMedia: Int, versionConflict: Bool)
        /// Menschlicher Fehlertext (LocalizedError des Import-/Preflight-Pfads); nie ein Crash.
        case failed(message: String)
        /// shiptrip://import ohne anstehende Datei — Hinweis zeigen.
        case linkHint
    }

    private(set) var state: State

    /// Einstieg für onOpenURL (Datei ODER Scheme; Kalt- und Warmstart identisch).
    /// Single-Flight (C10): während state == .importing werden weitere URLs verworfen
    /// (kein zweiter Task, keine Queue); in jedem anderen Zustand ersetzt die neue URL
    /// die aktuelle Präsentation. Datei-Pfad: startAccessingSecurityScopedResource
    /// best-effort (Files-App braucht es, Inbox nicht), dann der zweistufige
    /// Share-Import nach C10, dann Inbox-/Arbeitskopie löschen.
    /// Fehler → .failed, kein throw nach außen.
    func handleIncomingURL(_ url: URL, modelContext: ModelContext)

    /// Setzt state auf .idle (Sheet/Alert geschlossen).
    func dismiss()
}
```

- Der Share-Einstieg läuft über den **zweistufigen Preflight-Pfad C10**
  (neue Datei `ExportImportService+ShareImport.swift`, Eigentümer W2); die
  Mutation selbst ist der **bestehende** Import-Kern `importFromJSONData`
  (Sichtbarkeit via Seed C0) — Dedup, Validierung, Rollback inklusive; W2
  implementiert keinen eigenen Parser. W2 besitzt zusätzlich (Rev. 3): den
  Archiv-Preflight-Guard im Import-Kern (`ExportImportService+Import.swift`,
  C10) und das additive Attribut `Cruise.shareContentFingerprint: String?`
  (`Cruise.swift`, C1 — optional, CloudKit-konform, Lightweight-Migration).
- Verdrahtung in `ShipTripApp`: `onOpenURL` + Ergebnis-Präsentation hängen
  **oberhalb von `.modelContainer(container)`** in der Modifier-Kette (der
  Container-Modifier bleibt zuunterst und umhüllt alles — Lehre aus dem
  Onboarding-Demo-Bug, siehe Kommentar in `ShipTripApp.swift`).
- `SettingsView.fileImporter` nimmt zusätzlich `.shipTripCruise` in
  `allowedContentTypes` auf (eine Zeile, W2). Ob die Datei dort als Share
  oder Backup behandelt wird, entscheidet **nicht** der Einstiegspfad und
  nicht die Endung, sondern der `share`-Block im Archiv (archiv-gebundene
  Invariante, C1/C10 Rev. 3) — der Guard im Import-Kern greift automatisch;
  `SettingsView` selbst braucht keine Share-Logik.

## C7 — Teilen-UI (W3)

- Teilen-Aktion in der Reise-Detailansicht; für `isDemo`-Reisen nicht
  sichtbar.
- Share-Items: `[fileURL, nachrichtentext]` über den bestehenden
  `ShareSheet`-Wrapper (UIActivityViewController) — Datei + Text landen
  gemeinsam in Nachrichten/WhatsApp/Mail. Der Text enthält den
  `shiptrip://import`-Link (C3).
- Temp-Datei-Löschung im Completion-Handler (Muster SettingsView-Export).

## C8 — Neue String-Katalog-Keys (Katalog gesperrt — genau diese, DE/EN)

| Key (sinngemäß) | Zweck |
|---|---|
| „Reise teilen" | Button Reise-Detail (W3) |
| Nachrichtentext („Ich habe dir eine Kreuzfahrt aus ShipTrip geschickt …") inkl. Link | Share-Text (W3) |
| „Reise importiert" | Ergebnis Erfolg (W2) |
| „Diese Reise ist bereits vorhanden." | Ergebnis Duplikat (W2) |
| „Diese Reise ist bereits vorhanden — die geteilte Fassung weicht von deiner ab." | Ergebnis Versionskonflikt (W2, C6) |
| „Import fehlgeschlagen: %@" | Ergebnis Fehler (W2) |
| „Diese Datei ist keine gültige geteilte Reise." | Preflight: Invarianten verletzt / share-Block fehlt (W2, C10) |
| „Diese Datei benötigt eine neuere Version von ShipTrip." | Preflight: unbekannte Version (W2, C10) |
| „Die Datei überschreitet die Grenzen für geteilte Reisen." | Preflight: Limits (W2, C10) |
| „Öffne die angehängte .shiptrip-Datei, um die Reise zu importieren." | Link-Hinweis (C3, W2) |
| „Teilen fehlgeschlagen: %@" | Export-Fehler (W3) |

Exakte Wortlaute entscheidet W2/W3 im Diff; die Liste ist die Obergrenze —
weitere Keys nur mit Winston-Freigabe.

## C9 — Accessibility-Identifier (für UI-Tests)

| Identifier | Element |
|---|---|
| `cruiseDetail.shareButton` | Teilen-Aktion in der Detailansicht |
| `shareImport.resultSheet` | Ergebnis-Präsentation des Imports |
| `shareImport.linkHintSheet` | Hinweis-Präsentation nach `shiptrip://import` |

## C10 — Share-Import-Preflight, Limits, Versionsmatrix, Ausführungsmodell (W2)

Der automatische Share-Einstieg (`importSharedCruise` in
`ExportImportService+ShareImport.swift`, neue Datei, Eigentümer W2) prüft
**alles vor der ersten Datenbank-Mutation**.

**Zwei Preflight-Schichten (Rev. 3 — archiv-gebunden statt pfad-gebunden):**

- **Transport-Preflight (nur Share-Einstieg, Stufe A):** Schritte 1–4 der
  Reihenfolge unten — Dateigröße, Extraktion, Payload- und `data.json`-Deckel
  gegen `ShareArchiveLimits`.
- **Archiv-Preflight (bindet an den `share`-Block, gilt in JEDEM Pfad):**
  Schritte 5–7 — Versionsmatrix, Invarianten, Zählgrenzen. Implementiert
  **genau einmal** als Guard am Anfang des Import-Kerns `importFromJSONData`
  (W2): `archive.share != nil` ⇒ prüfen, jede Verletzung wirft
  `ShareImportError` vor jeder Mutation. Damit gilt er automatisch für
  onOpenURL, den manuellen `fileImporter` und den Legacy-JSON-Import. Der
  Share-Einstieg prüft 5–7 zusätzlich bereits in Stufe A (früher, lokalisierter
  Fehler ohne MainActor-Hop); die Doppelprüfung ist idempotent und mutationsfrei.

Der manuelle Pfad **ohne** `share`-Block bleibt Backup-Semantik (C1). Seine
Größenabwehr bleibt die bestehende `ZipArchiveReader`-Härtung (Entry-Limit
50 MB, Zip-Slip, CRC) — die Größendeckel 1/3/4 der `ShareArchiveLimits`
binden den manuellen Pfad bewusst nicht (Backup-Pfad unverändert).

**Grenzkonstanten `ShareArchiveLimits` (Seed C0; binden Export C5 UND
Import-Preflight):**

| Konstante | Wert | Zweck |
|---|---|---|
| `maxArchiveFileSize` | 275 MB | Datei-Stat vor jeder Verarbeitung |
| `maxPayloadSize` | 250 MB | Summe der entpackten Einträge |
| `maxDataJSONSize` | 10 MB | Deckel auf den JSON-Dekodieraufwand |
| `maxPorts` | 100 | Häfen der einen Cruise |
| `maxPhotos` | 300 | Reisefotos + Hafenbilder gesamt (≈ 240 MB bei 2048 px/q0,8) |
| `maxExpenses` | 1000 | Ausgaben der einen Cruise |

Das Entry-Limit (50 MB) sowie Zip-Slip-, CRC- und Header-Härtung des
`ZipArchiveReader` gelten zusätzlich unverändert.

**Preflight-Reihenfolge (prüfbar, jede Verletzung → `ShareImportError`, keine
Mutation):**

1. Dateigröße ≤ `maxArchiveFileSize` (Stat, vor Extraktion).
2. Extraktion über den bestehenden `ZipArchiveReader` (bestehende Härtung).
3. Summe der entpackten Einträge ≤ `maxPayloadSize`.
4. `data.json` ≤ `maxDataJSONSize`, erst dann `JSONDecoder`.
5. Versionsmatrix (unten): `formatVersion` == 2, `share`-Block vorhanden,
   `shareFormatVersion` == 1.
6. Invarianten: **genau 1** Cruise; `deals`/`customShippingLines`/
   `customShips`/`hiddenCatalogItems` leer oder fehlend.
7. Zählgrenzen: Häfen/Fotos/Ausgaben ≤ `maxPorts`/`maxPhotos`/`maxExpenses`.

**Versionsmatrix (Rev. 3 — Totalfunktion):** Die Matrix arbeitet auf den
**dekodierten** Werten des Bestands-Decoders (`ExportArchive.decode`):
fehlender `formatVersion` dekodiert dort zu 2 (Default), das 1.7-Top-Level-
Array zu 1 und kann strukturell keinen `share`-Block tragen. Damit ist die
Matrix total über (`share`-Block?, `formatVersion` ∈ ℤ,
`shareFormatVersion` ∈ ℤ) × Einstiegspfad — jede Kombination trifft genau
eine Zeile:

| `share`-Block | `formatVersion` | `shareFormatVersion` | Verhalten (Archiv-Preflight, jeder Pfad) |
|---|---|---|---|
| vorhanden | == 2 | == 1 | akzeptieren (Share-Import) |
| vorhanden | == 2 | > 1 | ablehnen `unsupportedVersion` — „neuere Version nötig" (C8) |
| vorhanden | == 2 | < 1 | ablehnen `notAShareFile` — kein legitimer Wert existiert unterhalb von v1; „neuere Version nötig" wäre gelogen (begründete Abweichung von der Symmetrie-Leitplanke) |
| vorhanden | > 2 | beliebig | ablehnen `unsupportedVersion` — „neuere Version nötig" |
| vorhanden | < 2 | beliebig | ablehnen `notAShareFile` — `share` existiert erst ab Envelope 2, nur manipuliert erreichbar |
| fehlt | beliebig | — | **Backup-Semantik.** Share-Einstieg: ablehnen `notAShareFile` („keine gültige geteilte Reise", verhindert Massenimport). Manueller Pfad: importieren wie bisher — der Bestands-Decoder ist ausdrücklich tolerant, dekodiert bekannte Felder und ignoriert unbekannte; das gilt auch für zukünftige `formatVersion > 2` (Bestandsverhalten, in diesem Run unverändert). |

**Fehlertyp:**

```swift
enum ShareImportError: LocalizedError, Sendable {
    /// share-Block fehlt (am Share-Einstieg), share-Block mit unplausibler Version
    /// (shareFormatVersion < 1 oder formatVersion < 2), mehr als 1 Cruise oder
    /// nicht-leere Sammlungen (Invarianten, C1 + Versionsmatrix).
    case notAShareFile
    /// formatVersion > 2 oder shareFormatVersion > 1 bei vorhandenem share-Block.
    case unsupportedVersion
    /// Eine ShareArchiveLimits-Grenze verletzt.
    case limitExceeded(reason: String)
}
```

**Ausführungsmodell (Rev. 3 — konkreter Übergang statt `nonisolated`-
Hoffnung):** zweistufig. Der Off-Main-Transfer ist explizit — `nonisolated`
allein garantiert unter Swift 6.x keinen Off-Main-Executor und wird nicht
als Garantie verwendet.

- **Stufe A** ist eine synchrone, zustandslose Funktion
  `enum SharePreflight { static func run(_ url: URL) throws(ShareImportError) -> SharePreflightResult }`
  — Stat, Extraktion, Payload-/JSON-Größencheck, Envelope-Decode,
  Versionsmatrix, Invarianten, Zählgrenzen; ausschließlich auf
  `URL`/`Data`/Export-DTOs, kein `@Model`, kein `ModelContext`.
  **Off-Main garantiert der Aufrufer:** Der Coordinator (MainActor) startet
  genau einen Task (Single-Flight) und führt darin
  `try await Task.detached(priority: .userInitiated) { try SharePreflight.run(url) }.value`
  aus.
- **Übergabetyp:** `struct SharePreflightResult: Sendable` mit
  `dataJSON: Data`, `imagesDir: URL`, `envelope: ExportArchive`. Die
  Sendable-Grundlage liefert der Seed W0: alle Export-DTOs der C0-Liste
  tragen explizite `Sendable`-Konformität; `ShareImportError` ist als Enum
  mit `String`-Payload ebenfalls `Sendable`.
- **Rückweg auf den MainActor:** `handleIncomingURL` ist `@MainActor`; der
  umgebende Task erbt diese Isolation. Nach `await ….value` läuft die
  Fortsetzung deshalb wieder auf dem MainActor — dort führt **Stufe B**
  synchron aus: Mutation über den bestehenden Import-Kern
  `importFromJSONData` + Konfliktprüfung (persistierter
  `Cruise.shareContentFingerprint` vs. `share.contentFingerprint` der Datei,
  C1 Rev. 3 — keine Neuberechnung). `@Model`/`ModelContext` überqueren nie
  eine Aktorgrenze; über die Grenze wandern nur `URL` + `SharePreflightResult`.
- **Kein `@ModelActor`-Umbau:** Die Mutation ist durch „genau 1 Cruise" +
  `ShareArchiveLimits` klein gebunden; ein zweiter Import-Kern in einem
  ModelActor würde die Dedup-/Rollback-Logik duplizieren (Begründung
  ADR-007, Revision).
- **Single-Flight:** siehe C6 — während `.importing` werden weitere
  URL-Events verworfen; es läuft nie mehr als ein Import-Task.
