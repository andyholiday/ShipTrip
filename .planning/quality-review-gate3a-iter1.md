# Review — Gate #3 Scope A Fixes (Onboarding-Erststart, Soft-Ask-Reconcile, In-Memory-Postpone)

- **Iteration**: 1 / 3
- **Reviewer**: quality-agent (statisch, Claude-intern — Codex-Budget verbraucht)
- **Datum**: 2026-08-24
- **Pruefgegenstand**: Worktree `ShipTrip-worktrees/gate3a`, Branch `task/1.8.0-gate3a`,
  Diff `08cc088..7bbfaf8` (1 Commit, 4 Dateien, +354/-19)
- **Verdikt**: **approve / go** — keine offenen Blocker
- **Stats**: critical: 0, major: 1, minor: 5 — Blocker: 0, ins Backlog: 6
- **Geladene Skills**: code-review, swift-standards, swiftdata, xctest-ios
- **Testlauf**: KEINER durch diesen Agenten (Auftrag: statisches Re-Review, Build-Token
  liegt beim parallelen Verifikations-Agenten). Statischer Pass gelaufen:
  `guard.py sizes --files <4 geaenderte Dateien>` → `ok (4 geprueft, 0 Soft-Warnungen)`,
  Exit 0. Das Go steht damit ausdruecklich **unter dem Vorbehalt** des gruenen
  Build-/Test-Artefakts aus dem Parallel-Agenten.

## Summary

Die drei Gate-#3-Scope-A-Majors sind sachlich behoben und decken sich mit den
Produktentscheiden aus TASKPLAN-1.8.0 §189-196. Die Loesungen sind knapp, ohne
spekulative Abstraktion, und halten die SwiftData-/Swift-6-Regeln ein (kein `@Model`
ueber Aktorgrenzen, kein Force-Unwrap, kein `@Attribute(.unique)`, `fetchLimit = 1`
statt Vollfetch). Einziger substanzieller Einwand: die vier neuen Sichtbarkeits-Tests
pruefen eine **test-lokale Nachbildung** der Startsequenz statt `ShipTripApp` selbst —
aussagekraeftig fuer die reine Entscheidungsfunktion, blind fuer die Verdrahtung.
Kein Go-Live-Blocker, aber der Punkt gehoert ins Backlog.

## Fix-fuer-Fix-Nachweis

### (1) Soft-Ask-CTA → Reconcile nach Grant + In-Flight-Guard — **erfuellt**

- `OnboardingModel.enableReminders(in:)` (OnboardingModel.swift:193-204): Naht liefert
  jetzt `Bool` (`NotificationService.requestAuthorization()` ist bereits
  `-> Bool`, NotificationService.swift:24), und **nur** bei `true` laeuft
  `NotificationReconciler.run(context:)`. Der Flow blaettert in beiden Faellen weiter.
- **Aktor-Frage (Prueffrage 1b): sauber.** `OnboardingModel` ist `@MainActor`
  (OnboardingModel.swift:95-97), beide Nahten sind als `@MainActor`-Closures typisiert,
  und `NotificationReconciler.run` ist selbst `@MainActor`
  (NotificationReconciler.swift:250-252) und liest die Cruises synchron auf dem
  MainActor, bevor es auf reine Wertdaten (`CruiseReminderInput`) umsteigt. Der
  `ModelContext` kommt aus `@Environment(\.modelContext)` (OnboardingFlowView.swift:25) —
  derselbe MainContext, den `CruiseListView` benutzt. Es wandert kein `@Model` ueber eine
  Aktorgrenze.
- **Guard-Reset (Pruffrage 1a): sauber.** `isRequestingPermission` wird per `defer`
  zurueckgesetzt (OnboardingModel.swift:196); die Funktion `throw`t nicht, und `defer`
  laeuft auch bei Task-Cancellation beim Verlassen des Scopes. Ein dauerhaftes
  Verklemmen ist nicht konstruierbar.
- **Doppel-Reconcile**: `CruiseListView.task` (CruiseListView.swift:119-124) faehrt
  denselben Reconciler beim Start. Ein zeitgleicher zweiter Lauf ist theoretisch moeglich
  (beide `@MainActor`, aber mit `await`-Unterbrechungen). Er ist ungefaehrlich:
  `desiredRequests` ist deterministisch, und `UNUserNotificationCenter.add` mit gleicher
  Identifier ersetzt statt zu duplizieren. Kein Finding.
- **Demo-Daten**: Der Reconciler filtert `isDemo` selbst heraus
  (NotificationReconciler.swift:266) — die Beispielreise loest keine echten Pushes aus.
  Konvention aus CLAUDE.md eingehalten.
- UI-Seite: beide Karte-3-Aktionen sind waehrend der Abfrage gesperrt
  (OnboardingFlowView.swift:140,147), `skipReminders()` traegt denselben Guard
  (OnboardingModel.swift:208).

### (2) Upgrade-Abgrenzung: dreiwertiger Schalter + stille Migration + fetchLimit=1 — **erfuellt**

- `OnboardingPresentation.startupDecision(hasCompletedFlag:storeIsHealthy:hasExistingCruises:)`
  (OnboardingModel.swift:82-90) ist eine reine Funktion ueber `Bool?`. Die
  Dreiwertigkeit traegt genau die geforderte Unterscheidung: `nil` = nie durchlaufen
  (migrationsfaehig), `false` = per „Intro erneut zeigen" zurueckgeholt (nicht
  migrationsfaehig), `true` = erledigt.
- **Idempotenz (Pruffrage 2a): gegeben.** Die Migration schreibt einmalig `true`
  (ShipTripApp.swift:76-78); beim naechsten Start greift `.alreadyCompleted` und es wird
  gar nicht mehr geschrieben, der Store wird nicht mehr befragt
  (`flag == nil && hasExistingCruises(...)`, ShipTripApp.swift:104 — Short-Circuit).
- **Reihenfolge (Pruffrage 2a, zweiter Teil): gegeben.** Der Schreibvorgang steht in
  `init()`, also vor dem ersten Auswerten des `@AppStorage` in `body`
  (ShipTripApp.swift:175,196-199). Das ist kein neues Risiko, sondern exakt das Muster,
  das die bestehende, gruene UI-Test-Naht `completeOnboardingIfNeeded()`
  (ShipTripApp.swift:148-152) seit B5 nachweislich benutzt — `@AppStorage` liest den
  Store beim Zugriff, nicht beim Wrapper-Init. Empirisch abgesichert, kein Finding.
- **Restore aus Backup (Pruffrage 2b):** Voll-Backup (iCloud/Finder) stellt UserDefaults
  **und** Store wieder her → `flag == true` → `.alreadyCompleted`. 1.7.x-Backup →
  `flag == nil` + Reisen → `.migrateSilently`. Beide korrekt. Der CloudKit-Fall auf einem
  **neuen Geraet** ist die Ausnahme → F05 (Doku, non-blocking).
- **fetchLimit (Pruffrage 3):** `FetchDescriptor<Cruise>()` mit `descriptor.fetchLimit = 1`
  und `try?` (ShipTripApp.swift:118-121) — billige Ja/Nein-Abfrage, kein Force-Unwrap,
  Fehler faellt sicher auf `false` (= Onboarding zeigen, die harmlosere Richtung). Das
  fehlende `isDemo`-Praedikat ist heute nicht ausloesbar → F02 (minor).

### (3) In-Memory-Fallback unterdrueckt das Cover (postpone) — **erfuellt**

- `coverBinding(hasCompleted:isSuppressed:)` (OnboardingModel.swift:37-45) unterdrueckt
  im Getter **und** guarded den Setter — der Schalter bleibt garantiert unangetastet.
  Der Test `temporaryStorePostponesOnboarding` prueft genau das (`object(forKey:) == nil`).
- TASKPLAN §195-196 fordert „Flag bleibt false"; die Implementierung laesst den
  Schluessel **fehlen** statt ihn auf `false` zu setzen. Fuer die Sichtbarkeit
  aequivalent (`@AppStorage`-Default ist `false`) und fuer die Upgrade-Abgrenzung sogar
  praeziser. Spec-konform.
- **Doppelt/nie wieder (Pruffrage 4): keins von beidem.** Die Entscheidung ist ein `let`,
  einmal pro Prozess (ShipTripApp.swift:24,70) — innerhalb der Sitzung kann das Cover
  nicht nachtraeglich aufpoppen. Beim naechsten gesunden Start steht der Erststart
  unveraendert an, weil der Schalter nie geschrieben wurde. Einzige Nebenwirkung:
  „Intro erneut zeigen" ist in einer Postpone-Sitzung ein stiller No-Op → F06 (minor).

## Bewertung der 7 neuen Tests

| Test | Prueft echtes Verhalten? |
|------|--------------------------|
| `grantedPermissionReconcilesImmediately` | **ja** — echter `OnboardingModel` ueber die oeffentliche Naht; gegen den Vor-Fix-Stand rot (kein Reconcile-Aufruf existierte) |
| `deniedPermissionSkipsReconcile` | **ja** — deckt die Negativ-Verzweigung ab, die der Fix neu einfuehrt |
| `secondTapDuringRequestIsIgnored` | **ja, und gut gebaut** — `GatedPermissionSpy` haelt nur den *ersten* Aufruf an (OnboardingModelTests.swift:196-199), ein fehlender Guard wird damit zu `callCount == 2` statt zu einem haengenden Test. Prueft zusaetzlich, dass „Spaeter" waehrenddessen nicht weiterblaettert |
| `freshInstallSeesOnboarding` | teilweise — s. F01 |
| `upgradeWithExistingDataSkipsOnboarding` | teilweise — s. F01 |
| `replayIsNotMistakenForAnUpgrade` | teilweise — s. F01, prueft aber die inhaltlich wichtigste Abgrenzung (`false` vs. `nil`) |
| `temporaryStorePostponesOnboarding` | teilweise — s. F01 |

Kein Rot-Beweis liegt vor (Feature-Aenderung, kein Bugfix-Repro — nach der
Testumfangs-Leiter zulaessig: Tests fuer das Neue, Deckung auf dem Diff). Die drei
Model-Tests waeren gegen das Vor-Fix-Verhalten inhaltlich rot; die vier
Sichtbarkeits-Tests koennen es systembedingt nicht sein, weil die geprueften Typen neu
sind — genau deshalb F01.

## Findings

| ID  | Severity | Blocker | File:Line | Kategorie | Titel |
|-----|----------|---------|-----------|-----------|-------|
| F01 | major | nein | ShipTripTests/OnboardingModelTests.swift:66-89 | tests | Startsequenz test-lokal nachgebaut statt geprueft |
| F02 | minor | nein | ShipTrip/ShipTripApp.swift:119 | correctness | `hasExistingCruises` zaehlt Demo-Reisen mit |
| F03 | minor | nein | ShipTrip/Views/Onboarding/OnboardingModel.swift:202 | ux | `advance(from: 2)` ueberschreibt einen Wisch waehrend des Reconcile |
| F04 | minor | nein | ShipTrip/Views/Onboarding/OnboardingModel.swift:198-202 | ux | Reconcile blockiert den Kartenwechsel sichtbar |
| F05 | minor | nein | ShipTrip/ShipTripApp.swift:104 | docs | CloudKit-Neugeraet sieht das Onboarding trotz Bestandsdaten |
| F06 | minor | nein | ShipTrip/Views/Onboarding/OnboardingModel.swift:39 | ux | „Intro erneut zeigen" ist im Postpone-Fall ein stiller No-Op |

### F01 — Startsequenz test-lokal nachgebaut statt geprueft
- **File**: `ShipTripTests/OnboardingModelTests.swift:66-89` (Helfer `coverIsPresented`),
  betroffener Produktivcode `ShipTrip/ShipTripApp.swift:70-78` und `:84-122`
- **Severity**: major · **Blocker**: nein
- **Problem**: Der Helfer bildet die drei Schritte aus `ShipTripApp.init` nach
  (Entscheidung → bei `.migrateSilently` schreiben → Binding mit `isSuppressed`). Damit
  testen die vier Sichtbarkeits-Tests die reine Funktion plus eine Kopie der Verdrahtung.
  Genau die drei Dinge, die in Produktion brechen koennen, liegen ausserhalb ihrer
  Reichweite: (a) die Reihenfolge Schreiben-vor-`@AppStorage`-Lesen, (b) die Abbildung
  `container == nil || usingTemporaryStore` → `storeIsHealthy: false`, (c) der Fetch
  selbst. Wuerde jemand die Zeilen 76-78 aus `init` in `body` verschieben, blieben alle
  vier Tests gruen.
- **Fix-Vorschlag**: Die Glue-Logik nach `OnboardingPresentation` ziehen, z. B.
  `static func resolveAtStartup(flag: Bool?, storeIsHealthy: Bool, hasExistingCruises: Bool, defaults: UserDefaults) -> StartupDecision`, die den Migrations-Schreibvorgang
  selbst uebernimmt. `ShipTripApp.init` ruft sie mit `.standard`, die Tests mit dem
  Suite-`UserDefaults` — dann prueft der Test dieselbe Funktion, die die App faehrt,
  und der Helfer entfaellt.
- **Triage-Begruendung**: Die Verdrahtung ist neun Zeilen geradliniger Code, gelesen und
  gegen das bestehende `completeOnboardingIfNeeded`-Muster abgeglichen; der
  Onboarding-UI-Test (`OnboardingUITests`) deckt den Praesentations-Pfad Ende-zu-Ende ab.
  Kein Go-Live-Risiko.

### F02 — `hasExistingCruises` zaehlt Demo-Reisen mit
- **File**: `ShipTrip/ShipTripApp.swift:119`
- **Severity**: minor · **Blocker**: nein
- **Problem**: `FetchDescriptor<Cruise>()` hat kein `#Predicate { !$0.isDemo }`. Eine reine
  Demo-Bibliothek wuerde als „Bestandsinstallation" gewertet und das Onboarding still
  wegmigrieren — obwohl der Nutzer es nie gesehen hat.
- **Heute nicht ausloesbar** (deshalb minor statt major): Demo-Daten gibt es erst ab
  1.8.0; jeder Pfad, der sie anlegt (Onboarding-Karte 4, Einstellungen), setzt den
  Schalter zuvor auf `true` oder `false` — nie `nil`. Und `flag == nil` ist die einzige
  Bedingung, unter der der Fetch ueberhaupt laeuft.
- **Fix-Vorschlag**: `var descriptor = FetchDescriptor<Cruise>(predicate: #Predicate { !$0.isDemo })`
  ergaenzen; `fetchLimit = 1` bleibt daneben gueltig.

### F03 — `advance(from: 2)` ueberschreibt einen Wisch waehrend des Reconcile
- **File**: `ShipTrip/Views/Onboarding/OnboardingModel.swift:202` (i. V. m. `:163-167`)
- **Severity**: minor · **Blocker**: nein
- **Problem**: `advance(from:)` prueft nicht, ob `selection` noch bei `2` steht, sondern
  setzt bedingungslos `select(3)`. `.disabled(...)` (OnboardingFlowView.swift:140,147)
  sperrt nur die Tasten, nicht das TabView-Paging (OnboardingFlowView.swift:46-47). Wischt
  der Nutzer waehrend des laufenden Reconcile zurueck, reisst ihn der Abschluss auf
  Karte 4.
- **Fix-Vorschlag**: In `enableReminders` vor dem Weiterblaettern
  `guard selection == 2 else { return }`; `advance(from:)` selbst unangetastet lassen
  (wird von Karte 1/2 mitbenutzt).

### F04 — Reconcile blockiert den Kartenwechsel sichtbar
- **File**: `ShipTrip/Views/Onboarding/OnboardingModel.swift:198-202`
- **Severity**: minor · **Blocker**: nein
- **Problem**: `advance(from: 2)` laeuft **nach** `await reconcileReminders(context)`. Bei
  einer grossen Reisen-Liste (Fetch + `pendingIdentifiers()` + Scheduling) steht der
  Flow mit zwei gesperrten Tasten still, obwohl der Abgleich fuer die Navigation
  irrelevant ist.
- **Fix-Vorschlag**: Erst `advance(from: 2)`, dann den Reconcile — der Vertrag
  „Berechtigung + sofortiger Replan" bleibt erfuellt.

### F05 — CloudKit-Neugeraet sieht das Onboarding trotz Bestandsdaten
- **File**: `ShipTrip/ShipTripApp.swift:104` (i. V. m. `ShipTrip/Services/ShipTripCloudSync.swift:19-20`)
- **Severity**: minor · **Blocker**: nein
- **Problem**: In Produktion laeuft der Store gegen `.private(iCloud.com.andre.ShipTrip)`.
  Auf einem **neuen Geraet** (App aus dem Store, kein Voll-Backup) sind UserDefaults leer
  (`flag == nil`) und der lokale Store beim Launch noch leer — CloudKit synct erst
  danach. Die Momentaufnahme entscheidet `.present`: ein Bestandsnutzer sieht das
  Onboarding einmal, inklusive der Karte-4-Copy „erste Reise".
- **Bewertung**: Nicht sinnvoll behebbar ohne einen zusaetzlichen, iCloud-synchronen
  Schalter (`NSUbiquitousKeyValueStore`) — klar ausserhalb des Gate-#3-Scopes, und
  „neues Geraet zeigt das Intro einmal" entspricht der Plattform-Konvention.
- **Fix-Vorschlag**: Als bewusste Konsequenz in `docs/` bzw. am Doc-Kommentar von
  `startupDecision` festhalten, damit sie nicht als Bug wiederentdeckt wird.

### F06 — „Intro erneut zeigen" ist im Postpone-Fall ein stiller No-Op
- **File**: `ShipTrip/Views/Onboarding/OnboardingModel.swift:39` (Wirkung),
  `ShipTrip/Views/Settings/SettingsView.swift:185-189` (Ausloeser)
- **Severity**: minor · **Blocker**: nein
- **Problem**: Laeuft die Sitzung im In-Memory-Fallback, ist `isSuppressed` fuer die
  gesamte Prozesslaufzeit `true`. `requestReplay` setzt den Schalter auf `false`, das
  Cover erscheint aber nicht — die Taste tut sichtbar nichts.
- **Bewertung**: Nur in der ohnehin degradierten Sitzung, in der die Datenverlust-Warnung
  bereits zum Neustart auffordert. Der Wunsch geht nicht verloren: beim naechsten
  gesunden Start erscheint das Intro.
- **Fix-Vorschlag**: Falls spaeter gewuenscht — die Zeile in `SettingsView` bei aktivem
  Fallback ausblenden oder deaktivieren.

## Nicht geprueft / bewusst ausgeklammert

- **GDPR**: kein Trigger. Der Diff verarbeitet keine personenbezogenen Daten; die
  Benachrichtigungs-Berechtigung ist eine explizite, aktive Zustimmung (Soft-Ask, nur
  ueber die CTA) und wird lokal vom System gehalten.
- **Security**: kein Trigger. Keine neue Angriffsflaeche — keine Netzwerk-, Datei- oder
  Krypto-Pfade, keine Secrets, kein Logging von Nutzerdaten.
- **Build/Test**: nicht durch diesen Agenten (Auftrag: statisch, Build-Token vergeben).
  Das Go steht unter Vorbehalt des gruenen Artefakts aus dem Parallel-Agenten;
  insbesondere die Swift-6-Compile-Konformitaet der geaenderten Closure-Signaturen
  (`@MainActor () async -> Bool`, `@MainActor (ModelContext) async -> Void`) ist statisch
  plausibel, aber nur der Compiler beweist sie.

## Verdikt

**go** — 0 Blocker. Die drei Gate-#3-Scope-A-Findings sind sachlich und spec-konform
behoben, das Verhalten ist an den relevanten Nahten getestet. F01-F06 gehen ins Backlog
und reiten mit. Merge-Freigabe, sobald der parallele Verifikations-Build gruen meldet.
