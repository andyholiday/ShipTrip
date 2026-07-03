# Timeline-Frame und Nadeln — Design-Spec

## A) Rahmen fur die Zeitstrahl-Zeilen

### Gewählter Ansatz: Jede Zeile als subtile Card (Option a, reduziert)

Jede `CruiseTimelineRowView` erhält einen eigenen Card-Hintergrund. Nicht denselben
Rahmen wie der Stats-Strip — eine reduzierte Variante ohne `strokeBorder`, um die
Hierarchie zu wahren (Stats-Strip > Hero-Karte > Zeitstrahl-Zeilen).

**Warum diese Wahl:** `.insetGrouped` (Option c) erzwingt ein strukturiertes Layout
das schlecht mit der Full-Bleed-Hero-Karte harmoniert und den `listRowInsets`-Trick
fur den Stats-Strip torpediert. Die Jahres-Gruppe als eine Card (Option b) wirkt bei
mehr als 2-3 Einträgen klotz-artig und versteckt die geschwungene Zeitstrahl-Optik.
Die Einzel-Card (Option a, reduziert) gibt jeder Zeile Boden ohne den grau gerahmten
Stats-Strip oder die abgerundete Hero-Karte zu kopieren.

### Exakte Werte

| Property | Wert |
|---|---|
| `background` | `Color(UIColor.secondarySystemBackground)` |
| `cornerRadius` | `10` (identisch Stats-Strip; kleiner als Hero `16`) |
| `border` | keiner — kein `strokeBorder` fur Zeitstrahl-Zeilen |
| Innen-Padding | `.vertical 6`, `.horizontal 12` (bestehend beibehalten) |
| `listRowInsets` | `EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16)` |
| Zeilen-Abstand | `top: 4 / bottom: 4` via `listRowInsets` |
| Light Mode | `secondarySystemBackground` = systemGray6 (~#F2F2F7) |
| Dark Mode | `secondarySystemBackground` = systemGray5 (~#2C2C2E) |

**Kein `strokeBorder`** auf den Zeilen — der Stats-Strip bekommt seinen Rahmen als
Unterscheidungsmerkmal behalten. Die Hero-Karte braucht keinen, weil das Foto/Geo
fur Kontur sorgt. Die Zeilen erhalten nur Flache, keine Linie.

**Hierarchie-Abstufung:**
- Stats-Strip: `secondarySystemBackground` + `strokeBorder(separator, 0.5)`
- Hero-Karte: Foto/Geo (volle Saturation) + Meta-Leiste `secondarySystemBackground`
- Zeitstrahl-Zeilen: `secondarySystemBackground`, kein Rahmen, `cornerRadius: 10`

---

## B) Nadel-Sprache: Start / Hafen / Endpunkt / Seetag

### Neuer Token

```swift
/// Endhafen-Pin: navyDark (dunkel, kontrastiert gegen Ocean-Verlauf)
static let endPortPin = Color.navyDark   // #1A365D
```

Alternativ-Token falls navyDark zu dunkel fur Dark Mode:
`Color(red: 0.204, green: 0.420, blue: 0.694)` — mittleres Marineblau `#345AB1`.
Empfehlung: `navyDark` testen; bei Dark Mode Visuell-Check genugt wegen des Rings.

### Vier Pin-Typen

| Typ | Kontext | Farbe (Token) | SF-Symbol (PortPinView) | Geo-Punkt-Grosse | Geo-Ring |
|---|---|---|---|---|---|
| **Start** | erster Hafen (sortOrder = min) | `sunsetOrange` `#FF6B35` | `mappin.circle.fill` | `dotR 5.5` | weisser Ring `lineWidth 2` |
| **Hafen** | Zwischenstops | `oceanBlue` `#0C8CE9` | `mappin.circle.fill` | `dotR 3.5` | keiner |
| **Endpunkt** | letzter Hafen (sortOrder = max) | `endPortPin` (`navyDark`) `#1A365D` | `mappin.and.ellipse.circle.fill` | `dotR 5.5` | weisser Ring `lineWidth 2` |
| **Seetag** | `isSeaDay == true` | `oceanLight` `#36A9F0` | `water.waves` | `dotR 2.5` (kleiner, transparent `0.4`) | keiner |

### Geo-Kontrast-Strategie (CruiseGeoFallbackView)

Hintergrund-Verlauf: `navyDark` (#1A365D) → `oceanBlue` (#0C8CE9) → `oceanLight` (#36A9F0)

- **Start** (sunsetOrange): hoher Kontrast gegen alle drei Verlaufsfarben — warm/dunkel
- **Hafen** (oceanBlue, weiss gefullter Kern): auf dunkelblauem Grund sichtbar; als
  weiss ausgefullten Kreis mit oceanBlue-Ring rendern statt umgekehrt, damit er auf
  dem Verlauf lesbar bleibt: `fill white, stroke oceanBlue 1pt`
- **Endpunkt** (navyDark + weisser Ring): Ring schafft Kontrast gegen dunklen Verlaufs-Beginn;
  auf hellem oceanLight-Abschnitt bleibt navyDark als dunkler Anker ebenfalls lesbar
- **Seetag** (oceanLight, kleiner): Grossenreduktion signalisiert "kein Stopp";
  niedrige Opacity (0.4) und kleiner Radius trennen klar von Hafenpunkten

### PortPinType-Ergänzung

Aktuell: `homePort | port | seaDay` — kein `endPort`.

Empfehlung: `case endPort` hinzufugen. Convenience-Init erweitern:

```swift
init(isSeaDay: Bool, isFirst: Bool, isLast: Bool) {
    if isSeaDay       { self = .seaDay }
    else if isFirst   { self = .homePort }
    else if isLast    { self = .endPort }
    else              { self = .port }
}
```

SF-Symbol fur `endPort`: `mappin.and.ellipse.circle.fill` — semantisch "Ziel erreicht",
unterscheidet sich optisch klar von `mappin.circle.fill` (homePort/port).

---

## Zusammenfassung fur Developer-Briefing

1. `CruiseTimelineRowView`: `.background(Color(UIColor.secondarySystemBackground))` +
   `.clipShape(RoundedRectangle(cornerRadius: 10))` auf den Row-Content;
   `listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))`.
2. `Color+Theme.swift`: Token `endPortPin = Color.navyDark` hinzufugen.
3. `PortPinType`: `case endPort` + `mappin.and.ellipse.circle.fill` +
   Farbe `endPortPin`. Convenience-Init um `isLast:` erweitern.
4. `CruiseGeoFallbackView`: Start/Ende als `dotR 5.5` mit weissem Ring `lineWidth 2`;
   Zwischen-Hafen: weiss gefullt, oceanBlue-Stroke 1pt, `dotR 3.5`;
   Seetag: `dotR 2.5`, Opacity 0.4, oceanLight.
