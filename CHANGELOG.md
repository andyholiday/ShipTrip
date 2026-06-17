# Changelog

Alle nennenswerten Änderungen am Projekt werden hier dokumentiert.

Das Format basiert auf [Keep a Changelog](https://keepachangelog.com/de/1.1.0/),
und dieses Projekt folgt [Semantic Versioning](https://semver.org/lang/de/).

## [Unreleased]

### Geplant

- iCloud-Backup/Sync via CloudKit (Datenmodell bereits vorbereitet; Aktivierung
  in separatem Build nach manuellem Xcode-Capability-Setup und Smoke-Test — siehe
  [ADR-002](docs/adr/ADR-002-cloudkit-sync-und-stabile-ids.md))
- Wetter-API Integration
- Hafen-Bilder mit KI-Generierung

### Hinzugefuegt

- **Hybrid-Hauptansicht „Meine Reisen"**: Die flache Liste gleichfoermiger
  Full-Bleed-Karten wurde durch ein dreischichtiges Layout ersetzt:
  ein schlanker Statistik-Strip (lifetime-Totals: Reisen, Laender, Seetage,
  Haefen), eine redaktionelle Hero-Card fuer die Fokus-Reise, und kompakte
  Timeline-Zeilen gruppiert nach Jahrestrennern.
  ([Feature-Doku](docs/features/hauptansicht-hybrid.md))
- **Hero-Card mit Cover-Foto und Geo-SVG-Fallback**: Die Hero-Card zeigt das
  erste Reisefoto als Hintergrundbild mit Scrim-Overlay. Ohne Foto rendert
  `CruiseGeoFallbackView` eine Routenlinie aus Port-Koordinaten auf Ozeanblau-
  Verlauf — kein Placeholder-Icon.
- **Fokus-Reise-Priorisierung**: `heroCruise` waehlt laufende Reise
  (`isOngoing`) > naechste bevorstehende > zuletzt vergangene.
- **Lifetime-Aggregatwerte**: Neue Array-Extension auf `Cruise` liefert
  `uniqueCountryCount`, `totalSeaDays` und `totalPortStops` fuer den Stats-Strip.
- **Neue Unit-Tests (52 gesamt)**: `CruiseAggregateTests` und
  `HeroSelectionTests` testen alle drei Aggregat-Properties und die Hero-
  Auswahl-Prioritaet; `DemoDataServiceTests` sichert Demo-Seeding-Idempotenz.
- **Screenshot-Tests**: `HauptansichtScreenshotTests` verifizieren Photo-Hero-
  und Geo-Fallback-Branch in Light und Dark Mode.

### Geaendert

- **Einheitlicher Hafen-Pin**: Gemeinsame `PortPinView`-Komponente fuer alle
  Hafen-Kontexte (Karte, Detailansicht); Pin-Farben als semantische Token in
  `Color+Theme` (`portPin`, `homePortPin`, `seaDayPin`). Ersetzt verstreute,
  hartkodierte Icon-/Farb-Duplikate.
- **Schiffslisten aktualisiert (Stand Juni 2026)**: Neue Schiffe ergaenzt (u.a.
  Mein Schiff Relax/Flow, AIDAstella, Disney Treasure/Destiny/Adventure).
  Ausgeschiedene Schiffe (Mein Schiff Herz, AIDAcara/vita/aura, Costa Firenze)
  wandern in eine `historicalShips`-Liste: nicht mehr in der Auswahl fuer neue
  Reisen, fuer Bestandsreisen aber weiterhin korrekt aufgeloest (Reederei-Logo).
- **Foto-zentrierte Reise-Karten**: `CruiseCardView` zeigt das erste Reisefoto
  als vollflaechi­ges Cover (210 pt) mit Text-Overlay und Scrim. Ohne Foto:
  Verlauf oceanBlue → navy mit Ferry-Symbol.
- **Hero-Header im Reise-Detail**: `CruiseDetailView` erhaelt einen grossen
  Hero-Header (280 pt Foto-Pager / 220 pt Verlauf-Fallback) und eine
  Eckdaten-Zeile mit Reisetagen, Hafen, Laendern und Gesamtausgaben.
- **Hero-Datumsformat geraetebasiert**: `.formatted(date: .abbreviated, time: .omitted)`
  ersetzt den statischen `DateFormatter("dd.MM.yy")`.
- **Lokalisierung Hero-Card und Timeline**: Vier neue String-Catalog-Schluessel
  (`"In %lld Tagen"`, `"%lldT"`, `"Details →"`, `"Keine Treffer"`) mit DE/EN-
  Uebersetzung; Countdown-Badge nutzt einen einzigen interpolierten Schuessel.
- **Filter-Leer-Zustand**: `ContentUnavailableView.search` ersetzt den leeren
  Bildschirm, wenn ein Suchfilter keine Treffer liefert.

### Entfernt

- **`CruiseCardView` entfernt**: Die 139-Zeilen-Komponente war seit dem
  Hybrid-Redesign in der Produktion nicht mehr referenziert. Der genutzte
  Helfer `RatingBadge` wurde zuvor in eine eigene Datei
  `ShipTrip/Views/Cruises/RatingBadge.swift` ausgelagert, die weiterhin von
  `CruiseHeroCardView` verwendet wird.

### Behoben

- **Statistik-Tab „Reisetage" zeigte faelschlich Seetage-Anzahl**: Die Kachel
  summierte `totalSeaDays` (Ports mit `isSeaDay == true`), was haeufig 0
  ergab. Sie nutzt jetzt das neue Array-Aggregat `[Cruise].totalTravelDays`
  (Summe der `duration`-Werte) und zeigt damit die echte Gesamt-Reisedauer
  ueber alle Kreuzfahrten.
- **Doppelte Anzeige von Reisen nach Update auf 1.5.0**: SwiftDatas
  Lightweight-Migration vergab allen Altdatensaetzen denselben `id`-Default-Wert.
  Einmalige Start-Reparatur `IdBackfill` weist kollidierenden Datensaetzen
  neue eindeutige UUIDs zu (idempotent, ohne Datenverlust).
  ([ADR-002](docs/adr/ADR-002-cloudkit-sync-und-stabile-ids.md))
- **Hero-Card zeigte Cover-Foto nicht nach Stale Demo-Daten**: Der
  Idempotenz-Guard in `loadDemoData` verhinderte das erneute Seeden bei
  aelteren Demo-Datensaetzen ohne Foto. `HauptansichtScreenshotTests` setzt
  nun vor jedem Lauf Demo-Daten zurueck und laed frisch nach.
- **Flaky UI-Tests**: `Thread.sleep(forTimeInterval:)` in
  `HauptansichtScreenshotTests` durch `waitForExistence(timeout:)` ersetzt.

---

## [1.5.0] - 2026-06-15

### Hinzugefuegt

- **Demo-Modus** (nur Debug-Build): Beispiel-Kreuzfahrten und -Angebote koennen
  ueber die Einstellungen geladen und sauber entfernt werden
  (`DemoDataService`, `isDemo`-Tag auf Cruise und Deal).
- **Test-Grundgeruest**: 27 Unit-Tests (Swift Testing) fuer Cruise, Deal, Expense,
  PortSuggestion, Export/Import-Roundtrip und Notification-Praefix-Logik;
  3 UI-Tests — als Sicherheitsnetz fuer alle weiteren Phasen.
- **ZIP-Export** (`ExportImportService`): Neue Export-Option erzeugt ein
  ZIP-Archiv mit `data.json` und externalen Bilddateien unter `images/`; Fotos
  werden als Rohbytes ohne Re-Encoding gespeichert (verlustfrei). Stabile IDs
  (`cruise.id`, `port.id`, `expense.id`) werden im Export mitgefuehrt und beim
  Import unveraendert uebernommen.
  ([ADR-002](docs/adr/ADR-002-cloudkit-sync-und-stabile-ids.md))
- **Foto-Thumbnails**: `ImageDownsampler` (ImageIO, max. 600 px) erzeugt
  Vorschaubilder fuer Listenansichten; einmaliger Launch-Backfill (`ThumbnailBackfill`)
  befuellt bestehende Fotos ohne Thumbnails im Hintergrund.
- **Zweisprachigkeit DE/EN**: String Catalog (`Localizable.xcstrings`) mit 177
  uebersetzten Strings; Entwicklungssprache ist Deutsch.

### Geaendert

- **Stabile Modell-IDs und CloudKit-ready-Schema**: Alle persistenten Modelle
  (`Cruise`, `Deal`, `Expense`, `Photo`, `Port`) erhalten `var id: UUID = UUID()`,
  explizite `inverse:`-Beziehungen, Default-Werte auf allen Attributen und
  `updatedAt: Date` fuer Last-Writer-Wins. CloudKit-Sync ist bewusst **nicht**
  aktiviert (kein `cloudKitDatabase` in `ModelConfiguration`, keine iCloud-Entitlements);
  die Aktivierung folgt als separater Build.
  ([ADR-002](docs/adr/ADR-002-cloudkit-sync-und-stabile-ids.md))
- **Waehrung geraetebasiert**: `Expense.formattedAmount` nutzt
  `Locale.current.currency` statt hartem `"EUR"`.
- **Tab umbenannt**: „Angebote" heisst jetzt „Merkliste" (ehrlichere Benennung;
  `MainTabView`, `DealsView`).
- **SwiftData-Reaktivitaet**: `refreshID = UUID()`-Redraw-Hack in
  `CruiseDetailView` entfernt; Property ist jetzt `@Bindable var cruise: Cruise`.
- **Stabiles Store-Laden**: `ShipTripApp` versucht beim Start den persistenten
  Store; schlaegt dieser fehl, wird auf einen In-Memory-Store ausgewichen und der
  Nutzer erhaelt einen Alert. Schlaegt auch der Fallback fehl, zeigt eine
  `ContentUnavailableView` (`StoreUnavailableView`) einen klaren Fehlerhinweis —
  kein `fatalError` mehr.
- Debug-Logs entfernt: 3 `print("DEBUG: …")`-Aufrufe aus `GeminiService` (x2)
  und `CruiseFormView` (x1) entfernt — diese loggten im Release-Build sensible
  Daten.
- Tote `DeveloperSettingsView` und das 5-Tap-Easter-Egg aus den Einstellungen
  entfernt.

### Behoben

- **Benachrichtigungen**: Erinnerungen werden jetzt tatsaechlich geplant und
  entfernt. `NotificationService` uebergibt nur noch Werttypen (keine
  `@Model`-Objekte ueber Aktorgrenzen); respektiert Einstellungen
  `notifyBeforeCruise`, `notifyOnCruiseDay` und `reminderDaysBefore`.
  Aufruf beim Speichern, Bearbeiten und Loeschen einer Reise.
- **Stiller Import-Datenverlust**: `ExportImportService` liefert jetzt
  `ImportResult` mit Zaehlung importierter, doppelter und ungueltig
  uebersprungener Eintraege; der Nutzer sieht nach dem Import einen
  informativen Alert.
- **Enddatum-Validierung**: `saveCruise` erzwingt `endDate >= startDate` und
  zeigt bei Verstoss einen Alert (deckt auch den KI-Import-Pfad ab).
- **GitHub-Link in Einstellungen**: Korrigiert auf
  `https://github.com/andyholiday/ShipTrip`.
- **ZIP-Overflow**: Expliziter Fehler bei mehr als 65.535 ZIP-Eintraegen oder
  einzelnen Eintraegen ueber UInt32-Grenze (kein stilles Truncaten).
- **Legacy-Import rueckwaertskompatibel**: Alter Base64-JSON-Import wird weiterhin
  erkannt und korrekt verarbeitet; fehlende Bilddateien in ZIP-Importen werden
  toleriert (Photo wird uebersprungen, Cruise bleibt erhalten).

---

## [1.4.1] - 2024-12-23

### Neu
- 🏷️ **Coming Soon Badge**: Zukünftige Reisen werden mit "Coming Soon" markiert
- 🚪 **Kabinennummer**: Neues Feld für die Kabinennummer (Issue #4)
- 🚢 **Schiff-Auswahl**: Dropdown mit Schiffen der gewählten Reederei (Issue #5)
- 📤 **Export/Import**: Kabinennummer wird mit exportiert/importiert
- 🤖 **KI-Erfassung**: Kabinennummer wird automatisch erkannt

### Behoben
- 🐛 SwiftData Migration für neue Felder

---

## [1.0.4] - 2024-12-23

### Behoben
- 🐛 **Dark Mode**: App startete immer im Light Mode, obwohl Dark Mode gewählt (Issue #12)
- 🐛 **Export/Import**: Hafenzeiten wurden nicht korrekt übertragen (Issue #11)
- 🐛 **Karten-Standort**: Location-Button funktioniert jetzt korrekt (Issue #10)
- 🐛 **Reederei-Erkennung**: KI erkennt jetzt Reederei aus Schiffsnamen (Issue #6)

### Verbessert
- 📍 **Routen-Anzeige**: Komplette Liegezeiten (Ankunft – Abfahrt) in Detailansicht
- 🚢 **100+ Schiffe** zu Reederei-Datenbank hinzugefügt für bessere Auto-Detection

---

## [1.0.3] - 2024-12-21

### Hinzugefügt
- 🗺️ **~120 neue Häfen hinzugefügt**
  - **Kanarische Inseln komplett**: Alle Inseln mit allen Namensvarianten (Santa Cruz, Arrecife, Puerto del Rosario, San Sebastián de La Gomera, etc.)
  - **Türkei**: Bodrum, Istanbul, Kusadasi, Izmir, Antalya, Marmaris, etc.
  - **Marokko**: Agadir, Casablanca, Tanger, Essaouira
  - **Deutschland**: Bremerhaven, Hamburg, Kiel, Warnemünde
  - **Portugal**: Lissabon, Porto, Leixões
  - **Spanien**: Cádiz, A Coruña, Vigo, Bilbao, Málaga, Valencia, etc.
  - **Frankreich**: Le Havre, Cannes, Nizza, Ajaccio, Bastia
  - **Italien**: Genua, Livorno, Bari, Triest, Palermo, Messina, etc.
  - **Nordeuropa**: Southampton, Amsterdam, Kopenhagen, Oslo, Stockholm

### Behoben
- 🐛 **Kritischer Bug**: Häfen wurden auf Karte nicht angezeigt (Issue #1)
- 🐛 **Kritischer Bug**: Häfen wurden an falschen Orten angezeigt (Issue #2)
- 🔧 **Verbessertes Port-Matching**:
  - Klammer-Hinweise werden jetzt verwendet (z.B. "San Sebastián (La Gomera)" findet korrekten Hafen)
  - Akzent-Normalisierung (z.B. "Argostóli" findet "Argostoli")
  - Vollständige Matches haben höchste Priorität
  - Länder-Prüfung verbessert

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

[Unreleased]: https://github.com/andyholiday/ShipTrip/compare/v1.5.0...HEAD
[1.5.0]: https://github.com/andyholiday/ShipTrip/compare/v1.4.1...v1.5.0
[1.4.1]: https://github.com/andyholiday/ShipTrip/compare/v1.0.4...v1.4.1
[1.0.0]: https://github.com/andyholiday/ShipTrip/releases/tag/v1.0.0
