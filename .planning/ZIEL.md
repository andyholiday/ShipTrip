# ZIEL — App-Store-Release 1.9.0 in App Store Connect vorbereiten, Widgets im Vordergrund (Run 2026-09-14)

**Ziel (1 Satz):** Der Entwurf in App Store Connect steht als Version 1.9.0 mit Build 33,
neuen Release-Notes und Beschreibung (DE/EN), die die Widgets deutlich nennen, und einer
Screenshot-Serie, in der ein eigenes Bild die Widgets hervorhebt — bereit zum Einreichen,
ohne dass eingereicht wird.

**Original-Anfrage (Andre, wörtlich, 2026-09-14):** „ok ich möchte die neue version
veröffentlichen. bereite bitte alles in app store connect vor. zusätzlich sollen die widgets auch
deutlich erwähnt und auch in einem bild hervorgehoben werden"

**Marktlösung:** entfällt — Store-Vorbereitung mit dem bestehenden Fastlane/deliver-Weg (1.7.0).

**Ist (ASC, 2026-09-14, read-only abgefragt):** live 1.7.0 (Build 23) · Entwurf 1.8.0
`PREPARE_FOR_SUBMISSION` ohne Build, „Neue Funktionen" leer, je 4 Screenshots 6,9" (1320×2868)
in de-DE/en-US · Untertitel und Keywords (ASO 1.8.0) bereits gesetzt · Build 33 (1.9.0) `VALID`.

**Kriterien (messbar):**

1. **Metadaten 1.9.0** unter `marketing/release-1.9.0/app-store-connect/metadata/{de-DE,en-US}/`:
   `release_notes.txt` (alles seit 1.7.0, Widgets im ersten Punkt, ≤ 4000 Zeichen),
   `description.txt` mit eigenem Widget-Absatz (≤ 4000), `promotional_text.txt` nennt Widgets
   (≤ 170), `keywords.txt` = ASO-Stand aus dem Fastfile (≤ 100), `subtitle.txt` = ASC-Stand.
   Prüfbar per `wc -m` + grep „Widget".
2. **Widget-Bild:** je Locale ein Screenshot `02-widgets*.png` (1320×2868, kein Alpha) im Stil
   der 1.7.0-Serie (`app-store-v2/template.html`), der echte Galerie-Renderings (Medium + Small
   und ein Lock-Screen-Widget) zeigt; EN-Bild mit englischen Widget-Texten (Harness-Lauf). Die
   vier 1.7.0-Bilder folgen als 01, 03–05. Prüfbar per `sips` + Bild-Gate (frischer Prüfer).
3. **ASC-Entwurf:** editierbare Version heißt 1.9.0, Build 33 zugeordnet, Lokalisierungen
   de-DE/en-US tragen die Texte aus (1), Screenshot-Set `APP_IPHONE_67` je Locale = 5 Bilder in
   der Reihenfolge 01–05, Zustand weiter `PREPARE_FOR_SUBMISSION` (kein Submit). Prüfbar per
   read-only Spaceship-Abfrage (`scratchpad/asc_state.rb`-Muster) nach dem deliver-Lauf.
4. **Fastfile** trägt `APP_STORE_VERSION = "1.9.0"`, `APP_STORE_BUILD = 33`, Asset-Root 1.9.0;
   `CHANGELOG.md` hat den 1.9.0-Schnitt mit den bisher „Unreleased"-Einträgen; alles committed
   und auf `origin/main`. Prüfbar per grep + `git status`/`git rev-parse origin/main`.
5. **Gate:** ein frischer Prüfer sichtet alle 10 Screenshots und die Zeichenlimits: 0 Bilder mit
   abgeschnittenem Text, 0 Limit-Verstöße. Prüfbar per Gate-Report `.planning/gate-store-1.9.0.md`.

**Entscheidungen (Winston):** Widget-Bild an Position 2 (Position 1 verkauft laut Benchmark die
Kategorie) · Version 1.8.0-Entwurf wird zu 1.9.0 umbenannt statt neu angelegt · App-Previews
(Videos) bleiben unverändert (1.7.0) · Einreichen bleibt Andres Klick.

**Nicht im Scope:** Submit for Review · Preis/Verfügbarkeit · neue Previews · Gerätebestätigung.
