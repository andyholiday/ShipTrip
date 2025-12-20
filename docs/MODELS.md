# Datenmodelle

Dokumentation aller SwiftData-Models in ShipTrip.

## Übersicht

| Model | Beschreibung | Beziehungen |
|-------|--------------|-------------|
| `Cruise` | Kreuzfahrt-Reise | → Port, Expense, Photo |
| `Port` | Hafen auf der Route | → Cruise |
| `Expense` | Ausgabe | → Cruise |
| `Photo` | Foto | → Cruise |
| `Deal` | Angebot | - |

---

## Cruise

Die zentrale Entität für eine Kreuzfahrt-Reise.

### Properties

| Property | Typ | Beschreibung |
|----------|-----|--------------|
| `id` | `UUID` | Eindeutige ID (automatisch) |
| `title` | `String` | Titel der Reise |
| `shippingLine` | `String` | Reederei (z.B. "AIDA") |
| `ship` | `String` | Schiffsname |
| `startDate` | `Date` | Abreisedatum |
| `endDate` | `Date` | Rückkehrdatum |
| `cabinType` | `String` | Kabinentyp |
| `bookingNumber` | `String` | Buchungsnummer |
| `notes` | `String` | Notizen |
| `rating` | `Int` | Bewertung (0-5) |

### Computed Properties

| Property | Typ | Beschreibung |
|----------|-----|--------------|
| `duration` | `Int` | Anzahl Nächte |
| `year` | `Int` | Jahr der Reise |
| `isUpcoming` | `Bool` | Liegt in der Zukunft |
| `isPast` | `Bool` | Liegt in der Vergangenheit |
| `sortedPhotos` | `[Photo]` | Fotos nach Reihenfolge |
| `sortedRoute` | `[Port]` | Route nach Reihenfolge |

### Beziehungen

```swift
@Relationship(deleteRule: .cascade, inverse: \Port.cruise)
var route: [Port]

@Relationship(deleteRule: .cascade, inverse: \Expense.cruise)
var expenses: [Expense]

@Relationship(deleteRule: .cascade, inverse: \Photo.cruise)
var photos: [Photo]
```

---

## Port

Ein Hafen auf der Kreuzfahrt-Route.

### Properties

| Property | Typ | Beschreibung |
|----------|-----|--------------|
| `name` | `String` | Hafenname |
| `country` | `String` | Land |
| `latitude` | `Double` | Breitengrad |
| `longitude` | `Double` | Längengrad |
| `arrival` | `Date` | Ankunftsdatum/-zeit |
| `departure` | `Date` | Abfahrtsdatum/-zeit |
| `sortOrder` | `Int` | Position in der Route |
| `isSeaDay` | `Bool` | Ist dies ein Seetag? |
| `imageData` | `Data?` | Optionales Hafenbild |
| `excursionsRaw` | `String` | Ausflüge (kommasepariert) |

### Computed Properties

| Property | Typ | Beschreibung |
|----------|-----|--------------|
| `coordinate` | `CLLocationCoordinate2D` | MapKit-Koordinate |
| `hasValidCoordinates` | `Bool` | Hat gültige Koordinaten (kein Seetag, nicht 0,0) |
| `excursions` | `[String]` | Ausflüge als Array |

### Beziehung

```swift
var cruise: Cruise?
```

---

## Expense

Eine Ausgabe während der Kreuzfahrt.

### Properties

| Property | Typ | Beschreibung |
|----------|-----|--------------|
| `title` | `String` | Bezeichnung |
| `amount` | `Double` | Betrag in EUR |
| `category` | `ExpenseCategory` | Kategorie |
| `date` | `Date` | Datum |
| `notes` | `String` | Notizen |

### ExpenseCategory (Enum)

| Case | Icon | Beschreibung |
|------|------|--------------|
| `.excursion` | 🚌 | Ausflüge |
| `.food` | 🍽️ | Essen & Getränke |
| `.shopping` | 🛍️ | Einkäufe |
| `.transport` | 🚕 | Transport |
| `.entertainment` | 🎭 | Unterhaltung |
| `.other` | 📦 | Sonstiges |

---

## Photo

Ein Foto zu einer Kreuzfahrt.

### Properties

| Property | Typ | Beschreibung |
|----------|-----|--------------|
| `imageData` | `Data` | Bilddaten (extern gespeichert) |
| `sortOrder` | `Int` | Reihenfolge |
| `createdAt` | `Date` | Erstellungsdatum |

### Storage

```swift
@Attribute(.externalStorage)
var imageData: Data
```

> **Hinweis**: `externalStorage` speichert große Binärdaten außerhalb der SQLite-DB für bessere Performance.

---

## Deal

Ein Kreuzfahrt-Angebot.

### Properties

| Property | Typ | Beschreibung |
|----------|-----|--------------|
| `title` | `String` | Angebotstitel |
| `shippingLine` | `String` | Reederei |
| `ship` | `String` | Schiff |
| `route` | `String` | Route-Beschreibung |
| `startDate` | `Date` | Abreisedatum |
| `endDate` | `Date` | Rückkehrdatum |
| `price` | `Double` | Preis in EUR |
| `originalPrice` | `Double?` | Originalpreis |
| `cabinType` | `String` | Kabinentyp |
| `url` | `String` | Link zum Angebot |
| `isSaved` | `Bool` | Gespeichert? |
| `notes` | `String` | Notizen |

### Computed Properties

| Property | Typ | Beschreibung |
|----------|-----|--------------|
| `duration` | `Int` | Anzahl Nächte |
| `discount` | `Int?` | Rabatt in % |

---

## Hilfs-Strukturen

### PortSuggestion

Statische Hafen-Datenbank für Autocomplete (~1.800 Häfen weltweit via Wikidata).

```swift
struct PortSuggestion: Identifiable, Hashable {
    let name: String
    let country: String
    let latitude: Double
    let longitude: Double
}
```

### ShippingLine

Statische Reederei-Datenbank.

```swift
struct ShippingLine: Identifiable, Hashable {
    let name: String
    let logo: String  // Emoji
}
```

---

## Entity-Relationship-Diagramm

```
┌─────────────┐
│   Cruise    │
├─────────────┤
│ id          │
│ title       │
│ shippingLine│
│ ship        │◄──────────────────┐
│ startDate   │                   │
│ endDate     │                   │
│ cabinType   │                   │
│ ...         │                   │
└──────┬──────┘                   │
       │                          │
       │ 1:n                      │
       │                          │
       ▼                          │
┌─────────────┐    ┌─────────────┐│   ┌─────────────┐
│    Port     │    │   Expense   ││   │    Photo    │
├─────────────┤    ├─────────────┤│   ├─────────────┤
│ name        │    │ title       ││   │ imageData   │
│ country     │    │ amount      ││   │ sortOrder   │
│ latitude    │    │ category    ││   │ createdAt   │
│ longitude   │    │ date        ││   │ cruise ─────┼┘
│ arrival     │    │ cruise ─────┼┘   └─────────────┘
│ departure   │    └─────────────┘
│ isSeaDay    │
│ cruise ─────┼────────────────────────────────────┘
└─────────────┘
```
