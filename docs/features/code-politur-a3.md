# Welle A3 — Code-Politur

**Status:** Abgeschlossen
**Testsuite:** 79/79 Unit-Tests PASS
**Quelle:** [Umsetzungsplan Audit 2026-07](../umsetzungsplan-audit-2026-07.md#welle-a3--code-politur-findings-key-in-url-l-m-ksecattraccessible-l-m-print-pii-l-status-sniffing-l-häfen-zählung-l-radius-wildwuchs-m-portsuggestion-scans-l-export-temp-l-idbackfill-flag-l-intidentifiable-l-toter-code-ml-god-file-m),
[Voll-Audit 2026-07-03](../../audit/audit-2026-07-03.html)

## Beschreibung

Welle A3 behebt elf Code-Qualitaets-Findings aus dem Voll-Audit: einen
API-Key in der Request-URL statt im Header, fehlende Keychain-Backup-Attribute,
`print`-Debug-Logs statt strukturiertem Logging, String-Sniffing statt
typisierter Feedback-Zustaende, inkonsistente Haefen-Zaehlung, verstreute
Corner-Radien, lineare Hafen-Suche, einen wiederholt laufenden Start-Repair,
eine `@retroactive Identifiable`-Konformitaet, toten Code sowie einen
monolithischen ZIP-Export-Service. Zusaetzlich (A3.11a) wurde der verbliebene
EUR-Fallback aus [A2.6](ux-fixes-a2.md) an den restlichen sechs
Anzeige-Stellen entfernt.

---

## A3.1 — Gemini-API-Key im Header + Keychain-Backup-Attribut

### Was / Warum

Der Gemini-API-Key wurde bisher als Query-Parameter an die Request-URL
angehaengt (Logs, Proxies, Browser-History-Analogon). Neu: der Key wird als
`x-goog-api-key`-Header gesetzt, die URL enthaelt keinen Key mehr. Zusaetzlich
erhaelt jeder Request ein 30-Sekunden-Timeout (`timeoutInterval: 30`), damit
ein haengender Request nicht unbegrenzt blockiert. Keychain-Items nutzen jetzt
`kSecAttrAccessibleWhenUnlockedThisDeviceOnly` statt des Default-Attributs —
der Key wandert damit nicht mehr in iCloud-Keychain-Backups oder
Geraete-Backups.

### Berührte Dateien

- `ShipTrip/Services/GeminiService.swift`
- `ShipTrip/Services/KeychainService.swift`

### Acceptance-Status

Erfüllt (Code-Review). `GeminiService` bleibt ohne dedizierte Unit-Tests
(Netzwerk-Mocking noch offen, siehe Offene Punkte / A4.3).

---

## A3.2 — Strukturiertes Logging statt `print` (NotificationService)

### Was / Warum

`NotificationService` protokollierte bisher ueber `print`, was im
Release-Build weder gefiltert noch unterdrueckt werden kann. Neu: ein
`os.Logger` (Subsystem `com.andre.ShipTrip`, Kategorie `notifications`)
ersetzt alle `print`-Aufrufe; Nutzerinhalte (z. B. Reise-Titel) werden als
`.private` markiert und erscheinen damit nicht im Klartext in Systemlogs.

### Berührte Dateien

- `ShipTrip/Services/NotificationService.swift`

### Acceptance-Status

Erfüllt (Code-Review).

---

## A3.3 — `FeedbackStatus`-Enum statt String-Sniffing

### Was / Warum

`CruiseFormView` und `SettingsView` erkannten Erfolgs-/Fehlerzustaende bisher
per `contains("✓")` auf dem angezeigten Text — fragil bei
Lokalisierung/Textaenderung und ohne VoiceOver-Unterstuetzung. Neu: ein
typisiertes `FeedbackStatus`-Enum (je eine private Definition in
`CruiseFormView` und `SettingsView`) traegt den Zustand explizit; ein
`accessibilityAnnouncement`-Post informiert VoiceOver-Nutzer beim
Zustandswechsel, statt dass die Information nur visuell sichtbar ist.

### Berührte Dateien

- `ShipTrip/Views/Cruises/CruiseFormView.swift` (`FeedbackStatus`, `aiFeedback`)
- `ShipTrip/Views/Settings/SettingsView.swift` (`FeedbackStatus`, `validationStatus`)

### Acceptance-Status

Erfüllt (Code-Review). VoiceOver-Announcement am Geraet noch nicht
gesichtet (siehe Offene Punkte).

---

## A3.4 — Einheitliche Haefen-Zaehlung ohne Seetage

### Was / Warum

`CruiseDetailView` und `StatsView` zaehlten Haefen bisher an je einer Stelle
inkonsistent (teils inklusive Seetagen als Route-Eintrag). Beide Views nutzen
jetzt dieselbe Zaehlweise: nur echte Hafenstopps (`isSeaDay == false`) zaehlen
als Hafen.

### Berührte Dateien

- `ShipTrip/Views/Cruises/CruiseDetailView.swift`
- `ShipTrip/Views/Stats/StatsView.swift`

### Acceptance-Status

Erfüllt (Code-Review).

---

## A3.5 — `DesignRadius`-Token statt verstreuter Corner-Radien

### Was / Warum

Corner-Radien waren als Magic Numbers ueber zehn View-Dateien verstreut
(u. a. 10, 16, 22, 24, 28). Neu: `DesignRadius` in `Color+Theme.swift`
definiert drei Stufen — `sm = 10`, `md = 16`, `lg = 28` — die app-weit
verwendet werden. **Bewusste Abweichung:** vormals 22er- und 24er-Radien
wurden auf `lg = 28` angehoben statt eine vierte Stufe einzufuehren; visuell
minimal groessere Rundung an diesen Stellen. Das ungenutzte
`cardStyle()`-View-Modifier wurde entfernt (ohne verbleibende Referenz).

### Berührte Dateien

- `ShipTrip/Utilities/Color+Theme.swift` (`DesignRadius`, `cardStyle()` entfernt)
- 10 weitere View-Dateien (Uebernahme der Token statt Literal-Radien)

### Acceptance-Status

Erfüllt (Code-Review). Visuelle Sichtpruefung der 22/24→28-Abweichung am
Geraet steht noch aus (siehe Offene Punkte).

---

## A3.6 — Vorberechneter Suchindex fuer Hafen-Suche (PortSuggestion)

### Was / Warum

Die Autocomplete-Suche fuehrte bisher bis zu vier lineare Scans ueber alle
~1.800 Haefen pro Tastenanschlag durch (Name, Alias, Land, Normalisierung).
Neu: ein vorberechneter Suchindex ersetzt die Linearscans; die bestehende
Treffer-Prioritaet (exakter Treffer vor Praefix vor Teilstring, siehe
[docs/MODELS.md](../MODELS.md)) bleibt unveraendert.

### Berührte Dateien

- `ShipTrip/Models/PortSuggestion.swift`

### Acceptance-Status

Erfüllt (Code-Review). Kein dedizierter Performance-Test; funktionale
Trefferreihenfolge unveraendert und bestehende Tests bleiben gruen.

---

## A3.7 — Export-Temp-Dateien mit UUID-Namen + garantiertes Aufraeumen

### Was / Warum

Export-Temp-Dateien fuer den Share-Sheet-Flow nutzten bisher vorhersagbare
Namen und wurden bei abgebrochenem Teilen nicht zuverlaessig entfernt. Neu:
Temp-Dateien erhalten UUID-basierte Namen und werden nach Abschluss des
Share-Vorgangs geloescht — auch wenn der Nutzer das Teilen abbricht.

### Berührte Dateien

- `ShipTrip/Services/ExportImportService.swift`
- `ShipTrip/Views/Settings/SettingsView.swift`

### Acceptance-Status

Erfüllt (Code-Review).

---

## A3.8 — `IdBackfill` laeuft nur noch einmal

### Was / Warum

`IdBackfill` (siehe [ADR-002](../adr/ADR-002-cloudkit-sync-und-stabile-ids.md))
lief bisher bei jedem App-Start erneut, obwohl die Reparatur idempotent ist.
Neu: ein UserDefaults-Flag (`idBackfillCompleted.v1`) markiert einen
vollstaendig erfolgreichen Lauf. Das Flag wird **nur** gesetzt, wenn alle fuenf
Modelltypen fehlerfrei gefetcht wurden, ein noetiger Save erfolgreich war,
und die App nicht auf dem In-Memory-Fallback-Store laeuft (siehe
`ShipTripApp`-Fallback-Logik) — ein Fetch- oder Save-Fehler laesst den
Backfill beim naechsten Start erneut laufen. Die Gating-Entscheidung ist als
reine Funktion `shouldMarkCompleted(allSucceeded:usingFallbackStore:)`
ausgelagert, getrennt von der SwiftData-I/O.

**Hinweis:** Ein Test fuer den reinen Fetch-Fehler-Pfad wurde bewusst wieder
entfernt — ein echter SwiftData-Fetch-Fehler laesst sich nicht deterministisch
provozieren (Schema-Auslassungen werden von SwiftData transitiv toleriert).
Der Fehler-Contract ist stattdessen ueber die Gating-Funktion
(`shouldMarkCompleted`) und ueber Save-Fehler-Tests deterministisch abgedeckt.

### Berührte Dateien

- `ShipTrip/Utilities/IdBackfill.swift` (`completedFlagKey`, `shouldMarkCompleted`)
- `ShipTripTests/IdBackfillTests.swift`

### Acceptance-Status

Erfüllt. `shouldMarkCompleted` und die Save-Fehler-Pfade sind in
`ShipTripTests/IdBackfillTests.swift` getestet.

---

## A3.9 — `PortEditIndex`-Wrapper statt `Int: @retroactive Identifiable`

### Was / Warum

`CruiseFormView` liess `Int` bisher retroaktiv `Identifiable` konformieren, um
`Int` als Sheet-Item zu verwenden — eine app-weite Konformitaet fuer einen
Fremdtyp mit Kollisionsrisiko. Neu: ein dedizierter Wrapper `PortEditIndex`
(mit `id`) ersetzt `Int?` als Zustand fuer den bearbeiteten Hafen-Index.

### Berührte Dateien

- `ShipTrip/Views/Cruises/CruiseFormView.swift` (`PortEditIndex`, `editingPortIndex`)

### Acceptance-Status

Erfüllt (Code-Review).

---

## A3.10 — Toter Code entfernt

### Was / Warum

Vier referenzlose Code-Stellen wurden entfernt:

- `ShipTrip/Components/EmptyStateView.swift` — komplett geloescht (keine
  verbleibende Verwendung, seit dem Hybrid-Redesign durch
  `ContentUnavailableView` ersetzt).
- Die ungenutzte `CruiseTimelineRowView`-Struct-Leiche in
  `CruiseTimelineRowView.swift` — entfernt; `CruiseYearDivider` in derselben
  Datei bleibt, da aktiv genutzt.
- `Expense.colorName` und `Color.expenseColor` — beide referenzlos, beide
  geloescht.

### Berührte Dateien

- `ShipTrip/Components/EmptyStateView.swift` (geloescht)
- `ShipTrip/Views/Cruises/CruiseTimelineRowView.swift`
- `ShipTrip/Models/Expense.swift`
- `ShipTrip/Utilities/Color+Theme.swift`

### Acceptance-Status

Erfüllt. Bestehende Tests bleiben gruen; keine verbleibenden Referenzen
gefunden.

---

## A3.11 — ZIP-Stack in eigene Dateien extrahiert

### Was / Warum

`ExportImportService.swift` buendelte bisher Export/Import-Logik zusammen mit
der ZIP-Implementierung (CRC32, Writer, Reader) in einer Datei. Neu: der
ZIP-Stack ist in drei eigene Dateien ausgelagert (`CRC32.swift`,
`ZipArchiveWriter.swift`, `ZipArchiveReader.swift`); `ExportImportService`
ist dadurch deutlich kompakter und auf Export/Import-Orchestrierung
fokussiert. Fehlertypen (`ImportError`) bleiben unveraendert.

### Berührte Dateien

- `ShipTrip/Services/ExportImportService.swift` (verkleinert)
- `ShipTrip/Services/CRC32.swift` (neu)
- `ShipTrip/Services/ZipArchiveWriter.swift` (neu)
- `ShipTrip/Services/ZipArchiveReader.swift` (neu)

### Acceptance-Status

Erfüllt. Bestehende `ExportImportHardeningTests` bleiben gruen (reine
Extraktion, keine Verhaltensaenderung).

---

## A3.11a — Verbleibender EUR-Fallback entfernt (Anzeige-Stellen)

### Was / Warum

[A2.6](ux-fixes-a2.md) hatte den EUR-Fallback nur fuer die Ausgaben-Eingabe
entfernt; sechs Anzeige-Stellen fielen weiterhin auf `?? "EUR"` zurueck, wenn
die Geraete-Locale keine Waehrung besitzt. Neu: ein einheitliches
`Double.formattedCurrencyOrNumber` (Geraete-Locale, neutrales Zahlenformat
ohne Waehrungssymbol als Fallback statt hartem `"EUR"`) ersetzt alle sechs
Stellen.

### Berührte Dateien

- `ShipTrip/Models/Expense.swift` (`formattedCurrencyOrNumber`)
- `ShipTrip/Models/Deal.swift`
- `ShipTrip/Views/Stats/StatsView.swift`
- `ShipTrip/Views/Cruises/CruiseDetailView.swift`

### Acceptance-Status

Erfüllt (Code-Review).

---

## Offene Punkte

- `GeminiService` bleibt ohne dedizierte Unit-Tests (Netzwerk-Mocking) —
  geplant fuer **A4.3**.
- Visuelle Sichtpruefung der Radius-Abweichung 22/24→28 (A3.5) und der
  VoiceOver-Announcements (A3.3) am Geraet/Simulator stehen vor dem
  1.6.0-Release noch aus.

## Verwandte Entscheidungen

- [ADR-002: CloudKit-Sync, stabile IDs und ZIP-Export](../adr/ADR-002-cloudkit-sync-und-stabile-ids.md)
