# Plan — Widget-Politur (Medium, Design-Runde) · 2026-09-12, Neuschnitt 2026-09-13

Basis feature/reisedauer-naechte @5968854. Prototyp = Widget-Target selbst.
Stand 2026-09-13: Andre verwirft die drei Richtungen (T1–T6 erledigt, Ergebnis abgelehnt) und
wählt Konzept 03 „Dynamic Instrument" aus seinem eigenen Mockup. Neuschnitt ab hier:

| Task | needs | parallel |
|---|---|---|
| U1 Codex-Imagegen: Hero (Kreisfoto) + Ghost (Silhouette) → docs/design/assets/ | Konzept-Ausschnitt | parallel zu U2 |
| U2 Designer (opus): Konzept 03 auf alle 4 Familien × 4 Zustände, Branch design/widget-dynamic-instrument, Worktree ../widget-dynamic, compile-only | Konzept-Ausschnitt | parallel zu U1 |
| U3 Winston: Bilder auf ≤600 px skalieren, in Imagesets legen, commit | U1, U2 | – |
| U4 Shoot: WidgetScreenshotUITests im Wegwerf-Sim → docs/design/directions/shots/dynamic/ | U3 (ein Sim, ein Build-Token) | 1 |
| U5 Bild-Gate: frischer Spawn, nur Bilder, Vergleich gegen Konzept-Ausschnitt, Treue ≥95 % + XXL-Text | U4 | 1 |
| U6 Reparatur (frischer Designer) → U4/U5 erneut, max 1 Runde | U5 fail | ≤1 |
| U7 Andre sieht Kontaktbogen; danach Quality (Opus): 23 PNG-Sichtung, berührte Suite, gate-run.json | U5 pass | 1 |
| U8 Knowledge: CHANGELOG, widget.md „Gestaltung" | U7 | parallel zum Abschluss |

Serielle Kanten: U4 nach U3 (Sim/Build-Token), U5 nach U4 (Bilder), U7 nach U5. Keine weiteren.
