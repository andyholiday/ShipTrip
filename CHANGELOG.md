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

- **Hafenbilder im ZIP-Export**: `ExportImportService` schreibt Hafenbilder
  jetzt unter `images/<cruiseId>/ports/<index>` und setzt `imageUrl`; Roundtrip
  ist damit verlustfrei (Import las Hafenbilder bereits zuvor korrekt ein).
  ([Feature-Doku](docs/features/datenintegritaet-a1.md))
- **Bestätigungsdialog fuer API-Key-Loeschung**: „Alle Daten löschen" fragt
  jetzt explizit, ob der Gemini-API-Key mitgelöscht werden soll, statt ihn
  stillschweigend zu behalten oder zu entfernen.
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
- **Neue Unit-Tests (84 gesamt)**: `CruiseAggregateTests` und
  `HeroSelectionTests` testen alle drei Aggregat-Properties und die Hero-
  Auswahl-Prioritaet; `DemoDataServiceTests` sichert Demo-Seeding-Idempotenz.
- **Screenshot-Tests**: `HauptansichtScreenshotTests` verifizieren Photo-Hero-
  und Geo-Fallback-Branch in Light und Dark Mode.

### Geaendert

- **Zeitstrahl-Zeilen gerahmt**: `CruiseTimelineRowView` erhaelt ein
  Card-Treatment (`secondarySystemBackground`, cornerRadius 10), passend zum
  Statistik-Strip und zur Hero-Card. `CruiseListView` reduziert den vertikalen
  `listRowInsets`-Abstand von 6 auf 4 Pt fuer kompaktere Optik.
- **Differenzierte Hafen-Nadeln nach Rolle** in drei Kontexten:
  - Detail-Route-Liste (`PortPinView`): neuer Typ `endPort` (Token
    `endPortPin = seaGreen`, Icon `mappin.and.ellipse.circle.fill`); Start =
    Heimathafen (orange), Hafen (blau), Endpunkt (gruen), Seetag (Wellen).
    Factory `PortPinType.init(isSeaDay:isFirst:isLast:)`.
  - Geo-Route in der Hero-Card (`CruiseGeoFallbackView`): Start (orange) und
    Endpunkt (gruen) als groessere Punkte mit weissem Ring; Zwischenstopps als
    kleine weisse Punkte.
  - Weltkarte (`MapView`): Start = Pin, Zwischenhaefen = kleine Punkte,
    Endpunkt = Zielflagge (`flag.checkered.circle.fill`) — Farbe bleibt pro
    Reise unveraendert.
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
- **Erinnerungs-Anfrage kontextuell**: Die Benachrichtigungs-Berechtigung wird
  beim Speichern zukuenftiger Reisen jetzt zustandsabhaengig angefragt: bei
  bereits erteilter (auch `provisional`/`ephemeral`) Berechtigung wird direkt
  geplant, bei `notDetermined` zeigt ein Begruendungs-Sheet den Zweck vor dem
  System-Prompt, bei `denied` erscheint einmalig ein Hinweis mit
  Einstellungen-Link statt eines wirkungslosen erneuten Anfrageversuchs.
  ([Feature-Doku](docs/features/ux-fixes-a2.md))
- **Barrierefreiheit Hauptansicht**: Die Hero-Card ist jetzt ein echter Button
  mit beschreibendem `accessibilityLabel`; Stats-Strip und Hero-Card nutzen
  `@ScaledMetric` und `minimumScaleFactor` fuer Dynamic Type.
  ([Feature-Doku](docs/features/ux-fixes-a2.md))
- **Einzel-Loeschen fuer Haefen/Ausgaben**: Ein `contextMenu` pro Zeile in der
  Reise-Detailansicht erlaubt das direkte Loeschen einzelner Haefen und
  Ausgaben, ohne die gesamte Reise zu bearbeiten.
  ([Feature-Doku](docs/features/ux-fixes-a2.md))
- **Karte ohne Standort-Berechtigung**: `MapView` benoetigt keine
  Standortdaten des Nutzers mehr; `CLLocationManager` und die zugehoerigen
  Berechtigungsschluessel wurden entfernt. Ein Empty-State-Overlay erscheint,
  wenn keine kartierbaren Haefen vorhanden sind.
  ([Feature-Doku](docs/features/ux-fixes-a2.md))
- **Ausgaben-Eingabe locale-basiert**: Die Betrag-Eingabe nutzt jetzt
  `.currency`-Formatierung nach Geraete-Locale (neutrales Zahlenformat ohne
  Waehrung, falls die Locale keine besitzt); die Anzeige sortiert Ausgaben
  chronologisch, undatierte Eintraege zuletzt.
  ([Feature-Doku](docs/features/ux-fixes-a2.md))
- **Fluessigere Foto-Galerie**: Ein Pager auf Thumbnail-Basis mit asynchronem
  Decoding (Lade-/Fehler-Platzhalter) sowie eine Zoom-Vollbildansicht
  (`PhotoZoomView`) mit Full-Res-Nachladen.
  ([Feature-Doku](docs/features/ux-fixes-a2.md))
- **Einheitliche Corner-Radien (`DesignRadius`)**: Drei Radius-Stufen (sm 10 /
  md 16 / lg 28) ersetzen verstreute Magic Numbers ueber zehn View-Dateien;
  vormals 22er/24er-Radien wandern bewusst auf `lg = 28`. Ungenutztes
  `cardStyle()`-Modifier entfernt.
  ([Feature-Doku](docs/features/code-politur-a3.md))
- **Einheitliche Haefen-Zaehlung**: `CruiseDetailView` und `StatsView` zaehlen
  Haefen jetzt konsistent ohne Seetage.
  ([Feature-Doku](docs/features/code-politur-a3.md))
- **Schnellere Hafen-Suche**: `PortSuggestion` nutzt einen vorberechneten
  Suchindex statt bis zu vier Linearscans pro Tastenanschlag; Trefferprioritaet
  unveraendert.
  ([Feature-Doku](docs/features/code-politur-a3.md))
- **`IdBackfill` laeuft nur noch einmal**: Ein UserDefaults-Flag
  (`idBackfillCompleted.v1`) verhindert den bisher bei jedem App-Start
  wiederholten Reparaturlauf; das Flag wird nur bei vollstaendigem Erfolg auf
  dem echten persistenten Store gesetzt.
  ([Feature-Doku](docs/features/code-politur-a3.md))
- **Export-Temp-Dateien mit UUID-Namen**: Werden nach Abschluss des
  Share-Vorgangs zuverlaessig geloescht, auch bei Abbruch.
  ([Feature-Doku](docs/features/code-politur-a3.md))
- **Strukturiertes Logging statt `print`**: `NotificationService` nutzt jetzt
  `os.Logger`; Nutzerinhalte sind als `.private` markiert.
  ([Feature-Doku](docs/features/code-politur-a3.md))
- **Typisierte Feedback-Zustaende statt String-Sniffing**: `CruiseFormView`
  und `SettingsView` nutzen ein `FeedbackStatus`-Enum mit
  VoiceOver-Announcement statt `contains("✓")`-Textpruefung.
  ([Feature-Doku](docs/features/code-politur-a3.md))
- **`PortEditIndex` statt `Int: @retroactive Identifiable`**: Dedizierter
  Wrapper ersetzt die app-weite Retroactive-Konformitaet in `CruiseFormView`.
  ([Feature-Doku](docs/features/code-politur-a3.md))
- **ZIP-Stack extrahiert**: `CRC32`, `ZipArchiveWriter` und `ZipArchiveReader`
  liegen jetzt in eigenen Dateien; `ExportImportService` deutlich verkleinert
  (reine Extraktion, keine Verhaltensaenderung).
  ([Feature-Doku](docs/features/code-politur-a3.md))
- **EUR-Fallback vollstaendig entfernt**: Die letzten sechs Anzeige-Stellen
  nutzen jetzt `Double.formattedCurrencyOrNumber` (Geraete-Locale) statt
  `?? "EUR"`.
  ([Feature-Doku](docs/features/code-politur-a3.md))

### Entfernt

- **`CruiseCardView` entfernt**: Die 139-Zeilen-Komponente war seit dem
  Hybrid-Redesign in der Produktion nicht mehr referenziert. Der genutzte
  Helfer `RatingBadge` wurde zuvor in eine eigene Datei
  `ShipTrip/Views/Cruises/RatingBadge.swift` ausgelagert, die weiterhin von
  `CruiseHeroCardView` verwendet wird.
- **Toter Code (Welle A3)**: `EmptyStateView.swift` geloescht, eine
  referenzlose `CruiseTimelineRowView`-Struct-Leiche entfernt sowie
  `Expense.colorName` und `Color.expenseColor` (beide ungenutzt) geloescht.
  ([Feature-Doku](docs/features/code-politur-a3.md))

### Behoben

- **Edit-Datenverlust bei Reisen mit Ausflügen/Hafenbild**: Bearbeiten einer
  Reise löschte bisher alle Häfen und legte sie neu an, wodurch importierte
  Ausflüge (`excursionsRaw`), Hafenbilder (`imageData`) verloren gingen und
  Port-`id`s neu vergeben wurden. `reconcileRoute()` in `CruiseFormView`
  aktualisiert bestehende Ports jetzt in-place per stabiler `id`.
  ([Feature-Doku](docs/features/datenintegritaet-a1.md),
  [ADR-002](docs/adr/ADR-002-cloudkit-sync-und-stabile-ids.md))
- **„Alle Daten löschen" unvollstaendig**: Geplante Erinnerungen wurden nicht
  entfernt; ein fehlschlagendes `save()` konnte inkonsistente Zustaende
  hinterlassen. Loeschung + `save()` laufen jetzt mit Rollback bei Fehler,
  danach werden alle geplanten Benachrichtigungen entfernt.
  ([Feature-Doku](docs/features/datenintegritaet-a1.md))
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

### Security

- **ZIP-Import gehaertet**: Ein Safe-Path-Resolver prueft ZIP-Eintraege und
  `data.json`-Pfadreferenzen gegen Pfad-Traversal (`..`, absolute Pfade)
  ausserhalb des Zielordners. Groessenlimits (50 MB pro Eintrag, 500 MB
  kumuliert, je fuer komprimierte und unkomprimierte Groesse vor jeder
  Allokation geprueft) verhindern Dekompressionsbomben; das Gesamtarchiv ist
  auf 550 MB gedeckelt. Datei-interne Cruise-ID-Duplikate werden erkannt und
  uebersprungen statt dupliziert importiert.
  ([Feature-Doku](docs/features/datenintegritaet-a1.md))
- **Gemini-API-Key nicht mehr in der Request-URL**: Der Key wird jetzt als
  `x-goog-api-key`-Header gesetzt (30s-Request-Timeout). Keychain-Items nutzen
  `kSecAttrAccessibleWhenUnlockedThisDeviceOnly` und wandern damit nicht mehr
  in iCloud-/Geraete-Backups.
  ([Feature-Doku](docs/features/code-politur-a3.md))

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
