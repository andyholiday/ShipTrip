# API Integration

Dokumentation der externen Integrationen und Kern-Services in ShipTrip.
Quelle: `ShipTrip/Services/`.

## Gemini API (Google AI)

ShipTrip nutzt **Gemini 2.5 Flash** für die KI-gestützte Analyse von
Buchungsbestätigungen.

### Konfiguration

1. API-Key erstellen: [Google AI Studio](https://aistudio.google.com/)
2. In der App: Einstellungen → Gemini-API-Key eingeben
3. Key wird in der iOS Keychain gespeichert (siehe [KeychainService](#keychainservice))

### GeminiService

`ShipTrip/Services/GeminiService.swift` — `@Observable`, `@MainActor class`, Singleton.

```swift
@Observable
@MainActor
class GeminiService {
    static let shared = GeminiService()

    /// `urlSession` ist injizierbar, damit Tests einen gemockten `URLSession` verwenden können.
    init(urlSession: URLSession = .shared)

    var isConfigured: Bool { get }

    func setApiKey(_ key: String)
    func clearApiKey()

    func validateApiKey() async throws -> Bool
    func extractCruiseData(from text: String) async throws -> ExtractedCruiseData
}
```

- `@MainActor`-isoliert seit der Swift-6-Migration (Welle A4.1).
- `baseURL` ist fest auf `gemini-2.5-flash:generateContent` verdrahtet
  (`https://generativelanguage.googleapis.com/v1beta/models/...`).
- Requests setzen den API-Key als `x-goog-api-key`-Header (nicht als
  Query-Parameter in der URL) und haben ein 30-Sekunden-Timeout
  (`URLRequest(url:timeoutInterval: 30)`).
- `validateApiKey()` prüft den Key mit einem Test-Prompt ("Sage nur 'OK'.")
  über denselben Endpunkt wie `extractCruiseData`.

### Datenextraktion

`extractCruiseData(from:)` schickt einen festen deutschen Prompt (siehe unten)
und parst die Antwort. Rückgabetyp `ExtractedCruiseData`:

```swift
struct ExtractedCruiseData: Codable {
    let title: String?
    let shippingLine: String?
    let ship: String?
    let startDate: String?      // YYYY-MM-DD
    let endDate: String?        // YYYY-MM-DD
    let cabinType: String?
    let cabinNumber: String?
    let bookingNumber: String?
    let ports: [ExtractedPort]?
}

struct ExtractedPort: Codable {
    let name: String
    let country: String?
    let arrivalDate: String?    // YYYY-MM-DD
    let arrivalTime: String?    // HH:MM
    let departureDate: String?  // YYYY-MM-DD
    let departureTime: String?  // HH:MM
    let isSeaDay: Bool?
}
```

Antwort-Bereinigung vor dem JSON-Decode: Markdown-Codefences (```` ```json ```` /
```` ``` ````) werden entfernt, danach wird der Bereich zwischen dem ersten `{`
und dem letzten `}` extrahiert.

### Fehlertypen

```swift
enum GeminiError: LocalizedError {
    case noApiKey
    case invalidURL
    case invalidRequest       // HTTP 400
    case invalidApiKey        // HTTP 401/403
    case quotaExceeded        // HTTP 429
    case networkError         // keine HTTPURLResponse
    case serverError(Int)     // sonstiger Statuscode
    case invalidResponse      // Antwort nicht parsbar
    case apiError(String)     // Fehlermeldung aus dem Gemini-Response-Body
}
```

Es gibt **keinen** dedizierten `parsingError`-Fall — ein fehlgeschlagenes
JSON-Decode von `ExtractedCruiseData` wirft ebenfalls `.invalidResponse`.

---

## KeychainService

`ShipTrip/Services/KeychainService.swift` — sichere Speicherung von Secrets
(aktuell nur der Gemini-API-Key) in der iOS Keychain.

```swift
enum KeychainService {
    enum Key: String {
        case geminiApiKey = "gemini_api_key"
    }

    @discardableResult
    static func save(_ value: String, for key: Key) -> Bool

    static func read(_ key: Key) -> String?

    @discardableResult
    static func delete(_ key: Key) -> Bool

    static func exists(_ key: Key) -> Bool
}
```

### Sicherheit

- Klasse: `kSecClassGenericPassword`, Service-Bezeichner `"com.shiptrip.app"`,
  Account = `Key.rawValue`.
- Zugriffs-Attribut: **`kSecAttrAccessibleWhenUnlockedThisDeviceOnly`** — das
  Item ist nur bei entsperrtem Gerät lesbar und wandert **nicht** in
  iCloud-Keychain- oder Geräte-Backups (Welle A3.1). Es wird **keine** Secure
  Enclave verwendet — das ist eine reguläre, gerätegebundene Generic-Password-
  Keychain-Eintragung, kein Hardware-Schlüssel.
- `save(_:for:)` löscht ein vorhandenes Item für denselben Key zuerst
  (`delete(key)`), bevor es neu angelegt wird — kein `SecItemUpdate`.

---

## NotificationService

`ShipTrip/Services/NotificationService.swift` — **lokale** Erinnerungen vor
Reisen über `UserNotifications`. Es handelt sich **nicht** um Push-Notifications
(APNs); es gibt aktuell keine `aps-environment`-Capability im Projekt (siehe
[ARCHITECTURE.md](ARCHITECTURE.md#push-vs-lokale-notifications)).

```swift
final class NotificationService: Sendable {
    static let shared = NotificationService()

    // Permission
    func requestAuthorization() async -> Bool
    func isAuthorized() async -> Bool
    func authorizationStatus() async -> UNAuthorizationStatus
    var remindersEnabledInSettings: Bool { get }

    // Cruise Reminders (reine Wertdaten, kein @Model-Objekt über Aktorgrenzen)
    func scheduleCruiseReminder(cruiseID: String, title: String, startDate: Date, daysBefore: Int) async
    func scheduleDepartureReminder(cruiseID: String, title: String, startDate: Date) async
    func scheduleAllReminders(cruiseID: String, title: String, startDate: Date) async
    func removeReminders(cruiseID: String) async

    // Management
    func removeAllPendingNotifications()
    func getPendingNotifications() async -> [UNNotificationRequest]
}
```

- `Sendable` seit der Swift-6-Migration (Welle A4.1): kein gespeicherter
  State außer dem `shared`-Singleton, alle Methoden arbeiten mit
  `UNUserNotificationCenter.current()` und reinen Wertparametern.
- `isAuthorized()` liefert `true` auch bei `.provisional`/`.ephemeral`, nicht
  nur bei `.authorized` — nur `.denied`/`.notDetermined` gelten als nicht
  autorisiert.
- `remindersEnabledInSettings` liest zwei `UserDefaults`-Flags
  (`notifyBeforeCruise` Default `true`, `notifyOnCruiseDay` Default `true`) —
  unabhängig vom System-Berechtigungsstatus.
- `scheduleAllReminders` liest zusätzlich `reminderDaysBefore` (Default `7`)
  aus `UserDefaults` und ruft je nach Flag `scheduleCruiseReminder` und/oder
  `scheduleDepartureReminder` auf.
- Notification-IDs sind `"cruise-\(cruiseID)-\(daysBefore)days"` bzw.
  `"cruise-\(cruiseID)-departure"`; `removeReminders(cruiseID:)` entfernt alle
  IDs mit Präfix `"cruise-\(cruiseID)-"`.
- Logging über `os.Logger` (Subsystem `com.andre.ShipTrip`, Kategorie
  `notifications`); Nutzerinhalte wie Reise-Titel sind `.private` markiert
  (Welle A3.2) — kein `print`.

### Reminder-Inhalte

| Methode | Zeitpunkt | Titel |
|---------|-----------|-------|
| `scheduleCruiseReminder` | `startDate` minus `daysBefore` Tage, zur berechneten Uhrzeit | "Kreuzfahrt in \(daysBefore) Tagen! 🚢" |
| `scheduleDepartureReminder` | Abreisetag, 8:00 Uhr | "Heute geht's los! ⚓️" |

---

## ExportImportService

`ShipTrip/Services/ExportImportService.swift` — Export/Import aller Reisen als
JSON (Legacy) oder ZIP (aktuell). ZIP-Implementierung selbst liegt in eigenen
Dateien: [`CRC32.swift`](#crc32), [`ZipArchiveWriter.swift`](#ziparchivewriter),
[`ZipArchiveReader.swift`](#ziparchivereader).

```swift
@MainActor
class ExportImportService {
    static let shared = ExportImportService()

    func exportToJSON(cruises: [Cruise]) throws -> URL
    func exportToZip(cruises: [Cruise]) throws -> URL

    func importFromZip(url: URL, modelContext: ModelContext) throws -> ImportResult
    func importFromJSON(url: URL, modelContext: ModelContext) throws -> ImportResult
}

struct ImportResult {
    let imported: Int
    let skippedDuplicates: Int
    let skippedInvalid: Int
}
```

`@MainActor`-isoliert seit der Swift-6-Migration (Welle A4.1) — hält
`DateFormatter`-State und arbeitet mit `ModelContext`, der selbst nicht
`Sendable` ist.

### Export-Formate

- **`exportToJSON`** — Legacy-Format: Fotos als `"data:image/png;base64,..."`
  direkt in `data.json` eingebettet. Skaliert nicht für viele/große Fotos.
- **`exportToZip`** — aktuelles Format:
  - `data.json` — strukturierte Daten; Foto-Referenzen sind Pfade
    (`images/<cruiseId>/<index>`), Hafenbild-Referenzen
    (`images/<cruiseId>/ports/<index>`), kein Base64.
  - `images/<cruiseId>/<index>` — rohe `Photo.imageData`-Bytes (kein
    Re-Encoding).
  - `images/<cruiseId>/ports/<index>` — rohe `Port.imageData`-Bytes, sofern
    vorhanden.
  - Alle IDs (`Cruise.id`, `Port.id`, `Expense.id`) werden als stabile
    `UUID`-Strings exportiert, nicht neu generiert — Re-Import ist idempotent.

`ExportCruise` / `ExportPort` / `ExportExpense` sind die `Codable`-DTOs für
beide Formate (siehe Source für exakte Feldliste).

### Import-Verhalten

- `importFromZip` extrahiert zunächst per `ZipArchiveReader.extract` in ein
  Temp-Verzeichnis, sucht `data.json` im Root oder einem Unterordner und
  delegiert an dieselbe interne `importFromJSONData`-Logik wie `importFromJSON`.
- **Duplikat-Erkennung:** primär über `Cruise.id` (Datei-UUID gegen
  bestehende Cruises **und** gegen bereits in diesem Import gesehene IDs);
  Fallback für Legacy-Exporte ohne gültige UUID über
  `title + startDate (Tag) + ship` (case-insensitive).
  Dasselbe ID-Präzedenz-Muster (erstes Vorkommen gewinnt die Datei-ID, weitere
  behalten ihre frische Auto-UUID) gilt zusätzlich innerhalb einer Cruise für
  `Port`- und `Expense`-IDs.
- **Validierung:** Cruises mit nicht parsbarem Datum oder `endDate < startDate`
  werden übersprungen (`skippedInvalid`), nicht importiert.
- **Fehlende Bilder** (ZIP-Pfad oder Base64 nicht lesbar) werden toleriert:
  das zugehörige `Photo`/`imageData` wird übersprungen, die Cruise bleibt
  erhalten.
- **Rollback:** Schlägt `modelContext.save()` fehl, wird `modelContext.rollback()`
  aufgerufen, bevor der Fehler weitergereicht wird — bereits gestagte
  Import-Objekte bleiben nicht im Context.
- Bildpfade aus `data.json` werden ausschließlich über
  `ZipArchiveReader.resolveSafePath(_:in:)` aufgelöst (Zip-Slip-Schutz, siehe
  unten) — nie direkt aus dem String gebaut.

### Fehlertypen

```swift
enum ImportError: LocalizedError {
    case noDataFile
    case invalidFormat
    case unsafePath(String)                       // Zip-Slip-Kandidat
    case entryTooLarge(name: String, size: Int)    // Dekompressionsbomben-Schutz
    case archiveTooLarge(Int)
    case sizeMismatch(name: String)                // STORED: compressedSize != uncompressedSize
}
```

---

## ZIP-Stack (Export/Import-Unterbau)

Ausgelagert aus `ExportImportService` in Welle A3.11 — reine Extraktion, keine
Verhaltensänderung.

### CRC32

`ShipTrip/Services/CRC32.swift`

```swift
enum CRC32 {
    static func checksum(_ data: Data) -> UInt32
}
```

IEEE-802.3-Polynom (`0xEDB88320`, reflected), Lookup-Tabelle wird einmalig
lazy berechnet.

### ZipArchiveWriter

`ShipTrip/Services/ZipArchiveWriter.swift`

```swift
enum ZipArchiveWriter {
    static func build(entries: [(name: String, data: Data)]) throws -> Data
}

enum ZipWriterError: LocalizedError {
    case invalidEntryName(String)
    case tooManyEntries(Int)              // ZIP32: max UInt16.max Einträge
    case entryTooLarge(name: String, size: Int)  // kein ZIP64: max UInt32.max Bytes
    case archiveTooLarge(Int)
}
```

- Schreibt ausschließlich **Compression Method 0 (STORED)**, kein Deflate.
- Zwei-Pass-Aufbau: erster Pass schreibt Local File Headers und cacht
  CRC-32/Größe/Offset pro Eintrag (`ZipEntryMeta`); zweiter Pass schreibt das
  Central Directory ausschließlich aus diesem Cache — CRC-32 wird nicht ein
  zweites Mal berechnet.
- Kein ZIP64-Support: Archive über 4 GB oder mit mehr als 65.535 Einträgen
  werfen explizit einen Fehler statt still zu truncaten.

### ZipArchiveReader

`ShipTrip/Services/ZipArchiveReader.swift`

```swift
enum ZipArchiveReader {
    static let maxEntryUncompressedSize = 50 * 1024 * 1024    // 50 MB
    static let maxTotalUncompressedSize = 500 * 1024 * 1024   // 500 MB
    static let maxArchiveFileSize = 550 * 1024 * 1024          // 550 MB

    static func resolveSafePath(_ relativePath: String, in baseURL: URL) throws -> URL
    static func extract(from sourceURL: URL, to destinationURL: URL) throws
}
```

- Unterstützt **STORED (0)** und **Deflate (8)** beim Lesen (Deflate über
  Apples `Compression`-Framework, `COMPRESSION_ZLIB`); geschrieben wird von
  `ZipArchiveWriter` nur STORED.
- **Zip-Slip-Schutz** (`resolveSafePath`): lehnt leere/absolute Pfade,
  `~`-Präfixe, Backslashes sowie jede Pfadkomponente `.`/`..` **vor** der
  Pfad-Normalisierung ab; prüft zusätzlich (Defense-in-Depth), dass der
  standardisierte Zielpfad innerhalb von `baseURL` bleibt.
- **Dekompressionsbomben-Schutz**: `uncompressedSize` **und**
  `compressedSize` jedes Eintrags werden gegen `maxEntryUncompressedSize`
  geprüft, kumulierte Größen gegen `maxTotalUncompressedSize` — alles
  **vor** jeder Allokation/Dekompression. Die Archivdatei selbst wird vor dem
  Einlesen gegen `maxArchiveFileSize` geprüft.
- **STORED-Konsistenz**: bei Methode 0 muss `compressedSize == uncompressedSize`
  sein, sonst `ImportError.sizeMismatch`.
- Sucht die End-of-Central-Directory-Signatur (`0x06054B50`) rückwärts vom
  Dateiende; kein ZIP64-EOCD-Support.

---

## Zukünftige APIs (Roadmap, nicht implementiert)

- **CloudKit-Sync** — Datenmodell teilweise vorbereitet (stabile IDs,
  `updatedAt`), aber nicht aktiv und nicht vollständig konform. Siehe
  [MODELS.md → CloudKit-Status](MODELS.md#cloudkit-status-projektweit) und
  [ADR-002](adr/ADR-002-cloudkit-sync-und-stabile-ids.md).
- **Wetter-API** — nicht begonnen.
- **Hafen-Bilder mit KI-Generierung** — nicht begonnen.
