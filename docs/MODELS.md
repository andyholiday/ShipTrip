# Datenmodelle

Dokumentation aller SwiftData-Models in ShipTrip. Quelle: `ShipTrip/Models/`.

Es gibt acht `@Model`-Klassen. Genau diese acht registriert `ShipTripApp.swift`
im `Schema([...])`-Array des `ModelContainer`.

Alle acht tragen ein app-seitiges `id: UUID` (kein `@Attribute(.unique)`, siehe
[ADR-002](adr/ADR-002-cloudkit-sync-und-stabile-ids.md)). Sieben führen zusätzlich
ein `updatedAt: Date` für App-Level Last-Writer-Wins; einzige Ausnahme ist
`HiddenCatalogItem`, das laut
[ADR-006](adr/ADR-006-eigene-reedereien-und-schiffe-overlay-modell.md) nur
`createdAt` besitzt. `updatedAt` wird von SwiftData **nicht** automatisch gebumpt;
das muss jeder Schreibpfad manuell tun.

## Übersicht

| Model | Beschreibung | Beziehungen |
|-------|--------------|-------------|
| `Cruise` | Kreuzfahrt-Reise | → `Port`, `Expense`, `Photo` (je `.cascade`) |
| `Port` | Hafen/Seetag auf der Route | → `Cruise` (Inverse) |
| `Expense` | Ausgabe | → `Cruise` (Inverse) |
| `Photo` | Foto | → `Cruise` (Inverse) |
| `Deal` | Gespeichertes Angebot | keine |
| `CustomShippingLine` | Eigene Reederei (Katalog-Overlay) | keine |
| `CustomShip` | Eigenes Schiff (Katalog-Overlay) | keine, String-Referenz `lineOptionID` |
| `HiddenCatalogItem` | Ausgeblendeter Katalog-Eintrag | keine |

---

## Cruise

`ShipTrip/Models/Cruise.swift` — die zentrale Entität für eine Kreuzfahrt-Reise.

### Properties

| Property | Typ | Default | Beschreibung |
|----------|-----|---------|--------------|
| `id` | `UUID` | `UUID()` | Stabile App-seitige ID |
| `title` | `String` | `""` | Titel der Reise |
| `startDate` | `Date` | `Date()` | Abreisedatum |
| `endDate` | `Date` | `Date()` | Rückkehrdatum |
| `shippingLine` | `String` | `""` | Reederei (Freitext, i. d. R. `ShippingLine.name`) |
| `ship` | `String` | `""` | Schiffsname |
| `cabinType` | `String` | `""` | Kabinentyp |
| `cabinNumber` | `String` | `""` | Kabinennummer |
| `bookingNumber` | `String` | `""` | Buchungsnummer |
| `notes` | `String` | `""` | Persönliche Notizen |
| `rating` | `Double` | `0` | Bewertung (0–5, keine Ganzzahl) |
| `createdAt` | `Date` | `Date()` | Erstellungsdatum |
| `updatedAt` | `Date` | `Date()` | Letztes Änderungsdatum (LWW) |
| `isDemo` | `Bool` | `false` | Markiert Demo-Daten für sauberes Entfernen (siehe [ADR-001](adr/ADR-001-isdemo-in-release-schema.md)) |

### Relationships

```swift
@Relationship(deleteRule: .cascade, originalName: "route", inverse: \Port.cruise)
var routeStorage: [Port]?

@Relationship(deleteRule: .cascade, originalName: "expenses", inverse: \Expense.cruise)
var expensesStorage: [Expense]?

@Relationship(deleteRule: .cascade, originalName: "photos", inverse: \Photo.cruise)
var photosStorage: [Photo]?
```

Die optionalen Storage-Beziehungen erfüllen die CloudKit-Anforderung. Die
berechneten Properties `route`, `expenses` und `photos` stellen der App weiterhin
nicht-optionale Arrays bereit. `originalName` erhält die bisherigen Relationship-
Namen für die Store-Migration.

### Computed Properties

| Property | Typ | Beschreibung |
|----------|-----|--------------|
| `duration` | `Int` | Reisedauer in Tagen, inklusive Start- und Endtag |
| `isUpcoming` | `Bool` | `startDate > Date()` |
| `isOngoing` | `Bool` | `startDate <= now && endDate >= now` |
| `year` | `Int` | Kalenderjahr von `startDate` |
| `totalExpenses` | `Double` | Summe aller `expenses.amount` |
| `countriesVisited` | `Set<String>` | Eindeutige Länder aus `route` |
| `shippingLineLogo` | `String` | Emoji-Logo via `ShippingLine.all`, Fallback `"🛳️"` |
| `sortedPhotos` | `[Photo]` | `photos`, sortiert nach `sortOrder` |

### `Array<Cruise>`-Aggregat-Helfer

Erweiterung direkt in `Cruise.swift`, für Lifetime-Statistiken über mehrere Reisen:

| Property | Typ | Beschreibung |
|----------|-----|--------------|
| `uniqueCountryCount` | `Int` | Eindeutige, nicht-leere Länder über alle Reisen |
| `totalSeaDays` | `Int` | Summe aller Ports mit `isSeaDay == true` |
| `totalPortStops` | `Int` | Summe aller Ports mit `isSeaDay == false` |
| `totalTravelDays` | `Int` | Summe aller `duration`-Werte |

---

## Port

`ShipTrip/Models/Port.swift` — ein Hafen (oder Seetag) auf der Kreuzfahrt-Route.

### Properties

| Property | Typ | Default | Beschreibung |
|----------|-----|---------|--------------|
| `id` | `UUID` | `UUID()` | Stabile App-seitige ID |
| `name` | `String` | `""` | Hafenname |
| `country` | `String` | `""` | Land |
| `latitude` | `Double` | `0` | Breitengrad |
| `longitude` | `Double` | `0` | Längengrad |
| `arrival` | `Date` | `Date()` | Ankunftsdatum/-zeit |
| `departure` | `Date` | `Date()` | Abfahrtsdatum/-zeit |
| `sortOrder` | `Int` | `0` | Position in der Route |
| `isSeaDay` | `Bool` | `false` | Seetag (kein Landgang) |
| `imageData` | `Data?` | `nil` | Optionales Hafenbild, `@Attribute(.externalStorage)` |
| `excursionsRaw` | `String` | `""` | Ausflüge, komma-separiert gespeichert |
| `updatedAt` | `Date` | `Date()` | Letztes Änderungsdatum (LWW) |

### Relationship

```swift
var cruise: Cruise?
```

Inverse Seite der `Cruise.route`-Relationship; kein eigenes `@Relationship`-Attribut nötig.

### Computed Properties

| Property | Typ | Beschreibung |
|----------|-----|--------------|
| `excursions` | `[String]` | Get/Set-Wrapper um `excursionsRaw` (Trenner: `", "`) |
| `hasValidCoordinates` | `Bool` | `!isSeaDay && !(latitude == 0 && longitude == 0)` |
| `coordinate` | `CLLocationCoordinate2D` | Für MapKit |
| `stayDuration` | `Int` | Aufenthalt in vollen Stunden (`arrival`→`departure`, min. 0) |
| `formattedArrival` / `formattedDeparture` | `String` | Geräte-lokalisiert (`.abbreviated`/`.shortened`) |

---

## Expense

`ShipTrip/Models/Expense.swift` — eine Ausgabe während der Kreuzfahrt.

### Properties

| Property | Typ | Default | Beschreibung |
|----------|-----|---------|--------------|
| `id` | `UUID` | `UUID()` | Stabile App-seitige ID |
| `categoryRaw` | `String` | `""` | Kategorie, als Rohstring gespeichert (siehe unten) |
| `descriptionText` | `String` | `""` | Beschreibung |
| `amount` | `Double` | `0` | Betrag in Geräte-Währung (kein hartkodiertes EUR) |
| `expenseDate` | `Date?` | `nil` | Datum der Ausgabe (optional) |
| `createdAt` | `Date` | `Date()` | Erstellungsdatum |
| `updatedAt` | `Date` | `Date()` | Letztes Änderungsdatum (LWW) |

### Relationship

```swift
var cruise: Cruise?
```

### `ExpenseCategory` (Enum)

`rawValue` ist der stabile Speicher-Schlüssel (deutscher String); `displayName`
lokalisiert diesen Schlüssel separat über `String(localized:)`.

| Case | `rawValue` | Icon (SF Symbol) |
|------|-----------|-------------------|
| `.cruise` | `"Kreuzfahrt"` | `ferry` |
| `.flight` | `"Flug"` | `airplane` |
| `.hotel` | `"Hotel"` | `bed.double` |
| `.excursion` | `"Ausflug"` | `figure.walk` |
| `.onboard` | `"An Bord"` | `dollarsign.circle` |
| `.other` | `"Sonstiges"` | `ellipsis.circle` |

### Computed Properties

| Property | Typ | Beschreibung |
|----------|-----|--------------|
| `category` | `ExpenseCategory` | Get/Set-Wrapper um `categoryRaw`, Fallback `.other` |
| `formattedAmount` | `String` | `amount.formattedCurrencyOrNumber` |

`Double.formattedCurrencyOrNumber` (Extension in `Expense.swift`) formatiert
als Währung, wenn `Locale.current.currency` bekannt ist, sonst als neutrales
Zahlenformat mit zwei Nachkommastellen — kein hartkodierter `"EUR"`-Fallback.

---

## Photo

`ShipTrip/Models/Photo.swift` — ein Foto zu einer Kreuzfahrt.

### Properties

| Property | Typ | Default | Beschreibung |
|----------|-----|---------|--------------|
| `id` | `UUID` | `UUID()` | Stabile App-seitige ID |
| `imageData` | `Data` | `Data()` | Bilddaten, `@Attribute(.externalStorage)` |
| `thumbnailData` | `Data?` | `nil` | Vorschaubild, wird beim Import via `ImageDownsampler.thumbnail(from:)` befüllt (`ShipTrip/Utilities/ImageDownsampler.swift`); Bestandsdaten werden per `ThumbnailBackfill` nachgezogen |
| `sortOrder` | `Int` | `0` | Reihenfolge |
| `createdAt` | `Date` | `Date()` | Erstellungsdatum |
| `updatedAt` | `Date` | `Date()` | Letztes Änderungsdatum (LWW) |

### Relationship

```swift
var cruise: Cruise?
```

### Storage

```swift
@Attribute(.externalStorage)
var imageData: Data = Data()
```

> **Hinweis**: `.externalStorage` speichert große Binärdaten außerhalb der
> SQLite-DB. Der nicht-optionale Default `Data()` ist Voraussetzung für die
> CloudKit-Schema-Constraints aus ADR-002 §3.

---

## Deal

`ShipTrip/Models/Deal.swift` — ein gespeichertes Kreuzfahrt-Angebot. Keine Relationships.

### Properties

| Property | Typ | Default | Beschreibung |
|----------|-----|---------|--------------|
| `id` | `UUID` | `UUID()` | Stabile App-seitige ID |
| `title` | `String` | `""` | Titel des Angebots |
| `shippingLine` | `String?` | `nil` | Reederei |
| `price` | `Double?` | `nil` | Aktueller Preis |
| `originalPrice` | `Double?` | `nil` | Originalpreis vor Rabatt |
| `startDate` | `Date?` | `nil` | Startdatum der Kreuzfahrt |
| `endDate` | `Date?` | `nil` | Enddatum der Kreuzfahrt |
| `destination` | `String?` | `nil` | Zielregion/Destination |
| `ship` | `String?` | `nil` | Schiffsname |
| `url` | `String?` | `nil` | Link zur Buchungsseite |
| `notes` | `String?` | `nil` | Persönliche Notizen |
| `createdAt` | `Date` | `Date()` | Speicherzeitpunkt |
| `updatedAt` | `Date` | `Date()` | Letztes Änderungsdatum (LWW) |
| `isDemo` | `Bool` | `false` | Markiert Demo-Daten |

### Computed Properties

| Property | Typ | Beschreibung |
|----------|-----|--------------|
| `discountPercent` | `Int?` | Rabatt in %, `nil` falls kein `originalPrice`/kein Preisvorteil |
| `savings` | `Double?` | Ersparnis `original - current` |
| `formattedPrice` / `formattedOriginalPrice` | `String?` | via `formattedCurrencyOrNumber` |
| `duration` | `Int?` | Tage inklusive, `nil` falls Start-/Enddatum fehlt |
| `shippingLineLogo` | `String` | Emoji via `ShippingLine.all`, Fallback `"🛳️"` |

---

## Katalog-Overlay-Modelle

Die folgenden drei Modelle legen eigene Reedereien/Schiffe **über** den
hartkodierten `ShippingLine`-Katalog, ohne diesen zu verändern. Sie sind flach
(keine `@Relationship` untereinander und keine zu `Cruise`/`Deal`), weil
`ShippingLine` kein `PersistentModel` ist und `Cruise.shippingLine`/`Cruise.ship`
reine Strings bleiben. Entscheidung und Randbedingungen:
[ADR-006](adr/ADR-006-eigene-reedereien-und-schiffe-overlay-modell.md).

Merge, Sortierung und Schreibpfade liegen in
`ShipTrip/Services/ShippingLineCatalogService.swift`; Views verwenden dessen
reine Funktionen `shippingLineOptions(...)` / `shipOptions(...)` und die DTOs
`ShippingLineOption` / `ShipOption` (`ShipTrip/Models/ShippingLineOption.swift`,
kein `@Model`).

### CustomShippingLine

`ShipTrip/Models/CustomShippingLine.swift` — eine vom Nutzer angelegte Reederei.

| Property | Typ | Default | Beschreibung |
|----------|-----|---------|--------------|
| `id` | `UUID` | `UUID()` | Stabile App-seitige ID; alleiniges Ziel für `updateCustomLine`/`deleteCustomLine` |
| `name` | `String` | `""` | Name der Reederei |
| `logo` | `String` | `"🚢"` | Emoji-Logo, analog `ShippingLine.logo` (kein Logo-Upload) |
| `createdAt` | `Date` | `Date()` | Erstellungsdatum, zugleich Dedup-Kriterium |
| `updatedAt` | `Date` | `Date()` | Letztes Änderungsdatum (LWW) |

### CustomShip

`ShipTrip/Models/CustomShip.swift` — ein vom Nutzer angelegtes Schiff.

| Property | Typ | Default | Beschreibung |
|----------|-----|---------|--------------|
| `id` | `UUID` | `UUID()` | Stabile App-seitige ID; alleiniges Ziel für `updateCustomShip`/`deleteCustomShip` |
| `name` | `String` | `""` | Schiffsname |
| `lineOptionID` | `String` | `""` | Referenz auf die Reederei: Katalog-ID (z. B. `"aida"`) oder `"custom:<UUID>"` |
| `createdAt` | `Date` | `Date()` | Erstellungsdatum, zugleich Dedup-Kriterium |
| `updatedAt` | `Date` | `Date()` | Letztes Änderungsdatum (LWW) |

### HiddenCatalogItem

`ShipTrip/Models/HiddenCatalogItem.swift` — ein ausgeblendeter Katalog-Eintrag.
Gilt nur für Katalog-Einträge; eigene Einträge werden gelöscht statt versteckt.

| Property | Typ | Default | Beschreibung |
|----------|-----|---------|--------------|
| `id` | `UUID` | `UUID()` | Stabile App-seitige ID |
| `lineID` | `String` | `""` | `ShippingLine.id` der betroffenen Katalog-Reederei |
| `shipKey` | `String?` | `nil` | `ShippingLine.normalizedShipKey(name)`; `nil` blendet die ganze Reederei aus |
| `createdAt` | `Date` | `Date()` | Erstellungsdatum, zugleich Dedup-Kriterium |

### Dedup ohne Unique-Constraints

Da CloudKit keine `@Attribute(.unique)` erlaubt (ADR-002), können zwei Geräte
offline kollidierende Zeilen anlegen. `ShippingLineCatalogDedup.run(context:)`
(`ShipTrip/Utilities/ShippingLineCatalogDedup.swift`) räumt das beim App-Start
auf — aufgerufen im `.task`-Block von `ShipTrip/Views/Cruises/CruiseListView.swift`,
mit eigenem Completed-Flag `"shippingLineCatalogDedupCompleted.v1"`.
Gewinner-Regel für alle drei Modelle: ältestes `createdAt`, bei Gleichstand die
lexikographisch kleinere `id.uuidString`. Kollisions-Kriterien:

- `CustomShippingLine`: gleicher `ShippingLineNameMatching.collisionKey(name)`;
  `CustomShip`-Zeilen der Verlierer werden vor dem Löschen auf den Gewinner
  umgeschrieben.
- `CustomShip`: gleiche `lineOptionID` **und** gleicher
  `ShippingLine.normalizedShipKey(name)`.
- `HiddenCatalogItem`: gleiche `lineID` **und** gleicher `shipKey` (inkl. beide `nil`).

---

## Hilfs-Strukturen (kein `@Model`, kein Storage)

### PortSuggestion

`ShipTrip/Models/PortSuggestion.swift` — statische Hafen-Datenbank für
Autocomplete, per Wikidata-Import befüllt (Stand dieser Doku: 1.956
`PortSuggestion`-Literale in `popular`).

```swift
struct PortSuggestion: Identifiable, Hashable {
    var id: String { "\(name)-\(country)" }
    let name: String
    let country: String
    let latitude: Double
    let longitude: Double
    var coordinate: CLLocationCoordinate2D { get }
}
```

- `PortSuggestion.findBestMatch(name:country:)` — bester Treffer für KI-Import
  (Priorität: 1. voller Match inkl. Klammerzusatz, 2. exakter Hauptname mit
  Hint/Land-Präferenz, 3. Fuzzy-Match).
- `PortSuggestion.search(...)` — Autocomplete-Suche.
- Beide Methoden nutzen einen vorberechneten `searchIndex` (akzent-gefaltete
  und kleingeschriebene Namensvarianten, einmalig beim ersten Zugriff gebaut)
  statt pro Tastenanschlag über alle Einträge zu scannen (Welle A3.6).

### ShippingLine

`ShipTrip/Models/ShippingLine.swift` — statische Reederei-Datenbank.

```swift
struct ShippingLine: Identifiable, Hashable {
    let id: String
    let name: String
    let logo: String           // Emoji
    let ships: [String]        // Aktive Schiffe, Auswahl für neue Reisen
    let historicalShips: [String] = []  // Ausgemusterte Schiffe, nur für Bestandsreisen
}
```

- `ShippingLine.all` — feste Liste aller unterstützten Reedereien (Stand Juni 2026).
- `find(byName:)`, `find(byId:)`, `findByShipName(_:)` (durchsucht `ships` **und** `historicalShips`).
- `coverAssetName`, `coverPoolAssetNames`, `coverPoolAssetName(for:)`,
  `shipCoverAssetName(for:)`, `coverAssetCandidates(shippingLine:ship:)` —
  Auflösung der Reederei-/Schiffs-Cover-Assets (deterministischer Hash-basierter
  Slot pro Schiff, priorisierte Fallback-Kette bis `"cover_ocean_route"`).

---

## Entity-Relationship-Diagramm

```
┌─────────────┐
│   Cruise    │
├─────────────┤
│ id          │
│ title       │
│ shippingLine│
│ ship        │
│ startDate   │
│ endDate     │
│ rating      │
│ isDemo      │
│ ...         │
└──────┬──────┘
       │ .cascade, 1:n (je Relationship)
       ├──────────────────┬──────────────────┐
       ▼                  ▼                  ▼
┌─────────────┐    ┌─────────────┐    ┌─────────────┐
│    Port     │    │   Expense   │    │    Photo    │
├─────────────┤    ├─────────────┤    ├─────────────┤
│ id          │    │ id          │    │ id          │
│ name        │    │ categoryRaw │    │ imageData   │
│ country     │    │ amount      │    │ thumbnailD. │
│ lat/long    │    │ expenseDate │    │ sortOrder   │
│ arrival     │    │ cruise ─────┼┐   │ cruise ─────┼┐
│ departure   │    └─────────────┘│   └─────────────┘│
│ isSeaDay    │                   │                   │
│ imageData   │                   │                   │
│ cruise ─────┼───────────────────┴───────────────────┘
└─────────────┘

┌─────────────┐
│    Deal     │   (keine Relationships)
├─────────────┤
│ id, title, shippingLine, price, originalPrice,          │
│ startDate, endDate, destination, ship, url, notes, isDemo│
└─────────────┘

Katalog-Overlay — flach, keine Relationships, nur String-Referenzen:

┌────────────────────┐        ┌──────────────────────┐        ┌───────────────────┐
│ CustomShippingLine │        │      CustomShip      │        │ HiddenCatalogItem │
│ id, name, logo     │        │ id, name,            │        │ id, lineID,       │
└────────────────────┘        │ lineOptionID         │        │ shipKey?          │
                              └──────────────────────┘        └───────────────────┘
         ▲                               │                              │
         │ lineOptionID = "custom:<UUID>"│                              │
         └───────────────────────────────┤                              │
                                         │ oder Katalog-ID ("aida")     │ lineID/shipKey
                                         ▼                              ▼
                          ShippingLine.all (statischer Katalog, kein @Model)
```

## CloudKit-Status (projektweit)

CloudKit ist im Release-Build konfiguriert:

- `ShipTripCloudSync.persistentConfiguration` bindet den persistenten SwiftData-
  Store an die private Datenbank von `iCloud.com.andre.ShipTrip`; XCTest-Läufe
  verwenden bewusst `.none` und bleiben unabhängig von einem iCloud-Account.
- Alle acht Modelle besitzen Default-Werte, stabile app-seitige IDs ohne
  `@Attribute(.unique)` und optionale Beziehungen. `Cruise` kapselt seine drei
  optionalen Storage-Beziehungen hinter nicht-optionalen App-Properties; die
  drei Katalog-Overlay-Modelle sind vollständig beziehungsfrei.
- `docs/cloudkit/ShipTrip.ckdb` dokumentiert das installierte Development-Schema.
- Das Schema wurde am 08.08.2026 nach Production promotet. Der anschließende
  Export unter `docs/cloudkit/ShipTrip-production.ckdb` entspricht semantisch
  dem Development-Schema; Build 23 ist in App Store Connect `VALID`.

Details und Migrationsplan: [ADR-002](adr/ADR-002-cloudkit-sync-und-stabile-ids.md).
