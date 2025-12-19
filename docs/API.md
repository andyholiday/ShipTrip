# API Integration

Dokumentation der externen API-Integrationen in ShipTrip.

## Gemini API (Google AI)

ShipTrip nutzt **Gemini 2.5 Flash** für die KI-gestützte Analyse von Buchungsbestätigungen.

### Konfiguration

1. API-Key erstellen: [Google AI Studio](https://aistudio.google.com/)
2. In der App: Einstellungen → API Key eingeben
3. Key wird sicher in der iOS Keychain gespeichert

### GeminiService

```swift
class GeminiService {
    static let shared = GeminiService()
    
    // API Key Management
    var hasApiKey: Bool
    func setApiKey(_ key: String)
    func clearApiKey()
    
    // Key Validation
    func validateApiKey() async throws -> Bool
    
    // Data Extraction
    func extractCruiseData(from text: String) async throws -> ExtractedCruiseData
}
```

### Datenextraktion

Der Service extrahiert folgende Daten aus Buchungsbestätigungen:

| Feld | Typ | Beschreibung |
|------|-----|--------------|
| `title` | `String?` | Reisetitel |
| `shippingLine` | `String?` | Reederei |
| `ship` | `String?` | Schiffsname |
| `startDate` | `String?` | Abreisedatum (YYYY-MM-DD) |
| `endDate` | `String?` | Rückkehrdatum (YYYY-MM-DD) |
| `cabinType` | `String?` | Kabinentyp |
| `bookingNumber` | `String?` | Buchungsnummer |
| `ports` | `[ExtractedPort]?` | Häfen mit Zeiten |

### ExtractedPort

```swift
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

### Prompt-Template

```
Analysiere den folgenden Text einer Kreuzfahrt-Buchung und extrahiere die Daten.
Antworte NUR im JSON-Format ohne Markdown-Formatierung:

{
    "title": "Titel der Reise",
    "shippingLine": "Name der Reederei",
    "ship": "Name des Schiffs",
    ...
    "ports": [
        {
            "name": "Hafenname oder Seetag",
            "country": "Land (leer bei Seetag)",
            "isSeaDay": false
            ...
        }
    ]
}
```

### Fehlerbehandlung

```swift
enum GeminiError: LocalizedError {
    case noApiKey           // Kein API-Key konfiguriert
    case invalidApiKey      // API-Key ungültig
    case networkError       // Netzwerkfehler
    case invalidResponse    // Ungültige API-Antwort
    case parsingError       // JSON-Parsing fehlgeschlagen
}
```

### Rate Limits

| Limit | Wert |
|-------|------|
| Requests/Minute | 60 |
| Requests/Tag | 1.500 (Free Tier) |
| Token-Limit | 1M pro Anfrage |

---

## KeychainService

Sichere Speicherung von API-Keys in der iOS Keychain.

### API

```swift
enum KeychainService {
    enum Key: String {
        case geminiApiKey = "gemini_api_key"
    }
    
    // CRUD Operations
    @discardableResult
    static func save(_ value: String, for key: Key) -> Bool
    
    static func read(_ key: Key) -> String?
    
    @discardableResult
    static func delete(_ key: Key) -> Bool
    
    static func exists(_ key: Key) -> Bool
}
```

### Sicherheit

- Daten werden verschlüsselt in der Secure Enclave gespeichert
- Nur die App hat Zugriff (kSecClass: kSecClassGenericPassword)
- Keychain überlebt App-Deinstallation (bis iOS 10.3)

---

## NotificationService

Push-Benachrichtigungen für Reiseerinnerungen.

### API

```swift
class NotificationService {
    static let shared = NotificationService()
    
    // Permission
    func requestPermission() async -> Bool
    
    // CRUD
    func scheduleNotification(for cruise: Cruise)
    func cancelNotification(for cruise: Cruise)
    func cancelAllNotifications()
}
```

### Benachrichtigungs-Typen

| Trigger | Zeitpunkt | Inhalt |
|---------|-----------|--------|
| Reise-Start | 1 Tag vorher | "Morgen geht's los! Deine Kreuzfahrt {title} beginnt." |

### Implementierung

```swift
func scheduleNotification(for cruise: Cruise) {
    let content = UNMutableNotificationContent()
    content.title = "🚢 Kreuzfahrt-Erinnerung"
    content.body = "Morgen geht's los! \(cruise.title)"
    content.sound = .default
    
    // 1 Tag vor Abreise, um 9:00 Uhr
    var dateComponents = Calendar.current.dateComponents(
        [.year, .month, .day, .hour, .minute],
        from: Calendar.current.date(byAdding: .day, value: -1, to: cruise.startDate)!
    )
    dateComponents.hour = 9
    dateComponents.minute = 0
    
    let trigger = UNCalendarNotificationTrigger(
        dateMatching: dateComponents,
        repeats: false
    )
    
    let request = UNNotificationRequest(
        identifier: cruise.id.uuidString,
        content: content,
        trigger: trigger
    )
    
    UNUserNotificationCenter.current().add(request)
}
```

---

## Zukünftige APIs (Roadmap)

### Wetter-API (geplant)

```swift
// OpenWeatherMap Integration
struct WeatherService {
    func getWeather(for port: Port) async throws -> Weather
}
```

### CloudKit (geplant)

```swift
// iCloud Sync
modelContainer.configurations = [
    ModelConfiguration(cloudKitDatabase: .automatic)
]
```
