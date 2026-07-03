# Setup Guide

Vollständige Anleitung zur Einrichtung der ShipTrip-Entwicklungsumgebung.

## Voraussetzungen

| Komponente | Mindestversion |
|------------|-----------------|
| Xcode | 26.5+ |
| iOS Simulator/Gerät | 18.5+ (`IPHONEOS_DEPLOYMENT_TARGET`) |
| Swift | 6.0 (`SWIFT_VERSION = 6.0`) |
| Apple Developer Account | Free (Simulator) / Paid (Gerät, TestFlight) |

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

> **Sicherheit**: Der Key wird in der iOS Keychain gespeichert
> (`kSecAttrAccessibleWhenUnlockedThisDeviceOnly`), geräte-gebunden und nicht
> in iCloud-/Geräte-Backups. Details: [API.md → KeychainService](API.md#keychainservice).

### Testen

1. Neue Kreuzfahrt erstellen
2. "Mit KI importieren" tippen
3. Buchungsbestätigung einfügen
4. "Analysieren" tippen

## Lokale Erinnerungen (kein Push/APNs)

`NotificationService` plant ausschließlich **lokale** Notifications
(`UNUserNotificationCenter`) vor Reisestart. Es gibt aktuell **keine**
Push-Notifications-Capability im Projekt (kein `aps-environment`-Entitlement) —
sie ist nicht nötig für lokale Erinnerungen. Echte Push-Notifications (APNs)
sind erst für die CloudKit-Aktivierung vorgesehen (siehe
[ADR-002](adr/ADR-002-cloudkit-sync-und-stabile-ids.md), Welle D2.1), noch
nicht umgesetzt.

### Simulator

Lokale Notifications funktionieren im Simulator normal (Berechtigungsdialog,
Anzeige). Kein zusätzliches Setup nötig.

### Echtes Gerät

1. App auf Gerät deployen (Free oder Paid Developer Account genügt).
2. Bei der Berechtigungsanfrage in der App: „Erlauben".

## Fastlane / TestFlight-Release

Der Release-Prozess läuft über `fastlane` (`fastlane/Fastfile`), zwei Lanes:

| Lane | Zweck |
|------|-------|
| `fastlane ios fetch_profile` | Holt das App-Store-Provisioning-Profile über die App Store Connect API |
| `fastlane ios upload_testflight` | Lädt `build/export/ShipTrip.ipa` zu TestFlight hoch |

Beide Lanes authentifizieren sich über `app_store_connect_api_key` und
benötigen folgende Umgebungsvariablen (siehe `fastlane/Fastfile`):

| Variable | Bedeutung |
|----------|-----------|
| `ASC_KEY_ID` | Key-ID des App-Store-Connect-API-Keys |
| `ASC_ISSUER_ID` | Issuer-ID des App-Store-Connect-API-Keys |
| `ASC_KEY_PATH` | Lokaler Dateipfad zur `.p8`-Key-Datei (**nicht** ins Repo einchecken) |

`team_id` (`LH324Y9MG7`) und `app_identifier` (`com.andre.ShipTrip`) sind fest
im `Fastfile` hinterlegt. `fastlane/README.md` ist auto-generiert (wird bei
jedem Fastlane-Lauf neu geschrieben) — nicht manuell editieren.

> **Sicherheit**: Der `.p8`-API-Key und alle drei Umgebungsvariablen sind
> Secrets. Niemals Key-Inhalte oder reale Werte in Doku, Commits oder Issues
> einfügen.

## Projektstruktur verstehen

```
ShipTrip/
├── ShipTrip.xcodeproj    # Xcode Projektdatei
├── ShipTrip/             # Hauptquellcode
│   ├── ShipTripApp.swift # App Entry Point (kein separater App/-Ordner)
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
