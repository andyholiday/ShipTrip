# Review — B5: Onboarding-UI-Tests + Kompat-Naht (Run 1.8.0)

- **Iteration**: 1 / 3
- **Reviewer**: quality-agent (statischer Pass, kein Build/Testlauf — Re-Run laeuft parallel)
- **Datum**: 2026-08-24
- **Gegenstand**: Worktree `/Users/andre-studio/Documents/0.Projekte/ShipTrip-worktrees/b5/`, Diff `e029023..a067fff`
- **Verdikt**: request-changes (1 Blocker fuer B5) — Produkt-Go-Live unberuehrt
- **Stats**: critical: 0, major: 1, minor: 5 — Blocker: 1, Backlog: 5

## Summary

Die DEBUG-Naht in `ShipTripApp` ist sauber gekapselt, korrekt platziert und mit der
richtigen Begruendung gebaut (UserDefaults statt NSArgumentDomain). Die Kompat-Verdrahtung
in den 11 Bestands-Klassen ist vollstaendig und semantisch neutral. Der Scroll-Helper in
`HauptansichtScreenshotTests` ist fuer beide Store-Zustaende korrekt.

Ein Befund traegt Gewicht: der in `a067fff` neu gesetzte Anker `"Keine Kreuzfahrten"` ist
der **Empty-State** der Reise-Liste und existiert nur bei leerem Store. In der
alphabetischen XCTest-Reihenfolge laufen vor `OnboardingUITests` mehrere Klassen mit
`-uiTestingResetAndLoadDemoData`, die den **persistenten** Store fuellen. Der Anker-Fix
hat damit eine Abhaengigkeit gegen eine andere getauscht.

## Findings

| ID  | Severity | Blocker | File:Line | Kategorie | Titel |
|-----|----------|---------|-----------|-----------|-------|
| F01 | major | ja (fuer B5) | ShipTripUITests/OnboardingUITests.swift:34,96-100 | tests | Empty-State-Anker macht alle 3 Onboarding-Tests reihenfolgeabhaengig |
| F02 | minor | nein | ShipTripUITests/OnboardingUITests.swift:152-159 | tests | Negativ-Asserts auf Nachbarkarten sind eine Wette auf das TabView-Paging |
| F03 | minor | nein | ShipTripUITests/OnboardingUITests.swift:104-106,130-133 | tests | Springboard-Check ohne Wartezeit — nicht tragend |
| F04 | minor | nein | ShipTripUITests/OnboardingUITests.swift:174 | tests | Ungeschuetzter Tap, inkonsistent zum Rest der Datei |
| F05 | minor | nein | ShipTrip/ShipTripApp.swift:91-95 | design | Kompat-Naht schreibt dauerhaft — Onboarding bleibt nach jedem UI-Lauf weg |
| F06 | minor | nein | ShipTripUITests/HauptansichtScreenshotTests.swift:83-88 | tests | Nach dem Entfernen wird ohne Neu-Scrollen getippt |

---

### F01 — Empty-State-Anker macht die Onboarding-Tests reihenfolgeabhaengig

- **File**: `ShipTripUITests/OnboardingUITests.swift:34` (`mainListAnchor`), Nutzung in `:96-100`, `:88`, `:187`
- **Severity**: major · **Blocker fuer B5: ja** (der Test *ist* das Deliverable) · Produkt-Go-Live: nein
- **Problem**: `"Keine Kreuzfahrten"` steht in `CruiseListView.swift:280-293` und wird nur
  im Zweig `cruises.isEmpty` gerendert (`CruiseListView.swift:92-94`). Der Store ist
  **persistent** (`ShipTripCloudSync.persistentConfiguration`, `isStoredInMemoryOnly: false`).
  `OnboardingUITests` startet nur mit `-uiTestingResetOnboarding` und setzt den Store
  **nicht** zurueck. XCTest fuehrt Klassen alphabetisch aus (kein Random-Ordering im
  `ShipTrip.xctestplan`, keine Reinstallation zwischen Klassen); direkt davor liegen u. a.
  `MapAlleRoutenUITests` und `HauptansichtScreenshotTests`, die per
  `-uiTestingResetAndLoadDemoData` Demo-Reisen anlegen. Im Bundle-Lauf ist der Store
  also gefuellt → Empty-State fehlt → `finishOnStartCardAndAssertMainList` schlaegt in
  allen drei Tests fehl.
  Zweitfaktor: ohne `-uiTestingResetAndLoadDemoData` laeuft die App in diesen Tests gegen
  den **CloudKit-gestuetzten** Store (`ShipTripCloudSync.swift:17-20` schaltet CloudKit nur
  bei genau diesem Argument bzw. `XCTestConfigurationFilePath` ab — letzteres steht im
  UI-Test-Runner, nicht im App-Prozess). Ein Sync-Treffer fuellt den Store ebenfalls.
- **Falsifizierbare Vorhersage**: im vollstaendigen Bundle-Lauf sind die drei
  Onboarding-Tests rot; einzeln (`-only-testing:ShipTripUITests/OnboardingUITests`) auf
  frischer Installation gruen. Genau das der Re-Run-Ausgabe gegenpruefen.
- **Fix (bevorzugt)**: store-unabhaengigen Anker nehmen. Die Tab-Leiste existiert in beiden
  Zweigen und ist unter dem `fullScreenCover` nicht erreichbar:
  ```swift
  private func mainListElement(in app: XCUIApplication) -> XCUIElement {
      app.tabBars.buttons["Reisen"]
  }
  ```
  Die bereits vorhandene Assertion „Cover-Text ist weg" (`:83-86`) bleibt und traegt
  weiterhin den eigentlichen Beweis.
- **Fix (Alternative, minimal)**: Praedikat ueber beide Zweige:
  `label CONTAINS 'Keine Kreuzfahrten' OR label CONTAINS 'Meine Reisen'`.

### F02 — Negativ-Asserts auf Nachbarkarten sind eine Wette auf das TabView-Paging

- **File**: `ShipTripUITests/OnboardingUITests.swift:152-159`
- **Severity**: minor · Blocker: nein
- **Problem**: `OnboardingFlowView` baut alle vier Seiten in einem `ForEach` (`:29-34`).
  Ob SwiftUI die Nachbarseite eines `.page`-`TabView` im Accessibility-Baum haelt, ist
  nicht garantiert. Nach dem Sprung auf Index 3 kann Karte 3 (`Card.softAsk`, Nachbar)
  durchaus existieren → **falsch rot**, nicht falsch gruen. Dieselbe Annahme traegt
  `tapWeiter` (`:70-73`) — dort tut sie echte Arbeit (die „Weiter"-Taste ist auf Karte 1
  und 2 gleich beschriftet, `.firstMatch` braucht die Disambiguierung), hier nicht.
- **Fix**: die beiden Asserts streichen; der Beweis fuer den Skip liegt bereits in
  „Karte 4 steht sofort da" (`:151`) plus „Skip-Taste ist weg" (`:160-163`) — und die
  Sprungsemantik selbst ist in `ShipTripTests/OnboardingModelTests.swift:135-145` sauber
  unit-getestet.

### F03 — Springboard-Check ohne Wartezeit

- **File**: `ShipTripUITests/OnboardingUITests.swift:104-106`, Nutzung `:130-133`
- **Severity**: minor · Blocker: nein
- **Problem**: `alerts.firstMatch.exists` ohne Wartefenster. Ein Systemdialog erscheint
  asynchron; die Negativ-Assertion kann gruen sein, waehrend der Dialog gerade kommt.
  Sie erzeugt mehr Vertrauen, als sie deckt.
- **Fix**: entweder als das kennzeichnen, was sie ist (Kommentar: „Sichtpruefung,
  die harte Zusage traegt `OnboardingModelTests.skippingTheWholeFlowNeverRequestsPermission`"),
  oder ein kurzes `waitForExistence(timeout: 2)` invertieren. Kein Fix-Auftrag noetig.

### F04 — Ungeschuetzter Tap

- **File**: `ShipTripUITests/OnboardingUITests.swift:174`
- **Severity**: minor · Blocker: nein
- **Problem**: `app.buttons["Überspringen"].firstMatch.tap()` ohne `waitForExistence` —
  einzige Stelle der Datei ohne Guard. Fehlt die Taste, ist der Fehler „no matches found"
  statt der sprechenden Meldung aus `:146`.
- **Fix**: Skip-Tap als kleinen Helfer ziehen und in Test 2 und 3 gleich verwenden.

### F05 — Kompat-Naht schreibt dauerhaft

- **File**: `ShipTrip/ShipTripApp.swift:91-95`
- **Severity**: minor · Blocker: nein
- **Problem**: `UserDefaults.standard.set(true, ...)` bleibt nach dem Testlauf stehen.
  Wer danach den DEBUG-Build von Hand startet, sieht das Onboarding nie wieder (nur
  ueber „Intro erneut zeigen"). Die Begruendung gegen NSArgumentDomain im Doc-Kommentar
  ist korrekt — dort haette die Argument-Domain jeden spaeteren Schreibvorgang
  ueberschattet und sowohl den Reset-Test als auch „Intro erneut zeigen" gebrochen. Der
  gewaehlte Weg ist der richtige; nur die Nebenwirkung gehoert notiert.
- **Fix**: keiner noetig. Ein Satz im Doc-Kommentar („der Schalter bleibt nach dem Lauf
  gesetzt") genuegt.

### F06 — Nach dem Entfernen ohne Neu-Scrollen getippt

- **File**: `ShipTripUITests/HauptansichtScreenshotTests.swift:83-88`
- **Severity**: minor · Blocker: nein
- **Problem**: Nach `removeButton.tap()` prueft der Test `loadButton.waitForExistence` und
  tippt. `waitForExistence` deckt Existenz, nicht Trefferbarkeit; der alte Code wischte
  hier bewusst nach. Die Annahme „die Sektion tauscht die Taste an Ort und Stelle" ist
  plausibel (Einstellungs-Zeilen sind statisch), aber ungeprueft.
- **Fix**: `XCTAssertTrue(scrollUntilVisible([loadButton], in: app), ...)` statt
  `waitForExistence` — der Helfer existiert bereits und kostet nichts.

---

## Urteile je Pruefpunkt

**1. DEBUG-Naehte — bestanden.** Aufruf (`ShipTripApp.swift:23-26`) und beide Funktionen
(`:74-95`) liegen vollstaendig in `#if DEBUG`; im Release-Build existiert kein Symbol und
kein Aufruf. Die Reihenfolge stimmt: beide laufen im `init()` der App, also bevor SwiftUI
`body` auswertet und `@AppStorage(hasCompletedKey)` (`:118`) liest — `AppStorage` liest
lazy beim Zugriff aus dem Store, nicht beim Property-Init. B2-Invariante unangetastet:
`fullScreenCover` haengt weiterhin am montierten `MainTabView` (`:133-139`),
`CruiseListView.task` (`CruiseListView.swift:119-124`) ist nicht beruehrt.

**2. Testqualitaet — bestanden mit Auflage.** Die drei Tests pruefen echtes Verhalten:
Test 1 laeuft alle vier Karten mit realen Taps, Test 2 prueft den Sprung inkl. Verschwinden
der Skip-Taste, Test 3 nutzt Reset → Abschluss → Neustart **ohne** Argument und schliesst
damit die Falsch-Gruen-Luecke „ein Vorlaeufertest hat das Flag schon gesetzt" korrekt.
Kein Falsch-Gruen gefunden. Warte-Muster (10 s, 15 s beim Relaunch) sind konsistent mit
der Bestands-Suite; kein `sleep`. Anker-Stabilitaet: `ContainsPredicate` ist als Technik
richtig gewaehlt (`ContentUnavailableView` kann zusammengefasst werden), aber der
**Anker-Wert** ist es nicht → F01. `descendants(matching: .any)` ist breit, mit
`.firstMatch` aber vertretbar.

**3. Skip-Semantik — kein Widerspruch, weil keine Spec existiert.** Weder
`docs/design/design-spec-onboarding.md` noch ein anderer Onboarding-Spec-Text liegt im
Baum. Die einzige schriftliche Zusage ist `.planning/TASKPLAN-1.8.0.md:48` — B2 verlangt
„ueberspringbar", ohne Ziel. Gebaut ist: Sprung auf Karte 4 (`OnboardingModel.swift:109-112`),
Skip-Taste dort ausgeblendet (`:114-117`), unit-getestet in
`ShipTripTests/OnboardingModelTests.swift:135-145`. Der Test bildet exakt das gebaute
Verhalten ab und benennt es im Kommentar (`OnboardingUITests.swift:149-150`) — kein
stiller Widerspruch, keine Testluege. **Produkt-Einordnung, kein Fix**: „Ueberspringen"
heisst in iOS-Konvention „raus aus dem Flow"; hier kostet es zwei Taps. Das ist eine
vertretbare Entscheidung (der Erststart soll nicht ohne Startentscheidung enden — so
begruendet in `OnboardingModel.swift:102-103`), aber sie ist nirgends als Produktentscheid
festgehalten. Empfehlung an Winston: einen Satz in den Taskplan, nicht in den Code.

**4. Kompat-Verdrahtung — bestanden.** 22 `launch()`-Stellen in 12 Klassen; 20 tragen
`-uiTestingCompleteOnboarding`, die zwei uebrigen sind die beiden bewussten Ausnahmen in
`OnboardingUITests` (Reset-Start und der argumentlose Relaunch). Kein Launch-Site
uebersehen. Das Argument steht **ueberall am Array-Ende**; damit bleiben die
NSArgumentDomain-Paare unversehrt: `-colorScheme <suffix>`
(`HauptansichtScreenshotTests.swift:117-121` u. a., gelesen via
`@AppStorage("colorScheme")` in `MainTabView.swift:13`) und `-AppleLanguages (en)` /
`-AppleLocale en_US` (`EnglishLocalizationSmokeUITests.swift:57-62`). Nebeneffekt ohne
Wirkung: `-uiTestingResetAndLoadDemoData` bekommt in der Argument-Domain jetzt den Wert
`"-uiTestingCompleteOnboarding"` — das Flag wird ausschliesslich ueber
`ProcessInfo.arguments` gelesen (`ShipTripApp.swift:98`, `ShipTripCloudSync.swift:18`),
nie ueber `UserDefaults`. Keine Semantik-Aenderung an Bestands-Tests.

**5. Scroll-Helper — bestanden.** `scrollUntilVisible`
(`HauptansichtScreenshotTests.swift:315-329`) ist fuer beide Store-Zustaende korrekt: es
wartet auf **eines** der beiden Elemente, und der nachfolgende
`if removeButton.isHittable` waehlt den richtigen Zweig (gefuellt → entfernen,
leer → direkt laden). Der `maxSwipes`-Abbruch liefert `false` und damit die sprechende
Assertion in `:86-87` statt einer Endlosschleife. Kleiner Rest: F06.

**6. Scope-Hygiene — bestanden.** 13 Dateien: 12 × `ShipTripUITests/*`, 1 × die App-Datei
(nur die Naehte). `ShipTrip/Localizable.xcstrings` ist nicht im Diff, keine neuen
user-sichtbaren Strings — korrekt, die Tests greifen auf bestehende DE-Literale. Kein
`project.pbxproj` im Diff und keins noetig: das Projekt nutzt
`PBXFileSystemSynchronizedRootGroup`, die neue Testdatei ist automatisch Target-Mitglied
(kein stilles Nicht-Kompilieren).

**7. Dateigroessen — bestanden.** `guard.py sizes --files <13 geaenderte Dateien>` →
`sizes: ok (13 geprueft, 0 Soft-Warnungen)`, exit 0.

**8. Testumfangs-Deckel — bestanden.** 195 Zeilen Test fuer drei Tests, 28 Zeilen
Produktions-Naht. Kein Assertions-Teppich, keine Snapshot-Attrappe, jede Assertion traegt
eine eigene Aussage. Der dritte Test (Persistenz) geht ueber den Wortlaut von B5
(„Durchlauf + Skip") hinaus, deckt aber die Kernzusage von B2 zum Preis von acht Zeilen —
angemessen, kein Ueberbau.

## Test-Run-Status

Statischer Pass laut Auftrag — **kein Build, kein Testlauf, kein Simulator** durch diesen
Reviewer. Kein `evidence_path` aus diesem Spawn. Das Go/No-Go stuetzt sich auf das
`gate-run.json` des parallel laufenden Re-Run-Spawns.

## Empfehlung

**No-Go fuer den B5-Merge, bedingt.** F01 zuerst pruefen: liefert der parallele Re-Run die
drei Onboarding-Tests im **Bundle-Lauf** gruen, ist meine Analyse widerlegt und F01 faellt
auf minor („Anker haengt am Store-Zustand, heute zufaellig erfuellt") — dann Go. Sind sie
rot oder lief der Re-Run nur klassenweise isoliert, ist F01 zu fixen (ein Helfer, drei
Zeilen) und ein Bundle-Lauf nachzuziehen.

F02–F06 sind Backlog, kein Fix-Auftrag in diesem Run.
