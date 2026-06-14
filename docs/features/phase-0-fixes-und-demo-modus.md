# Phase 0 — Fixes und Demo-Modus

**Status:** Abgeschlossen  
**Testsuite:** 17/17 Unit-Tests + 3 UI-Tests gruen, Build verifiziert  
**Datum:** 2026-06-14

## Beschreibung

Phase 0 schliesst die Luecken zwischen dem urspruenglichen v1.4.1-Release und einem
produktionsreifen Fundament: Benachrichtigungen wurden erstmals wirklich verdrahtet,
stiller Datenverlust beim Import wurde sichtbar gemacht, zwei tote Code-Pfade wurden
entfernt, Debug-Logs wurden bereinigt und eine isolierte Demo-Daten-Infrastruktur
(nur im Debug-Build sichtbar) wurde eingefuehrt. Abgerundet wird Phase 0 durch ein
Test-Grundgeruest mit Swift Testing (17 Unit-Tests), das als Sicherheitsnetz fuer alle
weiteren Phasen dient.

---

## Fix 1 — Benachrichtigungen tatsaechlich verdrahtet

### Was / Warum

`NotificationService` existierte bereits, wurde aber nie korrekt aufgerufen. Die
zentrale Ursache: `scheduleAllReminders` versuchte, ein `@Model`-Objekt ueber
Swift-Concurrency-Aktorgrenzen zu uebergeben, was zu Compiler-Fehlern und
Laufzeit-Crashes fuehrte.

Loesungsansatz:

- `scheduleAllReminders(cruiseID:title:startDate:)` nimmt jetzt reine Werttypen
  statt eines `@Model`-Objekts — keine Aktogrenzprobleme mehr.
- Die Methode liest `notifyBeforeCruise`, `notifyOnCruiseDay` und
  `reminderDaysBefore` aus `UserDefaults` und plant nur die gewuenschten
  Benachrichtigungen.
- `removeReminders(for:)` entfernt alle Pending-Requests mit dem Praefix
  `cruise-<id>-` und ist dadurch robust gegen wechselnde `reminderDaysBefore`-Werte
  (kein Rucksack alter Requests).
- `CruiseFormView.saveCruise()` ruft erst `removeReminders`, dann
  `scheduleAllReminders` — sowohl beim Anlegen als auch beim Bearbeiten.
- `saveCruise()` faengt Speicherfehler ab und zeigt einen Alert; bei Fehler wird
  weder geplant noch geschlossen.
- `CruiseDetailView.deleteCruise()` und `CruiseListView.deleteCruises()` rufen
  `removeReminders` vor dem Loeschen auf.

### Beruerhrte Dateien

- `ShipTrip/Services/NotificationService.swift`
- `ShipTrip/Views/Cruises/CruiseFormView.swift`
- `ShipTrip/Views/Cruises/CruiseDetailView.swift`
- `ShipTrip/Views/Cruises/CruiseListView.swift`

### Acceptance-Status

Verifiziert durch manuellen Test (Notification-Entitlement im Unit-Test-Host nicht
verfuegbar — siehe Bekannte Einschraenkungen).

---

## Fix 2 — Debug-Logs entfernt (Privacy)

### Was / Warum

Drei `print("DEBUG: …")`-Aufrufe loggten im Release-Build sensible Daten
(API-Antworten, Formulardaten) in die Konsole.

- 2 Aufrufe in `GeminiService.swift`
- 1 Aufruf in `CruiseFormView.swift`

Alle drei wurden entfernt.

### Beruerhrte Dateien

- `ShipTrip/Services/GeminiService.swift`
- `ShipTrip/Views/Cruises/CruiseFormView.swift`

### Acceptance-Status

Geprueft per Code-Review (keine `print("DEBUG:` mehr in den genannten Dateien).

---

## Fix 3 — Stiller Import-Datenverlust behoben

### Was / Warum

`ExportImportService` uebersprang Kreuzfahrten mit unparsebarern Daten lautlos;
der Nutzer sah keine Fehlermeldung, Daten verschwanden einfach.

Aenderungen:

- `importCruises` liefert jetzt `ImportResult { imported, skippedDuplicates, skippedInvalid }`.
- Uebersprungs-Gruende: nicht parsierbares Datum **oder** `endDate < startDate`.
- `DataManagementView` (in `SettingsView`) zeigt nach dem Import einen Alert mit
  den Zahlen aller drei Kategorien.

### Beruerhrte Dateien

- `ShipTrip/Services/ExportImportService.swift`
- `ShipTrip/Views/Settings/SettingsView.swift`

### Acceptance-Status

Durch Unit-Test `testImportSkipsInvalidDates` und `testImportSkipsInvertedDates`
abgedeckt (17/17 gruen).

---

## Fix 4 — Enddatum-Validierung

### Was / Warum

Ohne serverseitige Validierung konnte der KI-Import-Pfad Kreuzfahrten mit
`endDate < startDate` anlegen. `CruiseFormView.saveCruise()` prueft jetzt explizit
`endDate >= startDate` und zeigt andernfalls einen Validierungs-Alert.

### Beruerhrte Dateien

- `ShipTrip/Views/Cruises/CruiseFormView.swift`

### Acceptance-Status

Durch Unit-Test `testImportSkipsInvertedDates` abgedeckt.

---

## Fix 5 — Tote Settings und GitHub-Link

### Was / Warum

- Der GitHub-Link in `SettingsView` zeigte auf einen Placeholder-URL; korrigiert
  auf `https://github.com/andyholiday/ShipTrip`.
- `DeveloperSettingsView` war unerreichbar (das 5-Tap-Easter-Egg war auskommentiert)
  und enthielt veraltete Toggle-States. Beide Artefakte wurden entfernt.

### Beruerhrte Dateien

- `ShipTrip/Views/Settings/SettingsView.swift`

### Acceptance-Status

Geprueft per Code-Review und manuellem Test des Links.

---

## Feature — Demo-Modus (nur Debug-Build)

### Was / Warum

Fuer Praesentation und Onboarding ist es nuetzlich, reale Beispieldaten laden und
wieder sauber entfernen zu koennen, ohne Produktionsdaten zu beruehren.

Implementierung:

- `ShipTrip/Services/DemoDataService.swift` ist vollstaendig in `#if DEBUG`
  eingekapselt.
- Der Service laedt 3 Kreuzfahrten (past/upcoming) und 2 Angebote, die jeweils
  mit `isDemo = true` getaggt sind.
- `removeDemoData()` loescht via SwiftData-Cascade; `isDemoDataLoaded` prueft den
  Zustand.
- In `SettingsView` erscheint eine "Demo-Daten"-Sektion nur in Debug-Builds
  (`#if DEBUG`).
- Das `isDemo`-Feld ist **ohne** `#if DEBUG` im Modell definiert (siehe Bekannte
  Einschraenkungen, Punkt b).

### Beruerhrte Dateien

- `ShipTrip/Services/DemoDataService.swift` (neu)
- `ShipTrip/Models/Cruise.swift` (Feld `isDemo`)
- `ShipTrip/Models/Deal.swift` (Feld `isDemo`)
- `ShipTrip/Views/Settings/SettingsView.swift`

### Acceptance-Status

Manuell verifiziert; kein dedizierter Unit-Test fuer den Service selbst (SwiftData
in-memory-Setup waere noetig — als Folgeaufgabe notiert).

---

## Feature — Test-Grundgeruest

### Was / Warum

Vor Phase 0 gab es keine automatisierten Tests. Als Sicherheitsnetz fuer alle
weiteren Phasen wurde ein Swift-Testing-Grundgeruest eingefuehrt.

17 Unit-Tests in `ShipTripTests/ShipTripTests.swift`:

- `Cruise.duration`
- `Deal.discountPercent` und `Deal.savings`
- `Expense`-Modell
- `PortSuggestion.findBestMatch`
- Export-/Import-Roundtrip inkl. Skip-Accounting fuer invalid und invertiertes Datum
- Notification-Praefix-Filter-Logik

3 UI-Tests in `ShipTripUITests/`.

### Beruerhrte Dateien

- `ShipTripTests/ShipTripTests.swift`
- `ShipTripUITests/ShipTripUITests.swift`
- `ShipTripUITests/ShipTripUITestsLaunchTests.swift`

### Acceptance-Status

17/17 Unit-Tests + 3 UI-Tests gruen.

---

## Bekannte Einschraenkungen / Offene Punkte

**(a) Benachrichtigungs-Firing nicht automatisiert pruefbar**
Das echte Feuern von Benachrichtigungen laesst sich im Unit-Test-Host nicht
verifizieren: `pendingNotificationRequests` liefert dort leer, da das
Notification-Entitlement fehlt. Die Scheduling-Logik muss manuell oder per
dediziertem UI-Test geprueft werden.

**(b) `isDemo`-Feld im Release-Schema vorhanden (bewusste Entscheidung)**
`isDemo` ist als regulaeres SwiftData-Attribut definiert (kein `#if DEBUG`). Im
Release ist das Feld immer `false` und harmlos. Ein build-config-abhaengiges
Schema waere fragiler (Migration zwischen Debug- und Release-Build) und wuerde mit
dem geplanten CloudKit-Schema in Phase 1 kollidieren. Nur der Demo-Schalter und
der Service-Code sind Debug-only. Diese Entscheidung sollte in Phase 1 als ADR
formalisiert werden.

**(c) Erfolgs-`print` in NotificationService.swift Zeile 77**
Ein vorbestehender `print`-Aufruf loggt den Reisetitel auch im Release-Build.
Er liegt ausserhalb des Phase-0-Scopes und wurde bewusst nicht angefasst;
als Kleinkram fuer Phase 1 notiert.

**(d) Kein ADR vorhanden**
Es existiert noch kein ADR-Verzeichnis. Die Entscheidung zu `isDemo` und
CloudKit-Schema-Kompatibilitaet (Punkt b) sollte in Phase 1 unter
`docs/adr/` als erstes ADR formalisiert werden.

---

## Verwandte Entscheidungen

Kein ADR verknuepft. Siehe Punkt (d) oben — ADR fuer `isDemo`/CloudKit-Schema
steht in Phase 1 aus.
