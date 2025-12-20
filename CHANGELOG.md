# Changelog

Alle nennenswerten Änderungen am Projekt werden hier dokumentiert.

Das Format basiert auf [Keep a Changelog](https://keepachangelog.com/de/1.1.0/),
und dieses Projekt folgt [Semantic Versioning](https://semver.org/lang/de/).

## [Unreleased]

### Geplant
- CloudKit iCloud-Sync
- Wetter-API Integration
- Hafen-Bilder mit KI-Generierung

---

## [1.0.2] - 2024-12-20

### Hinzugefügt
- 🗺️ **Hafendatenbank massiv erweitert**
  - Von ~290 auf ~1.800 Häfen (Wikidata Import)
  - Karibik, Norwegen, VAE/Oman, Asien komplett abgedeckt
  - Beliebte Kreuzfahrt-Häfen mit gängigen Namen
  - Aliase für verschiedene Schreibweisen (z.B. "Willemstad (Curacao)")

- 🎨 **UI-Verbesserungen**
  - Route-Symbole: 📍 Mappin für Häfen, 🌊 Wellen für Seetage
  - Land wird bei Seetagen ausgeblendet

### Behoben
- 🔧 Compiler-Fehler in Color+Theme.swift
- 🔧 "Seetage" → "Reisetage" in Statistik (war irreführend)
- 🔧 Länder-Zählung zählt keine leeren Strings mehr
- 🔧 Route in Cards wird jetzt sortiert angezeigt
- 🔧 Version wird dynamisch aus Bundle gelesen
- 🔧 iCloud zeigt "Geplant" statt fälschlich "Aktiv"
- 🔧 macOS-Kompatibilität (ToolbarItem Placement)
- 🔧 Deprecated `autocapitalization` API ersetzt

---

## [1.0.1] - 2024-12-19

### Hinzugefügt
- 📦 **Export/Import Funktion**
  - Export als JSON mit Base64-Fotos
  - Import von ZIP (Web-App kompatibel) und JSON
  - Duplikat-Erkennung beim Import
  - Native ZIP-Parsing ohne externe Dependencies

- 📜 **App Store Vorbereitung**
  - Privacy Policy (DE/EN) auf GitHub Pages
  - App Store Beschreibung und Keywords
  - Apple Developer Account & Zertifikate
  - TestFlight Build hochgeladen

### Geändert
- Bundle ID: `com.andre.ShipTrip`

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
