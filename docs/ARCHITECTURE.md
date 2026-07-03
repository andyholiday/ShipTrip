# Architektur

Diese Dokumentation beschreibt die technische Architektur der ShipTrip iOS App.
Stand: Xcode-Projekt `IPHONEOS_DEPLOYMENT_TARGET = 18.5`, `SWIFT_VERSION = 6.0`.

## Übersicht

```
┌─────────────────────────────────────────────────────────────┐
│                        ShipTrip App                          │
├─────────────────────────────────────────────────────────────┤
│                                                              │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────────────┐  │
│  │   Views     │  │   Models    │  │     Services         │  │
│  │  (SwiftUI)  │  │ (SwiftData) │  │                     │  │
│  ├─────────────┤  ├─────────────┤  ├─────────────────────┤  │
│  │ CruiseList  │  │ Cruise      │  │ GeminiService       │  │
│  │ CruiseForm  │  │ Port        │  │ KeychainService     │  │
│  │ CruiseDetail│  │ Expense     │  │ NotificationService │  │
│  │ MapView     │  │ Deal        │  │ ExportImportService │  │
│  │ StatsView   │  │ Photo       │  │ ZipArchiveWriter/   │  │
│  │ DealsView   │  │             │  │   Reader, CRC32     │  │
│  │ SettingsView│  │             │  │                     │  │
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
│                 │               │    (lokal)      │
└─────────────────┘               └─────────────────┘
```

CloudKit ist **nicht** Teil des aktiven Datenflusses — siehe
[„CloudKit-Status" in MODELS.md](MODELS.md#cloudkit-status-projektweit).

## Schichten

### 1. Präsentationsschicht (Views)

`MainTabView` ist die Root-View (fünf Tabs, siehe unten). Views sind nach
Feature-Ordnern gegliedert:

| View | Ordner | Beschreibung |
|------|--------|--------------|
| `MainTabView` | `Views/` | Tab-Navigation |
| `CruiseListView` | `Views/Cruises/` | „Meine Reisen" — Hybrid-Layout: Stats-Strip, Hero-Card, Timeline |
| `CruiseHeroCardView` | `Views/Cruises/` | Redaktionelle Hero-Card für die Fokus-Reise |
| `CruiseStatsStripView` | `Views/Cruises/` | Lifetime-Statistik-Strip (Reisen/Länder/Seetage/Häfen) |
| `CruiseTimelineRowView` | `Views/Cruises/` | Kompakte Zeitstrahl-Zeile inkl. Jahres-Trenner |
| `CruiseGeoFallbackView` | `Views/Cruises/` | Routenlinien-Fallback ohne Foto (Hero-Card, Karte) |
| `CruiseDetailView` | `Views/Cruises/` | Detailansicht einer Kreuzfahrt |
| `CruiseFormView` | `Views/Cruises/` | Erstellen/Bearbeiten inkl. KI-Import |
| `PortFormView` | `Views/Cruises/` | Hafen anlegen/bearbeiten |
| `ExpenseFormView` | `Views/Cruises/` | Ausgabe anlegen/bearbeiten |
| `RatingBadge` | `Views/Cruises/` | Sterne-Bewertungs-Badge |
| `MapView` | `Views/Map/` | Weltkarte mit Routen-Visualisierung |
| `DealsView` | `Views/Deals/` | Wunschreisen/Angebote-Übersicht |
| `StatsView` | `Views/Stats/` | Statistiken mit Swift Charts |
| `SettingsView` | `Views/Settings/` | App-Einstellungen, Export/Import, API-Key |

### Tabs (`MainTabView.swift`)

| Tag | Label | SF Symbol | View |
|-----|-------|-----------|------|
| 0 | „Reisen" | `ferry` | `CruiseListView` |
| 1 | „Karte" | `map` | `MapView` |
| 2 | „Wunschreisen" | `bookmark` | `DealsView` |
| 3 | „Bilanz" | `chart.bar` | `StatsView` |
| 4 | „Mehr" | `ellipsis` | `SettingsView` |

### 2. Datenmodell-Schicht (Models)

Alle Models verwenden **SwiftData** mit dem `@Model`-Macro. Vollständige
Property-/Relationship-Referenz: [MODELS.md](MODELS.md).

```swift
@Model
final class Cruise {
    var id: UUID = UUID()
    var title: String = ""
    var startDate: Date = Date()
    var endDate: Date = Date()
    // ...
    @Relationship(deleteRule: .cascade, inverse: \Port.cruise)
    var route: [Port] = []
    @Relationship(deleteRule: .cascade, inverse: \Expense.cruise)
    var expenses: [Expense] = []
    @Relationship(deleteRule: .cascade, inverse: \Photo.cruise)
    var photos: [Photo] = []
}
```

#### Beziehungen

```
Cruise (1) ──cascade──< Port (n)
   │
   ├──cascade──< Expense (n)
   │
   └──cascade──< Photo (n)

Deal — keine Relationships
```

### 3. Service-Schicht

| Service | Verantwortung |
|---------|---------------|
| `GeminiService` | KI-Integration für Buchungsimport (Gemini 2.5 Flash) |
| `KeychainService` | Sichere, geräte-gebundene Speicherung des Gemini-API-Keys |
| `NotificationService` | **Lokale** Erinnerungen vor Reisestart (kein APNs) |
| `ExportImportService` | Export/Import als JSON (Legacy) oder ZIP; Orchestrierung, keine ZIP-Bytes selbst |
| `ZipArchiveWriter` / `ZipArchiveReader` / `CRC32` | ZIP-Unterbau (STORED-Writer, STORED+Deflate-Reader, CRC-32) — seit Welle A3.11 eigene Dateien |
| `DemoDataService` | Demo-Daten seeden/entfernen (nur `#if DEBUG`) |

Vollständige API-Signaturen: [API.md](API.md).

### 4. Utilities

| Datei | Zweck |
|-------|-------|
| `Color+Theme.swift` | Farb-Token, `DesignRadius` (Corner-Radius-Stufen `sm`/`md`/`lg`) |
| `Date+Extensions.swift` | Datums-Hilfsfunktionen |
| `IdBackfill.swift` | Einmalige Start-Reparatur für Legacy-Datensätze ohne stabile `id` (siehe [ADR-002](adr/ADR-002-cloudkit-sync-und-stabile-ids.md)); läuft nur einmal (`idBackfillCompleted.v1`-Flag) |
| `ImageDownsampler.swift` | Thumbnail-Erzeugung aus `Photo.imageData` |
| `ThumbnailBackfill.swift` | Nachträgliches Befüllen von `thumbnailData` für Bestandsfotos |

### 5. Components

| Datei | Zweck |
|-------|-------|
| `PortPinView.swift` | Gemeinsame Hafen-Pin-Komponente für Karte und Detailansicht (Rollen-basierte Farben: Start/Hafen/Endpunkt/Seetag) |

## Datenfluss

### 1. Kreuzfahrt erstellen

```
User Input → CruiseFormView → Cruise Model → SwiftData → SQLite
                    │
                    ├── KI-Import (optional)
                    │      │
                    │      └── GeminiService → Gemini API
                    │
                    └── Port Suggestions → PortSuggestion.swift (statisch, indexiert)
```

### 2. Karten-Visualisierung

```
SwiftData Query → [Cruise] → MapView
                              │
                              ├── Filter: hasValidCoordinates
                              │
                              ├── MapPolyline (Route)
                              │
                              └── Annotations (PortPinView, rollenbasiert)
```

### 3. Export/Import

```
[Cruise] → ExportImportService.exportToZip
              │
              ├── data.json (Struktur, Bild-Pfadreferenzen)
              └── images/<cruiseId>/... (rohe Bild-Bytes)
                     │
                     └── ZipArchiveWriter.build(entries:) → Data (STORED)

ZIP-Datei → ExportImportService.importFromZip
              │
              └── ZipArchiveReader.extract (Zip-Slip- + Bomben-Schutz)
                     │
                     └── importFromJSONData (Duplikat-Check via id, Rollback bei Save-Fehler)
```

## Technologie-Stack

| Kategorie | Technologie | Version |
|-----------|-------------|---------|
| Sprache | Swift | 6.0 (`SWIFT_VERSION = 6.0`, `SWIFT_STRICT_CONCURRENCY = complete`) |
| UI | SwiftUI | — |
| Datenbank | SwiftData | — |
| Karten | MapKit | — |
| Charts | Swift Charts | — |
| KI | Gemini API | 2.5 Flash |
| Sicherheit | Keychain Services | Generic Password, `WhenUnlockedThisDeviceOnly` |
| Benachrichtigungen | UserNotifications | lokal, kein APNs |
| Zielplattform | iOS | 18.5+ (`IPHONEOS_DEPLOYMENT_TARGET = 18.5`) |

## Datei-Organisation

```
ShipTrip/
├── ShipTripApp.swift            # @main Entry Point (kein separater App/-Ordner)
├── Models/                      # SwiftData Models + statische Referenzdaten
├── Views/                       # SwiftUI Views (nach Feature)
│   ├── Cruises/
│   ├── Map/
│   ├── Deals/
│   ├── Stats/
│   └── Settings/
├── Services/                    # Business Logic (siehe Service-Tabelle oben)
├── Components/                  # Wiederverwendbare UI-Komponenten
├── Utilities/                   # Extensions & Helpers
└── Assets.xcassets/              # Bilder & App Icon
```

## Threading

Das Projekt baut mit `SWIFT_STRICT_CONCURRENCY = complete` unter Swift 6.0
(alle sechs Build-Configs: App/Tests/UITests × Debug/Release). Es wird
**kein** `@unchecked Sendable` verwendet — jede Isolation ist entweder über
`@MainActor` oder eine echte `Sendable`-Konformität ausgedrückt.

- **Main Thread / `@MainActor`**: Alle UI-Updates. `GeminiService` und
  `ExportImportService` sind explizit `@MainActor`-isoliert (`GeminiService`
  zusätzlich `@Observable`; `ExportImportService` hält `DateFormatter`-State
  und arbeitet mit `ModelContext`, der selbst nicht `Sendable` ist).
- **`NotificationService`**: `final class NotificationService: Sendable` —
  hält außer dem `shared`-Singleton keinen State und arbeitet ausschließlich
  über `UNUserNotificationCenter.current()` sowie reine Wertparameter
  (`String`, `Date`, `UUID`).
- **Background**: Gemini-API-Calls (`async/await`), Foto-Verarbeitung.
- **SwiftData ist NICHT thread-safe.** `ModelContext` ist nicht `Sendable` und
  darf nicht über Isolationsgrenzen hinweg geteilt werden. Der App-Container
  wird auf dem Main Actor erzeugt und über `.modelContainer(container)` an
  `MainTabView` gereicht; UI-Views arbeiten über `@Query`/`@Environment(\.modelContext)`
  auf dem Main Actor. Wo Daten über Aktorgrenzen müssen (z. B.
  `NotificationService`), werden ausschließlich reine, `Sendable`-Wertdaten
  (`String`, `Date`, `UUID`) übergeben — **nie** `@Model`-Objektreferenzen.

### Push vs. lokale Notifications

`NotificationService` plant ausschließlich **lokale** Notifications
(`UNUserNotificationCenter` + `UNCalendarNotificationTrigger`). Es gibt aktuell
**keine** APNs-/Push-Capability im Projekt (kein `aps-environment`-Entitlement,
kein Background-Mode „Remote notifications"). Diese Fähigkeiten sind für die
CloudKit-Aktivierung vorgesehen (siehe ADR-002, Schritt „Manuelle Xcode-Schritte")
und noch nicht umgesetzt.

## Speicher

| Datentyp | Speicherort |
|----------|-------------|
| Cruise/Port/Expense/Deal | SwiftData (lokale SQLite-DB) |
| Fotos (`Photo.imageData`, `Port.imageData`) | SwiftData mit `@Attribute(.externalStorage)` |
| Gemini-API-Key | iOS Keychain (`kSecAttrAccessibleWhenUnlockedThisDeviceOnly`) |
| Nutzereinstellungen (Erinnerungs-Flags, Farbschema) | Standard `UserDefaults` |
