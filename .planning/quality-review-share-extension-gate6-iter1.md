# Review - Share-Extension, Knowledge Gate #6 (Doku-Gate, read-only)

- **Iteration**: 1 / 3
- **Reviewer**: quality-agent
- **Date**: 2026-09-10
- **Verdict**: request-changes (ein Doku-Blocker, Wortlaut-Fix)
- **Stats**: critical: 0, major: 1, minor: 4 — blockers: 1, backlogged: 4
- **Geladene Skills**: code-review, markdown-standards, changelog
- **Scope**: `git diff f8b44ec..b5c6115` im Worktree `ShipTrip-worktrees/widget-1.9.0`
  (Branch `feature/share-extension`). Kein Build/Test (Auftrag: Token beim E2E-Spawn);
  Test-Stand laut Vorspann 59/59 grün (`.winston-evidence/20260910T145442Z/gate-run.json`).

## Summary

Doku ist bis auf eine Stelle konsistent mit dem Code. CLAUDE.md, CHANGELOG, ADR-010
(inkl. A1/A2 und Contract H3), SETUP/Fastfile stimmen mit dem Diff überein. Blocker: die
Feature-Doku führt ZIEL-Kriterien 1 und 2 als „Erfüllt", obwohl der Sheet-Nachweis
(Screenshot) und der Laufzeit-Nachweis der Extension noch beim laufenden E2E liegen — das
widerspricht dem Prüfauftrag („kein erfüllt, wo nur strukturell geprüft").

## Pflicht-Kern

| Nr. | Prüfpunkt | Ergebnis | Beleg |
|---|---|---|---|
| 1 | CLAUDE.md nennt neue Targets, nichts Falsches | pass | `CLAUDE.md:108-113`; UIKit ohne Storyboard: `ShipTripShare/Info.plist:9-10`; kein SwiftData: `ShareViewController.swift:12-14`; Foundation-only + membershipExceptions: `project.pbxproj:71-73` |
| 2 | CHANGELOG `[Unreleased]`, Keep-a-Changelog, Nutzersprache | pass | `CHANGELOG.md:17-24` (Kategorie „Hinzugefügt", ein Bullet, kein Bezeichner-Dump, relativer Link) |
| 3 | ADR-010 konsistent mit Diff, Accepted, A1/A2, H3 | pass | s. u. Stichproben |
| 4 | Feature-Doku Acceptance-Status je Kriterium 1–9 | **fail** | `docs/features/kreuzfahrt-teilen.md:98-99` — Kriterium 1 und 2 „Erfüllt" (nur strukturell); 7 korrekt nicht erfüllt (`:104`), 8 offen (`:105`); Limitation „Keine Share-Extension" entfernt, neue Limitations `:145-156` korrekt |
| 5 | SETUP/Fastfile: Share-Profil, `PROFILE_ShipTripShare`, ExportOptions-Hinweis | pass (mit Finding F02) | `docs/SETUP.md:183-184,187-189`; `fastlane/Fastfile:322-331`; gitignore-Hinweis fehlt |
| 6 | markdown-standards: Zeilenlänge, Heading-Hierarchie | pass mit minor | Hierarchie in allen Dateien sauber; Tabellenzeilen > 100 Zeichen (F03) |

### Stichproben zu Prüfpunkt 3 (ADR ↔ Code)

- Status Accepted: `ADR-010:3`, `docs/adr/README.md:18`.
- Vordergrund-Scan an genau drei Stellen: `ShipTripApp.swift:326` (`.onDisappear` am
  Sheet-Inhalt, A1), `:359-365` (`scenePhase == .active`), `:375-380` (`.task`).
- A2 (kein Scan im Wegwerf-Store): `ShipTripApp.swift:246` `guard !usingTemporaryStore`.
- Kein URL-Parameter, kein Router-Case: `IncomingLinkRouter.swift` nicht im Diff
  (`git diff --stat`), `handleIncomingURL` unverändert (`ShareImportCoordinator.swift:43`).
- Mitteilung nur bei `.authorized`, `trigger: nil`, Identifier `share.handoff`:
  `ShareViewController.swift:171,178-182`.
- Löschregel Präfix ShareInbox mit Test-Naht: `ShareImportCoordinator.swift:77-92`.
- Aktivierungsprädikat (kein TRUEPREDICATE, kein MaxCount): `ShipTripShare/Info.plist:14-22`.
- Atomar `.tmp` → `moveItem`, Größenlimit, 24-h-Regel: `ShareViewController.swift:44,50,59-60`;
  `ShareHandoffStore.swift:34,108-126`.
- `ShareArchiveLimits` im Share-Target (ADR `:114`): `project.pbxproj:73`.
- A1/A2 im ADR `:179-187`; Contract `share-extension-handoff.md:14-16,138-152`.

## Findings

| ID | Severity | Blocker | File:Line | Category | Title |
|---|---|---|---|---|---|
| F01 | major | yes | docs/features/kreuzfahrt-teilen.md:98-99 | docs | Kriterien 1 und 2 als „Erfüllt", nur strukturell geprüft |
| F02 | minor | no | docs/SETUP.md:187 | docs | `build/ExportOptions.plist` ist gitignored — kein Hinweis |
| F03 | minor | no | ADR-010:1,166-174; adr/README.md:18; contract (Tabellen) | markdown | Zeilen > 100 Zeichen in Tabellen/H1 |
| F04 | minor | no | CHANGELOG.md:19; kreuzfahrt-teilen.md:22 | docs | „aus iMessage" behauptet, Geräte-Nachweis (#8) offen |
| F05 | minor | no | docs/features/kreuzfahrt-teilen.md:4 | docs | „seit 1.9.0" — 1.9.0 ist bereits released (2026-09-07), Eintrag steht unter Unreleased |

### F01 - Kriterien 1 und 2 als „Erfüllt"
- **Problem**: ZIEL #1 verlangt „Simulator-Screenshot als Beweis" für „ShipTrip" im
  Teilen-Sheet; ZIEL #2 die sichtbare Meldung „An ShipTrip übergeben". Beides ist bislang
  nur strukturell belegt (Plist, Display-Name, Code); der E2E-Lauf, der den Sheet-Tap prüft,
  läuft noch (Iteration 1 partial). Die Fußnote `:108-115` beschreibt nur Struktur.
- **Fix** (Wortlaut): Zeile 98 Status → `Strukturell erfüllt — Sheet-Nachweis (Screenshot) mit #7`;
  Zeile 99 Status → `Strukturell erfüllt — Laufzeit-Nachweis mit #7`. Nach grünem E2E beide
  auf „Erfüllt" heben, zusammen mit #7.

### F02 - ExportOptions.plist nicht versioniert
- **Problem**: `build/` ist gitignored (`.gitignore:11`), die Datei existiert nur lokal;
  SETUP tut so, als läge sie im Repo. Frischer Klon → Export scheitert.
- **Fix**: Nach `docs/SETUP.md:189` Satz ergänzen: „`build/ExportOptions.plist` ist nicht
  versioniert (`build/` steht in `.gitignore`) und muss auf einem frischen Klon mit
  `method app-store-connect`, `signingStyle manual`, `teamID LH324Y9MG7` und den drei
  Profil-Zuordnungen neu angelegt werden." Blockt Gate #6 nicht, aber Release-Reproduzierbarkeit.

### F03 - Zeilen > 100 Zeichen
- ADR-010 H1 (101), Iteration-2-Tabelle 103–212 Zeichen; `adr/README.md:18` (129);
  Contract-Tabellen bis 1023 Zeichen (`:301`); `kreuzfahrt-teilen.md:161` (105).
  Entspricht bestehender Repo-Praxis (ADR-009-Zeile ebenfalls > 100). Backlog.

### F04 / F05 - Formulierungen
- F04: iMessage-Weg ist laut ADR `:120-123` nur am Gerät verifizierbar. Unter
  `[Unreleased]` tolerierbar, muss vor dem Release-Cut durch #8 gedeckt sein.
- F05: „seit 1.9.0" ist vertretbar, weil kein Bump über 1.9.0 (ZIEL, Nicht-Scope), aber
  zusammen mit dem Unreleased-Eintrag missverständlich; „ab Build 31" wäre präziser.

## Backlog-Einträge (nicht blockend)

- [minor] docs/SETUP.md:187 — Hinweis, dass `build/ExportOptions.plist` gitignored ist
- [minor] docs/adr/ADR-010:1,166-174 + contract Tabellen — Zeilenlänge > 100
- [minor] CHANGELOG.md:19 — „aus iMessage" erst nach Geräte-Abnahme #8 belegt
- [minor] docs/features/kreuzfahrt-teilen.md:4 — „seit 1.9.0" vs. Unreleased

## Verdict

**No-Go für Gate #6** wegen F01 (Doku-Wortlaut, zwei Zellen). Nach dem Fix: Go.
