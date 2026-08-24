# Design-Spec — Onboarding (Erststart), Release 1.8.0

Verbindliche Übergabe an den Developer für Task B1 (+ B4-Karte). Sie
beschreibt, **was die Screenshots zeigen** — bei Widerspruch gewinnt der
Screenshot, dann ist diese Datei der Fehler.

- Prototyp: `/Users/andre-studio/Documents/0.Projekte/ShipTrip/prototype-onboarding/`
- Screenshots: `/Users/andre-studio/Documents/0.Projekte/ShipTrip/docs/design/directions/onboarding/shots/`
  (`karte-1..4` × `light|dark`)
- Narrativ: `narrative-onboarding.md` (gleicher Ordner)
- Gerät der Aufnahmen: iPhone 17 Pro, 402 × 874 pt (1206 × 2622 px @3x), iOS 26.5
- Stand: **Repair-Runde 1** (2026-08-24). Was sie geändert hat, steht in
  Abschnitt 9; alle Kontrastwerte in dieser Datei sind aus den neuen PNGs
  gemessen, nicht gerechnet.
- **Für Karte 4 gilt Abschnitt 12.** Die Fix-Runde nach dem letzten Re-Gate
  hat sie erneut umgebaut; die Beschreibungen in den Abschnitten 4, 7, 10 und
  11 beschreiben insoweit den überholten Stand. Gebaut ist der Flow in
  `ShipTrip/Views/Onboarding/` (Task B2) — bei Widerspruch gewinnt der
  Produktivcode.

## 1. Richtung in einem Satz

Der Erststart sieht aus wie die App, die dahinter liegt: großes echtes
Reisefoto, ruhige Typo-Hierarchie, ein sichtbarer Primärweg — und eine
Erlaubnis-Frage, die vorher sagt, was danach passiert.

Der eine bewusste Bruch mit dieser Ruhe steht am Ende: auf Karte 4 ist die
Einstiegs-Aktion das größte Typo-Element des ganzen Flows (Abschnitt 4,
„Signatur-Move").

## 2. Farben — ausschließlich bestehende Token

Keine neuen Markenfarben. Alles kommt aus
`ShipTrip/Utilities/Color+Theme.swift` bzw. aus den semantischen
UIKit-Farben, die die App bereits benutzt.

| Rolle | Token | Wert | Wo |
|---|---|---|---|
| Primär / Tint | `Color.oceanBlue` | `#0C8CE9` | gefüllte Aktionen, aktiver Seitenpunkt, „Überspringen", Icon-Kachel „Karte & Route" (K2), Kontur der ungefüllten Aktion **nur in Dark** |
| Akzent Foto | `Color.sunsetOrange` | `#FF6B35` | Icon-Kachel „Fotos & Ausflüge" (K2), Status-Chip „Beispielreise" (K4) |
| Akzent Erinnerung | `Color.seaGreen` | `#34C759` | Icon-Kachel „Erinnerungen" (K2) **und** die Leit-Kachel auf K3 |
| Label ungefüllte Aktion | `Color.actionLabel` | `#1A365D` hell / `#36A9F0` dunkel | „Später" (K3) |
| Kontur ungefüllte Aktion | `Color.actionBorder` | `#1A365D` hell / `#0C8CE9` dunkel | „Später" (K3) |
| Fließtext | `Color.bodyText` | `#65656B` hell / `#8E8E96` dunkel | alle Fließtexte K1–K4 |
| Screen-Grund | `Color(.systemGroupedBackground)` | `#F2F2F7` / `#000000` | alle vier Karten |
| Karten-Grund | `Color(.secondarySystemGroupedBackground)` | `#FFFFFF` / `#1C1C1E` | Feature-Liste (K2), Hinweis-Box (K3), Fläche der ungefüllten Aktion |
| Text | `.primary` / `.secondary` | adaptiv | Titel / Fußnoten und Captions |

`actionLabel` und `actionBorder` sind **keine neuen Marken**, sondern die
schemaabhängige Wahl zwischen zwei bestehenden Token: `navyDark` auf hellem
Grund, `oceanLight` bzw. `oceanBlue` auf dunklem. Grund: reines `oceanBlue`
als Textfarbe erreicht auf Weiß nur 3,53 : 1 und fällt damit unter WCAG AA
für normalen Text — das war der Gate-Befund gegen die alte, getönte
Zweit-Aktion. In Light tragen Label und Kontur jetzt dieselbe Farbe; vorher
standen dort zwei verschiedene Blaus im selben Button.

`bodyText` ist eine Stufe dunkler als das Caption-Grau der App (#85858B,
3,29 : 1 auf `#F2F2F7`) und erreicht 5,19 : 1. Der app-weite Grau-Token
selbst bleibt unangetastet, und Fußnoten und Captions im Onboarding stehen
weiterhin auf ihm.

**Abweichung, bewusst und benannt:** Die App hat kein gefülltes
`AccentColor.colorset` und benutzt für `.borderedProminent` daher
System-Blau (`#007AFF`), während Icons `oceanBlue` (`#0C8CE9`) nutzen — zwei
Blau nebeneinander. Der Prototyp setzt beides auf `oceanBlue`. Der
Developer übernimmt das für das Onboarding; ob `AccentColor` app-weit auf
`oceanBlue` gezogen wird, ist eine separate Entscheidung (Backlog, nicht
Teil von B1).

Ikonografie: ausschließlich SF Symbols (`map.fill`, `photo.stack.fill`,
`bell.badge.fill`, `bell.badge`, `info.circle`). Keine Emoji, keine
Eigenzeichnungen.

## 3. Raster, Typografie, Formen

- **Seitenrand 20 pt** auf allen vier Karten (gemessen an „Meine Reisen").
- **Radien** aus `DesignRadius`: `lg = 28` für den Foto-Hero (identisch zur
  Hero-Karte auf der Startseite), `md = 16` für Karten-Container und
  Hinweis-Box, `sm = 10` für Buttons und Icon-Kacheln. Eine Radius-Familie,
  drei Stufen — `elevation-radii.md`.
- **Ein Seitenverhältnis für alle Foto-Heros: 3 : 2** (`ProtoMetrics.heroRatio`).
  Bei 362 pt Kartenbreite sind das 241 pt Höhe, auf **beiden** Foto-Karten.
  Vorher standen dort 280 pt (K1) und 220 pt (K4) — zwei Formate ohne Grund,
  und damit zwei Rhythmen für dasselbe Element (`gestalt.md`, Ähnlichkeit).
  Die Höhe ist im Code kein Parameter mehr, sondern folgt aus dem Verhältnis.
- **Typo-Leiter, drei sichtbare Stufen** (`typography-scale.md`: mehr als
  drei ist ein Befund): `.title.bold` (28 pt, **alle vier Überschriften**) →
  `.body`/`.headline` → `.subheadline`/`.footnote`. Alles semantische
  Text-Styles, kein `.system(size:)` außer für Symbolgrößen.
- **`.largeTitle` kommt im ganzen Flow nicht vor.** Das größte Typo-Element
  jeder Karte ist ihre Überschrift. Der Signatur-Move auf Karte 4 arbeitet
  deshalb nicht mit Schriftgröße, sondern mit Form (Abschnitt 10); die
  einzige zusätzliche Größe dort — `.title3.heavy` für den Kartentitel —
  liegt in der Bildebene der Karte, weiß auf Foto, und mischt sich nicht in
  die Leseleiter des Screens.
- **Abstände** auf 4-pt-Raster: 8 · 12 · 16 · 20 · 28. Der Abstand zwischen
  Gruppen (28) ist rund doppelt so groß wie der innerhalb einer Gruppe (12)
  — `spacing-grid.md`, Gestalt-Nähe.

## 4. Die vier Karten

### Gemeinsamer Rahmen

- Kopfzeile 44 pt hoch, rechtsbündig „Überspringen" (`.body`, `oceanBlue`).
  **Auf Karte 4 nicht vorhanden** — dort gibt es nur noch die beiden echten
  Ausgänge.
- Fußzeile: Seitenpunkte, dann ein **fest reservierter Aktions-Block von
  174 pt**, in dem die Aktionen unten sitzen; darunter ggf. eine zentrierte
  Fußnote. Padding oben 16, unten 16, seitlich 20. Die 174 pt sind die
  höchste Staffel des Flows (Karte 3: 66 + 12 + 66 + 12 + Fußnote).
- Seitenpunkte: 8 pt hoch; der aktive ist eine **22 pt breite Kapsel** in
  `oceanBlue`, die inaktiven Kreise in `.secondary` bei 28 % — die Position
  ist damit auch ohne Farbunterscheidung ablesbar. Sie stehen auf **allen
  vier Karten bei y 626–634 pt**, also 206 pt über der unteren Safe Area
  (gemessen in allen acht Aufnahmen). Die Inhaltsspalte ist das flexible
  Glied und nimmt die Höhendifferenz auf.
- Aktionen, volle Breite, Radius `sm`, **ein** Größen-Level:

| Form | Höhe | Fläche | Label |
|---|---|---|---|
| Primär (K1–K4) | 66 | `oceanBlue` gefüllt | `.headline`, weiß |
| Ungefüllt (nur K3) | 66 | `secondarySystemGroupedBackground` + 1,5 pt Kontur `actionBorder` | `.headline`, `actionLabel` |

Die Primär-Markierung trägt **fill-vs-outline, nicht Größe**. Das größte
Typo-Element jeder Karte ist damit wieder ihre Überschrift (`.title.bold`,
28 pt) und nicht ein Button-Label.

Die ungefüllte Form ist **nicht** mehr `.bordered` mit Tint. Deren getönte
Füllung lag in Light Mode bei 1,22 : 1 zum Grund und trug ein Label bei
2,60 : 1 — sie las sich als deaktivierter Block, nicht als zweiter Weg.
Gemessen an den aktuellen Aufnahmen:

| Messung | Light | Dark | Schwelle |
|---|---|---|---|
| Label auf der Fläche | 12,14 : 1 | 6,55 : 1 | 4,5 : 1 (WCAG AA, Text) |
| Kontur gegen den Grund | 10,89 : 1 | 4,86 : 1 | 3 : 1 (WCAG 1.4.11, Komponente) |
| Fläche gegen den Grund | 1,12 : 1 | 1,23 : 1 | — |

In Light trägt die Kontur jetzt dieselbe Farbe wie das Label (`navyDark`).
Vorher standen dort zwei verschiedene Blaus nebeneinander — Label `navyDark`
#1A365D, Kontur `oceanBlue` #0C8CE9 —, was den Button als zwei Systeme in
einem las. Navy auf Navy zitiert die „Reise öffnen"-Pille der App
(`CruiseHeroCardView`). Dark bleibt unverändert: Label `oceanLight`, Kontur
`oceanBlue`.

Die Fläche allein trägt die Erkennbarkeit also weiterhin nicht — das tut
die Kontur, und genau dafür verlangt WCAG 1.4.11 ihre 3 : 1. Die Fläche ist
die Kartenfläche der App und hält die Zweit-Aktion optisch auf derselben
Ebene wie Feature-Liste und Hinweis-Box.

### Karte 1 — Wertversprechen

Foto-Hero (`hero_fjord`, 3 : 2 = 241 pt hoch, Radius 28, Verlaufs-Scrim
`clear → black 55 %` über der unteren Hälfte, Bildunterschrift als
`.ultraThinMaterial`-Kapsel mit 16 pt Innenabstand) · Titel „Dein Logbuch
für jede Kreuzfahrt" · Fließtext (Route, Häfen, Fotos, Ausgaben; offline;
bleibt auf dem Gerät) · „Weiter".

Warum ein Foto und kein Illustrations-Set: die App zeigt auf jeder
Reisekarte echte Fotos; eine gezeichnete Onboarding-Welt würde beim ersten
Screen nach dem Flow brechen (`gestalt.md`, Ähnlichkeit).

### Karte 2 — Kern-Features

Titel `.title.bold` · ein Satz Untertitel · **eine** gruppierte Karte mit
drei Zeilen, getrennt durch `Divider` mit 64 pt Vorsprung. Zeile: Icon
20 pt semibold in einer 48 × 48 Kachel (Radius 10, Tint bei 14 %), rechts
`.headline` + `.subheadline` secondary, vertikaler Zeilenabstand 16.

Die drei Zeilen sind fix: **Karte & Route** (`map.fill`, oceanBlue) ·
**Fotos & Ausflüge** (`photo.stack.fill`, sunsetOrange) ·
**Erinnerungen** (`bell.badge.fill`, seaGreen). Die dritte Zeile ist die
Vorbereitung für Karte 3 — erst nennen, dann fragen
(`onboarding-activation.md`, „Prime before the system dialog").

### Karte 3 — Soft-Ask Erinnerungen (Härtefall, B4)

Aufbau, übernommen aus dem bestehenden `ReminderPermissionSheet`
(`ShipTrip/Views/Cruises/CruiseFormView.swift:946`), damit Erststart und
kontextueller Ask dieselbe Sprache sprechen:

1. **Dieselbe Kachel wie die Zeile „Erinnerungen" auf Karte 2**:
   `bell.badge.fill` 28 pt semibold in `seaGreen`, auf 64 × 64 mit Radius
   `sm = 10` und `seaGreen` bei 14 %. Vorher stand hier ein 96-pt-Kreis in
   `oceanBlue` — eine Form, die es sonst nirgends im Flow gibt, in einer
   Farbe, die die Erinnerung nirgends sonst hat. Jetzt zitiert die Karte
   sichtbar die Zeile, aus der sie hervorgeht (`gestalt.md`, Ähnlichkeit;
   `onboarding-activation.md`, „Prime before the system dialog").
2. Titel: „Sollen wir dich an die Abreise erinnern?" — eine Frage, keine
   Aufforderung.
3. Nutzen **und Grenze**: „Ein paar Tage vor dem Auslaufen bekommst du
   einen Hinweis auf deine nächste Reise. Mehr nicht — keine Werbung, keine
   täglichen Meldungen."
4. **Transparenz-Box** (Radius 16, `secondarySystemGroupedBackground`,
   `info.circle` + `.footnote` secondary — eine Typo-Stufe unter dem
   Fließtext, damit sie als Fußnote und nicht als zweite Erklärung liest):
   „iOS fragt dich anschließend
   selbst um Erlaubnis — aber erst, wenn du hier auf ‚Erinnerungen
   aktivieren' tippst." Dieser Satz ist der Kern der Karte, nicht Deko: er
   macht die Zustimmung *informiert* (Nielsen 1, Sichtbarkeit des
   Systemzustands).
5. Aktionen: „Erinnerungen aktivieren" (gefüllt) · **„Später" (umrandet,
   gleiche Breite, gleiche Höhe, gleiche Schrift)**.
6. Fußnote: „Beides lässt sich jederzeit in den Einstellungen ändern."

**Kein Dark Pattern, prüfbar an diesen fünf Punkten:** „Später" ist gleich
groß und gleich lesbar wie die Zustimmung (kein grauer Mini-Link, kein
„Nein danke, ich verpasse gerne meine Reise"); die Ablehnung ist mit einem
Tipp erledigt und kehrt nicht wieder; die Karte macht keine Aussage über
Konsequenzen, die es nicht gibt; sie sagt vorab, dass der Systemdialog
folgt; und sie nennt den Rückweg.

Der Satz „gleich lesbar" war bis zur Repair-Runde eine Behauptung, kein
Befund: das alte „Später" trug 2,60 : 1, das „Erinnerungen aktivieren"
daneben 3,53 : 1 bei größerem Gewicht. Jetzt liegt „Später" bei 12,14 : 1
(hell) bzw. 6,55 : 1 (dunkel) und ist damit **besser** lesbar als die
Zustimmung. Karte 3 ist zugleich die einzige Karte, die überhaupt zwei
Aktionen in der Fußzeile trägt — und beide haben dieselbe Höhe (66 pt) und
dieselbe Schrift; unterschieden werden sie allein durch gefüllt gegen
umrandet.

**Verhalten, das der Developer bauen muss** (der Prototyp blättert nur
weiter): „Erinnerungen aktivieren" ruft
`UNUserNotificationCenter.requestAuthorization` auf und blättert danach
weiter — unabhängig vom Ergebnis. „Später" und „Überspringen" lösen
**keinen** Systemdialog aus, setzen kein Flag außer dem Flow-Fortschritt
und lassen den bestehenden kontextuellen Ask beim ersten Reise-Speichern
unangetastet. Kalender-Berechtigung bleibt außen vor (ZIEL.md, Kriterium 2).

### Karte 4 — Start-CTA (Signatur-Move)

Titel „Bereit für deine erste Reise" (`.title.bold`) · Fließtext ·
**Mini-Reise-Karte „Norwegische Fjorde"** (224 pt, antippbar) · Fußnote „Die
Beispielreise ist als Demo markiert und lässt sich mit einem Tipp wieder
entfernen." · in der Fußzeile die eine gefüllte Aktion „Erste Reise anlegen"
(66 pt). Beschreibung und Begründung des Moves: Abschnitt 10.

Kein Foto-Hero mehr wie auf Karte 1: es gäbe zwei Bilder, die um dieselbe
Aufmerksamkeit konkurrieren, und der Signatur-Move wäre keiner mehr.

Die Fußnote ist Pflicht, nicht Kür: sie ist die Antwort auf „was passiert
mit meinen Daten, wenn ich das antippe" und der Grund, warum die
Demo-Option ohne Warn-Dialog auskommen darf. Sie steht deshalb **unter der
Karte**, die sie erklärt, und nicht mehr unter der Taste.

## 5. Bewegung

- **Zitat:** Familie *Stagger / Cascade*, Muster **List Entrance Cascade**
  (`design-library/references/systems/motion-benchmarks.md`).
- **Umsetzung:** Beim Erscheinen einer Karte laufen ihre Elemente in
  Lesereihenfolge ein — `opacity 0 → 1`, `offset y 12 → 0`,
  `easeOut 250 ms` (`standardIn`), Versatz **30 ms** je Element
  (`staggerStep`), gedeckelt bei 6 (`staggerCap`). Im Prototyp:
  `ProtoTheme.swift`, `CascadeIn`.
- **Kartenwechsel:** die native Seitentransition von
  `TabView(.page)` — bewusst keine eigene Animation. Ein Erststart ist
  nicht der Ort für eine erfundene Geste.
- **Einmal, nicht wiederholt:** eine bereits gesehene Karte animiert beim
  Zurückwischen nicht erneut (`seen`-Menge in `OnboardingFlow`), sonst
  liest sich die Kaskade als Ruckeln.
- **Reduce Motion:** `@Environment(\.accessibilityReduceMotion)` schaltet
  die Kaskade vollständig ab (kein Versatz, keine Animation) — die Inhalte
  sind sofort da.
- **Status:** `motion: unverified` — Bewegung wird nicht fotografiert und
  war nicht Teil der Screenshot-Abnahme. Sie ist im Prototyp implementiert
  und live zu beurteilen.

## 6. Accessibility

Was implementiert ist:

- Alle Schriftgrade sind semantische Text-Styles → Dynamic Type wirkt.
- Seitenpunkte: ein A11y-Element mit Label „Schritt n von 4"; der aktive
  Punkt ist zusätzlich **breiter**, die Position also nicht nur farblich
  kodiert.
- Buttons 66 pt hoch, die Mini-Reise-Karte 224 pt — beide weit über der
  44-pt-Mindestgröße der HIG.
- Reduce Motion schaltet die Kaskade ab.
- Beide Farbschemata sind gebaut und aufgenommen (je vier Shots).
- **Die ungefüllte Aktion erfüllt WCAG AA für Text** (12,14 : 1 hell,
  6,55 : 1 dunkel) und 1.4.11 für die Komponentengrenze (10,89 : 1 hell,
  4,86 : 1 dunkel).
- **Fließtext-Grau `bodyText`:** gemessen aus `karte-4--light.png`
  #65656B → **5,19 : 1** auf `#F2F2F7`, über der AA-Schwelle von 4,5 : 1.
  Das App-Caption-Grau #85858B lag bei 3,29 : 1. Fußnoten und Captions
  bleiben bewusst auf dem App-Grau (`.secondary`) — dort ist es
  Zusatzinformation, die neben einer bereits verständlichen Aussage steht.
- **Die Mini-Reise-Karte** ist ein einzelnes A11y-Element mit der Rolle
  Button und dem Label „Ansehen: Norwegische Fjorde, Norwegen · 7 Tage,
  Beispielreise". Ihr Titel steht bei **11,91 : 1** (weiß auf dem
  verdunkelten Foto, aus dem PNG gemessen).

Was der Developer nachziehen muss — offene Punkte, ehrlich benannt:

1. **Kein `ScrollView`.** Die Karten sind auf 402 × 874 pt bei
   Standard-Textgröße gesetzt. Bei großen Dynamic-Type-Stufen (ab ca. `AX1`)
   reicht die Höhe von Karte 2 und 3 nicht. Der Produktivcode muss den
   Inhaltsbereich in einen `ScrollView` legen, Fußzeile und Kopfzeile
   außerhalb. Nicht im Prototyp gelöst, weil ein Scroll-Container den
   deterministischen Screenshot verschiebt.
2. **Kontrast „Überspringen": gemessen 3,17 : 1** (`#0C8CE9` auf
   `#F2F2F7`, `.body` 17 pt regular). Das ist die iOS-übliche Tint-Link-
   Praxis und dasselbe Niveau wie System-Blau (3,60 : 1), aber **unter
   WCAG AA 4,5 : 1 für normalen Text**. Zwei saubere Auswege: das Label auf
   `.body.weight(.semibold)` setzen (dann gilt der 3 : 1-Schwellwert für
   großen Text) oder in Light Mode `Color.navyDark` (10,9 : 1) verwenden
   und die Interaktivität über die Position tragen. Entscheidung bewusst
   nicht hier getroffen.
3. **Icon-Kacheln (K2 und die Leit-Kachel auf K3)** liegen bei 3,00 : 1
   (blau), 2,45 : 1 (orange) und **1,79 : 1 (grün, gemessen auf K3)**
   Glyph-gegen-Kachel; die Kachel selbst steht bei 1,11 : 1 zum Grund.
   Zulässig, weil die Glyphen **dekorativ** sind — die Bedeutung trägt
   jeweils das Textlabel daneben bzw. auf K3 die Überschrift direkt
   darunter, WCAG 1.4.11 greift dafür nicht. Konsequenz für den Developer:
   die Tint-Deckkraft nicht über 14 % anheben und **niemals** Text in der
   Kachelfarbe setzen.
   **Offen und bewusst nicht behoben:** Grün ist der schwächste der drei
   Tints, und die Leit-Kachel auf K3 erbt diese Schwäche. Sie über 14 %
   anzuheben würde die Kachel von der Karte-2-Zeile lösen, die sie zitieren
   soll. Wenn die Kachel-Familie insgesamt kräftiger werden soll, ist das
   eine Entscheidung für alle vier Kacheln, nicht für diese eine.
4. **VoiceOver-Reihenfolge und -Labels** der Buttons sind nicht geprüft
   worden; der Prototyp führt keine Aktion aus.
5. **Weißer Text auf `oceanBlue`** (gefüllte Aktionen) misst 3,53 : 1 —
   ausreichend für das `.headline`-Label (fetter Text ab 14 pt, 3 : 1) und
   für den Button als UI-Komponente. **Nicht** ausreichend, wenn jemand
   `oceanBlue` später als Textfarbe für Fließtext weiterverwendet.
6. **Weißer Text auf `sunsetOrange`** (Status-Chip „Beispielreise", K4)
   misst 2,83 : 1 und liegt damit unter jeder Schwelle. Aus der App 1 : 1
   übernommen, Begründung und Kompensation in Abschnitt 10.

## 7. Sprache

Der Prototyp ist durchgehend deutsch und hart verdrahtet. Für die
Produktivumsetzung: jeder sichtbare String als `String(localized:)`, die
EN-Fassung kommt zentral über C5 (Lokalisierungs-Gate). Zwei Stellen, die
beim Übersetzen brechen können, weil sie auf Zeilenumbruch gesetzt sind:
der Titel von Karte 2 (zweizeilig) und die Transparenz-Box auf Karte 3
(dreizeilig) — beide brauchen in EN eine Kontrolle im Simulator, keine
Kürzung im Blindflug.

Dritte Stelle: die Bodenzeile der Mini-Reise-Karte auf Karte 4. Kapsel und
Pille belegen zusammen 238 von 330 pt; beide tragen
`minimumScaleFactor(0.85)`, aber eine deutlich längere Übersetzung von
„Ansehen" gehört im Simulator geprüft.

## 8. Übergabe-Grenze

Der Developer erbt aus `prototype-onboarding/`:

- **die Views**: `OnboardingCards.swift` (die vier Karten),
  `OnboardingFlow.swift` (Rahmen, Kopf-/Fußzeile, Blättern),
- **die Bausteine** aus `ProtoTheme.swift`: `ProtoPrimaryButton`,
  `ProtoSecondaryButton`, `ProtoPageDots`, `ProtoHero`, `ProtoTripCard`,
  `CascadeIn` — umbenannt und in `ShipTrip/Views/Onboarding/` einsortiert.
  `ProtoTripCard` ist die einzige echte Neuentwicklung; im Produktivcode
  sollte sie **nicht** neu gebaut, sondern als kompakte Variante von
  `CruiseHeroCardView` geführt werden, damit beide Karten eine Quelle haben,
- **die Token-Bezüge**: `Space`, `Motion`, `ProtoMetrics` und die Kopien
  der Brand-Farben in `ProtoTheme.swift` werden **nicht** als Datei
  mitgenommen. Farben und Radien kommen im Produktivcode direkt aus
  `ShipTrip/Utilities/Color+Theme.swift`; `Space`, `Motion` und die beiden
  Maße aus `ProtoMetrics` (Hero-Verhältnis 3 : 2, Aktionshöhen 52 / 88)
  gehören dorthin ergänzt, wenn sie gebraucht werden. **`actionLabel` ist
  Pflicht**, nicht Kür: ohne diesen adaptiven Token fällt die ungefüllte
  Aktion auf 2,60 : 1 zurück, und genau daran ist die erste Runde
  gescheitert.

Der Developer erbt **nicht**:

- das Gerüst — `PrototypeApp.swift`, `ProtoScreens`, `ProtoRequest`,
  `proto.json`, `project.yml`, das generierte `.xcodeproj`;
- die Bild-Assets `hero_fjord` / `hero_hafen`: das sind Kopien von
  `demo_port_geiranger` und `demo_port_bergen` aus
  `ShipTrip/Assets.xcassets`. Im Produktivcode werden die
  **Originalnamen** referenziert, keine zweite Kopie angelegt;
- die Navigation: `startIndex`, das Blättern per Button und die
  `seen`-Menge sind Prototyp-Mechanik. Der Produktivcode braucht statt
  dessen `hasCompletedOnboarding` (@AppStorage), den echten
  Permission-Aufruf, den Aufruf aus den Einstellungen und die beiden
  Ausgänge auf Karte 4.

`prototype-onboarding/` bleibt bis zur Abnahme von B1 auf der Platte und
wird danach gelöscht. Es ist kein Produktivcode und gehört in kein Target.

## 9. Was die Repair-Runde geändert hat

Sechs Befunde des visuellen Gates, in der Reihenfolge ihres Schadens. Die
Screenshots im Shots-Ordner sind vollständig neu aufgenommen (8/8, exit 0);
die alten Bilder sind überschrieben und nicht mehr verfügbar.

| Befund | Änderung |
|---|---|
| Ungefüllte Aktion zu kontrastarm (K3, K4) | Neue Form: Kartenfläche + 1,5 pt `oceanBlue`-Kontur + `actionLabel`. Label 2,60 → 12,14 : 1 (hell), Kontur 3,17 : 1 |
| Signatur fehlte (Veto) | Display-Aktion auf K4: `.largeTitle.bold` auf 88 pt, das größte Typo-Element des Flows |
| Zwei Hero-Formate | Ein Seitenverhältnis 3 : 2 auf beiden Foto-Karten (241 pt) |
| Zwei Überschriftgrößen | Alle vier Überschriften `.title.bold` (28 pt) |
| Glocken-Badge als Kreis (K3) | Ersetzt durch die `seaGreen`-Kachel der Zeile „Erinnerungen" von K2, 64 pt, Radius 10 |
| Hinweis-Box zu laut (K3) | `.subheadline` → `.footnote` |

Nicht angefasst, weil ausdrücklich außerhalb dieser Runde: der app-weite
Grau-Token und die `AccentColor`-Frage aus Abschnitt 2 (beide Backlog).

Abschnitt 10 setzt diesen Abschnitt für Karte 4 **außer Kraft**: die
Display-Aktion aus Zeile 2 der Tabelle ist ersatzlos entfallen.

## 10. Neuableitung Karte 4

Das Gate hat Karte 4 zweimal zurückgewiesen: erst ohne Signatur-Move, dann
mit einem überdrehten — die Display-Aktion war mit `.largeTitle.bold` auf
88 pt größer als die Überschrift des Screens, und damit kippte die
Hierarchie. Karte 4 ist deshalb neu abgeleitet, nicht poliert.

### Der Move in einem Satz

**„Beispielreise ansehen" ist kein Button mehr, sondern eine echte,
antippbare Mini-Reise-Karte in der Hero-Karten-Sprache der App — die Wahl
am Ende des Erststarts steht damit als zwei sichtbar verschiedene Zukünfte
nebeneinander: die leere App, die man selbst füllt (die eine gefüllte
Taste), und die gefüllte App, die man sich vorher ansehen kann (die
Karte).**

### Warum dieser Move

- **Er macht die Entscheidung schneller lesbar, statt sie lauter zu
  machen.** Vorher standen zwei Beschriftungen untereinander, die sich nur
  im Wortlaut unterschieden; die Wahl war erst nach dem Lesen beider Labels
  zu treffen. Jetzt trägt die Form die Information: Fläche gegen Foto,
  Handlung gegen Vorschau — Unterscheidbarkeit über Ähnlichkeit und
  Prägnanz (`gestalt.md`), nicht über Größe.
- **Er zitiert die App, statt mit ihr zu brechen.** Die Karte ist Zeile für
  Zeile `CruiseHeroCardView` (siehe Maßtabelle): Foto, Scrim von der Mitte
  nach unten bei 84 %, Status-Chip in `sunsetOrange`, Titel, Meta-Kapsel in
  Weiß bei 16 %, weiße Pille mit `arrow.right` in `navyDark`, Radius 28,
  Schatten `navyDark` 22 % / r17 / y10. Wer sie antippt, sieht danach exakt
  diese Karte wieder — das ist die Richtung „App-Kontinuität" an der
  Stelle, an der der Flow in die App übergeht.
- **Er ist genau einer, und er konkurriert nicht.** Auf Karte 4 gibt es nur
  einen gefüllten, markenblauen Block: „Erste Reise anlegen". Die Karte ist
  bild-, nicht markenfarben; ihre Antippbarkeit trägt die weiße Pille, nicht
  Größe oder Blau. Leserichtung: **Überschrift → Karte → CTA**, geführt
  wird von der CTA.

### Maße und Werte

| Element | Wert | Herkunft / Messung |
|---|---|---|
| Überschrift | `.title.bold`, 28 pt | größtes Typo-Element des Screens |
| Mini-Reise-Karte | 224 pt hoch, Radius 28 | App-Karte ist 286, Hero auf K1 ist 241 — sichtbar eine Stufe kleiner als beide |
| Kartentitel | `.title3.heavy`, 20 pt, weiß | 11,91 : 1 gegen das verdunkelte Foto (aus dem PNG) |
| Meta-Kapsel / Pille | `.caption`, 12 pt | „Norwegen · 7 Tage" 127 pt, „Ansehen →" 111 pt, zusammen 238 von 330 pt |
| Primär-Aktion | 66 pt, `.headline` 17 pt | dieselbe Skala wie K1–K3, gemessen 66,0 pt in allen Aufnahmen |

Preis, offen benannt: der `sunsetOrange`-Chip „Beispielreise" trägt weiße
Schrift bei **2,83 : 1** — derselbe Wert wie der Status-Chip der App
(`CruiseHeroCardView`, „In N Tagen"), von dort 1 : 1 übernommen. Er bleibt,
weil er ein nicht-interaktiver Status-Marker ist, dessen Aussage direkt
unter der Karte im Fließtext wiederholt wird („Die Beispielreise ist als
Demo markiert…"); die Information hängt also an keiner Stelle allein an
diesem Kontrast. Ihn hier zu ändern hieße, den Status-Chip der App zu
ändern — eine app-weite Entscheidung, nicht eine des Onboardings.

### Die vier Flow-Korrekturen

| Befund | Änderung | Nachweis |
|---|---|---|
| Seitenpunkte wandern 146 pt | Aktions-Block auf feste 174 pt reserviert, Aktionen darin unten; Inhaltsspalte absorbiert die Differenz | Punkte auf allen vier Karten bei y 626,0–633,7 pt |
| Zwei Button-Größen-Level | Ungefüllte Aktion 52 → 66 pt; Display-Aktion entfallen | alle Aktions-Bänder messen 66,0 pt |
| Zwei Blaus im Sekundär-Button (light) | Kontur `oceanBlue` → `actionBorder` (= `navyDark` in Light), Label unverändert `navyDark`; Dark unverändert | Kontur 10,89 : 1 statt 3,17 : 1 |
| Fließtext-Grau unter AA | `.secondary` → `bodyText` #65656B für alle Fließtexte; Fußnoten bleiben auf `.secondary` | 5,19 : 1 statt 3,29 : 1 auf `#F2F2F7` |

**Der Preis der festen Punkt-Position, benannt:** die reservierten 174 pt
folgen der höchsten Staffel (Karte 3). Auf den Karten 1, 2 und 4 bleibt
zwischen Punkten und Taste ein leeres Band von rund 124 pt. Das ist keine
Nachlässigkeit, sondern die Gegenrechnung: entweder springen die Punkte
beim Wischen, oder das Band steht. Es steht auf allen drei Karten gleich
hoch und trennt Inhalts- von Aktionszone.

Nicht angefasst: Karten 1–3 in ihrer Struktur, die Soft-Ask-Geometrie auf
Karte 3, der app-weite Grau-Token.

## 11. Repair-Runde Karte 4

Diese Runde gewichtet um und poliert; der Signatur-Move aus Abschnitt 10
(die echte Mini-Reise-Karte als zweite Option) ist im visuellen Gate
bestanden und bleibt unverändert bestehen. Es kommt kein zweiter Move
hinzu. Wo dieser Abschnitt Abschnitt 10 widerspricht, gilt Abschnitt 11:
das betrifft die feste Höhe des Aktions-Blocks (174 pt) und das orange
Etikett auf der Reise-Karte.

### Die fünf Änderungen

| Befund | Änderung | Nachweis (gemessen im Shot) |
|---|---|---|
| Karte 4: zwei Elemente konkurrieren als primär | Reise-Karte + Fußnote aus der Inhaltsspalte in die Aktions-Gruppe geholt; Etikett achromatisch statt `sunsetOrange` | Kartenunterkante 648 pt, CTA-Oberkante 758 pt (vorher ~550 pt Abstand) |
| Seitenpunkte gruppieren mit nichts | Punkte fest 28 pt über der Primär-Aktion, feste Block-Höhe entfällt | 28,3 pt auf allen vier Karten (Punkte 8,0 pt hoch) |
| Karte 4: weiße Pille auf hellster Bildstelle | Scrim dreistufig (0 % / 45 % / 90 %) nach dem Vorbild der App-Hero-Karte, neues Motiv mit dunklem Wasser im unteren Drittel | Pille steht auf einer Passage bei rund 10 % Helligkeit |
| Karte 4: Overlays auf zwei Personen | Motiv getauscht: statt Bryggen/Bergen die Fjord-Aufnahme der Hero-Karte der App | keine Figur im Bild, kein Overlay über einer Figur |
| Karte 3: „Später"-Kontur wechselt die Familie | `actionBorder` in beiden Modi `systemGray` #8E8E93, 1 pt statt 1,5 pt | 3,53 : 1 (Light) / 4,57 : 1 (Dark), beide über WCAG 1.4.11 |

### Warum das Etikett und nicht die Pille gedämpft wurde

Das Gate ließ die Wahl: entweder die „Ansehen"-Pille streichen oder dem
Etikett das Orange nehmen. Gestrichen wurde das Orange, weil die Pille
das einzige sichtbare Zeichen dafür ist, dass die Karte antippbar ist —
ohne sie wäre der zweite Weg nur noch ein Bild, und die beiden Optionen
wären erst recht kein Paar mehr. Genau das ist die Eigenschaft, die das
Gate am Move bestanden hat. Die Pille ist zudem achromatisch (weiß auf
dunklem Scrim) und dasselbe Bauteil wie „Reise öffnen" in der App;
gesättigt ist auf Karte 4 damit genau ein Block: die blaue Primär-Taste
(60-30-10, `design-library/references/systems/color-systems.md`).

Das Etikett trägt jetzt `black` bei 55 % in einer Kapsel. Dunkel statt
hell, weil es oberhalb des Scrim-Schwerpunkts sitzt und dort auch über
hellem Bildinhalt lesbar bleiben muss. Fachlich ist die Dämpfung ohnehin
richtig: das Orange der App markiert einen laufenden Countdown („In 21
Tagen"), ein Demo-Etikett trägt keine solche Dringlichkeit.

### Warum das Motiv getauscht wurde

Das Gate schlug für die Overlays auf den beiden Personen einen
Fokus-Crop nach rechts vor. Das gab die Quelle nicht her: `hero_hafen`
misst 1200 × 675 px, das Kartenformat 362 × 224 pt lässt bei
`fill`-Skalierung nur 109 px Spielraum — die beiden Figuren stehen über
300 px breit im linken Bilddrittel und lassen sich damit nicht aus dem
Overlay-Bereich schieben. Das Overlay-Paar stattdessen zu versetzen
hätte die Anordnung der App-Hero-Karte aufgegeben, also den Move selbst
beschädigt.

Deshalb der dritte Weg: die Karte zeigt jetzt `hero_reise`, eine Kopie
von `cover_ship_aidanova` — genau das Bild, das die Hero-Karte der App
für „Norwegische Fjorde" verwendet. Damit erfüllt sie das Gate-Ziel
(„kein Overlay über einer Figur") ohne Crop-Akrobatik, zitiert die
App-Karte noch enger als vorher, hat ein von Natur aus dunkles unteres
Drittel für die weiße Pille — und zeigt endlich einen Fjord statt einer
Hafenzeile unter der Überschrift „Norwegische Fjorde". `hero_hafen`
wurde aus dem Prototyp-Katalog entfernt.

### Was der Preis der Umgewichtung ist

Die feste Aktions-Block-Höhe aus Abschnitt 10 ist entfallen. Die
Seitenpunkte stehen dadurch nicht mehr auf jeder Karte gleich hoch —
auf Karte 3 sitzen sie höher, weil die Staffel dort zwei Tasten und eine
Fußnote trägt. Das ist bewusst getauscht: Nähe schlägt Ausrichtung
(`design-library/references/psychology/gestalt.md`). Punkte, die überall
gleich hoch stehen, aber 340 pt vom Inhalt und 380 pt von der Taste
entfernt, gehören zu nichts; Punkte 28 pt über der Taste gehören zur
Aktion.

Die überschüssige Seitenhöhe fällt jetzt als **ein** Zwischenraum
zwischen Inhaltsspalte und Aktions-Gruppe an: 205 pt auf Karte 4,
207 pt auf Karte 1, 160 pt auf Karte 3. Vorher waren es zwei Bänder um
freistehende Punkte herum.

Nicht angefasst: Karten 1–3 in ihrer Struktur, die Soft-Ask-Geometrie
und die „Später"-Ehrlichkeit auf Karte 3, Bewegung, Sprache, Token der
App.

## 12. Fix-Runde Karte 4 — die Wahl als Paar (gebauter Stand)

Das Re-Gate nach Abschnitt 11 hat Karte 4 noch einmal zurückgewiesen: die
Reise-Karte las sich mit eigener „Ansehen"-Pille als lauteste, saturierte
Fläche des Screens und damit als konkurrierender Primary, der Intro-Satz
stand rund 200 pt über der Karte, die er ankündigt, und Text- und
Kartenachse liefen auseinander. Andre genehmigte am 2026-08-24 eine letzte,
eng geführte Fix-Runde; sie ist im Gate bestanden
(`directions/onboarding/gate-notes.md`, Abschluss-Absatz) und im
Produktivcode umgesetzt.

**Dieser Abschnitt setzt für Karte 4 die Abschnitte 4, 7, 10 und 11 außer
Kraft**, soweit sie ihr widersprechen. Karten 1–3, die Soft-Ask-Geometrie,
Bewegung, Sprache und die Token der App sind unverändert.

### Die vier Änderungen

| Befund des Re-Gates | Änderung |
|---|---|
| Drei Blöcke konkurrieren, der lauteste ist die Zweit-Option | Beide Ausgänge stehen als gestapeltes Paar in der Aktions-Gruppe — gefüllt „Erste Reise anlegen" über ungefüllt „Beispielreise ansehen", gleiche Breite, gleiche Höhe (66 pt), Abstand 12: exakt die Karte-3-Behandlung |
| Die Karte trägt eine eigene weiße „Ansehen"-Pille | **Pille ersatzlos gestrichen.** Die Karte ist Illustration der zweiten Option; die ganze Fläche ist antippbar und löst dieselbe Aktion aus wie die ungefüllte Taste |
| 202 pt Leerraum zwischen Intro-Satz und Karte | Die Karte steht wieder in der Inhaltsspalte, **28 pt unter der Copy** — derselbe Bild-zu-Text-Abstand wie auf Karte 1. Der Überschuss fällt unterhalb an, über den Seitenpunkten |
| Zwei Achsen (Text 27 pt, Karte/CTA 20 pt) | Alles auf der 20-pt-Achse; die Inhaltsspalte wird links ausgerichtet statt zentriert |

### Was damit überholt ist

- Abschnitt 4 (Karte 4), Abschnitt 10 („Maße und Werte", „Der Move in einem
  Satz") und Abschnitt 7: Die weiße Pille mit `arrow.right` und die
  Bodenzeile „Ansehen →" gibt es nicht mehr. Die Bodenzeile trägt nur noch
  die Meta-Kapsel.
- Abschnitt 11, erste Zeile der Änderungstabelle: Reise-Karte und Fußnote
  wandern **nicht** in die Aktions-Gruppe. Dort steht das Tasten-Paar, die
  Fußnote darunter; die Karte bleibt im Inhalt.
- Abschnitt 4 und 10: Die Fußnote lautet im Plural „Die Beispieldaten sind
  als Demo markiert und lassen sich mit einem Tipp wieder entfernen" —
  `loadDemoData` legt drei Reisen und zwei Wunschreisen an, nicht nur die
  gezeigte Norwegen-Reise. Aus demselben Grund nennt die Meta-Kapsel
  „Norwegen · 9 Tage" statt sieben: `Cruise.duration` zählt Start- und
  Endtag mit, und genau diese Zahl zeigt die Detailansicht danach.
- Abschnitt 8: Das Motiv heißt im Produktivcode `cover_ship_aidanova` —
  der Originalname aus `ShipTrip/Assets.xcassets`, keine Kopie `hero_reise`.

Unverändert aus Abschnitt 11 gültig: das achromatische Etikett (`black`
bei 55 %), der dreistufige Scrim, die Seitenpunkte 28 pt über der
Primär-Aktion und die neutrale `systemGray`-Kontur der ungefüllten Aktion.

Drei Minor-Notes des Gates bleiben offen und sind als Nicht-Blocker
triagiert (`.planning/BACKLOG.md`): die Achse des Etiketts, seine Polarität
gegenüber der Bildunterschrift auf Karte 1 und das Größenverhältnis von
Foto-Karte zu Primär-Aktion.

**`prototype-onboarding/handover.md` beschreibt den Stand vor dieser
Runde** (In-Foto-Pille, Karte in der Aktions-Gruppe) und wird nicht
nachgezogen — der Prototyp wird nach der Abnahme gelöscht (Abschnitt 8).
Wahrheit für Karte 4 ist `ShipTrip/Views/Onboarding/`, beschrieben in
`../features/onboarding.md`.
