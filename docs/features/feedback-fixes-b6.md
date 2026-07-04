# Welle B6 — Feedback-Fixes (TestFlight 1.6.2/14)

**Status:** Abgeschlossen (B6.1, B6.3) — B6.2 Deck geliefert, Umsetzung nach Wahl (Andre/Tester)
**Testsuite:** 164/164 Unit-Tests PASS (vorher 143), 21/21 UI-Tests PASS
**Quelle:** [Umsetzungsplan Audit 2026-07](../umsetzungsplan-audit-2026-07.md#welle-b6--feedback-fixes-testflight-16214-feedback-ausflug-nicht-entfernbar-m-h-erfassungdarstellung-von-hafenfotos--ausflügen-nicht-elegant--tester-erbittet-je-3-vorschläge-m-hinweis-auf-b5-funktion-in-einstellungen-fehlt-l--quelle-interner-tester-2026-07-04-build-14-0-crashes),
interner Tester 2026-07-04 (Build 14, 0 Crashes)

## Beschreibung

Welle B6 behebt drei Feedback-Punkte aus dem internen Test der TestFlight-Version
1.6.2(14): ein Ausflug ließ sich nicht sichtbar entfernen (B6.1), Erfassung und
Darstellung von Hafenfotos/Ausflügen wirkten „nicht elegant" — der Tester bat um
je drei alternative Vorschläge statt eines direkten Fixes (B6.2), und der Hinweis
auf die in Welle B5 eingeführte Reederei-/Schiff-Verwaltung fehlte in den
Einstellungen (B6.3). Die Untersuchung von B6.1 deckte zusätzlich einen zweiten,
schwerwiegenderen Datenverlust-Bug auf, der über das gemeldete Symptom hinausging.

---

## B6.1 — Ausflug entfernen + Edit-Datenverlust-Fix

### Was / Warum

Zwei unabhängige Ursachen für „Ausflug nicht entfernbar":

- **UI-Ursache:** Die Lösch-Funktion existierte nur als versteckte Wisch-Geste
  (`.onDelete`) ohne sichtbaren Button — für Tester nicht auffindbar. Neu: ein
  sichtbarer roter `minus.circle.fill`-Button (44×44 pt Tap-Fläche via
  `.frame`/`.contentShape`, HIG-Mindestgröße) pro Ausflugs-Zeile, index-basiert
  entfernt (`excursions.remove(at: index)`), in `PortFormView` und
  `TempPortFormSheet` (`CruiseFormView.swift`).
- **Echter Datenverlust-Bug (Root Cause, über das gemeldete Symptom hinaus):**
  Der Speichern-Button in `PortFormView` war bei Häfen mit leerem Land dauerhaft
  deaktiviert (`.disabled(name.isEmpty || country.isEmpty)`). Das „Land"-Feld ist
  aber nur sichtbar, solange `name` leer ist (`PortFormView.swift:119`) — bei
  einem bestehenden Hafen mit ausgefülltem Namen ließ sich ein leeres Land also
  nie nachtragen. Über `TempPortFormSheet` angelegte Häfen haben nie ein
  Pflicht-Land erzwungen (dort galt schon immer nur `.disabled(name.isEmpty)`),
  sodass Häfen mit leerem Land regulär entstehen. Ergebnis: **jede** Bearbeitung
  eines solchen Hafens über `PortFormView` — nicht nur das Löschen eines
  Ausflugs — wurde beim Tippen auf „Speichern" stillschweigend verworfen, der
  Button blieb einfach ausgegraut. Fix: `.disabled(name.isEmpty)`, analog zu
  `TempPortFormSheet`.

### Berührte Dateien

- `ShipTrip/Views/Cruises/PortFormView.swift` — sichtbarer Lösch-Button pro
  Ausflug; `.disabled(name.isEmpty)` statt `.disabled(name.isEmpty || country.isEmpty)`
  am Speichern-Button.
- `ShipTrip/Views/Cruises/CruiseFormView.swift` (`TempPortFormSheet`) —
  identischer sichtbarer Lösch-Button pro Ausflug.

### Known Limitations

- Die neuen/geänderten user-sichtbaren Strings (u. a. „Ausflug entfernen") sind
  noch nicht in `Localizable.xcstrings` synchronisiert — der Sync passiert beim
  nächsten Öffnen/Bauen in der Xcode-IDE, nicht über CLI-`xcodebuild test`
  (bestehendes Projektverhalten, keine Regression dieser Welle).

### Acceptance-Status

Erfüllt. Ausflug anlegen → über den sichtbaren Button löschen → gespeicherte
Reise hat ihn nicht mehr, für beide Erfassungspfade (`PortFormView` und
`TempPortFormSheet`), auch bei Häfen mit leerem Land. Abgesichert durch die
Unit-Suite „Ausflug entfernen (B6.1)" (`PortFormViewTests.swift`, inkl.
Letzter-Ausflug-leer-Roundtrips für beide Pfade) sowie
`ShipTripUITests/AusflugLoeschenUITests.swift` (End-to-End über den tatsächlichen
Button-Zustand, nicht nur Modell-Ebene).

---

## B6.2 — Design-Deck „Hafen-Momente"

### Was / Warum

Statt eines direkten Fixes für „nicht elegant" bat der Tester um je drei
alternative Vorschläge für (a) den Erfassungs-Flow von Ausflug/Hafenbild und
(b) die Darstellung von Hafenfoto/Ausflügen in der Detailansicht. Geliefert als
klickbares HTML-Deck: [`docs/ux-pitch-decks/b6-hafen-momente.html`](../ux-pitch-decks/b6-hafen-momente.html),
Gemini-Gates #5a (Erfassung) und #5b (Darstellung) bestanden.

### Status

Deck geliefert, Empfehlung A2 (Erfassung) + B2 (Darstellung). Umsetzung ist
bewusst **nicht** Teil dieser Welle — Entscheidung durch Andre/Tester steht noch
aus; die gewählte Richtung wird als eigene Folgewelle umgesetzt.

---

## B6.3 — Einstellungen-Hinweis zur Reederei-/Schiff-Verwaltung

### Was / Warum

Die in Welle B5 eingeführte Verwaltung eigener Reedereien/Schiffe
(`ShippingLineManagementView`, siehe [eigene-reedereien-b5.md](eigene-reedereien-b5.md))
war ohne Erklärtext nicht offensichtlich auffindbar. Neu: Section-Footer in drei
Ansichten, alle als `String(localized:)`:

- `SettingsView` — Footer an der Section „Reedereien & Schiffe": „Fehlt eine
  Reederei oder ein Schiff im Katalog? Hier kannst du eigene Einträge anlegen."
- `ShippingLineManagementView` — Footer an der Reederei-Anlegen-Section: „Fehlt
  deine Reederei oder dein Schiff im Katalog? Lege sie hier selbst an.
  Katalog-Einträge kannst du per Wisch-Geste ausblenden, statt sie zu löschen."
- `ShipManagementView` (in `ShippingLineManagementView.swift`) — Footer an der
  Schiff-Anlegen-Section: „Fehlt das Schiff dieser Reederei im Katalog? Lege es
  hier selbst an."

### Berührte Dateien

- `ShipTrip/Views/Settings/SettingsView.swift` — Footer an der
  „Reedereien & Schiffe"-Section.
- `ShipTrip/Views/Settings/ShippingLineManagementView.swift` — Footer an beiden
  betroffenen Sections (`ShippingLineManagementView` und `ShipManagementView`).

### Acceptance-Status

Erfüllt. Alle drei Einstiegspunkte zur B5-Funktion tragen jetzt einen
Erklärtext, der den Zweck (eigene Einträge anlegen, Katalog-Einträge ausblenden
statt löschen) direkt am Ort der Aktion benennt.

---

## Tests

Neue Unit-Suite „Ausflug entfernen (B6.1)" in `PortFormViewTests.swift`
(index-basiertes Löschen, auch bei Duplikaten; Roundtrip mit leerem Land) sowie
neue `ShipTripUITests/AusflugLoeschenUITests.swift`. Teststand: 164 Unit-Tests
gesamt (vorher 143), 21 UI-Tests (beide Suiten `** TEST SUCCEEDED **`).

### Kein ADR nötig

B6.1 und B6.3 sind Bugfix bzw. UI-Erklärtext ohne Architektur-Entscheidung; B6.2
ist ein Design-Deck ohne Umsetzung in dieser Welle.
