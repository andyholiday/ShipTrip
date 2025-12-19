# Changelog

Alle nennenswerten Änderungen am Projekt werden hier dokumentiert.

Das Format basiert auf [Keep a Changelog](https://keepachangelog.com/de/1.1.0/),
und dieses Projekt folgt [Semantic Versioning](https://semver.org/lang/de/).

## [Unreleased]

### Geplant
- Export/Import Funktion (JSON)
- CloudKit iCloud-Sync
- Wetter-API Integration
- Hafen-Bilder mit KI-Generierung
- Auto-Import von Reederei-Angeboten

---

## [1.0.0] - 2024-12-19

### Hinzugefügt
- 🚢 **Kreuzfahrt-Management**
  - Kreuzfahrten erstellen, bearbeiten, löschen
  - Detailansicht mit allen Informationen
  - Foto-Galerie pro Reise
  - Bewertungssystem (1-5 Sterne)
  - Buchungsnummer und Kabinentyp

- 🤖 **KI-Import (Gemini 2.5 Flash)**
  - Buchungsbestätigungen per KI analysieren
  - Automatische Extraktion von Reisedaten
  - Hafen-Erkennung mit Datum/Uhrzeit
  - Seetag-Erkennung

- 🗺️ **Interaktive Weltkarte**
  - Routen-Visualisierung mit MapKit
  - Zoom zu einzelnen Routen
  - Mehrere Reisen gleichzeitig anzeigen
  - Ein-/Ausblenden von Routen

- 🌊 **Seetage**
  - Seetage in der Route erfassen
  - Automatische Filterung auf der Karte
  - Visuelle Unterscheidung zu Häfen

- 📊 **Statistiken**
  - Kreuzfahrten pro Jahr (Bar Chart)
  - Ausgaben nach Kategorie (Pie Chart)
  - Top Reedereien
  - Besuchte Länder & Häfen

- 💰 **Ausgaben-Tracking**
  - Ausgaben pro Reise erfassen
  - Kategorien (Ausflüge, Essen, Shopping, etc.)
  - Gesamtübersicht

- 🔔 **Push-Benachrichtigungen**
  - Erinnerung 1 Tag vor Reisestart
  - Berechtigung in Einstellungen

- 🛳️ **~200 Häfen weltweit**
  - Europa, Karibik, Asien, Ozeanien, Afrika
  - Autocomplete bei Hafen-Suche
  - Automatische Koordinaten-Zuordnung

- 🎨 **Design**
  - Native iOS 17 Design
  - Dark Mode Support
  - Custom App Icon

### Technisch
- SwiftUI 5.0
- SwiftData (SQLite)
- MapKit
- Swift Charts
- Keychain Services
- UserNotifications
- Gemini 2.5 Flash API

---

## Versioning

- **MAJOR**: Inkompatible API-Änderungen
- **MINOR**: Neue Features, abwärtskompatibel
- **PATCH**: Bugfixes

[Unreleased]: https://github.com/andyholiday/ShipTrip/compare/v1.0.0...HEAD
[1.0.0]: https://github.com/andyholiday/ShipTrip/releases/tag/v1.0.0
