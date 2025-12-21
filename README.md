# ShipTrip 🚢

Eine iOS-App zum Verwalten und Dokumentieren von Kreuzfahrt-Reisen.

![Swift](https://img.shields.io/badge/Swift-5.9-orange)
![iOS](https://img.shields.io/badge/iOS-17.0+-blue)
![SwiftUI](https://img.shields.io/badge/SwiftUI-5.0-green)
![SwiftData](https://img.shields.io/badge/SwiftData-1.0-purple)
![Version](https://img.shields.io/badge/Version-1.0.3-brightgreen)

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

### 🛳️ **~1.800 Häfen weltweit**
- 🌍 Europa, Karibik, Asien, Ozeanien, Afrika, VAE/Oman
- Autocomplete bei der Hafen-Suche
- Automatische Koordinaten-Zuordnung

### Statistiken
- 📊 Kreuzfahrten pro Jahr
- 💰 Ausgaben nach Kategorie
- 🏆 Top Reedereien
- Besuchte Länder & Häfen

### Weitere Features
- 💸 Ausgaben-Tracking
- 🔔 Push-Benachrichtigungen vor Reisestart
- 🎨 Dark Mode Support
- 📱 Native iOS 17 Design

## 🛠️ Technologie-Stack

| Komponente | Technologie |
|------------|-------------|
| UI Framework | SwiftUI 5.0 |
| Datenbank | SwiftData |
| Karten | MapKit |
| Charts | Swift Charts |
| AI | Google Gemini 2.5 Flash |
| Sicherheit | Keychain Services |
| Notifications | UserNotifications |

## 📁 Projektstruktur

```
ShipTrip/
├── App/
│   └── ShipTripApp.swift          # App Entry Point
├── Models/
│   ├── Cruise.swift               # Kreuzfahrt-Model
│   ├── Port.swift                 # Hafen-Model
│   ├── Expense.swift              # Ausgaben-Model
│   ├── Deal.swift                 # Angebote-Model
│   ├── Photo.swift                # Foto-Model
│   ├── ShippingLine.swift         # Reederei-Daten
│   └── PortSuggestion.swift       # ~1.800 Hafen-Datenbank
├── Views/
│   ├── Cruises/
│   │   ├── CruiseListView.swift   # Übersicht
│   │   ├── CruiseDetailView.swift # Details
│   │   └── CruiseFormView.swift   # Erstellen/Bearbeiten
│   ├── Map/
│   │   └── MapView.swift          # Weltkarte mit Routen
│   ├── Deals/
│   │   └── DealsView.swift        # Angebote
│   ├── Stats/
│   │   └── StatsView.swift        # Statistiken
│   └── Settings/
│       └── SettingsView.swift     # Einstellungen
├── Services/
│   ├── GeminiService.swift        # AI Integration
│   ├── KeychainService.swift      # Sichere Speicherung
│   └── NotificationService.swift  # Push-Benachrichtigungen
└── Assets.xcassets/               # App Icon & Assets
```

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
- Xcode 15.0+
- iOS 17.0+ Simulator oder Gerät
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

### v1.0 ✅
- [x] Kreuzfahrten verwalten
- [x] Karten-Integration
- [x] KI-Import
- [x] Statistiken
- [x] ~1.800 Häfen (Wikidata Import)

### v2.0 (geplant)
- [ ] Export/Import (JSON)
- [ ] CloudKit Sync
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
