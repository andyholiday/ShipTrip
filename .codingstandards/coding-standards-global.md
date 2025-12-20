# Global Coding Standards

Diese Standards gelten für ALLE Projekte.

---

## 📝 Git Commits (Conventional Commits)

```
feat:     Neues Feature
fix:      Bugfix
docs:     Dokumentation
refactor: Code-Refactoring
perf:     Performance-Verbesserung
style:    Formatierung
test:     Tests
chore:    Build, Dependencies
```

**Format:** `<type>(<scope>): <description>`

---

## 💻 Namenskonventionen

| Element | Konvention | Beispiel |
|---------|------------|----------|
| Dateien (Komponenten) | PascalCase | `CruiseCard.tsx` |
| Dateien (Utils) | camelCase | `formatDate.ts` |
| Konstanten | UPPER_SNAKE | `API_BASE_URL` |
| CSS Klassen | kebab-case | `cruise-card--active` |
| Types/Interfaces | PascalCase | `CruiseData` |

---

## 🔐 Sicherheit (Pflicht)

### Secrets
- **Niemals** Secrets im Code oder Git
- Environment Variables für sensitive Daten
- `.env.example` für Dokumentation

### SQL Injection Prevention
```typescript
// ✅ Prepared Statements
db.query('SELECT * FROM users WHERE id = ?', [userId]);

// ❌ String Concatenation
db.query(`SELECT * FROM users WHERE id = ${userId}`);
```

### Input-Validierung
- Server-seitig mit Zod validieren
- Niemals User-Input vertrauen

---

## 📊 Performance

- Lazy Loading für große Komponenten
- Bilder: WebP Format, responsive Sizes
- Pagination: Max. 50 Items pro Request
- Caching für häufige API-Calls

---

## 🧪 Testing (Grundprinzipien)

### Arrange-Act-Assert Pattern
```
1. Arrange: Testdaten und Mocks vorbereiten
2. Act: Funktion ausführen
3. Assert: Ergebnis prüfen
```

### Was muss getestet werden?
| Bereich | Priorität |
|---------|-----------|
| Business-Logik | 🔴 Pflicht |
| API-Services | 🔴 Pflicht |
| Validierung | 🔴 Pflicht |
| UI-Komponenten mit Logik | 🟡 Empfohlen |
| Reine UI ohne Logik | 🟢 Optional |

### Coverage-Ziele
- Minimum: **70%** für kritische Pfade
- Ziel: **80%** für Kernfunktionen

---

## ✅ Zusammenfassung

| Regel | Priorität |
|-------|-----------|
| Keine Secrets im Code | 🔴 Kritisch |
| Prepared Statements | 🔴 Kritisch |
| Input-Validierung | 🔴 Kritisch |
| Tests für Business-Logik | 🔴 Kritisch |
| Conventional Commits | 🟡 Wichtig |
| 70% Test Coverage | 🟡 Wichtig |

---

*Version: 1.1 | Dezember 2025*

