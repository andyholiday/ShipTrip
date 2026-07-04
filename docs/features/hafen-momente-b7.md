# Welle B7 — Hafen-Momente-Umsetzung (A2 + B2)

**Status:** Abgeschlossen (B7.1, B7.2)
**Testsuite:** `PortFormViewTests.swift` (u. a. `AddExcursionViaChipTests`,
`ReorderExcursionTests`) + `PortMemoryCardTests.swift`, Teil der 202-Unit-Tests-
Gesamtsuite; `AusflugLoeschenUITests.swift` (`testAusflugReihenfolgeAendernZeigtReorderAffordance`)
+ `PortMemoryCardUITests.swift`, Teil der 23-UI-Tests-Gesamtsuite
**Quelle:** [Umsetzungsplan Audit 2026-07](../umsetzungsplan-audit-2026-07.md#welle-b7--hafen-momente-umsetzung-b62-wahl-andre-2026-07-04--a2--b2-empfehlung-bestätigt)
— B6.2-Wahl durch Andre 2026-07-04: **A2** (geführter Erfassungsschritt) für
die Erfassung, **B2** (`PortMemoryCard`) für die Darstellung, beide Empfehlungen
aus dem Design-Deck bestätigt

## Beschreibung

Welle B7 setzt die im Design-Deck [`docs/ux-pitch-decks/b6-hafen-momente.html`](../ux-pitch-decks/b6-hafen-momente.html)
(B6.2, siehe [feedback-fixes-b6.md](feedback-fixes-b6.md#b62--design-deck-hafen-momente))
von Andre/Tester gewählte Richtung um: A2 für die Erfassung von Hafenbild und
Ausflügen (B7.1) und B2 für ihre Darstellung in der Reise-Detailansicht (B7.2).
Kein Datenmodell-Umbau — `Port.excursions` bleibt `[String]`, `Port.imageData`
unverändert.

---

## B7.1 (A2) — Geführter Erfassungsschritt „Hafen-Momente"

### Was / Warum

Ersetzt die bisherigen zwei generischen Formularfelder (Foto-Picker + freie
Ausflugsliste) durch einen einzelnen, geführten Erfassungsschritt „Hafen-Momente":

- **Große Cover-Foto-Kachel** (160pt hoch, `PhotosPicker`) statt kleinem
  Thumbnail — mit „Bild ersetzen"/„Entfernen" im gefüllten Zustand, leerem
  Platzhalter mit Plus-Icon sonst.
- **Antippbare, vordefinierte Ausflug-Chips** (horizontal scrollbar: Stadtbummel,
  Strand, Wanderung, Bootstour, Museum, Shopping) — reduziert Tipparbeit an
  Bord (oft schlechtes Netz/wenig Zeit). Ein Chip-Tap hängt den Text direkt an
  `excursions` an (`excursions.append(suggestion)`), Duplikate sind bewusst
  erlaubt (derselbe Chip mehrfach antippbar), konsistent zum bestehenden
  Freitext-Pfad, der gleichnamige Ausflüge schon immer zuließ.
- **Freitext-Eingabe** bleibt zusätzlich zu den Chips bestehen.
- **Umsortieren** über einen expliziten „Reihenfolge ändern"-Modus (Button
  erscheint erst ab zwei Ausflügen): pro Zeile ein Auf-/Ab-Pfeil-Button
  (`chevron.up`/`chevron.down`, 44×44pt Tap-Fläche, jeweils an den Enden der
  Liste deaktiviert), der die Position index-basiert vertauscht (`excursions.swapAt(index, index ± 1)`).

Identisch in beiden Erfassungspfaden umgesetzt: `PortFormView.swift`
(bestehender Hafen) und `TempPortFormSheet` in `CruiseFormView.swift`
(Hafen während der Reiseerstellung).

Die bestehenden B6.1-Garantien bleiben erhalten: sichtbarer Lösch-Button pro
Ausflug (`minus.circle.fill`, 44×44pt), index-basiertes Löschen, und der
Speichern-Button bleibt nur bei leerem Namen deaktiviert (nicht bei leerem Land).

### Wichtige Entscheidung: natives List-EditMode verworfen (Lesson Learned)

Ursprünglich geplant war natives SwiftUI-Reordering (`.onMove` + `.environment(\.editMode, …)`).
Das wurde **zweifach per UI-Test widerlegt**: die native Move-Griff-Affordance
erschien in der echten `Form`/`List` weder bei `editMode` auf dem umgebenden
`Group`- noch auf dem `Form`-Environment. Statt eines dritten Anlaufs wurde
bewusst auf die robustere, zugänglichere Auf-/Ab-Button-Lösung umgestellt
(„Plan B" in den Code-Kommentaren von `PortFormView.swift`/`CruiseFormView.swift`) —
kein `editMode` mehr im Spiel, dafür klar sichtbare, einzeln antippbare
Pfeil-Buttons mit expliziten Accessibility-Identifiern
(`excursion-<index>-moveUp`/`-moveDown`), die auch per UI-Test zuverlässig
prüfbar sind.

### Berührte Dateien

- `ShipTrip/Views/Cruises/PortFormView.swift` — `hafenMomenteSection` (Cover-
  Foto-Kachel, Chip-Scroller, Ausflugsliste, Reorder-Toggle, Freitext-Zeile),
  `isReorderingExcursions`-State, `excursionMoveButtons(index:)`.
- `ShipTrip/Views/Cruises/CruiseFormView.swift` (`TempPortFormSheet`) —
  identischer Aufbau (`hafenMomenteSection`, `excursionMoveButtons(index:)`,
  Chip-Scroller).

### Acceptance-Status

Erfüllt. Chip-Tap fügt den Ausflug an, Duplikate bleiben möglich und persistent
über SwiftData-Roundtrip; Reorder-Toggle erscheint erst ab zwei Ausflügen,
Auf-/Ab-Buttons tauschen die sichtbare Reihenfolge, oberste/unterste Zeile
deaktivieren den jeweils unpassenden Pfeil. Abgesichert durch
`PortFormViewTests.swift` (`AddExcursionViaChipTests`, `ReorderExcursionTests`,
inkl. SwiftData-Roundtrip für beide Erfassungspfade) sowie
`ShipTripUITests/AusflugLoeschenUITests.swift`
(`testAusflugReihenfolgeAendernZeigtReorderAffordance`, End-to-End über die
tatsächlichen Auf-/Ab-Buttons statt nur Modell-Ebene).

---

## B7.2 (B2) — `PortMemoryCard` in der Route-Sektion

### Was / Warum

Ersetzt den bisherigen 44×44-Thumbnail + Fließtext-Block in der Route-Sektion
von `CruiseDetailView` durch eine neue, volle-Breite-Karte:

- **16:9-Hero-Foto** (`AsyncPhotoView`, `maxPixelSize: 800`) — feste
  Bounding-Box über `Color.clear.aspectRatio(16/9, .fit)` + verschachteltem
  `GeometryReader`, damit das Foto exakt über eine feste `.frame(width:height:)`
  gefüllt werden kann.
- **Liegezeit-Badge** („Ankunft – Abfahrt", Kurzzeitformat) als Overlay oben
  rechts auf dem Hero-Foto — ersetzt die bisherige Liegezeit-Anzeige in der
  Metadaten-Zeile von `CruiseDetailView`; nur bei echten Häfen (`nil` bei
  Seetagen, da dort keine Liegezeit existiert).
- **Ausflug-Chips** unter dem Hero-Foto, sofern Ausflüge erfasst sind.
- **Dashed-Border-Zero-State** („Foto & Ausflüge erfassen") anstelle einer
  leeren grauen Box, solange kein Hafenbild erfasst wurde — Tap zum Erfassen
  läuft über die bestehende Navigation der gesamten Hafen-Zeile.
- **Anzeigeregel:** Die Karte erscheint für jeden echten Hafen immer (inkl.
  einladendem Zero-State). Seetage ohne erfasste Momente bleiben dagegen
  kompakt ohne Card — nur wenn für einen Seetag bereits ein Foto oder ein
  Ausflug erfasst wurde, erscheint die Karte auch dort
  (`PortMemoryCard.shouldRender(for:)`).

Voraussetzung dafür: `AsyncPhotoView` (bisher `private` in
`CruiseDetailView.swift`) ist jetzt `internal`, damit `PortMemoryCard` es
wiederverwenden kann; `ImageDownsampler` unterstützt bereits seit B4.3b-1 ein
konfigurierbares `maxPixelSize` (hier 800 für die größere Hero-Fläche, dort 64
für den Karten-Callout).

### Berührte Dateien

- `ShipTrip/Views/Cruises/CruiseDetailView.swift` — Route-Sektion nutzt
  `PortMemoryCard(port:)` statt des alten Thumbnail-plus-Text-Blocks;
  `AsyncPhotoView` von `private` auf internal sichtbar.
- `ShipTrip/Views/Cruises/PortMemoryCard.swift` (neu) — die komplette Card:
  `hero`, `zeroStateHero`, `stayBadge`, `excursionChips` sowie die reine,
  separat testbare Logik `stayBadgeText(for:)`, `showsZeroStateHero(for:)`,
  `shouldRender(for:)`.

### Acceptance-Status

Erfüllt. Hero-Foto füllt zuverlässig die 16:9-Box, Liegezeit-Badge erscheint
nur bei echten Häfen mit korrektem Zeitformat, Zero-State erscheint nur ohne
Hafenbild (unabhängig von erfassten Ausflügen), Seetage ohne Momente bleiben
kompakt. Abgesichert durch `PortMemoryCardTests.swift` (reine Logik:
Badge-Text-Formatierung inkl. Ankunft==Abfahrt-Grenzfall, Seetag-Ausschluss,
Zero-State- und Render-Bedingungen) sowie
`ShipTripUITests/PortMemoryCardUITests.swift`
(`testZeroStateSichtbarBeiHafenOhneMomente`, End-to-End sichtbare Zero-State-Karte).

---

## Tests

Neue Unit-Suiten `AddExcursionViaChipTests` und `ReorderExcursionTests`
(`PortFormViewTests.swift`) sowie `PortMemoryCardTests.swift`; neue
`ShipTripUITests/PortMemoryCardUITests.swift` sowie eine erweiterte
`AusflugLoeschenUITests.swift` (`testAusflugReihenfolgeAendernZeigtReorderAffordance`).
Teststand: 202 Unit-Tests gesamt, 23 UI-Tests (beide Suiten grün).

### Kein ADR nötig

B7.1 und B7.2 sind reine UI-Umsetzung einer bereits gewählten Design-Richtung
ohne Datenmodell-Änderung (`excursions` bleibt `[String]`, `imageData`
unverändert) — keine Architektur-Entscheidung im Sinne eines ADR.

## Related Decisions

- [Design-Deck: Hafen-Momente (B6.2)](../ux-pitch-decks/b6-hafen-momente.html)
- [Welle B6 — Feedback-Fixes: B6.2-Ursprung der Wahl](feedback-fixes-b6.md#b62--design-deck-hafen-momente)
