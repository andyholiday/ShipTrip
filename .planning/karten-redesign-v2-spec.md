# Design-Spec — Karten-Redesign v2 „Journal Atlas" (Richtung 2, empfohlen)

> Verbindlich für den Developer-Spawn. Tokens sind bindend — Abweichungen
> erfordern eine Rückfrage an Winston, keine stille Improvisation.
> Herleitung/Vergleich der 3 Richtungen:
> `docs/ux-pitch-decks/karten-redesign-v2-richtungen.html`.
> Maschinenlesbare Tokens: `.planning/karten-redesign-v2-tokens.json`.

## Scope

- **Feature/Flow:** kompletter Umbau von `ShipTrip/Views/Map/MapView.swift`
  (Weltkarten-Screen) inkl. neuer Dateien für Bottom-Sheet und
  Kurven-Sampling.
- **Screens/Zustände:** Welt-Zoom (Default) · Routen-Zoom · Bottom-Sheet
  Peek/Medium/Large · Leerzustand „keine Häfen" (bestehend, unverändert) ·
  neuer Leerzustand „alle Routen ausgeblendet".
- **Out of scope:** `CruiseDetailView` (bleibt als Ziel-Screen erhalten, wird
  nur anders erreicht — aus dem Sheet statt per Bottom-Card), `PortPinView`-
  Rollenlogik (bleibt inhaltlich unverändert, nur Halo-Farbe passt sich an),
  `MapMarkerPlanner`/`MapZoomBucketPlanner`/`MapSelectionPlanner` (bleiben wie
  in B4.3a/B4.3b-1, siehe `docs/features/karten-redesign-b4.md`).

## Design-Entscheidungen (das „Warum")

- **Solide Navy-Chrome statt Glas** — Referenz-Vorlage (Road-Trip-Planer,
  siehe Brief) ist explizit flat UI mit soliden runden Buttons, kein
  Glasmorphismus. Grundfarbe `Color.navyDark` existiert bereits als Marken-
  farbe (`Color+Theme.swift`), keine neue Hue nötig.
- **Dicke „Ribbon"-Routen mit Farbschatten statt dünner Linie** — härteste
  Anforderung im Brief ("Routen sauber und modern", kurvig statt gerade).
  Farbschatten simuliert Tiefe, ohne dass `MapPolyline` einen echten
  `.shadow()`-Modifier bräuchte (den es nicht gibt, siehe Technische
  Leitplanken unten).
- **Warmes Papier-Sheet mit gepunkteter Timeline** — Roadtrippers-Pattern
  (nummerierte Wegpunkte + synchrone Liste, bereits in
  `.planning/b4-design-benchmark.md` verifiziert) kombiniert mit
  Polarsteps-Foto-Callouts (`port.imageData` bereits im Modell vorhanden,
  bisher auf der Karte ungenutzt außer im Tap-Callout).
- **Burger-Menü ersetzt Filter-Menü + Bottom-Capsule, Recenter-Button bleibt**
  — Brief listet nur „Funnel-Menü links" und „alte Bottom-Card" als
  wegfallend; der Recenter-Button (`point.topleft.down.curvedto...`) ist
  nützliche bestehende Funktionalität, die nicht explizit zum Wegfall
  vorgesehen ist — er wandert von rechts nach links, damit rechts Platz für
  den neuen Burger ist.

## Tokens (bindend)

Vollständiger Satz: `.planning/karten-redesign-v2-tokens.json`. Kernwerte:

| Token | Hell | Dunkel | Status |
|---|---|---|---|
| `chrome.solid.background` | `Color.navyDark` (#1A365D) | `Color.navyDark` (#1A365D) | bestehend, wiederverwendet |
| `chrome.solid.icon` | `.white` | `.white` | neu (Icon-Farbe auf solidem Grund) |
| `sheet.surface` | `#FBF7F0` | `#15212E` | **neu** — `Color.journalSurface` |
| `sheet.timelineLine` | `Color.navyDark.opacity(0.18)` | `Color.white.opacity(0.14)` | **neu** — `Color.journalTimeline` |
| `pin.halo` | `Color.journalSurface` (statt `.white`) | `Color.journalSurface` | geändert (Ist: hartkodiert `.white`) |
| `route.width.focused` | 4.5pt | gleich | erweitert (Ist: 3pt) |
| `route.width.other` | 2.5pt | gleich | erweitert (Ist: 2pt) |
| `route.opacity.focused` | 0.85 | gleich | erweitert (Ist: 0.78) |
| `route.opacity.other` | 0.35 | gleich | erweitert (Ist: 0.52) |
| `route.shadow.color` | `routeColor.opacity(0.30)` | gleich | neu |
| `route.shadow.radius` | 3pt | gleich | neu |
| `radius.sheet` | `DesignRadius.lg` (28pt) | gleich | bestehend |
| `radius.button` | 21pt (Kreis, Durchmesser 42pt) | gleich | bestehend (`.clipShape(Circle())`) |
| `spacing.sheetRowHeight` | min. 56pt | gleich | neu (Touch-Target ≥44pt + Luft) |
| `routeColors[0..7]` | oceanBlue…mint | gleich | bestehend, **unverändert** |

**Neue Farb-Tokens in `Color+Theme.swift` ergänzen** (nicht ersetzen):

```swift
/// Journal Atlas — warmes Papier-Surface für das Routen-Sheet (Karten-Redesign v2).
static let journalSurfaceLight = Color(red: 0.984, green: 0.969, blue: 0.941) // #FBF7F0
static let journalSurfaceDark  = Color(red: 0.082, green: 0.129, blue: 0.180) // #15212E

/// Adaptiv je Farbschema — siehe Environment(\.colorScheme) im Sheet-View.
static var journalSurface: Color {
    Color(uiColor: UIColor { trait in
        trait.userInterfaceStyle == .dark
            ? UIColor(Color.journalSurfaceDark)
            : UIColor(Color.journalSurfaceLight)
    })
}
```

(Analoges Muster für `journalTimeline`, falls kein dynamischer `Color(uiColor:)`-
Wrapper gewünscht ist — Alternative: zwei feste Werte + `@Environment(\.colorScheme)`
direkt im View, wie es für den Rest der App Konvention ist. Entscheidung liegt
beim Developer, solange die Hell/Dunkel-Werte aus der Tabelle oben exakt
getroffen werden.)

## Screens & Zustände

| Screen | Beschreibung | Empty | Loading | Error |
|---|---|---|---|---|
| Welt-Zoom | Alle aktiven Routen als Dots + dünne Kurven, Burger rechts, Recenter links | „Keine Häfen auf der Karte" (bestehend, `ContentUnavailableView`) | n/a (SwiftData sync) | n/a |
| Routen-Zoom | Volle Rollen-Pins + nummerierte Badges, Ribbon-Routen | wie oben | n/a | n/a |
| Sheet Peek (140pt) | Routentitel + Substats, erscheint bei Routen-Tap | — | — | — |
| Sheet Medium | + scrollbare Stop-Liste | — | — | — |
| Sheet Large | + „Reise öffnen"-CTA am Fuß | — | — | — |
| Alle-ausgeblendet | **Neu:** Karte ohne Marker, dezenter Hinweis-Overlay | „Alle Routen ausgeblendet — Burger-Menü zum Einblenden" | n/a | n/a |

## Komponenten im Detail

### 1. Header-Buttons (Chrome)

- **Position:** Recenter-Button (`point.topleft.down.curvedto.point.bottomright.up`)
  wandert von **oben rechts** nach **oben links** (ersetzt dort das bisherige
  Filter-Menü-Icon `line.3.horizontal.decrease.circle`, das ersatzlos entfällt).
  Neuer **Burger-Button** (`line.3.horizontal`) kommt **oben rechts**.
- **Stil:** 42×42pt Kreis, `Color.chromeSolidBackground` (= `Color.navyDark`,
  identisch hell/dunkel), weißes SF-Symbol-Icon, `.shadow(color: .black.opacity(0.28), radius: 10, y: 4)`.
  **Kein** `.ultraThinMaterial` mehr auf diesen beiden Buttons (Ist-Zustand
  nutzte Glas — Journal Atlas ist bewusst flach/solide).
- **Accessibility:** Recenter-Button behält sein bestehendes Label „Route
  anzeigen". Burger-Button neu: `"Routenauswahl"` (DE) / `"Route selection"` (EN).

### 2. Burger-Menü (Routen-Auswahl)

- Bleibt technisch ein SwiftUI `Menu` (kein Sheet) — leichtgewichtige,
  bereits im Code etablierte Interaktion, kein neuer Presentation-Mechanismus
  nötig.
- **Neu:** `.menuActionDismissBehavior(.disabled)` auf dem `Menu`, damit
  mehrere Taps (z. B. drei Routen einzeln abwählen) das Menü nicht nach jedem
  Tap schließen — sonst müsste der Nutzer für „alle bis auf eine abwählen"
  den Burger dreimal neu öffnen.
- **Inhalt, oben nach unten:**
  1. **Alle-ein/ausblenden-Zeile** (neu, ersetzt keine bestehende Zeile,
     ergänzt sie): Label wechselt zwischen bestehendem String
     `"Alle Reisen anzeigen"` (wenn aktuell nicht alle sichtbar sind) und
     neuem String `"Alle ausblenden"` (wenn aktuell alle sichtbar sind).
     Icon: `"eye.fill"` / `"eye.slash.fill"`.
  2. `Divider()`
  3. Pro Route wie bisher: `Label(route.title, systemImage: aktiv ? "checkmark" : "circle")`,
     Tap togglet Einzelauswahl (bestehende `toggle(route:)`-Logik bleibt).

- **State-Modell — WICHTIG, echte Verhaltensänderung:**
  Der aktuelle Code kodiert „alle sichtbar" implizit über
  `selectedRouteIDs.isEmpty` (leer = alle). Das kollidiert mit der neuen
  Anforderung „ein Klick blendet alle aus", weil ein leeres Set dann wieder
  als „alle" interpretiert würde. Notwendige Änderung:

  ```swift
  @State private var selectedRouteIDs: Set<UUID> = []
  @State private var allRoutesHidden: Bool = false   // NEU

  private var activeRouteIDs: Set<UUID> {
      if allRoutesHidden { return [] }
      return selectedRouteIDs.isEmpty ? Set(routableCruiseIDs) : selectedRouteIDs
  }
  ```

  - „Alle ausblenden" setzt `allRoutesHidden = true` (lässt `selectedRouteIDs`
    unangetastet, damit „Alle anzeigen" den vorherigen Zustand NICHT
    wiederherstellen muss — es räumt einfach `allRoutesHidden = false` und
    `selectedRouteIDs = []` auf, Ergebnis: wieder alle).
  - Tap auf eine **einzelne** Route setzt weiterhin `allRoutesHidden = false`
    (verlässt den „alles versteckt"-Zustand implizit) und toggelt wie bisher
    in `selectedRouteIDs`.
  - Die bestehende Schutzregel „letzte verbleibende Route kann nicht per
    Einzel-Tap abgewählt werden" (`next.count > 1`-Guard in `toggle(route:)`)
    bleibt **unverändert bestehen** — „auf null" geht ausschließlich über die
    explizite Alle-ausblenden-Zeile, nicht durch Wegtippen der letzten
    Einzelroute. Das verhindert eine versehentliche leere Karte, die wie ein
    Bug aussieht.
- **Leerzustand bei `allRoutesHidden`:** dezenter Overlay-Hinweis mittig auf
  der Karte (kein `ContentUnavailableView` — der ist für „keine Häfen
  vorhanden", nicht für „bewusst ausgeblendet"): Icon `"eye.slash"` +
  neuer String `"Alle Routen ausgeblendet"` + Substring
  `"Tippe auf das Menü, um Routen einzublenden"`.

### 3. Kurvige Routen (härteste technische Anforderung)

- **Algorithmus:** Catmull-Rom-Spline durch die geordneten, validen
  Hafen-Koordinaten einer Route (`MapMarkerPlanner.validPorts(in:)` bleibt
  die Datenquelle). Catmull-Rom statt quadratischer Bezier, weil die Kurve
  garantiert exakt durch jeden Original-Wegpunkt läuft (kein manuelles
  Kontrollpunkt-Tuning nötig) — wichtig, weil sonst Pins optisch neben statt
  auf der Linie sitzen würden.
- **Neue reine Logik-Einheit** (Muster: `MapMarkerPlanner`, SwiftUI-frei,
  isoliert testbar) — Vorschlag: `RouteCurveSampler` in `MapView.swift` oder
  eigener Datei `MapRouteCurveSampler.swift`:
  ```swift
  enum RouteCurveSampler {
      /// Liefert eine interpolierte Punktfolge für eine flüssige Kurve durch
      /// alle `waypoints`. `pointsPerSegment` wird adaptiv gedeckelt, damit die
      /// Gesamtpunktzahl über alle gleichzeitig sichtbaren Routen nicht explodiert.
      static func curve(
          through waypoints: [CLLocationCoordinate2D],
          pointsPerSegment: Int
      ) -> [CLLocationCoordinate2D]
  }
  ```
- **Performance-Deckel:** Gesamtpunkte-Budget über alle sichtbaren Routen
  ~280 Punkte. `pointsPerSegment = clamp(280 / gesamteSegmentanzahl, 6, 24)`
  — bei 1 Route mit 4 Stopps (3 Segmente) → 24 Punkte/Segment (satte Kurve),
  bei 10 gleichzeitig sichtbaren Routen mit insgesamt z. B. 40 Segmenten →
  7 Punkte/Segment (immer noch klar kurvig, aber leichtgewichtig).
- **Degenerierte Fälle** (für Unit-Tests): 0 oder 1 valider Port → leeres/
  einzelnes Ergebnis, keine Spline-Berechnung, kein Crash. 2 Ports → lineare
  Interpolation reicht (Catmull-Rom braucht eigentlich 4 Stützpunkte;
  Standard-Trick: erster/letzter Punkt werden für die Randsegmente
  gespiegelt/dupliziert, damit auch 2- und 3-Punkt-Routen eine Kurve statt
  eines Fehlers/Absturzes ergeben).
- **Darstellung:** `MapPolyline(coordinates: RouteCurveSampler.curve(...))`
  ersetzt die bisherige direkte `validPorts.map(\.coordinate)`-Übergabe.
  Stroke: `stroke(Color.routeColor(at: index).opacity(fokussiert ? 0.85 : 0.35), style: StrokeStyle(lineWidth: fokussiert ? 4.5 : 2.5, lineCap: .round, lineJoin: .round))`.
- **Farbschatten-Workaround (technische Einschränkung, für Developer
  wichtig):** `MapPolyline` unterstützt aktuell nur `.stroke(...)`, **kein**
  `.shadow()`-Modifier. Empfohlener Workaround: eine zweite, breitere,
  transparentere `MapPolyline` mit denselben interpolierten Koordinaten
  **unterhalb** der sichtbaren Linie rendern (`stroke(routeColor.opacity(0.30), lineWidth: fokussiert ? 9 : 6)`, vor der eigentlichen Linie in der
  `MapContentBuilder`-Reihenfolge). Das ist der pragmatische native Ersatz
  für einen echten Glow/Schatten. Falls das im Simulator zu unruhig/
  performancekritisch wirkt (mehrere Routen × 2 Polylines), ist das
  Weglassen des Schatten-Underlays eine zulässige, mit Winston abzustimmende
  Vereinfachung — kein Blocker für den Rest des Umbaus.

### 4. Pins/Badges/Callout

- `PortPinView`-Rollensystem, `MapStopBadgeView`, Zwei-Zoom-Bucket-Mechanik:
  **unverändert**, nur der Halo-Hintergrund hinter `PortPinView` wechselt von
  hartkodiertem `.white` auf `Color.journalSurface` (Zeile
  `MapView.swift:282`, `.background(Circle().fill(.white))` →
  `.background(Circle().fill(Color.journalSurface))`).
- `MapCalloutView` (navyDark-Chip): **unverändert** — passt bereits als
  solide, flache Komponente zur neuen Richtung, kein Anpassungsbedarf.

### 5. Bottom-Sheet — Trigger, Detents, Inhalt

**Trigger („Tap auf eine Route"):**
Primärer, empfohlener Ansatz — direkter Tap auf die Routenlinie selbst via
`MapReader`: Koordinate aus dem Tap-Punkt lesen (`reader.convert(location:from:.local)`),
gegen jede sichtbare Route den nächsten Punkt auf der interpolierten Kurve
suchen (einfache Punkt-zu-Segment-Distanz über die interpolierten Punkte aus
`RouteCurveSampler`), Toleranzradius ~20pt Bildschirmdistanz. Route mit dem
kleinsten Abstand innerhalb der Toleranz wird `primaryCruiseID`, Sheet öffnet.
Das ist die eigentliche neue Anforderung aus dem Brief ("Tap auf eine
Route"). **Fallback/Ergänzung**, geringeres Risiko und ohnehin schon
vorhandene Interaktion: Tap auf einen Pin/Badge einer Route setzt
`primaryCruiseID` bereits heute — dieselbe Aktion soll zusätzlich das Sheet
öffnen (`isSheetPresented = true`). Beide Trigger sind additiv, kein
Widerspruch — falls die Polyline-Hit-Testing-Variante sich in der
Implementierung als zu aufwändig/unzuverlässig erweist, ist der
Pin/Badge-Tap allein ein **akzeptabler Minimalscope**, der die
Akzeptanzkriterien noch erfüllt (Route lässt sich weiterhin per Tap öffnen,
nur eben über einen Marker statt jeden Punkt der Linie) — offene Frage, siehe
unten.

**Sheet-Aufbau:**
```swift
@State private var isSheetPresented = false
@State private var sheetDetent: PresentationDetent = .height(140)
```
```swift
.sheet(isPresented: $isSheetPresented) {
    RouteStopSheetView(route: primaryRoute, selectedStopID: $selectedStopID, onStopTap: { port in
        selectedStopID = port.id
        zoomTo(routes: [(index: ..., cruise: ...)])   // bestehende zoomTo-Logik, einzelner Port-Koordinate
        sheetDetent = .height(140)                     // Kamera-Sprung kollabiert das Sheet auf Peek
    })
    .presentationDetents([.height(140), .medium, .large], selection: $sheetDetent)
    .presentationBackgroundInteraction(.enabled(upThrough: .medium))
    .presentationCornerRadius(DesignRadius.lg)
    .presentationDragIndicator(.visible)
    .presentationBackground(.regularMaterial)   // s.u., Kompromiss statt Custom-Solid-Color
}
```
- **Peek (140pt):** Routentitel (`.headline`) + Substats
  (`"7 Tage · 4 Häfen · 3 Länder"`, identischer Aufbau wie bisherige
  `routeSelectionCard`-Kopfzeile) — **ersetzt** die bisherige
  `.ultraThinMaterial`-Overlay-Karte vollständig, die entfällt.
- **Medium:** + scrollbare Stop-Liste (siehe Stop-Row-Anatomie unten).
- **Large:** + Button „Öffnen" (bestehender String, bestehendes Verhalten —
  `NavigationLink`/Navigation zu `CruiseDetailView`) am unteren Sheet-Rand.
  Das ist die einzige verbleibende Stelle, an der die volle Detailansicht
  erreichbar ist — vorher ging das direkt aus der Bottom-Card, jetzt aus dem
  aufgeklappten Sheet.
- **Hintergrund-Kompromiss:** Volles „Warmes Papier"-Solid
  (`Color.journalSurface`) für das Sheet ist die Zielästhetik, birgt aber
  ein technisches Risiko: `.presentationBackground(Color(...))` deaktiviert
  einige System-Verhaltensweisen (z. B. automatische Anpassung an
  Dynamic-Type-Randfälle) weniger zuverlässig als `.regularMaterial`. Für
  Version 1 dieses Umbaus **`.presentationBackground(.regularMaterial)`**
  verwenden (nativ, adaptiert automatisch hell/dunkel, geringes Risiko) —
  der volle warme Solid-Ton (`Color.journalSurface`) ist eine mit Winston
  abzustimmende Politur-Nachbesserung, kein Blocker für diesen Umbau.

**Stop-Row-Anatomie** (jede Zeile min. 56pt hoch, gesamte Zeile tappbar):
- **Leading (32pt Kreis):** `MapStopBadgeView` für reguläre Zwischenstopps,
  `PortPinView`-Icon-in-Kreis für Start/Ende-Rollen — visuell identisch zu
  den Karten-Markern, nur kleiner.
- **Mitte:** Hafenname (`.body.weight(.semibold)`), darunter Land/Zeitraum
  (`.caption`, sekundär).
- **Trailing (40×40pt):** `AsyncPhotoView` falls `port.imageData` vorhanden,
  sonst SF-Symbol `"mappin"` in gedämpftem Kreis (`Color.journalSurfaceAlt`
  oder `.gray.opacity(0.15)`).
- **Ausgewählter Stopp** (`selectedStopID == port.id`): Zeilenhintergrund
  `Color.routeColor(at: index).opacity(0.12)`, Badge erhält weißen Ring
  (spiegelt das bestehende Selected-Highlight der Karten-Pins).
- **Timeline-Linie:** gepunktete vertikale Linie (`Color.journalTimeline`)
  links neben den Badges, verbindet die Reihen optisch zur Route.

### 6. Dark Mode

- Chrome-Buttons: identischer Navy-Solid-Ton hell/dunkel (kein Wechsel nötig
  — navyDark funktioniert in beiden Modi als Kontrastfläche).
- Sheet: `.regularMaterial` adaptiert automatisch; `journalSurface`-Fallback
  (falls später doch Custom-Solid gewählt wird) nutzt `journalSurfaceDark`
  (#15212E) statt `journalSurfaceLight`.
- Pin-Halo: `journalSurface` statt hartem `.white` — im Dunkelmodus dadurch
  automatisch dunkler statt eines grellen weißen Rings auf dunkler Karte
  (Verbesserung ggü. Ist-Zustand, der `.white` fix hartkodiert hatte).
- Routen-Opazitäten (0.85/0.35) unverändert für beide Modi — bereits im
  Ist-Zustand modusunabhängig gehalten, kein AA-Kontrastproblem, da Linien
  keine Textinhalte sind.

## Was fällt weg

- Filter-Menü oben links (`routeCircleMenu`, Icon
  `line.3.horizontal.decrease.circle`) — ersatzlos entfernt, Funktion geht
  im neuen Burger-Menü (jetzt oben rechts) auf.
- Bottom-Info-Card (`routeSelectionCard`, `.ultraThinMaterial`-Overlay,
  `MapView.swift:287–347`) — vollständig ersetzt durch den Sheet-Peek-Zustand.
- „Routen"-Capsule-Button innerhalb der alten Bottom-Card
  (`routeMenu`-Variante mit `Label("Routen", systemImage: "slider.horizontal.3")`) —
  entfällt, Funktion geht im Burger-Menü auf.
- Direkter `NavigationLink`-Sprung von der Bottom-Card zu `CruiseDetailView`
  bei Einzelauswahl — wird zum „Öffnen"-Button am Fuß des `.large`-Sheets.

## Neue user-sichtbare Strings (DE + EN)

| Key/Kontext | DE | EN |
|---|---|---|
| Burger-Zeile „alle ausblenden" | „Alle ausblenden" | "Hide all" |
| Burger-Zeile „alle einblenden" | *(bestehender String wiederverwendet:)* „Alle Reisen anzeigen" | *(bestehend)* "Show all trips" |
| Leerzustand Titel | „Alle Routen ausgeblendet" | "All routes hidden" |
| Leerzustand Untertitel | „Tippe auf das Menü, um Routen einzublenden" | "Tap the menu to show routes" |
| A11y-Label Burger-Button | „Routenauswahl" | "Route selection" |
| Sheet-Listenüberschrift (optional, falls Section-Header gewünscht) | „Stopps" | "Stops" |

„Öffnen" (Sheet-CTA) nutzt den bereits existierenden lokalisierten String
wieder — kein neuer Key.

## Barrierefreiheit

- Alle Chrome-Buttons ≥ 44×44pt Touch-Target (42pt Kreis + Padding erfüllt
  das knapp — bei Umsetzung auf effektive 44pt Hit-Area prüfen, ggf.
  `.contentShape(Circle())` mit größerem Rahmen).
- Stop-Rows: min. 56pt Höhe, klar über dem 44pt-Minimum.
- Kontrast: `journalSurfaceLight` (#FBF7F0) gegen `Color.navyDark`-Text
  (#1A365D) liegt deutlich über 4.5:1 (nahezu weiß gegen sehr dunkles Navy).
  `journalSurfaceDark` (#15212E) gegen weißen Text ebenfalls unkritisch —
  vor Umsetzung trotzdem mit einem Kontrastrechner gegenprüfen, da hier neue
  Farbpaare sind (Vorgabe aus `design-library/references/systems/color-systems.md`).
- VoiceOver-Reihenfolge im Sheet: Titel → Substats → Stop-Liste (top-down,
  keine Custom-Sortierung nötig, `List`/`ScrollView` liefert das nativ).
- Burger-Menü-Items behalten ihre bestehenden Accessibility-Labels
  (Routennamen); neue Alle-ausblenden-Zeile braucht kein zusätzliches Label
  über den sichtbaren Text hinaus (Label = Text, das reicht).

## Akzeptanzkriterien

- [ ] Routen werden als sichtbar kurvige Linien gerendert (Catmull-Rom durch
      alle validen Wegpunkte), nicht mehr als gerade Segmente.
- [ ] Burger-Menü-Button existiert oben rechts; Standardzustand zeigt alle
      Routen; ein Tap auf die Alle-Zeile blendet alle aus; ein weiterer Tap
      blendet alle wieder ein.
- [ ] Einzelne Route lässt sich weiterhin per Tap in der Liste ab-/anwählen;
      die letzte verbleibende Route kann nicht per Einzel-Tap auf null
      reduziert werden (nur über die Alle-Zeile).
- [ ] Tap auf eine Route (Linie und/oder deren Marker, siehe offene Frage
      unten) öffnet ein Bottom-Sheet mit Peek/Medium/Large-Detents; die Karte
      bleibt bis einschließlich `.medium` bedienbar
      (`presentationBackgroundInteraction(.enabled(upThrough: .medium))`).
- [ ] Tap auf einen Stopp im Sheet springt die Kartenkamera zu diesem Ort und
      kollabiert das Sheet auf den Peek-Zustand.
- [ ] Recenter-Button (bestehende Funktion) ist weiterhin erreichbar (jetzt
      oben links).
- [ ] Hell- und Dunkelmodus beide geprüft: neue `journalSurface`/
      `journalTimeline`-Töne, Pin-Halo, Chrome-Buttons.
- [ ] Bestehende Unit-Tests (`MapMarkerPlannerTests`, `MapZoomAndSelectionTests`)
      weiterhin grün; neue Tests für `RouteCurveSampler` (Degenerierte Fälle,
      Punkte-Deckel, Spline läuft durch Original-Wegpunkte) und für die neue
      `allRoutesHidden`/`activeRouteIDs`-Logik (analog zum bestehenden
      `MapSelectionPlanner`-Testmuster).

## Offene Fragen für Developer/Winston

- **Route-Tap-Hit-Testing:** Die `MapReader`-Koordinatenkonvertierung +
  Punkt-zu-Kurve-Distanzsuche ist der empfohlene Ansatz, aber ungetestet in
  diesem Codebase. Falls sie sich als unzuverlässig/aufwändig erweist, ist
  „Sheet öffnet nur über Pin/Badge-Tap" ein akzeptabler Minimalscope für v1
  (siehe Abschnitt 5) — bitte im Quality-Review-Artefakt vermerken, welche
  Variante tatsächlich gelandet ist.
- **Schatten-Underlay-Polyline** (Abschnitt 3) ist eine Politur-Nice-to-have,
  kein Blocker — bei Performance-Bedenken (mehrere Routen × 2 Polylines)
  auslassbar.
- **`.presentationBackground`**: `.regularMaterial` ist der für v1 gewählte
  Kompromiss statt vollem `journalSurface`-Solid — falls der Developer beide
  Varianten schnell durchprobieren kann, ist der volle Solid-Ton (näher an
  der Zielästhetik) willkommen, aber nicht Pflicht für die Akzeptanz.
