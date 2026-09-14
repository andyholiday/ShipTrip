# Audit-Verifikation v1 — Cruise-UI (Bezug: Audit 2026-07-10, Commit 687657c)

Read-only Verifikation, Stand heute (Zeilennummern gegen HEAD geprüft, nicht blind vom Audit übernommen).

## H1 — Filter ohne Treffer = UX-Dead-End

**Urteil: CONFIRMED**

`CruiseListView.swift:79-105` (body):
```
NavigationStack(path: $navigationPath) {
    Group {
        if cruises.isEmpty { emptyStateView }
        else if filteredCruises.isEmpty { ContentUnavailableView("Keine Treffer", ...) }
        else { cruiseList }
    }
    .toolbar(.hidden, for: .navigationBar)
    ...
}
```
- Der Filter-Button (`filterMenu`) lebt ausschließlich in `topActions`, das nur innerhalb von `cruiseList` gerendert wird (`cruiseList` Zeile 109-170, `topActions` 172-192, `filterMenu` 252-309). Sobald `filteredCruises.isEmpty` (z. B. Jahr+Reederei-Kombination ohne Treffer), wird stattdessen die bare `ContentUnavailableView` (Zeile 85) gerendert — ohne Actions-Closure, also ohne Reset-Button.
- Navigationbar ist für den kompletten Stack per `.toolbar(.hidden, for: .navigationBar)` (Zeile 90) ausgeblendet — unabhängig vom Branch. Kein Zurück/Reset über die Bar möglich.
- Kein `.refreshable` im gesamten File → Pull-to-Refresh existiert nicht als Reset-Weg.
- Tab-Wechsel resettet nichts: `MainTabView.swift:23-54` verwendet ein statisches `TabView(selection:)` mit `CruiseListView()` einmalig instanziiert (Zeile 25) und festen `.tag()`-Werten. Standard-SwiftUI-Verhalten: `@State` (hier `selectedYear`/`selectedShippingLine`) bleibt beim Tab-Wechsel erhalten, die View wird nicht neu erzeugt.
- Ergebnis: Ist man einmal auf einer leeren Filterkombination gelandet, gibt es **keinen** Reset-Weg auf dem Screen selbst. Einziger Ausweg: App neu starten (State verloren) oder zufällig eine Cruise löschen/hinzufügen, die das Match-Set wieder füllt.

**Fix-Hinweis:** `ContentUnavailableView` braucht eine `actions:`-Closure mit "Filter zurücksetzen" (dieselbe Logik wie `filterMenu`'s Reset-Button, Zeile 296-299), ODER `topActions`/`filterMenu` aus `cruiseList` herauslösen und immer sichtbar halten (dann greift auch `.toolbar(.hidden)` erneut zu prüfen). Keine bestehenden Tests berühren das (kein UI-Test für Filter-Empty-State gefunden); ein neuer UI-Test wäre sinnvoll.

---

## H2 — Manuelle Hafen-Eingabe verschwindet nach erstem Zeichen

**Urteil: CONFIRMED — exakt wie im Audit, sogar zugespitzt**

`PortFormView.swift:122-135`:
```swift
if name.isEmpty {
    Section("Manuell eingeben") {
        TextField("Hafenname", text: $name)
        TextField("Land", text: $country)
        HStack {
            TextField("Breitengrad", text: $latitude)...
            TextField("Längengrad", text: $longitude)...
        }
    }
}
```
- Die Bedingung `if name.isEmpty` umschließt **die TextField, die selbst an `$name` bindet**. Sobald der Nutzer das erste Zeichen in "Hafenname" tippt, wird `name` non-empty → beim nächsten Re-Render verschwindet die gesamte Section samt der gerade benutzten TextField. Das ist kein rein theoretischer Edge-Case, sondern der Standardpfad für jede manuelle Eingabe.
- Bestandsdaten (`loadExistingData()`, Zeile 192-207): `name = port.name` (Zeile 199) wird immer vor dem ersten Render gesetzt, wenn `port != nil`. D. h. ein bestehender Port mit gesetztem Namen zeigt die manuelle Section **nie** — nur die Zusammenfassung (Zeile 101-119) mit einem "X"-Button (`clearSelection()`, Zeile 111-116/183-190), der Name/Land/Lat/Long komplett auf `""` zurücksetzt. Korrektur eines bestehenden Ports (z. B. Tippfehler im Namen) ist über die UI nicht möglich, ohne erst alle Felder zu leeren und dann entweder eine Suggestion zu wählen oder erneut in den Ein-Zeichen-Verschwinde-Bug zu laufen.
- Gleiches Muster in `CruiseFormView.swift`'s eingebettetem `TempPortFormSheet`: dort ist "Details"-Section (Zeile 1055-1059, Name/Land) **nicht** conditional — kein Verschwinde-Bug dort. Das ist eine weitere Divergenz zwischen den zwei Editoren (siehe M5).

**Fix-Hinweis:** Bedingung muss vom Editier-/Eingabe-Modus abhängen (z. B. eigenes `@State private var isManualEntry` statt `name.isEmpty`), nicht vom aktuellen Inhalt des Felds, das selbst editiert wird. Betrifft keine vorhandenen Tests (kein Test für PortFormView-Manual-Entry gefunden in `ShipTripTests/`/`ShipTripUITests/`); Fix sollte einen Regressionstest bekommen (State bleibt nach erstem Zeichen erhalten).

---

## H5 — Reise-Löschung ohne Bestätigung in Hauptansicht

**Urteil: CONFIRMED**

- `CruiseListView.swift:141-147` (Hero-Card-Kontextmenü): `Button(role: .destructive) { deleteCruise(hero) }` — kein Alert, kein Dialog dazwischen.
- `CruiseListView.swift:220-226` (Timeline-Card-Kontextmenü): identisch, `deleteCruise(cruise)` direkt.
- `CruiseListView.swift:317-322` (`deleteCruise`-Funktion):
```swift
private func deleteCruise(_ cruise: Cruise) {
    let cruiseID = String(describing: cruise.persistentModelID)
    Task { await NotificationService.shared.removeReminders(cruiseID: cruiseID) }
    modelContext.delete(cruise)
}
```
  Die Notification-Entfernung läuft als **losgelöster** `Task` (fire-and-forget) parallel zum sofortigen, synchronen `modelContext.delete(cruise)` direkt danach — nicht awaited, keine Fehlerbehandlung, kein Rollback falls das Löschen fehlschlägt oder der Task nicht rechtzeitig fertig wird.
- Im Vergleich `CruiseDetailView.swift:98-105`: dort gibt es einen echten `.alert("Kreuzfahrt löschen?", ...)` mit Cancel/Destructive-Buttons, der erst nach Bestätigung `deleteCruise()` aufruft — also inkonsistent zur Liste.

**Fix-Hinweis:** Beide Context-Menü-Buttons in `CruiseListView.swift` brauchen denselben Bestätigungs-Mechanismus wie `CruiseDetailView` (`confirmationDialog`/`.alert`, State pro Card oder ein gemeinsames `@State private var cruiseToDelete: Cruise?`). Reihenfolge in `deleteCruise()` sollte Notification-Removal vor dem `modelContext.delete` awaiten (oder zumindest dokumentiert bewusst fire-and-forget lassen, aktuell ist es unkommentiert). Kein bestehender Test deckt Lösch-Pfade in `CruiseListView` ab (grep in `ShipTripUITests/` ergab keinen Treffer für `deleteCruise`/Kontextmenü-Löschen dort); neuer Test nötig.

---

## M5 — Zwei Hafen-Editoren mit widersprüchlicher Validierung

**Urteil: CONFIRMED (beide Teilclaims)**

**Teil 1 — Dezimalkomma → 0/0 (PortFormView):**
`PortFormView.swift:128-133` (Eingabe, `.decimalPad`) + `savePort()` Zeile 234-235:
```swift
let lat = Double(latitude) ?? 0
let lon = Double(longitude) ?? 0
```
`Double.init?(String)` erwartet zwingend `.` als Dezimaltrennzeichen, unabhängig von Gerätesprache/Locale. Tippt ein deutscher Nutzer `52,52` (üblich bei `.decimalPad` + de-Locale-Tastatur), liefert `Double("52,52")` `nil` → stiller Fallback auf `0`. Keine Validierung, kein Fehlerhinweis — der Port bekommt Koordinaten `(0,0)`, was auf der Karte fälschlich am Nullmeridian/Äquator landen würde.

**Teil 2 — Abfahrt vor Ankunft möglich (CruiseFormView/TempPortFormSheet):**
- `PortFormView.swift:139-140` (Standalone-Editor) **verhindert** das bereits: `DatePicker("Abfahrt", selection: $departure, in: arrival...)` — Range-Constraint vorhanden.
- `CruiseFormView.swift:1062-1064` (eingebetteter Editor, `struct TempPortFormSheet`, Zeile 990):
```swift
Section("Zeiten") {
    DatePicker("Ankunft", selection: $arrivalDate)
    DatePicker("Abfahrt", selection: $departureDate)
}
```
  Kein `in:`-Constraint. `savePort()` (Zeile 1131-1166) validiert Datumsreihenfolge an keiner Stelle. Ein Hafen kann hier mit Abfahrt vor Ankunft gespeichert werden — im anderen Editor (`PortFormView`) strukturell unmöglich. Bestätigt exakt die im Audit behauptete Inkonsistenz zwischen den zwei Editoren.

**Fix-Hinweis:** (1) Lat/Long-Parsing braucht einen locale-toleranten Parser (z. B. `NumberFormatter` mit `decimalSeparator`-Fallback oder manuelles Komma→Punkt-Replace vor `Double(...)`) plus sichtbares Validierungsfeedback statt stillem `0`-Fallback — betrifft beide Editoren identisch (gleiches Pattern vermutlich auch in `CruiseFormView`'s `TempPortFormSheet`, falls dort ebenfalls Lat/Long-Text-Parsing existiert — hier nicht separat verifiziert, da `TempPortFormSheet` keine Lat/Long-TextFields hat, sondern nur `PortSuggestion.findBestMatch`). (2) `TempPortFormSheet` braucht denselben `in: arrivalDate...`-Constraint wie `PortFormView`. Kein bestehender Test deckt Datums- oder Koordinaten-Validierung ab (keine Treffer in `ShipTripTests/` für "arrival"/"departure"-Validierung oder Lat/Long-Parsing gefunden).

---

## L3 — Datei-Größen & Duplikation

**Urteil: CONFIRMED**

`wc -l` (heute):
| Datei | Zeilen | Audit-Angabe |
|---|---|---|
| `CruiseFormView.swift` | 1488 | 1.488 ✓ exakt |
| `PortFormView.swift` | 487 | 487 ✓ exakt |
| `SettingsView.swift` | 660 | 660 ✓ exakt |

**Konkret duplizierte Blöcke** (fast wortgleich, gleiche Kommentare/Doc-Strings):
- `hafenMomenteSection` + `excursionSuggestions` + `coverPhotoTile` + `excursionChipScroller` + `excursionList` + `excursionRow` + `excursionDeleteButton` + `excursionMoveButtons` + `excursionReorderToggle` + `addExcursionRow`:
  `PortFormView.swift:282-472` (≈191 Zeilen) vs. `CruiseFormView.swift:1175-1367` (≈193 Zeilen, innerhalb `struct TempPortFormSheet`, deklariert Zeile 990) — Code inkl. Kommentare (z. B. "Gesten-Konflikt vermeiden...", "B7.1/A2 (Gate #2 Fix, Plan B)...") ist Zeile für Zeile identisch kopiert.
- `addExcursion()` / `addExcursion(_:)`: `PortFormView.swift:209-220` vs. `CruiseFormView.swift:1107-1118` — identisch.
- `loadImage(from:)`: `PortFormView.swift:222-231` vs. `CruiseFormView.swift:1120-1129` — identisch (inkl. `try?`-Silent-Fail, siehe L4).

Das sind zusammen ~200+ Zeilen 1:1-Duplikat zwischen den beiden Dateien — bestätigt den Audit-Claim präzise, nicht nur pauschal.

**Fix-Hinweis:** Extraktion in eine gemeinsame `HafenMomenteSection`-View (nimmt `Binding<Data?>`, `Binding<[String]>` etc. als Parameter) würde beide Duplikate auf einen Call-Site reduzieren. Risiko: `TempPortFormSheet` arbeitet mit `TempPort`/lokalem State (kein SwiftData-Objekt), `PortFormView` mit echtem `Port`-Model — Extraktion muss modellagnostisch bleiben (nur auf Bindings arbeiten, wie es faktisch schon tut). Kein Testverlust zu erwarten, da beide Blöcke aktuell ohnehin nicht separat getestet sind (kein Treffer für `hafenMomenteSection`/`excursionRow` in Tests).

---

## L4 — Kleine UX-Lücken

**1. Foto-Ladefehler unsichtbar — CONFIRMED**
`PortFormView.swift:222-231` und identisch `CruiseFormView.swift:1120-1129`:
```swift
private func loadImage(from item: PhotosPickerItem?) {
    guard let item else { return }
    Task {
        if let data = try? await item.loadTransferable(type: Data.self) {
            await MainActor.run { imageData = data }
        }
    }
}
```
`try?` schluckt jeden Fehler; im `else`-Fall (keine Zeile vorhanden) passiert nichts — kein Alert, kein Log, kein State-Flag. Nutzer sieht nur, dass sich nichts tut.

**2. Bewertung nicht auf "unbewertet" zurücksetzbar — CONFIRMED**
`CruiseFormView.swift:1458-1483` (`RatingInputView`):
```swift
ForEach(1...5, id: \.self) { star in
    Button { rating = Double(star) } label: { ... }
}
```
Die Sterne-Range ist `1...5`; der niedrigste über die UI erreichbare Wert ist `1`. Es gibt keinen Button/keine Geste, um `rating` zurück auf `0` ("unbewertet") zu setzen, sobald einmal bewertet wurde.

**3. Port-Zero-States auf langen Routen — nur Code-Indiz, visuell UNVERIFIABLE**
Zero-State-Logik existiert konkret in `ShipTrip/Views/Cruises/PortMemoryCard.swift` (Doc-Kommentare Zeile 137, 144-146: "`true`, wenn die Hero-Fläche den Zero-State zeigt..."). Das bestätigt, dass die Komponente einen dedizierten Zero-State-Rendering-Pfad hat — ob dieser auf langen Routen tatsächlich "groß/kontrastarm" wirkt, ist eine Rendering-Frage und ohne Simulator/Screenshot nicht zu verifizieren. Kein Urteil möglich, nur Bestätigung, dass der Code-Pfad existiert und ein Anwaltspunkt für spätere visuelle Prüfung ist.

**Fix-Hinweis:** (1) und (2) sind unabhängige, kleine Fixes: `try?` durch `do/catch` mit sichtbarem Fehler-State ersetzen (identisch an beiden Stellen — sollte zusammen mit der L3-Extraktion gemacht werden, sonst erneut dupliziert); `RatingInputView` braucht z. B. Tap-auf-bereits-aktivem-erstem-Stern → `rating = 0`, oder einen expliziten "Zurücksetzen"-Button. (3) braucht Screenshot-Review, kein Code-Fix vor Verifikation planbar.

---

## Geladene Skills
`swiftui`, `swift-standards` (SKILL.md-Referenzen konsultiert, keine Volltext-Ausführung nötig für reine Code-Verifikation)
