# TASKPLAN 1.8.5 — Journal-Kern (Wave D-Abschluss) · v4

Stand 2026-08-27 · **v4 nach Andre-Entscheid: Tagebuch-Verankerung in der
Route** (separater Tagebuch-Strang + Logbuch-Design VERWORFEN) ·
Ziel: `.planning/ZIEL.md` · Tier: **Big** → Gates #1 ✓ /#3/#4 ✓ + eine
tiefe Prüfung pro Diff + Quality nach jeder Dev-Wave + Knowledge incremental.

## Andre-Entscheid 2026-08-27 (Re-Anchoring, bindend)

Journal-Einträge erscheinen **im bestehenden Route-Abschnitt** der
`CruiseDetailView` — ein Tagesfaden statt zwei paralleler Tages-Listen:

- Aktive Reise: Route eingeklappt, nur der aktuelle Tag offen
  (Wechsel 0:00 lokale Gerätezeit). Nach Reiseende und vor Reisebeginn:
  komplett aufgeklappt. Manuelles Auf-/Zuklappen + „alles aufklappen"
  jederzeit, übersteuert die Automatik.
- Erfassung am Stopp/Tag (wo Fotos + Ausflüge hängen): „Tagebuch-Eintrag"
  dazu; Editor bleibt exakt J2/J2a („Erinnerung zuerst"), vorbelegt aus dem
  angetippten Stopp.
- Lange Einträge: Auszug in der Karte + „Weiterlesen".
- UNVERÄNDERT: J1-Modell (T7 ✓), Export/Teilen (T7b ✓), J4-Stimmung,
  Demo-Filter.
- Spec-Naht: **J3neu** in `docs/architecture/contracts/
  journal-editor-contract.md` + ADR-003-Nachtrag (Architect-Spawn,
  Session 8) — T8 baut ausschließlich dagegen.
- Design: **keine neue Designphase** (Andre). T8 baut im bestehenden
  Route-/Karten-Idiom (Karten-Redesign-Tokens, PortPinView-Rollen).
  Elemente der verworfenen Logbuch-Richtung (Tagesziffer, Zeitachse,
  Papierfläche) sind optionaler Fundus, keine Pflicht.

## Pre-Run-Gate (unverändert bestätigt)

Einzel-Agents (Agent-Teams-Env nicht gesetzt) · Codex `medium` ·
Branch **`release/1.8.5`** · Devs in eigenen Worktrees unter
`../ShipTrip-worktrees/`, committen dort, pushen nie · Merges seriell durch
Winston · Build-Token-Ledger (Test-Builds strikt seriell, Wegwerf-Sim im
Default-Set, `simctl privacy grant calendar`) · Nie `xcodebuild test
-scheme` → build-for-testing + test-without-building · Kein TestFlight/Push
ohne Andres Zuruf.

**String-Katalog-Eigentümer Welle 3 = T8** (alle Journal-Strings, deutsche
Wortlaut-Keys, DE/EN).

**Modell-Zuteilung (Fable-Direktive, hart):** Fable nur Orchestrierung /
Planung / finale Q-Gates; alle Dev-, Knowledge-, Test-Build- und
Routine-Review-Spawns `model: opus`; Reviews Codex (Budget s. u.).

## Task-DAG (Stand + Rest)

| ID | Task | Agent/Modell | needs | Status |
|----|------|--------------|-------|--------|
| T1–T4 | ADR-003/004, D1 Ländercodes, D2 FormView-Split | — | — | ✓ gemerged (d8ce9bb) |
| T5/T6 | Logbuch-Design + Gate #5 | — | — | **GESCHLOSSEN/VERWORFEN** (Gate r3: reject; Andre-Entscheid Re-Anchoring macht den Strang obsolet; Artefakte bleiben als Fundus unter `docs/design/directions/` + `prototype-journal/`) |
| T7 | Journal-Modell + Migration | — | — | ✓ gemerged (465/465) |
| T7b | Export/Teilen (ZIP + .shiptrip) | — | — | ✓ gemerged `ab93a0e` (Quality-GO runtime-verifiziert, 474 Tests; 4 Minor im Backlog) |
| **T13** | Architect: J3neu (Route-Integration inkl. Klapp-Zustandsmaschine, Zuordnungs-Randfälle) + ADR-003-Nachtrag | architect / fable | Andre-Entscheid ✓ | ✓ committet `ebfba99` + Fix-Nachzug (Opus-Verifikation: GO) |
| **T8** | Dev UI-Wave (neu geschnitten, Happen s. u.): (a) Route-Abschnitt: Klapp-Logik + Journal-Zeilen in den Stopp-Karten + Sammelblock + „Weiterlesen"-Detail; (b) Eintrag-Editor nach J2/J2a (Erinnerung → Eckdaten, Foto+Caption), Einstieg aus Stopp-Karte vorbelegt; (c) Lokalisierung DE/EN; (d) UI-/Integrationstests für anlegen/öffnen/bearbeiten/löschen + Klapp-Automatik (aktiv/vorbei/manuell) | developer / opus | T13 ✓, T4 ✓, T7 ✓, T7b ✓ | offen (Session 8) |
| T9 | Tiefe Prüfung je T8-Diff: Quality bevorzugt (Codex-Budget), Codex #2 nur bei Bedarf | quality / opus | T8-Diff | offen |
| T10 | Knowledge incremental | knowledge / opus | Quality-Go | teilweise ✓ (D1/D2/D4/T7 + journal.md: 681c818/1debe19; nach T8: journal.md auf Route-Verankerung umschreiben) |
| T11a | Integrations-Wave: voller Build + komplette Suite + Regression Statistiken/Export/Teilen (Journal-Roundtrip beide Formate) | Test-Build / opus | T8 gemerged | offen |
| T11b | Migrationstest auf Andres echtem Gerät (1.8.0 → 1.8.5; deckt CloudKit-Store — Fixture war `cloudKitDatabase: .none`) | Andre + Test-Build | T11a grün | offen |
| T12 | Final: Codex Gate #3 (scope-weise, nach T11b) · Gate #6 · Version-Bump 1.8.5 + CHANGELOG · TestFlight auf Zuruf | — | T11b | offen |

## Bindende T8-Auflagen (kumuliert)

1. **Lösch-Pfade NUR über `JournalDeletePaths`** (Codex-Finding E) —
   J2a-Bumps explizit.
2. **Editor-Contract J1/J2/J2a bindend** (Feld-Namen, Reihenfolge
   „Erinnerung zuerst", LWW-Matrix).
3. **J3neu bindend** (Zuordnung, Klapp-Zustandsmaschine — Architect-Spec).
4. Abnahme-Checkliste aus Gate-r3-Fehlerklassen (gelten sinngemäß im
   nativen Bau): kein Content unter Nav-/Tab-Leiste ohne Systemmaterial ·
   keine Wort-Grenzen-Brüche/Clipping · EINE Flächenfamilie pro Screen ·
   ein Tint für führende Listen-Icons · Foto-Thumbnails ohne
   Kopf-Beschnitt (Aspect-Regel) · Placeholder-Kontrast prüfen.
5. Neue Strings als `String(localized:)`, deutsche Wortlaut-Keys.

## Parallelisierung (Rest-Run) — T8-Happen (Architect-Schnitt)

- **T8a** Klapp-/Zuordnungslogik als reine testbare Structs (Phase,
  Defaults, Eintrag→Stopp, Weiterlesen-Trigger) + Unit-Tests ·
  **T8b** Stopp-Karten-UI (Collapse-Darstellung, Eintragszeilen,
  Sammelblock) gegen T8a · **T8c** Eintrags-Detailansicht +
  Editor-Vorbelegung/Einstiegspunkte · **T8d** L10n/A11y-Pass + UI-Tests +
  journal.md-Update. Reihenfolge: T8a zuerst, dann T8b ∥ T8c, T8d seriell;
  Test-Build-Phasen strikt seriell.
- Compile-Smoke im Dev-Spawn erlauben, wenn Build-Token frei
  (Lesson Session 6).
- T11a/b/12 echte Reihenfolge-Gates.

## Gate-Plan (Rest)

- Gate #1 ✓ (v1/v2) · Gate #4 ✓ (ADR-003-Kern; der **Nachtrag** ist
  UI-Verankerung ohne Modell-Änderung → Verifikation durch frischen
  Opus-Prüfer statt Codex-Re-Gate, Präzedenz ADR-003-Fixes).
- T9 je T8-Diff: **Quality** (Codex-Budget schonen).
- Gate #3 (Codex, final, scope-weise) nach T11b · Gate #6 vor Return.
- **Codex-Budget Big: 4/6 verbraucht** (#1 v1+v2, #4, #2-T7) · Reserve:
  #3 final + 1 Joker.

## Offene Punkte außerhalb des Runs

- Key-Rotation (DRINGEND, Andre: „später") · CloudKit Dev→Prod ·
  C6 Video-Altlasten · App-Store-Einreichung 1.8.0 gebündelt mit 1.8.5 ·
  Länderlabels: OS-Namen von Andre bestätigt (2026-08-27, kein Veto).
