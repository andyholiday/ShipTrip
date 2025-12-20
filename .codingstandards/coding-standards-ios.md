# iOS App Coding Standards (Swift + SwiftUI)

Ergänzend zu: `coding-standards-global.md`

---

## 📱 Apple Human Interface Guidelines

### Design-Prinzipien
1. **Clarity** – Lesbare Schrift (min. 17pt Body), hoher Kontrast
2. **Deference** – Inhalte im Vordergrund, subtiles Chrome
3. **Depth** – Schatten, Blur-Effekte, realistische Animation

### Touch Targets
- Minimum: **44x44pt** für alle interaktiven Elemente
- Empfohlen: 48x48pt für primäre Actions

### Spacing
- 8pt Grid-System (8, 16, 24, 32, 48pt)
- Safe Areas respektieren (Notch, Home Indicator)

---

## 🔤 Swift Coding Conventions

### Namenskonventionen

| Element | Konvention | Beispiel |
|---------|------------|----------|
| Typen | PascalCase | `CruiseViewModel` |
| Funktionen | camelCase | `fetchCruises()` |
| Variablen | camelCase | `isLoading` |
| Konstanten | camelCase | `maxRetryCount` |
| Enums | PascalCase + case camelCase | `BookingStatus.confirmed` |

### Optionals

```swift
// ✅ Guard für Early Exit
guard let cruise = selectedCruise else { return }

// ✅ Optional Chaining
let title = cruise.route.first?.portName

// ❌ Force Unwrap vermeiden
let title = cruise.route.first!.portName  // Crash-Gefahr!
```

### Closures

```swift
// Trailing Closure Syntax
cruises.filter { $0.isUpcoming }

// Explizit bei Komplexität
cruises.filter { cruise in
    cruise.startDate > Date() && cruise.rating >= 4
}
```

---

## 🏗️ Architektur (MVVM)

```
App/
├── Models/           # Datenstrukturen
│   └── Cruise.swift
├── Views/            # SwiftUI Views
│   ├── CruiseListView.swift
│   └── CruiseDetailView.swift
├── ViewModels/       # Business Logic
│   └── CruiseViewModel.swift
├── Services/         # API, Persistence
│   ├── APIService.swift
│   └── PersistenceService.swift
└── Utilities/        # Helper, Extensions
```

### ViewModel Pattern

```swift
@MainActor
class CruiseViewModel: ObservableObject {
    @Published var cruises: [Cruise] = []
    @Published var isLoading = false
    @Published var error: Error?
    
    private let apiService: APIServiceProtocol
    
    func fetchCruises() async {
        isLoading = true
        defer { isLoading = false }
        
        do {
            cruises = try await apiService.getCruises()
        } catch {
            self.error = error
        }
    }
}
```

---

## 🎨 SwiftUI Best Practices

### View-Größe begrenzen
- Max. 100 Zeilen pro View
- Komplexe Views in Subviews extrahieren

```swift
// ✅ Extrahieren
struct CruiseListView: View {
    var body: some View {
        List(cruises) { cruise in
            CruiseRowView(cruise: cruise)
        }
    }
}

struct CruiseRowView: View {
    let cruise: Cruise
    var body: some View { ... }
}
```

### State Management

| Property Wrapper | Verwendung |
|-----------------|------------|
| `@State` | View-lokaler, einfacher State |
| `@Binding` | Zwei-Wege-Verbindung zu Parent |
| `@StateObject` | ViewModel-Instanz erstellen |
| `@ObservedObject` | ViewModel von außen erhalten |
| `@EnvironmentObject` | App-weiter State |

### Async/Await

```swift
.task {
    await viewModel.fetchCruises()
}

.refreshable {
    await viewModel.refreshCruises()
}
```

---

## 🔐 Sicherheit

### Keychain für Secrets
```swift
// ✅ Keychain für sensitive Daten
KeychainService.save(token, forKey: "authToken")

// ❌ UserDefaults für Secrets
UserDefaults.standard.set(token, forKey: "authToken")
```

### App Transport Security
- HTTPS für alle Verbindungen
- Ausnahmen nur mit Begründung

---

## 🧪 Testing

### Unit Tests
```swift
func testCruiseFiltering() async {
    // Arrange
    let viewModel = CruiseViewModel(apiService: MockAPIService())
    
    // Act
    await viewModel.fetchCruises()
    let upcoming = viewModel.upcomingCruises
    
    // Assert
    XCTAssertFalse(upcoming.isEmpty)
}
```

### UI Tests (XCTest)
```swift
func testNavigationToCruiseDetail() {
    let app = XCUIApplication()
    app.launch()
    
    app.cells["cruise-cell-0"].tap()
    
    XCTAssertTrue(app.navigationBars["Cruise Detail"].exists)
}
```

---

## 📦 Dependencies

### Swift Package Manager bevorzugen
- `Package.swift` für Abhängigkeiten
- CocoaPods/Carthage nur wenn nötig

### Empfohlene Libraries
| Zweck | Library |
|-------|---------|
| Networking | URLSession (native) |
| JSON | Codable (native) |
| Images | AsyncImage, Kingfisher |
| Analytics | Firebase Analytics |

---

## ♿ Accessibility

```swift
Image(systemName: "star.fill")
    .accessibilityLabel("Bewertung: 5 Sterne")

Button("Buchen") { ... }
    .accessibilityHint("Öffnet das Buchungsformular")
```

- VoiceOver testen
- Dynamic Type unterstützen
- Reduced Motion respektieren

---

*Version: 1.0 | Dezember 2025*
