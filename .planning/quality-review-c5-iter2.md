# Review — C5 L10n-Gate (Re-Review nach Codex-No-Go-Fix)

- **Iteration**: 2 / 3
- **Reviewer**: quality-agent (frischer Spawn)
- **Datum**: 2026-08-24
- **Basis**: Worktree `/Users/andre-studio/Documents/0.Projekte/ShipTrip-worktrees/c5/`, Diff `c8bf384..ef8a518`
- **Verdikt**: approve (bedingt auf gruenen Verifikations-Build des parallelen Spawns)
- **Stats**: critical: 0, major: 0, minor: 5 — Blocker: 0, ins Backlog: 5

## Summary

Die zwei Codex-Majors (F1 Substitutions/Plural-Luecke, F2 `shouldTranslate:false`-Bypass)
und der F3-Sprachfund sind geschlossen. Alle Rot-Beweise wurden **eigenhaendig
reproduziert**, nicht aus dem Dev-Report uebernommen: r1/r2/r4/r5 laufen gegen den alten
Stand gruen (Exit 0 = Luecke unentdeckt) und gegen den neuen Stand rot (Exit 1), r3 bleibt
in beiden rot. Der echte Katalog ist mit dem neuen Skript gruen (Exit 0).

Fuenf eigene, vom Developer nicht getestete Angriffs-Faelle decken Rest-Luecken auf. Keine
davon erzeugt am **echten** Katalog ein falsches Gruen (nachgewiesen per Vollscan ueber
alle 396 Keys / 428 stringUnits) — deshalb alle non-blocking, alle ins Backlog.

## Reproduktion (eigenhaendig, Exit-Codes)

Skript-Identitaet zuerst verifiziert: `check-l10n-OLD.py` == `git show c8bf384:scripts/check-l10n.py`,
`check-l10n-NEW.py` == Worktree-Stand. Die Dev-Artefakte sind also der echte Code, keine Attrappe.

| Fall | alt (`c8bf384`) | neu (`ef8a518`) | Bewertung |
|------|-----------------|-----------------|-----------|
| `g1-sauber` | 0 | 0 | kein False-Positive |
| `r1-substitution-ohne-one` | **0** | **1** | F1 geschlossen |
| `r2-plural-ohne-one` | 0 | 1 | F1 geschlossen |
| `r3-plural-other-leer` | 1 | 1 | Regression ausgeschlossen |
| `r4-verschachtelte-substitution` | 0 | 1 | F1 geschlossen |
| `r5-shouldtranslate-bypass` | **0** | **1** | F2 geschlossen |
| `ShipTrip/Localizable.xcstrings` | — | **0** | Gruen-Gegenprobe |

Meldungen sind praezise pfadadressiert, z. B.
`[en/substitutions.haefen/plural.one] ohne Wert — '%lld Häfen besucht'` bzw.
`shouldTranslate=false ohne Allowlist-Eintrag — 'Reise wirklich löschen?'`.

## Pruefung der drei Codex-Findings

### F1 — substitutions/plural (resolved)
`missing_branches` (`scripts/check-l10n.py:70-104`) prueft `stringUnit`, `variations` und
`substitutions` **unabhaengig** (drei separate `if`, kein `elif`), setzt `checked` und meldet
einen Knoten ohne alle drei selbst als Luecke. `missing_variations:59-64` erzwingt `one`+`other`
nur fuer `kind == "plural"`. Rekursion laeuft ueber `substitutions` → `missing_branches` zurueck,
also unbegrenzt tief. Eigener Zusatzfall `q5-dreifach` (substitution → plural → substitution →
plural, Loch ganz unten) wird korrekt gefunden:
`[en/substitutions.a/plural.one/substitutions.b/plural.other]`. Keine neue Luecke in der
Rekursionslogik.

### F2 — shouldTranslate-Bypass (resolved)
`UNTRANSLATED_ALLOWLIST` (`:35-46`) enthaelt exakt 8 Keys. Vollscan des Katalogs: genau 8 Keys
tragen `shouldTranslate: false` — Allowlist und Ist-Zustand sind deckungsgleich, kein toter und
kein fehlender Eintrag. Alle 8 sind reine Format-/Interpolationsketten (`%@ %@`, `%lld`, `🌊` …),
kein nutzersichtbarer Satz. Verstoss-Meldung nennt Key und Grund. Ein zweiter Bypass-Pfad
existiert nicht: `continue` (`:118`) ist der einzige Skip neben `language == source` (`:121-122`),
und dieser ist durch die Allowlist bewacht.

### F3 — drei EN-Werte (resolved)
Genau drei Wert-Ersetzungen im Fix-Commit, jede am richtigen deutschen Key:

| DE-Key | EN neu | Verwendung |
|--------|--------|------------|
| `App kann nicht gestartet werden` | `Unable to Start App` | `ShipTripApp.swift:166` — `ContentUnavailableView`-Titel; Title-Case entspricht Apple-HIG |
| `Bilder und Notizen landen direkt beim richtigen Anlauf — mit Datum und Ort.` | `Photos and notes are saved with the correct port call — including date and location.` | `OnboardingCards.swift:70` |
| `Dein Gemini-API-Key ist separat in der Keychain gespeichert und bleibt sonst erhalten.` | `Your Gemini API key is stored separately in Keychain and will remain untouched.` | `SettingsView.swift:881` |

Der Fix-Commit beruehrt nur `ShipTrip/Localizable.xcstrings` (6 Zeilen = 3 Werte) und
`scripts/check-l10n.py`. **Keine** weiteren Katalog-Aenderungen, keine Schlepplast.

## Neue Findings (alle non-blocking → Backlog)

| ID | Severity | Blocker | Datei:Zeile | Kategorie | Titel |
|----|----------|---------|-------------|-----------|-------|
| N1 | minor | nein | `scripts/check-l10n.py:82-88` | correctness | Verwaiste Substitutions-Referenz unerkannt |
| N2 | minor | nein | `scripts/check-l10n.py:84-87` | correctness | `stringUnit.state` wird nicht geprueft |
| N3 | minor | nein | `scripts/check-l10n.py:59-64` | correctness | Nicht-Plural-Variations ohne Pflichtzweig |
| N4 | minor | nein | `scripts/check-l10n.py:113` | errors | Roher Traceback bei kaputtem Katalog |
| N5 | minor | nein | `scripts/check-l10n.py:1-158` | tests | Kein Regressionsnetz fuer das Gate-Skript |

### N1 — Verwaiste Substitutions-Referenz unerkannt
- **Problem**: Ein `en`-Wert `"Visited %1$#@haefen@"` ohne zugehoerigen `substitutions`-Block
  passiert das Gate (Exit 0). Zur Laufzeit zeigt die UI das rohe Token.
- **Warum kein Blocker**: Vollscan ueber alle 428 `stringUnit`-Werte findet **0** verwaiste
  `#@…@`-Referenzen. Aktuell kein falsches Gruen moeglich.
- **Fix (spaeter)**: Tokens per `re.findall(r"#@(\w+)@", value)` gegen `node["substitutions"]`
  gegenpruefen und Fehlende als Luecke melden.

### N2 — `stringUnit.state` wird nicht geprueft
- **Problem**: `{"state": "new", "value": "Reise löschen"}` (deutscher Quelltext in `en` kopiert)
  gilt als uebersetzt, Exit 0.
- **Warum kein Blocker**: Alle 428 Units im echten Katalog stehen auf `translated`.
- **Fix (spaeter)**: `state` gegen `{"translated"}` pruefen; `new`/`needs_review` als Luecke melden.

### N3 — Nicht-Plural-Variations ohne Pflichtzweig
- **Problem**: `variations.device` ohne `other`-Zweig passiert das Gate — kein Fallback zur Laufzeit.
- **Warum kein Blocker**: Der Katalog enthaelt **0** Nicht-Plural-Variations.
- **Fix (spaeter)**: Fuer `kind != "plural"` einen `other`-Zweig verlangen.

### N4 — Roher Traceback bei kaputtem Katalog
- **Problem**: Ein Nicht-Dict-Entry unter `strings` laesst `entry.get(...)` mit
  `AttributeError` durchschlagen; der Nutzer sieht einen Stacktrace statt einer Fehlermeldung.
  Verstoesst gegen `python-standards` §4 („ein roher Traceback beim Nutzer ist ein Bug").
- **Warum kein Blocker**: faellt **geschlossen** (Exit 1), erzeugt also nie ein falsches Gruen;
  der Katalog enthaelt keine solchen Entries.
- **Fix (spaeter)**: `isinstance(entry, dict)` guard, sonst Finding
  `"{catalog}: Eintrag ist kein Objekt — {key!r}"`.

### N5 — Kein Regressionsnetz fuer das Gate-Skript
- **Problem**: Die sechs Fixtures liegen nur im Scratchpad und sind nach der Session weg. Die
  naechste Aenderung am Checker hat keinen Rot-Beweis-Halt.
- **Warum kein Blocker**: Das Verhalten ist hier manuell und vollstaendig verifiziert; das Projekt
  hat keinerlei Python-Testinfrastruktur (kein `pyproject.toml`, kein `.venv`, kein pytest), und
  die dafuer aufzubauen waere fuer 158 Zeilen Gate-Skript ueberdimensioniert („Simplicity First").
- **Fix (spaeter, nur wenn der Checker weiter waechst)**: Fixtures nach `scripts/testdata/l10n/`
  legen und im CI-Job als Selbsttest mitlaufen lassen.

## Kein Finding (bewusst)

- `guard.py sizes` meldet `ShipTrip/Localizable.xcstrings: 4448 Zeilen (> 500 hart)`. Das ist eine
  von Xcode generierte JSON-Datendatei, kein Quellcode — das Limit zielt auf Module, nicht auf
  Kataloge. Ausserdem vorbestehend und nicht durch diesen Change verursacht. Kein Finding.
- `scripts/check-l10n.py` = 158 Zeilen, deutlich unter dem 400/500-Limit. Typannotationen
  vollstaendig, moderne Syntax (`list[str]`, `from __future__ import annotations`), keine
  Import-Side-Effects, `main()` + `__main__`-Guard, Diagnostik auf stderr, Ergebniszeile auf
  stdout — konform zu `python-standards`.

## Gate-Verdrahtung

`.github/workflows/ci.yml:22-34` — eigener `l10n`-Job auf `ubuntu-24.04`, laeuft parallel zum
teuren macOS-Job, ruft `python3 scripts/check-l10n.py` unter `set -euo pipefail` ohne Argumente
auf (rglob ueber alle `*.xcstrings`). Kein Weichspueler-Kommando, kein `|| true`. Eigenhaendig
gegengeprueft: argumentloser Lauf im Worktree → Exit 0.

## Status der Vorgaenger-Findings (Codex Gate #2)

- F1 substitutions/plural-Luecke: **resolved**
- F2 `shouldTranslate:false`-Bypass: **resolved**
- F3 drei unidiomatische EN-Werte: **resolved**

## Test-Run-Status

- Python-Verifikation des Gate-Skripts: **11 Laeufe, alle mit erwartetem Exit-Code** (6 Dev-Fixtures
  gegen alt und neu, 6 eigene Angriffs-Faelle, 2 Laeufe gegen den echten Katalog).
- Swift-Build/Unit-Tests: **hier bewusst nicht gefahren** — laeuft als paralleler eigener Spawn
  (Build-Token). Das Go steht unter diesem Vorbehalt.

## Verdikt

**Go — bedingt.** Keine offenen Blocker aus diesem Review. Merge freigegeben, sobald der parallele
Verifikations-Spawn einen gruenen `xcodebuild`-Lauf mit Evidenz-Artefakt meldet. Faellt der rot
aus, ist dieses Go hinfaellig.
