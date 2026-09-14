# Review — .shiptrip-Dateien aus der Dateien-App oeffnen (fix/share-open-in-place)

- **Iteration**: 1 / 3
- **Reviewer**: quality-agent (frischer Spawn)
- **Datum**: 2026-09-10
- **Basis**: `feature/widget-1.9.0`...`a0092dd` (Fix-Commit `0b3164b` + Doku-Commit `a0092dd`)
- **Verdikt**: approve — **GO**
- **Stats**: critical: 0, major: 2, minor: 1 — Blocker: 0, ins Backlog: 3

## Summary

Der Diff ist klein (4 Dateien, 107+/11-), chirurgisch und trifft genau die drei
Kriterien 1–3. Die Loeschregel ist konservativ in die sichere Richtung gebaut
(im Zweifel *nicht* loeschen) und gegen Symlink-/`..`-Tricks robust. Beide
Zweige der Regel und beide Onboarding-Faelle sind im Simulator **am laufenden
System** nachgestellt und per Screenshot belegt — nicht nur per Unit-Test.
Kein Blocker. Die zwei `major`-Befunde betreffen die *Beweisfuehrung*, nicht das
Produktverhalten.

## Findings

| ID  | Severity | Blocker | File:Line | Kategorie | Titel |
|-----|----------|---------|-----------|-----------|-------|
| F01 | major | nein | `.winston-evidence/20260910T122831Z/gate-run.json` | evidence | `-only-testing`-IDs treffen zwei Suites nicht — Gate exit 0 trotz leerer Auswahl |
| F02 | major | nein | `ShipTrip/Views/Share/ShareImportCoordinator.swift:99-105` | tests | Kein Regressionstest fuer die Verdrahtung (`defer`); "vor dem Fix rot" nur trivial erfuellt |
| F03 | minor | nein | `ShipTrip/ShipTripApp.swift:291-298` | readability | Sheet-Getter haengt am Cover-Binding statt an der Bedingung |

### F01 — `-only-testing`-Bezeichner treffen zwei Suites nicht

- **Datei**: `.winston-evidence/20260910T122831Z/gate-run.json` (Developer) und
  `.winston-evidence/20260910T124418Z/gate-run.json` (dieser Lauf)
- **Severity**: major · **Blocker: nein**
- **Problem**: Swift Testing selektiert ueber den **Typnamen**, nicht den
  Dateinamen. `-only-testing:ShipTripTests/ShareExportTests` und
  `-only-testing:ShipTripTests/ShareImportPreflightTests` zeigen auf Dateien;
  die Typen heissen `ShareExportEnvelopeTests`, `ShareExportGuardTests`,
  `ShareExportCompatibilityTests`, `ShareArchivePreflightTests` (+1).
  xcodebuild fuehrt dafuer nichts aus und liefert trotzdem Exit-Code 0 — das
  Gate behauptet einen Umfang, den es nie hatte. Der Developer meldete
  "30 Tests"; gelaufen sind 5 der 7 selektierten Suites.
- **Warum kein Blocker**: Die Suites, die den Diff decken, sind gelaufen und
  gruen (37 Tests / 6 Suites, u. a. "Share-Import: Loeschregel der Quelldatei",
  "Share-Import: Ergebnis und Fingerabdruck", "Onboarding", "Roundtrip",
  "IncomingLinkRouter"). Export/Preflight sind vom Diff nicht beruehrt.
- **Fix**: Typnamen statt Dateinamen verwenden, z. B.
  `-only-testing:ShipTripTests/ShareArchivePreflightTests`. Generell: nach jedem
  Gate-Lauf die Zeile `Test run with N tests in M suites` gegen die Zahl der
  selektierten Suites pruefen.

### F02 — Kein Regressionstest fuer die Verdrahtung

- **Datei**: `ShipTrip/Views/Share/ShareImportCoordinator.swift:99-105`
- **Severity**: major · **Blocker: nein**
- **Problem**: `ShareImportCleanupTests` deckt das reine Praedikat
  `shouldRemoveAfterImport(_:)` in allen vier Zweigen ab — aber nicht die Stelle,
  an der der Bug sass: das `defer` in `startImport`. ZIEL-Kriterium 2 verlangt
  "Unit-Test dafuer, vor dem Fix rot"; das ist hier nur trivial erfuellt, weil
  die Funktion vor dem Fix nicht existierte — ein Compile-Fehler ist kein
  Rot-Beweis eines Defekts.
- **Warum kein Blocker**: Beide Zweige der Verdrahtung sind in diesem Review am
  laufenden System verifiziert (E2E-Protokoll unten): In-Place-Datei bleibt,
  Inbox-Kopie wird geloescht.
- **Fix**: Test ueber die oeffentliche Naht `handleIncomingURL(_:modelContext:)`
  mit einer Datei in einem Wegwerf-Verzeichnis **ausserhalb** von
  `Documents/Inbox`/`tmp`; auf `.finished` warten, dann
  `#expect(FileManager.default.fileExists(atPath: url.path(percentEncoded: false)))`.
  Gegenprobe mit einer Datei in `Documents/Inbox` (muss weg sein).

### F03 — Sheet-Getter haengt am Cover-Binding

- **Datei**: `ShipTrip/ShipTripApp.swift:291-298` (Getter Zeile 294)
- **Severity**: minor · **Blocker: nein**
- **Problem**: `onboardingCover` ist eine *computed property*, die bei jedem
  Zugriff ein neues `Binding` baut; der Sheet-Getter ruft darauf `.wrappedValue`.
  Funktioniert (E2E belegt), koppelt das Sheet aber an die Praesentations-
  Semantik des Covers statt an die schlichte Bedingung. Eine Indirektion mehr
  als noetig.
- **Fix (optional)**: eine `private var onboardingCoverIsUp: Bool` als einzige
  Wahrheit und beide Leser (Cover-Binding und Sheet-Getter) darauf setzen.
- **Bewertung**: Geschmack, kein Defekt. Der Doc-Kommentar begruendet die
  gewaehlte Form ("eine Naht fuer beide Leser") nachvollziehbar. Backlog.

## Statischer Pass

- `guard.py sizes --files ShipTripApp.swift ShareImportCoordinator.swift ShareImportCleanupTests.swift`
  → `sizes: ok (3 geprueft, 0 Soft-Warnungen)`, Exit 0.
- Keine Force-Unwraps im Diff, keine `try!`, keine neuen Warnungen im Build.
- Test-Diff (51 Zeilen) ≤ Code-Diff (64 Zeilen) ✓.
- Swift 6: `shouldRemoveAfterImport` ist `static` auf einer `@MainActor`-Klasse,
  also MainActor-isoliert; Aufrufer (Task in `startImport`, `@MainActor`-Suite)
  passen. Keine Aktorgrenzen-Verletzung.
- **Pfad-Normalisierung**: `resolvingSymlinksInPath()` + `standardizedFileURL`
  loest `/var` → `/private/var` auf beiden Seiten des Vergleichs auf; `..`-Pfade
  werden entfernt, bevor der Praefix geprueft wird — ein
  `.../Documents/Inbox/../../X/f.shiptrip` faellt korrekt aus der Loeschregel.
  Der Praefix-Vergleich mit angehaengtem `/` verhindert einen Treffer auf
  `Inbox2`. Fehlerrichtung ist durchgehend "lieber nicht loeschen".

## E2E-Protokoll (Simulator, iPhone 17 / iOS 26.5, Wegwerf-Klon `ci-share-qa`)

Aufbau: Debug-Build (`-allowProvisioningUpdates`, **ohne**
`CODE_SIGNING_ALLOWED=NO` — ohne Entitlements trappt die App beim
CloudKit-Setup, siehe Notiz unten), Testdatei in
`AppGroup group.com.apple.FileProvider.LocalStorage/File Provider Storage/`
= "Auf meinem iPhone" der Dateien-App. Getippt wurde per CGEvent auf das
Simulator-Fenster (Fenster-Frame bei jedem Tap frisch ueber die AX-API geholt).

| Fall | Ergebnis | Screenshot |
|------|----------|------------|
| Datei-Icon in der Dateien-App traegt das ShipTrip-Symbol (UTI/`CFBundleDocumentTypes` greifen) | **bestanden** | `05-files-browse.png` |
| **E2E-1** Kaltstart: Tippen in der Dateien-App → App startet, importiert, Ergebnis-Sheet "Reise importiert", Liste zeigt 1 Reise / 8 Tage / 2 Laender / 6 Anlaeufe | **bestanden** | `11-E2E-case1-result.png` |
| **E2E-1b** Originaldatei danach noch da (Host-FS: 4407 Bytes unveraendert; Dateien-App: "1 Objekt") | **bestanden** | `12-E2E-case1-file-still-there.png` |
| **E2E-1c** `Documents/Inbox` des Containers nach dem Import **leer** → iOS hat die In-Place-URL uebergeben, keine Kopie | **bestanden** | (Container-Listing im Protokoll) |
| **E2E-2** Frische Installation, Onboarding offen: Tippen → Onboarding-Cover erscheint, Ergebnis-Sheet korrekt unterdrueckt | **bestanden** | `16-E2E-case2-onboarding-cover.png` |
| **E2E-2b** Onboarding abgeschlossen ("Ueberspringen" → "Erste Reise anlegen") → Ergebnis-Sheet erscheint nachtraeglich | **bestanden** | `18-E2E-case2-after-onboarding.png` |
| **E2E-3** (Zusatz) Inbox-Zweig: Kopie in `Documents/Inbox` + `simctl openurl` → Import gruen, Inbox-Kopie danach geloescht | **bestanden** | `19-inbox-branch.png` |

Screenshot-Verzeichnis:
`/private/tmp/claude-501/-Users-andre-studio-Documents-0-Projekte-ShipTrip/9d8067bb-9f28-48a2-bd9f-d0b1d0fd2d37/scratchpad/qa/`

**Nicht durchgefuehrt:** der urspruengliche Ausloeser — Tippen auf einen
`.shiptrip`-Anhang **in iMessage**. Per ZIEL ausdruecklich nicht im Scope
(Share-Extension), als Known Limitation in `docs/features/kreuzfahrt-teilen.md:84`
und als Backlog-Zeile dokumentiert. Der Fix macht den Umweg ueber die
Dateien-App belegbar moeglich; ob Andres konkreter iMessage-Tap danach direkt
funktioniert, ist damit **nicht** bewiesen.

**Notiz fuer kuenftige Laeufe:** ein Simulator-Build mit
`CODE_SIGNING_ALLOWED=NO` stripped die Entitlements; die App stirbt dann beim
Start mit `EXC_BREAKPOINT` in `PFCloudKitContainerProvider`. Das ist ein
Build-Flag-Artefakt, kein Produktfehler.

## Kriterien-Abgleich (ZIEL 1–4)

1. `ShipTrip-Info.plist:16-20,45` — `public.data` + `public.content`,
   `LSSupportsOpeningDocumentsInPlace` = `true` ✓
2. Loeschregel + Unit-Test ✓ (Einschraenkung Rot-Beweis: F02)
3. Ergebnis-Sheet ueberlebt das offene Onboarding ✓ (E2E-2/2b)
4. Beruehrte Suites gruen, `gate-run.json` Exit 0 ✓ (Einschraenkung Umfang: F01)

## Backlog-Kandidaten

- [major] `.winston-evidence/*/gate-run.json` — `-only-testing`-IDs auf Swift-Testing-Typnamen umstellen
- [major] ShipTrip/Views/Share/ShareImportCoordinator.swift:99 — Regressionstest fuer den `defer`-Loeschpfad ueber `handleIncomingURL`
- [minor] ShipTrip/ShipTripApp.swift:294 — Sheet-Getter auf eine schlichte Bool-Bedingung statt auf das Cover-Binding setzen
