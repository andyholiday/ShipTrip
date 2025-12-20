# Setup Guide

Vollständige Anleitung zur Einrichtung der ShipTrip-Entwicklungsumgebung.

## Voraussetzungen

| Komponente | Mindestversion | Empfohlen |
|------------|----------------|-----------|
| macOS | 13.0 Ventura | 14.0 Sonoma |
| Xcode | 15.0 | 15.1+ |
| iOS Simulator/Gerät | 17.0 | 17.0+ |
| Apple Developer Account | Free | Paid (für Gerät + Notifications) |

## Installation

### 1. Repository klonen

```bash
git clone https://github.com/andyholiday/ShipTrip.git
cd ShipTrip
```

### 2. Projekt öffnen

```bash
open ShipTrip.xcodeproj
```

Oder in Xcode: File → Open → ShipTrip.xcodeproj auswählen

### 3. Signing konfigurieren

1. In Xcode: ShipTrip Target auswählen
2. Tab "Signing & Capabilities"
3. Team auswählen (dein Apple Developer Account)
4. Bundle Identifier ggf. anpassen (muss eindeutig sein)

```
Original: com.andre.ShipTrip
Dein Bundle: com.DEINNAME.ShipTrip
```

### 4. Build & Run

```
⌘B  - Build
⌘R  - Run (im Simulator)
```

## Gemini API einrichten (optional)

Die KI-Import-Funktion benötigt einen Google Gemini API-Key.

### API Key erstellen

1. Gehe zu [Google AI Studio](https://aistudio.google.com/)
2. Melde dich mit deinem Google-Konto an
3. Klicke auf "Get API Key"
4. "Create API Key in new project"
5. Kopiere den Key

### In der App konfigurieren

1. App starten
2. Einstellungen → "Gemini API Key"
3. Key einfügen
4. Speichern

> **Sicherheit**: Der Key wird verschlüsselt in der iOS Keychain gespeichert.

### Testen

1. Neue Kreuzfahrt erstellen
2. "Mit KI importieren" tippen
3. Buchungsbestätigung einfügen
4. "Analysieren" tippen

## Push Notifications einrichten

### Simulator

Notifications funktionieren im Simulator mit Einschränkungen:
- Keine echten Push-Notifications
- Lokale Notifications werden angezeigt

### Echtes Gerät

1. Apple Developer Account (kostenpflichtig: 99€/Jahr)
2. In Xcode: Signing & Capabilities → "+ Capability"
3. "Push Notifications" hinzufügen
4. App auf Gerät deployen
5. Bei Berechtungsanfrage: "Erlauben"

## Projektstruktur verstehen

```
ShipTrip/
├── ShipTrip.xcodeproj    # Xcode Projektdatei
├── ShipTrip/             # Hauptquellcode
│   ├── App/              # App Entry Point
│   ├── Models/           # Datenmodelle
│   ├── Views/            # UI-Komponenten
│   ├── Services/         # Business Logic
│   ├── Components/       # Wiederverwendbare UI
│   ├── Utilities/        # Helpers
│   └── Assets.xcassets/  # Bilder
├── ShipTripTests/        # Unit Tests
├── ShipTripUITests/      # UI Tests
└── docs/                 # Dokumentation
```

## Häufige Probleme

### Build-Fehler: "No signing certificate"

**Lösung**: Signing & Capabilities → Team auswählen

### Build-Fehler: "Duplicate bundle identifier"

**Lösung**: Bundle Identifier ändern (z.B. com.DEINNAME.shiptrip)

### Simulator zeigt keine Karte

**Lösung**: 
- Location Services aktivieren: Simulator → Features → Location → Custom Location
- Oder: Apple Maps auf dem Simulator öffnen (löst Caching aus)

### Gemini API: "Invalid API Key"

**Lösung**:
1. Key in Google AI Studio prüfen
2. In App: Einstellungen → Key löschen → neu eingeben
3. Internetverbindung prüfen

### SwiftData: "Migration failed"

**Lösung** (nur Entwicklung):
1. App vom Simulator löschen
2. Neu builden & starten

## Debugging

### Logs anzeigen

```swift
print("Debug: \(variable)")
```

Oder mit Logger:
```swift
import os
let logger = Logger(subsystem: "com.andre.ShipTrip", category: "debug")
logger.info("Info message")
logger.error("Error: \(error)")
```

### SwiftData Datenbank inspizieren

1. Simulator Daten finden:
   ```bash
   open ~/Library/Developer/CoreSimulator/Devices/
   ```
2. Nach `default.store` suchen
3. Mit SQLite-Tool öffnen (z.B. DB Browser for SQLite)

### Network Requests debuggen

Xcode → Debug → Instruments → Network

## Nächste Schritte

Nach erfolgreicher Einrichtung:

1. 📖 [ARCHITECTURE.md](ARCHITECTURE.md) - Architektur verstehen
2. 📊 [MODELS.md](MODELS.md) - Datenmodelle kennenlernen
3. 🔌 [API.md](API.md) - API-Integrationen
4. 🤝 [CONTRIBUTING.md](CONTRIBUTING.md) - Zum Projekt beitragen
