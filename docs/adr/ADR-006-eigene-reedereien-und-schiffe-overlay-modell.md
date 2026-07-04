# ADR-006: Eigene Reedereien & Schiffe als Overlay über dem statischen Katalog

**Status:** Accepted
**Datum:** 2026-07-04
**Aktualisiert:** 2026-07-04 — Codex-Gate #4 (GO-WITH-CHANGES): Post-Sync-Dedup,
Edit-Pfad-Preserve-on-save, Mutation-IDs, Normalizer-Trennung ergänzt
(Abschnitte 2, 4, 5, 6 neu/überarbeitet).
**Autor:** Architect (Welle B5 „Eigene Reedereien & Schiffe verwalten")
**Querverweis:** ADR-002 (CloudKit-Constraints, stabile IDs), ADR-001 (Schema-Stabilität)

---

## Kontext

`ShippingLine.all` (`ShipTrip/Models/ShippingLine.swift`) ist ein hartkodierter
Katalog von ~15 Reedereien mit insgesamt >100 Schiffen. Nutzer, deren Reederei
oder Schiff dort fehlt (kleine Anbieter, Flusskreuzfahrten, Neubauten vor
Katalog-Update), können aktuell nur einen freien Text in `Cruise.ship` /
`Deal.shippingLine` eintragen — ohne Logo, ohne Wiederverwendbarkeit im
Picker, ohne Konsistenz zwischen mehreren Reisen mit demselben Schiff.

Wichtiger Bestandsbefund: `Cruise.shippingLine` und `Cruise.ship` sowie
`Deal.shippingLine` sind bereits reine `String`-Felder (kein Fremdschlüssel
auf `ShippingLine.id`). Das Matching auf den Katalog erfolgt ausschließlich
namensbasiert (`ShippingLine.find(byName:)`, `findByShipName(_:)`,
`shippingLineLogo`-Computed-Properties in `Cruise`/`Deal`). Das reduziert den
Migrationsdruck für dieses ADR erheblich: Bestandsdaten referenzieren nie ein
neues Modell, sie bleiben unverändert String-basiert.

Gefordert ist Weg 1 „Overlay" (vom Product Owner fixiert, hier nicht neu
bewertet): eigene Reedereien/Schiffe als zusätzliche SwiftData-Modelle in der
Nutzer-DB, der hartkodierte Katalog bleibt unangetastet, Picker zeigen
Katalog + eigene Einträge gemischt, einzelne Katalog-Vorschläge lassen sich
ausblenden.

Alle neuen Modelle unterliegen den CloudKit-Constraints aus ADR-002:
Default-Werte für alle nicht-optionalen Attribute, optionale Relationships,
kein `@Attribute(.unique)`, stabile App-seitige `id`. Genau diese Constraints
(keine Uniques) sind der Grund, warum Codex-Gate #4 einen expliziten
Post-Sync-Dedup-Mechanismus verlangt hat (Abschnitt 6) — ohne Uniques kann
CloudKit-Mirroring auf zwei Offline-Geräten unabhängig zwei gültige, aber
kollidierende Zeilen erzeugen.

Bestandsbefund aus der Gate-4-Prüfung: `CruiseFormView.swift:443/687` und
`DealsView.swift:358/381` laden beim Bearbeiten die Reederei ausschließlich
aus `ShippingLine.all` und schreiben beim Speichern `selectedShippingLine?.name
?? ""` bzw. `shippingLine?.name` (optional) zurück. Eine Reise mit einer
Custom-, gelöschten oder ausgeblendeten Reederei würde beim bloßen Öffnen und
Speichern des Bearbeiten-Formulars ihren `shippingLine`-Wert stillschweigend
auf `""`/`nil` zurücksetzen. Das ist als HIGH-Finding in Abschnitt 5
adressiert.

---

## Entscheidung

### 1. Drei neue, flache SwiftData-Modelle — keine Relationship zwischen ihnen

```
CustomShippingLine   { id: UUID, name: String, logo: String, createdAt, updatedAt }
CustomShip           { id: UUID, name: String, lineOptionID: String, createdAt, updatedAt }
HiddenCatalogItem    { id: UUID, lineID: String, shipKey: String?, createdAt }
```

`CustomShip.lineOptionID` referenziert die zugehörige Reederei **als String**,
nicht als SwiftData-`@Relationship`, und zwar sowohl für Katalog- als auch für
eigene Reedereien (`"aida"` bzw. `"custom:<UUID>"` — siehe DTO-Vertrag unten).
Begründung gegen eine Relationship: Ein Schiff kann einer **Katalog-Reederei**
zugeordnet sein (z. B. ein fehlendes AIDA-Schiff nachtragen), und
`ShippingLine` ist kein `@Model`/`PersistentModel`, sondern ein hartkodiertes
`struct` — eine SwiftData-Relationship kann darauf grundsätzlich nicht zeigen.
Ein einheitlicher String-Schlüssel für beide Fälle hält Service und UI auf
einem Codepfad, statt zwei Referenzarten (Relationship zu `CustomShippingLine`
vs. String zu Katalog) zu pflegen. Preis: keine referenzielle Integrität auf
DB-Ebene — behandelt in „Konsequenzen" und in Abschnitt 6 (Post-Sync-Dedup).

`HiddenCatalogItem` deckt sowohl „ganze Reederei ausblenden" (`shipKey == nil`)
als auch „einzelnes Schiff ausblenden" (`shipKey` gesetzt) in einem Modell ab,
um ein zweites Fast-Duplikat-Modell zu vermeiden. Ausblenden gilt **nur für
Katalog-Einträge**; eigene Einträge werden statt versteckt einfach gelöscht
(Non-Goal: kein Hidden-Zustand für Custom-Objekte, siehe Abschnitt „Non-Goals").

Alle drei Modelle sind CloudKit-konform: keine Relationships, keine Unique-
Constraints, jedes nicht-optionale Attribut hat einen Default-Wert.

### 2. Zwei getrennte Normalisierungen — Hidden-Key vs. Kollisions-/Sortier-Key

Gate-4-Finding: Ein einzelner Normalizer reicht nicht, weil zwei
unterschiedliche Anforderungen dahinterstehen — Kompatibilität mit dem
bestehenden Katalog-Matching (Hidden-Key) versus tolerante Namensvergleiche
für Kollisionsprüfung und Sortierung (Kollisions-Key). Beide werden mit
fester Signatur benannt, damit Dev-A und Dev-B nicht auseinanderlaufen:

```swift
extension ShippingLine {
    /// Hidden-Key-Normalisierung: lowercased() + trimmingCharacters(.whitespacesAndNewlines)
    /// + Leerzeichen entfernt. Identisch zur bestehenden Logik in `findByShipName`,
    /// bewusst NICHT diakritik-insensitiv, damit Hidden-Keys 1:1 kompatibel mit dem
    /// bestehenden Katalog-Matching bleiben.
    static func normalizedShipKey(_ name: String) -> String
}

enum ShippingLineNameMatching {
    /// Kollisions-/Sortier-Normalisierung: zusätzlich diakritik-insensitiv
    /// (`.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)`),
    /// getrimmt. Verwendet für: Namenskollisionsprüfung (Abschnitt 3), sortKey in den
    /// Merge-Funktionen (Abschnitt 4) und Gewinner-/Duplikat-Erkennung im
    /// Post-Sync-Dedup (Abschnitt 6).
    static func collisionKey(_ name: String) -> String
}
```

- **Reederei-Hide-Key**: `ShippingLine.id` (z. B. `"aida"`, `"msc"`) — der
  bereits stabile, handvergebene String-Identifier im Katalog, unabhängig vom
  (übersetzbaren) `name`.
- **Schiff-Hide-Key**: `lineID + normalizedShipKey(name)`. `normalizedShipKey(_:)`
  wird aus `findByShipName` in eine wiederverwendbare, statische Funktion
  extrahiert (chirurgische Änderung an `ShippingLine.swift`, kein
  Verhaltenswechsel) und von `findByShipName`, `HiddenCatalogItem` und dem
  neuen Service gemeinsam genutzt, damit beide Stellen nie auseinanderdriften.
- **Kollisions-/Sortier-Key**: `collisionKey(_:)` erkennt z. B. `"Königsklasse"`
  und `"Konigsklasse"` als Namenskollision (Abschnitt 3) und sortiert sie an
  derselben Stelle — teilt aber bewusst **nicht** denselben Hidden-Key, da ein
  Hide exakt wie der Katalog matchen muss.

Risiko (unverändert): Benennt der Katalog künftig ein Schiff um (selten, da
hartkodiert und manuell gepflegt), verwaist der gespeicherte Hide-Key
stillschweigend — das Schiff erscheint wieder sichtbar. Es gibt **keinen**
automatischen Reconciliation-Mechanismus; akzeptables Risiko, da
Katalog-Umbenennungen selten und manuell sind (Nutzer kann bei Bedarf erneut
ausblenden).

### 3. Namens-Kollisions-Politik: strikte Ablehnung, kein Override, kein Duplikat

Der Katalog bleibt kanonisch. Beim Anlegen einer eigenen Reederei/eines
eigenen Schiffs wird `ShippingLineNameMatching.collisionKey(_:)` (Abschnitt 2)
gegen den relevanten Bestand geprüft:

- **Eigene Reederei**: Kollision mit `ShippingLine.all[].name` ODER mit einer
  bestehenden `CustomShippingLine.name` → **Anlage wird abgelehnt**
  (`ShippingLineCatalogError.duplicateLineName`), UI zeigt Inline-Fehler
  („Diese Reederei ist bereits vorhanden — bitte den bestehenden Eintrag
  verwenden.").
- **Eigenes Schiff**: Kollision mit den Schiffen (aktiv + historisch) der
  Ziel-Reederei ODER mit bestehenden `CustomShip`-Einträgen derselben
  `lineOptionID` → **Anlage wird abgelehnt**
  (`ShippingLineCatalogError.duplicateShipName`).

Es gibt **keine** „getrennt angezeigte Duplikat"-Option — das würde im
Picker zwei fast identische Einträge erzeugen und die Auswahl für den Nutzer
verwirrender machen, ohne einen echten Vorteil zu bieten. Gegen Katalog-
Kollisionen zu blockieren ist die einfachere und eindeutigere Regel. Dieselbe
`collisionKey`-Logik ist die Grundlage für die Duplikat-Erkennung im
Post-Sync-Dedup (Abschnitt 6) — zwei Geräte, die offline denselben Namen
anlegen, erzeugen serverseitig genau die Kollision, die hier lokal verhindert
wird.

### 4. Verbindlicher Typ-/API-Contract

```swift
struct ShippingLineOption: Identifiable, Hashable {
    enum Source: String { case catalog, custom, unlisted }
    /// Anzeige-/Diffing-Key. catalog: ShippingLine.id ("aida"); custom: "custom:<uuidString>";
    /// unlisted: "unlisted:<collisionKey(name)>". NICHT für Mutationen verwenden — dafür `customID`.
    let id: String
    let source: Source
    /// Nur bei source == .custom gesetzt. Alleiniges Ziel für updateCustomLine/deleteCustomLine.
    let customID: UUID?
    let name: String
    let logo: String
}

struct ShipOption: Identifiable, Hashable {
    enum Source: String { case catalog, custom, unlisted }
    /// Anzeige-/Diffing-Key: "<lineOptionID>|<normalizedShipKey(name)>" bzw. "unlisted|<...>".
    /// NICHT für Mutationen verwenden — dafür `customID`.
    let id: String
    let source: Source
    /// Explizit mitgeführt, nicht aus `id` geparst.
    let lineOptionID: String
    /// Nur bei source == .custom gesetzt. Alleiniges Ziel für updateCustomShip/deleteCustomShip.
    let customID: UUID?
    let name: String
    /// true bei Katalog-Schiffen aus `ShippingLine.historicalShips` — unabhängig von `source == .unlisted`.
    let isHistorical: Bool
}

enum ShippingLineCatalogError: Error { case duplicateLineName, duplicateShipName }

enum ShippingLineCatalogService {
    // Reine Merge-/Sortier-/Filter-Funktionen — keine ModelContext-Abhängigkeit.
    // Views rufen diese direkt mit ihren @Query-Resultaten auf; eigene
    // Merge-Logik in Views ist nicht zulässig.
    //
    // `currentSelection`: der aktuell auf Cruise/Deal gespeicherte Freitext (z. B. `cruise.shippingLine`
    // bzw. `cruise.ship`). Matcht er keine der sonst zurückgegebenen Optionen (per exaktem
    // String-Vergleich zum gespeicherten Wert), wird eine zusätzliche `.unlisted`-Option mit
    // genau diesem Namen angehängt (s. Abschnitt 5). `nil`/leer für neue Cruises/Deals.
    static func shippingLineOptions(
        customLines: [CustomShippingLine], hidden: [HiddenCatalogItem], currentSelection: String?
    ) -> [ShippingLineOption]   // Katalog + Custom (+ ggf. unlisted) gemischt, sortiert nach collisionKey(name)

    static func shipOptions(
        for lineOptionID: String, customShips: [CustomShip], hidden: [HiddenCatalogItem], currentSelection: String?
    ) -> [ShipOption]           // dito für Schiffe einer Reederei

    // Schreibende Operationen — benötigen ModelContext, werfen bei Kollision.
    // Mutationen adressieren Custom-Objekte ausschließlich über ihre UUID, nicht über
    // den zusammengesetzten `id`-String der DTOs (Abschnitt 4-Fix aus Gate #4).
    static func createCustomLine(name: String, logo: String, in context: ModelContext) throws -> ShippingLineOption
    static func updateCustomLine(_ customID: UUID, name: String, logo: String, in context: ModelContext) throws
    static func deleteCustomLine(_ customID: UUID, in context: ModelContext)   // löscht zugehörige CustomShip-Zeilen mit
    static func createCustomShip(name: String, lineOptionID: String, in context: ModelContext) throws -> ShipOption
    static func updateCustomShip(_ customID: UUID, name: String, in context: ModelContext) throws
    static func deleteCustomShip(_ customID: UUID, in context: ModelContext)
    static func hideCatalogLine(lineID: String, in context: ModelContext)
    static func unhideCatalogLine(lineID: String, in context: ModelContext)
    static func hideCatalogShip(lineID: String, shipName: String, in context: ModelContext)
    static func unhideCatalogShip(lineID: String, shipName: String, in context: ModelContext)
}
```

Sortierung: `shippingLineOptions`/`shipOptions` liefern eine einzige, nach
`ShippingLineNameMatching.collisionKey(name)` sortierte Liste, Katalog und
Custom (und ggf. `.unlisted`) gemischt — keine Gruppierung nach Quelle. Damit
ist die in B5 mitzulösende Picker-Sortierung Teil dieses Contracts.

**Konsum-Pattern (verbindlich für Dev-B):** Views deklarieren
`@Query private var customLines: [CustomShippingLine]`,
`@Query private var customShips: [CustomShip]`,
`@Query private var hidden: [HiddenCatalogItem]` und übergeben diese Arrays
plus den aktuellen gespeicherten Freitext als `currentSelection` an die reinen
Service-Funktionen. `CruiseFormView`/`DealsView` ersetzen
`@State selectedShippingLine: ShippingLine?` durch
`@State selectedLineOption: ShippingLineOption?`; `ship`/`shippingLine`
bleiben unverändert `String` (kein Schema-Change an `Cruise`/`Deal` nötig, da
diese Felder bereits reine Strings sind — Namen aus `ShippingLineOption`/
`ShipOption` werden beim Speichern wie bisher als Klartext übernommen).

### 5. Edit-Pfad: Preserve-on-save-Regel (Gate-4-Finding, HIGH)

Root Cause des gemeldeten Datenverlust-Risikos: `CruiseFormView.swift:443`
lädt `selectedShippingLine = ShippingLine.all.first { $0.name ==
cruise.shippingLine }` — findet nichts, wenn `cruise.shippingLine` ein
gelöschter/ausgeblendeter Katalog- oder ein Custom-Name ist, und
`CruiseFormView.swift:687` schreibt beim Speichern `selectedShippingLine?.name
?? ""` zurück, was den gespeicherten Namen stillschweigend auf `""` zurücksetzt,
sobald der Nutzer das Formular nur öffnet und speichert, ohne die Reederei zu
ändern. Analog `DealsView.swift:358/381` mit `shippingLine?.name` (dort
zumindest `Optional`, kein Reset auf einen falschen Leerstring, aber derselbe
Informationsverlust).

**Verbindliche Regel:**

1. `loadExistingData()` in beiden Views ruft `shippingLineOptions(...,
   currentSelection: cruise.shippingLine)` (bzw. `deal.shippingLine`) auf und
   selektiert daraus die Option, deren `name` exakt dem gespeicherten String
   entspricht — inklusive der synthetischen `.unlisted`-Option, falls der Name
   sonst in keiner Liste vorkommt. `selectedLineOption` ist damit **nie**
   `nil`, solange `cruise.shippingLine` nicht leer war.
2. `saveCruise()`/`saveDeal()` schreiben **nie** einen leeren String/`nil`
   über einen zuvor nicht-leeren Wert, wenn der Nutzer die Auswahl nicht aktiv
   geändert hat: `existingCruise.shippingLine = selectedLineOption?.name ??
   existingCruise.shippingLine` statt `?? ""`. Nur ein expliziter
   Nutzer-Reset (z. B. "Wählen..."-Option erneut selektiert) darf auf leer
   zurücksetzen — das entspricht dem bestehenden Verhalten bei neuen
   Kreuzfahrten ohne Auswahl.
3. Analog für `ship`/`ShipOption` in `CruiseFormView`, inklusive des
   bestehenden Sonderfalls (`CruiseFormView.swift:222-224`: aktuelles Schiff
   wird in die Picker-Optionen injiziert, falls nicht im Katalog enthalten) —
   dieser Fall wird durch die neue `.unlisted`-Option im Service **ersetzt**,
   nicht zusätzlich in der View dupliziert. Die bisherige View-seitige
   Injektions-Logik entfällt zugunsten von `currentSelection`.

Diese Regel ist **Pflichtbestandteil** des Contracts (nicht optional für
Dev-B) und wird über Acceptance-Test 8 verifiziert.

### 6. Post-Sync-Dedup (Gate-4-Finding, HIGH)

CloudKit-Mirroring (ADR-002) erlaubt keine Unique-Constraints. Zwei Geräte
können offline unabhängig voneinander gleich benannte
`CustomShippingLine`/`CustomShip`/`HiddenCatalogItem`-Zeilen anlegen; nach dem
Sync existieren dann mehrere gültige, aber kollidierende Zeilen. Dedup ist
laut ADR-002 App-Aufgabe — analog zum bestehenden `IdBackfill`-Launch-Repair
(`ShipTrip/Utilities/IdBackfill.swift`, aufgerufen im `.task`-Block von
`ShipTrip/Views/Cruises/CruiseListView.swift` neben `ThumbnailBackfill`)
führt eine neue Repair-Routine `ShippingLineCatalogDedup.run(context:)`
(`ShipTrip/Utilities/ShippingLineCatalogDedup.swift`) einen deterministischen
Dedup-Pass durch, registriert an derselben Stelle (`.task { ... }` in
`CruiseListView.swift`) mit eigenem versionierten Completed-Flag
(`"shippingLineCatalogDedupCompleted.v1"`), synchron, `@MainActor`, idempotent
— exakt das Muster von `IdBackfill`.

**Gewinner-Regel (für alle drei Fälle identisch):** ältestes `createdAt`
gewinnt; bei exaktem Gleichstand entscheidet die lexikographisch kleinere
`id.uuidString` deterministisch (kein Zufall, reproduzierbar über alle
Geräte hinweg).

- **`CustomShippingLine`-Duplikate** (Kollision: `collisionKey(name)` gleich):
  Gewinner nach obiger Regel. Alle `CustomShip`-Zeilen mit `lineOptionID ==
  "custom:<Verlierer-UUID>"` werden auf `"custom:<Gewinner-UUID>"`
  umgeschrieben (Rewiring **vor** dem Löschen der Verlierer-Zeile). Verlierer
  werden danach gelöscht.
- **`CustomShip`-Duplikate** (Kollision: gleiche `lineOptionID` **und**
  gleicher `normalizedShipKey(name)` — dasselbe Schiff unter derselben
  Reederei, cross-device doppelt angelegt): Gewinner nach obiger Regel,
  Verlierer gelöscht. Kein Rewiring nötig, da in dieser Welle nichts auf
  `CustomShip.id` referenziert (`Cruise`/`Deal` speichern nur den Namen).
- **`HiddenCatalogItem`-Duplikate** (Kollision: gleiche `lineID` **und**
  gleicher `shipKey`, inkl. beide `nil`): Gewinner nach obiger Regel, Rest
  gelöscht. Kein Rewiring, da nichts auf `HiddenCatalogItem.id` referenziert.

Der Pass läuft unabhängig davon, ob CloudKit in diesem Release bereits aktiv
ist (ADR-002 aktiviert CloudKit erst in einem separaten, späteren Release) —
Duplikate können auch durch ZIP-Import/-Export oder manuelles Store-Restore
entstehen. Deshalb ist `ShippingLineCatalogDedup` **Teil dieser Welle**, nicht
auf das CloudKit-Release verschoben. Ein eigener Unit-Test
(`ShippingLineCatalogDedupTests.swift`, analog `IdBackfillTests.swift`) ist
Pflichtbestandteil (Acceptance-Test 7).

### 7. Schema-Registrierung

`ShipTripApp.swift` registriert die drei neuen Typen im `Schema([...])`-Array
(`CustomShippingLine.self, CustomShip.self, HiddenCatalogItem.self` ergänzen).
Migration: **Lightweight/automatisch** — es werden ausschließlich neue Tabellen
hinzugefügt, keine bestehenden Attribute geändert; SwiftData legt fehlende
Tabellen beim ersten Start mit neuem Schema automatisch an. Pflicht-Checks vor
Release (analog ADR-002, Abschnitt Migrationsstrategie):

1. **Fresh Install**: neue Reederei/Schiff/Hide anlegen, App neu starten,
   Persistenz prüfen.
2. **Upgrade von 1.6.1-Bestandsstore**: bestehende Cruises/Deals/Photos/Ports
   bleiben unverändert erhalten, neue Tabellen sind leer, kein Crash.

Die sieben bestehenden Test-Schema-Helfer in `ShipTripTests/*.swift`
(`Schema([Cruise.self, CruisePort.self, Expense.self, Deal.self, Photo.self])`,
je einmal in `CruiseFormRouteReconciliationTests.swift`,
`CruiseAggregateTests.swift`, `PortFormViewTests.swift`,
`DemoDataServiceTests.swift`, `ExportImportHardeningTests.swift`,
`ShipTripTests.swift` (×2), `IdBackfillTests.swift` (×2)) werden **nicht**
pauschal angefasst, da sie das neue Feature nicht testen. Neue Tests für
`ShippingLineCatalogService` und `ShippingLineCatalogDedup` erhalten je eine
eigene Testdatei mit eigenem Schema-Helfer (gleiches Muster wie die
bestehenden Dateien), der die drei neuen Modelle zusätzlich zu den fünf
bestehenden registriert.

### 8. Scope-Entscheidungen zu bestehenden `ShippingLine.all`-Nutzern

- **`DealsView.swift` (Picker `Zeile 299-304`, Prefill `Zeile 358`):**
  **In Scope.** Identisches Picker-Pattern wie `CruiseFormView`, gleiche DTOs,
  minimaler Zusatzaufwand. Würde es ausgenommen, könnte eine in
  `CruiseFormView` angelegte eigene Reederei in Deals nicht ausgewählt werden —
  inkonsistent und für den Nutzer nicht nachvollziehbar. Die Preserve-on-save-
  Regel (Abschnitt 5) gilt hier identisch.
- **`ShippingLine.findByShipName` (KI-Erfassung, `CruiseFormView.swift:535`):**
  **Non-Goal, bleibt katalog-only.** Die KI-Erfassung matcht Freitext aus
  Buchungsbestätigungen gegen die feste Schiffsliste als Best-Effort-Vorbefüllung.
  Eigene Schiffe sind nutzergetippt und potenziell uneinheitlich benannt;
  Fuzzy-Matching gegen eine variable, nutzerdefinierte Liste erhöht die
  Fehlerquote (Fehlzuordnungen) für einen seltenen Vorteil. Bei Bedarf später
  erweiterbar, hier bewusst ausgeklammert.
- **`Cruise.shippingLineLogo` / `Deal.shippingLineLogo`
  (`Cruise.swift:130-132`, `Deal.swift:106-109`) und `StatsView.swift:214`:**
  **Non-Goal, bleiben katalog-only.** Diese Computed Properties laufen auf
  `@Model`-Klassen ohne `ModelContext`-Zugriff und können keine `@Query`-Daten
  konsultieren. Für eigene Reedereien greift weiterhin der vorhandene
  generische Fallback `"🛳️"`. Eine Behebung (z. B. Logo beim Speichern auf
  `Cruise`/`Deal` denormalisieren) ist ein separater, kleinerer Folge-Task,
  falls Nutzerfeedback das verlangt — hier bewusst nicht mitgelöst, um den
  Scope dieser Welle nicht zu sprengen.

### 9. Non-Goals (explizit)

- Kein Hidden-Zustand für eigene Einträge (löschen statt verstecken).
- Kein Logo-Upload/Custom-Icon-Picker für eigene Reedereien in dieser Welle —
  `logo: String` nimmt ein Emoji, Default `"🚢"`, analog zum Katalog-Feld.
- Keine referenzielle Reparatur, wenn ein Katalog-Schiffsname sich ändert
  (Hide verwaist stillschweigend, siehe Abschnitt 2).
- Kein Realtime-Merge-UI für Post-Sync-Dedup-Konflikte (z. B. "zwei Geräte
  haben unterschiedliche Schiffe unter derselben Custom-Reederei angelegt,
  wähle aus") — die deterministische Gewinner-Regel (Abschnitt 6) läuft
  stillschweigend im Hintergrund, ohne Nutzer-Interaktion. Für den engen
  Anwendungsfall (Single-User über mehrere eigene Geräte) ausreichend.

---

## Konsequenzen

**Positiv**

- Kein Schema-Change an `Cruise`/`Deal` nötig — beide bleiben reine Strings,
  Bestandsdaten sind nie betroffen, Migrationsrisiko minimal.
- Drei flache, relationship-freie Modelle sind CloudKit-konform ohne
  Sonderfälle und leicht zu testen (reine Funktionen für Merge/Sortierung).
- Einheitlicher String-Schlüssel für Katalog- und Custom-Referenzen hält
  Service und Views auf einem Codepfad statt zwei Referenzarten.
- Strikte Kollisions-Ablehnung vermeidet verwirrende Picker-Duplikate.
- Post-Sync-Dedup und Preserve-on-save schließen die beiden vom Codex-Gate
  identifizierten Datenverlust-/Datenfragmentierungspfade, ohne dass der
  Nutzer manuell eingreifen muss.

**Negativ / Risiken**

- Keine DB-seitige referenzielle Integrität zwischen `CustomShip.lineOptionID`
  und der Zielreederei. `deleteCustomLine` muss **im Service-Code** aktiv alle
  `CustomShip`-Zeilen mit passender `lineOptionID` mitlöschen (App-seitiges
  Cascade statt SwiftData-`@Relationship`-Cascade) — wird bei Refactorings
  leicht vergessen; Unit-Test dafür ist Pflicht (siehe Acceptance-Tests).
- Hidden-Keys für Schiffe verwaisen stillschweigend bei künftigen
  Katalog-Umbenennungen (akzeptiertes Risiko, s. o.).
- `shippingLineLogo` zeigt für eigene Reedereien weiterhin nur den generischen
  Fallback, nicht das vom Nutzer gewählte Logo — bewusste Einschränkung
  dieser Welle (Non-Goal).
- `findByShipName` erkennt keine eigenen Schiffe — bewusste Einschränkung
  dieser Welle (Non-Goal).
- Zusätzlicher Launch-Repair-Pass (`ShippingLineCatalogDedup`) erhöht die
  Zahl der beim App-Start laufenden Migrations-/Reparatur-Routinen; muss wie
  `IdBackfill` sorgfältig idempotent und fehlertolerant sein (kein Crash bei
  leerem Store).
- Die Preserve-on-save-Regel (Abschnitt 5) ersetzt bestehende, funktionierende
  View-Logik (`CruiseFormView.swift:222-224`) durch die neue
  `.unlisted`-Option — Dev-B muss diesen Codepfad vollständig ablösen, nicht
  nur ergänzen, sonst entstehen zwei konkurrierende Fallback-Mechanismen.

**Neutral**

- Drei neue, kleine Tabellen im Store; vernachlässigbarer Speicher-Overhead.
- Ein bestehender Datei-Touch außerhalb der neuen Dateien: `ShippingLine.swift`
  erhält die extrahierte `normalizedShipKey(_:)`-Funktion (kein
  Verhaltenswechsel an `findByShipName`).

---

## Alternativen

**Option A: `CustomShip` referenziert `CustomShippingLine` per
`@Relationship`, Schiffe unter Katalog-Reedereien sind nicht möglich**
Abgelehnt. Würde den häufigsten realen Fall — ein einzelnes fehlendes Schiff
bei einer sonst vollständigen Katalog-Reederei nachtragen — ausschließen und
den Nutzer zwingen, für ein Schiff eine komplette Parallel-Reederei
anzulegen.

**Option B: Kollidierende Custom-Einträge als separat angezeigtes Duplikat
zulassen ("Eigener Eintrag" mit gleichem Namen)**
Abgelehnt. Erzeugt zwei fast identische Picker-Zeilen mit identischem
sichtbaren Namen; Nutzer können nicht erkennen, welche der stabile
Katalog-Eintrag ist. Strikte Ablehnung mit Fehlermeldung ist eindeutiger.

**Option C: Ein gemeinsames Feld `ShippingLine.id` auf `Cruise`/`Deal`
einführen (Fremdschlüssel statt Freitext), um Reedereien/Schiffe eindeutig
zu referenzieren**
Abgelehnt. Bestandsdaten sind bereits namensbasiert; eine Umstellung auf
ID-Referenzen wäre ein Migrations- und Kompatibilitätsprojekt für sich (Import/
Export, KI-Erfassung, historische Freitexte) und steht in keinem Verhältnis
zum Nutzen dieser Welle.

**Option D: Hidden-Status direkt als Feld auf einem gecachten
Katalog-Duplikat in SwiftData (jede Katalog-Reederei/-Schiff als Zeile
gespiegelt, mit `isHidden`-Flag)**
Abgelehnt. Erfordert Synchronisation zwischen Code-Katalog und DB-Spiegel bei
jedem Katalog-Update (App-Release) — zusätzlicher Migrationsmechanismus ohne
Mehrwert gegenüber einer schlanken Hidden-Liste, die nur die Ausnahmen
speichert.

**Option E: Kein Post-Sync-Dedup — Duplikate bleiben nebeneinander bestehen,
Nutzer räumt manuell auf**
Abgelehnt (Gate-4-Finding, HIGH). Erzeugt für den Nutzer unsichtbar
fragmentierte Daten ("warum habe ich AIDA zweimal in der Liste?") ohne
erkennbare Ursache und widerspricht dem in ADR-002 festgelegten Grundsatz,
dass Dedup ohne DB-Uniques explizit App-Aufgabe ist.

**Option F: Edit-Formular zwingt bei fehlender/veralteter Reederei-Auswahl
zur manuellen Neuauswahl, statt automatisch zu preserven**
Abgelehnt (Gate-4-Finding, HIGH). Der bestehende Bug (stillschweigendes
Überschreiben mit `""` beim bloßen Öffnen+Speichern) ist für ein
Reise-Tagebuch mit Bestandsdaten ein inakzeptabler Datenverlust; eine
Pflicht-Neuauswahl würde denselben Fehler nur in eine andere Form
(unbeabsichtigtes Leerlassen) verschieben, statt ihn zu beheben.

---

## Verbindliche Acceptance-Tests

1. Katalog- und Custom-Reedereien erscheinen gemischt, alphabetisch (nach
   `collisionKey`) sortiert im Picker.
2. Ausgeblendete Katalog-Reederei/-Schiff verschwindet aus
   `shippingLineOptions`/`shipOptions`.
3. Unhide stellt den Eintrag wieder her (an ursprünglicher Sortierposition).
4. Anlegen einer Custom-Reederei/eines Custom-Schiffs mit Namenskollision
   (Katalog oder bestehender Custom-Eintrag) wird abgelehnt, kein Duplikat
   entsteht.
5. Löschen einer `CustomShippingLine` lässt bestehende `Cruise`/`Deal`-Zeilen,
   die diesen Namen als Freitext trugen, unverändert (historischer Name
   bleibt beim Bearbeiten sichtbar) — UND löscht alle zugehörigen
   `CustomShip`-Zeilen mit (App-seitiges Cascade, s. Konsequenzen).
6. `ShippingLine.findByShipName` bleibt für alle bestehenden Katalog-Schiffe
   funktional unverändert (Regressionstest gegen die bestehenden Tests in
   `ShipTripTests.swift:127-135`).
7. **Post-Sync-Dedup:** Zwei simulierte Geräte legen offline dieselbe
   Custom-Reederei (gleicher `collisionKey`) mit unterschiedlichen UUIDs an,
   inklusive je eines `CustomShip` darunter; nach `ShippingLineCatalogDedup.run`
   existiert nur noch eine `CustomShippingLine`-Zeile (ältestes `createdAt`
   gewinnt), beide `CustomShip`-Zeilen zeigen auf deren `lineOptionID`, keine
   verwaisten Referenzen. Analoger Test für `CustomShip`- und
   `HiddenCatalogItem`-Duplikate.
8. **Preserve-on-save:** Eine `Cruise` mit einer zwischenzeitlich gelöschten
   oder ausgeblendeten Reederei/Schiff wird im Bearbeiten-Formular geöffnet
   und ohne Änderung der Auswahl gespeichert — `shippingLine`/`ship` bleiben
   exakt der ursprüngliche String, kein Reset auf `""`/`nil`. Analoger Test
   für `DealsView`.

---

## Parallelisierungsplan

**Dev-A — Models, Service, Dedup, Tests (seriell zuerst: Schema-Registrierung)**
`ShipTrip/Models/CustomShippingLine.swift`,
`ShipTrip/Models/CustomShip.swift`, `ShipTrip/Models/HiddenCatalogItem.swift`
(neu) · `ShipTrip/Models/ShippingLineOption.swift` (DTOs + Error, neu) ·
`ShipTrip/Services/ShippingLineCatalogService.swift` (neu, inkl.
`currentSelection`-Handling und `.unlisted`-Option) ·
`ShipTrip/Utilities/ShippingLineCatalogDedup.swift` (neu, analog
`IdBackfill.swift`) + Aufruf im `.task`-Block von
`ShipTrip/Views/Cruises/CruiseListView.swift` neben `IdBackfill.run`/
`ThumbnailBackfill.run` · `ShipTrip/Models/ShippingLine.swift` (Extraktion
`normalizedShipKey(_:)` + neue `ShippingLineNameMatching.collisionKey(_:)`,
chirurgisch) · `ShipTrip/ShipTripApp.swift` (Schema-Zeile ergänzen — **so früh
wie möglich**, da Dev-B's `@Query`-Views ohne diese Registrierung nicht
laufen) · neue Testdateien `ShipTripTests/ShippingLineCatalogServiceTests.swift`
und `ShipTripTests/ShippingLineCatalogDedupTests.swift`, je mit eigenem
Schema-Helfer.

**Dev-B — Views gegen den eingefrorenen Contract (kann sofort mit den
DTO-/API-Signaturen aus diesem ADR beginnen, ohne auf Dev-As Implementierung
zu warten)**
`ShipTrip/Views/Settings/` — neue Verwaltungs-Ansicht (Liste Katalog+Custom,
Hide/Unhide-Toggle, Anlegen/Bearbeiten/Löschen eigener Reedereien/Schiffe) ·
`ShipTrip/Views/Cruises/CruiseFormView.swift` (Picker-Umstellung, Zeilen
205-234; `loadExistingData()`/`Zeile 443` und `saveCruise()`/`Zeile 687` nach
Abschnitt 5 umbauen, dabei die bestehende Injektions-Logik `Zeile 222-224`
durch die `.unlisted`-Option ablösen, nicht duplizieren) ·
`ShipTrip/Views/Deals/DealsView.swift` (identische Picker-Umstellung und
Preserve-on-save-Fix, Zeilen 298-304, 358, 381).

**Serielle Kante:** einzig die Schema-Registrierung in `ShipTripApp.swift`
muss vor funktionierenden `@Query`-basierten Dev-B-Views existieren; alles
andere parallelisiert vollständig gegen den in Abschnitt 4 fixierten
Typ-Contract.

---

## Referenzen

- ADR-002 — CloudKit-Sync, stabile IDs (Constraints, denen diese Modelle folgen)
- ADR-001 — Schema-Stabilität (gemeinsame Motivation)
- `ShipTrip/Models/ShippingLine.swift` — Katalog, `findByShipName`,
  `find(byName:)`/`find(byId:)`
- `ShipTrip/Utilities/IdBackfill.swift`, `ShipTripTests/IdBackfillTests.swift`
  — Vorbild für `ShippingLineCatalogDedup` (Launch-Repair-Pattern,
  versioniertes Completed-Flag, MainActor/synchron/idempotent)
- `ShipTrip/Views/Cruises/CruiseListView.swift` — `.task`-Block, tatsächlicher
  Aufrufort von `IdBackfill.run`/`ThumbnailBackfill.run` (nicht
  `ShipTripApp.swift`)
- `ShipTrip/Models/Cruise.swift:130-132`, `ShipTrip/Models/Deal.swift:105-109`
  — `shippingLineLogo` (Non-Goal, Abschnitt 8)
- `ShipTrip/Views/Cruises/CruiseFormView.swift:205-234, 443, 519-538, 687` —
  bestehender Picker, Prefill, Edit-Mode-Fallback, Save (Preserve-on-save-Fix)
- `ShipTrip/Views/Deals/DealsView.swift:298-304, 358, 381` — bestehender
  Picker (In Scope, Preserve-on-save-Fix)
- `ShipTrip/Views/Stats/StatsView.swift:214` — Logo-Lookup (Non-Goal)
- `ShipTrip/ShipTripApp.swift` — Schema-Registrierung
- `ShipTripTests/ShipTripTests.swift:124-136` — bestehende `findByShipName`-Tests
  (Regressionsanker für Punkt 6 der Acceptance-Tests)
- `docs/umsetzungsplan-audit-2026-07.md` — Welle B5, ADR-Nummer-Reservierung
  (ADR-003 B2, ADR-004 C2, ADR-005 D1, ADR-006 B5)
