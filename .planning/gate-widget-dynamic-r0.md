# Bild-Gate — Widget "Dynamic Instrument", Repair-Runde 0

Geladene Skills: keine (bewusst — nur Bilder).
Verdikt: **repair**

## 1. Thumbnail-Test

- small-active: Ring links oben als Block erkennbar, aber die untere Hälfte ist ein
  Textklotz aus 4 Zeilen — Hierarchie „Ring / Ortsname" verschwimmt. **grenzwertig**
- medium-active: Ring winzig, rechte Hälfte leer, Zeitleiste als Streifen erkennbar.
  Der Block „Instrument" trägt nicht. **fail**
- medium-countdown: großer Kreis rechts klar erkennbar, aber **leer** (nur Kontur);
  die große Zahl „1" ist als Zahl kaum dominant. **grenzwertig**

## 2. Treue-Urteil (Home-Screen, L)

| Bild | Urteil | Treue |
|---|---|---|
| widget-small-active-de-light-L | pass | ~88 % |
| widget-small-countdown-de-light-L | pass | ~90 % |
| widget-medium-active-de-light-L | fail | ~78 % |
| widget-medium-countdown-de-light-L | fail | ~78 % |
| widget-medium-active-de-dark-L | fail | ~78 % |

**small-active (~88 %)** — Farbwelt, Ring mit Schiffsglyphe, weißer Ortsname sitzen.
Kostet Prozent: (1) vier Textzeilen unter dem Ring drücken den Ring optisch klein,
Mockup hat zwei; (2) „Noch 2:34:43" mit Sekunden ist fast so groß wie „Kopenhagen"
und bricht die Hierarchie (Mockup: „Noch 3:25 h", deutlich kleiner).

**small-countdown (~90 %)** — sehr nah am Mockup. Kostet: der Reisetitel bricht auf
zwei Zeilen und schiebt Schiff/Datum nach unten; die „1" ist weiß statt cyan-betont
und damit weniger Signal als die „12" im Mockup.

**medium-active (~78 %, light und dark identisch)** — Ring, Zeitleiste, Farben, Typo
stimmen. Kostet: (1) **Geister-Schiffssilhouette rechts fehlt komplett** — dadurch
(2) ein leeres Band von ~40 % Kachelhöhe zwischen Kopfzeile und Zeitleiste, die
Kachel wirkt halb befüllt statt „Instrument"; (3) Ring deutlich kleiner als im
Mockup und ohne optische Verbindung zur Zeitleiste.

**medium-countdown (~78 %)** — Layout, Script-Zeile, Logo, Claim sitzen erstaunlich
genau. Kostet: (1) **der Kreis rechts ist leer** — kein Schiffsfoto, nur eine dünne
cyanfarbene Kontur, damit fehlt das Hero-Element des Mockups; (2) die Kontur ist
haarfein statt als Foto-Maske gesetzt; (3) „1" cyan / „Woche" weiß ist ok, wirkt
aber gegen den leeren Kreis nicht als Blickfang.

## 3. Text-Abschneide-Prüfung (23 Bilder)

ok: small-active-de-L · small-active-de-XXL · small-active-en-L ·
small-countdown-de-L · small-countdown-de-XXL · small-idle-de-L ·
small-unavailable-de-L · medium-active-de-light-L · medium-active-de-dark-L ·
medium-countdown-de-L · medium-countdown-de-XXL · medium-idle-de-L ·
rectangular-active-L · rectangular-active-XXL · rectangular-countdown-L ·
rectangular-countdown-XXL · rectangular-idle-L · circular-active-L ·
circular-active-XXL · circular-countdown-L · circular-countdown-XXL ·
circular-idle-L

**…** widget-medium-active-de-light-XXL — zwei Abbrüche: „Nächster Stopp: Santa
Cruz de la Palma, 14. Se…" (oben rechts) und „Mittelmeer-Traumreise…" (unten
rechts).

Zusatzbeobachtung (kein Abschneide-Befund im engeren Sinn): medium-active L
light **und** dark zeigen am unteren Kachelrand einen angeschnittenen
Glyphen-Rest mittig — ein Element ragt unter die Kachelkante.

## 4. Lock-Screen

- rectangular (alle 5): **pass** — Hierarchie Titel/Zeiten/Nebentext klar, Ring-Motiv
  mit Glyphe links vorhanden, monochrom gut lesbar, nichts abgeschnitten.
- circular active (L/XXL): **pass** — Ring als Fortschritt sichtbar, Glyphe + „17:00"
  lesbar.
- circular countdown/idle: **grenzwertig pass** — Lesbarkeit ok, aber **kein Ring**;
  das Ring-Motiv der Richtung fehlt hier ganz.

## 5. Gesamtverdikt: repair

Reparaturliste (priorisiert):

1. medium-active: Geister-Schiffssilhouette rechts ergänzen — sie füllt das leere
   Band und ist das Markenzeichen der Mockup-Kachel 2×1.
2. medium-countdown: Schiffsfoto in den Kreis legen (Foto-Maske statt leerer
   Kontur) — ohne Bild fehlt das Hero-Element der 4×2-Kachel.
3. medium-active: vertikalen Leerraum zwischen Kopfblock und Zeitleiste auflösen,
   Ring größer ziehen, damit die Kachel gefüllt wirkt.
4. medium-active XXL: „Nächster Stopp"-Zeile und Reisetitel dürfen nicht mit „…"
   abbrechen — kürzen oder Zeile bei XXL weglassen (Text hat Vorrang).
5. small-active: Countdown ohne Sekunden und eine Stufe kleiner setzen, damit
   „Kopenhagen" die dominante Zeile bleibt.
6. medium-active: den angeschnittenen Glyphen-Rest an der Unterkante entfernen.
