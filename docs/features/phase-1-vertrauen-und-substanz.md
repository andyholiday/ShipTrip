# Phase 1 — Vertrauen und Substanz

**Released:** v1.5.0 (build 5), 2026-06-15, TestFlight  
**Status:** Abgeschlossen  
**Testsuite:** 27/27 Unit-Tests + 3 UI-Tests gruen, Build verifiziert  
**Datum:** 2026-06-14

## Beschreibung

Phase 1 legt das technische Fundament fuer dauerhaften Nutzervertrauen: stabile,
CloudKit-taugliche Modelle, ein verlustfreier ZIP-Export, speicherschonende
Foto-Thumbnails in Listen, echte SwiftData-Reaktivitaet statt eines
Workaround-Hacks, geraetebasierte Waehrungsdarstellung und eine vollstaendige
Zweisprachigkeit (DE/EN). Diese Aenderungen vorbereiten ausserdem die CloudKit-
Aktivierung als separaten Folgeschritt (siehe Bekannte Einschraenkungen).

---

## Aenderung 1 — Stabile Modell-IDs, CloudKit-ready-Schema und explizite Inverse-Relationships

### Was / Warum

v1.5.0 liefert ein CloudKit-taugliches Schema, aktiviert CloudKit jedoch **nicht**.
`ModelConfiguration` verwendet kein `cloudKitDatabase`; die iCloud-Entitlements sind
nicht im App-Bundle enthalten. Die Aktivierung erfolgt als separater, dedizierter Build
gemaess dem Zwei-Stufen-Migrationsplan aus
[ADR-002](../adr/ADR-002-cloudkit-sync-und-stabile-ids.md).

Die folgenden Schema-Anpassungen sind in v1.5.0 enthalten:

- Jedes Modell erhaelt ein explizites `var id: UUID = UUID()` als stabilen
  App-seitigen Schluessel (kein `@Attribute(.unique)` — das ist unter CloudKit
  verboten; Eindeutigkeit ist App-Aufgabe).
- `Photo.imageData` wurde von `Data` ohne Default auf `Data = Data()` umgestellt,
  damit das Attribut CloudKit-Anforderungen erfuellt.
- `Photo.thumbnailData` wurde als `Data?` ergaenzt (Aufnahme-Punkt fuer Thumbnails,
  optional — kein CloudKit-Constraint-Problem).
- Alle Relationships sind jetzt mit explizitem `inverse:`-Parameter deklariert
  (`Port.cruise`, `Expense.cruise`, `Photo.cruise` zeigen auf `Cruise`); der
  Compiler warnt nicht mehr.
- `updatedAt: Date = Date()` ist auf `Cruise`, `Deal`, `Port`, `Expense` und `Photo`
  vorhanden. Das Feld muss in jedem Schreibpfad manuell auf `Date()` gesetzt werden
  (SwiftData tut das nicht automatisch); es dient als Entscheidungsgrundlage fuer
  Last-Writer-Wins bei einem kuenftigen CloudKit-Sync-Konflikt.

### Beruerhrte Dateien

- `ShipTrip/Models/Cruise.swift`
- `ShipTrip/Models/Deal.swift`
- `ShipTrip/Models/Expense.swift`
- `ShipTrip/Models/Photo.swift`
- `ShipTrip/Models/Port.swift`

### Acceptance-Status

Verifiziert durch Build (keine Compiler-Warnungen zu fehlenden Inverses) und
Review der Modell-Properties. `updatedAt`-Bump in jedem Schreibpfad ist **nicht**
durch automatisierte Tests abgedeckt — Code-Review-Checkliste empfohlen.

---

## Aenderung 2 — ZIP-Export mit externen Bilddateien (verlustfrei)

### Was / Warum

Der bisherige Base64-in-JSON-Export skaliert nicht: ein einziges Foto mit 3 MB
produziert ca. 4 MB Base64. Das neue Format schreibt ein ZIP-Archiv mit zwei
Bestandteilen:

- `data.json` — alle strukturierten Reisedaten; Fotos werden als Pfadreferenzen
  `images/<cruiseId>/<index>` eingetragen.
- `images/<cruiseId>/<index>` — Rohbytes aus `Photo.imageData`, direkt ohne
  UIImage-Re-Encoding; damit ist der Export bit-exakt verlustfrei.

Weitere Eigenschaften der Implementierung:

- ZIP-Methode 0 (STORED, kein Deflate) mit korrektem CRC-32 (IEEE 802.3-Polynom).
- Overflow-Guard: `tooManyEntries`-Fehler bei mehr als 65.535 Eintraegen (UInt16-Limit),
  `entryTooLarge`-Fehler bei einzelnen Eintraegen ueber UInt32-Grenze; lieber explizit
  werfen als still truncaten.
- Stabile IDs im Export: `cruise.id`, `port.id` und `expense.id` werden als UUID-String
  exportiert und beim Import unveraendert uebernommen — kein frisches `UUID()`.
- ID-basierte Duplikat-Erkennung beim Import; Fallback auf `title + startDate + ship`
  fuer Legacy-Importe ohne gueltige UUID.
- Rueckwaertskompatibilitaet: der alte `data:image/png;base64,...`-Import-Pfad bleibt
  aktiv; fehlende Bilddateien in einem ZIP werden toleriert (Photo wird uebersprungen,
  Cruise bleibt).

### Beruerhrte Dateien

- `ShipTrip/Services/ExportImportService.swift`
- `ShipTrip/Views/Settings/SettingsView.swift`

### Acceptance-Status

Durch 4 ZIP-Unit-Tests in `ShipTripTests/ShipTripTests.swift` abgedeckt
(`ExportImportService ZIP`-Suite, 27/27 gruen):

- `zipRoundtripPreservesStableID` — stabile ID nach Export+Import erhalten
- `zipReimportIsIdempotent` — Re-Import zaehlt Duplikate via ID, keine Dubletten
- `legacyBase64JSONImport` — altes Base64-Format importiert weiterhin korrekt
- `zipPhotoRoundtripLosslessAndThumbnail` — `imageData` byte-identisch nach
  Roundtrip; `thumbnailData` ist nach Import gesetzt

---

## Aenderung 3 — Foto-Thumbnails und Downsampling in Listen

### Was / Warum

Kreuzfahrten mit vielen Hochaufloesungsfotos fuehrten zu hohem Speicherbedarf in
Listenansichten, weil `UIImage(data: fullResData)` das vollstaendige Bild dekodiert.

Loesungsansatz (drei Ebenen):

1. **`ImageDownsampler`** (`Utilities/ImageDownsampler.swift`) — nutzt
   `CGImageSourceCreateThumbnailAtIndex` aus ImageIO; dekodiert nicht das volle Bild,
   sondern erstellt direkt ein JPEG-Vorschaubild (max. 600 px Kantenlange, Qualitaet 0.75).
   Dieser Ansatz hat wesentlich weniger Speicherbedarf als der `UIImage`-Pfad.

2. **Synchrone Thumbnail-Generierung beim Hinzufuegen** — `CruiseFormView.swift` ruft
   `ImageDownsampler.thumbnail(from: data)` sofort nach dem Photo-Picker auf und schreibt
   das Ergebnis in `photo.thumbnailData`.

3. **Backfill beim Launch** — `ThumbnailBackfill.run(context:)` wird in `CruiseListView`
   als `.task` gestartet; er holt alle `Photo`-Objekte mit `thumbnailData == nil` und
   befuellt sie per `Task.detached` im Hintergrund. Die Funktion ist idempotent.

Beim Import (ZIP und Base64) generiert `ExportImportService` ebenfalls sofort ein
Thumbnail und setzt `photo.thumbnailData`.

**Detailansicht**: `CruiseDetailView` nutzt bewusst `photo.imageData` (Vollaufloesung),
weil in der Lightbox-Ansicht die Qualitaet wichtiger ist als der Speicherbedarf.

### Beruerhrte Dateien

- `ShipTrip/Utilities/ImageDownsampler.swift` (neu)
- `ShipTrip/Utilities/ThumbnailBackfill.swift` (neu)
- `ShipTrip/Views/Cruises/CruiseCardView.swift` (nutzt `thumbnailData ?? imageData`)
- `ShipTrip/Views/Cruises/CruiseDetailView.swift` (nutzt `imageData`, Vollaufloesung)
- `ShipTrip/Views/Cruises/CruiseFormView.swift` (generiert Thumbnail beim Hinzufuegen)
- `ShipTrip/Views/Cruises/CruiseListView.swift` (startet `ThumbnailBackfill`)

### Acceptance-Status

`CruiseCardView` nutzt `thumbnailData ?? imageData` — bei fehlenden Thumbnails wird
automatisch auf Vollaufloesung zurueckgefallen (kein Datenverlust).
Kein dedizierter Unit-Test fuer Thumbnail-Groesse; Backfill-Idempotenz ist durch den
Import-Test `zipPhotoRoundtripLosslessAndThumbnail` indirekt abgedeckt.

---

## Aenderung 4 — `refreshID`-Hack entfernt, echte SwiftData-Reaktivitaet via `@Bindable`

### Was / Warum

`CruiseDetailView` nutzte einen `@State var refreshID = UUID()`, der bei Aenderungen
neu generiert wurde (`id(refreshID)`), um SwiftData-Aenderungen in der View zu triggern.
Dieses Muster umgeht die native Reaktivitaet von SwiftData und fuehrt zu ueberfluessigen
View-Rebuilds.

Behoben: Die Property wird jetzt als `@Bindable var cruise: Cruise` deklariert. SwiftData
benachrichtigt die View automatisch, wenn beobachtete Properties des Modell-Objekts sich
aendern — kein manueller Redraw-Trigger mehr noetig.

### Beruerhrte Dateien

- `ShipTrip/Views/Cruises/CruiseDetailView.swift`

### Acceptance-Status

Verifiziert durch Code-Review (keine `refreshID`-Referenz in `CruiseDetailView.swift`).

---

## Aenderung 5 — Geraetebasierte Waehrung und Zweisprachigkeit DE/EN

### Was / Warum

**Waehrung:** `Expense.formattedAmount` nutzte zuvor hartes `"EUR"`. Jetzt wird
`Locale.current.currency?.identifier ?? "EUR"` verwendet, sodass die Waehrungsdarstellung
der Geraete-Lokalisierung folgt. Das Kommentarfeld `/// Betrag in EUR` wurde nicht
bereinigt (liegt ausserhalb des Aenderungsscopes); der Datenbankwert bleibt `Double` ohne
Waehrungssymbol.

**Lokalisierung:** Das Projekt hat ein Xcode String Catalog (`Localizable.xcstrings`) mit
Deutsch als Entwicklungssprache (`sourceLanguage: "de"`) und Englisch als zweiter Sprache.
Der Katalog enthaelt 177 Strings (verifiziert), alle mit `"state": "translated"` fuer
Englisch. Alle User-sichtbaren Strings in den Views verwenden `String(localized:)` oder
`Text("key")` mit Schluesseln aus dem Katalog.

**Tab-Umbenennung:** Der Tab „Angebote" wurde in „Merkliste" umbenannt
(Label in `MainTabView.swift`). `DealsView` und das zugrundeliegende `Deal`-Modell
behalten ihre technischen Namen; nur die Benutzerflaeche aendert sich. Die neue
Bezeichnung ist ehrlicher — der Tab speichert gemerkete Angebote, nicht ein aktives
Angebots-Feed.

### Beruerhrte Dateien

- `ShipTrip/Localizable.xcstrings`
- `ShipTrip/Models/Expense.swift` (Waehrungsformatierung)
- `ShipTrip/Models/Deal.swift` (lokalisierte Strings)
- `ShipTrip/Views/MainTabView.swift` (Tab-Label „Merkliste")
- `ShipTrip/Views/Deals/DealsView.swift`
- Alle weiteren Views, die `String(localized:)` oder `Text("key")` verwenden

### Acceptance-Status

Verifiziert durch Code-Review von `MainTabView.swift` (Label „Merkliste" und
systemImage „bookmark" bestaetigt). String-Zaehlung: 177 Strings im Katalog
(python3-Pruefung auf `Localizable.xcstrings`). Vollstaendige UI-Pruefung beider
Sprachen ist manuell; kein automatisierter Screenshot-Test vorhanden.

---

## Bekannte Einschraenkungen / Offene Punkte

**(a) CloudKit-Sync ist in v1.5.0 nicht enthalten — Aktivierung in separatem Build**  
v1.5.0 enthaelt ausschliesslich die Schema-Vorbereitung (Schritt 1 des Zwei-Stufen-
Migrationsplans aus [ADR-002](../adr/ADR-002-cloudkit-sync-und-stabile-ids.md)).
CloudKit ist bewusst **deaktiviert**: `ModelConfiguration` hat kein `cloudKitDatabase`,
und die iCloud-Entitlements sind nicht im Bundle (`ShipTrip.entitlements` enthaelt nur
`com.apple.security.app-sandbox` und `com.apple.security.files.user-selected.read-only`).

Die verbleibenden Schritte fuer den Folge-Build:

- Manuelle Xcode-Schritte: iCloud-Capability hinzufuegen, Container
  `iCloud.com.andre.ShipTrip` registrieren, Push-Notification-Background-Mode aktivieren.
- Smoke-Test auf einem bevoelkerten Store mit echtem iCloud-Account (kein Simulator).
- Erst danach Aktivierung als eigenstaendiges Release.

**(b) Resilientes Store-Laden (v1.5.0)**  
`ShipTripApp` versucht beim Start den persistenten SQLite-Store. Schlaegt dieser fehl,
wird automatisch auf einen In-Memory-Store ausgewichen und der Nutzer erhaelt einen
Alert ("Daten nicht verfuegbar"). Schlaegt auch der In-Memory-Fallback fehl, zeigt
`StoreUnavailableView` (`ContentUnavailableView`) einen klaren Fehlerhinweis —
kein `fatalError` wird mehr ausgeloest. Der In-Memory-Store speichert keine Daten
ueber den App-Neustart hinaus; Nutzer werden im Alert auf die Export/Import-Funktion
zur Wiederherstellung hingewiesen.

**(c) `updatedAt` wird nicht automatisch gebumpt**  
SwiftData setzt `updatedAt` nicht selbst; jeder Schreibpfad muss `updatedAt = Date()`
explizit setzen. Fehlende Bumps fuehren bei aktivem CloudKit zu stillem Datenverlust
durch Last-Writer-Wins. Eine Code-Review-Checkliste wird empfohlen.

**(d) ZIP-Format ohne ZIP64-Unterstuetzung**  
Einzelne Eintraege sind auf UInt32 Bytes (~4 GB) begrenzt; bei mehr als 65.535 Eintraegen
wird ein Fehler geworfen. Fuer reale Kreuzfahrt-Exporte unrealistisch, aber dokumentiert.

**(e) Waehrungskommentar in `Expense.swift` noch auf "EUR"**  
Der Docstring `/// Betrag in EUR` beschreibt noch das alte Verhalten; der tatsaechliche
Code nutzt bereits die Geraete-Waehrung. Kosmetische Korrektur steht aus.

**(f) Kein automatisierter Test fuer `updatedAt`-Bump und Tab-Lokalisierung**  
Beide werden durch Code-Review abgedeckt, nicht durch Unit-Tests.

---

## Verwandte Entscheidungen

- [ADR-001: `isDemo`-Attribut bleibt build-konfigurationsunabhaengig im Schema](../adr/ADR-001-isdemo-in-release-schema.md)
  — gleiche Schema-Stabilitaets-Motivation wie Phase 1
- [ADR-002: CloudKit-Sync, stabile IDs und ZIP-Export](../adr/ADR-002-cloudkit-sync-und-stabile-ids.md)
  — treibt Aenderungen 1, 2 und die CloudKit-Vorbereitung
