# Quality Review — B4.3b-1 (Karte, mutige Richtung Stufe 1) + B7/A2+B2 (Hafen-Momente)

Iteration 1 · 2026-07-04 · unabhängiger Review vor Final-Gate

## Verdikt: GO-WITH-CHANGES

Keine kritischen Findings. Ein major Finding (Performance-Inkonsistenz beim Foto-Decode
im Karten-Callout), zwei minor Findings. Test-Evidenz ist real und wurde stichprobenartig
selbst gegengeprüft (nicht nur dem Dev-Report geglaubt).

---

## 1. Deck-Treue

**B4.3b-1 (Karte, `docs/ux-pitch-decks/b4-karten-redesign.html`, Richtung "Mutig", Stufe 1):**
- Zwei-Zoom-Zustände (Welt/Reise) über `MKCoordinateRegion.span`-Schwelle: umgesetzt
  (`MapView.swift:96-106`, `MapZoomBucketPlanner`). Schwelle bewusst als geometrisches
  Mittel der beiden Deck-Anker (20°/5° → √100 = 10°) hergeleitet und dokumentiert — sauberer,
  nachvollziehbarer Kompromiss statt Rätselraten.
- Welt-Zoom: nur Dots + Polyline, keine Labels, jetzt routenfarbig statt einheitlich
  (`worldDotView`) — entspricht Slide 6 und behebt zusätzlich die bekannte B4.3a-Limitation.
- Reise-Zoom: volle Rollen-Pins (Start/Ende/Rundreise über bestehendes `PortPinView`) +
  nummerierte Badges für Zwischenstopps (`MapStopBadgeView`) — entspricht Slide 5+7
  (Roadtrippers-Nummerierung, Form+Farbe statt nur Farbe).
- Tap-Callout mit Foto (`MapCalloutView`) statt Dauerlabel — entspricht Polarsteps-Prinzip
  aus Slide 6.
- Bewusst NICHT umgesetzt (korrekt, da Folge-Wellen): Bottom-Sheet mit synchronisierter
  Liste (B4.3b-2, Slide 9) und Bezier-Routenlinien um Landmassen (B4.3b-3, Slide 7) —
  `selectedStopID` ist explizit als Fundament dafür angelegt und dokumentiert
  (`MapView.swift:134-136`).

**B7.1/A2 + B7.2/B2 (`docs/ux-pitch-decks/b6-hafen-momente.html`):**
- A2 (Erfassung): eine "Hafen-Momente"-Section statt zwei generischer Felder, große
  Foto-Kachel, vordefinierte Chips (Stadtbummel/Strand/Wanderung/Bootstour/Museum/Shopping)
  + Freitext — entspricht Slide 6. `.scrollIndicators(.hidden)` + `.contentShape(Rectangle())`
  auf den Chips wie im Gate-Hinweis des Decks umgesetzt (`PortFormView.swift:363-366`).
- Abweichung vom Deck, dokumentiert und nachvollziehbar begründet: Deck schlägt natives
  `.onMove`/List-EditMode für Reorder vor: laut Kommentaren zweifach per UI-Test widerlegt
  (rendert in der echten Form/List keine Move-Griffe) → Plan B mit expliziten
  Auf-/Ab-Chevron-Buttons. Nicht selbst nachgestellt (kein Build/Testlauf meinerseits), aber
  die Begründung ist plausibel (SwiftUI `List`-EditMode in Formularen mit gemischtem
  Section-Inhalt ist ein bekanntes Wackelfeld) und die Buttons sind eine vollwertige,
  zugängliche Alternative (siehe Abschnitt 5).
- B2 (Darstellung): volle-Breite `PortMemoryCard`, 16:9-Hero mit Downsampling, Liegezeit-
  Badge, Dashed-Border-Zero-State — entspricht Slide 9 inkl. Gemini-Gate-Auflage
  (Liegezeit auf die Karte statt in die Metadaten-Zeile).

Fazit: beide Wellen bilden ihre jeweiligen Decks in den wesentlichen Punkten sauber ab.

## 2. Surgical Changes

Diff-Scope wie angekündigt: `MapView.swift` + 2 neue Map-Views, `PortFormView.swift`,
`CruiseFormView.swift` (nur `TempPortFormSheet`), `CruiseDetailView.swift` + 1 neue View,
zugehörige Tests. `audit/screenshots/*.png` sind reproduzierbarer Beifang aus einem
Screenshot-Skript (Binärdiff durch PNG-Recompression, kein inhaltlicher Bezug), `.planning/`
und `docs/umsetzungsplan-audit-2026-07.md` sind Planungsartefakte. Keine unerwarteten
Dateien im Scope.

## 3. Regressionen — B6.1-Garantien, EditMode-Reste, Bestands-APIs

- **Sichtbarer Lösch-Button erhalten:** `excursionDeleteButton` in beiden Dateien ist
  zeichengleich mit dem vorherigen Block (Diff bestätigt: nur verschoben/umbenannt, keine
  Logikänderung). `.onDelete`-Swipe bleibt zusätzlich bestehen (war bereits vorher so).
- **Index-Semantik:** `excursions.remove(at: index)` unverändert übernommen.
- **Save-Logik aus B6.1:** `savePort()`/Speicherpfad in `PortFormView.swift:233-271`
  unangetastet (kein Diff in diesem Bereich).
- **Alte EditMode-/onMove-Reste vollständig weg:** `grep` auf `editMode`/`EditButton` in
  beiden Formular-Dateien ergibt nur die Erklär-Kommentare, keinen aktiven Code mehr. Der
  einzige verbleibende `.onMove`-Treffer (`CruiseFormView.swift:358`) gehört zum
  unabhängigen Routen-/Port-Reorder (`tempPorts.move`), nicht zu den Ausflügen — kein
  Leftover.
- **`MapMarkerPlanner`-Bestands-API:** `validPorts(in:)` unverändert (Signatur, Filterlogik).
  `markerRoles(for:)` erweitert `MapPortRole` um `stopNumber`, bricht aber keine bestehende
  Verwendung (additives Feld, Rollen-Zuordnungslogik selbst unverändert).
- **Beide Editor-Pfade wirklich diff-identisch:** selbst nachvollzogen (nicht nur
  Dev-Behauptung übernommen) — der eingefügte Block in `PortFormView.swift` und
  `CruiseFormView.swift` ist Zeile für Zeile identisch. Vorbestehende Code-Duplikation
  zwischen beiden Dateien (bereits vor diesem Diff so, siehe entfernte alte Blöcke) —
  keine neue Schuld durch dieses Feature, aber auch keine Gelegenheit genutzt, sie zu
  reduzieren (nicht im Scope, daher kein Fix-Verlangen).

## 4. Performance/Robustheit

**MAJOR — `MapCalloutView.swift:15` deckt `Port.imageData` ohne Downsampling.**
`UIImage(data: imageData)` läuft synchron im View-Body, direkt auf Vollauflösungsdaten aus
`@Attribute(.externalStorage)` (kamera-/fotobibliotheks-originalgroß, kein Cap beim Import
in `PortFormView.loadImage`). Für ein 32×32-Thumbnail im Tap-Callout ist das unnötig teuer —
und zwar auf dem Main-Thread, im interaktiven Kartenpfad (Tap → sofortiges Callout). Genau
für diesen Fall wurde in derselben PR `AsyncPhotoView(imageData:maxPixelSize:)` mit
Off-Main-Thread-Decode + ImageIO-Downsampling gebaut und in `PortMemoryCard` auch benutzt
(`PortMemoryCard.swift:61`, `heroMaxPixelSize = 800`). `MapCalloutView` sollte denselben Weg
nutzen (z. B. `maxPixelSize: 64`) statt einen dritten, synchronen Decode-Pfad einzuführen.
Fix-Vorschlag: `AsyncPhotoView(imageData: imageData, maxPixelSize: 64)` statt direktem
`UIImage(data:)`.

- **onEnd+Bucket-Dedupe:** `onMapCameraChange(frequency: .onEnd)` plus `if bucket != zoomBucket`
  ist eine sinnvolle, günstige Kombination — kein State-Churn während des Zoomens, nur ein
  Update am Ende der Geste. Für den synchronen Sofort-Zoom (`zoomTo(routes:)`) wird der
  Bucket zusätzlich synchron vorgesetzt, um den beschriebenen Flash zu vermeiden — korrekt.
- **Downsampling im Card-Pfad (B7.2):** korrekt eingebunden, kein Vollbild-Decode
  (`PortMemoryCard.swift:61`, `AsyncPhotoView.swift` via `CruiseDetailView.swift:503-513`
  mit Fallback auf Vollbild nur wenn `maxPixelSize == nil`, was für bestehende Call-Sites
  unverändert bleibt — sauber rückwärtskompatibel).
- **`swapAt`-Grenzen:** `.disabled(index == 0)` / `.disabled(index == excursions.count - 1)`
  auf Button-Ebene verhindert Out-of-Range-Aufrufe von der UI aus zuverlässig
  (`PortFormView.swift:427`, `439`). Kein zusätzlicher Bounds-Check in der Swap-Funktion
  selbst nötig, da der einzige Call-Site (der Button) bereits abgesichert ist.

## 5. Accessibility

- `MapStopBadgeView`: `.accessibilityLabel("Stopp \(number)")` vorhanden.
- Marker-Button in `MapView.swift:172`: `.accessibilityLabel(Text(role.port.name))` auf dem
  äußeren Button — sinnvoll, VoiceOver liest den Hafennamen unabhängig vom Zoom-Zustand
  (Dot/Badge/Pin), nicht nur die Nummer.
- Auf-/Ab-Buttons: eigene Labels ("Nach oben"/"Nach unten") + `accessibilityIdentifier` für
  UI-Tests — gut für beides (VoiceOver und Testautomatisierung).
- Ausflug-Chips (`excursionChipScroller`): kein explizites `.accessibilityLabel`, aber
  `Text(suggestion)` liefert VoiceOver-Default-Label automatisch — ausreichend, kein Fix nötig.
- **MINOR** — `MapCalloutView` selbst hat keine kombinierte Accessibility-Semantik (Foto +
  Name als zwei separate Elemente lesbar). Unkritisch, da der darunterliegende Marker-Button
  bereits den vollständigen Namen trägt und das Callout rein visuell/redundant ist.

## 6. Sonstiges

- **MINOR** — `ReorderExcursionTests` (`PortFormViewTests.swift`) testen weiterhin generische
  `Array.move(fromOffsets:toOffset:)`-Semantik, die von der tatsächlichen UI (Plan B,
  swapAt-Buttons) nicht mehr aufgerufen wird. Das ist im Code selbst transparent
  kommentiert ("spiegeln aber nicht mehr den tatsächlichen Aufruf aus der UI") und durch die
  neue `SwapExcursionTests`-Suite ergänzt statt ersetzt — vertretbar, da `move` weiterhin an
  anderer Stelle der App genutzt wird (Port-Reihenfolge in `CruiseFormView.swift:358`), aber
  bei Gelegenheit könnte der Docstring der alten Suite noch klarer machen, dass sie keine
  B7.1-Regression mehr abdeckt.
- Bewusste Kern-Entscheidung (Duplikate bei Ausflug-Chips erlaubt) ist konsistent mit
  bestehendem Freitext-Verhalten und durch `AddExcursionViaChipTests` abgedeckt.

## Test-Evidenz (eigenständig gegengeprüft, nicht nur übernommen)

- Unit: `grep -c "passed on"` im Log ergibt 202 — deckt sich mit der gemeldeten Zahl; kein
  `failed`/`error:` im Log außerhalb der bekannten "0 unexpected"-Meldungen. `** TEST
  SUCCEEDED **` vorhanden.
- UI: Log-Ende zeigt `Executed 23 tests, with 0 failures (0 unexpected)` und
  `** TEST SUCCEEDED **`.
- Beide Logs unter `scratchpad/unit-test-b43b-b7-run7.log` /
  `scratchpad/ui-test-b43b-b7-run7.log` sind lesbar und enthalten reale xcodebuild-Ausgabe
  (keine Platzhalter/Kürzung).

## Empfehlung

GO-WITH-CHANGES. Vor Merge: MapCalloutView auf `AsyncPhotoView(maxPixelSize:)` umstellen
(kleiner, lokaler Fix, kein Test-Rerun der übrigen Suite nötig, nur neuer/angepasster Test
für den Callout-Decode-Pfad falls gewünscht). Die beiden minor Findings sind Kann-Fixes und
blockieren nicht.
