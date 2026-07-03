# ShipTrip 🚢

Eine iOS-App zum Verwalten und Dokumentieren von Kreuzfahrt-Reisen.

![Swift](https://img.shields.io/badge/Swift-6.0-orange)
![iOS](https://img.shields.io/badge/iOS-18.5+-blue)
![SwiftUI](https://img.shields.io/badge/SwiftUI-native-green)
![SwiftData](https://img.shields.io/badge/SwiftData-native-purple)
![Version](https://img.shields.io/badge/Version-1.5.1-brightgreen)

📋 **[Changelog](CHANGELOG.md)** | 📖 **[Dokumentation](docs/)**

## ✨ Features

### Kreuzfahrten verwalten
- 📋 Kreuzfahrten mit allen Details erfassen (Schiff, Reederei, Kabine, Buchungsnummer)
- 🗺️ Interaktive Karte mit Routen-Visualisierung
- 📸 Fotos zu jeder Reise hinzufügen
- ⭐ Bewertungssystem
- 🌊 Seetage erfassen

### KI-gestützter Import
- 🤖 **Gemini 2.5 Flash Integration** - Buchungsbestätigungen per KI analysieren
- Automatische Extraktion von:
  - Reisedaten (Titel, Datum, Schiff, Reederei)
  - Häfen mit Ankunfts-/Abfahrtszeiten
  - Seetage

### 🛳️ **~1.900 Häfen weltweit**
- 🌍 Europa, Karibik, Asien, Ozeanien, Afrika, VAE/Oman
- Autocomplete bei der Hafen-Suche
- Automatische Koordinaten-Zuordnung

### Statistiken
- 📊 Kreuzfahrten pro Jahr
- 💰 Ausgaben nach Kategorie
- 🏆 Top Reedereien
- Besuchte Länder & Häfen

### Weitere Features
- 💸 Ausgaben-Tracking (Geräte-Locale-Währung, kein hartkodiertes EUR)
- 💾 Export/Import als ZIP (verlustfrei, inkl. Reise- und Hafenbilder)
- 🔔 Lokale Erinnerungen vor Reisestart (keine Push-Notifications/APNs)
- 🎨 Dark Mode Support
- 📱 Natives iOS-Design

## 🛠️ Technologie-Stack

| Komponente | Technologie |
|------------|-------------|
| Sprache | Swift 6 |
| UI Framework | SwiftUI |
| Datenbank | SwiftData |
| Karten | MapKit |
| Charts | Swift Charts |
| AI | Google Gemini 2.5 Flash |
| Sicherheit | Keychain Services (Generic Password, geräte-gebunden) |
| Notifications | UserNotifications (lokal) |

## 📁 Projektstruktur

```
ShipTrip/
├── ShipTripApp.swift              # App Entry Point (kein separater App/-Ordner)
├── Models/
│   ├── Cruise.swift                # Kreuzfahrt-Model
│   ├── Port.swift                  # Hafen-Model
│   ├── Expense.swift               # Ausgaben-Model
│   ├── Deal.swift                  # Angebote-Model
│   ├── Photo.swift                 # Foto-Model
│   ├── ShippingLine.swift          # Reederei-Daten
│   └── PortSuggestion.swift        # ~1.900 Hafen-Datenbank (Wikidata-Import)
├── Views/
│   ├── Cruises/                    # Liste, Detail, Formulare, Hero-Card, Timeline
│   ├── Map/                        # MapView.swift — Weltkarte mit Routen
│   ├── Deals/                      # DealsView.swift — Wunschreisen
│   ├── Stats/                      # StatsView.swift — Statistiken
│   └── Settings/                   # SettingsView.swift — Einstellungen, Export/Import
├── Services/
│   ├── GeminiService.swift         # KI-Integration
│   ├── KeychainService.swift       # Sichere Speicherung des API-Keys
│   ├── NotificationService.swift   # Lokale Erinnerungen (kein APNs)
│   ├── ExportImportService.swift   # ZIP-/JSON-Export/-Import
│   ├── ZipArchiveWriter.swift      # ZIP-Erstellung (STORED)
│   ├── ZipArchiveReader.swift      # ZIP-Extraktion (Zip-Slip-/Bomben-Schutz)
│   └── CRC32.swift                 # CRC-32 für den ZIP-Stack
└── Assets.xcassets/                # App Icon & Assets
```

Vollständige Architektur- und API-Doku: [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md), [docs/API.md](docs/API.md).

## 📚 Dokumentation

| Dokument | Beschreibung |
|----------|--------------|
| [Setup Guide](docs/SETUP.md) | Installation & Einrichtung |
| [Architektur](docs/ARCHITECTURE.md) | Technische Architektur |
| [Datenmodelle](docs/MODELS.md) | SwiftData Models |
| [API Integration](docs/API.md) | Gemini, Keychain, Notifications |
| [Contributing](docs/CONTRIBUTING.md) | Beitragsrichtlinien |
| [Changelog](CHANGELOG.md) | Versionshistorie |

## 🚀 Installation

### Voraussetzungen
- Xcode 26.5+
- iOS 18.5+ Simulator oder Gerät
- Apple Developer Account (für Gerät-Tests)

### Schritte

1. **Repository klonen**
   ```bash
   git clone https://github.com/DEIN-USERNAME/ShipTrip.git
   cd ShipTrip
   ```

2. **Projekt öffnen**
   ```bash
   open ShipTrip.xcodeproj
   ```

3. **Gemini API Key einrichten** (optional, für KI-Features)
   - [Google AI Studio](https://aistudio.google.com/) öffnen
   - API Key erstellen
   - In der App unter Einstellungen → API Key eingeben

4. **Bauen & Starten**
   - `⌘B` zum Bauen
   - `⌘R` zum Starten

## 📸 Screenshots

*Kommt bald*

## 🔮 Roadmap

### Umgesetzt ✅
- [x] Kreuzfahrten verwalten
- [x] Karten-Integration
- [x] KI-Import
- [x] Statistiken
- [x] ~1.900 Häfen (Wikidata Import)
- [x] Export/Import als ZIP (verlustfrei, inkl. Bilder)

### Geplant
- [ ] CloudKit Sync (Datenmodell teilweise vorbereitet, aber noch nicht
      konform/aktiv — siehe [ADR-002](docs/adr/ADR-002-cloudkit-sync-und-stabile-ids.md))
- [ ] Hafen-Bilder + KI-Generierung
- [ ] Wetter-API Integration
- [ ] Auto-Import von Reederei-Angeboten

## 🤝 Contributing

Contributions sind willkommen! Bitte erst ein Issue erstellen, bevor du einen PR einreichst.

## 📄 Lizenz

MIT License - siehe [LICENSE](LICENSE) für Details.

## 👨‍💻 Autor

Entwickelt mit ❤️ und 🤖 AI-Unterstützung.

---

**Made for cruise lovers** 🚢
