# Audit-Verifikation V5 — Tests/CI/Doku-Drift
Bezug: Voll-Audit 2026-07-10, Commit 687657c. Read-only Verifikation, kein Testlauf, kein Build.

## M6 — Testlauf breit, aber nicht hermetisch

**Teil (a) — Screenshot-Test schreibt in versionierten Repo-Pfad: CONFIRMED**

`ShipTripUITests/HauptansichtScreenshotTests.swift:17`:
```swift
private let outputDir = URL(filePath: "/Users/andreja/Documents/0.Projekte/ShipTrip/audit/screenshots")
```
Hardcodierter absoluter Pfad (nutzerspezifisch, kein `$(SRCROOT)`/relative Auflösung). Schreib-Helfer
`write(screenshot:name:)` (Zeile 283–287) schreibt direkt per `screenshot.pngRepresentation.write(to:)`
ohne Diff-/Baseline-Vergleich — jeder Testlauf überschreibt die Datei stillschweigend.

`git ls-files audit/screenshots/` liefert aktuell **20** getrackte PNGs (Audit nannte 11 zum
Audit-Zeitpunkt — seither sind mind. 9 weitere hinzugekommen, u. a. `weltkarte-v2-*`,
`meine-reisen-final-*`, vermutlich aus der Karten-Redesign-v2-Welle nach dem Audit-Snapshot).
Die 9 aktuellen Testmethoden schreiben auf einen Teil dieser Namen (`meine-reisen-{light,dark}`,
`-scrolled`-Varianten, `detail-pins-*`, `geo-hero-*`, `weltkarte-all-*` — 10 Dateien via
`captureMainView`/Helfer). Zahl „11" nicht exakt reproduzierbar (da Verzeichnis seit Audit
gewachsen), Mechanismus aber exakt wie behauptet: Kein Snapshot-Vergleich, direktes Überschreiben
versionierter Bilddateien, Pfad an einen einzelnen Entwickler-Rechner gebunden — auf jeder anderen
Maschine (CI, Zweit-Rechner) schlägt `setUpWithError` zwar nicht hart fehl (erstellt Verzeichnis-
Baum neu), schreibt aber in einen für dieses System falschen Pfad statt eines projektrelativen.

**Teil (b) — kombinierter Testlauf am Unit-Host-Bootstrap gescheitert: UNVERIFIABLE ohne Lauf**

Kein `.xctestplan` im Repo (siehe M7). Keine `.xcscheme`-Datei existiert überhaupt im Repo —
weder shared (`xcshareddata/xcschemes/`, leer) noch user-scoped (nur
`ShipTrip.xcodeproj/xcuserdata/abook.xcuserdatad/xcschemes/xcschememanagement.plist`, das auf
ein referenziertes, aber nicht vorhandenes `ShipTrip.xcscheme_^#shared#^_` verweist — die
eigentliche `.xcscheme`-Datei fehlt auf der Platte). Ohne Scheme-Datei lassen sich weder
`TestAction`-Parallelisierung (`parallelizable`) noch Test-Host-Konfiguration statisch prüfen —
das ist ohne echten Testlauf nicht rekonstruierbar. Code-Indiz: keines der beiden Test-Targets
(`ShipTripTests`, `ShipTripUITests`) hat ersichtliche gemeinsame Host-App-Abhängigkeiten im
Repo, die einen Bootstrap-Konflikt nahelegen würden — reine Vermutung, nicht verifizierbar.

**Fix-Hinweis:** Pfad relativ zu `ProcessInfo.processInfo.environment["SRCROOT"]` oder in einen
`FileManager.default.temporaryDirectory`-Unterordner umbauen und PNGs aus Git-Tracking nehmen
(oder bewusst als Artefakt in CI hochladen statt versionieren). Eine `.xcscheme` sollte als shared
committed werden, damit Testkonfiguration reproduzierbar und CI-fähig wird.

---

## M7 — Keine reproduzierbare CI-/Release-Kette

**CONFIRMED — vollständig, sogar etwas gravierender als im Audit beschrieben.**

- `.github/workflows/`: existiert nicht (`ls` liefert nichts).
- `.xctestplan`: keine Datei im gesamten Repo (`find . -iname "*.xctestplan"` leer).
- **Keine `.xcscheme`-Datei überhaupt** im Repo (weder shared noch getrackt via git) — d. h. nicht
  nur "keine CI-Kette", sondern auch lokal keine reproduzierbare, versionierte Testkonfiguration.
  `git ls-files | grep xcscheme` liefert nichts.
- `fastlane/Fastfile` hat genau 3 Lanes:
  1. `validate` (Zeile 5–13): read-only, prüft nur ASC-API-Key + `latest_testflight_build_number`.
  2. `fetch_profile` (Zeile 15–33): lädt Provisioning-Profil.
  3. `upload_testflight` (Zeile 37–51): **exakt wie im Audit zitiert** — `pilot(ipa:
     "build/export/ShipTrip.ipa", ...)`. Kein `build_app`/`gym`/`scan`/`run_tests`-Aufruf irgendwo
     im Fastfile. Die Lane setzt eine bereits fertig gebaute/exportierte IPA voraus, baut und
     testet selbst nicht.
- Kein `Gemfile`/`Gemfile.lock` im Repo → Fastlane-Version ist **nicht gepinnt**, hängt von der
  lokal installierten Version ab (Drift-Risiko zwischen Rechnern).

**Fix-Hinweis:** Shared `.xcscheme` committen; `fastlane test`-Lane ergänzen, die `scan`/`run_tests`
lokal UND in einer CI-Lane (z. B. `xcodebuild test` via GitHub Actions macOS-Runner) ausführt, bevor
`upload_testflight` überhaupt erreichbar ist. `Gemfile`+`Gemfile.lock` mit gepinnter Fastlane-Version
ergänzen.

---

## M8 — Roadmap/Modell-Doku/Store-Metadaten auseinandergelaufen

**CONFIRMED — alle Teil-Behauptungen bestätigt, teils deutlicher als im Audit beschrieben.**

**Modelle 5 vs. 8:** `grep -rn "^@Model" ShipTrip/Models/*.swift` liefert 8 Treffer: `Cruise`,
`CustomShip`, `CustomShippingLine`, `Expense`, `HiddenCatalogItem`, `Deal`, `Photo`, `Port`.
`docs/MODELS.md` Übersichtstabelle (Zeile ~13–19) listet nur 5: `Cruise`, `Port`, `Expense`,
`Photo`, `Deal`. Fehlend in der Doku: `CustomShippingLine`, `CustomShip`, `HiddenCatalogItem` —
genau die drei Modelle, die zu ADR-006 (eigene Reedereien/Schiffe) gehören und die
`ShippingLineCatalogDedup`-Logik (siehe L5) betreffen.

**Roadmap vs. CHANGELOG — konkreter Fund, präziser als Audit-Beschreibung:**
`docs/umsetzungsplan-audit-2026-07.md:184`:
```
— **B4.3b-2** (Bottom-Sheet-Stopliste) und **B4.3b-3** (Bezier-Kurvenrouten) offen.
```
und Zeile 230: `(Release-Commit bbcc06a; B4.3b-2/-3 folgen bewusst in einer späteren Welle)`.
`CHANGELOG.md` Abschnitt `[1.7.0] - 2026-07-10` (Zeilen 20–29) führt aber genau diese beiden
Punkte bereits als **veröffentlicht**: „Karte: Bottom-Sheet mit Stop-Timeline" (= B4.3b-2) und
„Karte: kurvige Routen statt gerader Linien … Catmull-Rom-Spline" (= B4.3b-3, funktional das
Bezier-Kurven-Äquivalent). Die Roadmap wurde seit dem 1.7.0-Release (selbes Datum wie der Audit)
nicht nachgezogen — Doku-Drift bestätigt mit exaktem Beleg.

**Store-Metadaten/README — Versions- und Format-Drift bestätigt:**
- `README.md` Zeile 9: Versions-Badge `![Version](...Version-1.5.1-brightgreen)` — tatsächlicher
  Stand laut CHANGELOG/Memory: 1.7.0 (Build 18). Massive Drift (2 Minor-Versionen).
- `APP_STORE_LISTING.md` Zeile 130: `## What's New (Version 1.0.3)` — noch krasser veraltet.
- Export-Format JSON vs. ZIP: `APP_STORE_LISTING.md` Zeile 63/111 („Export als JSON jederzeit
  möglich" / „Export as JSON anytime"), `PRIVACY_POLICY.md` Zeile "Export: ... als JSON exportieren"
  sowie identisch in `docs/privacy.html:175,235` — alle drei sagen JSON. Tatsächliches Format laut
  `README.md` Zeile 42 und `CHANGELOG.md`: „Export/Import als ZIP (verlustfrei, inkl. Bilder)".
  Bestätigt: Store-/Privacy-Texte sind auf einem älteren (JSON-only) Stand, App exportiert real ZIP.
- App-Name-Inkonsistenz: **teilweise bestätigt** — `README.md` nennt nur „ShipTrip",
  `APP_STORE_LISTING.md` Zeile 4/6 listet zwei Kandidaten-Namen „ShipTrip - Kreuzfahrt Sammlung"
  und „ShipTrip - Cruise Tracker" nebeneinander (als offene Auswahl, nicht als Fehler markiert),
  `PRIVACY_POLICY.md` Zeile 3 nutzt „ShipTrip - Kreuzfahrt Sammlung". Es ist kein hart
  widersprüchlicher Live-Zustand (App Store zeigt nur einen Namen), sondern ein unaufgelöster
  Namensentwurf in der Listing-Doku — daher **PARTIALLY CONFIRMED**, nicht „konkret falsch live".
- `PRIVACY_POLICY.md`/`docs/privacy.html` Datumsstempel „19. Dezember 2024" — deutlich vor allen
  seither verbauten Features (Karten-Redesign, eigene Reedereien, ZIP-Export) — zusätzlicher,
  im Audit nicht explizit genannter Beleg für Doku-Drift.

**Fix-Hinweis:** Vor jedem Release-Tag ein Doku-Sync-Schritt (README-Badge, APP_STORE_LISTING „What's
New", PRIVACY_POLICY/privacy.html Exportformat) als Checklistenpunkt in den Release-Prozess
aufnehmen; `docs/MODELS.md` um die 3 fehlenden Custom-/Hidden-Modelle ergänzen; Roadmap-Datei nach
jedem CHANGELOG-Eintrag gegenlesen (oder Roadmap-Checkbox-Update Teil des Release-Fastlane-Schritts).

---

## L2 — Screenshot-Tests ohne visuelle Baseline

**CONFIRMED.** `ShipTripUITests/HauptansichtScreenshotTests.swift` enthält genau **9**
`func test...`-Methoden (Zeilen 26, 33, 44, 134, 141, 151, 156, 163, 168):
`testScreenshot_Light`, `testScreenshot_Dark`, `testScreenshot_HeroPhotoClean`,
`testScreenshot_DetailPins_Light/_Dark`, `testScreenshot_GeoHero_Light/_Dark`,
`testScreenshot_MapAllTrips_Light/_Dark`. Zahl deckt sich exakt mit dem Audit-Claim „9
UI-Methoden". Kein `XCTAssert`, kein Pixel-Diff, kein Snapshot-Testing-Framework (z. B.
`swift-snapshot-testing`) im gesamten Test-Target referenziert — jede Methode endet mit einem
reinen `write(screenshot:name:)`-Aufruf ohne Vergleich gegen eine Baseline.

**Fix-Hinweis:** Entweder ein echtes Snapshot-Testing-Framework einführen (Pixel-Diff mit
Toleranzschwelle) oder die Tests explizit als „Screenshot-Erzeugung für manuelle Sichtprüfung"
umbenennen/dokumentieren, damit niemand fälschlich von automatischer Regressionsabsicherung ausgeht.

---

## L5 — CloudKit-Folgerisiko einmalige Dedup-Flags

**CONFIRMED als dokumentiertes Zukunftsrisiko, kein aktueller Bug** (CloudKit ist deaktiviert,
siehe ADR-002/`docs/MODELS.md`).

`ShipTrip/Utilities/ShippingLineCatalogDedup.swift`: `run(context:isFallbackStore:defaults:)`
(Zeile 32) prüft zu Beginn `guard !defaults.bool(forKey: completedFlagKey) else { return }` — ein
einmaliges, **versioniertes** UserDefaults-Flag (`"shippingLineCatalogDedupCompleted.v1"`, Zeile
25) pro Gerät. Das Flag wird nur gesetzt, wenn alle drei Dedup-Pässe (`dedupeLines`, `dedupeShips`,
`dedupeHidden`) fehlerfrei liefen UND kein In-Memory-Fallback-Store aktiv ist (`shouldMarkCompleted`,
Zeile 60–63).

**Konkretes Szenario geprüft:** Läuft der Dedup-Pass einmal (Flag → `true`) und aktiviert der
Nutzer/eine spätere Version danach CloudKit, das rückwirkend ältere, auf einem zweiten Gerät
offline angelegte Duplikate synchronisiert, würde der Dedup **nicht** erneut laufen — das Flag
blockiert jeden weiteren Durchlauf auf diesem Gerät, unabhängig davon, ob neue Duplikate durch
CloudKit-Merge nach dem Flag-Zeitpunkt eintreffen. Der Code selbst benennt dieses Muster im
Kommentar (Zeile 26–27: „Bei einer künftigen, grundlegend geänderten Dedup-Logik den Suffix
hochzählen (z. B. `.v2`)") — das deckt aber nur eine *Logikänderung* ab, nicht das hier relevante
Szenario „gleiche Logik, aber neue Duplikate durch später aktivierten Sync". Die Analogie zu
`IdBackfill` (siehe Projekt-Memory zum SwiftData-Migrations-Gotcha) legt nahe, dass dasselbe
Store-Rework nötig wäre, das dort bereits einmal zu Datenverlust-artigen Symptomen geführt hat.

**Fix-Hinweis:** Wenn CloudKit aktiviert wird, das Dedup entweder von einem einmaligen Flag auf
einen wiederkehrenden Trigger umstellen (z. B. bei jedem erfolgreichen `NSPersistentCloudKitContainer`-
Remote-Change-Event erneut prüfen, nicht nur beim ersten App-Start) oder den Flag-Suffix beim
CloudKit-Aktivierungs-Release explizit auf `.v2` hochzählen, damit der Dedup mindestens einmal nach
Sync-Aktivierung erneut läuft.
