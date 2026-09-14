# Bild-Gate — Widget "Dynamic Instrument", Repair-Runde 1

Geladene Skills: keine (bewusst — nur Bilder).
Verdikt: **repair** (knapp — ein einziger Fehler blockiert)

## 1. Thumbnail-Test

- small-active: **pass** — Ring oben links, darunter fetter Ortsname als klarer
  zweiter Block; Countdown ohne Sekunden ordnet sich jetzt unter.
- medium-active: **pass** — Ring links, Geisterschiff rechts, Zeitleiste als Band:
  drei Blöcke, die Kachel wirkt als Instrument. Aber schon im Thumbnail sichtbar:
  "Kopenh…".
- medium-countdown: **pass** — Kreisfoto rechts trägt jetzt als Blickfang, "1 Woche"
  links dominant.

## 2. Treue-Urteil (Home-Screen, L)

| Bild | Urteil | Treue |
|---|---|---|
| widget-small-active-de-light-L | pass | ~92 % |
| widget-small-countdown-de-light-L | pass | ~90 % |
| widget-medium-active-de-light-L | **fail** | ~88 % |
| widget-medium-active-de-dark-L | **fail** | ~88 % |
| widget-medium-countdown-de-light-L | pass | ~93 % |

**small-active (~92 %)** — Kostet: (1) vier Textzeilen unter dem Ring gegen zwei im
Mockup; (2) Zeitspanne/Nächster-Stopp in identischem Grau — eine Graustufe
Differenz würde die Hierarchie schärfen.

**small-countdown (~90 %)** — Kostet: (1) die "1" ist weiß statt cyan (Mockup betont
die Zahl); (2) Leerband zwischen Reisetitel und "AIDAnova".

**medium-active (~88 %, light = dark)** — Ring groß, Geisterschiff da, Leerband weg,
Glyphen-Rest an der Unterkante weg: Layout sitzt. Kostet: (1) **"Kopenh…" — der
Hero-Ortsname bricht ab**, obwohl rechts daneben Platz ist; (2) der Kopfblock ist
links auf ~45 % Breite geklemmt, während der Datumsblock rechts auf drei Zeilen
läuft — unausgewogener als das Mockup.

**medium-countdown (~93 %)** — Kreisfoto, Script-Zeile, Logo, Claim, Cyan-"1" sitzen
sehr nah am 4×2-Mockup. Kostet: Reisetitel auf zwei Zeilen drückt den Datenblock
tiefer als im Mockup.

## 3. Reparaturpunkte aus Runde 0

1. Geisterschiff medium-active — **behoben**
2. Schiffsfoto im Kreis medium-countdown — **behoben** (echtes Foto, kein Umriss)
3. Leerraum / Ring größer medium-active — **behoben**
4. XXL "…" bei medium-active — **teilweise**: "Nächster Stopp" und Reisetitel laufen
   jetzt voll aus, dafür bricht der Ortsname "Puerto de la Cruz de Te…" ab
5. small-active Countdown kleiner, ohne Sekunden — **behoben**
6. Angeschnittener Glyphen-Rest Unterkante — **behoben**

## 4. Text-Abschneide-Prüfung (23 Bilder)

**…** widget-medium-active-de-light-L · widget-medium-active-de-dark-L ·
widget-medium-active-de-light-XXL (jeweils der Ortsname)

ok: alle übrigen 20 — small-active L/XXL/en, small-countdown L/XXL, small-idle,
small-unavailable, medium-countdown L/XXL, medium-idle, rectangular ×5, circular ×5.
Bemerkenswert: small-active-XXL setzt "Puerto de la Cruz de Tenerife" vollständig
zweizeilig — medium kann es also auch.

Kein Element läuft über die Kachelkante (der Runde-0-Rest ist weg).

## 5. Lock-Screen

- rectangular active L/XXL, countdown L/XXL, idle: **pass** — Hierarchie
  Titel/Zeit/Nebentext klar, Ring-Motiv mit Glyphe links, nichts abgeschnitten.
- circular active L/XXL: **pass** — Fortschrittsring + Glyphe + "17:00" lesbar.
- circular countdown/idle L/XXL: **grenzwertig pass** — lesbar, aber weiterhin nur
  ein statischer Ring ohne Fortschritt; das Motiv der Richtung fehlt hier.

## 6. Gesamtverdikt: repair

1. **medium-active: Ortsname darf nicht abbrechen** (L light+dark, XXL) —
   Kopfspalte breiter, Datumsblock rechts schmaler; zweizeilig erlauben wie bei small.
2. medium-active: Kopf-/Datumsspalte ausbalancieren (ca. 60/40 statt 45/55).
3. small-countdown: die Zahl "1" cyan setzen wie die "12" im Mockup.
4. circular countdown/idle: Fortschritts-/Ringmotiv ergänzen (kosmetisch, kein Blocker).

Die Richtung selbst trägt — kein reject. Punkt 1 ist der einzige echte Blocker.
