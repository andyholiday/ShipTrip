# Konsistenz-Brief — ShipTrip „Meine Reisen"

**Zweck:** Verbindliche Design-Sprache der redesignten Hauptseite „Meine Reisen".
Vier Designer richten ihre Vorschläge für **Karte · Statistik · Merkliste · Mehr**
exakt hieran aus. Konsistenz ist harter Constraint.

**Quelle der Wahrheit:** der tatsächliche Code (Stand 1.5.1 Build 8), nicht die
Designer-Spec. Wo Spec und Code abweichen, gilt der Code (siehe Hinweis bei den
Nadel-Farben).

---

## 1. Farb-Tokens

Alle Marken-Tokens aus `ShipTrip/Utilities/Color+Theme.swift` (exakte RGB→Hex aus Code).
System-Fills sind dynamisch (Light/Dark via iOS) — Näherungswerte „aus Code abgeleitet".

| Token | Hex / Asset | Verwendung |
|---|---|---|
| `oceanBlue` | `#0C8CE9` | Marken-Hauptfarbe; Hafen-Pin; Stats-Zelle „Reisen"; „Details →"-CTA; Spine-Dot bewertet; Gradient-Mitte |
| `oceanLight` | `#36A9F0` | helle Variante; Seetag-Pin; Stats-Zelle „Länder"; Gradient-Endfarbe |
| `navyDark` | `#1A365D` | dunkles Navy; Gradient-Startfarbe (Geo-Hero + Thumbnail-Fallback) |
| `sunsetOrange` | `#FF6B35` | Start-/Heimathafen-Pin; Countdown-Badge-Fill; Stats-Zelle „Häfen"; Spine-Dot bevorstehend |
| `seaGreen` | `#34C759` | Seetage-Stats-Zelle; **Endhafen-Pin**; Hafen-Vorschau-Text + Rating-Zeile in Timeline-Row |
| `portPin` | = `oceanBlue` `#0C8CE9` | semantischer Token Zwischenhafen |
| `homePortPin` | = `sunsetOrange` `#FF6B35` | semantischer Token Starthafen |
| `seaDayPin` | = `oceanLight` `#36A9F0` | semantischer Token Seetag |
| `endPortPin` | = `seaGreen` `#34C759` | semantischer Token Endhafen |
| `AccentColor` | Asset `Assets.xcassets/AccentColor` | globaler Tint (Wert nicht in Swift; im Asset-Katalog) |
| `secondarySystemBackground` | Light ≈ `#F2F2F7` · Dark ≈ `#1C1C1E`/`#2C2C2E` (aus Code abgeleitet) | **Standard-Card-Fill** auf allen Flächen |
| `systemGroupedBackground` | dynamisch (aus Code abgeleitet) | Seiten-Hintergrund StatsView-ScrollView |
| `separator` (`UIColor.separator`) | dynamisch | Stroke des Stats-Strips; Divider zwischen Stats-Zellen |

> **Wichtiger Hinweis Endhafen-Farbe:** Die Spec
> (`timeline-frame-und-nadeln-spec.md`) schlug `endPortPin = navyDark` vor.
> **Im ausgelieferten Code ist `endPortPin = seaGreen` (#34C759).** Designer
> verwenden Grün als Endpunkt-Farbe.

**Ausgabe-Kategorie-Farben** (`expenseColor(for:)`, nur StatsView/Expense-Kontext):
cruise=blue, flight=orange, hotel=purple, excursion=green, onboard=pink, other=gray.

**Routen-Farben** (`routeColors`, zyklisch pro Reise auf der Weltkarte):
oceanBlue, sunsetOrange, seaGreen, purple, pink, cyan, indigo, mint.

---

## 2. Flächen & Karten

Drei Card-Stufen bilden eine **bewusste Hierarchie** (Stats-Strip > Hero > Timeline-Zeile).
Alle teilen denselben Fill (`secondarySystemBackground`), differenzieren über Radius/Rand.

### Standard-Card (Stats-Strip, `CruiseStatsStripView`)
- Fill: `Color(UIColor.secondarySystemBackground)`
- `cornerRadius: 10` (`RoundedRectangle` via `.clipShape`)
- Rand: `.strokeBorder(Color(UIColor.separator), lineWidth: 0.5)` — **nur der Stats-Strip hat einen Rand**
- Padding innen: `.horizontal 16`, `.vertical 10`
- Zell-Trenner: vertikaler `Divider`, `width 0.5`, Farbe `separator`

### Hero-Card (`CruiseHeroCardView`)
- `cornerRadius: 16` (größter Radius im System)
- Zweizonen-Aufbau (siehe §7), kein expliziter Rand/Schatten — Foto/Geo liefert Kontur
- untere Meta-Leiste: Fill `secondarySystemBackground`, oben ein `Divider`

### „Graue Karte" für vergangene/Timeline-Reisen (`CruiseTimelineRowView`) — exakt
- Fill: `Color(UIColor.secondarySystemBackground)`
- `cornerRadius: 10` (identisch Stats-Strip, kleiner als Hero 16)
- **Kein** `strokeBorder`, **kein** Schatten — nur Fläche, keine Linie
- Padding innen: `.horizontal 12`, `.vertical 10`
- `listRowInsets`: `EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16)`
- `listRowSeparator(.hidden)` — Listen-Standardtrenner sind aus
- Light: `secondarySystemBackground` ≈ `#F2F2F7` · Dark ≈ `#1C1C1E`/`#2C2C2E`

> Legacy-Helfer `cardStyle()` in Color+Theme.swift nutzt `cornerRadius 12` +
> Schatten `black.opacity(0.05), radius 4, y 2`. Wird auf der **Hauptseite nicht**
> verwendet; Stats/Deals nutzen `cornerRadius 12` ohne diesen Schatten. Für neue
> Seiten gilt der Hauptseiten-Standard (10/16, kein Schatten), nicht `cardStyle()`.

---

## 3. Nadel-Rollensystem

Vier Rollen, drei Render-Kontexte. Quelle: `Components/PortPinView.swift`,
`CruiseGeoFallbackView.swift`, `MapView.swift`.

### Listen-/Detail-Kontext (`PortPinView`, Symbolgröße 20pt, frame width 24)

| Rolle | Token / Farbe | SF-Symbol | A11y-Label |
|---|---|---|---|
| **Start / Heimathafen** | `homePortPin` = orange `#FF6B35` | `mappin.circle.fill` | „Heimathafen" |
| **Hafen** (Zwischenstopp) | `portPin` = blau `#0C8CE9` | `mappin.circle.fill` | „Hafen" |
| **Endpunkt** | `endPortPin` = grün `#34C759` | `mappin.and.ellipse.circle.fill` | „Endhafen" |
| **Seetag** | `seaDayPin` = hellblau `#36A9F0` | `water.waves` | „Seetag" |

Rollen-Ableitung: `PortPinType(isSeaDay:isFirst:isLast:)` — Seetag schlägt alles,
sonst erster = homePort, letzter = endPort, sonst port.

### Geo-Hero-Kontext (`CruiseGeoFallbackView`, Canvas-Punkte)
- **Start:** `sunsetOrange`-Kreis, `dotR 5.0`, weißer Ring `lineWidth 2` (ringR = dotR+2)
- **Endpunkt:** `seaGreen`-Kreis, `dotR 5.0`, weißer Ring `lineWidth 2`
- **Zwischenstopps:** `white.opacity(0.6)`, `dotR 3.5`, kein Ring
- Routenlinie: weiß `opacity 0.4`, `lineWidth 1.5`, gestrichelt `dash [4,2]`

### Weltkarten-Kontext (`MapView`, Farbe = pro-Reise-Routenfarbe, Form = Rolle)
- **Start:** `mappin.circle.fill` (`.title2`)
- **Zwischenstopp:** `circle.fill` (`.caption`)
- **Endpunkt:** `flag.checkered.circle.fill` (`.title2`)
- Routenlinie: `MapPolyline` mit `routeColor(at:index)`, `lineWidth 3`

---

## 4. Typografie

Ausschließlich System-Font (SF), Dynamic-Type-Styles. Keine Custom-Fonts.

| Element | Style | Gewicht | Farbe |
|---|---|---|---|
| Hero-Titel | `.title3` | `.heavy` | weiß (auf Scrim) |
| Hero-Subline | `.caption` | regular | `white.opacity(0.8)` |
| Hero-Meta-Zeile | `.caption` | regular | `.secondary` |
| Hero-CTA „Details →" | `.caption` | `.medium` | `oceanBlue` |
| Countdown-Badge | `.caption2` | `.semibold` | weiß auf `sunsetOrange` |
| Stats-Zelle Zahl | `.title3` | `.heavy` | Token-Farbe, `monospacedDigit()` |
| Stats-Zelle Label | `.caption2` | `.semibold` | `.secondary` |
| Timeline-Titel | `.subheadline` | `.bold` | primär, `lineLimit(1)` |
| Timeline-Metazeile | `.caption` | regular | `.secondary` |
| Timeline-Hafenvorschau | `.caption2` | regular | `seaGreen` |
| Timeline-Rating | `.caption2` | regular | `seaGreen` |
| Jahr-Divider | `.caption` | `.heavy` | `.secondary` |

---

## 5. Abstände & Rhythmus

- **Listen-Stil Hauptseite:** `List { … }.listStyle(.plain)` — auf iOS 18 ist
  das die `collectionViews`-Backing (relevant für UI-Test-Scrolling).
- **Section-Struktur:** Stats-Strip · Hero · pro Jahr eine Section mit
  `CruiseYearDivider`-Header.
- `listRowInsets`:
  - Stats-Strip: `EdgeInsets()` (full-bleed, Insets über inneres Padding)
  - Hero: `top 8, leading 16, bottom 8, trailing 16`
  - Timeline-Zeile: `top 4, leading 16, bottom 4, trailing 16`
- **Seitenrand-Konvention:** 16pt horizontal außen, 12pt innen in Cards.
- **Vertikaler Card-Innenabstand:** 10pt (Stats-Strip, Hero-Meta, Timeline-Row).
- Jahr-Divider: `.padding(.top 6, .bottom 4, .trailing 16, .leading 10)`,
  `Divider().frame(height: 0.5)`.
- Timeline-Row HStack-Spacing: 12; Thumbnail 34×34, `cornerRadius 6`.
- StatsView-Rhythmus (Referenz, nicht Hauptseite): ScrollView, `VStack spacing 20`,
  äußeres `.padding()`, Grid `spacing 12`.

---

## 6. Ikonografie (SF Symbols)

| Symbol | Verwendung |
|---|---|
| `plus` | „Hinzufügen"-Toolbar (Reisen, Merkliste) |
| `line.3.horizontal.decrease.circle(.fill)` | Filter-Menü (gefüllt = aktiv) |
| `ferry` | Empty-State Reisen; Stats „Kreuzfahrten" |
| `trash` | Löschen (Swipe / Buttons) |
| `mappin.circle.fill` | Start- + Zwischenhafen-Pin (Liste/Detail), Start-Pin Karte |
| `mappin.and.ellipse.circle.fill` | Endhafen-Pin (Liste/Detail) |
| `mappin.and.ellipse` | Stats-Kachel „Häfen" |
| `water.waves` | Seetag-Pin |
| `flag.checkered.circle.fill` | Endhafen auf Weltkarte |
| `circle.fill` | Zwischenhafen auf Weltkarte; Legenden-Punkt |
| `star.fill` | Rating-Badge; Stats „Ø Bewertung" |
| `list.bullet.circle(.fill)` | Karten-Legende ein/aus |
| `eye` / `eye.slash` · `scope` | Legende: Sichtbarkeit / Zoom |
| `calendar` · `globe` · `eurosign.circle` | Stats-Kacheln Reisetage/Länder/Ausgaben |
| `bookmark` | Merkliste Empty-State |
| `wand.and.stars` · `key` · `arrow.up.right.square` | Settings KI/Gemini |
| `icloud` · `bell`(`.badge`) · `externaldrive` | Settings Sync/Benachrichtigung/Daten |
| `square.and.arrow.up` / `square.and.arrow.down` | Export / Import |
| `chevron.left.forwardslash.chevron.right` | GitHub-Link |

Reederei-Logos sind **Emoji** (`shippingLineLogo`, z. B. 🚢), kein SF-Symbol.

---

## 7. Hero-Behandlung

`CruiseHeroCardView` — Zweizonen-Karte, `cornerRadius 16`, wiederverwendbares Muster
für „Fokus-Objekt" auf anderen Seiten.

- **Obere Medienzone (~190pt Höhe):**
  - Hintergrund: Cover-Foto (`sortedPhotos.first`, `aspectRatio(.fill)`) **oder**
    `CruiseGeoFallbackView` (Geo-SVG-Canvas) als inhaltsreicher Fallback — nie ein leeres Icon.
  - **Scrim** für Lesbarkeit: `LinearGradient([.clear, .black.opacity(0.8)], .center → .bottom)`.
  - Text unten links im Scrim: Titel (`.title3`/`.heavy`/weiß) + Subline (`.caption`/`white .8`),
    Padding `.horizontal 12, .bottom 12`.
  - **Badges:** oben links Countdown-Capsule (`sunsetOrange`, nur upcoming, padding 10);
    oben rechts `RatingBadge` (nur rating>0, padding 10).
  - `.clipped()`.
- **Untere Meta-Leiste:** HStack — links Meta (`.caption`/`.secondary`:
  „N Länder · M Häfen · Betrag"), rechts „Details →" (`oceanBlue`); Fill
  `secondarySystemBackground`, `Divider` oben, Padding `.horizontal 12 .vertical 10`.

**RatingBadge** (`RatingBadge.swift`): HStack `star.fill` + `%.1f`, padding
`.horizontal 8 .vertical 4`, Fill `yellow.opacity(0.2)`, Text orange, `Capsule`.

---

## 8. Seiten-Inventar (Ziel-Seiten)

### Karte (`MapView.swift`, navigationTitle „Karte")
- **Zweck:** Interaktive Weltkarte aller Reiserouten (MapKit).
- **Sektionen/Inhalte:**
  - `Map` mit `MapPolyline` pro Reise (`routeColor(at:index)`, lineWidth 3)
  - Hafen-Marker per `Annotation`: Start-Pin / Punkt / Zielflagge + `port.name`-Capsule (`.ultraThinMaterial`)
  - Legenden-Overlay (`.ultraThinMaterial`, `cornerRadius 12`): pro Reise Farbpunkt,
    `cruise.title`, eye/scope-Buttons; max-Höhe 200
  - Toolbar-Toggle Legende; Standort-Permission via `LocationManager`
- **Schwächen:** (1) Legenden-Overlay-Stil (`ultraThinMaterial`, r12) weicht vom
  Card-Standard (`secondarySystemBackground`, r10/16) ab. (2) Marker-Rollenfarben
  folgen der Routenfarbe, nicht dem semantischen Pin-Token-System (kein orange/grün
  Start/End) — Inkonsistenz zu Detail/Geo-Hero.

### Statistik (`StatsView.swift`, navigationTitle „Statistik")
- **Zweck:** Dashboard mit Lifetime-Kennzahlen + Charts.
- **Sektionen/Inhalte:**
  - `quickStatsGrid` (2-spaltig, 6× `StatCard`): Kreuzfahrten=`cruises.count`,
    Reisetage=`totalTravelDays`, Häfen=`uniquePorts`, Länder=`uniqueCountries`,
    Ausgaben=`totalExpenses` (Locale-Währung), Ø Bewertung=`averageRating`
  - BarChart „Kreuzfahrten pro Jahr" (`.blue.gradient`)
  - DonutChart „Ausgaben nach Kategorie" (`SectorMark`) + Legende
  - „Top Reedereien" (prefix 5): Emoji-Logo + Name + Reise-Anzahl
- **Schwächen:** (1) `StatCard` nutzt eigene Farbpalette (`.blue/.cyan/.orange/.green/
  .purple/.yellow`) statt der Marken-Tokens — bricht mit der Stats-Strip-Farbsprache
  der Hauptseite (oceanBlue/oceanLight/seaGreen/sunsetOrange). (2) `cornerRadius 12`
  statt 10/16; linksbündige Kachel-Typo statt zentrierter Stats-Zellen.

### Merkliste (`DealsView.swift`, navigationTitle „Merkliste")
- **Zweck:** Gespeicherte Kreuzfahrt-Angebote (Wunschliste).
- **Sektionen/Inhalte:**
  - `List(.plain)` aus `DealRowView`: Emoji-Logo (44×44, r8, `secondary.opacity(0.1)`),
    Titel (`.headline`), `destination` + `duration`, rechts `formattedPrice` (`.headline`)
    + Rabatt-Capsule `-X%` (rot/weiß)
  - Swipe-to-Delete; Empty-State (`bookmark`); `DealFormView`-Sheet (Form-basiert)
- **Schwächen:** (1) Deal-Zeilen haben **keinen** Card-Hintergrund (flache Listenzeile)
  — bricht mit der gerahmten „grauen Karte" der Timeline-Zeilen. (2) Rabatt nutzt
  rohes `.red`, kein Marken-Token; kein Bezug zum Hero-/Card-Radius-System.

### Mehr (`SettingsView.swift`, navigationTitle „Einstellungen")
- **Zweck:** Einstellungen, KI-Key, Sync-Status, Daten-Export/Import, Demo (Debug).
- **Sektionen/Inhalte:**
  - Erscheinungsbild (`colorScheme`-Picker System/Hell/Dunkel)
  - KI-Funktionen (Gemini-API-Status, Key setzen/entfernen, Google-Link)
  - Synchronisation (iCloud „Geplant")
  - Benachrichtigungen → `NotificationSettingsView` (Toggles, Stepper Tage)
  - Daten → `DataManagementView` (Übersicht-Counts, ZIP-Export/Import, Alle löschen)
  - Demo (nur DEBUG); Info (Version, GitHub)
- **Schwächen:** (1) Reines Standard-`List`-Settings-Layout ohne jede Marken-Identität
  (kein Akzent, keine Tokens) — wirkt generisch neben der redaktionellen Hauptseite.
  (2) Status-Indikatoren nutzen `.green/.red` statt Marken-/semantischer Tokens.

---

## 9. Konsistenz-Regeln (do / don't)

1. **Card-Fill = `secondarySystemBackground`.** Kein hartkodiertes Weiß/Grau. Stats/Hero/Row
   teilen denselben Fill; Differenzierung nur über Radius + Rand.
2. **Corner-Radius-Hierarchie respektieren:** Hero/Fokus-Objekt = **16**, Standard-Karte/
   Zeile = **10**, kleine Thumbnails = 6, Capsules = `Capsule`. Nicht erfinden (kein 8/14/20).
3. **Rand nur am Stats-Strip** (`separator`, 0.5pt). Andere Karten haben **keinen** Rand
   und **keinen** Schatten — Foto/Geo bzw. der Fill trägt die Kontur.
4. **Marken-Tokens statt System-Farben.** Akzent-/Wertfarben aus oceanBlue, oceanLight,
   seaGreen, sunsetOrange (+ semantische Pin-Token). **Nicht** `.blue/.cyan/.green/.red`
   roh verwenden (das ist die aktuelle Schwäche von Stats/Deals).
5. **Nadel-Rollen sind kanonisch:** Start = orange `mappin.circle.fill`, Hafen = blau
   `mappin.circle.fill`, Endpunkt = grün `mappin.and.ellipse.circle.fill`, Seetag =
   hellblau `water.waves`. Start/End immer hervorgehoben (größer/Ring/Flagge).
6. **Nur System-Font (SF), Dynamic-Type-Styles.** Titel `.title3/.heavy`, Werte
   `.title3/.heavy` + `monospacedDigit()`, Labels `.caption2/.semibold/.secondary`,
   Sekundärtext `.secondary`. Keine festen pt-Fontgrößen, keine Custom-Fonts.
7. **16pt außen / 12pt innen / 10pt vertikal.** Listen `.listStyle(.plain)` mit
   `listRowSeparator(.hidden)`; Abstände an den §5-Werten ausrichten.
8. **Leere Zustände inhaltsreich, nicht leer:** `ContentUnavailableView` mit Label-Icon
   + Aktion (wie Reisen/Merkliste), bzw. Geo-/Daten-Fallback statt Platzhalter-Icon.

---

## Quelldateien (alle Pfade ab Repo-Root)

- `ShipTrip/Utilities/Color+Theme.swift`
- `ShipTrip/Views/Cruises/CruiseListView.swift`
- `ShipTrip/Views/Cruises/CruiseTimelineRowView.swift`
- `ShipTrip/Views/Cruises/CruiseHeroCardView.swift`
- `ShipTrip/Views/Cruises/CruiseGeoFallbackView.swift`
- `ShipTrip/Views/Cruises/CruiseStatsStripView.swift`
- `ShipTrip/Views/Cruises/RatingBadge.swift`
- `ShipTrip/Components/PortPinView.swift`
- `ShipTrip/Views/Map/MapView.swift` · `Stats/StatsView.swift` · `Deals/DealsView.swift` · `Settings/SettingsView.swift`
- `docs/ux-pitch-decks/timeline-frame-und-nadeln-spec.md` · `docs/features/hauptansicht-hybrid.md`
