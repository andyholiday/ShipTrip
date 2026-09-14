# Review — B2 Erststart-Onboarding

- **Iteration**: 1 / 3
- **Reviewer**: quality-agent (statischer Pass, ohne Build/Testlauf — Test-Build laeuft als eigener serieller Spawn)
- **Datum**: 2026-08-24
- **Gegenstand**: Worktree `ShipTrip-worktrees/b2`, Branch `task/1.8.0-b2`, Diff `de69d97..8d24073` (8 Dateien, +1160)
- **Verdikt**: approve (bedingt) — **keine Blocker**
- **Stats**: critical: 0, major: 3, minor: 3 — Blocker: 0, Backlog: 6

## Summary

Sauber gebauter, spec-treuer Port des Prototyps. Die B2-Invariante haelt: das
Onboarding haengt als `fullScreenCover` ueber dem montierten Hauptbaum, die
Start-Reparatur-Kette in `CruiseListView` ist unberuehrt und laeuft weiter.
Der B4-Soft-Ask ist korrekt: der Systemdialog haengt an genau einer Taste.
Die beiden vom Developer als „Abweichung" deklarierten Punkte sind **keine**
Abweichungen — die Design-Spec fordert bzw. erlaubt beide ausdruecklich
(§6 Punkt 1 und Punkt 2). Offene Punkte sind Produkt-Feinheiten und ein
Falsch-Gruen-Muster in den Sichtbarkeits-Tests, beides nicht go-live-relevant.

Go/No-Go steht unter Vorbehalt des parallelen Test-Builds: dieser Pass ist
rein statisch, es liegt **kein** `gate-run.json` vor.

## Findings

| ID  | Sev.  | Blocker | File:Line | Kategorie | Titel |
|-----|-------|---------|-----------|-----------|-------|
| F01 | major | nein | ShipTrip/Views/Onboarding/OnboardingFlowView.swift:184-187 | correctness | „Beispielreise" (Singular) laedt drei Reisen + zwei Wunschreisen |
| F02 | major | nein | ShipTripTests/OnboardingModelTests.swift:33-60 · OnboardingModel.swift:29-36 | tests | Falsch-Gruen: Sichtbarkeits-Tests pruefen test-only-Hilfsfunktionen |
| F03 | major | nein | ShipTrip/Views/Settings/SettingsView.swift:1071 | size | Datei ueber 500-Zeilen-Hardlimit (**vorbestehend**, B2 fuegt 8 Zeilen zu) |
| F04 | minor | nein | ShipTrip/Views/Onboarding/OnboardingCards.swift:242 | correctness | Karten-Meta „7 Tage" vs. Demo-Datensatz 8 Tage |
| F05 | minor | nein | ShipTrip/Views/Onboarding/OnboardingModel.swift:123,132 | readability | `advance(from: 2)` hartkodiert statt `advance(from: selection)` |
| F06 | minor | nein | ShipTrip/Views/Onboarding/OnboardingFlowView.swift:152-160 | ux | Beide Start-CTAs enden auf der Liste, nicht im Formular/Detail (Pruefpunkt 11) |

### F01 — „Beispielreise" laedt drei Reisen + zwei Wunschreisen
- **File**: `ShipTrip/Views/Onboarding/OnboardingFlowView.swift:184-187`
- **Severity**: major · **Blocker**: nein
- **Problem**: Karte 4 zeigt genau eine Reise („Norwegische Fjorde", Etikett
  „Beispielreise"), die Fussnote spricht im Singular („Die Beispielreise ist
  als Demo markiert"). `DemoDataService.loadDemoData` legt aber
  `insertMittelmeer` + `insertNorwegen` + `insertKaribik` (DemoDataService.swift:121-125)
  und zwei Deals an. Der Erstnutzer bekommt fuenf Objekte, versprochen war eins.
  Kein Datenverlust, in einem Tipp aus den Einstellungen entfernbar.
- **Fix (kleinster Schnitt, ohne Service-Aenderung)**: Copy auf den Bestand
  ziehen — Fussnote auf „Die Beispieldaten sind als Demo markiert und lassen
  sich mit einem Tipp wieder entfernen.". Eine `loadSampleCruiseOnly`-Variante
  waere die schoenere Loesung, aendert aber `DemoDataService` und liegt damit
  ausserhalb des B2-Auftrags — eigener Task.

### F02 — Falsch-Gruen: Sichtbarkeits-Tests pruefen test-only-Hilfsfunktionen
- **File**: `ShipTripTests/OnboardingModelTests.swift:33-60`, `ShipTrip/Views/Onboarding/OnboardingModel.swift:29-36`
- **Severity**: major · **Blocker**: nein
- **Problem**: `OnboardingPresentation.shouldPresent(defaults:)` und
  `markCompleted(in:)` werden **nirgends im Produktivcode gerufen**.
  `ShipTripApp.swift:90/107/109/113` inlined dieselbe Logik ueber
  `@AppStorage`; produktiv genutzt sind nur `hasCompletedKey` und
  `requestReplay` (SettingsView.swift:186). Die drei Tests
  `presentsOnFirstLaunch` / `doesNotPresentAfterCompletion` /
  `replayPresentsAgain` beweisen damit, dass eine fuer den Test eingefuehrte
  Hilfsfunktion funktioniert — nicht, dass die App beim ersten Start das
  Onboarding zeigt. Zusaetzlich verstoesst `markCompleted` gegen CLAUDE.md §2
  (toter, spekulativer Produktivcode).
- **Fix**: `markCompleted(in:)` streichen (unbenutzt). `shouldPresent(defaults:)`
  entweder streichen und den Doc-Kommentar der Test-Suite ehrlich auf
  „Persistenz-Vertrag des Schluessels" umbenennen, oder in `ShipTripApp` das
  Binding gegen `OnboardingPresentation` fuehren. Die echte Sichtbarkeits-
  Zusage gehoert in den UI-Test aus B5 — dort so vormerken.

### F03 — SettingsView ueber dem Hardlimit
- **File**: `ShipTrip/Views/Settings/SettingsView.swift` (1071 Zeilen)
- **Severity**: major · **Blocker**: nein
- **Problem**: `guard.py sizes` meldet exit 1. **Vorbestehend** — B2 fuegt
  genau 8 Zeilen (den „Intro erneut zeigen"-Button) hinzu und verursacht die
  Ueberschreitung nicht. Alle fuenf neuen Onboarding-Dateien liegen bei
  134–253 Zeilen, also klar unter dem Softlimit.
- **Fix**: nicht in dieser Runde. Backlog: Settings in Sektions-Views schneiden.

### F04 — Karten-Meta „7 Tage" vs. Datensatz 8 Tage
- **File**: `ShipTrip/Views/Onboarding/OnboardingCards.swift:242`
- **Severity**: minor · **Blocker**: nein
- **Problem**: Die Karte annonciert „Norwegen · 7 Tage"; `insertNorwegen`
  (DemoDataService.swift:173-174) setzt `start = +21 d`, `end = +29 d` — acht
  Tage. Wer die Beispielreise laedt, sieht direkt danach eine andere Zahl.
- **Fix**: Meta-String auf „Norwegen · 8 Tage" ziehen (der Prototyp-Wert war
  Illustration ohne Datensatz dahinter).

### F05 — Magic-Index im Soft-Ask
- **File**: `ShipTrip/Views/Onboarding/OnboardingModel.swift:123,132`
- **Severity**: minor · **Blocker**: nein
- **Problem**: `enableReminders()` und `skipReminders()` rufen
  `advance(from: 2)` mit hartkodiertem Index. Kein Fehlverhalten (der
  System-Dialog blockt die Interaktion waehrend des `await`), aber das Modell
  koppelt sich an die Kartenreihenfolge.
- **Fix**: `advance(from: selection)`.

### F06 — Start-CTAs enden auf der Liste (Pruefpunkt 11)
- **File**: `ShipTrip/Views/Onboarding/OnboardingFlowView.swift:152-160`
- **Severity**: minor · **Blocker**: **nein**
- **Problem**: „Erste Reise anlegen" ruft nur `onFinish()` und landet auf der
  leeren Liste; „Beispielreise ansehen" laedt die Daten und landet auf der
  gefuellten Liste. Die Design-Narrative fordert das Oeffnen des Formulars
  bzw. der Detail-Ansicht.
- **Einordnung**: kein Go-Live-Blocker. Beide Wege enden auf einem sinnvollen,
  funktionierenden Zustand — Empty-State mit eigener CTA bzw. die sichtbar
  gefuellte App, also genau das Versprechen „sieh dir an, wie eine fertige
  Reise aussieht". Es fehlt ein Tipp, nicht ein Weg. Der Fix erfordert eine
  Deep-Link-Naht vom Cover in `CruiseListView` (`showingAddSheet` bzw.
  NavigationPath) — ein echter Umbau, kein Einzeiler.
- **Fix (falls Winston eine Runde ansetzt)**: `onFinish` um einen
  `OnboardingExit`-Enum (`.createTrip` / `.sampleTrip` / `.plain`) erweitern,
  in `ShipTripApp` in `@State`-Werte spiegeln, die `MainTabView` an
  `CruiseListView` durchreicht.

## Pruefliste — Urteile

| # | Pruefpunkt | Urteil |
|---|---|---|
| 1 | B2-Invariante | **erfuellt** |
| 2 | Swift-6-Naehte | **erfuellt**, soweit statisch pruefbar |
| 3 | B4-Soft-Ask | **erfuellt** |
| 4 | DemoDataService-API | **erfuellt** |
| 5 | Design-Konformitaet | **erfuellt**; beide „Abweichungen" sind spec-gefordert |
| 6 | Erst-Start-Logik | **erfuellt** (Testabdeckung siehe F02) |
| 7 | L10n-Disziplin | **erfuellt** |
| 8 | Scope-Hygiene | **erfuellt** |
| 9 | Testumfang | **teilweise verletzt** (F02) |
| 10 | Dateigroessen | 1 FAIL, vorbestehend (F03) |
| 11 | Dead-End-CTAs | **Nicht-Blocker** (F06) |

### 1. B2-Invariante — erfuellt
`ShipTripApp.swift:96-114`: `MainTabView().modelContainer(container).fullScreenCover(...)`.
Reihenfolge korrekt — das Cover haengt **nach** `.modelContainer`, der
praesentierte Inhalt erbt daher den `modelContext` (den `showSampleTrip`
braucht). Ein `fullScreenCover` haengt den Praesentierenden nicht ab:
`MainTabView` und `CruiseListView` bleiben montiert.
`CruiseListView.swift:118-123` — die Kette `IdBackfill.run` →
`await NotificationReconciler.run` → `ThumbnailBackfill` →
`ShippingLineCatalogDedup` ist **nicht im Diff** und damit byte-identisch;
weder verzoegert noch uebersprungen.

### 2. Swift-6-Naehte — erfuellt (statisch)
- `@MainActor @Observable final class OnboardingModel` + `@State private var model = OnboardingModel()`
  in einem als `@MainActor` markierten `struct OnboardingFlowView` — der
  Default-Initializer-Ausdruck ist damit MainActor-isoliert. Sauber.
- `private let requestNotificationPermission: @MainActor () async -> Void`:
  MainActor-Closure in MainActor-Klasse, nur aus MainActor-Kontext gerufen —
  keine Sendable-Naht noetig. Der Default-Ausdruck greift auf
  `NotificationService.shared` zu; `NotificationService` ist
  `final class ... : Sendable` (NotificationService.swift:15) mit
  nonisolated `async` API — der `await` ist korrekt und noetig.
- `Task { await model.enableReminders() }` (FlowView:136) erbt die
  MainActor-Isolation aus dem Button-Closure. Kein Hop, kein Datenrennen.
- `Binding(get:set:)` mit `hasCompletedOnboarding = true` im Setter
  (ShipTripApp:106-111): zulaessig, weil `AppStorage.wrappedValue` einen
  `nonmutating set` hat — `self` wird nicht mutierend gefangen. Identisches
  Muster steht bereits vier Zeilen tiefer im `.alert`-Binding, das heute baut.
- Ziel-Setting ist `SWIFT_STRICT_CONCURRENCY = complete` / `SWIFT_VERSION = 6.0`
  fuer alle Konfigurationen — keine Aufweichung im Diff.
- Restrisiko liegt allein beim Compiler; der Test-Build ist der Beweis.

### 3. B4-Soft-Ask — erfuellt
Die Naht `requestNotificationPermission` wird von genau einer Stelle gerufen:
`OnboardingModel.enableReminders()` (Model:121-124), erreichbar ueber genau
eine Taste (FlowView:135-137). `skipReminders()` (Model:131-133) blaettert
nur weiter — keine Notification-API, kein Flag. Test
`laterNeverRequestsSystemPermission` und
`skippingTheWholeFlowNeverRequestsPermission` decken beide Wege ueber einen
Call-Count-Spy; das ist Verhalten, nicht Mock-Interna.
Der kontextuelle Ask ist unberuehrt: weder `CruiseFormView` noch
`NotificationService` stehen im Diff. `.notDetermined` bleibt nach „Spaeter"
erhalten, die spaetere Abfrage findet ihren Zustand also unveraendert vor.

### 4. DemoDataService — erfuellt
Einziger neuer Aufruf: `DemoDataService.loadDemoData(into: modelContext)`
(FlowView:185). Kein Zugriff auf `resetAndLoadDemoDataForUITesting` (das
einzige `#if DEBUG`-gated Symbol). Der Service selbst ist nicht im Diff.
`loadDemoData` ist idempotent (DemoDataService.swift:28-32 — Guard auf
`hasDemoData`), ein zweiter Durchlauf nach „Intro erneut zeigen" dupliziert
also nichts. Das Fussnoten-Versprechen („laesst sich mit einem Tipp wieder
entfernen") ist im **Release** einloesbar: SettingsView.swift:154-170 traegt
die Sektion ohne DEBUG-Gate.

### 5. Design-Konformitaet — erfuellt; die beiden „Abweichungen" sind keine
**Karten 1–3 gegen §4/§10/§11**: Seitenpunkte (8 pt, aktiv 22-pt-Kapsel
`oceanBlue`, inaktiv `.secondary` 28 %), Divider-Vorsprung 64 pt
(`48 + OnboardingSpace.md`), Icon-Kachel 48×48 / Radius `sm` / Tint 14 % /
Glyphe 20 pt semibold, Hero 3:2 mit Zwei-Stopp-Scrim ab 50 % auf 55 % und
`.ultraThinMaterial`-Kapsel bei 16 pt Innenabstand, Aktionen ein einziges
Groessen-Level (66 pt), `actionBorder` = `systemGray` 1 pt, Fliesstext auf
`bodyText` und Fussnoten auf `.secondary` — alles deckungsgleich, inklusive
der Korrekturen aus §10/§11 (kein fester 174-pt-Block mehr, Punkte fest
28 pt ueber der Primaer-Aktion). Abgeglichen gegen die Soll-Shots
`karte-1--dark.png`, `karte-3--light.png`, `karte-4--light.png`.

**Karte 4 gegen den Prototyp-Code**: pixelgenauer Port. Scrim-Stops
(0.30 clear / 0.62 black 45 % / 1.0 black 90 %), Kartenhoehe 224, Radius 28,
Schatten `navyDark` 22 % / r17 / y10, Etikett `.caption2.bold` weiss auf
`black` 55 %, Titel `.title3.heavy`, Meta-Kapsel `white` 16 %, Reihenfolge und
Kaskaden-Indizes der Aktions-Gruppe — identisch. Die **Info-Pille fehlt zu
Recht**: der Prototyp hat sie ebenfalls nicht (`ProtoTheme.swift` dokumentiert
sie als Gate-Befund gestrichen), und der Soll-Shot `karte-4--light.png` zeigt
sie nicht. Der Kommentar in `OnboardingComponents.swift:153-157` ist damit
belegt. *(Hinweis: der Prosa-Abschnitt §11 „Warum das Etikett und nicht die
Pille gedaempft wurde" ist gegenueber Prototyp und Shot veraltet — Doku-Drift,
kein Code-Befund.)*

**Die zwei deklarierten Abweichungen — beide berechtigt, beide spec-gefordert:**
1. *Inhaltsspalte in `ScrollView`* — keine Abweichung, sondern eine
   **Auflage**: design-spec §6, „Was der Developer nachziehen muss", Punkt 1:
   „Der Produktivcode muss den Inhaltsbereich in einen `ScrollView` legen,
   Fusszeile und Kopfzeile ausserhalb." Genau so umgesetzt (FlowView:57-73).
   `.scrollBounceBehavior(.basedOnSize)` verhindert zusaetzlich den
   Gestenkonflikt mit dem paging-`TabView`. Sauber geloest.
2. *„Ueberspringen" `.semibold`* — keine Abweichung, sondern **eine der beiden
   ausdruecklich angebotenen Optionen**: §6 Punkt 2 nennt „das Label auf
   `.body.weight(.semibold)` setzen (dann gilt der 3 : 1-Schwellwert fuer
   grossen Text)" als sauberen Ausweg und ueberlaesst die Wahl dem Developer.
   Der gemessene Wert stimmt: `#0C8CE9` auf `#F2F2F7` = **3,165 : 1**
   (nachgerechnet). Der Optik-Delta zum Shot (dort `.regular`) ist die
   bewusste Gegenleistung fuer die Farbtreue.

### 6. Erst-Start-Logik — erfuellt
`@AppStorage("hasCompletedOnboarding")` liegt in `UserDefaults.standard` und
ueberlebt App-Kill; `false`/fehlend = Onboarding steht aus. „Intro erneut
zeigen" (SettingsView:185-187) setzt den Schluessel auf `false`; `@AppStorage`
beobachtet `UserDefaults` und praesentiert das Cover neu. Da
`fullScreenCover` seinen Inhalt bei jeder Praesentation neu baut, startet
`@State private var model` frisch auf Karte 1 — kein Zustands-Leck zwischen
Durchlaeufen. Testabdeckung dieser Zusage: siehe F02.

### 7. L10n-Disziplin — erfuellt
`Localizable.xcstrings` steht **nicht** im Diff (verifiziert ueber
`git diff --name-only`) — korrekt, Xcode extrahiert beim naechsten Build.
Alle 24 neuen sichtbaren Strings sind `String(localized:)`. Das
`Text(title)`-Muster ist hier **unschaedlich**: `OnboardingPrimaryButton`/
`SecondaryButton`/`FeatureRow` bekommen bereits aufgeloeste `String`-Werte
uebergeben, die Lokalisierung passiert am Aufrufort. Gleiches gilt fuer
`Label(String(localized: "Intro erneut zeigen"), systemImage:)`.
Interpolationen sind type-aware: `"Schritt \(index + 1) von \(count)"` →
`%lld`/`%lld` (Components:88), `"Beispielreise ansehen: \(title), \(meta), \(badge)"`
→ 3× `%@` (Components:197).

### 8. Scope-Hygiene — erfuellt
Exakt die acht erwarteten Dateien, nichts sonst. `SettingsView` traegt genau
den einen Eintrag (+8 Zeilen). `project.pbxproj` musste **nicht** angefasst
werden: das Projekt nutzt `PBXFileSystemSynchronizedRootGroup` fuer
`ShipTrip`/`ShipTripTests` — die neuen Dateien sind automatisch
Target-Mitglied, kein Build-Blocker aus fehlender Projektmitgliedschaft.

### 9. Testumfang — teilweise verletzt
Leiter „Feature": Tests nur fuer das Neue ✓. Test-Diff 177 Zeilen ≤ Code-Diff
983 Zeilen ✓. Isolierte `UserDefaults`-Suites statt `.standard` ✓ (kein
geteilter mutabler Zustand). Der Spy zaehlt Aufrufe statt Mock-Interna zu
pruefen ✓. **Aber**: Falsch-Gruen-Muster bei den drei Sichtbarkeits-Tests —
siehe F02. Die Flow-/Soft-Ask-Tests (8 Stueck) pruefen echtes,
produktiv genutztes Verhalten.

### 10. Dateigroessen — `guard.py sizes`
```
FAIL  ShipTrip/Views/Settings/SettingsView.swift: 1071 Zeilen (> 500 hart)
sizes: 1 Datei(en) ueber Hard-Limit — major-Finding
exit=1
```
Alle uebrigen gepruefften Dateien bestehen. Neue Dateien: Cards 253 ·
Components 232 · FlowView 195 · Theme 137 · Model 134 · Tests 177.
Der einzige FAIL ist vorbestehend (F03).

## Security / GDPR

Kein GDPR-Pass ausgeloest: B2 verarbeitet keine personenbezogenen Daten,
oeffnet keinen Netzwerkpfad und loggt nichts. Die einzige Privacy-Flaeche ist
die Notification-Berechtigung, und die ist lehrbuchmaessig opt-in — kein
vorangekreuztes Feld, kein „Weiter = Zustimmung", der Systemdialog haengt an
einer bewussten Taste, „Spaeter" ist gleichrangig gestaltet (gleiche Hoehe,
gleiche Breite) statt als grauer Mini-Link. Kein Security-Pass ausgeloest:
keine neue Angriffsflaeche.

## Testlauf-Status

**Kein Testlauf in diesem Spawn** (Auftrag: statischer Pass, kein Build,
kein Simulator). Es liegt **kein `gate-run.json`** vor. Der Test-Build laeuft
als separater serieller Spawn; das Go steht unter dessen Vorbehalt.
