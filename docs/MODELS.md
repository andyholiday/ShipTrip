# Datenmodelle

Dokumentation aller SwiftData-Models in ShipTrip. Quelle: `ShipTrip/Models/`.

Alle persistenten Modelle tragen ein app-seitiges `id: UUID` (kein
`@Attribute(.unique)`, siehe [ADR-002](adr/ADR-002-cloudkit-sync-und-stabile-ids.md))
sowie — mit Ausnahme von `Cruise.createdAt`/`isDemo` — ein `updatedAt: Date`-Feld
für App-Level Last-Writer-Wins. `updatedAt` wird von SwiftData **nicht** automatisch
gebumpt; das muss jeder Schreibpfad manuell tun.

## Übersicht

| Model | Beschreibung | Beziehungen |
|-------|--------------|-------------|
| `Cruise` | Kreuzfahrt-Reise | → `Port`, `Expense`, `Photo` (je `.cascade`) |
| `Port` | Hafen/Seetag auf der Route | → `Cruise` (Inverse) |
| `Expense` | Ausgabe | → `Cruise` (Inverse) |
| `Photo` | Foto | → `Cruise` (Inverse) |
| `Deal` | Gespeichertes Angebot | keine |

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
@Relationship(deleteRule: .cascade, inverse: \Port.cruise)
var route: [Port] = []

@Relationship(deleteRule: .cascade, inverse: \Expense.cruise)
var expenses: [Expense] = []

@Relationship(deleteRule: .cascade, inverse: \Photo.cruise)
var photos: [Photo] = []
```

> **Bekannte CloudKit-Lücke:** ADR-002 §3 verlangt optionale Beziehungen für
> CloudKit-Mirroring. `route`, `expenses` und `photos` sind aktuell
> **nicht-optionale** Arrays (`[Port] = []` statt `[Port]?`). Solange das nicht
> behoben ist, ist das Schema nicht CloudKit-konform — siehe
> [„CloudKit-Status" unten](#cloudkit-status-projektweit).

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

## Hilfs-Strukturen (kein `@Model`, kein Storage)

### PortSuggestion

`ShipTrip/Models/PortSuggestion.swift` — statische Hafen-Datenbank für
Autocomplete, per Wikidata-Import befüllt (aktuell rund 1.900 Einträge, Stand
dieser Doku: 1.933 `PortSuggestion`-Literale in `popular`).

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
```

## CloudKit-Status (projektweit)

CloudKit ist **vorbereitet, aber nicht aktiv und nicht konform**:

- `ShipTripApp.swift` verwendet `ModelConfiguration(schema:isStoredInMemoryOnly:)`
  ohne `cloudKitDatabase:` — kein CloudKit-Container ist konfiguriert.
- Alle Modelle haben stabile `id: UUID`-Felder und (bis auf `Cruise.createdAt`)
  `updatedAt`-Felder für die geplante Last-Writer-Wins-Logik.
- **Offene Lücke:** `Cruise.route`, `Cruise.expenses` und `Cruise.photos` sind
  nicht-optionale Arrays; ADR-002 §3 verlangt optionale Beziehungen für
  CloudKit-Mirroring. Diese drei Felder müssten vor einer CloudKit-Aktivierung
  auf `[Port]?` / `[Expense]?` / `[Photo]?` umgestellt werden.

Details und Migrationsplan: [ADR-002](adr/ADR-002-cloudkit-sync-und-stabile-ids.md).
