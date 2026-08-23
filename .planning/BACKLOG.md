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
