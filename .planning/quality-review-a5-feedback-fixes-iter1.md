# Quality Review — Welle A5 „Feedback-Fixes" (Iteration 1)

**Scope:** uncommitted Working-Tree-Änderungen auf `main` (siehe `git status`/`git diff`)
**Reviewer:** Quality-Agent (read-only, kein Build/Testlauf durch mich selbst — Testergebnis
98/98 grün wurde vom Orchestrator geliefert und hier nicht erneut verifiziert)

## Verdikt: **Go-with-changes**

Keine Critical-Findings. Zwei Minor-Findings, keine davon Merge-Blocker; Empfehlung: vor
TestFlight-Release beheben oder bewusst zurückstellen (Andre-Entscheidung).

---

## Acceptance-Check (Feedback-Item 1: „nirgends Hafenbilder/Ausflüge hinzufügbar")

Abgedeckt für beide Flows:
- `PortFormView.swift` (Bearbeiten eines bestehenden Hafens aus `CruiseDetailView`): PhotosPicker +
  Ausflüge-Editor vorhanden, Laden in `loadExistingData()`, Speichern in `savePort()`
  (`imageData`/`excursions` in beiden Zweigen — neu und Edit).
- `TempPortFormSheet` in `CruiseFormView.swift` (Routen-Editor beim Anlegen/Bearbeiten einer
  Kreuzfahrt): identische UI, Laden in `onAppear`, Speichern in `savePort()`. `reconcileRoute()`
  (unverändert in diesem Diff) propagiert `excursionsRaw`/`imageData` bereits korrekt von
  `TempPort` zu `Port` — vor dem Feature schon vorhanden, jetzt end-to-end nutzbar.
- Anzeige: `CruiseDetailView.swift` zeigt Thumbnail (via bestehende `AsyncPhotoView`, off-main-Thread
  Decode) + Ausflugsliste in der Routen-Zeile, nur gerendert wenn Daten vorhanden.

Feature schließt die gemeldete Lücke vollständig.

---

## Findings

### Minor 1 — A11y-Inkonsistenz beim „Ausflug hinzufügen"-Button
`ShipTrip/Views/Cruises/PortFormView.swift` (im Ausflüge-Editor, Add-Button) und identisch in
`ShipTrip/Views/Cruises/CruiseFormView.swift` (`TempPortFormSheet`):
```swift
Button { addExcursion() } label: { Image(systemName: "plus.circle.fill") }
```
Der „Entfernen"-Button direkt daneben (Hafenbild-Sektion) nutzt `Label(String(localized: "Entfernen"), ...)`
mit explizitem Text, der Add-Button dagegen ein reines `Image` ohne `.accessibilityLabel`. VoiceOver
fällt hier auf Apples generische SF-Symbol-Beschreibung zurück ("Plus Circle Fill" o. ä.) statt
"Ausflug hinzufügen" zu sagen. Fix: `.accessibilityLabel(String(localized: "Ausflug hinzufügen"))`
auf dem Button ergänzen, analog zum bestehenden Muster im selben Screen.

### Minor 2 — Neue Strings noch nicht im String Catalog
`ShipTrip/Localizable.xcstrings` enthält noch keine Einträge für die 6 neuen
`String(localized:)`-Strings ("Hafenbild", "Entfernen", "Bild auswählen", "Bild ersetzen",
"Ausflüge", "Ausflug hinzufügen") — der Diff berührt die `.xcstrings`-Datei nicht. Xcode extrahiert
das üblicherweise automatisch beim nächsten Build ("Use Compiler to Extract Swift Strings"), daher
kein funktionaler Bug (deutscher Fallback-Text ist bereits der Key), aber die EN-Übersetzung fehlt
bis zum nächsten Build+Sync. Vor dem TestFlight-1.6.1-Build einmal in Xcode bauen und Katalog prüfen.

### Informationell (kein Fix nötig, nur zur Kenntnis)
- **Sea-Day-Editing zeigt jetzt auch Hafenbild/Ausflüge-Sektionen:** In `CruiseFormView.swift` öffnet
  ein Tap auf eine Seetag-Zeile denselben `TempPortFormSheet` (vorbestehendes Verhalten, nicht Teil
  dieses Diffs). Da der Sheet jetzt einen Bild-/Ausflüge-Editor hat, sieht man diese Sektionen auch
  beim Bearbeiten eines Seetags, obwohl Seetage kein Hafenbild/keine Ausflüge im Datenmodell sinnvoll
  nutzen. Kein Datenverlust-Risiko (Felder werden einfach mitgespeichert), nur UX-Fussnote für eine
  spätere Politur-Welle.
- **Vorbestehender Datensatz-Fund (nicht durch diesen Diff verursacht):** `PortSuggestion.swift`
  enthält bereits vor diesem Diff ein Duplikat "Mumbai"/"Indien" mit leicht abweichenden Koordinaten
  (Zeile ~1376 und ~2038). Die 23 neuen Häfen in diesem Diff sind sauber (Name+Land-Uniqueness-Test
  grün, DE/EN-Alt-Namen wie "Kapstadt"/"Cape Town" folgen demselben Muster wie bereits bestehende
  Einträge im File). Nur zur Kenntnis, nicht Teil dieses Reviews.
- Sehr kleine Whitespace-Bereinigung (trailing spaces auf Leerzeilen) in `PortFormView.swift`/
  `CruiseFormView.swift` außerhalb der eigentlichen Änderung — vermutlich Xcode-Autoformat-Nebeneffekt
  beim Editieren angrenzender Zeilen. Kein Funktionsrisiko, nur Erwähnung gemäß Surgical-Changes-Regel.

---

## Datenverlust-Risiken — geprüft, keine Findings
- `excursionsRaw`-Roundtrip (`", "`-Trenner) konsistent zwischen `Port.excursions` (bestehend) und
  neuem `TempPort.excursions` computed property; Test `PortImageExcursionsRoundtripTests` deckt
  Create/Edit/Remove über SwiftData-In-Memory-Container ab.
  `sanitizedExcursionEntry` entfernt Kommas aus Nutzereingaben, bevor sie ins `", "`-Format gelangen
  — verhindert Trenner-Kollision.
- `TempPortFormSheet.savePort()`: beim Edit-Pfad geht `port = originalPort ?? TempPort(...)` von der
  vollständigen Originalkopie aus und überschreibt nur die im Sheet editierbaren Felder inkl. Bild/
  Ausflüge — kein Feld-Verlust durch Teil-Overwrite.
- Bild-Entfernen setzt `imageData = nil` (kein Re-Encoding, kein Leerbild), Ausflüge-Entfernen leert
  über `excursions = []` korrekt `excursionsRaw` auf `""` (verifiziert per Test).

## Swift-6-Concurrency — geprüft, keine Findings
- `loadImage(from:)` in beiden Formularen folgt exakt dem bereits im Projekt etablierten Muster
  (`CruiseFormView.swift:472`, Foto-Upload für Kreuzfahrten): `Task { ... await MainActor.run { ... } }`.
  Kein neues Anti-Pattern, keine `@Model`-Instanz wird über eine Task-Grenze gereicht (nur `Data`,
  Sendable).
- `CruiseDetailView` nutzt für die Thumbnail-Anzeige die bestehende `AsyncPhotoView`
  (Decode via `Task.detached` abseits des Main-Threads) statt direktem `UIImage(data:)` im Body —
  vermeidet das aus Welle A2 bekannte "Foto-Grid Full-Res"-Perf-Problem.

## Referenzdaten-Stichprobe (5 von 23 neue Häfen)
Kapstadt (-33.9249/18.4241), Walvis Bay (-22.9576/14.5052), Praia (14.9330/-23.5133),
Stanley/Falklandinseln (-51.6980/-57.8514), Montevideo (-34.9011/-56.1645) — Koordinaten gegen
bekannte Referenzwerte plausibel, Länderzuordnung korrekt, alle südlich/südwestlich orientiert wie
im Kommentar angekündigt. Kein `popular`-Flag-Missbrauch (Konstruktor ohne `popular:`-Parameter
nutzt bestehenden Default, konsistent mit Nachbareinträgen).

## Surgical Changes
Keine Modell-Schema-Änderungen (keine neuen `@Attribute`, keine neuen Properties auf `@Model`-Typen
— `Port.imageData`/`excursionsRaw`/`excursions` existierten bereits vor diesem Diff). CloudKit-Regeln
(ADR-002) somit nicht berührt. Kein Beifang außerhalb des beschriebenen Scopes.

## Test-Coverage
9 neue Tests in `ShipTripTests/PortFormViewTests.swift` (Auto-Datum × 2 Suiten, Sanitisierung × 1,
SwiftData-Roundtrip × 3) + 2 neue Tests in `ShipTripTests.swift` (`ShippingLine`) + 2 neue Tests
(`PortSuggestion` Südhalbkugel-Häfen). Tests decken die in diesem Review geprüften Kernpfade ab
(Datumslogik, Sanitisierung, Persistenz-Roundtrip inkl. Löschen). Kein eigener Testlauf durch mich
(read-only) — 98/98 grün laut Orchestrator-Meldung.

## GDPR / OWASP
Keine User-Daten-Verarbeitung außerhalb des bestehenden lokalen SwiftData-Stores berührt (kein
Netzwerk-Call, kein neuer Datenexport-Pfad). Kein OWASP-relevantes Muster (keine Injection-Fläche,
keine neue externe Eingabeverarbeitung außer bereits vorhandenem PhotosPicker-Flow).
