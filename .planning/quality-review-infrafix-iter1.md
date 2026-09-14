# Review — Gate-#3-Scope-B-Fixes (infrafix)

- **Iteration**: 1 / 3
- **Reviewer**: quality-agent (frischer Spawn)
- **Datum**: 2026-08-24
- **Scope**: `08cc088..964cbb3` im Worktree
  `/Users/andre-studio/Documents/0.Projekte/ShipTrip-worktrees/infrafix/`
  — genau 2 Dateien: `scripts/check-l10n.py`, `.github/workflows/ci.yml`
- **Verdikt**: approve (Go)
- **Stats**: critical: 0, major: 0, minor: 1 neu — Blocker: 0, ins Backlog: 1

## Summary

Beide Codex-Findings aus Gate #3 Scope B sind fail-closed geschlossen und selbst
reproduziert — nicht nur gelesen. F1 (`strings` fehlt → Gate lief grün durch) ist
über eine echte Struktur-Validierung (`load_catalog` + `CatalogError`) geschlossen,
die zusätzlich kaputtes JSON, Nicht-Objekt-Root, leere `sourceLanguage` und nicht
lesbare Dateien als Fund meldet — jeweils Exit 1 **ohne Traceback**. F2 (Xcode-Pin
warnte nur) failt jetzt in beiden Richtungen: fehlendes `$XCODE_APP` **und**
Versions-Mismatch beenden den Step mit Exit 1. Die C5-Fix-Logik
(Substitutions/Plural/Allowlist) ist unangetastet: alle fünf Rotfälle bleiben rot,
der Sauberfall bleibt grün. Kein neuer Bypass im Diff, keine weiteren
Workflow-Änderungen.

## Reproduktionen (alle selbst gefahren, Kopien im Scratchpad)

### check-l10n.py — Struktur-Fail-Closed (F1)

| Fall | Kommando | Exit | Ausgabe |
|------|----------|------|---------|
| echter Katalog | `python3 scripts/check-l10n.py ShipTrip/Localizable.xcstrings` | **0** | `L10n-Gate ok: 1 Katalog(e) vollständig für en.` |
| CI-Kommando 1:1 (Repo-Root, ohne Args) | `set -euo pipefail; python3 scripts/check-l10n.py` | **0** | `L10n-Gate ok: 1 Katalog(e)…` |
| Kopie **ohne** `strings` | `… b-no-strings.xcstrings` | **1** | `unbrauchbarer Katalog — 'strings' fehlt oder ist kein Objekt` |
| `strings` als Liste | `… b2-strings-list.xcstrings` | **1** | dito |
| kaputtes JSON | `… c-broken.json.xcstrings` | **1** | `nicht lesbar oder kein gültiges JSON — Expecting property name…` (kein Traceback) |
| Root ist Array | `… c2-array.xcstrings` | **1** | `kein JSON-Objekt auf oberster Ebene` |
| `sourceLanguage` leer | `… c3-src-leer.xcstrings` | **1** | `'sourceLanguage' fehlt oder ist leer` |
| Datei existiert nicht | `… gibtsnicht.xcstrings` | **1** | `nicht lesbar… [Errno 2]` (kein Traceback) |
| kein Katalog im Baum | leeres Verzeichnis, ohne Args | **1** | `L10n-Gate: kein String Catalog gefunden.` |
| sauber + kaputt gemischt | zwei Pfade als Args | **1** | ein kaputter Katalog reisst den Lauf mit |

### check-l10n.py — C5-Regressionsnetz gegen den NEUEN Stand

| Fixture | Exit | Meldung (gekürzt) |
|---------|------|-------------------|
| `g1-sauber` | **0** | Gate ok |
| `r1-substitution-ohne-one` | **1** | `[en/substitutions.haefen/plural.one] ohne Wert` |
| `r2-plural-ohne-one` | **1** | `[en/plural.one] ohne Wert` |
| `r3-plural-other-leer` | **1** | `[en/plural.other] ohne Wert` |
| `r4-verschachtelte-substitution` | **1** | `[en/plural.other/substitutions.haefen/plural.other] ohne Wert` |
| `r5-shouldtranslate-bypass` | **1** | `shouldTranslate=false ohne Allowlist-Eintrag` |

→ Der geforderte Substitutions-Rotfall (r1) ist gegen den neuen Stand weiterhin
rot, mit identischem Pfad-Detail. Keine Regression an der C5-Logik; der Diff
berührt `missing_branches` / `missing_variations` / `UNTRANSLATED_ALLOWLIST`
nicht — `check_catalog` liest nur noch `data["strings"]` statt
`data.get("strings", {})`, also ohne stillen Default.

### ci.yml — Xcode-Pin (F2)

YAML parst sauber (PyYAML 6.0.3): `jobs: ['l10n', 'build-and-test']`,
Step `Xcode-Version wählen` mit `env: {XCODE_VERSION: '26.6'}`,
`permissions: {contents: read}`, Concurrency unverändert.

Step-Skript aus dem Workflow extrahiert und mit Stubs für `sudo` /
`xcode-select` / `xcodebuild` gefahren:

| Szenario | Exit | Ausgabe |
|----------|------|---------|
| `$XCODE_APP` fehlt | **1** | `::error::… fehlt im Runner-Image – Pin nicht erfüllbar.` |
| aktiv 26.5, erwartet 26.6 | **1** | `::error::Xcode 26.5 aktiv, erwartet 26.6.` |
| aktiv 26.6.1 (Patch-Drift) | **1** | `::error::Xcode 26.6.1 aktiv, erwartet 26.6.` |
| aktiv 26.6 | **0** | läuft weiter |

`set -euo pipefail` deckt zusätzlich den Fall ab, dass `xcodebuild -version`
selbst scheitert: die Pipeline in `ACTIVE=$(…)` failt, der Step bricht ab —
ein leeres `ACTIVE` würde ohnehin am Vergleich scheitern. Fail-closed in beide
Richtungen.

**Keine weiteren Workflow-Änderungen**: `git diff --name-only` liefert exakt die
zwei Dateien, der ci.yml-Diff ist ein einziger Hunk (`@@ -47,14 +47,23 @@`)
innerhalb des Steps `Xcode-Version wählen`. Der `l10n`-Job, der
Wegwerf-Simulator-Step, Permissions und Concurrency sind unangetastet.

### Statischer Pass

- `guard.py sizes --files scripts/check-l10n.py .github/workflows/ci.yml`
  → `sizes: ok (2 geprueft, 0 Soft-Warnungen)`, Exit 0 (189 bzw. 158 Zeilen).
- `ruff check` (Skill-Config) → 1 Treffer `PTH201` in Zeile 164 — **identisch im
  alten Stand** (`08cc088`), also vorbestehend, keine Regression.
- `ruff format --check` → 2 Abweichungen, beide in Zeilen, die der Diff nicht
  anfasst; alter Stand zeigt dieselben. Das Projekt hat weder `pyproject.toml`
  noch `ruff.toml`/`mypy.ini` — ruff/mypy sind hier kein Projekt-Gate, die Werte
  sind rein informativ.
- `mypy --strict` → 1 Treffer, siehe N3.

## Findings

| ID  | Severity | Blocker | Datei:Zeile | Kategorie | Titel |
|-----|----------|---------|-------------|-----------|-------|
| N1 | minor | nein | `.github/workflows/ci.yml:41,50` | ci | Xcode-Version an zwei Stellen gepflegt (Drift-Risiko) |
| N2 | minor | nein | `scripts/check-l10n.py:141` | errors | Roher Traceback bei Nicht-Dict-Entry (bereits im Backlog) |
| N3 | minor | nein | `scripts/check-l10n.py:115` | typing | `-> dict` ohne Typargumente |

### N1 — Xcode-Version an zwei Stellen gepflegt
- **Datei**: `.github/workflows/ci.yml:41` (`XCODE_APP: /Applications/Xcode_26.6.app`)
  und `:50` (`XCODE_VERSION: "26.6"`)
- **Problem**: Beim nächsten Xcode-Bump müssen beide Werte mitwandern. Wird nur
  einer gezogen, failt der Job — fail-closed, also sicher, aber unnötig.
  Zusätzlich ist der Vergleich exakt: liefert das Runner-Image unter
  `Xcode_26.6.app` eines Tages `26.6.1`, bricht CI (verifiziert oben).
- **Fix (optional)**: `XCODE_VERSION` als Single Source, Pfad daraus ableiten —
  `XCODE_APP="/Applications/Xcode_${XCODE_VERSION}.app"`.
- **Triage**: kein Blocker — die Fehlerrichtung ist die sichere.

### N2 — Roher Traceback bei Nicht-Dict-Entry
- **Datei**: `scripts/check-l10n.py:141` (`entry.get("shouldTranslate")`)
- **Problem**: `{"strings": {"k": "nope"}}` → `AttributeError: 'str' object has
  no attribute 'get'` als Traceback. Exit ist trotzdem 1, das Gate hält; aber
  python-standards §4 („ein roher Traceback beim Nutzer ist ein Bug") ist
  verletzt. Die neue Struktur-Prüfung endet eine Ebene zu früh.
- **Status**: steht bereits als Backlog-Zeile (`:113` im alten Stand) — die
  Zeilennummer ist durch den Fix gewandert, das Verhalten unverändert. Nicht
  erneut aufgemacht.
- **Fix (später)**: in `check_catalog` `if not isinstance(entry, dict):
  findings.append(…); continue`.

### N3 — `-> dict` ohne Typargumente
- **Datei**: `scripts/check-l10n.py:115` (`def load_catalog(...) -> dict:`)
- **Problem**: `mypy --strict` meldet `type-arg`. python-standards §3 verlangt
  vollständige Annotationen; `dict[str, object]` wäre exakt.
- **Triage**: kein Blocker, kein Projekt-Gate (keine mypy-Config im Repo).

## Vorheriger Stand (Codex Gate #3, Scope B)

- **F1 (major, `check-l10n.py` fail-open bei fehlendem `strings`)**: **resolved** —
  reproduziert, Exit 1 mit klarer Meldung, kein Traceback.
- **F2 (minor, Xcode-Pin warnt statt failt)**: **resolved** — reproduziert,
  Exit 1 bei fehlendem Xcode **und** bei Versions-Mismatch.

Weiterhin offen (unverändert, war nicht Auftrag dieses Fixes und bleibt im
Backlog): ein leerer, aber wohlgeformter Katalog (`"strings": {}`) passiert das
Gate grün (Exit 0, selbst nachgeprüft) — bewusste Scope-Entscheidung, kein
Mindest-Key-Count.

## Verdikt

**Go.** Keine offenen Blocker. Der Fix ist chirurgisch (48 Zeilen in zwei
Dateien), schliesst genau die beiden gemeldeten Löcher, erzeugt keinen neuen
Bypass und lässt das C5-Regressionsverhalten unberührt. Merge frei.
