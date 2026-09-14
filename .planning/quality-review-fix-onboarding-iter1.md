# Review — Fix-Runde Onboarding (Beispielreise-CTA + App-Reset)

- **Iteration**: 1 / 3
- **Reviewer**: quality-agent (statisch, kein eigener Lauf — Regression parallel)
- **Datum**: 2026-08-24
- **Prüfgegenstand**: Worktree `ShipTrip-worktrees/fix-onboarding`, Diff `b5e4838..b0ec375`
  (Rot-Commit `8f6e00d`, Fix-Commit `b0ec375`) — 5 Dateien, +288/−6
- **Verdikt**: **approve / GO**
- **Stats**: critical 0, major 1, minor 5 — Blocker: **0**, Backlog: 6

## Summary

Der Root-Cause ist richtig getroffen und der Fix ist die minimal mögliche Änderung
(eine Modifier-Position). Beide Präsentationen in `ShipTripApp` liegen jetzt
innerhalb des Containers; nichts verliert Environment. Das neue Feature
„App zurücksetzen" nutzt den bestehenden Lösch-Pfad, die bestehende Sperre und
die bestehende Replay-Naht — keine neue Mechanik, kein erreichbarer
Halb-Zustand. L10n ist rein additiv und gate-grün.

Ein echtes Finding: der Regressions-Test für den Beispielreise-CTA ist im
Voll-Suite-Lauf nicht rot-fähig (F01). Der Rot-Beweis selbst ist gültig — er lief
isoliert per `-only-testing`. Kein Go-Live-Blocker, aber der Wächter hält nicht.

## Antworten auf die Prüffragen

**1) Bekommen jetzt alle Präsentationen den echten Container?** Ja. Im Scene-Body
existieren genau zwei Präsentationen — `.fullScreenCover` (`ShipTripApp.swift:191-197`)
und die Datenverlust-`.alert` (`:198-217`); beide stehen im Quelltext **über**
`.modelContainer(container)` (`:223`), sind damit **innerhalb** des Containers.
`grep` über `ShipTrip/` findet genau **einen** produktiven `.modelContainer`-Aufruf
(`:223`); die 25 weiteren `.sheet`/`.fullScreenCover`-Stellen sitzen im Teilbaum von
`MainTabView` und erben ohnehin. Es hängt keine Präsentation mehr über dem Container.

**2) Verliert MainTabView etwas?** Nein — der neue Zustand ist eine echte Obermenge.
`V.m1().m2()` heißt: `m2` umschließt das Ergebnis von `m1`. Environment fließt von
außen nach innen, also sind die Environment-Schreibvorgänge des **äußeren**
Modifiers auch für den vom inneren Modifier präsentierten Inhalt Vorfahre.
Vorher war `.modelContainer` innerster Modifier → nur `MainTabView` sah ihn;
jetzt ist er äußerster → `MainTabView` **plus** Cover **plus** Alert.
Verifiziert gegen aktuelle Doku (context7 `/websites/developer_apple_swiftdata`,
`developer.apple.com/documentation/swiftdata/preserving-your-apps-model-data-across-launches`):
„Use the `modelContainer` view modifier **at the top of your SwiftUI view hierarchy**"
bzw. „to ensure that all child views share the same container". Kein Trainings-Rateschluss.

**3) Soft-Ask-Reconcile konsistent zu den Gate-3-Fixes?** Ja, und vom Diff
unberührt. `OnboardingModel` ist `@MainActor` (`OnboardingModel.swift:96`),
`enableReminders(in:)` (`:193-202`) hat den In-Flight-Guard unverändert
(`guard !isRequestingPermission` + `defer`), die Naht ist
`@MainActor (ModelContext) async -> Void` (`:126`) — es wandert kein `@Model` über
eine Aktorgrenze. Der Fix heilt nur, **welcher** Kontext ankommt, nicht die Form.

**4) `resetApp()`.** Dreiwertiger Schalter: `requestReplay` setzt `false` statt zu
entfernen (`OnboardingModel.swift:48-50`) — korrekt. `startupDecision` (`:81-90`)
migriert still **nur** bei `hasCompletedFlag == nil`; ein entfernter Schlüssel mit
Bestandsreisen wäre beim nächsten Start stumm abgehakt worden. `false` + gesunder
Store ⇒ `.present`. Exakt derselbe Pfad wie „Intro erneut zeigen"
(`SettingsView.swift:186`).
**Race:** keiner. `resetApp` (`SettingsView.swift:1080-1083`) läuft synchron auf dem
MainActor in der Alert-Aktion; `deleteAllData` committet `try modelContext.save()`
und erst **danach** kippt der Schalter. Das Cover kann nicht während der
Lösch-Transaktion erscheinen.
**Gegenseitige Sperre:** greift — `.disabled(Self.isDataActionBlocked(isExporting:isImporting:))`
am neuen Button (`SettingsView.swift:867`), identisch zu Export/Import/Löschen.
Export/Import sind async, der Reset-Pfad synchron auf dem MainActor → kein Interleaving.

**5) `@discardableResult -> Bool` und alle Aufrufstellen.** Drei Aufrufstellen:
`SettingsView.swift:878`, `:894`, `:897` (alt, Wert bewusst verworfen — sie zeigen
den Fehler bereits selbst über `alertMessage`/`showingAlert`, Verhalten unverändert)
und `:1081` (neu, wertet aus). Der gefürchtete Zustand „halb gelöscht + Onboarding
zurückgesetzt" ist **nicht erreichbar**: im Fehlerzweig macht `modelContext.rollback()`
(`:1057`) die gestageten Deletes rückgängig, `false` kommt zurück, und
`guard … else { return }` verhindert den Schalter-Schreibvorgang.

**6) Gemini-API-Key bleibt in der Keychain** (`alsoDeleteApiKey: false`,
`SettingsView.swift:1081`) — bewusste Entscheidung, im Section-Footer (`:864`)
für den Nutzer erklärt und auf „Alle Daten löschen" verwiesen. **Produktentscheid
für Andre**, kein Fix-Auftrag (F04).

**7) `guard.py sizes`** über die vier geänderten Swift-Dateien: **exit 1** —
`SettingsView.swift` 1106 Zeilen (> 500 hart). Vorbestehend (1067 vor dem Diff,
+39 durch diese Änderung), Backlog-Zeilen existieren bereits. Die drei anderen
Dateien liegen unter dem Limit. → F05.

**L10n (Katalog gesperrt).** Rein additiv: 5 neue Schlüssel, **kein** bestehender
Eintrag geändert oder entfernt (`git diff` zeigt nur `+`-Blöcke). JSON valide,
401 Schlüssel, `sourceLanguage: de`, alle 5 mit `en`-`stringUnit`
(`state: translated`). `python3 scripts/check-l10n.py` → **exit 0**
(„L10n-Gate ok: 1 Katalog(e) vollständig für en"). Sortierposition entspricht der
Xcode-Ordnung. Neue Dateien brauchen keinen pbxproj-Eintrag — das Projekt nutzt
`PBXFileSystemSynchronizedRootGroup` (5×).

**Entwickler-Evidenz geprüft** (`.winston-evidence/`, 5 `gate-run.json`):
`20260824T180113Z` commit `b5e4838` — `repro-rot` **exit 65** (echter Rot-Beweis,
Vor-Fix-Quellstand); `20260824T181420Z` — `repro-gruen` 0, `feature-app-reset` 0,
`unit-smoke` 0, `l10n` 0, `status: verified`. Zwei Zwischenläufe waren rot und sind
erklärbar: `180922Z` scheiterte an der Navigations-Hilfe in `AppResetUITests`
(„Daten verwalten" nicht gefunden → daraufhin `scrollUntilHittable` eingebaut),
`181248Z` an EventKit-`.notAuthorized` in `CalendarSyncServiceMigrationTests`
(Umgebung, nicht Diff → F06). Alle Kommandos sind echte `xcodebuild test`-Läufe
mit `-only-testing`-Scoping — keine Weichspüler.

## Findings

| ID  | Severity | Blocker | Datei:Zeile                                       | Kategorie | Titel |
|-----|----------|---------|---------------------------------------------------|-----------|-------|
| F01 | major    | nein    | `ShipTripUITests/OnboardingSampleTripUITests.swift:39,64` | tests | Regressionstest im Voll-Suite-Lauf nicht rot-fähig |
| F02 | minor    | nein    | `ShipTrip/ShipTripApp.swift:223`                  | robustheit | Korrektheit hängt an Modifier-Position, nicht an der Struktur |
| F03 | minor    | nein    | `ShipTrip/Views/Settings/SettingsView.swift:864`  | produkt | „App zurücksetzen" lässt App-Einstellungen stehen |
| F04 | minor    | nein    | `ShipTrip/Views/Settings/SettingsView.swift:1081` | produkt | Gemini-API-Key überlebt den Reset (Entscheid) |
| F05 | minor    | nein    | `ShipTrip/Views/Settings/SettingsView.swift:1`    | struktur | 1106 Zeilen über Hard-Limit (vorbestehend, +39) |
| F06 | minor    | nein    | `ShipTripTests/CalendarSyncServiceMigrationTests.swift:20,38,53,69` | tests | 4 Tests hängen an EventKit-Berechtigung des Simulators |

### F01 — Regressionstest im Voll-Suite-Lauf nicht rot-fähig
- **Datei**: `ShipTripUITests/OnboardingSampleTripUITests.swift:39` (Launch-Argumente), `:64-67` (Assertion)
- **Severity**: major · **Blocker**: nein
- **Problem**: Der Test startet nur mit `-uiTestingResetOnboarding`. Diese DEBUG-Naht
  (`ShipTripApp.swift:136-139`) entfernt **ausschließlich** den UserDefaults-Schlüssel —
  der SwiftData-Store bleibt unberührt. XCTest installiert die App pro Lauf einmal;
  alle UI-Test-Klassen teilen sich denselben App-Container. Alphabetisch frühere
  Klassen (`AusflugLoeschenUITests`, `CruiseLoeschenFilterUITests`,
  `MapAlleRoutenUITests`, `HauptansichtScreenshotTests` …) laufen mit
  `-uiTestingResetAndLoadDemoData` und hinterlassen genau die Reise
  „Norwegische Fjorde" im Store. Die Assertion
  `app.staticTexts["Norwegische Fjorde"].waitForExistence` wäre dann **auch ohne den
  Fix grün**. Der Rot-Beweis (`.winston-evidence/20260824T180113Z`, exit 65) ist
  gültig, weil er isoliert per `-only-testing` lief — als Dauer-Wächter im
  Voll-Suite-Lauf taugt der Test in dieser Form nicht.
  (Die verwandte `.migrateSilently`-Falle ist bereits entschärft:
  `hasExistingCruises` gibt unter `-uiTestingResetOnboarding` hart `false` zurück,
  `ShipTripApp.swift:110-115`.)
- **Fix**: DEBUG-Naht für einen garantiert leeren Store ergänzen und im Test mitgeben.
  In `DemoDataService` (analog `resetAndLoadDemoDataForUITesting`,
  `DemoDataService.swift:52-64`) eine `resetStoreForUITesting(in:)` ohne den
  abschließenden `loadDemoData(into:)` herausziehen; in
  `ShipTripApp.prepareUITestDataIfNeeded` (`:154`) unter
  `-uiTestingEmptyStore` aufrufen; in `OnboardingSampleTripUITests.swift:39`
  `app.launchArguments += ["-uiTestingResetOnboarding", "-uiTestingEmptyStore"]`.

### F02 — Korrektheit hängt an der Modifier-Position
- **Datei**: `ShipTrip/ShipTripApp.swift:223`
- **Severity**: minor · **Blocker**: nein
- **Problem**: Der Fix ist korrekt, aber die Invariante „`.modelContainer` ist der
  äußerste Modifier" ist nur durch einen Kommentar (`:213-222`) geschützt. Der
  nächste Präsentations-Modifier, der unten angehängt wird, reißt exakt denselben
  Bug wieder auf — und der äußert sich still (kein Fehler, keine Daten).
- **Fix**: Container an die **Scene** hängen statt an den Inhalt, dann ist die
  Reihenfolge strukturell egal:
  `WindowGroup { if let container = modelContainer { MainTabView()… } else { StoreUnavailableView() } }`
  → die Verzweigung im Body behalten, aber die `if let`-Bindung nach oben ziehen und
  `.modelContainer(container)` an `WindowGroup` setzen (Scene-Overload). Alternativ
  minimal: Kommentar-Guard belassen und in `docs/adr/` eine Zeile dazu.

### F03 — „App zurücksetzen" lässt App-Einstellungen stehen
- **Datei**: `ShipTrip/Views/Settings/SettingsView.swift:864` (Footer), `:1080-1083`
- **Severity**: minor · **Blocker**: nein
- **Problem**: Der Reset löscht Daten + Erststart-Schalter. Erhalten bleiben:
  `colorScheme`, `notifyBeforeCruise`, `notifyOnCruiseDay`, `reminderDaysBefore`,
  `CalendarSyncPreferences` (`enabledKey`, `modeKey`, `calendarIdentifierKey`).
  Nach dem Reset ist der Kalender-Sync also weiter an und zeigt auf denselben
  Kalender. Der Button heißt „App zurücksetzen"; der Footer erklärt nur die
  Keychain-Ausnahme. Andres Wortlaut war „die app frisch".
  *Kein* Problem sind die Kalender-**Termine**: `CalendarSyncObserver`
  (`Views/CalendarSyncObserver.swift:29-32`) läuft nach dem Löschen erneut und
  `synchronize` entfernt verwaiste verwaltete Termine (`CalendarSyncService.swift:168-173`).
- **Fix (Produktentscheid nötig)**: entweder Footer präzisieren („Deine
  Anzeige-, Erinnerungs- und Kalender-Einstellungen bleiben erhalten.") oder
  die sieben Schlüssel in `resetApp()` mit zurücksetzen. Nicht selbst entschieden.

### F04 — Gemini-API-Key überlebt den Reset
- **Datei**: `ShipTrip/Views/Settings/SettingsView.swift:1081`
- **Severity**: minor · **Blocker**: nein
- **Problem/Entscheid**: `alsoDeleteApiKey: false` ist bewusst gesetzt und im Footer
  erklärt. Vertretbar (der Key ist Nutzer-Eigentum, nicht App-Daten), aber es ist ein
  **Produktentscheid für Andre**, kein Reviewer-Urteil. Kein Fix-Auftrag.

### F05 — SettingsView über Hard-Limit
- **Datei**: `ShipTrip/Views/Settings/SettingsView.swift:1`
- **Severity**: minor · **Blocker**: nein
- **Problem**: `guard.py sizes` exit 1 — 1106 Zeilen (Hard-Limit 500). Vorbestehend
  (1067), dieser Diff addiert 39. Backlog-Zeilen mit veralteten Zahlen existieren.
- **Fix**: `CalendarSyncSettingsView` und `DataManagementView` in eigene Dateien
  ziehen (getrennter Task, nicht in diesem Run).

### F06 — Kalender-Migrationstests hängen an der Simulator-Berechtigung
- **Datei**: `ShipTripTests/CalendarSyncServiceMigrationTests.swift:20,38,53,69`
- **Severity**: minor · **Blocker**: nein
- **Problem**: Im Evidenz-Lauf `20260824T181248Z` fielen vier Tests mit
  `Caught error: .notAuthorized`; im Wiederholungslauf `20260824T181420Z` grün.
  Die Tests hängen an der ambienten EventKit-Berechtigung des Simulators — auf einem
  frischen Wegwerf-Klon sind sie rot. Nicht aus diesem Diff.
- **Fix**: EventKit hinter eine injizierbare Naht legen (wie
  `requestNotificationPermission` in `OnboardingModel`) oder die Suite auf
  `.disabled("braucht Kalender-Berechtigung", …)` mit getaggter Begründung setzen.

## GDPR / Security

Nicht getriggert. Der Diff berührt keine neue Datenverarbeitung und keine neue
Angriffsfläche: keine Netzwerk-Pfade, keine neuen Persistenz-Ziele, keine
Berechtigungen. Der Reset ist ausschließlich **löschend** und nutzerinitiiert mit
Bestätigungs-Dialog; der einzige Keychain-Bezug ist eine bewusste Nicht-Löschung
(F04). Aus GDPR-Sicht ist die Ergänzung eher stärkend (zusätzlicher Erasure-Pfad,
Art. 17).

## Test-Status (aus Entwickler-Evidenz, kein eigener Lauf)

| Gate | Lauf | Exit |
|------|------|------|
| `repro-rot` (`OnboardingSampleTripUITests`, Vor-Fix) | `20260824T180113Z` | **65** (korrekt rot) |
| `repro-gruen` (`OnboardingSampleTripUITests`) | `20260824T181420Z` | 0 |
| `feature-app-reset` (`AppResetUITests`) | `20260824T181420Z` | 0 |
| `unit-smoke` (`ShipTripTests`, 361 Tests) | `20260824T181420Z` | 0 |
| `l10n` (`scripts/check-l10n.py`) | `20260824T181420Z` | 0 |
| `ui-regression` (`CruiseLoeschenFilter`, `OnboardingUITests`) | `20260824T182109Z` | 0 |
| `guard.py sizes` (eigener statischer Pass) | 2026-08-24 | 1 (F05, vorbestehend) |
| `check-l10n.py` (eigener statischer Pass) | 2026-08-24 | 0 |

Anmerkung: Alle Läufe nutzen dieselbe Simulator-UDID `29A6CCA8-…`; die Evidenz
belegt nicht, dass es ein eigener Wegwerf-Klon war. Für die Aussagekraft der
Ergebnisse unkritisch, aber für die nächste Runde notieren.

## Verdikt

**GO.** Keine offenen Blocker. Der Bug ist an der Wurzel behoben, das Feature
trägt keinen erreichbaren Fehl-Zustand, L10n ist gate-grün. F01 gehört ins
Backlog und sollte vor dem nächsten Feature-Zyklus fallen, damit der Wächter
wieder wächtert. F03 und F04 sind Produktentscheide für Andre.
