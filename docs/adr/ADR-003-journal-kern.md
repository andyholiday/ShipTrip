# ADR-003: Journal-Kern — eigenes `JournalEntry`-Modell, `Photo.caption` und additive Lightweight-Migration

**Status:** Accepted (2026-08-27 — Codex-Gate #4 Findings eingearbeitet, unabhängig verifiziert)
**Datum:** 2026-08-27
**Autor:** architect (Run 1.8.5, T1) für Andre
**Querverweis:** ADR-001 (`isDemo`-Filterung), ADR-002 (CloudKit-Regeln, stabile IDs, LWW), ADR-007 (Teilen-Format)

---

## Kontext

ShipTrip verfolgt die Produktrichtung „Travel Journal", aber der Journal-Kern
fehlt (Audit-Welle B2, Finding [H]): Es gibt keine Möglichkeit, während der
Reise eine Erinnerung zu einem Tag festzuhalten. Vorhandene Behelfe decken das
nicht ab — `Cruise.notes` ist ein einziger Freitext pro Reise, `Port` trägt
keine Tages-Erinnerungen und existiert an Seetagen nur als Routen-Stopp, Fotos
haben keine Bildunterschriften. Andre hat für 1.8.5 den vollen B2-Umfang
beauftragt („Basis + Captions + Stimmung") mit dem Produkt-Prinzip
„Erinnerung als Einstieg, Eckdaten als Zweitschritt".

Harte Rahmenbedingungen: CloudKit-Mirroring ist seit 1.7.0 in Production aktiv,
daher gelten die Schema-Regeln aus ADR-002 §3 uneingeschränkt (Defaults auf
allen nicht-optionalen Attributen, optionale Relationships, keine
`.unique`-Constraints, Dedup über stabile `id: UUID`). Bestehende Nutzer-Stores
(1.8.0) müssen verlustfrei migrieren; ein Schema-Bruch ist ausgeschlossen.
Der Run ist auf parallele Wellen geschnitten (Design T5/T6 ∥ Modell T7,
danach UI T8), was eine früh fixierte Naht zwischen Modell und UI erfordert.

## Entscheidung

Wir führen ein eigenes SwiftData-Modell **`JournalEntry`** ein — pro Eintrag:
Freitext (`text`), Kalendertag (`entryDate`), Stimmung (`moodRaw` als stabiler
Roh-String, leer = keine), stabile `id`, `createdAt`/`updatedAt` (LWW) — mit
optionalen Beziehungen zu `Cruise` (cascade-besitzt), optional zu `Port`
(nullify) und zu angehängten `Photo`s (nullify). `Photo` erhält additiv
`caption: String = ""` und die optionale Rückbeziehung `journalEntry`;
angehängte Fotos bleiben zugleich Kinder der Reise, damit Galerie, Export und
Aggregate unverändert funktionieren. Mehrere Einträge pro Tag sind erlaubt.

Drei Verträge gehören verbindlich zur Entscheidung: `entryDate` trägt
**Date-only-Semantik** (s. „Zeitzonen-Vertrag"), `createdAt`/`updatedAt`
folgen dem **LWW-Vertrag** mit Mutations-Matrix (J2a im Editor-Contract),
und `moodRaw` unterliegt dem **Stabilitätsvertrag** inkl.
Unknown-Preservation. Per Zusatzentscheid Andre („Beides in 1.8.5") sind
Journal-Einträge und Foto-Captions außerdem Teil des ZIP-Exports **und** des
Teilen-Formats (s. „Export- und Teilen-Integration", Contract für T7b).

Die verbindliche Feld-Liste (Namen, Typen, Defaults, Delete-Regeln) und der
Editor-Flow („Erinnerung zuerst, Eckdaten als Zweitschritt" mit
Default-Regeln) stehen als eigenständige Naht in
[`docs/architecture/contracts/journal-editor-contract.md`](../architecture/contracts/journal-editor-contract.md)
(J1–J5); dieser Contract ist Bestandteil dieser Entscheidung.

Die Migration erfolgt als **additive Lightweight-Automatic-Migration** ohne
`VersionedSchema`/`SchemaMigrationPlan`: ein neues Modell, drei neue optionale
Relationships, ein neues Attribut mit Default — keine Umbenennung, kein
Datentransform, kein Entfernen. Der Beweis läuft über die eingefrorene
1.8.0-Store-Fixture (siehe Migrationsstrategie).

## Migrationsstrategie

Die Schema-Änderung ist **additiv** und damit per SwiftData-Lightweight-
Migration automatisch: Bestandsobjekte bleiben erwartungsgemäß unverändert
erhalten — belegt ist das erst nach Fixture- (T7), Geräte- (T11b) und
CloudKit-Gate, nicht vorab per Behauptung. Neue
Attribute erhalten ihre Defaults (`Photo.caption = ""`), neue Relationships
sind optional und starten leer. Ein Migrationsplan mit versionierten Schemas
wird bewusst **nicht** eingeführt — es gibt keinen zu transformierenden
Bestand, und die Projekt-Historie (Build 20, ADR-002) hat denselben additiven
Weg bereits erfolgreich beschritten.

**Fixture-Plan (verbindlich, aus `.planning/TASKPLAN-1.8.5.md` → Abschnitt
„Migrations-Beweis", Finding 7):**

1. Store mit dem 1.8.0-Build (Tag `92d19e1`) im Wegwerf-Simulator erzeugen:
   Beispielreise + 1 manuelle Reise mit Fotos.
2. Store-Dateien als eingefrorene Fixture nach
   `ShipTripTests/Fixtures/store-1.8.0/` kopieren.
3. T7-Tests öffnen die Fixture mit dem 1.8.5-Schema und prüfen: alle Objekte
   verlustfrei · neue Attribute mit Defaults · Relationships optional · keine
   `.unique`-Constraints im Schema · Aggregate identisch.
4. T11b wiederholt den Pfad auf Andres echtem Gerät (1.8.0 installiert →
   1.8.5 drüber) — Pflicht vor Release (Lehre aus
   [[shiptrip-swiftdata-migration-id-gotcha]]).

**CloudKit-Nachzug:** Das neue Record-Type `CD_JournalEntry` und die neuen
Felder müssen vor dem Release nach ADR-002 §Migrationsstrategie (e) in die
Development-Umgebung installiert und kontrolliert nach Production promotet
werden (`docs/cloudkit/*.ckdb` nachziehen). Additive CloudKit-Erweiterungen
sind unkritisch, aber der Promote ist ein expliziter Release-Schritt.

## Export- und Teilen-Integration (Zusatzentscheid „Beides in 1.8.5") — Contract für T7b

Beide Türen — ZIP-Export (ADR-002 §5) und `.shiptrip`-Teilen (ADR-007) —
nutzen denselben `ExportArchive`-Envelope; die Erweiterung gilt daher für
beide gleichzeitig.

- **Versionierung:** `formatVersion` bleibt **2**, `shareFormatVersion`
  bleibt **1**. Die Erweiterung ist rein additiv über optionale Felder; die
  Totalmatrix aus ADR-007 bleibt unberührt. Ein Versions-Bump würde
  1.8.0-Empfänger komplett aussperren (abgelehnt, s. Option F).
- **Neue DTO-Felder** (alle nach dem bestehenden `decodeIfPresent`-Muster
  aus `ExportImportDTOs.swift`):
  - `ExportCruise.journalEntries: [ExportJournalEntry]` — fehlt → `[]`.
  - `ExportPhoto.caption: String?` — fehlt → beim Materialisieren `""`.
  - `ExportJournalEntry`: `id`, `text`, `entryDate`, `moodRaw`,
    `createdAt`, `updatedAt`, `portId: String?`, `photoIds: [String]`
    (stabile UUIDs; Datums-Encoding wie übrige Export-Daten).
- **Import-Re-Linking:** Entry↔Photo und Entry↔Port werden beim Import
  über die stabilen UUIDs **innerhalb derselben Reise** rekonstruiert.
  Nicht auflösbare IDs werden verworfen — der Eintrag importiert ohne
  diesen Link, das Foto bleibt Reise-Kind; niemals Import-Abbruch.
  `.nullify` regelt nur das Lösch-Verhalten im Live-Store; die
  Rundtrip-Zuordnung leisten ausschließlich die ID-Listen im DTO.
- **Legacy-Verhalten (verbindliche Fixtures für T7b):** (a) 1.8.0-ZIP und
  1.8.0-`.shiptrip` ohne Journal-Felder importieren fehlerfrei mit leerem
  Journal und `caption == ""`; (b) neue Rundtrip-Fixtures mit Einträgen
  (inkl. Seetag, ohne Hafen, mehrere pro Tag, unbekanntem `moodRaw`)
  laufen über beide Türen verlustfrei; (c) `moodRaw`-Rohwerte passieren
  Export/Import verbatim.
- **Akzeptierte Asymmetrie:** 1.8.0-Leser importieren neue Dateien
  weiterhin (unbekannte JSON-Keys werden von Codable ignoriert), verlieren
  dabei aber still Journal + Captions. Bewusst in Kauf genommen, damit
  Teilen an Bestands-Installationen funktioniert (s. Konsequenzen).
- **Import-Limit:** `ShareArchiveLimits` (C10-Preflight, ADR-007 Schritt 7)
  wird um `maxJournalEntries` erweitert — konkreter Wert analog zur
  bestehenden Limit-Skala, festgelegt in T7b; ohne dieses Limit wäre die
  Entry-Sammlung die einzige unbegrenzte Kollektion aus Fremddateien.
- **Import-Normalisierung:** importierte `entryDate`-Werte werden auf
  12:00 UTC ihres UTC-Tag-Tripels normalisiert (Zeitzonen-Vertrag) —
  Alt- und Fremddateien dürfen keine unnormalisierten Zeitstempel in den
  Store bringen.

## LWW-Vertrag (`createdAt`/`updatedAt`)

Konfliktregel: Last-Writer-Wins **pro Objekt** über `updatedAt`
(ADR-002 §2). `createdAt` wird genau einmal beim Insert gesetzt und ist
danach **unveränderlich**. `updatedAt`-Bumps allein definieren kein LWW —
verbindlich ist die vollständige Mutation→Timestamp-Matrix in **J2a** des
Editor-Contracts, die auch Attach/Detach von Fotos und die Nullify-Pfade
beim Löschen von Eintrag bzw. Hafen abdeckt. Wichtig: SwiftData-Nullify
bumpt nichts automatisch; die Lösch-Pfade müssen die Bumps explizit
ausführen. T7-Tests decken die Matrix zeilenweise ab.

## Zeitzonen-Vertrag (`entryDate` als Date-only-Wert)

Gate-#4-Hypothese bestätigt plausibel: lokales `startOfDay` verschiebt bei
Zeitzonenwechseln — dem Kreuzfahrt-Normalfall — den Kalendertag.
Entscheidung: `entryDate` ist ein **Date-only-Wert** ohne Uhrzeit-Semantik.

- **Kanonische Kodierung:** 12:00 UTC des gewählten Kalendertags
  (Mittags-Anker; defensiv robust für Geräte-Zeitzonen bis ±12 h, falls
  doch einmal lokal interpretiert wird).
- **Tag-Extraktion aus `entryDate`:** immer über einen Kalender mit fester
  UTC-Zeitzone.
- **Vergleiche** (Gruppierung, Reisetag-Nummer, Hafen-Default, Klemmen auf
  den Reisezeitraum): auf Tag-Tripeln (Jahr/Monat/Tag) — die
  `entryDate`-Seite via UTC-Kalender, die Seite
  `cruise.startDate`/`port.arrival` via Geräte-Kalender (lokale
  Ereignis-Zeitstempel). Nie `Date ==`, nie gemischtes
  `isDate(inSameDayAs:)` über beide Konventionen hinweg.
- Eine gespeicherte Reisezeitzone wird bewusst **nicht** eingeführt: kein
  Träger im Modell nötig, Date-only deckt den Bedarf; falls später
  Uhrzeiten pro Eintrag gewünscht sind, ist das ein neues ADR.

## `moodRaw`-Stabilitätsvertrag

Ergänzend zu J4: Rohwerte werden **nie umbenannt und nie wiederverwendet** —
ein ausgemusterter Rohwert bleibt dauerhaft verbrannt.
**Unknown-Preservation:** ein unbekannter Rohwert (z. B. aus einer neueren
App-Version via CloudKit-Sync oder Datei-Import) wird verbatim erhalten;
die UI zeigt den „keine Stimmung"-Fallback, der Editor überschreibt den
Wert nur, wenn der User aktiv eine andere Stimmung wählt, und
Export/Import reichen ihn unverändert durch.

## Nähte und Parallelisierung

- **Naht = Editor-Contract** (J1–J5): T5 (Designer) baut den Editor-Prototyp
  gegen die Feld-Liste, T7 (Modell-Dev) implementiert exakt die J1-Felder —
  beide unabhängig und ohne Querzugriff.
- **Parallel:** T5/T6 (Design-Strecke) ∥ T7 (Modell-Wave, nach Gate-#4-GO);
  die Modell-Wave hängt nicht am UI-Design.
- **Seriell:** T8 (UI-Wave) erst nach T6 (visuelles Gate + Andre-Go), T7
  (Modell vorhanden) und T4 (Dialog-Struktur in `Views/Cruises/`).
- Contract-Änderungen laufen über Winston (Rev.-Vermerk im Contract), nie
  still per Diff.

## Konsequenzen

**Positiv**

- Tages-Erinnerungen inkl. Seetagen und mehrfachen Einträgen pro Tag — ohne
  Missbrauch von `Port` oder `Cruise.notes`.
- Vollständig CloudKit-konform; das Migrations-Risiko für Bestands-Stores
  ist wegen rein additiver Änderungen als gering eingeschätzt — der
  Nachweis läuft verbindlich über Fixture- (T7), Geräte- (T11b) und
  CloudKit-Gate und gilt bis dahin als offen.
- Journal-Einträge und Captions überleben ZIP- und Teilen-Rundtrips
  (Re-Linking über stabile UUIDs, s. Export- und Teilen-Integration/T7b).
- Fotos in Einträgen bleiben Reise-Kinder: Galerie, Statistiken, Export und
  Teilen (ADR-007) verhalten sich unverändert (T11a-Regressionskriterium).
- Stimmung als stabiler Roh-String ist reorder-sicher, export-lesbar und
  dank Unknown-Preservation vorwärtskompatibel.

**Negativ / Risiken**

- **Alt-Leser-Asymmetrie:** 1.8.0-Installationen importieren neue
  ZIP-/`.shiptrip`-Dateien ohne Fehler, verlieren dabei aber still
  Journal + Captions (unbekannte Keys werden ignoriert). Ohne
  Versions-Bump — der Alt-Empfänger ganz aussperren würde (Option F) —
  nicht schließbar; bewusst akzeptiert.
- `updatedAt` muss in jedem Schreib- **und Lösch-Pfad** manuell nach der
  Mutations-Matrix (J2a) gebumpt werden — inklusive der Nullify-Pfade, die
  SwiftData nicht automatisch bumpt; bekanntes LWW-Risiko aus ADR-002,
  durch T7-Tests zeilenweise abgedeckt.
- Zwei zusätzliche Relationships auf `Photo`/`Port` erhöhen die Zahl der
  Delete-Regel-Kombinationen; die Löschregeln sind in J1 fixiert und in
  T7-Tests abzudecken.

**Neutral**

- Kein `isDemo` auf `JournalEntry`; Demo-Filterung läuft über
  `cruise?.isDemo` wie bei allen Kind-Modellen. Ob die Beispielreise künftig
  Journal-Einträge enthält, ist eine separate Produktentscheidung.
- Reisetag-Nummer („Tag 3") wird abgeleitet, nie gespeichert — kein Drift bei
  Datumsänderungen der Reise.

## Alternativen

**Option A: Tages-Notizen an `Port` hängen (Feld-Erweiterung statt neues Modell)**
Abgelehnt. Seetage und Tage ohne Routen-Stopp hätten keinen Träger, mehrere
Einträge pro Tag wären unmöglich, und der Flow „Erinnerung zuerst" würde einen
Hafen-Pflichtbezug erzwingen — das Gegenteil der Produktentscheidung.

**Option B: Journal als serialisiertes JSON-Attribut auf `Cruise`**
Abgelehnt. Nicht per `@Query`/Predicate abfragbar, kein feingranulares
CloudKit-Delta (jeder Eintrag synct die ganze Reise), Foto-Verknüpfung nur
über fragile ID-Listen — widerspricht dem SwiftData-Modellgraph-Ansatz.

**Option C: Foto-Zuordnung implizit über Datum statt Relationship**
Abgelehnt. Bricht, sobald ein Eintrag umdatiert wird oder zwei Einträge am
selben Tag existieren; eine explizite optionale Relationship ist eindeutig
und CloudKit-konform.

**Option D: Stimmung als `Int` (0–5)**
Abgelehnt. Magic Numbers im Store und Export; ein späteres Umsortieren der
Skala würde Bestandsdaten still umdeuten (gleiche Lehre wie
textEnum-vor-intEnum). Roh-Strings sind selbstbeschreibend und stabil.

**Option E: `VersionedSchema` + `SchemaMigrationPlan` jetzt einführen**
Abgelehnt für diesen Run. Die Änderung ist rein additiv und von Lightweight
abgedeckt; ein Versionierungsgerüst ohne transformierende Stage wäre
spekulative Infrastruktur. Wird nötig, sobald eine erste nicht-additive
Änderung ansteht (dann eigenes ADR).

**Option F: `formatVersion`-Bump auf 3 für die Journal-Felder**
Abgelehnt. Die Totalmatrix (ADR-007) würde jeden Import auf 1.8.0 mit
„neuere Version nötig" abweisen — Teilen an Bestands-Installationen bräche
komplett. Die additive Erweiterung innerhalb von Version 2 erhält den
Alt-Pfad; Preis ist die dokumentierte Silent-Drop-Asymmetrie
(s. Konsequenzen).

## Umgesetzt durch

- [Feature-Doku: Journal](../features/journal.md) — Umsetzungsstand,
  Acceptance-Status und offene Punkte

## Referenzen

- `docs/architecture/contracts/journal-editor-contract.md` — verbindliche
  Feld-Liste, Editor-Flow, Stimmungs-Skala, ER-Diagramm (J1–J5)
- `docs/adr/ADR-002-cloudkit-sync-und-stabile-ids.md` — CloudKit-Regeln,
  LWW, Migrations-Zweischritt
- `docs/adr/ADR-001-isdemo-in-release-schema.md` — Demo-Filterung
- `docs/adr/ADR-007-kreuzfahrt-teilen.md` — Teilen-Format; Journal +
  Captions werden per Zusatzentscheid additiv innerhalb von
  formatVersion 2 / shareFormatVersion 1 integriert (s. Export- und
  Teilen-Integration)
- `ShipTrip/Services/ExportImportDTOs.swift` — bestehendes
  `decodeIfPresent`-Muster, das die neuen DTO-Felder spiegeln
- `.planning/TASKPLAN-1.8.5.md` — Task-DAG, Abschnitt „Migrations-Beweis"
- `docs/umsetzungsplan-audit-2026-07.md` — Welle B2 (B2.1–B2.3)
- `ShipTrip/Models/Cruise.swift`, `Port.swift`, `Photo.swift` — gespiegelte
  Bestands-Muster (Storage-Relationship + computed Wrapper, stabile IDs)

## Revisionen

- 2026-08-27 (Iteration 2, nach Codex-Gate #4 NO-GO): Export-/Teilen-
  Integration als T7b-Contract ergänzt (Finding 1) · LWW-Vertrag mit
  Mutations-Matrix in J2a des Editor-Contracts (Finding 2) ·
  Zeitzonen-Vertrag: `entryDate` als Date-only-Wert (Finding 3) ·
  Migrations-Aussagen auf „Nachweis über Gates" abgeschwächt (Finding 4) ·
  `moodRaw`-Stabilitätsvertrag mit Unknown-Preservation (Finding 5).
  Status bleibt Proposed.
