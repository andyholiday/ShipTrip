# B4.3 Karten-Redesign — Fertiglösungen-Research (native-first)

Frage: Gibt es für die „mutige Richtung" (Richtung 2 im Design-Deck) eine fertige,
einfache Lösung, oder bauen wir sie selbst nativ?

**Auflage aus dem Plan-Review (Gate 1):** Projektkonvention ist „MapKit nativ,
kein Fremd-Code". Fremd-SDKs (Mapbox/Google/MapLibre) werden hier **nur als
Vergleich/Pattern-Referenz** geführt, nicht als empfehlbare Option. Ergebnis
vorweg: Kein Fremd-SDK bietet einen Nutzen, der einen Konventionsbruch
rechtfertigen würde — daher keine Eskalation an Andre nötig, die Empfehlung
ist durchgehend native-first.

## 0. MapKit-Bausteine-Mix: was die mutige Richtung mit minimalem Eigencode abdeckt

| Baustein (Richtung 2) | Native MapKit/SwiftUI-Baustein | Eigencode nötig? |
|---|---|---|
| Routenlinie | `MapPolyline` (`MapContentBuilder`) | Nein — vorhanden, nur wiederverwenden |
| Nummerierte Wegpunkt-Badges | `Annotation` mit eigenem SwiftUI-Label (`Text("\(index)")`) | Minimal — Label-Inhalt austauschen, kein neues Rendering |
| Start/Ende/Seetag-Rollen-Pins | bestehendes `PortPinView` (4 Rollen, bereits vorhanden) | Nein — nur auf Karte statt nur Detailliste einsetzen |
| Zoom-Zustand (Welt- vs. Reise-Zoom) | `.onMapCameraChange(frequency:)` + `MKCoordinateRegion.span`-Schwellenwert | Minimal — ein Vergleichswert, zwei feste UI-Zustände |
| Rundreise-Kombi-Marker | reine App-Logik: Koordinatenvergleich Start == Ende | Ja, aber trivial (kein MapKit-Feature nötig) |
| Tap-Callout (Name + Foto) | `Annotation`-Content ist beliebige SwiftUI-View → eigenes Callout mit `port.imageData` | Minimal — Views neu komponieren, keine neue API |
| Bottom-Sheet-Stopliste | reines SwiftUI (`VStack`-Overlay o. `.sheet`), kein MapKit-Feature | Ja — App-UI, unabhängig vom Karten-SDK |
| Karte↔Liste-Sync (Tap→Scroll, Scroll→Highlight) | kein MapKit-Baustein — reines `@State`/`ScrollViewReader`-Handling | **Ja, größter Eigenanteil** — bestätigt Deck-Einschätzung „Hoch" |
| Kurvenrouten um Landmassen | kein MapKit-Baustein (auch UIKit/Fremd-SDK liefert das nicht ohne echtes Routing) | Ja — reine Bezier-Geometrie, App-eigen |
| Echtes Annotation-Clustering / Label-Collision | fehlt in SwiftUI `Map` (siehe unten) | Nur relevant, falls Datengröße wächst — aktuell durch Zoom-Schwelle ersetzt |

**Kernaussage:** 7 von 10 Bausteinen sind mit vorhandenen/nahezu vorhandenen
MapKit- und SwiftUI-Mitteln abgedeckt (Polyline, Rollen-Pins, Zoom-Schwelle,
Callout-Content sind kleine Erweiterungen bestehender Patterns). Echter
Eigenbau mit spürbarem Aufwand bleibt nur bei zwei Stellen, und beide sind
**UI-Logik, kein Karten-Rendering-Problem**: (1) die bidirektionale
Karte↔Liste-Synchronisation und (2) die Bezier-Kurvenrouten. Kein Fremd-SDK
würde (1) abnehmen (reines App-State-Handling) — und (2) würde nur durch
echtes, kostenpflichtiges maritimes Routing gelöst, was das Deck selbst explizit
ausschließt. Es gibt also **keinen Baustein, für den ein Fremd-SDK echten
Mehrwert liefert.**

## 1. Was die „mutige Richtung" konkret braucht (aus dem Deck)

- Nummerierte Wegpunkt-Badges statt Namen auf der Karte (Roadtrippers-Stil).
- Zwei feste Zoom-Zustände über `MKCoordinateRegion.span`-Schwelle (Welt-Zoom:
  nur Dots/Polyline; Reise-Zoom: volle Pins, Label nur Start/Ende/Selektion).
- Bottom-Sheet-Stopliste, bidirektional mit der Karte synchronisiert (Tap auf
  Badge scrollt Liste, Scroll hebt Badge hervor), inkl. Foto-Thumbnails aus
  vorhandenem `port.imageData`.
- Tap-Callout mit Name + Foto statt Dauerlabel.
- Rundreise-Sonderfall: ein kombinierter Marker mit Zyklus-Icon statt zwei
  überlagerten Kreisen.
- Gepunktete, um Landmassen "herumgeführte" Routenlinie (Bezier/Kurven) — vom
  Deck selbst explizit als **kein echtes maritimes Routing** deklariert (das
  bräuchte kostenpflichtige Dritt-APIs, ist nicht Teil des Vorschlags).
- Explizites Acceptance-Kriterium im Deck: **„Ausschließlich natives MapKit +
  SwiftUI, keine Fremd-SDKs/Custom-Tiles."** Das ist bereits eine bewusste
  Vorentscheidung, keine offene Frage — deckt sich mit der Projektkonvention
  in CLAUDE.md ("Karten nativ mit MapKit, kein Fremd-Code").

## 2. Abdeckungs-Matrix: nativ vs. Fremd-SDK (Referenzvergleich)

| Baustein | SwiftUI `Map` (iOS 17/18, nativ) | UIKit `MKMapView`-Wrapper (nativ) | Mapbox/Google Maps/MapLibre (Fremd-SDK, nur Vergleich) |
|---|---|---|---|
| Polyline/Route | `MapPolyline` — trivial, vorhanden | ja | ja, aber overkill |
| Nummerierte Badges | trivial (`Text` im `Annotation`-Label) | ja | ja |
| Zoom-Span-Schwelle (2 feste Zustände) | trivial, `.onMapCameraChange` + `region.span` | ja | ja, eigene Camera-API |
| Echtes Annotation-Clustering | **fehlt** — SwiftUI `Map` hat bis heute (2026) kein `ClusterAnnotation`-Äquivalent zu UIKit | ja, `MKMarkerAnnotationView.clusteringIdentifier` nativ vorhanden | ja, eingebaut |
| Label-Collision-Avoidance | **fehlt**, deshalb die manuelle Zwei-Stufen-Schwelle im Deck | ja, automatisch | ja, eingebaut |
| Bottom-Sheet + Karten-Sync | reines SwiftUI-State-Handling, kein MapKit-Feature — überall gleich viel Eigenaufwand | gleich | gleich |
| Kurvenrouten um Landmassen | **fehlt überall** nativ — reine Geometrie/Bezier-Berechnung, App-eigen zu bauen | gleich | teils via Directions-API, aber das ist echtes Routing (kostenpflichtig, nicht Ziel) |
| Rundreise-Kombi-Marker | trivial, App-Logik (Koordinatenvergleich) | gleich | gleich |

Kernbefund: Bei ShipTrips Maßstab (max. ~20 Häfen pro Reise, keine 1000er-Marker-Mengen)
ist **Clustering/Label-Collision der einzige Baustein, den natives SwiftUI-`Map`
nicht abdeckt** — und genau dafür sieht das Deck selbst schon die richtige,
proportionale Antwort vor: eine manuelle Zwei-Stufen-Zoom-Schwelle statt echtem
Clustering-Framework. Bei dieser Datengröße ist das ausreichend und deutlich
einfacher als jede Fremdlösung.

## 3. Fremd-SDK-Kurzcheck (reine Vergleichsreferenz, keine Empfehlung)

| Option | Stars/Reife | Lizenz/Preis | Aufwand/Bruch | Fazit |
|---|---|---|---|---|
| **Mapbox Maps SDK iOS** | Marktführer, aktiv | Free bis 25.000 MAU/Monat, danach nutzungsbasiert (Vector/Raster-Tiles-API) | Account+Access-Token-Pflicht, eigenes Tile-Rendering statt Apple-Kartenbild, +SDK-Größe zur App | Kein Nutzen, der Konventionsbruch rechtfertigt — bricht mit „100% Apple Maps-Look" |
| **Google Maps SDK iOS** | Marktführer, aktiv | Kostenpflichtig ab gewissem Volumen, Google-Cloud-Account | Fremdes Kartenbild (kein Apple-Look), Datenschutz-Rückfragen (Google-SDK in App) | Gleiche Einwände, zusätzlich GDPR-Diskussion |
| **MapLibre Native (+ SwiftUI-DSL)** | Aktiv gepflegt, Community wächst (Dez. 2025 Newsletter bestätigt laufende SwiftUI-DSL-Arbeit) | Open Source (BSD-2), kostenlos, kein Vendor-Lock-in | Eigenes Tile-Hosting/-Styling nötig, deutlich mehr Setup als Apple-`Map`, kein „echtes maritimes Routing" inklusive | Technisch am ehesten vertretbar, aber kein Bedarf für Custom-Styling/Vektor-Tiles vorhanden — kein Grund für Konventionsbruch |
| **ClusterMap** (nur Clustering-Algorithmus, kein Kartenrenderer, kein Kartenwechsel) | Nur 123 GitHub-Stars, letztes Release Mai 2024 (>1,5 Jahre alt), MIT | kostenlos | Funktioniert mit SwiftUI `Map` (iOS 17+), aber schwaches Maintenance-Signal | Bei ShipTrips kleiner Markeranzahl (max. ~20) unnötig; da es keinen Kartenwechsel bedeutet (nur Algorithmus on top von MapKit), wäre es im Bedarfsfall kein Konventionsbruch — aber aktuell kein Trigger |

**Keine der Fremd-Optionen erreicht die Schwelle „überwältigender Nutzen" —
alle lösen entweder nichts, was natives MapKit nicht auch (proportional)
lösen kann, oder sie ersetzen das Kartenbild komplett ohne Not.** Keine
Eskalation an Andre erforderlich.

## 4. Empfehlung (native-first)

**Mutige Richtung (Richtung 2) nativ mit dem oben stehenden MapKit-Bausteine-Mix
bauen, wie im Deck bereits phasiert vorgeschlagen.** Die einzige MapKit-Lücke
(Clustering/Label-Collision) betrifft ShipTrip bei seiner Datengröße nicht real;
die im Deck vorgeschlagene Zwei-Stufen-Zoom-Schwelle ist die richtige,
proportionale Lösung. Fremd-SDKs bringen keinen Baustein, der native Mittel
nicht abdecken — sie würden nur zusätzlich das Kartenbild ersetzen und einen
Account/Kosten-Layer einziehen.

Geschätzter Umfang (bestätigt Deck-Einschätzung, aus Code-Sicht):
- **Sprint 1 / Richtung 1 (Konsistenz-Fix):** klein, 1 Session. `PortPinView`
  statt `routeMarker()`, Rundreise-Koordinatenvergleich, `markerPorts()` nicht
  mehr auf `[first,last]` kappen.
- **Sprint 2 / Richtung 2 (Badges + Sheet):** hoch, mehrere Sessions. Größter
  Aufwandstreiber ist **nicht** MapKit, sondern die bidirektionale
  SwiftUI-State-Synchronisation Karte↔Liste (Scroll-Position, Selektion,
  Animation) — das bestätigt die Aufwandseinschätzung im Deck ("Hoch, nicht
  Mittel").
- **UIKit-`MKMapView`-Wrapper:** nur falls später reale Clustering-Probleme
  auftreten (>50 gleichzeitig sichtbare Häfen) — aktuell kein Trigger, bleibt
  aber ebenfalls nativ (kein Fremd-SDK-Bedarf).

## 5. Risiken

- Kurvenrouten "um Landmassen" (Slide 7) sind reine Bezier-Geometrie, kein
  MapKit-Feature — Aufwand nicht unterschätzen, auch nicht mit Fremd-SDK
  automatisch gelöst (echtes maritimes Routing ist explizit ausgeschlossen).
- Wird die "Alle Reisen"-Ansicht künftig auf sehr viele parallele Routen
  skaliert (z. B. 50+ Häfen gleichzeitig), reicht die feste Zwei-Stufen-Schwelle
  eventuell nicht mehr — dann zuerst `ClusterMap` (leichtgewichtig, kein
  Kartenwechsel, kein Konventionsbruch) statt UIKit-Wrapper oder Fremd-SDK
  prüfen, aber Maintenance-Status (letztes Release 2024) vor Einsatz erneut
  checken.
- Fremd-SDKs wurden bewusst nicht vertieft benchmarkt (Performance/Bundle-Size),
  da sie am Grundproblem (Clustering nicht nötig, Datenschutz/Account-Overhead
  unerwünscht, Konventionsbruch ohne überwältigenden Nutzen) scheitern.

## Quellen

- [Apple: Decluttering a Map with MapKit Annotation Clustering](https://developer.apple.com/documentation/MapKit/decluttering-a-map-with-mapkit-annotation-clustering) (UIKit-only)
- [SwiftUI MapKit (iOS 17/18): The Missing Features — G. Castan](https://medium.com/@gerdcastan/swiftui-mapkit-ios-17-the-missing-features-4b08fa42ee9f)
- [Mapbox Pricing (Maps SDK iOS)](https://docs.mapbox.com/ios/maps/guides/pricing/)
- [MapLibre Newsletter Dez. 2025](https://maplibre.org/news/2026-01-03-maplibre-newsletter-december-2025/)
- [ClusterMap (GitHub, vospennikov)](https://github.com/vospennikov/ClusterMap)
