#!/usr/bin/env python3
"""L10n-Gate: jeder String-Catalog-Key braucht eine Übersetzung je Zielsprache.

Prüft alle `*.xcstrings` im Repo rein statisch über die JSON-Struktur — kein
Xcode, kein Simulator, keine Fremd-Tools. Ein Key gilt als gedeckt, wenn er für
jede Zielsprache einen nicht-leeren `stringUnit`-Wert hat; bei Plural-/Device-
Variationen muss jeder Zweig einen Wert haben.

Bewusst ausgenommen:
  * `"shouldTranslate": false` — reine Format-/Interpolationsketten.
  * die `sourceLanguage` des Katalogs — dort ist der Key selbst der Wert.

Aufruf: python3 scripts/check-l10n.py [pfad ...]
Exit-Code 1, sobald ein Key ohne Übersetzung existiert.
"""
from __future__ import annotations

import json
import pathlib
import sys

# Neue Sprache im Projekt? Hier eintragen.
TARGET_LANGUAGES = ("en",)


def missing_branches(node: object, path: str) -> list[str]:
    """Sammelt Pfade von Variations-Zweigen ohne nutzbaren Wert."""
    if not isinstance(node, dict):
        return [path or "<root>"]

    if "stringUnit" in node:
        unit = node["stringUnit"]
        value = unit.get("value") if isinstance(unit, dict) else None
        return [] if isinstance(value, str) and value.strip() else [path or "<root>"]

    variations = node.get("variations")
    if isinstance(variations, dict):
        gaps: list[str] = []
        for kind, cases in variations.items():
            if not isinstance(cases, dict) or not cases:
                gaps.append(f"{path}/{kind}")
                continue
            for case, branch in cases.items():
                gaps.extend(missing_branches(branch, f"{path}/{kind}.{case}"))
        return gaps

    return [path or "<root>"]


def check_catalog(catalog: pathlib.Path) -> list[str]:
    data = json.loads(catalog.read_text(encoding="utf-8"))
    source = data.get("sourceLanguage")
    findings: list[str] = []

    for key, entry in sorted(data.get("strings", {}).items()):
        if entry.get("shouldTranslate") is False:
            continue
        localizations = entry.get("localizations", {})
        for language in TARGET_LANGUAGES:
            if language == source:
                continue
            if language not in localizations:
                findings.append(f"{catalog}: [{language}] fehlt komplett — {key!r}")
                continue
            for gap in missing_branches(localizations[language], language):
                findings.append(f"{catalog}: [{gap}] ohne Wert — {key!r}")

    return findings


def main(argv: list[str]) -> int:
    if argv:
        catalogs = [pathlib.Path(a) for a in argv]
    else:
        catalogs = sorted(pathlib.Path(".").rglob("*.xcstrings"))

    if not catalogs:
        print("L10n-Gate: kein String Catalog gefunden.", file=sys.stderr)
        return 1

    findings: list[str] = []
    for catalog in catalogs:
        findings.extend(check_catalog(catalog))

    if findings:
        print(f"L10n-Gate fehlgeschlagen: {len(findings)} Lücke(n).", file=sys.stderr)
        for finding in findings:
            print(f"  {finding}", file=sys.stderr)
        return 1

    languages = ", ".join(TARGET_LANGUAGES)
    print(f"L10n-Gate ok: {len(catalogs)} Katalog(e) vollständig für {languages}.")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
