# Handover — Logbuch (journal)

Status: ready_for_test_build

Prototype:  /Users/andre-studio/Documents/0.Projekte/ShipTrip/prototype-journal
Bundle ID:  com.proto.journal.protoJournal
Scheme:     ProtoJournal
Device:     iPhone 17 Pro (402 x 874 pt)
Modes:      light + dark

Registry (stimmt mit proto.json "screens" exakt überein):

```text
journal          Tagebuch-Strang, Kopf (Tag 1-3), Standbild
journal.tag3     Härtefall: Seetag mit drei Einträgen, Standbild
journal.tag5     Tag 4-6 inkl. Empty-Zustand Tag 5, Standbild
journal.motion   optional, für die Live-Demo — der Strang spielt die Kaskade
                 einmal von selbst und kommt zur Ruhe. Sein Standbild ist ein
                 Vor-Bewegungs-Nebenprodukt; nicht daraus urteilen.
editor           Schritt 1 „Erinnerung" vollständig, Kopf von Schritt 2
editor.scrolled  Schritt 2 „Eckdaten" vollständig
```

`journal.tag3`, `journal.tag5` und `editor.scrolled` scrollen beim Erscheinen
per `ScrollViewReader` an einen festen Anker (150 ms nach dem ersten Frame).
Das ist deterministisch, braucht aber eine Settle-Zeit über 150 ms — der
Default reicht.

Motion:            Stagger / Cascade · List Entrance Cascade
                   (design-library/references/systems/motion-benchmarks.md)
                   easeOut 0.24 s, Versatz 0.06 s, Deckel 8 Blöcke.
                   Nur `journal.motion` animiert; alle anderen Einträge stehen
                   ab dem ersten Frame.

Assets:
  copied:          Resources/Assets.xcassets — 10 Imagesets, alle aus echten
                   Repo-Fotos abgeleitet (Ausschnitte aus
                   ShipTrip/Assets.xcassets/demo_port_barcelona,
                   demo_port_palma, demo_port_cozumel, demo_port_geiranger):
                   foto_ablegen, foto_kathedrale, foto_marina, foto_deck,
                   foto_horizont, foto_wasser, foto_bucht, foto_morgenlicht,
                   foto_promenade, foto_altstadt.
  animated:        none
  Lücke:           Das Repo hat kein Foto von offener See und keines von
                   Cannes/Neapel/Civitavecchia. Die Seetag- und Cannes-Bilder
                   sind mediterrane bzw. Wasser-Ausschnitte der vorhandenen
                   Demo-Fotos.

Pitch deviation:   entfällt — schlanke Ein-Richtungs-Variante ohne Wave P.

Repair-Runde 0 (nach visuellem Gate #5) — was sich am Shoot ändert:

- Die drei `journal*`-Screens laufen jetzt in echter App-Chrome
  (`ProtoAppChrome`: die fünf Tabs aus `ShipTrip/Views/MainTabView.swift`,
  Reisen aktiv, plus Zurück-Chevron in der Navigationsleiste). Der sichtbare
  Ausschnitt ist dadurch rund 49 pt kürzer — die Scroll-Anker sitzen
  unverändert, der Bildausschnitt verschiebt sich aber gegenüber Runde 0.
- `editor` und `editor.scrolled` bleiben ohne Tab-Leiste: der Editor ist ein
  modales Blatt.
- Kommando, Registry, Anker-Logik und Settle-Zeit sind unverändert.

Repair-Runde 2 (nach visuellem Gate Runde 1) — nur `journal*`, der Editor ist
unberührt:

- Foto-Reihe (`ProtoPhotoStrip`): feste Kachelgröße 108 × 81 pt, Abstand 6 pt,
  die Reihe an der Inhaltsspalte beschnitten. Ursache der Runde-1-Regression
  war die flexible Kachelbreite: über einem `aspectRatio(.fill)`-Bild meldet
  sie als Mindestbreite die Eigenbreite des Fotos auf Kachelhöhe — in der
  Dreier-Reihe gemessen 93 / 121 / 78 pt. Deren Summe sprengte die Spalte, und
  weil ein VStack seine Kinder mit der eigenen (gewachsenen) Breite platziert,
  brach danach auch der Fließtext erst am Rand der Papierseite um.
- Damit hält Tag 3 wieder denselben rechten Inset wie `journal`/`tag5`
  (Inhaltsspalte endet bei 373 pt = 29 pt vom Displayrand), und die Kürzung des
  langen Eintrags endet mit echter Ellipse in der Spalte.
- Drei Fotos passen bei fester Kachelgröße nicht mehr nebeneinander: die dritte
  Kachel schaut mit rund 57 von 108 pt am Spaltenrand hervor. Der Schnitt liegt
  an der Spalte, nicht am Display.
- Seetag-Badge (`ProtoDayBadge`): `water.waves` bringt keinen gefüllten Kreis
  mit und stand als nackte Glyphe neben drei Pin-Badges. Der Seetag bekommt
  jetzt denselben 15-pt-Kreis in `seaDayPin`, Glyphe als Aussparung — die
  Hafen-Symbole selbst sind unverändert.
- Neue Token in `Proto.Layout`: `photoTile` (108, vorher Kachelhöhe 70),
  `photoTileHeight` (81), `photoGap` (6), `dayBadge` (15).
- Registry, Anker-Logik, Settle-Zeit, Signatur (Tagesziffer + gepunktete
  Zeitachse), Motion und Shoot-Kommando sind unverändert.

Repair-Runde 3 (nach visuellem Gate Runde 2) — mit Render-Rückkopplung: gefixt,
gebaut, aufgenommen, die eigenen Aufnahmen angesehen, nachgebessert.

- **Gemeinsame Ursache der beiden Kanten-Befunde:** die Foto-Reihe. Drei feste
  Kacheln à 108 pt + 12 pt Fugen = 336 pt melden sich als *Mindestbreite* nach
  oben; die Inhaltsspalte hat aber nur 282 pt. Der ScrollView hat den 456 pt
  breiten Inhalt zentriert — die Papierseite lief randlos, „Tagebuch" war links
  angeschnitten, das Stift-Symbol rechts bündig abgesägt, und die Zeilen
  darunter standen bei 61 statt 88 pt. Kachel jetzt 88 × 66 pt: 3 × 88 + 12 =
  276 pt, alle drei Fotos ganz in der Spalte. Gemessen an der Aufnahme: die
  Papierseite steht auf allen sieben `journal*`-Bildern exakt bei 16,0 … 385,7
  pt, also 16 pt Rand auf beiden Seiten.
- Zweite, kleinere Überbreite derselben Art in der Empty-Zeile von Tag 5
  (`fixedSize()` auf beiden Texten, 286 pt) — beim Nachmessen der ersten
  Reparatur-Aufnahme aufgefallen, sonst wäre der Rand 12,7 statt 16 pt
  geblieben. `fixedSize()` steht jetzt nur noch auf „Nachtragen", Innenrand
  10 pt, Fugen 7 pt.
- Abschnittskopf ohne Extra-Rand: „Tagebuch" steht auf der linken Kante der
  Papierseite, das Stift-Symbol schließt rechts bündig mit ihr ab.
- Kürzung langer Einträge passiert jetzt im Payload an der Wortgrenze
  (`ProtoEntry.collapsedText`, Budget 250 Zeichen) statt in SwiftUIs `.tail` —
  aus „außer zu schauen, w…" wird „… Fläche türkis da …". `lineLimit(8)` bleibt
  als Deckel, greift aber nicht mehr.
- Der Editor bestellt die Abdeckung der Navigationsleiste ausdrücklich
  (`toolbarBackground(.visible / Material.bar)`); als modales Blatt bekam er
  den Scroll-Rand-Effekt nicht von selbst, deshalb stand Runde 2 „Sichern" auf
  „Vormittag".
- Signatur (Tagesziffer + gepunktete Zeitachse), Registry, Anker-Logik,
  Settle-Zeit, Motion und Shoot-Kommando sind unverändert.
- Aufnahmen dieser Runde: `docs/design/directions/shots/logbuch-r3/`.

Vorprüfung, die hier gelaufen ist (kein Build, kein Simulator):
  xcodegen generate                      -> ProtoJournal.xcodeproj, Exit 0
  xcodebuild -list -project ...          -> Scheme "ProtoJournal" vorhanden
  swiftc -typecheck -sdk iphonesimulator -target arm64-apple-ios18.0-simulator
         Sources/*.swift                 -> Exit 0, keine Diagnose
Ein echter `xcodebuild`-Lauf hat nie stattgefunden; der erste Build ist der
des Shoot-Agents.

Run exactly this, from the project root
(/Users/andre-studio/Documents/0.Projekte/ShipTrip):

```bash
python3 ~/.claude/skills/design-phase/scripts/shoot.py \
        --project /Users/andre-studio/Documents/0.Projekte/ShipTrip/prototype-journal \
        --all --mode both \
        --out /Users/andre-studio/Documents/0.Projekte/ShipTrip/docs/design/directions/shots/journal
```

Falls `xcodegen` neu laufen muss (nur wenn die .xcodeproj fehlt):

```bash
cd /Users/andre-studio/Documents/0.Projekte/ShipTrip/prototype-journal && xcodegen generate
```

Hand back: Exit-Code jedes Kommandos, die `shoot-report.json` dieser Richtung
(jeder Lauf steht in ihrem `runs`-Array — nicht umbenennen, zwischen den
Kommandos nicht löschen) und die Liste der erzeugten Dateien.
