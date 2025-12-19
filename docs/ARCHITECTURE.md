# Architektur

Diese Dokumentation beschreibt die technische Architektur der ShipTrip iOS App.

## Übersicht

```
┌─────────────────────────────────────────────────────────────┐
│                        ShipTrip App                          │
├─────────────────────────────────────────────────────────────┤
│                                                              │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────────────┐  │
│  │   Views     │  │   Models    │  │     Services        │  │
│  │  (SwiftUI)  │  │ (SwiftData) │  │                     │  │
│  ├─────────────┤  ├─────────────┤  ├─────────────────────┤  │
│  │ CruiseList  │  │ Cruise      │  │ GeminiService       │  │
│  │ CruiseForm  │  │ Port        │  │ KeychainService     │  │
│  │ MapView     │  │ Expense     │  │ NotificationService │  │
│  │ StatsView   │  │ Deal        │  │                     │  │
│  │ DealsView   │  │ Photo       │  │                     │  │
│  │ Settings    │  │             │  │                     │  │
│  └─────────────┘  └─────────────┘  └─────────────────────┘  │
│         │                │                   │               │
│         └────────────────┴───────────────────┘               │
│                          │                                   │
│  ┌───────────────────────┴───────────────────────────────┐  │
│  │                    SwiftData                           │  │
│  │              (ModelContainer / ModelContext)           │  │
│  └───────────────────────────────────────────────────────┘  │
│                          │                                   │
│  ┌───────────────────────┴───────────────────────────────┐  │
│  │                  Lokale SQLite DB                      │  │
│  └───────────────────────────────────────────────────────┘  │
│                                                              │
└─────────────────────────────────────────────────────────────┘
                           │
          ┌────────────────┴────────────────┐
          │                                 │
          ▼                                 ▼
┌─────────────────┐               ┌─────────────────┐
│  Gemini API     │               │  Apple Services │
│  (Google AI)    │               │  - MapKit       │
│                 │               │  - Keychain     │
│                 │               │  - Notifications│
└─────────────────┘               └─────────────────┘
```

## Schichten

### 1. Präsentationsschicht (Views)

| View | Beschreibung |
|------|--------------|
| `MainTabView` | Tab-Navigation (Reisen, Karte, Angebote, Statistik, Einstellungen) |
| `CruiseListView` | Übersicht aller Kreuzfahrten |
| `CruiseDetailView` | Detailansicht einer Kreuzfahrt |
| `CruiseFormView` | Erstellen/Bearbeiten mit AI-Import |
| `MapView` | Weltkarte mit Routen-Visualisierung |
| `StatsView` | Statistiken mit Charts |
| `DealsView` | Angebote-Übersicht |
| `SettingsView` | App-Einstellungen |

### 2. Datenmodell-Schicht (Models)

Alle Models verwenden **SwiftData** mit dem `@Model` Macro:

```swift
@Model
final class Cruise {
    var title: String
    var startDate: Date
    var endDate: Date
    // ...
    var route: [Port]        // Relationship
    var expenses: [Expense]  // Relationship
    var photos: [Photo]      // Relationship
}
```

#### Beziehungen

```
Cruise (1) ──────< Port (n)
   │
   ├───────────< Expense (n)
   │
   └───────────< Photo (n)
```

### 3. Service-Schicht

| Service | Verantwortung |
|---------|---------------|
| `GeminiService` | KI-Integration für Buchungsimport |
| `KeychainService` | Sichere Speicherung von API-Keys |
| `NotificationService` | Push-Benachrichtigungen vor Reisen |

## Datenfluss

### 1. Kreuzfahrt erstellen

```
User Input → CruiseFormView → Cruise Model → SwiftData → SQLite
                    │
                    ├── AI Import (optional)
                    │      │
                    │      └── GeminiService → Gemini API
                    │
                    └── Port Suggestions → PortSuggestion.swift (statisch)
```

### 2. Karten-Visualisierung

```
SwiftData Query → [Cruise] → MapView
                              │
                              ├── Filter: hasValidCoordinates
                              │
                              ├── MapPolyline (Route)
                              │
                              └── Annotations (Häfen)
```

## Technologie-Stack

| Kategorie | Technologie | Version |
|-----------|-------------|---------|
| UI | SwiftUI | 5.0 |
| Datenbank | SwiftData | 1.0 |
| Karten | MapKit | - |
| Charts | Swift Charts | - |
| AI | Gemini API | 2.5 Flash |
| Sicherheit | Keychain Services | - |
| Notifications | UserNotifications | - |

## Datei-Organisation

```
ShipTrip/
├── App/
│   └── ShipTripApp.swift       # @main Entry Point
├── Models/                      # SwiftData Models
├── Views/                       # SwiftUI Views (nach Feature)
│   ├── Cruises/
│   ├── Map/
│   ├── Deals/
│   ├── Stats/
│   └── Settings/
├── Services/                    # Business Logic
├── Components/                  # Wiederverwendbare UI-Komponenten
├── Utilities/                   # Extensions & Helpers
└── Assets.xcassets/            # Bilder & App Icon
```

## Threading

- **Main Thread**: Alle UI-Updates
- **Background**: 
  - Gemini API Calls (`async/await`)
  - Foto-Loading (`Task {}`)
  - SwiftData ist thread-safe

## Speicher

| Datentyp | Speicherort |
|----------|-------------|
| Cruise/Port/Expense | SwiftData (SQLite) |
| Fotos | SwiftData mit `@Attribute(.externalStorage)` |
| API Keys | iOS Keychain |
| User Defaults | Standard UserDefaults |
