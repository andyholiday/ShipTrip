# Design Spec — Karten-UI-Politur Welle C (Tester-Feedback Build 16)

> Designer-Output, verbindlich für den Developer. Tokens/Werte hier sind bindend —
> Abweichungen sind eine Rückfrage, keine Improvisation.
>
> Referenzen: `.planning/testflight-feedback-2026-07-10/2026-07-10-build16-01..04.png`,
> `.planning/karten-redesign-v2-spec.md` (Vorläufer-Spec „Journal Atlas"),
> `.planning/karten-redesign-v2-tokens.json` (Farb-/Radius-Basistokens, unverändert übernommen).

## Scope

- **Feature/Flow:** Karten-Tab (`MapView`) — Routen-Burger-Menü, Routen-Detail-Sheet
  (Swipe-up), Marker-Darstellung im mittleren Zoom.
- **Adressierte Tester-Findings:** F2 (Burger-Menü), F3 (Routen-Sheet-Optik + Swipe),
  F4 (mittlerer Zoom — Stops nicht lesbar).
- **Screens/Views betroffen:** `MapView.swift`, `MapView+RouteInteraction.swift`,
  `MapZoomBucketPlanner.swift`, `MapStopBadgeView.swift`, `RouteStopSheetView.swift`.
- **Out of scope:** `MapSelectionPlanner.swift`-Kernsemantik (Selection-Clear bleibt an
  `.world` gebunden), `MapRouteVisibilityPlanner.swift` (Sichtbarkeitslogik unverändert),
  `MapCalloutView.swift` (unverändert — kein Feedback dazu), `ContentUnavailableView`/
  `allRoutesHiddenOverlay` (bestehende Empty-States, nicht angefasst), Routen-Kurven-
  Interpolation (`MapRouteCurveSampler.swift`), Loop-Schutz Karte↔Liste (bereits gelöst,
  nicht Teil dieser Welle).

## Design decisions (die „Warum")

- **F2 — Popover statt hand-gebautem Overlay:** ein systemeigenes `.popover` gibt uns
  Dismiss-on-outside-tap, VoiceOver-Fokus-Trap und Escape-Geste umsonst (Nielsen #6
  „Recognition over recall" für Systemkonsistenz) und lässt uns trotzdem Breite,
  Hintergrund und Radius voll steuern — weniger Custom-Code als ein manueller
  Fullscreen-Tap-Catcher, gleiches visuelles Ergebnis.
- **F2 — Icon-Kreis 24pt statt 20pt:** ein Checkmark in einem 20pt-Kreis schrumpft auf
  ~10–12pt und wird auf kompakten Displays zu Pixelbrei (Gemini-Gate #5a, verifiziert
  gegen `typography-scale.md`: Text/Icon-Elemente unter 11pt sind eine HIG-Smell).
- **F3 — kein separater „Spine"-Akzentstrich:** kollidiert visuell mit dem nativen
  Sheet-Grabber (Gemini-Gate #5a). Restraint-Regel aus `microinteractions.md` („one hero
  moment, everything else stays subtle") — Routenfarbe kommuniziert bereits über Badge-
  Gradient + Auswahl-Chip, ein drittes Akzent-Element ist redundant.
- **F3 — `.presentationContentInteraction(.resizes)`:** löst den ScrollView-vs-Sheet-
  Drag-Konflikt („hakeliges Runterswipen") mit einer System-API statt eigener Gesture-
  Logik — genau das dafür vorgesehene Werkzeug (Apple-Doku: Drag im Content resized bis
  Max-Detent, danach scrollt es).
- **F4 — zwei Buckets bleiben zwei Buckets, kein drittes „region"-Badge:** ein 18pt-Kreis
  kann eine zweistellige, 11pt-fette Zahl nicht verlustfrei aufnehmen (Text ~14–15pt breit
  auf 18pt Kreisdurchmesser — läuft über den Rand). Der bestehende 22pt-Badge ist bereits
  bewährt (keine Lesbarkeits-Beschwerde für den Reise-Zoom); ihn einfach früher zu zeigen
  löst F4 ohne neue Größenklasse und ohne neues Lesbarkeits-Risiko.
- **F4 — Schwelle 20° statt latitude-unkorrigiert 10°:** `MapZoomBucketPlanner.swift:23-27`
  dokumentiert bereits zwei Anker aus dem ursprünglichen Design-Deck — „Welt-Zoom bei Span
  > 20°, Reise-Zoom bei Span < 5°"; der binäre 10°-Kompromiss (geometrisches Mittel) war
  nur nötig, weil es damals nur die zwei Sichtbarkeits-Zustände gab. Mit dem neuen Overlap-
  Handling (siehe F4 unten) kann der ursprüngliche 20°-Weltzoom-Anker direkt verwendet
  werden — das ist keine neue Zahl, sondern die Rückkehr zur eigenen Deck-Vorgabe.
- **F4 — Breitengrad-Korrektur der Span-Formel:** ein reiner Grad-Span überschätzt die
  visuelle Breite in höheren Breiten (Mercator-Stauchung) — bei ShipTrip-relevanten
  Breiten (Nordnorwegen bis ~70°N) ein realer, aber bislang unkorrigierter Effekt
  (Gemini-Gate #5a). Korrektur mit `cos(centerLatitude)` auf den Längengrad-Span ist eine
  Ein-Zeilen-Änderung, keine Architektur-Änderung, und hält `MapZoomBucketPlanner` weiter
  SwiftUI-frei/pur testbar.
- **F4 — Overlap-Cluster statt nativem MapKit-Clustering:** geprüft und verworfen. Die
  eigene Recherche `.planning/b4-fertigloesungen-research.md:65` dokumentiert bereits,
  dass SwiftUI `Map` (Stand 2026) kein Cluster-Äquivalent zu UIKit hat —
  `clusteringIdentifier` existiert nur auf `MKMarkerAnnotationView` (UIKit). Gemini-Gate
  #5a schlug dies vor, die Prämisse ist für den hier verwendeten SwiftUI-`Map`-Typ nicht
  zutreffend; verworfen zugunsten eines leichten Eigenbaus (paarweiser Geo-Vergleich,
  siehe unten — bei ShipTrips Datengröße ≤20 Stops trivial günstig, kein Performance-
  Grund für eine eingeschränktere Routenreihenfolge-Variante, siehe Gate #5b-Korrektur).
- **F4 — Konsolidiertes VoiceOver-Label unabhängig vom Zoom-Bucket:** blinde Nutzer sind
  nicht an das sichtbare Zoom-Level gebunden — sie bekommen immer den vollen Datensatz
  (Nummer + Name + Land), auch wenn sehende Nutzer bei diesem Zoom nur einen Dot sehen
  (`patterns/accessibility.md` — „Meaningful images/icons get labels"). Behebt nebenbei
  einen bestehenden Bug: `MapView+RouteInteraction.swift:58` überschreibt aktuell das
  Label aus `MapStopBadgeView` komplett, VoiceOver liest heute nie die Stopp-Nummer vor.

## Tokens (bindend)

Vollständiger Satz: `.planning/karten-politur-c-tokens.json` (Delta zu
`karten-redesign-v2-tokens.json`, dessen Farb-/Radius-Basiswerte unverändert gelten).
Kernwerte für den menschlichen Leser:

| Token | Wert (Light) | Wert (Dark) |
|-------|---------------|--------------|
| menu.panel.background | `Color.journalSurface` (opak, `#FBF7F0`) | `Color.journalSurface` (opak, `#15212E`) |
| menu.panel.radius | `DesignRadius.md` (16pt) | gleich |
| menu.panel.maxWidth | 300pt | gleich |
| menu.row.minHeight | 44pt | gleich |
| menu.icon.diameter | 24pt | gleich |
| menu.allRow.tint | `Color.oceanBlue.opacity(0.06)` | `Color.oceanBlue.opacity(0.10)` |
| sheet.badge.gradient | `routeColor → routeColor.opacity(0.75)` | gleich |
| sheet.selectedChip.radius | 10pt (`DesignRadius.sm`) | gleich |
| sheet.selectedChip.border | `routeColor.opacity(0.35)`, 1pt | gleich |
| sheet.pinPlaceholder.fill | `Color.navyDark.opacity(0.05)` | `Color.white.opacity(0.06)` |
| sheet.pinPlaceholder.border | `Color.navyDark.opacity(0.14)`, 1pt | `Color.white.opacity(0.16)`, 1pt |
| map.worldThreshold | 20.0° (latitude-korrigiert) | gleich |
| map.cluster.collisionDistance | 28pt (Bildschirm) | gleich |
| map.tapTarget.min | 44×44pt (alle Marker-Varianten) | gleich |
| motion.popover.enter/exit | System-Default (`.popover`) | gleich |
| motion.badge/chip | kein neues Motion-Token — keine zusätzliche Animation eingeführt | — |

## Screens & states

Alle drei Findings sind Politur an bereits produktiven Komponenten, kein neuer Screen.
Betroffen sind ausschließlich der „default"-Zustand dieser Komponenten — bestehende
Empty/Loading/Error-States (`ContentUnavailableView`, `allRoutesHiddenOverlay`) sind
unverändert und nicht Teil dieser Welle.

| Screen/Komponente | Mockup-Ref | Empty | Loading | Error |
|---|---|---|---|---|
| Burger-Menü-Popover | dieses Dokument, F2 | – (immer ≥1 Route, sonst Menü-Button gar nicht sichtbar) | – | – |
| Routen-Sheet | dieses Dokument, F3 | – (Sheet erscheint nur bei vorhandener `primaryRoute`) | – | – |
| Marker/Cluster | dieses Dokument, F4 | – | – | – |

---

## F2 — Burger-Menü (Routenauswahl)

### IST-Kritik

Natives SwiftUI `Menu` (`MapView.swift:220-231`) rendert bei 7 Routen ein bis zu
bildschirmfüllendes, halbtransparentes Panel. Lange Cruise-Titel (z. B. „14 Nächte -
Kanaren, Madeira und marokkanisches Flair - ab/bis Gran Canaria") brechen dreizeilig um.
Auswahl-Icons wechseln zwischen zwei unterschiedlichen Glyphen-*Formen*
(`"checkmark"` vs. `"circle"`, `MapView.swift:250`) statt zwischen zwei Zuständen
derselben Form — wirkt unruhig. Der `Menu`-Systemhintergrund ist transparent genug, dass
der „Karte"-Titel dahinter durchscheint (Screenshot 02).

### SOLL-Design

Eigenes Popover-Panel statt nativem `Menu`, inhaltlich vollständig selbst gebaut, aber
über `.popover` präsentiert (System übernimmt Dismiss/Fokus/Accessibility).

**Layout**
- Container: `VStack(spacing: 0)`, max. Breite **300pt**, Hintergrund **opak**
  `Color.journalSurface` (kein Material — das war die Ursache des Durchscheinens),
  Corner-Radius **16pt** (`DesignRadius.md`), Schatten „overlay"-Level
  (`elevation-radii.md`: y=4, blur=16, ~12–16 % Schwarz).
- Reihenfolge unverändert: „Alle anzeigen/ausblenden"-Zeile → Trennlinie
  (`Color.journalTimeline`, bestehendes Token) → Routenliste.

**„Alle anzeigen/ausblenden"-Zeile**
- Eigene Optik zur Abgrenzung von der Liste: Hintergrund-Tint
  `Color.oceanBlue.opacity(0.06)` (Light) / `0.10` (Dark), Label **semibold**, Icon
  `eye.fill`/`eye.slash.fill` (unverändert), Zeilenhöhe ≥ 44pt.

**Routenzeilen**
- Ein Icon-*System*, zwei Zustände derselben Form: 24pt-Kreis in `Color.routeColor(at:
  index)` — **gefüllt + weißer Checkmark** wenn aktiv, **nur 1.5pt-Outline** (keine
  Füllung) wenn inaktiv. Kein Formwechsel mehr zwischen den Zuständen. Kopplung
  Menü-Farbe ↔ Kartenfarbe (Wiedererkennung, Nielsen #6).
- Titel: `.subheadline` (15pt), **einzeilig**, `.lineLimit(1)` +
  `.truncationMode(.middle)` (harte Vorgabe „einzeilig" aus dem Auftrag bleibt erfüllt;
  `.middle` statt `.tail` — Gemini-Gate #5b — hält den unterscheidenden Suffix sichtbar,
  z. B. „14 Nächte – Kana…ab Teneriffa" statt „14 Nächte – Kana…" bei zwei Routen mit
  identischem Präfix aber unterschiedlichem Abfahrtshafen). 300pt Panel-Breite abzüglich
  Icon+Padding ergibt ~34–38 sichtbare Zeichen. Zwei Routen mit identischem Präfix UND
  identischem Suffix bleiben ein Restrisiko (siehe Offene Punkte).
- Zeilenhöhe ≥ 44pt, horizontales Padding 16pt, vertikaler Row-Abstand 4pt (Spacing-Grid).

**Interaktion**
- `.popover(isPresented: $isRouteMenuOpen, attachmentAnchor: .rect(.bounds), arrowEdge:
  .top) { menuPanelContent }` am `burgerMenu`-Button.
- `.presentationCompactAdaptation(.popover)` — erzwingt echtes Popover-Verhalten auf
  iPhone (sonst fällt SwiftUI bei kompakter Breite auf Sheet-Darstellung zurück, die auf
  iPhone immer Full-Width ist und damit die harte Vorgabe „definierte max. Breite" nicht
  erfüllen kann).
- **Höhenbegrenzung verschärft** (Gemini-Gate #5b — auf iPhone SE/Mini kann ein zu hohes
  Popover fast den ganzen Screen blockieren): Panel-Höhe ≤ `min(0.45 × Bildschirmhöhe,
  380pt)` statt einer vagen „~60 %"-Angabe; bei Überlauf scrollt die Routenliste intern
  innerhalb des Panels.
- `.presentationBackground(Color.journalSurface)` + `.presentationCornerRadius(16)` auf
  dem Popover-Content (beide Modifier sind seit iOS 16.4 auch für `.popover` gültig, nicht
  nur `.sheet`).
- Mehrfach-Toggle ohne Zwischenschließen bleibt erhalten: kein Auto-Dismiss bei
  Row-Tap (eigener `@State`-getriebener Inhalt statt `Menu`s eingebautem
  Dismiss-Verhalten — `menuActionDismissBehavior` entfällt ersatzlos, da nicht mehr
  `Menu`-basiert).
- Tap außerhalb schließt (System-Standard von `.popover`); dass danach ein zweiter Tap
  für die Karten-Interaktion nötig ist, ist Standard-Modal-Verhalten und identisch zum
  heutigen `Menu` — keine Regression.

### SwiftUI-Umsetzungshinweise

- `@State private var isRouteMenuOpen = false` in `MapView`, Button-Action von
  `burgerMenu` togglet dies statt `Menu` zu öffnen.
- Bestehende `routeMenuItems`-Logik (`MapView.swift:233-253`) wird zu einer eigenen
  `RouteMenuPanelView` (analog zu `RouteStopSheetView` als eigene Datei) mit denselben
  Daten (`routableCruises`, `activeRouteIDs`, `toggle(route:)`,
  `toggleAllRoutesVisibility()`) — reine Präsentationsverschiebung, keine neue Logik in
  `MapRouteVisibilityPlanner`.
- `chromeButton`-Inset-Pattern (`MapView.swift:204`,
  `.contentShape(Circle().inset(by: -1))`) als Vorbild für den 44pt-Touch-Bereich der
  24pt-Auswahl-Icons wiederverwenden.

### Akzeptanzkriterien

- [ ] Popover-Panel ist bei jeder Routenanzahl (1 bis N) nie höher als
      `min(0.45 × Bildschirmhöhe, 380pt)` (internes Scrollen ab Überlauf), auch auf
      iPhone SE/Mini verifiziert.
- [ ] Panel-Hintergrund ist bei keinem Farbschema/keiner Kartenposition durchscheinend
      (opak, `Color.journalSurface`).
- [ ] Kein Routentitel bricht mehrzeilig um; alle enden ggf. mit „…".
- [ ] Auswahl-Icon ist in beiden Zuständen ein Kreis (aktiv gefüllt, inaktiv Outline) —
      keine Formänderung.
- [ ] Drei aufeinanderfolgende Einzel-Toggles schließen das Panel nicht zwischendurch.
- [ ] VoiceOver liest jede Zeile als „Route, {Titel}, {ausgewählt/nicht ausgewählt}".

---

## F3 — Routen-Detail-Sheet (Swipe-up)

### IST-Kritik

`RouteStopSheetView.swift` ist optisch flach: einfarbige orange Nummern-Badges
(`MapStopBadgeView.swift:19-28`), generisch-graue Pin-Platzhalter
(`RouteStopSheetView.swift:134-138`, `Color.gray.opacity(0.15)`), Auswahl-Highlight ist
ein randloser Full-Bleed-Wash (`RouteStopSheetView.swift:107`). Swipe-Runter fühlt sich
hakelig an — die `ScrollView` der Stop-Liste (`RouteStopSheetView.swift:65-73`) konkurriert
vermutlich mit dem Sheet-eigenen Drag-Gesture um denselben Touch, da weder
`.presentationContentInteraction` noch `.scrollBounceBehavior` gesetzt sind.

### SOLL-Design

Warme, „papierne" Tiefe statt echtem Liquid-Glass (Deployment-Target iOS 18.5, `.glass*`-
APIs sind iOS 26+) — Tiefe über Gradient, Kontur und Chip-Form statt Blur-Material.

**Badges**
- `MapStopBadgeView` bekommt einen dezenten Fill-Gradient statt Flat-Fill:
  `LinearGradient(colors: [routeColor, routeColor.opacity(0.75)], startPoint:
  .topLeading, endPoint: .bottomTrailing)`. Größe (22pt), Font (`.caption2.weight(.bold)`),
  Stroke-Ring bei Auswahl (3pt weiß) **unverändert** — bewährte Werte, kein neues
  Lesbarkeits-Risiko.

**Auswahl-Zeile (Chip statt Full-Bleed)**
- `RoundedRectangle(cornerRadius: 10)` (`DesignRadius.sm`), Fill `routeColor.opacity(0.12)`
  (unverändert), **neu:** 1pt-Rand `routeColor.opacity(0.35)`, horizontales Inset 4pt
  gegenüber der Row-Kante — wirkt als schwebender Chip statt als Screen-breiter Wisch.

**Pin-Platzhalter (kein Foto vorhanden)**
- Ersetzt `Color.gray.opacity(0.15)` durch Fill `Color.navyDark.opacity(0.05)` (Light) /
  `Color.white.opacity(0.06)` (Dark) **plus** 1pt-Rand `Color.navyDark.opacity(0.55)`
  (Light) / `Color.white.opacity(0.40)` (Dark) — reine Hairline ohne Fill hat auf dem
  hellen `journalSurface`-Ton bei Sonnenlicht zu wenig Kontrast (Gemini-Gate #5a).
  **Korrektur nach Gate #5b:** die ursprünglich vorgeschlagenen Werte (0.14 Light / 0.16
  Dark) UND Gemini's eigener Korrekturvorschlag (0.30) wurden gegen die
  sRGB-Relativluminanz-Formel nachgerechnet — 0.14 ergibt rechnerisch nur **~1.3:1**,
  auch 0.30 bleibt mit **~1.8:1** unter dem 3:1-Ziel; erst ab ~0.5–0.55 (Light) bzw.
  ~0.35–0.4 (Dark) wird 3:1 überschritten. Die hier gesetzten Werte (0.55/0.40) liegen
  mit Sicherheitsabstand darüber. Handrechnung, kein Ersatz für echte Messung — vor
  Merge mit Accessibility Inspector in Light UND Dark verifizieren (siehe Offene Punkte).

**Kein separater Farbakzent-Strich** über dem Header (im Konzept verworfen, siehe Design
Decisions — kollidiert mit dem nativen Grabber).

**Swipe-Verhalten**
- `.presentationDetents([.height(140), .medium, .large], selection: $sheetDetent)` bleibt
  unverändert.
- **Neu:** `.presentationContentInteraction(.resizes)` auf dem Sheet-Content — Drag
  irgendwo im Content resized das Sheet bis zum größten Detent, danach übernimmt
  Scrollen. Das ist der direkte, System-eigene Fix für „Runterswipe funktioniert noch
  nicht so gut". **Wichtig für die Umsetzung (Gate #5b geprüft):** das gilt auch für
  Aufwärts-Drags — ein Swipe nach oben INNERHALB der Liste expandiert zuerst das Sheet
  bis `.large`, erst danach scrollt die Liste selbst. Das ist der dokumentierte,
  gewollte Vertrag von `.resizes` (Apple-Doku), kein Bug — nicht versehentlich
  „reparieren", indem `.resizes` durch `.automatic` ersetzt wird (das würde den
  eigentlich zu behebenden Downward-Swipe-Konflikt wieder zurückbringen).
- **Neu:** `.scrollBounceBehavior(.basedOnSize)` auf der `ScrollView` in `stopList`
  (`RouteStopSheetView.swift:65`) — verhindert Rubber-Banding bei kurzen Listen, das
  sonst zusätzlich mit dem Sheet-Drag um den Touch konkurriert.

**iOS-26-Kür (optional, nicht Pflicht)**
```swift
if #available(iOS 26, *) {
    // .presentationBackground { RoundedRectangle(cornerRadius: 28).fill(.clear).glassEffect() }
    // nur als zusätzliches Upgrade, Fallback bleibt .regularMaterial (iOS 18.5-Basis)
}
```

### SwiftUI-Umsetzungshinweise

- Änderungen ausschließlich in `MapStopBadgeView.swift` (Gradient-Fill),
  `RouteStopSheetView.swift` (Chip-Rand, Pin-Platzhalter-Farben,
  `.presentationContentInteraction`, `.scrollBounceBehavior`) und dem `.sheet {}`-Block
  in `MapView.swift:89-113` (Modifier-Ergänzung).
- `.presentationContentInteraction` und `.presentationBackground`/
  `.presentationCornerRadius` bleiben auf dem `.sheet`-Aufruf in `MapView.swift`
  (bestehende Stelle), nicht in `RouteStopSheetView` selbst — Presentation-Modifier
  gehören an den Präsentierenden, nicht an den präsentierten Content.

### Akzeptanzkriterien

- [ ] Drag-Geste irgendwo im sichtbaren Sheet-Bereich (Header ODER Liste) resized das
      Sheet bis `.large`, ohne dass die Liste zwischendurch unkontrolliert mitscrollt.
- [ ] Ab `.large` scrollt ein weiterer Downward-Drag die Liste normal (kein Blockieren).
- [ ] Badges zeigen sichtbaren Gradient (kein Flat-Fill mehr) in Light UND Dark.
- [ ] Ausgewählte Stop-Zeile ist als abgesetzter Chip erkennbar (Rand + Inset), nicht als
      Full-Bleed-Band.
- [ ] Pin-Platzhalter erreichen ≥ 3:1 Kontrast gegen `journalSurface` in Light UND Dark
      (Accessibility-Inspector-Check).
- [ ] Kein zusätzliches Akzent-Element kollidiert visuell mit dem System-Grabber.

---

## F4 — Mittlerer Zoom: Stops nicht lesbar

### IST-Kritik

`MapZoomBucketPlanner` (`MapZoomBucketPlanner.swift:29-31`) ist binär: `max(span.lat,
span.lon) > 10° → .world` (nur 9pt-Dot, `MapView+RouteInteraction.swift:87-93`, ohne
Nummer/Namen), sonst `.route` (volle 22pt-Badges/Rollen-Pins). Der 10°-Schwellenwert war
laut Code-Kommentar (`MapZoomBucketPlanner.swift:23-27`) selbst nur ein Kompromiss
(geometrisches Mittel aus den ursprünglichen Deck-Ankern 5°/20°) — der Tester-Screenshot
bei mittlerem Zoom (Kanaren/Madeira/Marokko-Küste) liegt im 10–20°-Bereich und fällt
dadurch in den `.world`-Fall, obwohl das ursprüngliche Deck diesen Bereich eigentlich noch
als „Reise-Zoom" vorgesehen hatte. Zusätzlich hat der Welt-Dot (`worldDotView`,
`MapView+RouteInteraction.swift:87-93`) **keinen** `.contentShape`-Inset — die Tap-Fläche
ist real ~9–12pt statt der geforderten 44pt (bestehender Bug, nicht nur Politur). Das
VoiceOver-Label der Stopp-Nummer wird aktuell nie vorgelesen, weil
`MapView+RouteInteraction.swift:58` das Label aus `MapStopBadgeView` mit
`role.port.name` überschreibt (SwiftUI: das Label des äußeren `Button` verdrängt das des
inneren `Text`).

### SOLL-Design

**Kein drittes visuelles Bucket.** Zwei Buckets bleiben zwei Buckets — `.world` (Dot) und
`.route` (volle Badges/Pins, **unverändert** in Größe/Optik). Gelöst wird F4 stattdessen
über (a) eine korrigierte, höhere Schwelle und (b) ein leichtes Overlap-Cluster
ausschließlich innerhalb von `.route`.

**Schwellenwert-Formel (ersetzt `MapZoomBucketPlanner.threshold`)**
```
effectiveSpan = max(span.latitudeDelta, span.longitudeDelta * cos(centerLatitude * .pi / 180))
bucket = effectiveSpan > 20.0 ? .world : .route
```
- **20.0°** ist der ursprüngliche „Welt-Zoom"-Anker aus dem Design-Deck
  (`MapZoomBucketPlanner.swift:24`), nicht neu erfunden.
- `cos(centerLatitude)` korrigiert die Mercator-Stauchung des Längengrad-Spans in
  höheren Breiten (relevant für Nordnorwegen-Routen bis ~70°N). Bei Äquatornähe ist die
  Korrektur ein No-op (`cos(0°) = 1`).
- `MapZoomBucketPlanner.bucket(for:)` bekommt einen zweiten Parameter
  `centerLatitude: Double` — bleibt SwiftUI-frei und pur testbar (bestehendes Muster).
  Beide Call-Sites (`MapView.swift:57` im `.onMapCameraChange`, `MapView.swift:355` in
  `zoomTo(coordinates:)`) haben `region.center.latitude` bereits im Scope.

**Was pro Band sichtbar ist**

| Band | Span (korrigiert) | Sichtbar | Tap-Ergebnis |
|---|---|---|---|
| `.route` | ≤ 20° | volle 22pt-Badges (Nummer immer sichtbar) bzw. Rollen-Pins | Callout (Name+Foto) + Sheet-Peek |
| `.world` | > 20° | 9pt-Dot, kein Text | Callout (Name+Foto) + Sheet-Peek (unverändert) |

**Overlap-Strategie (neu, nur innerhalb `.route`)**

Wenn zwei oder mehr Stops derselben Route auf dem Bildschirm näher als **28pt**
beieinander projizieren (22pt Badge-Durchmesser + 6pt Mindestabstand, `spacing-grid.md`),
wird nur der erste (niedrigste Stop-Nummer der Gruppe) als normales Badge gezeigt; die
übrigen werden zu einem kleinen **„+N"-Pill** zusammengefasst, der am Badge andockt
(Offset +14/+10pt, `Capsule()`, Hintergrund `Color.navyDark`, weißer `.caption2`-Text,
Höhe 20pt).

**Geografisch-paarweiser Vergleich, nicht Routenreihenfolge (korrigiert nach Gate #5b):**
ursprünglich war hier ein linearer Scan „nur direkte Routen-Nachbarn clustern" geplant,
um O(n²) zu vermeiden — das übersieht aber reale ShipTrip-Fälle wie Rundreisen, die
denselben Zielhafen an zwei nicht aufeinanderfolgenden Tagen anlaufen (z. B. Mallorca →
Ibiza → Mallorca-Region erneut), wo geografisch nahe, aber routenreihenfolge-ferne Stops
sonst unclustered überlappen würden. Der Distanzvergleich läuft daher **paarweise über
alle Stops einer Route** (Union-Find/Greedy-Grouping, unabhängig von der Stop-Reihenfolge).
Bei ShipTrips Datengröße (max. ~20 Stops pro Route, `.planning/b4-fertigloesungen-
research.md:75`) sind das im Worst Case ~190 Vergleiche — auf einem iPhone im
Mikrosekundenbereich, vernachlässigbar. Die Berechnung läuft weiterhin nur einmal pro
Gesten-Ende (`.onMapCameraChange(frequency: .onEnd)`, bereits bestehend) plus synchron in
`zoomTo(coordinates:)`, nicht pro Frame.

**Ein Tap-Target pro Cluster, nicht zwei (korrigiert nach Gate #5b):** Badge (22pt,
gecapped auf 44pt Hit-Fläche) und „+N"-Pill (Offset nur 14/10pt) liegen bei einer
44×44pt-Mindest-Tap-Fläche fast vollständig übereinander — eine treffsichere Unter-
scheidung „Badge tippen = Callout, Pill tippen = Zoom" ist am Touchscreen nicht
zuverlässig möglich. Stattdessen: **Badge + Pill bilden EIN gemeinsames Tap-Target**
(eine `.contentShape` über die kombinierte Bounding-Box). Jeder Tap darauf zoomt/
rezentriert auf `MKCoordinateRegion(coordinates:)` (bestehender Initializer,
`MapView.swift:366-401`) der geclusterten Stops — kein Callout im geclusterten Zustand.
Die Kamera zieht sich zusammen, `effectiveSpan` fällt, die Stops trennen sich in
einzelne, individuell tappbare Badges auf (jedes davon wieder mit eigenem Callout) —
selbstauflösend, keine Sackgasse, keine neue Disambiguierungs-UI nötig. Ein einzelner
(nicht geclusterter) Stop verhält sich unverändert: Tap zeigt direkt den Callout.

**Tap-Flächen (alle Marker-Varianten, ≥ 44×44pt — Pflicht, nicht optional)**

| Marker | Sichtbare Größe | Inset für 44pt | Status |
|---|---|---|---|
| Welt-Dot (`worldDotView`) | 9pt | `.inset(by: -17.5)` | **Bugfix** — aktuell kein Inset |
| Route-Badge (`MapStopBadgeView`) | 22pt | `.inset(by: -11)` | neu |
| Rollen-Pin (`markerView`, `PortPinView`+6pt Padding) | ~32–36pt (vor Umsetzung exakt messen) | Inset so wählen, dass Summe = 44pt | neu |
| Cluster-Pill | Badge + Pill kombiniert | `.contentShape` über Bounding-Box beider Elemente | neu |

**VoiceOver (unabhängig vom Zoom-Bucket, immer voller Datensatz)**

- Label-Format: `"Stopp {n} von {gesamt}, {Hafenname}, {Land}"` (Rollen-Pins:
  `"{Heimathafen/Endhafen}, {Hafenname}, {Land}"`).
- Fix: Label wandert vollständig auf den äußeren `Button`
  (`MapView+RouteInteraction.swift:58`); `MapStopBadgeView`/`worldDotView` markieren ihre
  eigene interne `Text`/`Circle` als `.accessibilityHidden(true)` (dekorativ, das
  Button-Label trägt bereits die volle Semantik — verhindert doppelte Ansage).

### SwiftUI-Umsetzungshinweise

- `MapZoomBucketPlanner.bucket(for:centerLatitude:)` — Signaturänderung, Unit-Tests für
  hohe Breiten (z. B. Norwegen ~62–70°N) ergänzen, da dort die Korrektur den größten
  Effekt hat.
- Cluster-Berechnung als neue reine Funktion (Vorbild: `MapSelectionPlanner`,
  `MapRouteVisibilityPlanner` — SwiftUI-frei, isoliert testbar), z. B.
  `MapClusterPlanner.clusters(projected: [UUID: CGPoint], collisionDistance: 28) ->
  [ClusterGroup]` mit `ClusterGroup { primaryID: UUID, suppressedIDs: [UUID] }` —
  paarweiser Vergleich über ALLE übergebenen Punkte, unabhängig von Eingabe-Reihenfolge
  (kein Routenreihenfolge-Bias, siehe Design-Entscheidung oben). Bildschirm-Projektion
  selbst bleibt in `MapView+RouteInteraction.swift` (nutzt `MapProxy.convert(_:to:)`,
  gleiches Muster wie `nearestRouteID(to:using:)`, `MapView+RouteInteraction.swift:122-143`).
- Kamera-Zoom-Übergang beim Cluster-Auflösen: `motion.zoomTransition` Token
  (`easeOut, 280ms`, siehe `karten-politur-c-tokens.json`) für das Ein-/Ausblenden der
  Einzel-Badges beim Hineinzoomen — ohne benanntes Token würde sonst mit `.spring()`
  improvisiert, was die Marker unruhig „einschnappen" lässt (Gate #5b).
- Ergebnis der Cluster-Berechnung als `@State` (z. B. `[UUID: Int]` Primär-Stop → Anzahl
  unterdrückter Nachbarn) — Neuberechnung in `.onMapCameraChange(frequency: .onEnd)`
  (bestehende Stelle, `MapView.swift:56-62`) UND synchron in `zoomTo(coordinates:)`
  (`MapView.swift:349-361`), analog zum bestehenden Muster „Bucket sofort synchron
  setzen … verhindert Flash der falschen Zoom-Stufe" (`MapView.swift:353-354`).

### Akzeptanzkriterien

- [ ] Bei einer Route mit Span zwischen 10° und 20° (latitude-korrigiert) zeigen alle
      Stops volle nummerierte Badges statt Dots (regressionstestbar mit dem
      Kanaren/Madeira/Marokko-Beispiel aus Screenshot 04).
- [ ] Norwegen-Route (hohe Breite) fällt bei vergleichbarem unkorrigiertem Grad-Span
      nicht vorzeitig in `.world` (Unit-Test mit `centerLatitude` ≈ 65°).
- [ ] Jede der vier Marker-Varianten hat eine Tap-Fläche ≥ 44×44pt (manuell mit
      Accessibility Inspector oder Debug-Overlay verifiziert).
- [ ] Zwei künstlich nah zusammengelegte Stops (< 28pt Bildschirmdistanz) zeigen genau
      ein Badge + einen „+1"-Pill, kein doppeltes Badge-Overlay.
- [ ] Dasselbe gilt, wenn die zwei nahen Stops NICHT aufeinanderfolgende Stop-Nummern
      haben (Rundreise-/Kreuzungs-Fall, z. B. Stop 2 und Stop 5 geografisch nah) —
      Clustering ist geografisch, nicht routenreihenfolge-gebunden.
- [ ] Tap **überall** auf dem kombinierten Badge+Pill-Bereich (nicht nur exakt auf den
      Pill) zoomt zuverlässig so weit hinein, dass sich der Cluster in Einzel-Badges
      auflöst (kein Endlos-Cluster, kein separater Callout im geclusterten Zustand).
- [ ] VoiceOver liest bei JEDEM Zoom-Bucket Nummer + Name + Land vor — auch im
      `.world`-Dot-Zustand.
- [ ] Kein doppeltes VoiceOver-Announcement (Badge-internes Label ist
      `.accessibilityHidden`).

---

## Accessibility (Zusammenfassung)

- Kontrast: alle neuen/geänderten Farbpaare (Menü-Panel-Text auf `journalSurface`,
  Pin-Platzhalter-Rand, Cluster-Pill-Text auf `navyDark`) müssen WCAG AA erreichen
  (Text ≥ 4.5:1, UI-Komponenten ≥ 3:1) — vor Merge mit Accessibility Inspector in Light
  UND Dark verifiziert, nicht nur behauptet.
- Dynamic Type: Menü-Zeilen und Sheet-Rows müssen bei Body +2 Stufen ohne Abschneiden
  überleben (keine neuen Fixed-Height-Container außer den bewusst gesetzten
  Badge-/Pill-Kreisen/Kapseln, die als dekorative Icons ohnehin `.accessibilityHidden`
  sind und nicht mitskalieren müssen).
- VoiceOver-Reihenfolge Menü: „Alle anzeigen/ausblenden" zuerst, dann Routen in
  Listenreihenfolge — unverändert zur heutigen Lesereihenfolge.
- VoiceOver Marker: siehe F4-Abschnitt oben (konsolidiertes Label, kein Doppel-Announcement).

## Offene Punkte/Risiken

- **F2 Truncation-Kollision (abgeschwächt durch `.middle` statt `.tail`, Gate #5b):**
  zwei Routen mit identischem Präfix UND identischem Suffix (selten, aber möglich, z. B.
  exakt derselbe Reisetitel in zwei Jahren mit identischem Abfahrtshafen) sehen im
  300pt-Panel weiterhin identisch aus. Hart vorgegeben („einzeilig"), daher nicht
  vollständig lösbar — Rückfrage an Winston/Andre, ob ein sekundäres Unterscheidungs-
  merkmal (z. B. Startjahr) für diesen Restfall gewünscht ist.
- **F3 Kontrastwerte per Hand nachgerechnet, nicht gemessen:** die in Gate #5b
  korrigierten Opacity-Werte (0.55 Light / 0.40 Dark) basieren auf einer manuellen
  sRGB-Relativluminanz-Rechnung (siehe F3-Abschnitt), nicht auf einer echten Messung im
  Simulator/Gerät — Pflicht-Check vor Merge (siehe Akzeptanzkriterien).
- **F4 Rollen-Pin-Maße unbekannt:** `PortPinView`s tatsächliche gerenderte Größe wurde
  für diese Spec nicht exakt vermessen (Datei nicht Teil des Leseumfangs) — Developer
  muss vor dem Inset-Wert die reale Größe prüfen.
- **iOS-26-Glass-Kür:** rein optional, kein Akzeptanzkriterium hängt daran — falls
  Zeitdruck, ersatzlos weglassbar ohne dass eine der drei Findings ungelöst bleibt.
- **Cluster-Pill-Kollision bei 3+ benachbarten Stops:** die Spec deckt „N aufeinander-
  folgende Stops im selben Cluster" ab (Pill zeigt korrekt „+{n-1}"), aber zwei
  *benachbarte, aber getrennte* Cluster auf sehr dichten Routen könnten optisch nah
  aneinanderrücken — bei ShipTrips Datengröße (≤ 20 Stops/Route) als seltener Edge-Case
  eingestuft, nicht gesondert gelöst.

## Gemini Design Gate — Protokoll

### Gate #5a (Konzeptskizze, vor Ausarbeitung)

**Verdict:** Substanzielle Kritik an allen drei Findings, im Kern zutreffend.

Übernommen:
- F2: Icon-Kreis 20pt → 24pt (Lesbarkeit des Checkmarks).
- F2: natives `.popover` statt handgebautem Fullscreen-Tap-Catcher (System-Accessibility
  umsonst).
- F3: „Spine"-Akzentstrich verworfen (Kollision mit System-Grabber).
- F3: Pin-Platzhalter braucht Fill+Rand statt reiner Hairline (Kontrast).
- F4: 18pt-Badge mit 11pt-Text ist geometrisch nicht tragfähig — verworfen zugunsten des
  bewährten 22pt-Badges, dafür früher gezeigt (Schwellenkorrektur statt neuer Größe).
- F4: Latitude-/Mercator-Korrektur der Span-Schwelle übernommen.

Geprüft und **verworfen** (mit Begründung):
- F4: „6°/20° sind willkürlich" — teilweise entkräftet: 20° ist der Original-Deck-Anker
  (`MapZoomBucketPlanner.swift:24`), nicht neu erfunden; das mittlere 6°-Band wurde
  ohnehin gestrichen (siehe oben), die Kritik an einer dritten Bucket-Grenze ist damit
  gegenstandslos geworden.
- F4: „Nutze natives `MKAnnotationView.clusteringIdentifier`" — verworfen, da für
  SwiftUI `Map` nicht verfügbar (Repo-eigene Recherche
  `.planning/b4-fertigloesungen-research.md:65` widerspricht der Prämisse explizit).
- F2: „2-zeilige Titel statt 1-zeilig" — verworfen, harte Auftrags-Vorgabe („einzeilige
  Titel mit Truncation"); stattdessen Panel-Breite 280→300pt als Teilkompensation.

### Gate #5b (fertige Spec, inkl. Token-JSON)

**Verdict:** 7 konkrete Findings, davon 5 mit Substanz — deckte insbesondere einen
eigenen Rechenfehler bei den F3-Kontrastwerten auf (per Hand nachgerechnet und
bestätigt: 0.14 ≈ 1.3:1, Gemini's eigener Vorschlag 0.30 ≈ 1.8:1 — beide unter 3:1;
korrigiert auf 0.55/0.40, siehe F3) sowie einen echten Tap-Target-Widerspruch (Badge vs.
Pill) und eine Lücke im Clustering-Algorithmus (Routenreihenfolge übersieht
Rundreise-Fälle).

Übernommen (Dokument oben entsprechend aktualisiert):
1. F4: Badge+Pill zu einem gemeinsamen Tap-Target zusammengelegt (kein separater Callout
   im geclusterten Zustand) — vorheriger Entwurf hätte zwei nicht unterscheidbare
   44×44pt-Ziele übereinandergelegt.
2. F4: Clustering von „linear, nur Routen-Nachbarn" auf „paarweiser Geo-Vergleich, alle
   Stops einer Route" umgestellt — deckt Rundreise-/Kreuzungsfälle ab; Performance-
   Mehrkosten (≤190 Vergleiche bei ≤20 Stops) sind bei dieser Datengröße vernachlässigbar.
3. F3: Kontrastwerte Pin-Platzhalter-Rand korrigiert (0.14/0.16 → 0.55/0.40), inkl.
   Beleg-Rechnung im Dokument.
4. F2: `.truncationMode(.tail)` → `.middle` (behält den unterscheidenden Suffix sichtbar).
5. F2: Popover-Höhenlimit von vager „~60 %"-Angabe auf konkretes
   `min(0.45 × Bildschirmhöhe, 380pt)` verschärft (iPhone-SE-Fall).
6. F4: `motion.zoomTransition`-Token ergänzt (280ms easeOut) für den Cluster-Auflöse-
   Übergang.

Geprüft und **verworfen/korrigiert** (mit Begründung):
- F2: „Popover auf iPhone SE zu groß, zurück auf System-Sheet" — Kern-Sorge (Bildschirm-
  Bedeckung) übernommen (siehe Höhenlimit oben), aber die Remedur nicht: ein natives
  `.sheet` ist auf iPhone immer Full-Width und kann die harte Auftrags-Vorgabe
  „definierte max. Breite" grundsätzlich nicht erfüllen — Popover mit strengerem
  Höhenlimit statt Sheet-Rückfall gewählt.
- F3: „`.resizes` erzeugt Konflikt bei Aufwärts-Scroll" — das ist der dokumentierte,
  gewollte Vertrag von `.presentationContentInteraction(.resizes)` (Resize-zuerst in
  beide Richtungen), kein Bug; im Dokument als explizite Implementierungs-Warnung
  ergänzt, damit es nicht versehentlich „wegoptimiert" wird.
