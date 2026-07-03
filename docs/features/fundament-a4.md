# Welle A4 — Fundament & Wahrheit

**Status:** Abgeschlossen (A4.1, A4.2, A4.3)
**Testsuite:** 84/84 Unit-Tests PASS + 12/12 UI-Test-Methoden PASS (finaler serieller Testlauf)
**Quelle:** [Umsetzungsplan Audit 2026-07](../umsetzungsplan-audit-2026-07.md#welle-a4--fundament--wahrheit-findings-swift-5-drift-h-non-sendable-m-doku-drift-m-readmesetup-stale-l-test-lücken),
[Voll-Audit 2026-07-03](../../audit/audit-2026-07-03.html)

## Beschreibung

Welle A4 behebt drei zusammenhängende Findings aus dem Voll-Audit: Swift-5-Drift
im Projekt trotz beschlossener Swift-6-Migration (A4.1), Dokumentation, die an
mehreren Stellen von tatsächlich vorhandenen APIs/Modellen/Architektur abweicht
oder erfundene Details enthält (A4.2), sowie Testlücken in
sicherheitsrelevanten Services (A4.3).

---

## A4.2 — Doku-Sync

### Was / Warum

Die bestehende Dokumentation (`docs/MODELS.md`, `docs/API.md`,
`docs/ARCHITECTURE.md`, `README.md`, `docs/SETUP.md`, `CHANGELOG.md`) enthielt
mehrere nicht (mehr) zutreffende Aussagen: eine erfundene
`NotificationService`-API (`scheduleNotification(for cruise:)` existiert
nicht), eine falsche Behauptung „Secure Enclave" für den Gemini-API-Key
(real: Generic-Password-Keychain-Eintrag,
`kSecAttrAccessibleWhenUnlockedThisDeviceOnly`), ein nicht existierender
`App/`-Quellordner, veraltete Xcode-/iOS-Versionsangaben, eine falsche
`ExpenseCategory`-Liste (erfunden: Food/Shopping/Transport/Entertainment;
real: Kreuzfahrt/Flug/Hotel/Ausflug/An Bord/Sonstiges), die fälschliche
Behauptung „SwiftData ist thread-safe" sowie eine falsche Unit-Test-Zahl im
Changelog. Zusätzlich fehlte jede Dokumentation für `ExportImportService` und
den ZIP-Stack (`ZipArchiveWriter`/`ZipArchiveReader`/`CRC32`, alle drei erst
in Welle A3.11 in eigene Dateien extrahiert).

Jede Aussage in den überarbeiteten Dokumenten wurde gegen den realen
Quellcode verifiziert (Datei gelesen, Signatur/Property/Default geprüft) —
nicht aus altem Doku-Stand oder Gedächtnis übernommen.

### Berührte Dateien (nur `docs/`, `README.md`, `CHANGELOG.md` — kein Quellcode)

- `docs/MODELS.md` — komplett neu aus `ShipTrip/Models/` geschrieben:
  reale Properties/Defaults/Relationships für `Cruise`, `Port`, `Expense`,
  `Deal`, `Photo`; reale `ExpenseCategory`-Fälle; `PortSuggestion`/
  `ShippingLine`-Referenzstrukturen; neuer Abschnitt „CloudKit-Status"
  (siehe unten).
- `docs/API.md` — `NotificationService`, `GeminiService`, `KeychainService`
  an reale Signaturen angeglichen; `ExportImportService` und der ZIP-Stack
  (`CRC32`, `ZipArchiveWriter`, `ZipArchiveReader`) neu dokumentiert,
  inklusive Zip-Slip-/Dekompressionsbomben-Schutz und Größenlimits.
- `docs/ARCHITECTURE.md` — Threading-Absatz korrigiert (`ModelContext` ist
  nicht `Sendable`, kein „SwiftData ist thread-safe"); neuer Abschnitt „Push
  vs. lokale Notifications"; Service-Tabelle um `ExportImportService`/
  ZIP-Stack/`DemoDataService` ergänzt; Ordnerstruktur (kein `App/`-Ordner)
  und reale Tab-Namen (Reisen/Karte/Wunschreisen/Bilanz/Mehr) korrigiert.
- `README.md` — Badges (Swift 6, iOS 18.5+), Feature-Liste (lokale statt
  „Push"-Benachrichtigungen; ZIP-Export ergänzt), Tech-Stack-Tabelle,
  Projektstruktur (kein `App/`-Ordner, ZIP-Stack ergänzt), Roadmap
  (Export/Import als erledigt markiert, CloudKit-Status ehrlich mit
  Cross-Link zu ADR-002).
- `docs/SETUP.md` — Xcode 26.5 / iOS 18.5+ / Swift 6.0; Abschnitt „Push
  Notifications einrichten" ersetzt durch „Lokale Erinnerungen (kein
  Push/APNs)" — es gibt heute keine APNs-Capability im Projekt, diese ist
  erst für die CloudKit-Aktivierung (Welle D2.1) vorgesehen; neuer Abschnitt
  „Fastlane / TestFlight-Release" (Lanes, benötigte Umgebungsvariablen
  `ASC_KEY_ID`/`ASC_ISSUER_ID`/`ASC_KEY_PATH`, **keine** Secret-Werte).
- `CHANGELOG.md` — falsche Testzahl „52 gesamt" im `[Unreleased]`-Abschnitt
  auf den finalen Stand nach A4.1+A4.3 korrigiert (siehe „Testzahlen — final"
  unten).

### Korrigierte erfundene/falsche Doku-Behauptungen

| Datei | Falsche Behauptung | Korrektur |
|-------|--------------------|-----------|
| `docs/API.md` | `NotificationService.scheduleNotification(for cruise:)`, `cancelNotification`, `hasApiKey`, `GeminiError.parsingError` | Reale Methoden: `scheduleCruiseReminder`/`scheduleDepartureReminder`/`scheduleAllReminders`/`removeReminders` (reine Wertdaten); `GeminiService.isConfigured`; kein `.parsingError`-Fall |
| `docs/API.md` | „Daten werden verschlüsselt in der Secure Enclave gespeichert" | Generic-Password-Keychain-Eintrag mit `kSecAttrAccessibleWhenUnlockedThisDeviceOnly`, keine Secure Enclave |
| `docs/MODELS.md` | `ExpenseCategory`: Food/Shopping/Transport/Entertainment; `Expense.title`/`.date` | Reale Fälle: cruise/flight/hotel/excursion/onboard/other; reale Felder `descriptionText`/`expenseDate` |
| `docs/MODELS.md` | `Cruise.rating: Int`; keine `id`/`updatedAt`/`isDemo`-Felder erwähnt | `rating: Double`; alle Modelle mit `id: UUID`/`updatedAt` (LWW) dokumentiert |
| `docs/ARCHITECTURE.md` | „SwiftData ist thread-safe" | `ModelContext` ist nicht `Sendable`; Arbeit auf dem Main Actor bzw. via reine Wertdaten über Aktorgrenzen |
| `docs/ARCHITECTURE.md`, `README.md` | `App/`-Unterordner, Tab-Namen „Angebote"/„Statistik"/„Einstellungen" | Kein `App/`-Ordner (`ShipTripApp.swift` liegt direkt in `ShipTrip/`); reale Tabs „Reisen"/„Karte"/„Wunschreisen"/„Bilanz"/„Mehr" |
| `docs/SETUP.md` | Abschnitt „Push Notifications einrichten" (impliziert APNs-Capability) | Es existiert keine Push-/APNs-Capability; nur lokale Notifications |
| `CHANGELOG.md` | „Neue Unit-Tests (52 gesamt)" | Final (serieller Testlauf nach A4.1+A4.3): 84 Unit-Tests |

### Acceptance-Status

Erfüllt. Nach Abschluss von A4.1 (Swift 6) und A4.3 (neue Tests) wurde
`docs/ARCHITECTURE.md` (Threading-Absatz) zusätzlich gegen den finalen
Swift-6-Code gegengelesen und angepasst (siehe A4.1 unten).

### Testzahlen — final

**Verbindlich: 84 Unit-Tests + 12 UI-Test-Methoden, beide „TEST SUCCEEDED"**
(finaler serieller Testlauf nach Abschluss von A4.1 und A4.3). Eine statische
Zählung von `@Test`-Attributen in `ShipTripTests/` während der laufenden
A4.2-Session ergab nur 75 — parametrisierte Swift-Testing-Tests expandieren
im tatsächlichen Testlauf zu mehreren Einzelfällen, weshalb die reine
Attribut-Zählung die reale Testanzahl unterschätzt. Maßgeblich ist der
Testlauf, nicht die statische Zählung. Der im Umsetzungsplan genannte
Zielwert „48 Unit + 12 UI" war zu diesem Zeitpunkt bereits veraltet (Stand
vor Welle A3). Alle Testzahl-Stellen im Projekt wurden auf 84 Unit + 12 UI
geprüft; historische Wave-Docs (A0–A3) behalten bewusst ihre damaligen,
zum jeweiligen Abschlusszeitpunkt korrekten Werte (17/27/68/73/79/52) und
wurden nicht angetastet.

### Verwandte Entscheidungen

- [ADR-002: CloudKit-Sync, stabile IDs und ZIP-Export](../adr/ADR-002-cloudkit-sync-und-stabile-ids.md)

---

## A4.1 — Swift 6 + Strict Concurrency

### Was / Warum

Das Projekt war formal auf `SWIFT_VERSION = 5.0` konfiguriert, obwohl bereits
mit modernen Concurrency-Patterns (`async`/`await`, `@Observable`) gearbeitet
wurde — eine Lücke zwischen deklariertem und tatsächlichem Sprachstand, die
Concurrency-Fehler erst zur Laufzeit statt zur Compile-Zeit hätte sichtbar
werden lassen. Neu: `SWIFT_VERSION = 6.0` und `SWIFT_STRICT_CONCURRENCY =
complete` für alle sechs Build-Configs (App/Tests/UITests × Debug/Release).

Betroffene Singletons wurden je nach tatsächlichem State-Zugriffsmuster
eingestuft, **kein** `@unchecked Sendable`:

- **`GeminiService`** → `@MainActor` (bleibt zusätzlich `@Observable`).
  Erhält einen Test-Seam: `init(urlSession: URLSession = .shared)` — Tests
  können eine gemockte `URLSession` injizieren, ohne den Produktionscode zu
  verzweigen.
- **`ExportImportService`** → `@MainActor` (hält `DateFormatter`-Instanzen
  als State und arbeitet mit `ModelContext`, der selbst nicht `Sendable`
  ist — beides erzwingt Aktor-Isolation).
- **`NotificationService`** → `final class NotificationService: Sendable`
  (kein gespeicherter State außer dem `shared`-Singleton selbst; arbeitet
  ausschließlich über `UNUserNotificationCenter.current()` und reine
  Wertparameter — siehe bereits vorher in [API.md](../API.md#notificationservice)
  dokumentiertes Muster).
- **`DemoDataService`** — unverändert, war bereits sauber (kein
  zusätzlicher State).

Kollateral: Zwei private Helper-Funktionen in `HauptansichtScreenshotTests.swift`
wurden auf `@MainActor` annotiert (Migrations-Nebenwirkung, kein
Verhaltensunterschied).

### Berührte Dateien

- `ShipTrip.xcodeproj/project.pbxproj` (`SWIFT_VERSION`, `SWIFT_STRICT_CONCURRENCY`
  für alle sechs Build-Configs)
- `ShipTrip/Services/GeminiService.swift` (`@MainActor`, `init(urlSession:)`)
- `ShipTrip/Services/ExportImportService.swift` (`@MainActor`)
- `ShipTrip/Services/NotificationService.swift` (`final class: Sendable`)
- `ShipTripUITests/HauptansichtScreenshotTests.swift` (zwei private Helper
  `@MainActor`)

### Acceptance-Status

Erfüllt. `build-for-testing` für alle Targets (App, Unit-Tests, UI-Tests) mit
Exit-Code 0 und 0 Concurrency-Warnungen unter `SWIFT_STRICT_CONCURRENCY =
complete`.

---

## A4.3 — Testlücken schließen (GeminiService, KeychainService, Import-Härtung)

### Was / Warum

`GeminiService` — die einzige Netzwerk-Integration der App — war ohne
dedizierte Tests (offener Punkt seit Welle A3, siehe
[code-politur-a3.md](code-politur-a3.md#offene-punkte)). Neu: eine gemockte
`URLSession` (`MockURLProtocol`, ausschließlich per
`URLSessionConfiguration.protocolClasses` in eine Test-Session eingehängt,
**nicht** global via `URLProtocol.registerClass`) deckt vier Fälle ab:
erfolgreiche Extraktion, HTTP 401 (`GeminiError.invalidApiKey`), HTTP 429
(`GeminiError.quotaExceeded`) und kaputtes JSON in der Gemini-Antwort
(`GeminiError.invalidResponse`). Der Mock-Handler-State liegt hinter einem
`OSAllocatedUnfairLock` — bewusst kein `@unchecked Sendable`.

Zusätzlich: ein `KeychainService`-Roundtrip-Test (save/read/delete für
`.geminiApiKey`), der einen eventuell real vorhandenen Key vor dem Testlauf
sichert und danach wiederherstellt, um lokal hinterlegte Keys nicht zu
überschreiben.

Alle fünf Tests liegen in einer gemeinsamen `@Suite(.serialized)` (neue Datei
`ShipTripTests/GeminiServiceTests.swift`), da GeminiService- und
Keychain-Tests denselben physischen Keychain-Eintrag teilen und parallel
laufend interferieren könnten.

**Import-Härtungs-Tests aus A1.3 existierten bereits vollständig**
(`ShipTripTests/ExportImportHardeningTests.swift`, aus Welle A1) — hier war
keine weitere Arbeit nötig, keine Doppelungen angelegt.

### Berührte Dateien

- `ShipTripTests/GeminiServiceTests.swift` (neu — 4 GeminiService-Tests + 1
  KeychainService-Roundtrip-Test)

### Acceptance-Status

Erfüllt. Alle 5 neuen Tests grün im finalen seriellen Testlauf (siehe
Testzahlen oben: 84 Unit-Tests gesamt).
