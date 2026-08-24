#!/usr/bin/env python3
"""L10n-Gate: jeder String-Catalog-Key braucht eine Übersetzung je Zielsprache.

Prüft alle `*.xcstrings` im Repo rein statisch über die JSON-Struktur — kein
Xcode, kein Simulator, keine Fremd-Tools. Ein Key gilt als gedeckt, wenn er für
jede Zielsprache einen nicht-leeren Wert hat. `stringUnit`, `variations` und
`substitutions` werden dabei **unabhängig voneinander** geprüft: ein gültiger
übergeordneter `stringUnit` deckt eine kaputte Substitution nicht zu. Jeder
`plural`-Block braucht mindestens `one` und `other`.

Bewusst ausgenommen:
  * `"shouldTranslate": false`, aber nur für die Keys aus `UNTRANSLATED_ALLOWLIST`
    — reine Format-/Interpolationsketten. Jeder andere Key mit dem Flag ist ein
    Fund, damit das Flag kein stiller Bypass für nutzersichtbaren Text wird.
  * die `sourceLanguage` des Katalogs — dort ist der Key selbst der Wert.

Das Gate fällt geschlossen aus: ein Katalog, dessen Grundstruktur nicht stimmt
(kein JSON-Objekt, `strings` fehlt oder ist kein Objekt, `sourceLanguage` leer),
ist ein Fund — kein stiller Durchmarsch.

Aufruf: python3 scripts/check-l10n.py [pfad ...]
Exit-Code 1, sobald ein Key ohne Übersetzung existiert.
"""
from __future__ import annotations

import json
import pathlib
import sys

# Neue Sprache im Projekt? Hier eintragen.
TARGET_LANGUAGES = ("en",)

# Plural-Zweige, die jede Zielsprache mindestens braucht (en: one/other).
REQUIRED_PLURAL_CASES = ("one", "other")

# Reine Format-/Interpolationsketten ohne übersetzbaren Text. Nur diese Keys
# dürfen `shouldTranslate: false` tragen — neue Ausnahme heisst: hier eintragen
# und im Review begründen.
UNTRANSLATED_ALLOWLIST = frozenset(
    {
        "%@ %@",
        "%@ - %@",
        "%@ · %@",
        "%lld",
        "%lld %@",
        "+%lld",
        "-%lld%%",
        "🌊",
    }
)


def missing_variations(variations: object, path: str) -> list[str]:
    """Prüft einen `variations`-Block inklusive der Pflicht-Plural-Zweige."""
    if not isinstance(variations, dict) or not variations:
        return [f"{path}/variations"]

    gaps: list[str] = []
    for kind, cases in variations.items():
        if not isinstance(cases, dict) or not cases:
            gaps.append(f"{path}/{kind}")
            continue
        if kind == "plural":
            gaps.extend(
                f"{path}/{kind}.{case}"
                for case in REQUIRED_PLURAL_CASES
                if case not in cases
            )
        for case, branch in cases.items():
            gaps.extend(missing_branches(branch, f"{path}/{kind}.{case}"))
    return gaps


def missing_branches(node: object, path: str) -> list[str]:
    """Sammelt Pfade von Zweigen ohne nutzbaren Wert.

    `stringUnit`, `variations` und `substitutions` werden unabhängig geprüft;
    ein Knoten ohne jede dieser drei Angaben gilt selbst als Lücke.
    """
    if not isinstance(node, dict):
        return [path or "<root>"]

    gaps: list[str] = []
    checked = False

    if "stringUnit" in node:
        checked = True
        unit = node["stringUnit"]
        value = unit.get("value") if isinstance(unit, dict) else None
        if not (isinstance(value, str) and value.strip()):
            gaps.append(path or "<root>")

    if "variations" in node:
        checked = True
        gaps.extend(missing_variations(node["variations"], path))

    if "substitutions" in node:
        checked = True
        substitutions = node["substitutions"]
        if not isinstance(substitutions, dict) or not substitutions:
            gaps.append(f"{path}/substitutions")
        else:
            for name, substitution in substitutions.items():
                gaps.extend(
                    missing_branches(substitution, f"{path}/substitutions.{name}")
                )

    return gaps if checked else [path or "<root>"]


class CatalogError(Exception):
    """Der Katalog ist strukturell unbrauchbar — geprüft werden kann er nicht."""


def load_catalog(catalog: pathlib.Path) -> dict:
    """Liest den Katalog und erzwingt die Struktur, auf der das Gate aufbaut."""
    try:
        data = json.loads(catalog.read_text(encoding="utf-8"))
    except (OSError, ValueError) as error:
        raise CatalogError(f"nicht lesbar oder kein gültiges JSON — {error}") from error

    if not isinstance(data, dict):
        raise CatalogError("kein JSON-Objekt auf oberster Ebene")

    source = data.get("sourceLanguage")
    if not (isinstance(source, str) and source.strip()):
        raise CatalogError("'sourceLanguage' fehlt oder ist leer")

    if not isinstance(data.get("strings"), dict):
        raise CatalogError("'strings' fehlt oder ist kein Objekt")

    return data


def check_catalog(catalog: pathlib.Path) -> list[str]:
    data = load_catalog(catalog)
    source = data["sourceLanguage"]
    findings: list[str] = []

    for key, entry in sorted(data["strings"].items()):
        if entry.get("shouldTranslate") is False:
            if key not in UNTRANSLATED_ALLOWLIST:
                findings.append(
                    f"{catalog}: shouldTranslate=false ohne Allowlist-Eintrag — {key!r}"
                )
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
        try:
            findings.extend(check_catalog(catalog))
        except CatalogError as error:
            findings.append(f"{catalog}: unbrauchbarer Katalog — {error}")

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
