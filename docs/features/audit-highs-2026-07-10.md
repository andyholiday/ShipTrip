# Audit-Fixes 2026-07-10 — High-Findings (H1–H8)

**Status:** Abgeschlossen
**Testsuite:** 290 Unit-Tests grün, alle funktionalen UI-Suiten grün (inkl. neuer
`CruiseDeletionSequenceTests`, `CruiseLoeschenFilterUITests`, `DealLoeschenUITests`), EN-UI-
Smoke grün (`EnglishLocalizationSmokeUITests`)
**Quelle:** [Umsetzungsplan Audit 2026-07-10](../umsetzungsplan-audit-2026-07-10.md),
[Voll-Audit 2026-07-10](../../audit/audit-2026-07-10.html)

## Beschreibung

Diese Welle behebt alle acht High-Findings (H1–H8) aus dem Voll-Audit vom 10.07.2026 —
Wellen S1 (Release-Sicherheit) und die H6/H8-Anteile aus S2.1/S2.2 im
Umsetzungsplan. Medium- und Low-Findings (S2.3, S2.4, S3.x, S4.x) sind bewusst
zurückgestellt, bis Andre sie aufruft. Schwerpunkte: fehlender Reset-Weg im
Reisen-Filter, ungesicherte Lösch-Pfade für Reisen und Deals, ein instabiler
Hafen-Editor-Modus-Switch, eine Seetag-Fehlklassifikation beim Import, ein
fehlendes Privacy-Manifest, eine unvollständig lokalisierte UI sowie ein
ungehärteter ZIP-Restore-Pfad.

---

## H1 — Filter-Dead-End in der Reiseliste (Task S1.1)

### Was / Warum

Der Jahres-/Reederei-Filter in `CruiseListView` konnte in einen Zustand ohne
Treffer führen, aus dem es im Empty-State keinen sichtbaren Ausweg gab. Der
`ContentUnavailableView` im gefilterten Leerzustand zeigt jetzt einen
„Filter zurücksetzen"-Button (destructive Rolle).

### Berührte Dateien

- `ShipTrip/Views/Cruises/CruiseListView.swift`

### Acceptance-Status

Erfüllt. `ShipTripUITests/CruiseLoeschenFilterUITests.swift` deckt den Weg
„Filter ohne Treffer → Reset erreichbar" ab.

---

## H5 — Löschen ohne Bestätigung/Rollback (Task S1.1)

### Was / Warum

Das Löschen einer Reise (Context-Menü in Liste und Detail) lief bisher ohne
Bestätigungsdialog und ohne Rollback bei fehlgeschlagenem `save()`. Die neue
`CruiseDeletionSequence.run(...)` (in `CruiseListView.swift` definiert, von
`CruiseListView` und `CruiseDetailView` genutzt) kapselt die Sequenz
`modelContext.delete` → `try save()` → bei Fehler `modelContext.rollback()`;
erst nach erfolgreichem Speichern werden geplante Erinnerungen entfernt. Beide
Aufrufstellen zeigen vorher einen `confirmationDialog`.

### Berührte Dateien

- `ShipTrip/Views/Cruises/CruiseListView.swift` (`CruiseDeletionSequence`,
  `confirmationDialog`)
- `ShipTrip/Views/Cruises/CruiseDetailView.swift` (nutzt dieselbe Sequenz)

### Acceptance-Status

Erfüllt. `ShipTripTests/CruiseDeletionSequenceTests.swift` prüft Erfolgs- und
Rollback-Pfad der Sequenz isoliert; UI-Bestätigungsdialog manuell verifiziert.

---

## H2 — Instabiler Modus-Switch im Hafen-Editor (Task S1.2, inkl. M5)

### Was / Warum

`PortFormView` unterschied Such- und manuellen Eingabemodus bisher implizit
über `if name.isEmpty`, was bei bestehenden Häfen zu unvorhersagbarem
Verhalten führte. Der Editor hat jetzt einen expliziten Modus-Switch inkl.
Rückweg „Zur Suche"; Bestands-Ports lassen sich in beiden Modi bearbeiten.
Zusätzlich (M5, gleiche Zeilen wie H2): ein locale-toleranter
`NumberFormatter`-Parser für Breiten-/Längengrad akzeptiert sowohl Komma als
auch Punkt als Dezimaltrennzeichen statt des bisherigen `Double(latitude) ?? 0`.

### Berührte Dateien

- `ShipTrip/Views/Cruises/PortFormView.swift`

### Acceptance-Status

Erfüllt. `ShipTripTests/PortFormViewTests.swift` deckt Komma-/Punkt-Parsing
inkl. Grenzfällen ab; manuelle Neuanlage und Korrektur eines Bestands-Ports
per UI verifiziert.

---

## H4 — Hero-Deal nicht löschbar (Task S1.3)

### Was / Warum

Der neueste („Hero"-)Deal ließ sich in `DealsView` nicht löschen. Beide
Lösch-Einstiege — Context-Menü auf der Hero-Karte und Delete-Button im
`DealFormView` — nutzen jetzt denselben bestätigten Pfad: `confirmationDialog`
+ `.alert("Eintrag löschen?", …)` vor dem Löschen, `.alert("Info", …)` bei
Fehlern.

### Berührte Dateien

- `ShipTrip/Views/Deals/DealsView.swift`

### Acceptance-Status

Erfüllt. `ShipTripUITests/DealLoeschenUITests.swift` deckt „neuester Deal
löschbar" ab.

---

## H3 — Seetag-Fehlklassifikation beim Import (Task S1.4)

### Was / Warum

`ExportImportService` klassifizierte Häfen ohne Koordinaten (`lat == nil`)
beim Import fälschlich als Seetag und überschrieb dabei den echten
Hafennamen. `isSeaDay` ist jetzt ein optionales DTO-Feld
(`decodeIfPresent`, Default `nil`): Alt-ZIPs/Legacy-JSON ohne das Feld bleiben
dekodierbar über einen Namens-Fallback („Seetag"/„Sea Day"), neue Exporte mit
explizitem Flag haben Vorrang. Der Export (`buildExportCruises`) überschreibt
den Hafennamen nie mehr.

### Berührte Dateien

- `ShipTrip/Services/ExportImportService.swift`
- `ShipTripTests/ExportImportHardeningTests.swift`

### Acceptance-Status

Erfüllt. Regressionstest „koordinatenloser echter Hafen übersteht
Export→Import→Export mit Name+Land"; getrennte Fixtures für Alt-Format (ohne
Flag) und Neu-Format (mit Flag), beide grün.

---

## H7 — Fehlendes Privacy-Manifest (Task S1.5)

### Was / Warum

Der App fehlte ein `PrivacyInfo.xcprivacy`. Das neue Manifest deklariert
`NSPrivacyAccessedAPICategoryUserDefaults` (Reason `CA92.1`) und
`NSPrivacyAccessedAPICategoryFileTimestamp` (Reason `3B52.1` — deckt u. a.
`ZipArchiveReader.attributesOfItem`, `CruiseFormView`, `IdBackfill`,
`ShippingLineCatalogDedup` ab). Da das Projekt Xcode-16-Filesystem-Synced-
Groups nutzt (`PBXFileSystemSynchronizedRootGroup`), ist keine manuelle
`project.pbxproj`-Eintragung nötig — die Datei wird allein durch ihre
Ordner-Zugehörigkeit ins Target aufgenommen.

### Berührte Dateien

- `ShipTrip/PrivacyInfo.xcprivacy` (neu)

### Acceptance-Status

Erfüllt (Bundle-Check im Build). Der signierte Archive-Privacy-Report bleibt
laut Umsetzungsplan Pflichtpunkt im nächsten regulären
TestFlight-Release-Preflight (S3.4, noch offen).

---

## H6 — Unvollständige Lokalisierung (Tasks S2.1a, S2.2/S2.4-Anteile, S2.1b-1/-2)

### Was / Warum

Mehrere Code-Stellen zeigten hartkodierte deutsche Strings statt
`String(localized:)`, u. a. `Date+Extensions.swift`, `ZipArchiveWriter.swift`,
`ExportImportService.swift` (Import-Alert-Texte), `GeminiService.swift`
(Disclosure-Texte) sowie dynamische Titel in mehreren Views (u. a.
„Wunschreisen"→Deals, „Bilanz"→Stats, `StatCard`-Verbatim-Fix in
`StatsView`, „Anzahl"→Count). Der String-Katalog
(`Localizable.xcstrings`) erhält dafür 101 neue Keys mit englischer
Übersetzung. Ein neuer EN-UI-Smoke-Test startet die App mit
`-AppleLanguages (en)` und prüft Kernbildschirme (Liste, Karte, Stats,
Settings, Deals) gegen bekannte deutsche Marker-Strings.

### Berührte Dateien

- `ShipTrip/Utilities/Date+Extensions.swift`
- `ShipTrip/Services/ZipArchiveWriter.swift`
- `ShipTrip/Services/ExportImportService.swift`
- `ShipTrip/Services/GeminiService.swift`
- `ShipTrip/Views/Stats/StatsView.swift`
- `ShipTrip/Localizable.xcstrings` (101 neue Keys, einziger Katalog-Schreiber
  laut Single-Writer-Prinzip)
- `ShipTripUITests/EnglishLocalizationSmokeUITests.swift` (neu)

### Acceptance-Status

Erfüllt. EN-UI-Smoke grün im seriellen Testlauf; statischer Katalog-Abgleich
zeigt keine fehlenden Keys mit leerer EN-Unit.

---

## H8 — Ungehärteter ZIP-Restore (Task S2.2)

### Was / Warum

`ZipArchiveReader`/`ExportImportService` prüften Einträge beim Restore weder
auf CRC-32-Konsistenz noch auf Local-Header-Signatur, und Strukturfehler
führten teils zu stillem `break`/`continue` statt eines Abbruchs. Neu:
CRC-32-Verifikation pro Entry (`CRC32.checksum(extractedData) ==
crc32Expected`), Local-Header-Signatur- und Namenskonsistenz-Check gegen die
Central-Directory-Einträge, beidseitige Entry-Count-Validierung, Bounds-Checks
für Extra-Felder und Deflate-Größenkonsistenz. Bildvalidierung erfolgt jetzt
über ImageIO (`CGImageSourceGetCount(source) > 0`) statt reiner
Datei-Existenzprüfung; ungültige/fehlende Medien werden über das neue
`ImportResult.invalidMedia`-Feld gezählt und im Import-Alert in
`SettingsView` ausgewiesen. Bei Strukturfehlern bricht der Import atomar ab
(kein Teil-Import). Der Test-ZIP-Builder schreibt jetzt standardmäßig echte
CRCs; ein expliziter CRC-Override existiert nur noch für gezielte
Korruptionstests.

### Berührte Dateien

- `ShipTrip/Services/ZipArchiveReader.swift`
- `ShipTrip/Services/ExportImportService.swift` (`ImportResult.invalidMedia`,
  `isValidImageData`)
- `ShipTrip/Views/Settings/SettingsView.swift` (Import-Alert)
- `ShipTripTests/ExportImportHardeningTests.swift`

### Acceptance-Status

Erfüllt. Tests mit korruptem CRC, truncated Central Directory und fehlendem
Medium zeigen jeweils eine klare Fehlermeldung bzw. einen sichtbaren Zähler;
alle bestehenden Hardening-/Roundtrip-Tests bleiben grün.

---

## Offene Punkte

- Medium- und Low-Findings (M1, M3, M4, M6–M11, L1–L5) sind laut
  Andre-Entscheidung vom 10.07.2026 zurückgestellt, bis sie aufgerufen werden
  (Details: [Umsetzungsplan Audit 2026-07-10](../umsetzungsplan-audit-2026-07-10.md)).
- EN-Terminologie uneinheitlich (Cruise vs. Trip je nach Bildschirm) —
  bewusst nicht angefasst in dieser Welle.
- Mögliche `%lld`/`%llu`-Duplikat-Keys im String-Katalog (38 Treffer beim
  Scan) sind nicht bereinigt — potenzielle Katalog-Leichen aus früheren
  Wellen, kein Regressionsrisiko dieser Welle.
- Der signierte Archive-Privacy-Report für H7 (Pflichtpunkt laut
  Umsetzungsplan) läuft erst im nächsten regulären
  TestFlight-Release-Preflight (S3.4), nicht Teil dieser Welle.

## Verwandte Entscheidungen

- [ADR-002: CloudKit-Sync, stabile IDs und ZIP-Export](../adr/ADR-002-cloudkit-sync-und-stabile-ids.md)
  (betrifft H3/H8 — Export/Import-Format und ID-Stabilität)
