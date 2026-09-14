# ZIEL — Release 1.9.0 Build 33: Widgets „Dynamic Instrument" auf TestFlight und main (Run 2026-09-14)

**Ziel (1 Satz):** Der geprüfte Widget-Stand von `feature/widget-politur` wird in `main`
integriert, als Build 33 (1.9.0) auf TestFlight hochgeladen und samt Tags nach GitHub gepusht.

**Original-Anfrage (Andre, wörtlich, 2026-09-14):** „Winston, ich habe mir die widgets
angeschaut und ich finde sie gut. kannst du sie einbauen (falls noch nicht geschehen) und mir
alles zu testflight schicken und alles auf main pushen und zu github?"

**Marktlösung:** entfällt — Release-Lauf, keine Bauarbeit.

**Basis:** `feature/widget-politur` @ 3c3a355 (Quality approve go-mit-backlog,
`.planning/quality-review-widget-dynamic-iter1.md`; Widget-Code liegt bereits im Target
`ShipTripWidget/`). Kein neuer Produktionscode in diesem Run.

**Kriterien (messbar):**

1. **Merge:** `main` enthält 3c3a355 (`git merge-base --is-ancestor 3c3a355 main` → 0), ohne Konflikt.
2. **Build 33:** `CURRENT_PROJECT_VERSION = 33` an allen 6 Stellen der 1.9.0-Targets in
   `project.pbxproj`; Commit + Tag `v1.9.0-b33`.
3. **TestFlight:** `fastlane ios upload_testflight` Exit 0 und `fastlane ios validate` meldet
   latest TestFlight build = 33; `gate-run.json` mit Exit 0 (release-verifiziert).
4. **GitHub:** `origin/main` = lokales `main`, `origin/feature/widget-politur` vorhanden,
   Tags `v1.9.0-b30…b33` auf origin (`git ls-remote --tags origin`).
5. **Roadmap/ZIEL:** Stand-Satz neu, Run-Zeile `[x]`, ZIEL-Status gesetzt.

**Nicht im Scope:** App-Store-Einreichung · Changelog-Release-Schnitt (bleibt [Unreleased] wie
bei Build 30–32) · große Medienordner `marketing/release-1.7.0/` und `videos/` (bleiben
untracked, bewusst) · Gerätebestätigung (K8 der Vorläufer-Runs, Andre am Gerät).

**Status:** abgeschlossen 2026-09-14 — main @ 41b29a8, Tag v1.9.0-b33, Evidenz `.winston-evidence/20260914T083514Z/gate-run.json`.
