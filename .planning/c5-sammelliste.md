# C5-Sammelliste — neue Keys ohne EN + Aufräumliste (Stand 2026-08-24, nach B2-Merge)

Input für Task C5 (zentraler Katalog-Task). Quelle: Session-Handoff Run 1.8.0
plus B2-Developer-Returns. `Localizable.xcstrings` fasst NUR C5 an.

## Neue Keys ohne EN (aus C-/B-Wellen vor B2)

- „Anläufe" (→ „Port Calls")
- 2 C3-Footer-Sätze (Export/Import-Umfang)
- „Beispielreise" + B3-Footer („…Export- oder Backup-Dateien…")
- 4 ExportError-Texte (C4-Fix, `ExportImportService+Export.swift:28-38`)

## Neue Keys aus B2 (Onboarding; Stand nach Mini-Fix `730b98a`)

- Karte 1: „Geirangerfjord · Norwegen" · „Dein Logbuch für jede Kreuzfahrt" ·
  „Route, Häfen, Fotos und Ausgaben — …"
- Karte 2: „Drei Dinge, die ShipTrip für dich mitschreibt" · „Mehr musst du
  nicht einrichten — …" · „Karte & Route" · „Jeder Hafen wird zum Pin, …" ·
  „Fotos & Ausflüge" · „Bilder und Notizen landen …" · „Erinnerungen" ·
  „Ein Hinweis ein paar Tage vor …"
- Karte 3: „Sollen wir dich an die Abreise erinnern?" · „Ein paar Tage vor dem
  Auslaufen …" · „iOS fragt dich anschließend selbst …" ·
  „Erinnerungen aktivieren" · „Später" · „Beides lässt sich jederzeit …"
- Karte 4: „Bereit für deine erste Reise" · „Leg deine Reise an — …" ·
  „Beispielreise" · „Norwegische Fjorde" · „Norwegen · 9 Tage" ·
  „Erste Reise anlegen" · „Beispielreise ansehen" ·
  „Die Beispieldaten sind als Demo markiert und lassen sich mit einem Tipp
  wieder entfernen."
- Rahmen/A11y: „Überspringen" · „Weiter" · „Schritt %lld von %lld" ·
  „Beispielreise ansehen: %@, %@, %@"
- Settings: „Intro erneut zeigen"

Hinweis Mini-Fix-Delta (bereits eingearbeitet): „Die Beispielreise ist als
Demo markiert …" und „Norwegen · 7 Tage" existieren NICHT mehr — ersetzt
durch die Plural-Fußnote bzw. „Norwegen · 9 Tage".

Wortlaut-Konflikt, zentral entscheiden: Settings-Eintrag gebaut als
„Intro erneut zeigen" (Andres Formulierung); `narrative-onboarding.md` sagt
„Einführung erneut ansehen".

## Verwaist (aufräumen)

- „Demo (nur Debug)"
- 2 alte Export-Footer-Keys
- alter B3-Footer („…in einem Backup…")

## Regeln

- 36 Alt-EN-Lücken + 4 Push-Texte zusätzlich nachführen (Zählung aus Audit).
- Test-Build C5 OHNE `SWIFT_EMIT_LOC_STRINGS=NO` (einziger Task).
- Katalog-Keys type-aware (\(int) → %lld, \(str) → %@); `Text(title)` mit
  String-Parameter lokalisiert nie.
- B5-Abgleich erledigt (2026-08-24): B5 lieferte KEINE neuen Keys (nur
  Testcode + DEBUG-Nähte ohne user-sichtbare Strings). Liste ist final.
- Wortlaut-Entscheid Winston: Settings-Eintrag bleibt „Intro erneut zeigen"
  (Andres Formulierung, so gebaut und getestet) — EN entsprechend übersetzen,
  narrative-Formulierung ignorieren.
