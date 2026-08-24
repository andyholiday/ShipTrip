# C6 — Bestandsaufnahme Video-/Groß-Altlasten

**Stand:** 2026-08-24 · **Branch:** `task/1.8.0-c6` · **Bezug:** ZIEL.md Kriterium 9

> **Dieser Bericht löscht nichts.** Er ist Entscheidungsgrundlage. Alle Messungen
> wurden read-only im Haupt-Tree `/Users/andre-studio/Documents/0.Projekte/ShipTrip`
> erhoben. Ein History-Rewrite hat **nicht** stattgefunden und braucht ein
> explizites Ok von Andre.

---

## Kernbefund in drei Sätzen

1. Der Arbeitsbaum ist **1,2 GB**, `.git` zusätzlich **460 MB**.
2. Von den 460 MB `.git` hängen **rund 246 MB an zwei Codex-Checkpoint-Refs**, nicht
   an echter Commit-Historie — die lassen sich **ohne jeden History-Rewrite** lösen.
3. Der Ordner `videos/` (265 MB) ist in **keinem** Branch und **keinem** Tag; er war
   bis zu diesem Task nur deshalb nicht im Repo, weil ihn niemand `git add`-te —
   eine `.gitignore`-Regel gab es nicht.

---

## 1. Große Dateien im Arbeitsbaum

### 1.1 Verzeichnis-Summen

| Verzeichnis  | Größe  | Git-Status                                     |
|--------------|--------|------------------------------------------------|
| `videos/`    | 265 MB | untracked, **war nicht ignoriert** (371 Dateien) |
| `marketing/` | 164 MB | teils tracked (70,4 MB in Historie), 68 MB untracked |
| `build/`     | 159 MB | ignoriert (`build/`)                            |
| `audit/`     | 34 MB  | tracked                                         |
| `.planning/` | 25 MB  | 61 Dateien untracked, nicht ignoriert           |
| `docs/`      | 2 MB   | tracked                                         |

### 1.2 Einzeldateien > 8 MB

| Größe | Pfad | Status |
|---|---|---|
| 77,8 MB | `build/export/ShipTrip.ipa` | ignoriert |
| 76,1 MB | `build/ShipTrip.xcarchive/…/ShipTrip.app/Assets.car` | ignoriert |
| 45,6 MB | `videos/…-preview-de/node_modules/ffmpeg-static/ffmpeg` | untracked¹ |
| 23,6 MB | `videos/…-preview-de/renders/…-de-18s-appstore.mp4` | untracked¹ |
| 23,6 MB | `marketing/…/previews/de-DE/…-preview-de-18s.mp4` | **tracked** |
| 23,6 MB | `videos/…-preview-en/renders/…-en-18s-appstore.mp4` | untracked¹ |
| 23,6 MB | `marketing/…/previews/en-US/…-preview-en-18s.mp4` | **tracked** |
| 20,0 MB | `videos/…-preview-en/renders/…-en-18s.mp4` | untracked¹ |
| 19,5 MB | `videos/…-preview-de/renders/…-de-18s.mp4` | untracked¹ |
| 18,2 MB | `videos/…-preview-de/node_modules/@ffprobe-installer/…/ffprobe` | untracked¹ |
| 10,5 MB | `build/ShipTrip.xcarchive/dSYMs/…/DWARF/ShipTrip` | ignoriert |
| 8,6 MB | `videos/…-teaser{,-en}/renders/…-teaser-10s.mp4` (2×) | untracked¹ |

¹ Ab diesem Commit durch die neuen `.gitignore`-Regeln abgedeckt (siehe §3).

Darunter folgen ~30 PNGs zwischen 2 und 3,6 MB in `marketing/`, `audit/screenshots/`
und `.planning/screenshots-*/`.

---

## 2. Größte Blobs der Git-Historie

### 2.1 Die entscheidende Unterscheidung

| Messung                                          | Blob-Volumen | Blobs |
|--------------------------------------------------|--------------|-------|
| **A** — echte Branches + Tags + Remotes           | **201,7 MB** | 1.037 |
| **B** — alle Refs inkl. `refs/codex/**`           | **447,8 MB** | 1.477 |
| **Delta B−A** — exklusiv an Codex-Refs hängend    | **≈ 246 MB** | 440   |

`git count-objects -vH`: 1.123 lose Objekte / **300,32 MiB**, Packs 158,34 MiB.
Die losen Objekte sind im Wesentlichen das Delta.

### 2.2 Woher das Delta kommt

Es existieren zwei Refs der Form

```text
refs/codex/turn-diffs/checkpoints/<hash>/<hash>/<timestamp>/<uuid>
```

Beide sind vom Objekttyp **`tree`** (kein Commit, kein Tag) — also nackte
Schnappschüsse des Arbeitsverzeichnisses, die Codex als Turn-Undo angelegt hat.
Jeder dieser Trees enthält **371 Dateien unterhalb `videos/`**, inklusive
`node_modules` mit den ffmpeg/ffprobe-Binaries. Deshalb taucht `videos/` in der
Objektdatenbank auf, obwohl `git log --all -- 'videos/*'` leer ist und
`git ls-tree` für **jeden** Branch und **jeden** Tag null `videos/`-Treffer liefert.

### 2.3 Top-Blobs — nur über Codex-Refs erreichbar

| Größe   | Pfad                                                            |
|---------|------------------------------------------------------------------|
| 43,46 MB| `videos/…-preview-de/node_modules/ffmpeg-static/ffmpeg`           |
| 19,10 MB| `videos/…-preview-en/renders/…-en-18s.mp4`                        |
| 18,64 MB| `videos/…-preview-de/renders/…-de-18s.mp4`                        |
| 17,34 MB| `videos/…-preview-de/node_modules/@ffprobe-installer/…/ffprobe`   |
| 8,18 MB | `videos/…-teaser-en/renders/…-teaser-10s.mp4`                     |
| 7,58 MB | `videos/…-teaser-en/renders/…-teaser-en-10s.mp4`                  |

Verteilung des Codex-Deltas nach Top-Verzeichnis: `videos/` 170,9 MB ·
`marketing/` 103,6 MB · `ShipTrip/` 76,6 MB · `audit/` 33,0 MB · `.planning/` 22,9 MB.
(Die Nicht-`videos/`-Anteile sind größtenteils Dubletten von Blobs, die ohnehin in
der echten Historie liegen.)

### 2.4 Top-Blobs der **echten** Historie (Branches/Tags)

| Größe   | Blob      | Pfad                                                        |
|---------|-----------|-------------------------------------------------------------|
| 22,49 MB| `b44670bb`| `marketing/…/previews/de-DE/shiptrip-app-preview-de-18s.mp4` |
| 22,47 MB| `892046e4`| `marketing/…/previews/en-US/shiptrip-app-preview-en-18s.mp4` |
| 3,46 MB | `f358db56`| `marketing/…/screenshots/en-US/04-travel-logbook.png`        |
| 3,46 MB | `3bdc90eb`| `marketing/…/screenshots/de-DE/04-reiselogbuch.png`          |
| 3,09 MB | `5a739dec`| `marketing/…/screenshots/en-US/03-icloud-sync.png`           |
| 2,96 MB | `e58a795e`| `marketing/…/screenshots/en-US/02-port-moments.png`          |
| 2,88 MB | `0db674ad`| `marketing/…/screenshots/de-DE/03-icloud-sync.png`           |
| 2,86 MB | `4735ae93`| `marketing/…/screenshots/de-DE/01-deine-kreuzfahrt.png`      |
| 2,86 MB | `19095043`| `marketing/…/screenshots/en-US/01-your-cruise.png`           |
| 2,61 MB | `6b6dba12`| `marketing/…/screenshots/de-DE/02-hafen-momente.png`         |
| 2,54 MB | `ce46cb24`| `audit/screenshots/meine-reisen-light-scrolled.png`          |
| 2,50 MB | `1ca66b3a`| `audit/screenshots/meine-reisen-dark-scrolled.png`           |
| 2,41 MB | `79ff9b94`| `audit/screenshots/weltkarte-light.png`                      |
| 2,17 MB | `1552d97c`| `audit/screenshots/weltkarte-dark.png`                       |
| 2,04 MB | `2eb845f5`| `audit/screenshots/weltkarte-v2-welt-zoom-light.png`         |

**Nur diese Liste wäre Ziel eines History-Rewrites.** Alles Video-Schwergewicht
darüber hinaus steckt in den Codex-Refs (§2.2) und braucht keinen Rewrite.

---

## 3. Was dieser Task bereits getan hat (`.gitignore`)

Ergänzt wurden ausschließlich Muster, die der Befund belegt:

| Muster | Belegt durch |
|---|---|
| `node_modules/` | 230 untracked Dateien, 0 getrackt; ffmpeg 45,6 MB + ffprobe 18,2 MB |
| `videos/*/renders/` | 7 Render-MP4s, ~70 MB |
| `videos/*/snapshots/` | 51 generierte Frame-Grabs, 43,8 MB |
| `videos/*/qa-final/` | 12 generierte QA-Frames, 14,3 MB |
| `videos/*/.bin-tools/` | ffmpeg/ffprobe-Binaries |
| `videos/*/.thumbnails/` | 9 generierte Thumbnails |
| `*.mp4`, `*.mov`, `*.m4v`, `*.webm` | ~70 MB untracked Renderausgaben |

**Verifiziert** (mit `core.excludesFile` gegen die echten Pfade im Haupt-Tree):

- untracked+nicht-ignoriert in `videos/`: **264,2 MB / 371 Dateien → 36,4 MB / 60 Dateien**
- repo-weit untracked+nicht-ignoriert: **519 → 223 Dateien**
- Quellen bleiben trackbar: `index.html`, `meta.json`, `package.json`, `assets/`
- **Kein getrackter Pfad** wird durch die neuen Muster ignoriert; die zwei
  getrackten App-Store-Previews bleiben unverändert versioniert (`.gitignore`
  wirkt nicht auf bereits versionierte Dateien).

Bewusst **nicht** ignoriert:

- `videos/*/assets/` (36 MB) — Quellmaterial der Videos, keine Renderausgabe.
- `.planning/screenshots-*/` (25 MB) — Screenshots werden in diesem Projekt
  bewusst versioniert (`audit/screenshots/` liegt getrackt in der Historie). Ob
  die Archiv-Screenshots dieselbe Behandlung bekommen, ist eine Produktentscheidung
  → siehe Option E.

---

## 4. Empfehlung — Optionen für Andre

### Option A — Codex-Checkpoint-Refs entfernen · **empfohlen, sofort**

**Gewinn:** ≈ 246 MB in `.git` (460 MB → ~210 MB).
**History-Rewrite:** **nein.** Es werden keine Commits angefasst; die Refs zeigen
auf lose Trees, nicht auf Commit-Historie. Alle SHAs bleiben stabil, kein
Force-Push, keine Neu-Klone.
**Kosten:** Für zwei alte Codex-Turns geht die „Turn rückgängig machen"-Funktion
verloren. Beide Checkpoints sind Altbestand und ohne laufenden Bezug.
**Risiko:** gering.

Vorgehen (auszuführen erst nach Andres Ok, nicht Teil dieses Tasks):
`git for-each-ref 'refs/codex/**'` prüfen → die beiden Refs löschen →
`git reflog expire --expire=now --all` → `git gc --prune=now`.

### Option B — `videos/` aus dem Arbeitsbaum auslagern · **empfohlen**

**Gewinn:** 265 MB auf der Platte.
**History-Rewrite:** **nein** — `videos/` ist in keinem Branch und keinem Tag.
Der Ordner kann frei verschoben werden, Git merkt es nicht einmal.
**Wohin:** externes Volume oder Cloud-Ordner für `renders/` + `assets/`;
`node_modules/` (64 MB) gar nicht sichern, das stellt `npm install` wieder her.
Alternativ ein eigenes kleines Repo `shiptrip-videos` nur für die Quellen
(`index.html`, `meta.json`, `package.json`, `hyperframes.json`, `assets/`) —
zusammen deutlich unter 40 MB.
**Risiko:** gering, sofern die finalen Renders vorher gesichert sind. Die
ausgelieferten Previews liegen ohnehin zusätzlich unter `marketing/`.

### Option C — `build/` aufräumen

**Gewinn:** 159 MB auf der Platte. Vollständig reproduzierbar (Archive + IPA),
bereits ignoriert, kein Git-Bezug. Risiko: keines.

### Option D — History-Rewrite für die zwei getrackten Preview-MP4s · **nur mit explizitem Ok**

**Gewinn:** ≈ 45 MB in der echten Historie — der mit Abstand teuerste Gewinn pro Risiko.
**Konsequenzen, die Andre kennen muss:**

- Alle Commit-SHAs ab dem einführenden Commit ändern sich.
- `origin/main` und `origin/release/1.7.1` brauchen einen **Force-Push**.
- Die Tags `v1.0.0 … v1.7.1` müssen neu gesetzt und neu gepusht werden.
- Jeder vorhandene Klon und **jeder Worktree** (`c1`, `c3`, `c6`, `c7`, `c8`) muss
  neu geklont bzw. neu aufgesetzt werden; offene Task-Branches müssten vorher
  gemerged oder neu aufgebaut werden.
- Laufende Release-Zweige (`release/1.8.0`) kollidieren mit dem Rewrite.

**Meine Einschätzung:** Optionen A+B+C bringen zusammen ~670 MB (246 MB Git +
424 MB Platte) **ohne jedes Rewrite-Risiko**. Die 45 MB aus Option D rechtfertigen
den Eingriff derzeit nicht — insbesondere nicht mitten in Run 1.8.0 mit fünf
offenen Task-Worktrees. Empfehlung: **Option D zurückstellen**, sinnvollerweise
auf einen Zeitpunkt ohne offene Branches, falls überhaupt.

### Option E — offene Produktentscheidung: Screenshot-Archive

`.planning/screenshots-archiv-2026-07-10/`, `.planning/screenshots-build23/` und
`.planning/testflight-feedback-2026-07-10/` sind 25 MB untracked. Zwei saubere Wege:
entweder bewusst committen (dann wachsen sie in die Historie), oder ignorieren und
außerhalb des Repos archivieren. Dieser Task hat sie unangetastet gelassen, weil
das Projekt Screenshots bisher bewusst versioniert.

---

## 5. Zusammenfassung der Größenordnungen

| Maßnahme                                   | Gewinn   | Rewrite nötig |
|--------------------------------------------|----------|---------------|
| A · Codex-Refs + `gc`                      | ~246 MB  | nein          |
| B · `videos/` auslagern                    | 265 MB   | nein          |
| C · `build/` löschen                       | 159 MB   | nein          |
| **Summe A+B+C**                            | **~670 MB** | **nein**   |
| D · MP4s aus echter Historie               | ~45 MB   | **ja**        |
