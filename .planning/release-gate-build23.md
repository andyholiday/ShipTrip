# Release-Gate — Build 23 (TestFlight-Vorlauf)

- **Rolle**: quality-agent (frischer Spawn, Ein-Runden-Lauf)
- **Datum**: 2026-08-04
- **Basis**: HEAD `52b22a9` + uncommitteter Working Tree
- **Scope**: Kalenderwechsel-Fix (Dialog + Migration) · Andres Demo-Hafen-Arbeit
  (`DemoDataService` + 5 `demo_port_*`-Imagesets, nur auf Build-/Suite-Schaden geprüft)
- **Verdikt**: **GO** — keine offenen Blocker im Code.
  **Aber**: Der Upload selbst ist ohne Version-Bump nicht durchführbar (siehe R1).
- **Evidenz**: `.winston-evidence/20260804T170113Z/gate-run.json`
- **Stats**: critical 0, major 1 (neu) + 1 Release-Voraussetzung, minor 1 — Blocker 0, Backlog 3

## Kurzfassung

Der Kalenderwechsel-Dialog wurde erstmals real durchgeklickt und mit Screenshots
belegt: Dialog erscheint mit korrektem, vollständigem deutschen Text, „Abbrechen"
stellt den alten Kalender wieder her, „Übertragen" migriert nachweislich — im
echten EventStore liegt danach genau **ein** ShipTrip-Termin, und der liegt im
**neuen** Kalender. Die Unit-Suite ist vollständig grün (305/305). Der
Release-Konfiguration-Build läuft fehlerfrei; `DemoDataService` ist im
Release-Binary nicht enthalten, der `UIKit`-Import erzeugt keine Release-Fehler.
Die UI-Suite ist **nicht** grün: 9 von 24 Tests fallen aus, alle mit derselben
vorbestehenden Ursache — ein hartkodierter, fremder Home-Pfad in
`HauptansichtScreenshotTests`. Kein Produktdefekt, aber ein Loch im Gate.

## Testläufe

Wegwerf-Simulator `ci-release-gate` (iPhone 17 / iOS 26.5), eigens erzeugt,
danach gelöscht. Kalender-Grant via
`xcrun simctl privacy <udid> grant calendar com.andre.ShipTrip` (plus
`…xctrunner` für den Test-Runner, der den zweiten Kalender anlegt).

| Gate | Befehl (Kern) | Exit | Ergebnis |
|------|---------------|------|----------|
| tests-unit | `test-without-building -only-testing:ShipTripTests` | **0** | 305 passed / 0 failed / 0 skipped |
| tests-ui | `test-without-building -only-testing:ShipTripUITests` | **65** | 14 passed / **9 failed** / 1 skipped (XCTSkip: Build19-Migrations-Smoke) |
| ui-proof-kalenderdialog | `-only-testing:…/ZZReleaseGateCalendarMigrationUITests` | **0** | 3 Zustände belegt, zweimal unabhängig reproduziert |
| release-build | `xcodebuild build -configuration Release -sdk iphonesimulator` | **0** | 0 Fehler |

**Abweichung vom Kanon** (`swift-standards/assets/gates.yaml`, Gate `tests`):
statt `xcodebuild test -scheme ShipTrip` wurde `test-without-building -xctestrun`
verwendet. Grund: `-scheme` läuft in diesem Projekt reproduzierbar in den
LLDB-VersionStore-Hänger. Kein Weichspüler — der Testumfang ist identisch
(volle Suite, nichts ausgeblendet), nur der Aufrufweg unterscheidet sich.
Statischer Pass `guard.py sizes`: exit 1 nur wegen `SettingsView.swift`
(987 Zeilen) — vorbestehend, bereits als F10 im Backlog.

Die 9 roten UI-Tests namentlich (alle `HauptansichtScreenshotTests`):
`testScreenshot_Light`, `testScreenshot_Dark`, `testScreenshot_DetailPins_Light`,
`testScreenshot_DetailPins_Dark`, `testScreenshot_GeoHero_Light`,
`testScreenshot_GeoHero_Dark`, `testScreenshot_MapAllTrips_Light`,
`testScreenshot_MapAllTrips_Dark`, `testScreenshot_HeroPhotoClean`.

## UI-Durchklick-Beweis (Teil B)

Aufbau: Wegwerf-Simulator, Kalender-Grant, zweiter beschreibbarer Kalender
„Release Gate B" (lokaler `EKCalendar`, aus dem Test-Runner angelegt), eine
**nicht-Demo**-Reise „Release Gate Reise / MS Beweis" über das echte
Reise-Formular angelegt (Demo-Reisen werden von `synchronize` per
`filter { !$0.isDemo }` ausgeschlossen, hätten also keine Termine erzeugt).
Ausgangskalender: „Kalender · Default".

| # | Zustand | Screenshot | Was auf dem Bild zu sehen ist (selbst angesehen) |
|---|---------|------------|---------------------------------------------------|
| 1 | Bestätigungsdialog | `.planning/screenshots-build23/01-dialog-bestaetigung.png` | Titel „Termine in den neuen Kalender übertragen?", Text „Alle bestehenden ShipTrip-Termine werden im neuen Kalender angelegt und im bisherigen Kalender gelöscht.", Buttons „Abbrechen" / „Übertragen". Vollständig umgebrochen, nichts abgeschnitten, kein roher Lokalisierungs-Key, kein Platzhalter. |
| 2 | Nach „Abbrechen" | `.planning/screenshots-build23/02-nach-abbrechen.png` | Dialog weg, Zielkalender steht wieder auf **„Kalender · Default"** (nicht „Release Gate B"), Sync weiter an, Statuszeile unverändert. Kein erneut aufpoppender Dialog. |
| 3 | Nach „Übertragen" | `.planning/screenshots-build23/03-nach-uebertragen.png` | Statuszeile „1 Kalendereinträge in den neuen Kalender übertragen.", Zielkalender steht auf **„Release Gate B · Default"**. |

**Fachliche Gegenprobe am echten EventStore**
(`.planning/screenshots-build23/06-eventstore-nach-migration.txt`):
`ShipTrip-Termine je Kalender: ["Release Gate B": 1]` — genau ein Termin
(`shiptrip://calendar/cruise/…/trip`), im neuen Kalender, **keiner** im alten.
Damit ist Success-Kriterium 3 aus `ZIEL.md` erstmals laufzeitbelegt statt
nur unit-getestet.

**Nebenbefund, der ein Backlog-Item schließt:** Der Zielkalender-Picker ist ein
**Menü**-Picker (`Button, label: 'Kalender, Kalender · Default'`), kein
gepushter Navigations-Picker. Die Sorge aus Backlog-F06 („Alert über gepushtem
Form-Picker nicht durchgeklickt") ist damit empirisch erledigt: Es gibt keinen
Push, der Alert legt sich korrekt über das Form.

**Sichtbestätigung eines bekannten Backlog-Items (kein neues Finding):** Der
Plural-Mangel aus F07 ist auf allen drei Screenshots als „**1** Kalendereinträge
…" zu sehen — die Testerin wird das lesen.

### Wie der Beweis entstanden (Transparenz)

Für den Durchklick war eine XCUITest-Datei nötig; ein Flutter-artiges Treiben von
außen (`simctl`/AppleScript) gibt es für SwiftUI nicht. Dafür wurde temporär
`ShipTripUITests/ZZReleaseGateCalendarMigrationUITests.swift` angelegt (das
Projekt nutzt `PBXFileSystemSynchronizedRootGroup`, also **ohne**
`project.pbxproj`-Änderung), der Lauf gefahren und die Datei danach wieder
entfernt. Kein Produktionscode angefasst, kein Commit, Working Tree danach
verifiziert identisch zum Ausgangsstand. Konsequenz: Das Gate
`ui-proof-kalenderdialog` im `gate-run.json` ist **einmalig** und auf dem
ausgelieferten Baum nicht reproduzierbar — die Screenshots und die
EventStore-Gegenprobe sind der bleibende Beweis. Will das Projekt das dauerhaft,
muss der Test bewusst eingecheckt werden (siehe F17-Fix-Vorschlag).

## Release-Tauglichkeit (Teil C)

- **Release-Build**: `xcodebuild build -configuration Release -sdk iphonesimulator`
  → exit 0, 0 Fehler. Zwei Warnungen, beide unkritisch und eine davon vorbestehend
  (`CruiseGeoFallbackView.swift:68` unbenutzter Wert; `SettingsView.swift:450`
  „result of 'try?' is unused" — das ist der bewusst stumme Restore aus F12).
- **`#if DEBUG`-Isolation verifiziert**: `nm` auf dem Release-Binary findet
  **0** `DemoDataService`-Symbole, `strings` **0** Treffer auf `demo_port`.
  Der neue `import UIKit` und `demoPortMoments` erzeugen keinen Release-Fehler.
- **L10n DE+EN vollständig**: `Localizable.xcstrings`, `sourceLanguage: de`,
  324 Keys. 0 Keys ohne `en`-Localization, **0** `state: new`. Die vier neuen
  Strings (Dialogtitel, Dialogtext, „Übertragen", Erfolgsmeldung `%lld …`) liegen
  alle mit `state: translated` auf EN vor.
- **Demo-Assets**: die 5 neuen Imagesets sind syntaktisch valide (JPG + 1x-Slot,
  2x/3x leer) und laden zur Laufzeit (Unit-Test `seedsCuratedPortMoments` grün).

## Findings

| ID | Sev | Blocker | File:Line | Kategorie | Titel |
|----|-----|---------|-----------|-----------|-------|
| R1 | — | Upload-Voraussetzung | `ShipTrip.xcodeproj/project.pbxproj:396,439` | release | `CURRENT_PROJECT_VERSION = 22` — Build 22 liegt schon auf TestFlight |
| F17 | major | nein | `ShipTripUITests/HauptansichtScreenshotTests.swift:16` | tests | Hartkodierter fremder Home-Pfad legt 9 von 24 UI-Tests lahm |
| F18 | minor | nein | `ShipTrip/Assets.xcassets/demo_port_*.imageset` | build | 5 Debug-only Demo-Bilder liegen im Release-`Assets.car` |

### R1 — Version-Bump fehlt (gehört dem Release-Schritt, nicht der Fix-Schleife)
`MARKETING_VERSION = 1.7.0`, `CURRENT_PROJECT_VERSION = 22`. Build 22 ist bereits
hochgeladen (`docs/features/testflight-cover-hotfix-build-22.md`, Commit
`52b22a9` „docs: record TestFlight build 22 status"). App Store Connect weist
einen zweiten Upload mit `1.7.0 (22)` ab. **Kein Code-Blocker** und deshalb kein
Grund, das Gate rot zu drehen — aber der Upload scheitert, wenn der
Release-Schritt nicht vorher auf `23` bumpt und einen CHANGELOG-Eintrag für
Build 23 setzt (bisher endet der Changelog bei Build 22). Zuständig: golive.

### F17 — Hartkodierter Home-Pfad in den Screenshot-Tests
`private let outputDir = URL(filePath: "/Users/andreja/Documents/0.Projekte/ShipTrip/audit/screenshots")`
Auf dieser Maschine (`/Users/andre-studio/…`) scheitern deshalb alle 9 Tests der
Klasse mit `NSCocoaErrorDomain 513` („keine Zugriffsrechte"). Vorbestehend
(unverändert seit Commit `2234878`), **nicht** von diesem Diff verursacht — die
Datei steht nicht im Diff, und `audit/screenshots/*.png` sind durch meine Läufe
nachweislich unverändert geblieben (Hash-Vergleich vor/nach).
Warum es trotzdem `major` ist: Solange diese Klasse mitläuft, kann „volle Suite
grün" als Release-Kriterium nie erfüllt werden — das Gate ist strukturell blind,
und echte künftige UI-Regressionen gehen im Rauschen der 9 Dauerfehler unter.
**Fix**: Ausgabeordner aus einer Umgebungsvariablen lesen und ohne sie
`throw XCTSkip("SHIPTRIP_SCREENSHOT_DIR nicht gesetzt")`, z. B.
```swift
guard let dir = ProcessInfo.processInfo.environment["SHIPTRIP_SCREENSHOT_DIR"] else {
    throw XCTSkip("SHIPTRIP_SCREENSHOT_DIR nicht gesetzt — Screenshot-Generator übersprungen")
}
let outputDir = URL(filePath: dir)
```
Dann ist die Suite grün-fähig und der Screenshot-Generator bleibt auf Zuruf
nutzbar. Gleicher Anlass wäre der richtige Moment, den Kalenderdialog-Durchklick
als dauerhaften Test einzuchecken.

### F18 — Debug-Assets im Release-Bundle
`assetutil --info` auf dem Release-`Assets.car` listet alle fünf
`demo_port_*`-Assets. `DemoDataService` ist per `#if DEBUG` heraus, der
Asset-Katalog kennt diese Unterscheidung aber nicht — rund 1,5 MB reine
Debug-Nutzlast in einem 76-MB-`Assets.car` (≈2 %). Kein Funktionsproblem.
**Fix** (wenn überhaupt): eigener, nur dem Debug-Target zugeordneter
Asset-Katalog, oder bewusst akzeptieren und hier dokumentiert lassen.

## Simulator- und Cleanup-Beleg

Wegwerf-Simulator selbst erzeugt (`simctl create "ci-release-gate"`), nie ein
fremder übernommen. Nach dem Lauf: `xcodebuild clean`,
`rm -rf ~/Library/Developer/Xcode/DerivedData/ShipTrip-*`,
`xcrun simctl --set testing delete all`, Simulator gelöscht;
`simctl list devices | grep -c ci-release-gate` = 0. Screenshots bewusst
**nicht** gelöscht — sie sind das Deliverable.
