# Gate-Notizen — Onboarding „App-Kontinuität" (Stand 2026-08-24, abgeschlossen)

**Ergebnis: PASS.** Andre genehmigte am 2026-08-24 eine letzte, eng geführte
Fix-Runde (Option a). Frischer Designer setzte exakt die vier Fixes um
(Button-Paar in Karte-3-Behandlung, Karte ~28pt unter die Copy, ganze Karte
als Tap-Fläche ohne In-Foto-Pille, alles auf der 20pt-Achse); frischer
Prüfer, Repair round 1: **pass**. Kriterium 8 answered — erinnerter Satz
(„liest sich als ausgefüllter Reise-Datensatz statt szenischem Header")
deckt den deklarierten Signatur-Move. Drei Minor-Notes (Chip-Achse,
Chip-Polarität, Foto-Dominanz vs. Primary) sind als Nicht-Blocker in
`.planning/BACKLOG.md` triagiert. Alte Karte-4-Shots: `shots/archive-round1/`.

---

Historie der visuellen Gates (Prüfer: je frischer, fremder Spawn, nur Bilder):

1. **Runde 1 (Erstbau): repair** — „Später"-Kontrast 2,60:1, Signatur unbeantwortet,
   3 Konsistenz-Findings. → Repair-Runde.
2. **Re-Gate (Runde 1): reject** — Signatur-Move überdreht (102pt-Button-Label >
   Headline, Hierarchie gekippt). → Neuableitung Karte 4.
3. **Gate Neuableitung (Runde 0): repair** — Signatur „answered" (Mini-Reise-Karte
   als zweite Option, load-bearing); Findings: Karte übertönt CTA, Dots stranden,
   Pille auf heller Bildstelle, Overlay auf Personen, „Später"-Kontur-Familie.
   → Repair-Runde (Karte+Fußnote in Aktions-Gruppe, Orange raus, Motivtausch,
   Dots 28pt über Primär-Aktion, Kontur systemGray).
4. **Re-Gate (Runde 1, 2026-08-24): reject** — Findings unten. Karten 1–3 und
   die Kontinuität bestehen durchgehend; „Später" (Soft-Ask) in ALLEN Runden
   ausdrücklich sauber. Das Problem ist ausschließlich die Ausführung von Karte 4.

## Findings des letzten Re-Gates (reject, mechanisch fixbar)

1. **[Hierarchie]** Drei Blöcke konkurrieren, der lauteste ist die SEKUNDÄR-Option
   (Sunset-Karte 362×224pt, saturiert, eigene weiße Pille) vs. blaue CTA-Bar 66pt,
   130pt tiefer. Die zwei Optionen lesen nicht als Paar — Karte 3 zeigt im selben
   Flow, wie ein Paar aussieht (zwei gestapelte Controls, identische Kanten).
   **Fix:** beide Optionen als gestapeltes Paar unter der Karte in identischer
   Breite (gefüllt „Erste Reise anlegen" über outlined „Beispielreise ansehen",
   Karte-3-Behandlung); die In-Foto-„Ansehen"-Pille streichen — die Karte wird
   Illustration der zweiten Option, nicht konkurrierender Primary.
2. **[Spacing]** 202pt-Void ZWISCHEN Intro-Satz und der Karte, die er ankündigt
   (alle anderen Gaps 6–29pt) — Proximität sagt „gehört zu nichts". Karten 1/3
   legen ihre Leere NACH dem Inhalt ab. **Fix:** Karte ~32pt unter die Copy,
   Überschuss nach unten über die Dots.
3. **[Signatur, partly answered]** Der Move (zweiter Weg = echte Reise-Karte) ist
   load-bearing, aber in den Pixeln nicht als OPTION lesbar (Folge von 1+2).
   **Fix:** kein zweiter Move — die ganze Karte wird Tap-Fläche, die Wahl steht
   auf der Karte selbst, hochgezogen an die Copy.
4. **[Alignment]** Text-Block auf 27pt-Achse, Karte/CTA auf 20pt — zwei Achsen.
   **Fix:** alles auf die 20pt-Achse.

## Entscheidung (liegt bei Andre)

Design-Iterationen sind aufgebraucht (Erstbau + Repair + Neuableitung + Repair).
Optionen:
- **(a) Eine letzte, eng geführte Fix-Runde** exakt nach den vier Fixes oben —
  Winstons Empfehlung: Die Findings sind mechanisch (Layout, keine Konzeptfrage),
  Richtung + Signatur-Konzept sind bestätigt; Risiko gering.
- **(b) Andre sichtet die Shots selbst** (`shots/karte-4--light.png` u. a.) und
  übersteuert das Gate oder wählt Anpassungen.
- **(c) B2 mit Karten 1–3 starten** und Karte 4 konservativ (zwei gestapelte
  Buttons ohne Karte) bauen; die Karten-Idee ins Backlog.
