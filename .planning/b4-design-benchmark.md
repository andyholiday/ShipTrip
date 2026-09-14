# B4 — Karten-Überarbeitung: Design-Benchmark + Konzept-Skizze

Phase 1 (Benchmark + Skizze). Kein HTML-Deck, kein Produktiv-Code.

## 1. Problem (TestFlight-Feedback 2026-07-03)

a) Route-Stops auf der Karte nicht klar erkennbar
b) Hafennamen fehlen teils
c) Start-/Endhafen nicht unterscheidbar — auch beim Sonderfall Start=Ende (Rundreise)

## 2. IST-Analyse (Code + Screenshots)

- `ShipTrip/Views/Map/MapView.swift`: eigene `routeMarker()`-Funktion mit
  hartkodierten Farben (`.sunsetOrange` = Start, `.seaGreen` = Ende), **nicht**
  das bestehende `PortPinView`-Komponentensystem (4 Rollen: Hafen/Heimathafen/
  Endhafen/Seetag, in `ShipTrip/Components/PortPinView.swift`) — das aber schon
  in der Routen-Detailliste (`CruiseDetailView.swift:287`) sauber genutzt wird.
  Zwei Pin-Sprachen für dieselbe Sache → Inkonsistenz.
- Bei **mehreren gleichzeitig angezeigten Routen** zeigt `markerPorts()` nur
  Start+Ende, alle Zwischenstopps werden komplett ausgeblendet — nur die
  Polyline bleibt (Screenshot `weltkarte-all-*`: dünne Linie ohne Zwischenpunkte
  Richtung rechter Bildrand). Das ist Problem (a).
- `Annotation(port.name, ...)` nutzt MapKit-Systemlabels ohne Zoom-/Kollisions-
  steuerung. Screenshot zeigt „Nassau" und ein fremder Ortsname am rechten Rand
  angeschnitten. SwiftUI-`Map` hat **kein** natives Label-Collision-Avoidance
  (nur UIKit-MapKit via `MKMarkerAnnotationView`/Clustering hat das) — Problem (b)
  ist teils eine Plattform-Lücke, nicht nur ein Marker-Problem.
- Rundreise-Fall: Start- und End-Port sind zwei separate `Port`-Einträge mit
  identischen Koordinaten → zwei überlappende Kreise (orange + grün) exakt
  übereinander, nicht als ein Punkt erkennbar. Code behandelt „Start=Ende"
  nirgends explizit — Problem (c) konkret nachvollzogen.
- `CruiseGeoFallbackView.swift` (Hero-Canvas, `geo-hero-*`) hat dasselbe
  Start/End-Farbschema (orange/grün) unabhängig gepflegt — dritte Stelle mit
  eigener Pin-Logik.
- Positiv vorhanden, wiederverwendbar: `PortPinView` mit sauberen 4 Rollen +
  Accessibility-Labels; Farbtoken in `Color+Theme` (`portPin`, `homePortPin`,
  `endPortPin`, `seaDayPin`); Port-Objekt trägt bereits `imageData` und
  `excursions` (in Detailliste genutzt, auf Karte bisher ungenutzt).

## 3. Benchmark: 6 Apps

| App | Routen-Visualisierung | Stop-Marker | Label-Sichtbarkeit bei Zoom | Start/Ende-Differenzierung | MapKit-Machbarkeit |
|---|---|---|---|---|---|
| **Polarsteps** | Tatsächliche Reiseroute als Linie (nicht nur Luftlinie), Step-Marker mit Foto-Thumbnail | Marker = „Steps", tippbar, Foto-Vorschau im Callout | Namen erscheinen primär beim Tap/Callout, nicht permanent als Overlay-Text | Kein hartes Start/Ende-Konzept (offene Reise) | Polyline nativ easy; Foto-Callout mit SwiftUI-View machbar (mittlerer Aufwand) |
| **Wanderlog** | Farbcodierte Pins nach Tag/Kategorie, verbindende Linien mit Distanz/Zeit | Pins in Sektionsfarbe, Liste synchron zur Karte | Kollaps in Liste statt Karten-Overlay bei vielen Punkten | Kein explizites Start/Ende, aber klare Tages-Gruppierung | Trivial — passt direkt zu bestehendem `PortPinView`-Rollenkonzept |
| **Flighty** (Apple Design Award 2023) | Minimalistischer Routen-Bogen, klare Typo-Hierarchie, Heatmap bei vielen Routen | Start/Ziel als klar unterscheidbare Icons (Flugzeug-Icon rotiert je Richtung) | Kompakte Info-Kacheln statt Karten-Text — Karte bleibt clean | Sehr klar: Icon-Form + Position (oben/unten), nicht nur Farbe | Direkt übertragbar, kein Custom-Rendering nötig — nur Icon/Layout-Disziplin |
| **AllTrails** | Trail-Linien mit progressiver Detailtiefe je Zoomstufe | Marker mit weißem Halo-Hintergrund für Icon-Lesbarkeit, Differenzierung über Form **und** Farbe (Lehre: nicht nur Farbe, s. Camp/Peak-Verwechslung) | Info erscheint erst ab bestimmter Zoomstufe (progressive disclosure) | n/a (kein Start/Ende-Konzept) | Halo/Ring bereits in `routeMarker()` vorhanden (weißer Stroke) — zoombasierte Sichtbarkeit ist simple Region-Span-Schwelle, kein Cluster-Framework nötig |
| **Apple Maps / iOS-Systemkonvention** (Fahrtrouten) | Blaue Routenlinie, System-Pins für Start (grün) und Ziel (rot/kariert) | Etablierte OS-Affordanz, jedem iOS-Nutzer vertraut | Callout on-tap, Systemstandard | Sehr stark: Form + Farbe + Position, seit Jahren iOS-Konvention | 100 % nativ, kein Aufwand — nur Konvention übernehmen statt eigene Orange/Grün-Erfindung |
| **Roadtrippers** | Multi-Stop-Route mit nummerierten Wegpunkten | Nummerierte Badges (1, 2, 3…) auf Markern + separate scrollbare Stop-Liste synchron zur Karte | Löst Label-Problem strukturell: Namen stehen in der Liste, nicht auf jedem Pin | Erster/letzter Wegpunkt optisch hervorgehoben, aber nummeriert bleibt die Reihenfolge immer lesbar | Trivial in SwiftUI — `Text("\(index)")` im Annotation-Label statt Vollname |

## 4. Pattern-Shortlist → Mapping auf die 3 Probleme

- **P(a) Stops nicht erkennbar:** Roadtrippers (nummerierte Badges) + Wanderlog
  (alle Punkte immer sichtbar, auch bei Mehrfachrouten — aktuell werden sie bei
  >1 Route komplett weggelassen). Fix: `markerPorts()` gibt bei Mehrfachrouten
  kleine Dots für Zwischenstopps zurück statt sie zu droppen.
- **P(b) Namen fehlen/werden abgeschnitten:** AllTrails (zoom-abhängige
  Einblendung) + Polarsteps (Name im Callout statt Dauer-Overlay) + Roadtrippers
  (Namen in synchronisierter Liste statt auf der Karte). Fix: Name nur für
  Primary-Route/Selektion permanent, sonst Tap-Callout; zusätzlich optionale
  Stop-Liste als Bottom-Sheet.
- **P(c) Start/Ende + Rundreise-Sonderfall:** Apple-Systemkonvention (Form
  **und** Farbe unterscheiden, nicht nur Farbe — AllTrails-Lehre) + explizite
  Sonderfall-Behandlung. Fix: `PortPinView` (existiert bereits mit passenden
  SF-Symbols `mappin.circle.fill` vs. `mappin.and.ellipse.circle.fill`) auch auf
  der Karte verwenden statt eigener Kreis-Logik; bei Start-Koordinate ==
  Ende-Koordinate einen **einzigen kombinierten Marker** (z. B. Doppelring oder
  „Rundreise"-Badge) statt zwei überlagerter Kreise rendern.

## 5. Konzept-Skizze: 3 Richtungen

**Richtung 1 — Konservativ (Konsistenz-Fix, kleiner Aufwand):**
`MapView.routeMarker()` durch das bestehende `PortPinView` ersetzen (eine
Pin-Sprache für Karte + Detailliste), Rundreise-Sonderfall über
Koordinatenvergleich abfangen (ein Marker statt zwei), alle Zwischenstopps
auch bei Mehrfachrouten als kleine Dots zeigen. Kein neues UI-Konzept, nur
Bugfix-Charakter — schnell umsetzbar, geringes Risiko.

**Richtung 2 — Mutig (Journal-natives Kartenerlebnis):** Nummerierte
Wegpunkt-Badges (Roadtrippers-Stil) statt Namen auf der Karte, dazu eine mit
der Karte synchronisierte Bottom-Sheet-Stopliste (nutzt bereits vorhandenes
`port.imageData`/`excursions` für Foto-Vorschau, ähnlich Polarsteps-Callouts),
Tap-Callout mit Hafenname + Foto statt Dauerlabel. Größerer Umbau der
Karten-Interaktion, aber löst alle 3 Probleme strukturell statt kosmetisch.

**Richtung 3 — Hybrid/Phasiert:** Richtung 1 sofort (nächster Release, behebt
die 3 gemeldeten Bugs), Richtung 2 als Folge-Welle (Bottom-Sheet + Badges) —
gleiche Zielarchitektur, aber risikoärmer gestaffelt. Empfehlung fürs Deck.

### Slide-Gliederung (für Phase 2, 11 Slides, `ui-mockup-html`-Schema)

1. Cover · 2. Problem (TestFlight-Zitate) · 3. IST-Analyse (Screenshots +
Code-Befunde) · 4. Benchmark-Übersicht (Tabelle oben) · 5. Pattern Deep-Dive:
Start/Ende-Differenzierung · 6. Pattern Deep-Dive: Label-Sichtbarkeit bei Zoom
· 7. Pattern Deep-Dive: Stop-Marker/Nummerierung · 8. Richtung 1 Konservativ
(Before/After-Mockup) · 9. Richtung 2 Mutig (Before/After-Mockup) · 10.
Empfehlung Richtung 3 Hybrid + Aufwand/Machbarkeit (MapKit-Grenzen: kein
natives Label-Collision-Avoidance) · 11. Roadmap/Acceptance.

### Acceptance-Kriterien

- Jeder Marker ist per Form **und** Farbe eindeutig als Start/Zwischenstopp/
  Endpunkt/Seetag erkennbar, nicht nur über Farbe.
- Rundreise (Start = Ende) zeigt genau einen Marker, keine zwei überlappenden
  Kreise.
- Hafenname ist für die Primärroute lesbar sichtbar und wird nicht am
  Bildschirmrand abgeschnitten; bei Mehrfachrouten per Tap abrufbar.
- Bei Mehrfach-Routen-Ansicht bleiben alle Zwischenstopps sichtbar (aktuell:
  komplett ausgeblendet).
- Ausschließlich natives MapKit + SwiftUI, keine Fremd-SDKs/Custom-Tiles.
- Light/Dark Mode konsistent über bestehende `Color+Theme`-Token.
