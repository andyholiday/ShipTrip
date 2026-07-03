# Welle A5 — Feedback-Fixes (TestFlight 1.6.0/12)

**Status:** Abgeschlossen (A5.1, A5.2, A5.3) — A5.4 Release offen
**Testsuite:** 98/98 Unit-Tests PASS (vorher 84)
**Quelle:** [Umsetzungsplan Audit 2026-07](../umsetzungsplan-audit-2026-07.md#welle-a5--feedback-fixes-testflight-160112-feedback-hafenbildausflüge-erfassung-fehlt-m-südhalbkugel-häfen--aidastella-sichtbarkeit-l-kein-auto-datum-neuer-hafen-l--quelle-interner-tester-2026-07-03-deckungsgleich-mit-app-store-reviews-3-2805-und-2-1405),
interner Tester 2026-07-03 (deckungsgleich mit App-Store-Reviews ★3 28.05. und
★2 14.05.)

## Beschreibung

Welle A5 behebt drei Feedback-Punkte aus dem internen Test der TestFlight-Version
1.6.0(12): fehlende Erfassungs-UI für Hafenbild und Ausflüge trotz vorhandener
Datenschicht (A5.1), fehlende Südhalbkugel-Häfen in der Referenzdatenbank sowie
eine als „AIDAstella fehlt" gemeldete, tatsächlich anderweitig verursachte
Reederei-Zuordnung (A5.2), und ein fehlendes Vorschlagsdatum beim Anlegen eines
neuen Hafens (A5.3).

---

## A5.1 — Erfassungs-UI + Anzeige für Hafenbild & Ausflüge

### Was / Warum

`Port.imageData`/`Port.excursionsRaw` waren datenschicht-komplett, aber ohne
Erfassungs-UI und Anzeige — Tester-Feedback: „Hafenbild und Ausflüge lassen
sich nirgends hinzufügen". Neu:

- **`PortFormView`** (Bearbeiten eines bestehenden Hafens) und
  **`TempPortFormSheet`** (Neuanlage einer Route in `CruiseFormView`) erhalten
  je einen `PhotosPicker`-Abschnitt „Hafenbild" (wählen/ersetzen/entfernen,
  `Data` wird direkt aus dem `PhotosPickerItem` übernommen, keine
  Re-Encodierung) und einen Abschnitt „Ausflüge" (Text-Eingabe + Add-Button,
  Liste mit Swipe-to-Delete).
- Neue Ausflug-Einträge laufen durch `sanitizedExcursionEntry(_:)`
  (`PortFormView.swift:26`): Kommas werden entfernt (Format-Trenner von
  `excursionsRaw`, das die Einträge kommasepariert speichert), Whitespace/
  Zeilenumbrüche getrimmt, leere Eingaben ergeben `nil` und werden verworfen.
- **`CruiseDetailView`** rendert in der Routen-Liste jetzt ein Hafenbild-
  Thumbnail (`AsyncPhotoView`, 44×44) und die Ausflugsliste
  (durch `·` getrennt), wenn `port.imageData != nil || !port.excursions.isEmpty`.
- Neue user-sichtbare Strings als `String(localized:)`: „Hafenbild",
  „Ausflüge", „Bild auswählen", „Bild ersetzen", „Entfernen", „Ausflug
  hinzufügen". Der Add-Button trägt zusätzlich ein `accessibilityLabel`.

### Berührte Dateien

- `ShipTrip/Views/Cruises/PortFormView.swift` — `PhotosPicker`-Abschnitt,
  Ausflüge-Editor, `defaultArrivalDateForNewPort(in:calendar:)` und
  `sanitizedExcursionEntry(_:)` als freie Funktionen oberhalb der View.
- `ShipTrip/Views/Cruises/CruiseFormView.swift` — identischer
  `PhotosPicker`-/Ausflüge-Abschnitt in `TempPortFormSheet`,
  `defaultArrivalDate(afterLastOf:fallback:calendar:)` (Pendant für
  `[TempPort]` statt `Cruise.route`).
- `ShipTrip/Views/Cruises/CruiseDetailView.swift` — Hafenbild-Thumbnail
  (`AsyncPhotoView`) und Ausflugsliste in der Routen-Zeile.

### Known Limitations

- Ausflüge sind nur Add/Delete, kein Inline-Edit eines bestehenden Eintrags.
- Kein UI-Test für den `PhotosPicker`-Flow (Foto-Bibliothek ist im
  UI-Test-Host nicht simulierbar).
- Die sechs neuen Strings sind noch nicht in `Localizable.xcstrings`
  synchronisiert — passiert beim nächsten Xcode-Build; EN-Übersetzung dann
  nachziehen.

### Acceptance-Status

Erfüllt. Hafenbild + Ausflug sind beim Neuanlegen UND Bearbeiten eines Hafens
erfassbar und in der Detailansicht sichtbar — per SwiftData-Feld-Roundtrip
abgesichert (dieselbe Feld-Zuweisung wie `savePort()`; kein UI-/PhotosPicker-
End-to-End-Test, siehe [Tests](#tests) unten).

---

## A5.2 — Referenzdaten: Südhalbkugel-Häfen & AIDAstella-Zuordnung

### Was / Warum

23 neue Häfen der Südhalbkugel bzw. des Südatlantiks wurden zu
`PortSuggestion.all` ergänzt (u. a. Kapstadt/Cape Town, Durban, Port
Elizabeth, Walvis Bay, Mindelo, Praia, Port Louis, Victoria/Seychellen, Nosy
Be, Sansibar, Mombasa, Stanley, Punta Arenas, Buenos Aires, Montevideo).
Root Cause: Der ursprüngliche Wikidata-Import deckte primär Häfen in Ländern
A–J ab, wodurch der gesamte südliche Atlantik und Indische Ozean lückenhaft
blieb.

Der gemeldete Befund „AIDAstella fehlt" war **kein Datenproblem** — das Schiff
war bereits vollständig in `ShippingLine.swift` vorhanden. Ursache war eine
zu strikte String-Übereinstimmung in `ShippingLine.findByShipName(_:)`: Die
KI-Erfassung lieferte „AIDA Stella" (mit Leerzeichen) für ein Datenfeld, das
als „AIDAstella" (ohne Leerzeichen) gespeichert ist. Der Vergleich normalisiert
jetzt zusätzlich Whitespace (`replacingOccurrences(of: " ", with: "")` auf
beiden Seiten), sodass „AIDA Stella" weiterhin auf „AIDAstella" matcht.

### Berührte Dateien

- `ShipTrip/Models/PortSuggestion.swift` — 23 neue `PortSuggestion`-Einträge
  im Abschnitt „Südhalbkugel & Südatlantik - Ergänzungen".
- `ShipTrip/Models/ShippingLine.swift` — `findByShipName(_:)` vergleicht
  jetzt whitespace-normalisiert statt nur lowercased+trimmed.

### Known Limitations

- Der Schiffs-Picker in `CruiseFormView` bleibt unsortiert (AIDAstella steht
  z. B. auf Position 11 von 11 in seiner Reederei-Liste) — als
  Verbesserungsidee erkannt, bewusst nicht Teil dieser Welle.

### Acceptance-Status

Erfüllt. Neue Häfen sind über `PortSuggestion.all` in der Suche auffindbar,
keine Namens-/Land-Duplikate zu bestehenden Einträgen; AIDAstella-Befund als
Matching-Problem der KI-Erfassung dokumentiert und behoben (nicht als
fehlender Datensatz).

---

## A5.3 — Auto-Datum bei neuem Hafen

### Was / Warum

Beim Anlegen eines neuen Hafens war das Ankunftsdatum-Feld ohne Vorbelegung.
Neu: Zwei Helper-Funktionen leiten ein plausibles Vorschlagsdatum ab —
Folgetag des letzten Stopps der (nach `sortOrder` sortierten) Route, bzw. bei
leerer Route exakt das Startdatum der Reise:

- `defaultArrivalDateForNewPort(in cruise: Cruise, calendar: Calendar = .current) -> Date`
  (`PortFormView.swift`) — sortiert `cruise.route` selbst nach `sortOrder`,
  statt sich auf die ungeordnete SwiftData-Relationship zu verlassen.
- `defaultArrivalDate(afterLastOf ports: [TempPort], fallback: Date, calendar: Calendar = .current) -> Date`
  (`CruiseFormView.swift`) — Pendant für die noch ungespeicherte
  `[TempPort]`-Route in `TempPortFormSheet`.

### Berührte Dateien

- `ShipTrip/Views/Cruises/PortFormView.swift` — `defaultArrivalDateForNewPort(in:calendar:)`.
- `ShipTrip/Views/Cruises/CruiseFormView.swift` — `defaultArrivalDate(afterLastOf:fallback:calendar:)`.

### Acceptance-Status

Erfüllt. Ein neu angelegter Hafen erhält ein plausibles Default-Ankunftsdatum
(Folgetag des letzten Stopps bzw. Reise-Startdatum bei leerer Route).

---

## Tests

Neue Datei `ShipTripTests/PortFormViewTests.swift`: Datums-Helper
(`defaultArrivalDateForNewPort`/`defaultArrivalDate(afterLastOf:)`,
Sortierung nach `sortOrder` statt Einfüge-Reihenfolge, leere Route),
`sanitizedExcursionEntry` (Trimmen, Komma-Entfernung, leere/Whitespace-only
Eingaben) sowie ein SwiftData-Roundtrip für Bild + Ausflüge (Neuanlage,
Bearbeiten, Entfernen). Ergänzend neue `PortSuggestion`-/`ShippingLine`-Tests
in `ShipTripTests.swift` (neue Häfen auffindbar, keine Duplikate,
`findByShipName` whitespace-tolerant). Teststand: 98 Unit-Tests gesamt
(vorher 84).

### Kein ADR nötig

Keine der drei Änderungen trifft eine Architektur-Entscheidung — reine
UI-Erfassung für bereits vorhandene Datenfelder, Referenzdaten-Ergänzung und
ein Datums-Default.
