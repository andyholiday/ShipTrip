# Journal-Kern 1.8.5 — Kurz-Narrativ und Richtungs-Block

Stand 2026-08-27, Welle T5 (Design, schlanke Ein-Richtungs-Variante).
Bindender Feld- und Flow-Vertrag: `docs/architecture/contracts/journal-editor-contract.md`
(J1–J5). Bestehender Look: `.planning/karten-redesign-v2-tokens.json` und
`.planning/karten-politur-c-tokens.json`.

## Kurz-Narrativ

**Persona.** Andrea, 54, sitzt am dritten Seetag mit dem iPhone auf dem
Balkon und will festhalten, wie der Morgen war — bevor die Tage
ineinanderlaufen und sie zu Hause nicht mehr weiß, ob die Wolkenbank an Tag 3
oder Tag 5 war.

**Kern-Moment.** Der Tagebuch-Strang in der Reise-Detailansicht: die Reise als
lesbare Folge von Tagen. Das ist der Bildschirm, wegen dem die App später
noch geöffnet wird, wenn die Reise vorbei ist.

**Härtefall.** Tag 3, der Seetag: drei Einträge an einem Tag, einer davon lang
und mit drei bebilderten Fotos, einer nur Text, dazu kein Hafen. Das
Layout-Problem: drei gleichwertige Einträge dürfen nicht in drei gleichwertige
Kacheln zerfallen, sonst verliert der Tag seine Klammer — und der Strang
seinen Rhythmus.

**Emotionaler Zielwert.** Wiedererkennen. Drei Sekunden nach dem Öffnen soll
klar sein: das ist meine Reise, chronologisch, und ich finde den Tag, den ich
suche, ohne zu lesen.

**Anti-Gefühl.** Nie wie ein Formular. Kein Feld darf vor der Erinnerung
stehen; das Erfassen darf sich nie anfühlen wie eine Spesenabrechnung.

**Content-Temperatur.** Text-lastig mit Bild-Einsprengseln — der Fließtext
trägt, Fotos akzentuieren.

**Screens im Scope (T5).**

- `journal` — Tagebuch-Strang in `CruiseDetailView` (Kern-Moment, drei
  Scroll-Positionen als eigene Registry-Einträge, weil die Reise nicht auf
  einen Screen passt).
- `editor` — Eintrag-Editor, zwei Schritte, feste Reihenfolge nach J2.

**Einstieg.** Reise-Detailansicht → Abschnitt „Tagebuch" → Stift-Symbol rechts
in der Abschnittszeile. Der Weg zurück ist der System-Zurück-Pfeil bzw.
„Abbrechen" im Editor.

## Richtungs-Block — „Logbuch"

**Ein-Satz-Versprechen.** Die Reise liest sich als eine durchgehende
Logbuch-Seite, auf der jeder Tag seine eigene große Ziffer bekommt.

**Welt.** Warmes Papier (`journalSurface` #FBF7F0 / #15212E) statt einer
Kachelwand: eine einzige Fläche mit einer gepunkteten Zeitachse links, die
durch alle sieben Tage läuft. Die Pin-Farben der App (`homePortPin`,
`portPin`, `seaDayPin`, `endPortPin`) bleiben die einzigen Akzente und sagen
weiterhin, was für ein Tag das war.

**Der eine mutige Move — die Tagesziffer.** Jeder Reisetag trägt seine Nummer
als 46-pt-Ziffer in der linken Rinne, ultraleicht, gerundet, in der Pin-Farbe
des Tages, mit der Zeitachse darunter. In ShipTrip gibt es heute außerhalb des
Hero-Titels nichts über 28 pt — die Ziffer ist damit sichtbar
nicht-konform und leistet genau das, woran der Härtefall sonst scheitert: Tag
3 bleibt ein Block mit einer Klammer, auch wenn drei Einträge darunterhängen.
An einem leeren Tag steht dieselbe Ziffer blass da; die Lücke ist sichtbar,
ohne dass eine leere Karte dafür gebaut werden muss.

**Bewegung (nicht fotografiert, live in Stufe 4 zu beurteilen).**
Stagger / Cascade · *List Entrance Cascade*
(`design-library/references/systems/motion-benchmarks.md`): die Tagesblöcke
laufen einmal von oben nach unten ein, `easeOut` 0.24 s, Versatz 0.06 s,
gedeckelt bei 8 Blöcken.

**Was es ist.** Ein chronologischer Tagebuch-Strang auf einer Papierfläche,
mit einer Logbuch-Rinne links und dem Editor als Zwei-Schritt-Scroll-Flow,
in dem die Erinnerung oben und groß steht und die Eckdaten darunter als
vorbelegte Zeilen.

**Was es bringt.** Ein dichter Tag bleibt lesbar, weil die Ziffer und die
Zeitachse ihn zusammenhalten; leere Tage fallen auf, ohne zu stören; die
Rangfolge „Erinnerung zuerst" ist im Editor gebaut und nicht nur behauptet.

**Was es kostet.** Die Papierfläche ist eine zweite Flächenfarbe neben dem
grauen Karten-Idiom der übrigen Detail-Abschnitte — der Tagebuch-Abschnitt
sieht bewusst anders aus als „Route" und „Ausgaben". Der lange Eintrag an Tag
3 wird ungekürzt gezeigt, kein „Weiterlesen"; der Strang wird dadurch lang.
Die Stimmung erscheint als Farbpunkt mit Wort statt als Emoji, was leiser ist
als der Vorschlag in J4.

## Abweichungen vom Vertrag, bewusst und benannt

- **J4 Emoji.** Der Contract schlägt Emoji vor und stellt die Darstellung
  ausdrücklich frei. Diese Richtung nutzt stattdessen einen Farbpunkt der
  Stimmungs-Rampe plus das deutsche Wort. Grund: Emoji als Icon ist im
  Design-Prozess dieses Projekts ausgeschlossen, und die fünf Rohwerte
  (`great` … `awful`) bleiben unverändert.
- **J2 „Weiter".** Statt zweier Screens ein Scroll-Flow mit zwei sichtbaren
  Schritten; der Contract stellt das frei. Es gibt darum keinen
  „Weiter"-Knopf — die Freigabe-Regel (Text nicht leer **oder** ≥ 1 Foto)
  hängt am „Sichern" oben rechts.

## Neue Token (der einzige Zuwachs zum bestehenden Set)

| Token | Wert hell | Wert dunkel | Wofür |
|---|---|---|---|
| `moodNeutral` | `rgba(26,54,93,0.45)` | `rgba(255,255,255,0.42)` | Stimmung `okay` und `keine` |
| `moodAwful` | `#D63131` | `#D63131` | Stimmung `awful`, dunkler als System-Rot |

Alles Übrige — Pin-Farben, `journalSurface`, `journalTimeline`, `DesignRadius`
sm/md/lg — ist unverändert aus dem bestehenden Set übernommen.
