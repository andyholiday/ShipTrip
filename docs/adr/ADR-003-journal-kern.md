# ADR-003: Journal-Kern — eigenes `JournalEntry`-Modell, `Photo.caption` und additive Lightweight-Migration

**Status:** Proposed (Accepted nach Codex-Gate #4; Gate-GO ist Vorbedingung für die Modell-Wave T7)
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
Migration automatisch: Bestandsobjekte bleiben byte-identisch erhalten, neue
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
- Vollständig CloudKit-konform; kein Migrations-Risiko für Bestands-Stores
  (nur additive Änderungen, per Fixture-Test bewiesen).
- Fotos in Einträgen bleiben Reise-Kinder: Galerie, Statistiken, Export und
  Teilen (ADR-007) verhalten sich unverändert (T11a-Regressionskriterium).
- Stimmung als stabiler Roh-String ist reorder-sicher und export-lesbar.

**Negativ / Risiken**

- **Backup-Lücke:** `JournalEntry` und `Photo.caption` sind im 1.8.5-Scope
  nicht Teil des ZIP-Exports (ADR-002 §5) und nicht Teil des Teilen-Formats
  (ADR-007) — Journal-Daten überleben Export/Import-Rundtrips nicht.
  Bewusst aus dem Run herausgehalten; braucht einen Folge-Task (Backlog)
  vor dem Marketing-Claim „Tagebuch ist gesichert".
- `updatedAt` muss in jedem neuen Schreibpfad (Editor-Save, Caption-Edit)
  manuell gebumpt werden — bekanntes LWW-Risiko aus ADR-002.
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

## Referenzen

- `docs/architecture/contracts/journal-editor-contract.md` — verbindliche
  Feld-Liste, Editor-Flow, Stimmungs-Skala, ER-Diagramm (J1–J5)
- `docs/adr/ADR-002-cloudkit-sync-und-stabile-ids.md` — CloudKit-Regeln,
  LWW, Migrations-Zweischritt
- `docs/adr/ADR-001-isdemo-in-release-schema.md` — Demo-Filterung
- `docs/adr/ADR-007-kreuzfahrt-teilen.md` — Teilen-Format (Journal dort
  bewusst nicht enthalten, s. Konsequenzen)
- `.planning/TASKPLAN-1.8.5.md` — Task-DAG, Abschnitt „Migrations-Beweis"
- `docs/umsetzungsplan-audit-2026-07.md` — Welle B2 (B2.1–B2.3)
- `ShipTrip/Models/Cruise.swift`, `Port.swift`, `Photo.swift` — gespiegelte
  Bestands-Muster (Storage-Relationship + computed Wrapper, stabile IDs)
