# Plan — Reisedauer in Nächten (Run 2026-09-11) · Tier: Medium · Fassung 2 (nach Gate #1)

Maßstab: `.planning/ZIEL.md`. Basis: Worktree `../ShipTrip-worktrees/reisedauer`,
Branch `feature/reisedauer-naechte` ab `feature/share-extension`.

## Tasks (DAG)

| Task | Agent · Modell | needs | Scope (Schreibpfade) | Erfüllt Kriterium |
|---|---|---|---|---|
| T1 Modell + Kopplungs-Reducer + Tests | developer · opus | — | `ShipTrip/Models/Cruise.swift` (nur `nights`), neu `ShipTrip/Utilities/CruiseDateTriad.swift`, neu `ShipTripTests/CruiseDateTriadTests.swift`, `ShipTripTests/CalendarSyncPlannerTests.swift` (+1 Test) | K1 (inkl. Backfill-Logik), K2 (Regeln + Rot-Beweis), K3 (Verschiebung, Dialog-B-Regel), K4 |
| T2 Formular-UI + Dialogkette + Strings | developer · opus | T1-Commit | `ShipTrip/Views/Cruises/CruiseFormView.swift`, String Catalog | K2 (UI), K3 (Dialog A→B, Ruhephase), K5, K1 (Backfill-Aufruf im Load) |
| T3 Runtime-Prüfung + Review + Upgrade-Smoke | quality · fable (`FINAL-GATE`) | T2-Commit | read-only; Evidenz `.winston-evidence/` | K6, Go-Live-Triage |
| T4 Doku | knowledge · opus | T3-Go | `CHANGELOG.md`, `docs/features/reisedauer.md`, ggf. CLAUDE.md | K7 (Kern prüft Winston, Gate #6) |
| T5 Geräteabnahme | Andre | TestFlight-Build | — | K8 (bewusst offen; Rückkanal: nächster Chat) |

Serielle Kanten: T1→T2 — T2 kompiliert gegen T1 und beide leben im selben Worktree/Target; ein
zweiter Worktree plus Merge kostet mehr als T1 dauert (Gate-#1-Vorschlag „parallel" bewusst
verworfen). T2→T3 — Prüfung braucht den fertigen Diff. T3→T4 — Knowledge startet per Prozess nach
Quality-Go; die Doku prüft Winston selbst als Gate-#6-Kern (Gate-#1-Vorschlag „T4 vor T3"
verworfen: T3 ist das Code-Gate, Gate #6 das Doku-Gate).

## Contract T1 → T2 (eingefroren; Namen darf T1 präzisieren, Semantik nicht)

```swift
/// Reiner Wert + Reducer, keine SwiftData-Abhängigkeit, Kalender injizierbar. Invariante: nights == Kalendertage(start, end) ≥ 0.
struct CruiseDateTriad: Equatable {
    var start: Date; var end: Date; var nights: Int

    /// Backfill: storedNights == 0 && end > start → nights berechnet; sonst Invariante aus start/end erzwingen.
    init(start: Date, end: Date, storedNights: Int, calendar: Calendar)

    enum StartShiftChoice { case keepNights /* Ende wandert */, keepEnd /* Nächte neu */ }
    enum NightsChoice     { case moveStart, moveEnd }

    func changingStart(to: Date, choice: StartShiftChoice, calendar: Calendar) -> CruiseDateTriad
    func changingEnd(to: Date, calendar: Calendar) -> CruiseDateTriad          // Nächte folgen, keine Rückfrage
    func changingNights(to: Int, choice: NightsChoice, calendar: Calendar) -> CruiseDateTriad

    /// Kalendertage zwischen zwei Startdaten (signed) — das N der Dialoge.
    static func dayShift(from: Date, to: Date, calendar: Calendar) -> Int
    /// Dialog B nur bei Route ≠ leer ∧ N ≠ 0.
    static func needsRouteShiftPrompt(routeIsEmpty: Bool, dayShift: Int) -> Bool
    /// Für Port.arrival/departure (Häfen und Seetage).
    static func shifted(_ date: Date, byDays: Int, calendar: Calendar) -> Date
}
```
`Cruise.nights: Int = 0` (persistiert, additiv). Beim Speichern: `cruise.nights = triad.nights`.

## Dialogkette in T2 (Präsentationsvertrag)
- Phasen-State `enum DatePromptPhase { idle, dialogA(newStart), dialogB(shift) }`, ein einziger
  `confirmationDialog` pro Phase; nach Dismiss von A ohne Wahl (Abbrechen) → Startdatum zurück auf
  Baseline, Phase idle. Nach Wahl in A → Triad anwenden, dann `needsRouteShiftPrompt` → B oder idle.
- Ruhephase: cancellable `Task.sleep(0.5 s)` im `onChange(of: startDate)`; N = `dayShift(baseline →
  aktueller Wert)`; Baseline = zuletzt bestätigter Start (nach Antwort in A neu gesetzt).
- Programmatische Setzungen unterdrücken den Dialog: Load beim Bearbeiten und KI-Import setzen
  Baseline mit (Flag `isProgrammaticDateChange`).
- Nächte-Zeile: `Stepper` mit Zahl (≥ 0); Änderung → Dialog „Startdatum anpassen / Enddatum
  anpassen / Abbrechen" (Abbrechen = Nächte zurück).

## Prüfung (T3)
- Tiefe Prüfung = Quality (Runtime nötig), Fable per `.planning/FINAL-GATE`; kein Codex-#2 auf
  denselben Diff (kein Security-/GDPR-Scope). Codex-Jobs bisher: Gate #1 (1 von 3).
- T3 zusätzlich: **Upgrade-Smoke** — Build der Basis (`feature/share-extension`) im Wegwerf-Sim
  installieren, Reise mit Häfen anlegen, dann Feature-Build darüber installieren; Reise öffnen,
  bearbeiten, speichern (Backfill + Lightweight-Migration). CloudKit-Container-Rollout: offene
  Evidenz, nicht im Sim prüfbar → Run-Bericht.
- Simulator-Beobachtung: Rad-Picker scrollen → genau ein Dialog A; leere Route → kein Dialog B.
- Gate #4/ADR: nicht ausgelöst (additives Attribut mit Default, Produktentscheidung Andres).

## Kompass-Checkpoints
- nach Zerlegen · vor Return.

## Kernmetriken (am Ende ausfüllen)
Diff-Größe · Test-Diff vs. Code-Diff · Spawns/Tokens · was parallel lief.
