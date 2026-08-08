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

## iCloud-/CloudKit-Setup

Build 21 erwartet für `com.andre.ShipTrip`:

- iCloud-Capability mit CloudKit-Container `iCloud.com.andre.ShipTrip`
- Push-Notifications-Capability und Background Mode `remote-notification` für
  entfernte CloudKit-Store-Änderungen
- ein Provisioning Profile, das diese Entitlements enthält

Das Schema-Artefakt unter `docs/cloudkit/ShipTrip.ckdb` entspricht der installierten
**Development**-Umgebung. Die Promotion nach **Production** wurde am 08.08.2026
in der CloudKit Console ausgeführt. Der anschließende maschinenlesbare Export liegt
unter `docs/cloudkit/ShipTrip-production.ckdb` und entspricht semantisch dem
Development-Schema.
Ein Geräte-Smoke benötigt ein entsperrtes, bei iCloud angemeldetes Gerät. Unit-
Tests benötigen keinen iCloud-Account, weil `ShipTripCloudSync` CloudKit unter
XCTest deaktiviert.

## Optionalen Kalender-Sync testen

1. App öffnen: Mehr → Kalender.
2. „Reisen mit Kalender synchronisieren“ aktivieren und vollständigen Zugriff
   erlauben.
3. Einen beschreibbaren Zielkalender und „Nur Reisen“ oder
   „Reisen, Häfen & Seetage“ wählen.
4. Eine Nicht-Demo-Reise anlegen bzw. ändern und den Termin in Kalender prüfen.
5. Sync deaktivieren und prüfen, dass die von ShipTrip verwalteten Termine
   entfernt werden.

### Kalender-Grant für die Migrationstests

`ShipTripTests/CalendarSyncServiceMigrationTests.swift` arbeitet gegen einen
echten EventStore und benötigt deshalb einen Kalender-Grant auf dem Simulator:

```bash
xcrun simctl privacy <udid> grant calendar com.andre.ShipTrip
```

Ohne den Grant schlagen genau diese vier Tests hart fehl (Exit-Code 65); es gibt
keinen stillen Skip.

## Lokale Erinnerungen (keine Nutzer-Push-Nachrichten)

`NotificationService` plant ausschließlich **lokale** Notifications
(`UNUserNotificationCenter`) vor Reisestart. Das APNs-Entitlement von Build 21
gehört zur CloudKit-Spiegelung; ShipTrip versendet weiterhin keine eigenen
Nutzer-Push-Nachrichten.

### Simulator

Lokale Notifications funktionieren im Simulator normal (Berechtigungsdialog,
Anzeige). Kein zusätzliches Setup nötig.

### Echtes Gerät

1. App auf Gerät deployen (Free oder Paid Developer Account genügt).
2. Bei der Berechtigungsanfrage in der App: „Erlauben".

## Fastlane / TestFlight-Release

Der Release-Prozess läuft über `fastlane` (`fastlane/Fastfile`), drei Lanes:

| Lane | Zweck |
|------|-------|
| `fastlane ios validate` | Prüft API-Key und liest die neueste TestFlight-Buildnummer |
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

Für künftige CloudKit-Schemaänderungen gilt zusätzlich: Schema in Development
validieren, über die CloudKit Console nach Production promoten und den
Production-Export vergleichen.
Ein echter Geräte-Smoke bleibt der stärkste End-to-End-Nachweis; ist kein Gerät
verfügbar, muss diese Einschränkung im Release-Status ausdrücklich stehen.

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
