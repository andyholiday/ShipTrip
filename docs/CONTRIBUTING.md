# Contributing Guide

Danke für dein Interesse, zu ShipTrip beizutragen! 🚢

## Code of Conduct

Wir erwarten von allen Mitwirkenden ein respektvolles und professionelles Verhalten.

## Wie kann ich beitragen?

### 🐛 Bug Reports

1. Prüfe, ob der Bug bereits gemeldet wurde (Issues durchsuchen)
2. Erstelle ein neues Issue mit:
   - Klarer Beschreibung des Problems
   - Schritte zur Reproduktion
   - Erwartetes vs. tatsächliches Verhalten
   - iOS-Version und Gerät
   - Screenshots (wenn hilfreich)

### 💡 Feature Requests

1. Prüfe, ob das Feature bereits vorgeschlagen wurde
2. Erstelle ein Issue mit dem Label "enhancement"
3. Beschreibe:
   - Das gewünschte Feature
   - Den Anwendungsfall
   - Mögliche Implementierungsideen

### 🔧 Pull Requests

1. Fork das Repository
2. Erstelle einen Feature-Branch: `git checkout -b feature/mein-feature`
3. Implementiere deine Änderungen
4. Committe mit aussagekräftigen Messages
5. Push und erstelle einen PR

## Entwicklungsrichtlinien

### Git Workflow

```bash
# Fork klonen
git clone https://github.com/DEIN-USERNAME/ShipTrip.git

# Upstream hinzufügen
git remote add upstream https://github.com/andyholiday/ShipTrip.git

# Feature-Branch erstellen
git checkout -b feature/mein-feature

# Änderungen committen
git add .
git commit -m "✨ Add: Mein neues Feature"

# Vor PR: Upstream synchronisieren
git fetch upstream
git rebase upstream/main

# Push
git push origin feature/mein-feature
```

### Commit Messages

Wir verwenden Gitmoji für Commit-Messages:

| Emoji | Code | Bedeutung |
|-------|------|-----------|
| ✨ | `:sparkles:` | Neues Feature |
| 🐛 | `:bug:` | Bugfix |
| 📝 | `:memo:` | Dokumentation |
| 🎨 | `:art:` | Code-Struktur/Format |
| ⚡ | `:zap:` | Performance |
| 🔧 | `:wrench:` | Konfiguration |
| ♻️ | `:recycle:` | Refactoring |
| 🗑️ | `:wastebasket:` | Code entfernen |
| 🚀 | `:rocket:` | Release |

**Format:**
```
<emoji> <type>: <description>

[optional body]

[optional footer]
```

**Beispiele:**
```
✨ Add: Port weather display
🐛 Fix: Map zoom not working correctly
📝 Update: README with new features
```

### Code Style

#### Swift

- SwiftLint-Regeln beachten (wenn konfiguriert)
- 4 Spaces Indentation
- Camel Case für Variablen und Funktionen
- Pascal Case für Typen

#### SwiftUI

```swift
// ✅ Gut
struct MyView: View {
    @State private var isLoading = false
    
    var body: some View {
        VStack {
            // Content
        }
    }
}

// ❌ Vermeiden
struct my_view: View {
    @State var isLoading = false  // private fehlt
    var body: some View {
        VStack{  // Space vor { fehlt
        }
    }
}
```

#### Dokumentation

```swift
/// Beschreibung der Funktion
/// - Parameters:
///   - param1: Beschreibung des Parameters
///   - param2: Beschreibung des Parameters
/// - Returns: Beschreibung des Rückgabewerts
/// - Throws: Beschreibung der möglichen Fehler
func myFunction(param1: String, param2: Int) throws -> Bool {
    // ...
}
```

### Dateiorganisation

```
Views/
├── FeatureName/
│   ├── FeatureNameView.swift       # Hauptview
│   ├── FeatureNameDetailView.swift # Detailansicht
│   └── FeatureNameFormView.swift   # Formular
```

### Testing

Zwei Frameworks, klar getrennt:

| Ziel | Framework | Ordner |
|------|-----------|--------|
| Unit-Tests | Swift Testing (`import Testing`, `@Test`, `#expect`) | `ShipTripTests/` |
| UI-Tests | XCTest (`XCTestCase`, `XCUIApplication`) | `ShipTripUITests/` |

Neue Unit-Tests werden ausschließlich mit Swift Testing geschrieben; in
`ShipTripTests/` gibt es kein `XCTestCase` mehr. UI-Tests bleiben bei XCTest,
weil `XCUIApplication` nur dort verfügbar ist.

#### Unit Tests (Swift Testing)

```swift
import Testing
import Foundation
@testable import ShipTrip

@Test
func kreuzfahrtDauerZaehltStartUndEndtag() {
    let start = Date(timeIntervalSince1970: 0)
    let cruise = Cruise(
        title: "Mittelmeer",
        startDate: start,
        endDate: start.addingTimeInterval(6 * 24 * 60 * 60),
        shippingLine: "AIDA Cruises",
        ship: "AIDAnova"
    )
    #expect(cruise.duration == 7)
}
```

Tests gegen SwiftData bauen einen eigenen In-Memory-Container
(`ModelConfiguration(isStoredInMemoryOnly: true)`) — nie den App-Container.

#### UI Tests (XCTest)

```swift
import XCTest

final class CruiseListUITests: XCTestCase {
    @MainActor
    func testAddNewCruise() {
        let app = XCUIApplication()
        app.launch()

        app.buttons["addCruise"].tap()
        // ...
    }
}
```

Für reproduzierbare Daten startet die App im UI-Test mit dem Launch-Argument
`-uiTestingResetAndLoadDemoData` (nur in Debug-Builds ausgewertet).

#### Build & Test ausführen

Bevorzugt über die Xcode-MCP-Tools (`BuildProject`, `RunAllTests`), alternativ
über die Kommandozeile:

```bash
# Build
xcodebuild -scheme ShipTrip build

# Alle Tests
xcodebuild -scheme ShipTrip test
```

Test-Builds laufen strikt seriell. Vor einem Release-Lauf empfiehlt sich ein
sauberer Ausgangszustand (`xcodebuild clean`, DerivedData leeren,
`xcrun simctl --set testing delete all`).

## Review-Prozess

1. Automatische Checks (wenn konfiguriert)
2. Code Review durch Maintainer
3. Feedback einarbeiten
4. Approval und Merge

### Review-Kriterien

- [ ] Code folgt den Style-Guidelines
- [ ] Änderungen sind dokumentiert
- [ ] Tests sind vorhanden (wenn sinnvoll)
- [ ] Keine Breaking Changes ohne Absprache
- [ ] PR-Beschreibung ist aussagekräftig

## Fragen?

Bei Fragen oder Problemen:
- Issue erstellen
- Discussion starten

---

Danke für deinen Beitrag! 🙏
