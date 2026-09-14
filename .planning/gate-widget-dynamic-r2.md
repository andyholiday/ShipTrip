# Bild-Gate — Widget "Dynamic Instrument", Repair-Runde 2

Geladene Skills: keine (bewusst — nur Bilder).
Verdikt: **repair** (knapp — 2 Punkte, davon 1 echter Blocker)

## 1. Treue-Urteil (Home-Screen, L)

| Bild | Urteil | Treue |
|---|---|---|
| widget-small-active-de-light-L | pass | ~93 % |
| widget-small-countdown-de-light-L | pass | ~93 % |
| widget-medium-active-de-light-L | pass | ~93 % |
| widget-medium-active-de-dark-L | pass | ~93 % |
| widget-medium-countdown-de-light-L | pass | ~95 % |

**small-active (~93 %)** — Ring oben links, Zeit cyan oben rechts, fetter Ortsname
als zweiter Block, Countdown cyan darunter. Kostet: vier Textzeilen unter dem Ring
(erlaubt); Zeitspanne und "Nächster Stopp" in identischem Grau — eine Graustufe
Differenz würde die Hierarchie noch schärfen (kosmetisch).

**small-countdown (~93 %)** — Kalender-Glyphe links, Segler rechts, "Noch / 1 Woche",
cyan Reisetitel, Wellen-Trenner, Schiff, Datum. Leerband aus R1 ist weg. Weiße "1"
ist laut Vorlagen-Freigabe korrekt (1×1-Mockup setzt "12 Tage" ebenfalls weiß).

**medium-active (~93 %, light = dark)** — Blocker aus R1 behoben: "Kopenhagen" läuft
voll aus. Spaltenverhältnis jetzt ca. 60/40, Kopfblock atmet. Ring groß links,
Geisterschiff rechts, Zeitleiste als Band mit 8:00 / 15:05 / 17:00, cyan Reststand
unten links. Kostet: der rechte Kopfblock (Datum + "Nächster Stopp") läuft auf drei
Zeilen und drückt optisch gegen das Geisterschiff — im Mockup steht dort nur eine
Datumszeile plus Wetter.

**medium-countdown (~95 %)** — Kreisfoto mit Cyan-Rand, Script-Zeile, ShipTrip-Logo,
Sperrschrift-Claim, cyan "1", Symbolzeilen Schiff/Kalender: das nächste am 4×2-Mockup.

## 2. Reparaturpunkte aus Runde 1

1. medium-active Ortsname bricht ab (L light+dark, XXL) — **behoben** (alle drei)
2. Spaltenverhältnis Kopf/Datum ausbalancieren — **behoben** (ca. 60/40)
3. small-countdown Leerband / Zahlfarbe — **behoben** (Leerband weg; weiße Zahl ist
   vorlagenkonform, der R1-Punkt war ein Fehlurteil)
4. circular countdown/idle Ringmotiv — **teilweise**: countdown hat jetzt echten
   Fortschrittsbogen + "12"; idle bleibt ein voller statischer Ring (bei "keine
   Reise" vertretbar)

## 3. Text-Abschneide-Prüfung (23 Bilder)

**…** widget-medium-active-de-light-XXL — Datum rechts oben: "13. September 20…",
das Jahr fehlt.

ok: alle übrigen 22.

**Über die Kachelkante:** kein Text. Aber in **allen fünf rectangular-Bildern** ist
der Ring/Kreis links an der Kachelkante flach gekappt statt als geschlossener Bogen
gesetzt — sieht nach Clipping aus, nicht nach Absicht.

## 4. Lock-Screen

- rectangular active L/XXL, countdown L/XXL, idle: **pass mit Auflage** — Hierarchie
  Titel/Zeit/Nebentext sauber, kein Text abgeschnitten, XXL setzt "Puerto de la Cruz
  de Tenerife" und den langen Folgestopp voll. Auflage: linker Ring-Anschnitt (s. o.).
- circular active L/XXL: **pass** — Fortschrittsring, Schiffsglyphe, "17:00" lesbar.
- circular countdown L/XXL: **pass** — Fortschrittsbogen + Segler + "12".
- circular idle L: **pass** — Ring + Schirm-Glyphe, ohne Fortschritt (kein Datum da).

## 5. Nebenbeobachtungen (kein Gate-Kriterium)

- widget-small-active-en-light-L: "Still 1 hr, 53 min" — "Still" ist ein
  DE→EN-Übersetzungsschnitzer (gemeint: "1 hr 53 min left"). Backlog.
- widget-medium-countdown-de-light-XXL und -idle-L: großes Leerband in der unteren
  Kachelhälfte. Kosmetisch, XXL-Größe.

## 6. Gesamtverdikt: repair (2 Punkte)

1. **medium-active XXL: Datum bricht ab** ("13. September 20…") — kurzes Format bei
   XXL ("13.09.26") oder Jahr weglassen. Einziger echter Blocker.
2. rectangular (alle 5): linken Ring-Anschnitt beheben — Ring-Frame kleiner oder
   führendes Padding.

Die Richtung trägt vollständig; alle Home-Screen-L liegen über 90 %. Beide Punkte
sind Ein-Zeilen-Fixes, keine Layout-Umbauten.
