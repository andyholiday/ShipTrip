# ZIEL — Widget-Politur: Home- und Sperrbildschirm-Widgets sehen professionell aus (Run 2026-09-12)

**Ziel (1 Satz):** Die vier Widget-Familien (systemSmall, systemMedium, accessoryRectangular,
accessoryCircular) bekommen eine gewählte visuelle Richtung mit erkennbarer Hierarchie, statt
flachem Text auf Papier — ohne dass Inhalt, Wortlaut oder Datenweg sich ändern.

**Original-Anfrage (Andre, wörtlich, 2026-09-12):** „Winston, ich habe den neuen build geprüft
und auch die widgets. kannst du die widgets optisch noch ein wenig aufbereiten und aufpolieren,
dass sie professioneller aussehen?"

**Marktlösung:** entfällt — eigene WidgetKit-Views; Maßstab sind System- und Reise-Widgets
(Benchmark in Stufe 1), kein Fertigprodukt einsetzbar.

**Basis:** Branch `feature/reisedauer-naechte` @ `5968854` (1.9.0-Linie, Build 32 auf TestFlight,
Worktree `../ShipTrip-worktrees/reisedauer`). Richtungen auf `design/widget-<slug>` in eigenen
Worktrees; die gewählte Richtung wird auf `feature/widget-politur` ausgebaut.

**Kriterien (messbar):**

1. **Drei Richtungen, gebaut statt gemalt:** je Richtung ein eigener Branch, in dem
   `systemMedium` (Zustand aktiv) und `systemSmall` (aktiv, Dynamic Type XXL, lange Namen) in
   der Richtung umgesetzt sind; `xcodebuild build -scheme ShipTrip` grün; Screenshots stammen
   aus der Debug-Galerie (`WidgetScreenshotUITests`), nie aus Skizzen.
   Prüfbar per: Build-Exit-Code + PNGs unter `docs/design/directions/shots/<slug>/`.
2. **Bild-Gate bestanden:** ein frischer Spawn, der nur Bilder sieht, vergibt `pass` für jede
   Richtung auf dem Auswahlbogen und `spread: pass` über das Set. Prüfbar per Gate-Report.
3. **Ein Auswahlbogen, eine Entscheidung:** `docs/design/auswahl-widget.html` zeigt je Richtung
   Medium (Light + Dark) und Small XXL auf identischem Inhalt (`PreviewFixtures`); Andre wählt
   genau einmal. Prüfbar per Datei + Andres Antwort.
4. **Ausbau ohne Textverlust:** die gewählte Richtung ist auf alle vier Familien und alle vier
   Zustände übertragen; die 23 Galerie-Screenshots sind neu erzeugt. Der Prüfer sichtet jedes
   PNG und listet es mit ok/„…"; Schwellwert: 0 Bilder mit abgeschnittenem Pflichttext
   (Stoppname, Zeiten, „Nächster Stopp", Countdown, Schiff) bei L und XXL. Prüfbar per
   dieser Liste im Quality-Report.
5. **Inhalt und Datenweg unverändert:** kein Pflichtinhalt entfernt (Titel, aktueller Stopp +
   Zeiten, nächster Stopp, Countdown, Schiff, Datum), `accessibilityLabel` unverändert,
   `WidgetShared/`, Provider und Snapshot unberührt; Änderungen nur unter `ShipTripWidget/`
   (Galerie-Rahmen nur, wenn die Richtung ihn braucht). Prüfbar per `git diff --stat`.
6. **Verifiziert:** berührte Suite (`WidgetScreenshotUITests` + Widget-Unit-Tests) grün mit
   `gate-run.json` Exit 0; Test-Diff ≤ Code-Diff.
7. **Doku:** CHANGELOG unter [Unreleased]; `docs/features/widget.md` bekommt einen Abschnitt
   „Gestaltung" mit den Token-Werten der gewählten Richtung (keine separate Design-Spec).
   Prüfbar per Existenz der Einträge.
8. Andre bestätigt am Gerät im nächsten TestFlight-Build. (Bewusst offen; blockiert den
   Run-Abschluss nicht — wie bei den Vorläufer-Runs.)

**Annahmen (Ziel-Verifikation 2026-09-12):** Basis ist die 1.9.0-Linie, weil Build 32 der
zuletzt hochgeladene Build ist — widerspricht Andre, wird die Basis gewechselt. Drei
Richtungen statt einer sind bewusst gewählt: Andre entscheidet erfahrungsgemäß lieber am
Vergleich (Karten-Redesign, Onboarding) als an einem Einzelentwurf; die Mehrkosten sind
parallele Tokens, keine Wartezeit. Kein Pitch-Wave (Skizzen kosten hier so viel wie der Bau).

**Nicht im Scope:** neue Widget-Inhalte oder -Familien · Konfigurations-Intent · Deep-Link ·
Änderungen am Snapshot-Schema · App-UI.

---

## Richtungswechsel (Andre, 2026-09-13)

**Original-Anfrage (wörtlich):** „winston. ich schaue mir gerade die widget mookups von dir an
und sie gefallen mir nicht, kannst du zu 95% das die dritte variante auf diesen vorschlägen
nachbauen? wenn du bilder brauchst, soll codex die mit imagegen image2.5 nachbauen. codex kann das"

**Entscheidung:** Kriterien 1–3 (drei Richtungen, Bild-Gate über das Set, Auswahlbogen) sind
durch Andres eigene Wahl ersetzt. Gebaut wird **Konzept 03 „Dynamic Instrument"** aus
`docs/design/mookup_widgets.png` (Ausschnitt: `docs/design/assets/konzept-03-dynamic-instrument.png`)
auf Branch `design/widget-dynamic-instrument` (Basis `5968854`).

**Neue Kriterien 1–3:**

1. **Treue ≥ 95 %:** ein frischer Bild-Prüfer legt die Galerie-Shots neben den Ausschnitt und
   vergibt pro Familie/Zustand `pass`, wenn Layout, Farbwelt (Navy-Grund, Cyan-Akzent),
   Ring-Instrument, Zeitleiste und Typo-Hierarchie dem Konzept entsprechen; abweichen darf nur,
   was WidgetKit nicht kann oder wofür es keine Daten gibt (Wetter). Prüfbar per Gate-Report.
2. **Bilder aus Codex-Imagegen:** Schiffsfotos (Kreis-Hero, Ghost-Silhouette) liegen unter
   `docs/design/assets/` mit `manifest.md`, eingebettet im Widget-Asset-Katalog. Prüfbar per Dateien.
3. **Dark-Only-Look in beiden Erscheinungsbildern:** Home-Screen-Familien zeigen den Navy-Grund
   auch im Light-Mode (Konzept ist dunkel); Lock-Screen-Familien bleiben systemgerendert.
   Prüfbar per Light- und Dark-Shots.

Kriterien 4–8 gelten unverändert.

**Status:** abgeschlossen 2026-09-13 — Branch `feature/widget-politur` @ 3c3a355 (Worktree
`../ShipTrip-worktrees/widget-dynamic`); Gate r2 `.planning/gate-widget-dynamic-r2.md`, Quality
`.planning/quality-review-widget-dynamic-iter1.md`, Evidenz
`../ShipTrip-worktrees/widget-dynamic/.winston-evidence/20260913T141535Z/gate-run.json`. K8 (Gerät) offen.
