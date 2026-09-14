# BACKLOG

## Kalender-Migration (Review-Iteration 1, 2026-08-04)

- [major] ShipTrip/Services/CalendarSyncService.swift:220-229 — matchingEvent nur im Zielkalender: Dedup-Netz nach Restore/Neuinstallation weg, Duplikate möglich (F03)
- [major] ShipTrip/Services/CalendarSyncService.swift:189-193 — Migration create-before-delete umdrehen: echte Atomarität statt Guard (F01-Rest)
- [minor] ShipTrip/Views/Settings/SettingsView.swift:381-394 — Alert über gepushtem Form-Picker nicht durchgeklickt (F06)
- [minor] ShipTrip/Localizable.xcstrings:5-15 — Plural fehlt („1 Kalendereinträge …"), gleicher Mangel bei Zeile 3201 (F07)
- [minor] ShipTrip/Services/CalendarSyncService.swift:70-73 — Doc-Kommentar von hasManagedEvents behauptet Kalenderbezug (F08)
- [minor] ShipTrip/Views/Settings/SettingsView.swift:1 — Datei 977 Zeilen über Hard-Limit, bestand schon vor dem Diff; CalendarSyncSettingsView extrahieren (F10)

## Kalender-Migration (Review-Iteration 2, 2026-08-04)

- [major] ShipTrip/Views/Settings/SettingsView.swift:440-450 — Rollback-Pfad ist die einzige Datenverlust-Absicherung und ungetestet (F11)
- [major] ShipTrip/Views/Settings/SettingsView.swift:450 — Scheitern von restorePreviousCalendarEvents bleibt fuer den Nutzer unsichtbar (F12)
- [minor] ShipTrip/Views/Settings/SettingsView.swift:434-437 — accessDenied-Zweig in migrateNow macht keinen Restore (F13)
- [minor] ShipTrip/Services/CalendarSyncService.swift:57 — EKEventStoreChanged wird nie beobachtet, shared-Store kann veralten (F14)
- [minor] ShipTripTests/CalendarSyncServiceMigrationTests.swift:170-172 — Tests mutieren UserDefaults.standard des Test-Hosts, Flake-Risiko (F15)
- [minor] ShipTripTests/CalendarSyncServiceMigrationTests.swift:133-134 — Testkalender-Leak, wenn init nach dem ersten makeCalendar wirft (F16)

## Release-Gate Build 23 (2026-08-04)

- [major] ShipTripUITests/HauptansichtScreenshotTests.swift:16 — hartkodierter fremder Home-Pfad `/Users/andreja/...` laesst 9 von 24 UI-Tests fehlschlagen; Ausgabeordner per ENV + XCTSkip (F17)
- [minor] ShipTrip/Assets.xcassets/demo_port_*.imageset — 5 Debug-only Demo-Bilder (~1,5 MB) liegen im Release-Assets.car, obwohl DemoDataService `#if DEBUG` ist (F18)
- [minor] .planning/screenshots-build23 — Kalenderdialog-Durchklick war ein temporaerer Wegwerf-UI-Test; als dauerhaften XCUITest einchecken, sonst faellt der Beweis beim naechsten Release wieder an (F19)

## Release 1.7.1 (Codex Gate #1 Triage, 2026-08-23)

- [major] ShipTrip/Views/Settings/SettingsView.swift:641-688 — Erinnerungs-Toggle/Offset-Änderung löst keinen Reconcile aus; wirkt erst beim nächsten App-Start (nach A1) bzw. Speichern
- [minor] ShipTrip/Views/Cruises/CruiseFormView.swift:374 — Plural „Einträge" fehlt (aus A4 ausgenommen, fremder Dev-Scope)
- [minor] ShipTrip/Views/Cruises/CruiseHeroCardView.swift:52 — daysUntilStart == 0 zeigt „In 0 Tagen" statt „Heute" (vorbestehend, A4 hat nur one/other)
- [minor] ShipTrip/Localizable.xcstrings:1 — Katalog unsortiert, 33 Kompakt-Einträge; einmalige Xcode-Normalisierung als eigener Task (~3.000-Zeilen-Diff)
- [major] ShipTrip/Views/Settings/SettingsView.swift:923-931 — Konkatenat-Plurale `"\(n) " + String(localized:)` nicht pluralisierbar (gleiche Klasse: CruiseFormView.swift:722)
- [minor] ShipTrip/Views/Settings/SettingsView.swift:223 — Datenschutz-Link wählt nach Gerätesprache (`Locale.current.language.languageCode`), nicht nach App-Lokalisierung; Drittsprachen landen auf EN-Seite bei DE-UI
- [minor] ShipTrip/Views/Cruises/CruiseFormView.swift:1428 — Gemini-Hinweis steht unter dem TextEditor, „Analysieren" sitzt in der Toolbar; Hinweis sichtbar vor dem Senden, aber nicht in Leserichtung vor dem Button
- [minor] ShipTripTests/ShipTripTests.swift:591-617 — prefixFilterLogic beschreibt altes `cruise-<id>-`-Schema, seit A1 stale; streichen oder auf ReminderIdentifier.prefix umstellen
- [minor] ShipTrip/Views/Cruises/CruiseFormView.swift:828 — Kommentar „damit persistentModelID final ist" irreführend, Identifier kommt seit A1 aus Cruise.id
- [minor] ShipTrip/Views/Cruises/CruiseListView.swift:1 — 402 Zeilen, überschreitet seit A1 erstmals das 400er-Soft-Limit
- [major] ShipTripTests/TempPortCoordinatesTests.swift:1 — Rot-Beweis deckt nur die Entscheidungslogik, nicht die Verdrahtung in savePort (bräuchte XCUITest über das Sheet)
- [minor] ShipTrip/Views/Cruises/CruiseFormView.swift:1168 — fieldChanged faltet keine Diakritika („Málaga"→„Malaga" gilt als Änderung), enger als findBestMatch
- [minor] ShipTrip/Services/NotificationService.swift:82-86 — Vorab-Erinnerung erbt die Uhrzeit des date-only Startdatums (00:00); importierte Daten können am falschen lokalen Tag feuern (vorbestehend, Codex Gate #2 A1)
- [minor] ShipTrip/Views/Settings/SettingsView.swift:1 — 1010 Zeilen, überschreitet seit A3–A5 erstmals SwiftLint file_length 1000 (Projekt hat keine .swiftlint.yml)
- [minor] ShipTrip/Services/NotificationReconciler.swift:316 — Add-Fehler-Guard ist global; Removes gelöschter Reisen verschieben sich dann auf den nächsten Start
- [minor] ShipTrip/Services/NotificationService.swift:99-103 — removeReminders filtert nur neues Prefix; Legacy-Requests einer gelöschten Reise räumt erst der Start-Reconcile
- [minor] CHANGELOG.md:112 — Datum von [1.7.0] steht auf 2026-07-10, echtes App-Store-Freigabedatum nachtragen
- [major] marketing/release-1.7.0/app-store-connect/release-configuration.md:32 — Blocker „EEA Paid Services" weiterhin offen (Altersfreigabe-Teil erledigt)

## Run 1.8.0 (Go-Live-Triage, 2026-08-24)

- [minor] ShipTrip/Views/Cruises/CruiseDetailView.swift:123 — „Häfen"-Label zählt Anläufe (route ohne Seetage, inkl. Mehrfachbesuch); gleiche Zweideutigkeit wie C8 eine Ebene tiefer (auch CruiseHeroCardView.swift:178, Map/RouteStopSheetView.swift:66); auf „Anläufe" ziehen oder als Per-Reise-Konvention dokumentieren
- [major] ShipTripTests/CruiseAggregateTests.swift:1 — 627 Zeilen über Hard-Limit 500 (Vorbestand 590); Suite splitten (CruiseAggregateTests / CruiseHeroSelectionTests)
- [minor] ShipTrip/Views/Cruises/CruiseStatsStripView.swift:39 — „Anläufe"/„Port Calls" längstes Strip-Label, Truncation-Risiko bei XXL Dynamic Type + EN; im visuellen Beweis vor Release einmal ansehen
- [minor] ShipTripTests/CruiseAggregateTests.swift:287 — Regressionstest fixiert Zahlen, nicht Beschriftungen; Label-Nachweis über Release-Durchklick-Beweis, optional EN-Smoke-Marker nach C5
- [minor] ShipTrip/Utilities/Color+Theme.swift:1 — App-weiter Subtitle-Grau-Token (133,133,139) misst 3,29:1 auf Light-Ground, unter AA für <18pt; Produkt-Frage, nicht B1-spezifisch (Gate-#5-Finding 7; auch Primär-Button weiß auf Akzentblau 3,53:1 nur Large-Text-tauglich)
- [minor] .gitignore:1 — Einträge für .bundle/ und vendor/bundle fehlen (seit C2 existiert ein Gemfile); Mini-Task (C2-Hinweis 4)
- [minor] .github/workflows/ci.yml:1 — beim ersten grünen Actions-Lauf prüfen, ob simctl privacy grant calendar auf dem Runner als .fullAccess ankommt — sonst skippt CalendarSyncServiceMigrationTests still statt zu failen (C2-Hinweis 2)
- [minor] ShipTrip/Views/Settings/SettingsView.swift:931 — ImportResult zählt nur Cruises; reiner Deal-/Katalog-Import meldet „✓ 0 importiert" (Codex #2 C3); aggregierte Zählung als Folge-Task
- [minor] ShipTripTests/ExportLegacyCompatibilityTests.swift:104 — Kompat-Matrix unvollständig (defekte/partielle Envelopes); Kern-Grenzfälle leeres 1.7-Array + JSON-Demo-Filter kommen in der C3-Fix-Runde, Rest hier
- [minor] .github/workflows/ci.yml:82 — Kommentar „sonst skippen sie" falsch: Fixture-Throw ist in Swift Testing ein Fail, kein Skip (C2-Review F01)
- [minor] .github/workflows/ci.yml:108 — xctestrun-Glob ohne pipefail/Leer-Guard; set -euo pipefail + Guard ergänzen (C2-Review F03)
- [minor] .github/workflows/ci.yml:32 — Actions per Tag statt SHA gepinnt (OWASP A08, Schaden klein bei contents:read) (C2-Review F04)
- [minor] Gemfile:1 — Bundler-4-Lock vs. Runner-Bundler-2 (erst relevant, wenn CI bundelt) + Kommentar beschreibt Soll statt Ist / Lanes nicht via bundle exec (C2-Review F05+F06)
- [minor] ShipTripTests/ExportImportHardeningTests.swift:1 — 1.339 Zeilen, weit über 500er-Grenze (Vorbestand + C3); Suite thematisch splitten
- [minor] ShipTrip/Services/ExportImportService+Import.swift:1 — seenPortIDs/seenExpenseIDs haben dieselbe Kollisions-Lücke wie das gefixte Foto-Set (nur pro Cruise, DB unberücksichtigt); gleiche Fix-Form wie Foto-ID-Fix (C3-Fix-Runde, offener Punkt)
- [minor] ShipTrip/Services/ExportImportService+Import.swift:90 — FetchDescriptor<Photo>() materialisiert beim Import alle Photo-Rows nur für .id; propertiesToFetch = [\.id] setzen (C3-Fix-Review)
- [minor] ShipTripTests/ExportButtonStateTests.swift:19 — Test deckt nur den Summen-Helper, nicht die Call-Site-Verdrahtung der fünf Sammlungen (C3-Fix-Review)
- [major] ShipTripTests/ExportGuardTests.swift:85 — „Dateigröße exakt vorhergesagt" ungetestet auf Archiv-Ebene; Grenzfall-Test gegen attributesOfItem[.size] == payload + Σ(76+2n) + 22 ergänzen (C4-Fix-Review)
- [major] ShipTrip/Services/ExportImportService+Export.swift:107 — Alles-oder-nichts: EIN unlesbares Bild verhindert jedes Backup, Fehlertext nennt nur internen Pfad; Skip-Option oder verständliche Meldung (Reise/Hafen benennen) als Folge-Task (C4-Fix-Review)
- [minor] ShipTrip/Views/Settings/SettingsView.swift:922 — CancellationError landet im generischen „Export fehlgeschlagen"-Alert; bei künftigem Cancel-Button `if error is CancellationError { return }` (C4-Fix-Review)
- [minor] ShipTrip/Views/Settings/SettingsView.swift:1004 — deleteAllData ohne harten Reentrancy-Guard (nur .disabled); Asymmetrie zu exportData/handleImport (C4-Fix-Review)
- [minor] ShipTripTests/ExportGuardTests.swift:114 — data(at: 0) ohne count-Zusicherung, Index-Trap statt Testfehler (C4-Fix-Review)
- [minor] ShipTrip/Services/ExportImportService+Export.swift:1 — RSS-Speicherprofil-Messung des Streams auf realem Gerät + Golden-Byte-Test alt/neu-ZIP stehen aus (Codex #2 C4)
- [minor] ShipTrip.xctestplan:5-9 — SHIPTRIP_SCREENSHOT_DIR nirgends verdrahtet (Testplan ohne environmentVariableEntries); lokaler Screenshot-Workflow braucht zweite Testplan-Konfiguration „Screenshots" (C1-Review F01)
- [minor] ShipTripUITests/HauptansichtScreenshotTests.swift:25-31 — relativer ENV-Wert löst gegen undefiniertes Runner-CWD auf; Guard auf absoluten Pfad ergänzen (C1-Review F02)
- [minor] ShipTrip/Views/Onboarding/OnboardingComponents.swift:1 — Karte-4-Foto-Overlay: Eyebrow-Chip auf eigener Achse (~9pt Einzug) + zweite Chip-Polarität neben kartenbreitem Scrim; auf eine Achse und eine Chip-Behandlung (Karte-1-Muster) ziehen — per B2 1:1 aus dem Prototyp portiert (B1-Re-Gate pass, Notes 1+2)
- [minor] ShipTrip/Views/Onboarding/OnboardingCards.swift:1 — Karte 4: Foto-Karte (~25% Screen) stützt visuell nur die Sekundär-Option, Primary „Erste Reise anlegen" ohne visuelle Stütze; Karte kürzen oder direkt über den Sekundär-Button rücken — per B2 portiert (B1-Re-Gate pass, Note 3)
- [minor] CHANGELOG.md:1 — B3 (Beispielreise im Release) fehlt unter [Unreleased]; im Final-Knowledge vor Gate #6 nachtragen (Knowledge-Wave-B-Fund)
- [minor] ShipTripUITests/OnboardingUITests.swift:152 — Negativ-Asserts auf Nachbarkarten wetten auf TabView-Paging (Falsch-Rot-Risiko); Skip-Semantik ist unit-gedeckt (B5-Review F02)
- [minor] ShipTripUITests/OnboardingUITests.swift:104 — Springboard-Check ohne Wartefenster, nicht tragend (B5-Review F03)
- [minor] ShipTripUITests/OnboardingUITests.swift:174 — einziger ungeschützter Tap der Datei; waitForExistence davor (B5-Review F04)
- [minor] ShipTrip/ShipTripApp.swift:91 — Kompat-Naht schreibt UserDefaults dauerhaft; Onboarding bleibt nach jedem UI-Lauf auf dem Gerät weg (DEBUG-only, bewusst gegen NSArgumentDomain) (B5-Review F05)
- [minor] ShipTripUITests/HauptansichtScreenshotTests.swift:83 — nach „Beispieldaten entfernen" ohne Neu-Scrollen getippt (B5-Review F06)
- [minor] ShipTripUITests/OnboardingUITests.swift:24 — Tests an DE-Labels gekoppelt, keine Sprache beim Launch gesetzt; nach C5 (EN vollständig) potenziell locale-abhängig — stabile Accessibility-Identifier + expliziter Sprach-Pin als Folge-Task; ob akut, entscheidet der Gate-3a-Beweislauf (Codex #3 Scope A F5)
- [minor] scripts/check-l10n.py:1 — leerer, aber wohlgeformter Katalog (`strings: {}`) passiert das Gate grün; Mindest-Key-Count als bewusste Scope-Entscheidung nachziehen (Infrafix, offener Punkt)
- [minor] docs/design/design-spec-onboarding.md:1 — §10/§11 und prototype-onboarding/handover.md beschreiben den alten Karte-4-Stand (In-Foto-Pille, Karte in Aktions-Gruppe); im Knowledge-incremental nach B2 nachziehen — bis dahin ist der Prototyp-Code die Wahrheit für Karte 4
- [major] ShipTrip/Views/Settings/SettingsView.swift:1 — 1071 Zeilen über Hard-Limit 500 (vorbestehend, B2 fügt nur 8 zu); Datei thematisch splitten (B2-Review F03)
- [minor] ShipTrip/Views/Onboarding/OnboardingModel.swift:123 — advance(from: 2) hartkodiert; Kartenzahl als Konstante ziehen (B2-Review F05)
- [minor] ShipTrip/Views/Onboarding/OnboardingFlowView.swift:152 — Onboarding-CTAs enden auf der Liste statt Formular/Detail direkt zu öffnen (Design-Narrative fordert Öffnen); Deep-Link-Naht Cover→CruiseListView als Folge-Task (B2-Review F06, Quality: Nicht-Blocker)

- [minor] scripts/check-l10n.py:82-88 — Verwaiste Substitutions-Referenz (`#@name@` ohne substitutions-Block) unerkannt (C5-Review iter2)
- [minor] scripts/check-l10n.py:84-87 — `stringUnit.state` ungeprueft: `state: "new"` mit DE-Text in `en` passiert das Gate (C5-Review iter2)
- [minor] scripts/check-l10n.py:59-64 — Nicht-Plural-Variations (z. B. `device`) ohne Pflicht-`other`-Zweig (C5-Review iter2)
- [minor] scripts/check-l10n.py:113 — Roher AttributeError-Traceback bei Nicht-Dict-Entry statt Fehlermeldung (C5-Review iter2)
- [minor] scripts/check-l10n.py:1-158 — Kein Regressionsnetz: Gate-Fixtures nur im Scratchpad, nicht im Repo (C5-Review iter2)
- [minor] .github/workflows/ci.yml:41,50 — Xcode-Version doppelt gepflegt (XCODE_APP-Pfad + XCODE_VERSION); Single Source ziehen, exakter Vergleich bricht bei Patch-Drift 26.6.1 (Infrafix-Review iter1)
- [minor] scripts/check-l10n.py:115 — `load_catalog() -> dict` ohne Typargumente (mypy --strict type-arg) (Infrafix-Review iter1)
- [major] ShipTripTests/OnboardingModelTests.swift:66-89 — Helfer `coverIsPresented` bildet `ShipTripApp.init` nach statt sie zu prüfen; Glue (Schreiben-vor-@AppStorage-Lesen, storeIsHealthy-Abbildung, Fetch) untestet → nach `OnboardingPresentation.resolveAtStartup(...)` ziehen (Gate3a F01)
- [minor] ShipTrip/ShipTripApp.swift:119 — `hasExistingCruises` ohne `isDemo`-Prädikat; heute nicht auslösbar, kippt sobald Demo-Daten vor Onboarding-Abschluss persistieren (Gate3a F02)
- [minor] ShipTrip/Views/Onboarding/OnboardingModel.swift:202 — `advance(from: 2)` bedingungslos; ein Wisch während des laufenden Reconcile wird überschrieben (Gate3a F03)
- [minor] ShipTrip/Views/Onboarding/OnboardingModel.swift:198-202 — Reconcile läuft vor `advance`; Flow steht bei großer Reisen-Liste sichtbar mit gesperrten Tasten (Gate3a F04)
- [minor] ShipTrip/ShipTripApp.swift:104 — CloudKit-Neugerät: Store beim Launch-Snapshot leer, Bestandsnutzer sieht das Onboarding einmal; als bewusste Konsequenz dokumentieren (Gate3a F05)
- [minor] ShipTrip/Views/Onboarding/OnboardingModel.swift:39 — „Intro erneut zeigen" ist in einer Postpone-Sitzung (In-Memory-Fallback) ein stiller No-Op (Gate3a F06)
- [minor] ShipTripUITests/OnboardingScreenshotTests.swift:89 — Kommentar verspricht Fehler bei unbekannter Sprache, Code wirft XCTSkip; Verhalten und Kommentar angleichen (Gate-6-Review)

## Fix-Runde Onboarding (Review iter1, 2026-08-24)
- [major] ShipTripUITests/OnboardingSampleTripUITests.swift:39 — Repro-Test nur mit `-uiTestingResetOnboarding`; im Voll-Suite-Lauf steht „Norwegische Fjorde" aus früheren Klassen schon im geteilten Store → false-green. DEBUG-Naht `-uiTestingEmptyStore` ergänzen (F01)
- [minor] ShipTrip/ShipTripApp.swift:223 — `.modelContainer` muss äußerster Modifier bleiben, nur per Kommentar geschützt; robuster an der Scene statt am Inhalt (F02)
- [minor] ShipTrip/Views/Settings/SettingsView.swift:1 — jetzt 1106 Zeilen (war 1067), weiter über Hard-Limit 500; DataManagementView + CalendarSyncSettingsView herausziehen (F05, ersetzt die alten 977/1010-Zeilen-Einträge)
- [minor] ShipTripTests/CalendarSyncServiceMigrationTests.swift:20 — 4 Tests hängen an der ambienten EventKit-Berechtigung des Simulators (rot auf frischem Wegwerf-Klon); EventKit-Naht injizierbar machen (F06)

## Fix-Runde Reset-Komplettierung (Review iter1, 2026-08-25)
- [major] ShipTrip/Utilities/AppPreferencesReset.swift:1 — kein Unit-Test für AppPreferencesReset; `run(in:)` ist injizierbar, Test-Stub liegt im Review-Report (F03)
- [major] ShipTrip/Views/Settings/SettingsView.swift:1078 — Keychain-Löschung beim Reset ohne eigenständigen Test (nur umgelegtes Flag auf produktivem `deleteAllData`-Pfad); bräuchte DEBUG-Naht zum Key-Vorbelegen (F04)
- [minor] ShipTrip/Utilities/AppPreferencesReset.swift:12 — Literal-Allowlist: künftige Präferenz-Keys fallen beim Reset still durch; Registry/Konvention überlegen (F05)
- [minor] ShipTripUITests/AppResetUITests.swift:1 — zwei Test-Suites in einer Datei; `-only-testing` auf Klassenebene verwirft die zweite still (F06)

## Fix-Runde Reset-Komplettierung (Review iter2, 2026-08-25)
- [minor] ShipTrip/Views/Settings/SettingsView.swift:865 — Alert und Footer von „App zurücksetzen" nennen die Kalender-Aufräumung nicht; Halbsatz DE+EN ergänzen (G01)
- [minor] ShipTrip/Utilities/AppReset.swift:28 — bei entzogenem Kalenderzugriff wirft `removeAllManagedEvents` vor `managedEventIdentifiers = [:]`, `try?` schluckt es → verwaiste Termin-Zuordnung überlebt den Reset (G02)
- [minor] ShipTrip/Utilities/AppReset.swift:27 — Produktions-Verdrahtung `.shared`/`.standard` nicht behavioral gedeckt (Test injiziert Fixture) (G03)

## Re-Review Reset-Komplettierung (iter2, 2026-08-25)
- [minor] ShipTrip/Views/Settings/SettingsView.swift:865 — Alert/Footer nennen die Kalender-Aufräumung beim Reset nicht (Daten außerhalb der App) (G01)
- [minor] ShipTrip/Utilities/AppReset.swift:28 — ohne Kalenderzugriff wirft removeAllManagedEvents vor dem Mapping-Reset; try? schluckt es → verwaiste Zuordnung überlebt den Reset (G02)
- [minor] ShipTrip/Utilities/AppReset.swift:27 — Verdrahtung .shared/.standard nicht behavioral gedeckt (G03)

## Fix-Runde Navigation-nach-Reset (Review iter1, 2026-08-25)
- [major] ShipTripUITests/AppResetUITests.swift:128-131 — Assertion laeuft auf dem Reisen-Tab und beweist den Settings-Stack-Neuaufbau nicht; ohne `.id(settingsIdentity)` bliebe der Test gruen. Nach dem Reset „Mehr" antippen und `navigationBars["Einstellungen"]` pruefen (F01)
- [minor] ShipTrip/Utilities/AppReset.swift:39 — `run` postet jetzt global; Dateikopf (:5-8) verspricht weiter eine „UI-freie" Stelle, CalendarSyncServiceMigrationTests.swift:101 loest den Post mit aus (F02)
- [minor] .winston-evidence/20260825T184959Z/gate-run.json — Gruen-Artefakt traegt den Repro-Commit c4e4e27 statt b570ada (Lauf 18 s vor dem Commit); erst committen, dann Gruen fahren (F03)
- [minor] ShipTrip/Views/Settings/SettingsView.swift:1079-1082 — `resetApp` ohne Doppel-Tap-Nachgarde, anders als exportData:930 / handleImport:968 (folgenlos, weil idempotent) (F04)

## W0 Naht-Seed „Kreuzfahrt teilen" (Review iter1, 2026-08-25)
- [minor] ShipTrip-Info.plist:14 — UTTypeDescription/CFBundleTypeName nicht lokalisiert (InfoPlist.strings DE/EN)
- [minor] ShipTrip-Info.plist:20 — public.mime-type-Tag am UTI fehlt; vor W3-Abnahme evaluieren (Seed-Änderung → über Winston)

## W1 Share-Export (Quality-Review iter1, 2026-08-25)
- [minor] ShipTripTests/ShareImageTranscoderTests.swift:121 — EXIF-/TIFF-Fixture-Vorbedingung ungesichert; nur GPS beidseitig bewiesen (F01)
- [minor] ShipTripTests/ShareExportTests.swift:207 — #expect(throws: ShareExportError.self) unterscheidet die drei Fehlerfälle nicht (F02)
- [minor] ShipTrip/Services/ExportImportService+ShareExport.swift:70 — Guards maxExpenses/maxPhotos ungetestet, nur maxPorts (F03)
- [minor] ShipTrip/Services/ExportImportService+ShareExport.swift:171 — unerreichbarer Guard wirft .limitExceeded, falsches Fehler-Vokabular (F04)
- [minor] ShipTrip/Services/ExportImportService+ShareExport.swift:270 — Slug kann nach 60-Zeichen-Deckel auf „-" enden; Trimmung läuft vor prefix (F05)
- [minor] ShipTrip/Services/ExportImportService+ShareExport.swift:177 — appVersion-Fallback „1.0" behauptet falsche Version (F08)
- [minor] ShipTrip/Services/ExportImportService+ShareExport.swift:51 — Kommentar dreht die Aktor-Richtung um (F09)

## W2 Import-Flow (Quality-Re-Review iter2, 2026-08-25)
- [minor] ShipTrip/Views/Settings/SettingsView.swift:1012 — manueller .shiptrip-Import zeigt keinen Versionskonflikt-Hinweis (contract-konform per C6, erst durch B1 erreichbar) (F01)
- [minor] ShipTrip/Services/ExportImportService+ShareImport.swift:78 — Share-Transportdeckel greifen nur am Share-Einstieg; manuell deckt ZipArchiveReader + Zählgrenzen (bewusste C10-Aufteilung) (F02)
- [minor] ShipTripTests/ShareImportPreflightTests.swift:257 — B1-Test prüft die Funktion, die fileImporter-Verdrahtung nur statisch belegt (F03)

## W3 Teilen-UI (Dev-Return, 2026-08-25)
- [minor] ShipTrip/Views/Cruises/CruiseDetailView.swift:1 — 679 Zeilen über dem 500er-Hard-Limit (vorbestehend, +15 durch W3; Teilen-Logik bereits ausgelagert) — Refactoring als eigener Auftrag

## W3 Teilen-UI (Quality-Review iter1, 2026-08-25)
- [major] ShipTrip/Views/Cruises/CruiseShareAction.swift:85 — kein Unit-Test für shareFailureReason (hält den „Backup abgebrochen"-Wortlaut aus dem Teilen-Kontext; rein/static, trivial testbar) (F01)
- [minor] ShipTrip/Views/Cruises/CruiseShareAction.swift:36 — unstrukturierter Export-Task nicht an View-Lebensdauer gebunden; verwaister share-<UUID>-Temp-Ordner bei Navigation während des Exports (System räumt) (F02)
- [minor] ShipTrip/Views/Cruises/CruiseShareAction.swift:59 — finish() (Temp-Hygiene F07) ohne Testabdeckung (F03)
- [minor] ShipTrip/Views/Cruises/CruiseShareAction.swift:1 — 5 Zeilen über 100 Zeichen (F04)

## Codex Final-Gate #3 „Kreuzfahrt teilen" (2026-08-25)
- [major] ShipTrip/Views/Share/ShareImportCoordinator.swift:44 — während .importing eintreffende zweite Datei wird vor Routing/Cleanup verworfen; ihre Inbox-Kopie bleibt liegen (Storage-Leak im Race-Randfall, kein Datenverlust)
- [minor] ShipTrip/Utilities/IncomingLinkRouter.swift:47 — Router akzeptiert Pfad/Query/Fragment-Varianten von shiptrip://import als importHint; Vertrag C3 definiert nur die parameterlose URL (harmlos: zeigt nur den Hinweis)

## Run 1.8.5 Welle 1 (Triage 2026-08-27)

- [major] ShipTrip/Views/Cruises/CruiseFormView.swift:1 — nach D2-Split noch 950 Zeilen (>500 Hard-Limit); Restmasse processAIImport (~170), saveCruise (~145), Form-body — eigener Folge-Task (T4-Empfehlung)
- [minor] ShipTrip/Models/PortSuggestion-Daten — Wikidata-Datenmüll „Antikes Athen", „Byzantinisches Reich", „Britisch-Hongkong" ohne ISO-Code; separate Datenbereinigung (T3-Befund)
- [minor] docs/adr/README.md:1 — Fußtext-Stale-Reservierung „C2→004" nach ADR-004-Annahme; beim Merge nachziehen (T2-Befund)
- [minor] ShipTrip/Views/Cruises/PortFormView.swift:1 — EN-Gerät: Vorschlagsliste zeigt lokalisierten Ländernamen, Land-Feld danach den DE-Rohwert; Code-Feld auf Port im ADR-008 verworfen (T3-Naht)
- [minor] ShipTrip/Services/CalendarEventPlanner.swift:115 — Kalender-Event-Ort nutzt weiter den DE-Bestandsnamen statt PortCountryCatalog.localizedName; siebte Anzeigestelle, in ADR-008 Entscheidung 5 nicht erfasst (D1-Befund F01)
- [major] ShipTrip/Views/Cruises/HafenMomenteSection.swift:44-46 — onChange(selectedPhotoItem) haengt an der Section statt an coverPhotoTile; Modifier wird je Zeile durchgereicht → mehrfacher loadTransferable pro Foto-Auswahl (idempotent, aber N-facher Decode). Quelle: quality-review-d2-formview-split-iter1.md F01
- [minor] ShipTrip/Views/Onboarding/OnboardingCards.swift:147 — stale Doku-Referenz CruiseFormView.ReminderPermissionSheet (Typ ist nach D2 Top-Level)
- [minor] ShipTripTests/JournalExportLegacyCompatibilityTests.swift:158 — Golden-Fingerprint fuer journallose Reise pinnen (T7b F01)
- [minor] ShipTrip/Services/ExportImportService+JournalImport.swift:52 — entryDate ohne Millisekunden wird still verworfen (T7b F02)
- [minor] ShipTrip/Services/ExportImportService+JournalImport.swift:69 — updatedAt < createdAt moeglich bei unparsbarem createdAt (T7b F03)
- [minor] ShipTripTests/JournalExportLegacyCompatibilityTests.swift:18 — Force-Unwrap im Test-Fixture (T7b F04)
- [minor] ShipTripTests/RouteJournalPlannerTests.swift:247 — westliche Zeitzonen-Gegenprobe (UTC-11) ohne Unterscheidungskraft; auf Etc/GMT+12 umstellen und als Rand-Stabilitaetsprobe benennen (T8a F01)
- [minor] ShipTripTests/RouteJournalPlannerTests.swift:132 — Fall „verwaiste portID UND kein Stopp traegt den Tag → Sammelblock" (J3neu (a) Regel 4) ungetestet (T8a F02)
- [minor] ShipTripTests/RouteJournalPlannerTests.swift:200 — id-Tiebreak nur auf Stabilitaet, nicht auf Richtung geprueft (T8a F03)
- [minor] ShipTrip/Views/Cruises/JournalExcerpt.swift:34 — zweite J3neu-(c)-Regel „Datum nur bei Abweichung vom arrival-Tag" nicht als reine Funktion extrahiert; T8b muss RouteDayKey nutzen (T8a F04)
- [minor] ShipTrip/Views/Cruises/RouteJournalPlanner.swift:46 — Vorbedingung „stops = vollstaendige Route" des Verwaist-Fallbacks nicht dokumentiert (T8a F05)
- [minor] .winston-evidence/20260827T123855Z/gate-run.json — Dev-Evidenz pinnt Basis-Commit 65c5f32 statt Feature-Commit; Prozessregel „erst committen, dann evidence.py" (T8a F06)
- [minor] ShipTrip/Views/Cruises/CruiseDetailView.swift:1 — 615 Zeilen ueber 500er-Hardlimit (Vorbestand; T8b hat um 64 reduziert) — Split-Kandidat nach 1.8.5 (T8b)
- [minor] ShipTrip/Views/Cruises/RouteJournalSection.swift:111 — Mehrfach-Sortierung und CollapseDefaults.make() pro body-Auswertung; memoisieren (T8b F04)
- [minor] ShipTrip/Views/Cruises/RouteJournalEntryRow.swift:182 — Tageswechsel-Reset via RunLoop.main statt DispatchQueue.main (T8b F06)
- [minor] ShipTrip/Views/Cruises/RouteJournalSection.swift:144 — toggleAll-Pfad ohne Testabdeckung (T8b F07)
- [minor] ShipTrip/Views/Cruises/RouteStopCard.swift:44 — Vorbelegungs-Tag der Plus-Aktion nur implizit ueber Port transportiert (T8b F08)
- [major] ShipTrip/Views/Cruises/JournalEntryEditorView.swift:301-367 — J2a-Orchestrierung in save() untestbar/untestet (Diff-Plan extrahieren)
- [minor] ShipTrip/Views/Cruises/JournalEntryEditorView.swift:74 — Prefill-Hafen wird beim Datumswechsel überschrieben (J2-konform, UX-Frage)
- [minor] ShipTrip/Views/Cruises/JournalEntryEditorView.swift:187 — hartes .red statt Theme-/Rollenfarbe am Entfernen-Icon
- [minor] ShipTrip/Views/Cruises/JournalEntryDetailView.swift:90-94 — .sheet ohne else-Zweig: leeres Sheet bei entry.cruise == nil
- [major] ShipTrip/Views/Cruises/JournalEntryEditorView.swift:301 — J2a-Orchestrierung in save() ist private View-Logik ohne Test; vertauschter Tag-Vergleich bliebe gruen — testbar extrahieren (T8c F02)
- [minor] ShipTrip/Views/Cruises/JournalEntryEditorView.swift:74 — Prefill-Hafen zaehlt nicht als manuelle Wahl (contract-konform, Restrisiko Stopp-Einstieg) — Produktfrage (T8c F03)
- [minor] ShipTrip/Views/Cruises/JournalEntryEditorView.swift:187 — hartes .red statt Semantik-Token (T8c F04)
- [minor] ShipTrip/Views/Cruises/JournalEntryDetailView.swift:90 — .sheet-Pfad ohne else-Behandlung (T8c F05)
- [major] ShipTrip/Views/Cruises/CruiseFormView.swift:792 — JournalDeletePaths.deletePhoto-Bindung ohne Test (T9d F01)
- [major] ShipTrip/Views/Cruises/CruiseFormView.swift:1-986 — 986 Zeilen, ueber 500-Zeilen-Hardlimit (Bestand 954, +32 durch Foto-Race-Fix; T9d F02)
- [minor] ShipTripUITests/JournalRouteFadenUITests.swift:133-142 — value-Assertion direkt nach tap() ohne XCTNSPredicateExpectation (T9d F03)
- [minor] ShipTripUITests/JournalRouteFadenUITests.swift:96,210,239,254 — deutsche Label-Anker brechen unter EN-Locale (T9d F04)
- [minor] ShipTrip/Views/Cruises/RouteStopCard.swift:127,145,160 — A11y-Identifier aus port.name: mehrere Seetage kollidieren (T9d F05)
- [minor] ShipTrip/Services/DemoDataService.swift:78 — letzter direkter Photo-Delete am JournalDeletePaths-Vertrag vorbei (T9d F06)
- [minor] .planning — T8d-1 gate-run.json: leeres build.log (-quiet), tool_versions leer (T9d F07)
- [minor] ShipTrip/Views/Cruises/RouteJournalSection.swift:44-46 — leere Route ohne Journal-Erfassungs-Einstieg (Produkt-Luecke, T9d)
- [minor] docs/umsetzungsplan-audit-2026-07.md:159 — nennt noch "Tagebuch-Strang" (Doku-Altlast nach J3neu, T9d)
- [minor] ASO — Review-Prompt (SKStoreReviewController) nach abgeschlossener Reise für 1.8.x/1.9: wirksamster Hebel gegen Ranking-Schwäche bei 4 Bewertungen (ASO-Runde 2026-08-27, Andre: Später/Backlog)
- [minor] ShipTrip/Views/Cruises/RouteJournalSection.swift:177 — todayAnchor: Zeitzonenwechsel kann vorgeschriebene Klapp-Uebersteuerungen bei Szenen-Reaktivierung ungeloescht lassen (Gate#3a)
- [minor] ShipTrip/Views/Cruises/JournalEntryEditorView.swift:83 — Bearbeiten-Pfad klemmt gespeicherten Eintragstag nicht auf nachtraeglich verkuerzten Reisezeitraum; DatePicker startet ausserhalb des Auswahlbereichs (Gate#3b, Hypothese)
- [minor] ShipTripUITests/JournalRouteFadenUITests.swift:294 — blinder swipeUp vor nur aufwaerts scrollendem scrollUntilHittable; redundant, kann ueberschiessen (Gate#3c F3)
- [minor] ShipTripUITests/JournalRouteFadenUITests.swift:9 — Header behauptet rein identifier-basierte Anker, tatsaechlich 19 deutsche Label-/Value-Anker (Gate#3c F2, s. T9d F04)
- [major] ShipTrip/Views/Cruises/JournalEntryEditorView.swift:304 — photoLoadsInFlight-Lebenszyklus ohne Testabdeckung (Fix-Review F01)
- [minor] ShipTrip/Views/Cruises/JournalEntryEditorView.swift:307 — photoLoadFailed kann bei ueberlappenden Picker-Runden wiederbelebt werden (Fix-Review F03)
- [minor] ShipTrip/Views/Cruises/JournalEntryEditorView.swift:153 — Fehlerhinweis verdraengt Pflichtfeld-Hinweis bei leerem Eintrag (Fix-Review F04)
- [minor] ShipTrip/Views/Cruises/JournalEntryEditorView.swift:403 — 403 Zeilen ueber Soft-Limit 400, Refactor bewusst vertagt (Fix-Review F05)
- [minor] .winston-evidence — build-for-testing -quiet erzeugt leeres build.log ohne Diagnosewert (Fix-Review F06)
- [minor] ShipTrip/Views/Cruises/CruiseFormView.swift:565 — Teil-Fehlschlag beim Foto-Laden: fehlgeschlagene Transfers fallen still raus, konkreter Fehler ungeloggt (1.8.6-Review)
- [minor] ShipTrip/Views/Cruises/CruiseFormView.swift:174 — photoLoadFailed ohne Reset beim Entfernen der Fotos (1.8.6-Review)
- [minor] ShipTripTests/CruiseFormSaveGateTests.swift:1 — Zaehler-Verdrahtung in CruiseFormView untestet, nur reine Gate-Funktion abgedeckt (1.8.6-Review)
- [minor] ShipTripUITests/JournalRouteFadenUITests.swift:259 — 10s-Timeout aufs Hafen-Sheet flaked unter Last (1.8.6-UI-Gate)

## Andre-Wuensche Kalender-Sync (2026-08-29)

- [minor] ShipTrip/Services/CalendarSyncService.swift — Sync-Umfang umdrehen: standardmaessig nur die einzelnen Stopps in den Kalender eintragen, NICHT mehr den Ganztages-Eintrag ueber die gesamte Reise; der Gesamtreise-Eintrag nur noch als explizite Opt-in-Auswahl in den Einstellungen (Andre 2026-08-29)
- [minor] ShipTrip/Services/CalendarSyncService.swift — Stopp-Eintraege mit echtem strukturiertem Ort versehen (EKEvent structuredLocation mit Koordinaten statt reinem Text-Feld), damit der Ort im Kalender anklickbar ist und Karte/Navigation oeffnet; Koordinaten liegen am Port bereits vor (Andre 2026-08-29)

## Kalender-Paket 1.8.7 — Q0 Wave 0 (Go-Live-Triage, 2026-09-02)

- [major] ShipTrip/Views/Settings/SettingsView.swift:1 — 730 Zeilen nach T0-Extraktion weiterhin über Hard-Limit 500; nächste Extraktion (ApiKeySheet/Datenschutz-Sektion) als eigener Refactor
- [major] ShipTrip/Services/CalendarSyncService.swift:232 — breite Marker-Suche kann bei zwei Geräten mit unterschiedlichen Zielkalendern Termine hin- und herschieben (Prefs nicht geräteübergreifend; Vorbestand über Umhängen, jetzt über Journal)
- [minor] ShipTrip/Services/CalendarSyncService.swift:27 — tote statische Preferences-Shims ohne Aufrufer nach T3
- [minor] ShipTrip/Services/CalendarSyncService.swift:71 — Journal-Drain im init löscht Kalendereinträge als Seiteneffekt; expliziter Aufruf wäre lesbarer
- [minor] .winston-evidence — Rot-Beweise T3 nur per Commit-Message/xcresult-Prosa belegt, kein eigenes Rot-Evidenz-Artefakt; evidence.py auch für Rot-Läufe fahren
- [minor] ShipTripTests/CalendarSyncHardeningTests.swift:44 — Double-Pfade failCommit/failRemove nie gefahren
- [minor] ShipTrip/Services/CalendarSyncService.swift:252 — Journal bleibt bei dauerhaft scheiterndem remove ewig gefüllt; Max-Versuche oder Verwerfen bei fehlendem Event
- [minor] ShipTrip/Services/CalendarSyncService.swift:106 — writableCalendars-Overload verwirrend benannt

## Kalender-Paket 1.8.7 — Q1a Wave 1 (Go-Live-Triage, 2026-09-02)

- [major] ShipTrip/Services/CalendarSyncService.swift:239-254 — Aufräumpfad für Ort stützt sich auf undokumentierte Kopplung location/structuredLocation (Apple-Doku sichert sie nicht zu); beide Felder explizit setzen/leeren
- [major] ShipTrip/Services/CalendarEventPlanner.swift:167 — Koordinaten-Plausibilität nur Null-Insel; NaN/Range-Filter wie MapMarkerPlanner:38-43 übernehmen
- [major] ShipTrip/Views/Settings/NotificationSettingsView.swift:91-99 — Reconcile-Tasks bei schneller Stepper-Bedienung nicht serialisiert, veralteter Lauf kann gewinnen; Task-Cancel oder Debounce
- [major] ShipTripTests/NotificationSettingsReconcileTests.swift:19-34 — Test prüft die extrahierte Funktion, nicht die onChange-Verdrahtung; bleibt grün, wenn onChange fehlt (Verdrahtung nur per XCUITest beweisbar)
- [major] ShipTripTests/CalendarMigrationCoordinatorTests.swift:38-59 — Rollback-Test trifft die calendarMissing-Guard, nicht den Teilabbruch nach begonnenem Anlegen
- [major] ShipTrip/Services/CalendarSyncService.swift:272-276 — Restore ohne Mapping: alter Ganzreise-Termin bleibt als Karteileiche im Kalender und die Bestands-Migration erkennt ihn nicht (wählt itineraryOnly); Marker-Suche auch für die Migrations-Entscheidung nutzen, als Limitation dokumentiert
- [minor] ShipTrip/Services/CalendarSyncService.swift — unnötiger Kalender-Scan im Migrationspfad (Q1a F08)
- [minor] ShipTrip/Services/CalendarMigrationCoordinator.swift — Rollback-Fehler im Erfolgsfall des Restores verworfen (Q1a F09)
- [minor] ShipTrip/Services/CalendarEventPlanner.swift:18 — Fallname `none` kollidiert lesbar mit Optional.none; `off` erwägen (Q1a F10)
- [minor] ShipTrip/Services/CalendarSyncService.swift — `none`-Modus räumt alle verwalteten Events ab, service-seitig ungetestet

## Kalender T5 (Quality-Review iter1, 2026-09-02)
- [major] ShipTrip/Views/Settings/CalendarSyncSettingsView.swift:270-275 — Migration laeuft erst im `.task`, Kommentar behauptet „vor der Anzeige"
- [major] ShipTrip/Views/Settings/CalendarSyncSettingsView.swift:154-160 — Umfangs-Schalter vor der Bestands-Migration bedienbar, Wahl auf falscher Basis moeglich
- [major] ShipTripUITests/KalenderUmfangUITests.swift:60-70 — Relaunch-Pruefung deckt nur den Trip-Schalter ab, `tripOnly` fiele nicht auf
- [major] ShipTripUITests/KalenderUmfangUITests.swift:26-77 — Test nicht hermetisch: kein Praeferenz-Reset, Cleanup nicht in `tearDown`
- [minor] ShipTrip/Views/Settings/CalendarSyncSettingsView.swift:104 — doppelter Sync pro Tap (View + CalendarSyncObserver)
- [minor] ShipTrip/Services/CalendarEventPlanner.swift:14-20 — `CaseIterable, Identifiable` und `id` verwaist
- [minor] ShipTrip/Views/Settings/CalendarSyncSettingsView.swift:149 — inkonsistente Deaktivierung bei Sync-aus (Zielkalender aus, Umfang an)
- [minor] ShipTripUITests/KalenderUmfangUITests.swift:103-105 — Koordinaten-Tap dx 0.9 statt Element-Tap
- [minor] .winston-evidence/20260902T144947Z/gate-run.json:4 — Evidenz-Commit `aec5263` != geprueftem Stand `c33d9df`
- [minor] ShipTrip/Localizable.xcstrings — EN „Add stops" bricht die Title-Case der Nachbar-Strings

## Kalender-Paket 1.8.7 — Codex Gate #3 (Go-Live-Triage, 2026-09-02)

- [major] ShipTrip/Services/CalendarSyncService.swift:176-189 — Crash nach Anlegen-Commit, aber vor Journal-Schreiben: ändern sich vor der Recovery die Reisedaten, liegt das Zielevent außerhalb des ±1-Tag-Suchfensters und die Marker-Recovery legt ein dauerhaftes Duplikat an; Marker-Suche mit vom Draft-Zeitfenster unabhängigem Horizont (Codex Scope A)
- [minor] ShipTrip/Views/Settings/CalendarSyncSettingsView.swift:1 — 407 Zeilen über Soft-Limit 400; CalendarSyncOperationState + CalendarScopeAvailability in eigene Datei ziehen (FIX1)
- [major] ShipTrip/Views/Settings/CalendarSyncSettingsView.swift:196-200 — kein Test bewacht die Verdrahtung `.disabled(!isEditable)` der Umfangs-Schalter (FIX1-Review F03)
- [minor] ShipTrip/Views/Settings/CalendarSyncSettingsView.swift:57-63 — bei `.writeOnly`-Kalenderzugriff bleibt die Migration dauerhaft offen und die Fußnote „sobald der Kalenderzugriff erteilt ist" irreführend (FIX1-Review F04)
- [minor] ShipTrip/Utilities/AppReset.swift:36-38 — Reset ohne Kalenderzugriff lässt Mapping und Migrations-Marker stehen (vorbestehend, FIX1-Review F05)
- [major] ShipTrip/Views/Settings/CalendarSyncSettingsView.swift:375-380 — Freigabe der Umfangs-Schalter nach Zugriffserteilung in der Sitzung ist unbewacht; Rückbau bliebe grün (FIX2-Review F07)
- [minor] ShipTrip/Views/Settings/CalendarSyncSettingsView.swift:366-370 — Zugriff erteilt, aber kein Standardkalender: early return vor dem Neulesen, Fußnote behauptet fehlenden Zugriff (FIX2-Review F08)
- [minor] ShipTrip/Views/Settings/CalendarSyncSettingsView.swift:229-231 — kein scenePhase-Refresh der Sperr-Zustände nach Rückkehr aus den System-Einstellungen (FIX2-Review F09)
- [minor] ShipTripUITests/KalenderUmfangUITests.swift:31-37 — UI-Test-Reset lässt das Termin-Mapping stehen (FIX2-Review F10)
- [minor] ShipTrip.xcodeproj/project.pbxproj:BF1F290E — Widget 1.9.0: neue WidgetShared-Dateien werden nicht automatisch Widget-Target-Mitglied, jede muss in membershipExceptions nachgetragen werden (Quality W1 F06)
- [minor] ShipTripTests/WidgetSnapshotPublisherTests.swift — Widget 1.9.0: Snapshot nach Archiv-Import unbelegt, braucht ZIP-Fixture (T3)
- [major] ShipTripWidget/WidgetFormatting.swift:1 — Widget 1.9.0: Countdown-/Abstandstabelle ohne Unit-Tests, Drift gegen cruiseStartDescription möglich (Quality W2b)
- [major] ShipTripWidget/Views/RectangularWidgetView.swift:41-44 — Widget 1.9.0: Countdown im Rectangular zeigt nie den Reisetitel, ab XXL auch kein Startdatum (Quality W2b)
- [minor] ShipTrip/WidgetShared/WidgetTimelinePlanner.swift:33-34 — Widget 1.9.0: Idle-/Unavailable-Timeline nur [now, Mitternacht], minimumHorizon nur im Test genutzt (Quality W2b)
- [minor] ShipTrip/ShipTripApp.swift:293-322 — Widget 1.9.0: NSPersistentStoreRemoteChange-Trigger stützt sich auf Forum-Aussage (DTS, thread 761875), kein API-Vertrag; Gerätelauf mit zwei Geräten steht aus (Quality W2a)
- [major] ShipTrip/WidgetShared/WidgetSnapshotStore.swift:68-95 — Widget 1.9.0: Store validiert 64-KB-/3-Reisen-/40-Stopps-Grenzen weder vor Decode noch vor Save (Codex Gate #3 a1 F4; Publisher kappt schreibseitig)
- [minor] ShipTrip/WidgetShared/WidgetStateResolver.swift:195-205 — Widget 1.9.0: Fallbacks addieren feste 86400 s statt Kalenderrechnung bei Kalenderfehlern (Codex Gate #3 a1 F5)
- [minor] ShipTrip/WidgetShared/WidgetStateResolver.swift:167-173 — Widget 1.9.0: Eintrag am heutigen Kalendertag gilt vor seiner Ankunft bereits als aktueller Stopp (ZIEL-K1-Regel, bewusst; Codex a1 F2 sieht das als zu früh — Produktentscheid ausstehend)
- [minor] ShipTrip.xcodeproj/project.pbxproj — Widget 1.9.0: Widget-Views/Formatting/Fixtures sind für den Screenshot-Harness Mitglied des App-Targets und landen als toter Code im Release-Binary; Harness-Galerie selbst ist #if DEBUG (T5b)
- [major] ShipTrip/Services/WidgetSnapshotPublisher.swift:105-153 — Widget 1.9.0: Auswahl und 40er-Fenster nutzen Calendar.current; nach Zeitzonenwechsel bis zum nächsten Publish falsches Fenster möglich (Codex a2 F4)
- [major] ShipTrip/Services/WidgetSnapshotPublisher.swift:166-184 — Widget 1.9.0: 64-KB-Budget wird bei langen Textfeldern nicht erzwungen, kein Bytebudget/Feldkappung (Codex a2 F5)
- [minor] ShipTrip/Services/WidgetSnapshotPublisher.swift:87-117 — Widget 1.9.0: Fetch/DTO-Mapping komplett auf MainActor, Worst-Case-Latenz ungemessen (Codex a2 F6)
- [minor] ShipTrip/Services/WidgetSnapshotPublisher.swift:103-113 — Widget 1.9.0: Reload-Gate zählt Versuche statt angenommener Writes (Gate3-Re-Review)
- [minor] ShipTripTests/WidgetStateResolverTests.swift — Widget 1.9.0: Fall now == departure am letzten Stopp (isAfterLastStop) untestet (Gate3-Re-Review N5)
- [minor] ShipTrip/WidgetShared/WidgetTimelinePlanner.swift:78-90 — Widget 1.9.0: Auffüllung mit Mitternachten läuft vor dem 12er-Deckel, ferne Kandidaten können verdrängt werden (Gate3-Re-Review)

## Kreuzfahrt teilen — Fix-Run .shiptrip-Datei oeffnen (2026-09-10)

- [minor] ShipTrip-Info.plist — Keine Share-Extension (`com.apple.share-services`, `NSExtensionActivationSupportsFileWithMaxCount`): ShipTrip erscheint nicht im Teilen-Sheet der Dateien-App, iMessage bietet fuer den `.shiptrip`-Anhang nur „Weiterleiten"; Umweg ueber Dateien-App noetig
- [major] ShipTripTests/ShareExportTests.swift:1 — `-only-testing`-Pfade müssen Swift-Testing-Typnamen statt Dateinamen verwenden, sonst laufen Suites still nicht (Gate-Befehle prüfen)
- [major] ShipTrip/Views/Share/ShareImportCoordinator.swift:99 — Test deckt nur `shouldRemoveAfterImport`, nicht den `defer`-Löschpfad; Integrationstest mit In-Place-URL nachziehen
- [minor] ShipTrip/ShipTripApp.swift:294 — Ergebnis-Sheet-Getter hängt am Cover-Binding; entkoppeln, falls Onboarding-Präsentation umgebaut wird

## Share-Extension — Gate #4 Architektur (Go-Live-Triage, 2026-09-10)

- [minor] docs/architecture/contracts/share-extension-handoff.md:1 — `public.file-url`-Fallback in der Aktivierungsregel nur, falls iMessage den Anhang nicht mit dem exportierten UTI registriert (Geraetetest entscheidet)
- [minor] docs/architecture/contracts/share-extension-handoff.md:1 — Zweite geteilte Datei bleibt bis zum 24-h-Cleanup im ShareInbox liegen (Scan importiert nur eine Datei pro Aktivierung)
- [minor] ShipTrip/Views/Share/ShareImportCoordinator.swift:1 — `.linkHint`-Sheet blockiert den ShareInbox-Scan bis zum Dismiss (bewusst, Single-Flight)
- [minor] ShipTrip/Views/Share/ShareImportCoordinator.swift:1 — Selbst-Teilen einer eigenen Reise erzeugt „bereits vorhanden"-Sheet statt stillem No-op
- [minor] ShipTripShare/ShareViewController.swift:1 — „Antippen der Mitteilung oeffnet ShipTrip" ist unverifiziert (keine Apple-Referenz gefunden); im Geraetetest pruefen, sonst Mitteilung entfernen
- [minor] ShipTripTests/ShareHandoffStoreTests.swift:1 — Single-Flight-Verhalten des Scans (Race zweier schneller Aktivierungen) hat keinen Test
- [minor] ShipTrip/ShipTripApp.swift:1 — 417 Zeilen ueber Soft-Limit 400 (Test-Build Share-Extension); Share-Handoff-Verdrahtung in eigene Datei ausgliedern
- [minor] ShipTripShare/ShareViewController.swift:155 — `closeTapped` ohne Doppeltipp-Schutz (completeRequest koennte zweimal feuern)
- [minor] ShipTripTests/ShareImportHandoffScanTests.swift:1 — Loeschung einer defekten Uebergabedatei nach fehlgeschlagenem Import ist untestiert (nur Erfolgspfad)
- [minor] ShipTrip/ShareShared/ShareHandoffStore.swift:1 — `Sendable` auf fall-losem Enum ist redundant
- [minor] ShipTrip/Views/Share/ShareImportResultSheet.swift:102 — Accessibility-Identifier `shareImport.resultSheet` landet auf Blattelementen statt auf einem Container; XCUITest findet nur via `descendants(matching: .any)`
- [minor] docs/adr/ADR-010-share-extension-app-group-handoff.md:1 — Tabellenzeilen ueber 100 Zeichen (auch adr/README.md:18, Contract-Tabellen)
- [minor][p3] ShipTrip/Utilities/Date+Extensions.swift:90 — Präzedenz-Bug in durationInDays (`?? 0 + 1` bindet als `?? 1`); Nebenbefund Run Reisedauer 2026-09-11
- [major][p2] ShipTrip/Views/Cruises/CruiseFormView.swift:1-1033 — 1033 Zeilen über Hard-Limit 500 (vorbestehend, Reisedauer +52); nächster Split-Schritt
- [minor][p3] ShipTrip/Utilities/CruiseDateTriad.swift:43-47 — `storedNights` wird ignoriert, persistiertes `nights` nie gelesen; Signatur vereinfachen
- [minor][p2] ShipTrip/Views/Cruises/CruiseFormView.swift:541,719,726 — `isProgrammaticDateChange` bleibt hängen, wenn Load/KI-Import den Wert nicht ändert (nächste Nutzeränderung ohne Dialog A)
- [minor][p3] ShipTrip/Views/Cruises/CruiseDatesSection.swift:154-159,202-207 — Speichern in der 0,5-s-Ruhephase / Start-Änderung im 350-ms-Fenster überspringt Dialog A bzw. B
- [minor][p3] ShipTrip/Views/Cruises/CruiseDatesSection.swift:62-116 — drei confirmationDialogs im Body (SourceKit-Type-Check-Warnung); in ViewModifier ziehen
- [minor][p3] ShipTrip/Views/Cruises/CruiseDatesSection.swift:217,229-231 — Abbrechen-Revert und `.moveStart` nicht per UI-Test beobachtet; dauerhaften XCUITest für die Dialogkette anlegen
- [minor][p2] ShipTripWidget/Views/WidgetStyle.swift — Widget-Politur: Kontrast der Versal-Labels (Hafenschild: #C7D4E4 auf Navy; Brückenpult: hellste Grau-Stufe auf Creme) im Ausbau messen, ≥ AA sicherstellen (Gate-Hinweis K4)
- [minor][p3] ~/.claude/skills/design-phase/references/benchmark-shots.md — Store-Scrape tot (apps.apple.com JS-Shell); Ersatz itunes lookup + /9999x0w.png dokumentieren; Shoot-Spec: SHIPTRIP_SCREENSHOT_DIR muss via patched .xctestrun + `-xctestrun` laufen (Winston-Skill-Pflege)
- [minor][p2] ShipTripWidget/Views/SmallWidgetView.swift:159 — Countdown-Label „Noch"/„In" steht doppelt über dem vollen Wortlaut („Noch" über „Heute!"/„In ca. 3 Wochen"), wenn countdownParts nil liefert; Label in den nil-Fällen ausblenden (Widget Dynamic Instrument, 2026-09-13)
- [minor][p3] ShipTripWidget/Views/CircularWidgetView.swift — Idle zeigt statischen Vollring statt Fortschritt; Gate r2 „vertretbar" (2026-09-13)
- [major][p2] ShipTripWidget/WidgetFormatting.swift:175-228,258-281 — countdownParts/sinceLastCruise duplizieren die Schwellen von countdown()/lastCruise() ohne Test, der sie zusammenhaelt
- [minor][p2] ShipTripWidget/Views/MediumWidgetView.swift:1-458 — 458 Zeilen ueber Soft-Limit 400, Countdown-Teil in eigene Datei ziehen
- [minor][p2] ShipTripWidget/Views/MediumWidgetView.swift:125 — Schiffsname weicht dem Land des aktuellen Stopps (ZIEL K5 fuehrt Schiff als Pflichtinhalt)
- [minor][p3] ShipTripWidget/WidgetFormatting.swift:288-290 — taglineActive deklariert und lokalisiert, aber nie verwendet
- [minor][p3] ShipTripWidget/Views/WidgetStyle.swift:92 — WidgetSymbol.place neu eingefuehrt, nie verwendet
- [minor][p3] ShipTripWidget/Views/MediumWidgetView.swift:285-292,373 — Leerband in der unteren Kachelhaelfte bei medium-countdown XXL und medium-idle

## App-Store-Release 1.9.0 (Store-Gate, 2026-09-14)

- [major][p1] marketing/release-1.9.0/app-store-connect/metadata/de-DE/keywords.txt — Reederei-Marken aida/msc/costa: Restrisiko 2.3.7 bewusst entscheiden
- [minor][p2] marketing/release-1.9.0/app-store-connect/screenshots/*/0{1,3,4,5}-*.png — Footer „VERSION 1.7" beim nächsten Screenshot-Refresh angleichen
- [minor][p3] marketing/release-1.9.0/app-store-connect/screenshots/*/02-widgets.png — Lock-Screen-Panel-Label linksbündig wie Home-Panel
- [minor][p3] marketing/release-1.9.0/app-store-connect/screenshots/en-US/02-widgets.png — EN-Fixture mit englischen Reisenamen rendern
- [major][p2] ShipTripWidget/Views/WidgetStyle.swift — Light-Variante der Widgets: Home-Screen-Familien zeigen heute auch im hellen Erscheinungsbild den Navy-Grund (Dark-Only-Look); eine echte helle Fassung ist nötig (Andre, 2026-09-14)
