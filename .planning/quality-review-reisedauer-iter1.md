# Review — Reisedauer in Nächten (feature/reisedauer-naechte, 9b3bc33 vs. 186bf5f)

- **Iteration**: 1 / 3
- **Reviewer**: quality-agent (T3, finales Gate, Runtime-Verifikation)
- **Date**: 2026-09-11
- **Verdict**: approve (GO-WITH-BACKLOG)
- **Stats**: critical: 0, major: 1, minor: 5 — blockers: 0, backlogged: 6
- **Statusstufe**: runtime-verifiziert (Wegwerf-Sim `ci-t3-gate`, iPhone 17 / iOS 26.5, Xcode 26.6)

## Summary
Diff (7 Dateien, Code 453 Zeilen + 181 String-Catalog, Tests 151) dient dem Ziel ohne Umweg: reiner
Reducer `CruiseDateTriad` (100 % Diff-Coverage), eigene Formular-Section mit Dialogkette A→B, additives
CloudKit-konformes Attribut, Kalender-Sync-Beweis über stabile Schlüssel. Volle Unit-Suite 654/654 grün
(`gate-run.json` Exit 0). Dialogkette, Ruhephase, Routen-Verschiebung, Stepper-Dialog und Upgrade
einer Bestandsreise im Simulator beobachtet (Screenshots). Keine Blocker.

## Evidenz
- Gate (final, sauber): `.winston-evidence/20260911T125811Z/gate-run.json` — build 0, tests 0, 654 Tests / 132 Suiten, Ergebnis `verified`.
  Kommandos: `xcodebuild build-for-testing … -only-testing:ShipTripTests -enableCodeCoverage YES` → `xcodebuild test-without-building … -resultBundlePath .winston-evidence/gate-tests.xcresult`.
- Vorläufe: `20260911T124505Z` (ohne Kalenderrecht: 15 Issues, alle `.notAuthorized`, neue Suite „Reisedauer" grün) · `20260911T124737Z` (Grant vor Neuinstallation: identisch rot) · `20260911T125629Z` (Grant nach Installation: tests 0; das Grant-Gate selbst 149, weil der Sim zwischen den Läufen von außen heruntergefahren war).
- **EventKit-Rot vorbestehend — Beweis**: Basis 186bf5f (eigener Worktree, eigenes DerivedData) im selben Sim, `CalendarMigrationCoordinatorTests` + `CalendarSyncModeMigrationTests`: ohne Recht Exit 65 / 7 Issues `.notAuthorized`; nach `xcrun simctl privacy <sim> grant calendar com.andre.ShipTrip` 12/12 grün. Der Grant muss **nach** der App-Installation gesetzt werden (Test-Kanon laut `CalendarMigrationCoordinatorTests.swift:13-14`). Kein Zusammenhang mit dem Diff.
- Diff-Coverage (diffcov.py, Basis 186bf5f, Schwelle 80 %):
  - Logik `CruiseDateTriad.swift` + `Cruise.swift`: **100,0 %** auf 59 Zeilen (Unit-Suite).
  - Views `CruiseDatesSection.swift` + `CruiseFormView.swift`: 0,0 % über Unit-Tests (SwiftUI-Body per Unit-Test nicht erreichbar — deshalb getrennt ausgewiesen), **87,7 %** auf 212 Zeilen über die Wegwerf-UI-Läufe (`ui-t3.xcresult`, `ui-t3b.xcresult`). Nicht getroffen: Abbrechen-Revert (`CruiseDatesSection.swift:217`), `.moveStart`-Pfad (`:229-231`).
  - Gesamt Unit-only: 40,9 % auf 359 Zeilen (Views-Anteil).
- Größen-Lint `guard.py sizes`: FAIL `CruiseFormView.swift` 1033 Zeilen (vorbestehend ~981, +52 im Diff) → F01.
- Build: 0 Warnungen in geänderten Dateien; SourceKit-Meldung zu `CruiseDatesSection.swift:101` reproduziert sich im realen Build nicht (4 Builds sauber) → F05 (Wartbarkeit).

## Simulator-Beobachtung (Wegwerf-XCUITest, entfernt)
| Fall | Screenshot | Gesehen |
|---|---|---|
| Route vorhanden, Start 11.09.→14.09. | `screens/01-dialogA.png` | Dialog A „Startdatum verschoben" genau einmal (sheets.count == 1, kein zweites A nach 1,5 s); Ende noch 18.09., Nächte 7 |
| „Enddatum mitverschieben" | `screens/02-dialogB.png` | Dialog B „Hafen- und Seetag-Daten um 3 Tage nach hinten verschieben?", Ende 21.09.2026, Nächte 7 |
| „Verschieben" | `screens/03b-form-route-shifted.png` | Hamburg 11.→14. Sept., Kiel 12.→15. Sept., Uhrzeit 15:18 erhalten |
| Speichern | `screens/04-detail-after-save.png` | Detail Zeitraum 14.09.2026–21.09.2026, 8 Tage |
| Ohne Route | `screens/06-no-route-no-dialogB.png` | Dialog A → Antwort → kein Dialog B (2 s), 14.09.–21.09., 7 Nächte |
| Stepper + | `screens/07-nights-dialog.png` | „Nächte geändert" mit Start-/Enddatum anpassen; Wert bleibt 7 bis zur Antwort |
| „Enddatum anpassen" / Abbrechen | `screens/08-after-nights-end.png` | Nächte 8, Ende 19.09.2026, kein Dialog A; Dekrement+Abbrechen lässt 8 stehen |
| Upgrade-Smoke | `screens/05-upgrade-base-seeded.png`, `05-upgrade-edit-nights.png`, `05-upgrade-detail-after-save.png` | Basis-Build 1.9.0 (31) installiert + Beispielreise geseedet (Store ohne `nights`), Feature-Build darüber: Bearbeiten zeigt 02.10.–10.10.2026, **Nächte 8**, kein Dialog, Speichern ohne Fehler, Detail zurück |

Einschränkungen: Der Seetag-Button war für XCUITest nicht hittable (Koordinaten-Tap ohne Wirkung) — Route bestand aus zwei Häfen; `shiftRouteDates` iteriert alle `tempPorts` ohne Seetag-Unterscheidung, Seetag-Verschiebung durch `CalendarSyncPlannerTests` + `CruiseDateTriadTests` abgedeckt. Datumsänderung über den grafischen Picker (Tag antippen), nicht das Rad. CloudKit-Container-Rollout im Sim nicht prüfbar (wie geplant).

## Bewertung der fünf Entwickler-Abweichungen
1. Eigene Section „Reisezeitraum" — dient dem Ziel (Kopplung sichtbar gruppiert, Section lokalisiert). OK.
2. Dialog B 350 ms nach A — pragmatisch (UIKit verschluckt zwei Präsentationen im selben Zyklus); Timing-Hack, kein Umweg. OK, Restrisiko F04.
3. Richtung im Titel mit abs(N), Plural-Varianten DE/EN — besser als negatives N. OK.
4. Dialog B auch nach „Nächte anpassen" — ZIEL K3 knüpft B an „Route ≠ leer ∧ N ≠ 0", nicht an die Wahl; Start ist tatsächlich verschoben. OK.
5. Stepper schreibt erst nach Antwort — einfacher als Revert, im Sim bestätigt. OK.

## Findings

| ID | Severity | Blocker | File:Line | Category | Title |
|----|----------|---------|-----------|----------|-------|
| F01 | major | no | ShipTrip/Views/Cruises/CruiseFormView.swift:1-1033 | size | 1033 Zeilen über Hard-Limit 500 (vorbestehend, +52) |
| F02 | minor | no | ShipTrip/Utilities/CruiseDateTriad.swift:43-47 | api | `storedNights` wird ignoriert — persistiertes `nights` nie gelesen |
| F03 | minor | no | ShipTrip/Views/Cruises/CruiseFormView.swift:541,719,726 · CruiseDatesSection.swift:149 | correctness | `isProgrammaticDateChange` bleibt hängen, wenn die programmatische Setzung den Wert nicht ändert |
| F04 | minor | no | ShipTrip/Views/Cruises/CruiseDatesSection.swift:154-159,202-207 | correctness | Speichern in der Ruhephase / Start-Änderung im 350-ms-Fenster überspringt Dialog A bzw. B |
| F05 | minor | no | ShipTrip/Views/Cruises/CruiseDatesSection.swift:62-116 | readability | Body mit drei `confirmationDialog`s — SourceKit-Type-Check-Warnung, Build sauber |
| F06 | minor | no | ShipTrip/Views/Cruises/CruiseDatesSection.swift:217,229-231 | tests | Abbrechen-Revert und `.moveStart` im UI-Lauf nicht beobachtet (Reducer unit-getestet) |

### F01 — CruiseFormView über Hard-Limit
- **Problem**: 1033 Zeilen; der Diff lagert die Datumslogik korrekt in `CruiseDatesSection` aus, fügt aber netto 52 Zeilen hinzu.
- **Fix**: nächster Split-Schritt (Route-Section + AI-Import in eigene Dateien, analog D2-Review). Nicht Teil dieses Ziels.

### F02 — `storedNights` ignoriert
- **Problem**: `init(start:end:storedNights:calendar:)` berechnet `nights` immer neu; das persistierte Attribut ist reine Schreib-Nutzlast (ZIEL K1 verlangt das Feld, also kein Umweg — aber die Signatur täuscht eine Verwendung vor).
- **Fix**: Parameter entfernen (`init(start:end:calendar:)`), Backfill-Kommentar an den Aufrufer.

### F03 — hängender Programmatik-Merker
- **Problem**: Flag wird vor `startDate = …` gesetzt, aber nur im `onChange` zurückgesetzt. Ändert sich der Wert nicht (KI-Import liefert das bereits eingestellte Datum; `onAppear` läuft erneut), bleibt `true` — die nächste echte Nutzeränderung wird still übernommen, ohne Dialog A.
- **Fix**: nach den programmatischen Setzungen im selben Aufruf zurücksetzen, wenn sich nichts geändert hat: `if startDate == cruise.startDate && endDate == cruise.endDate { isProgrammaticDateChange = false }`.

### F04 — Zeitfenster der verzögerten Dialoge
- **Problem**: „Speichern" < 0,5 s nach der Datumsänderung speichert mit stehendem Ende (Invariante hält, Absicht ungefragt); Start-Änderung während der 350 ms vor B cancelt B, die erste Verschiebung geht für die Route verloren.
- **Fix**: `canSave` um `phase == .idle && pendingPromptTask == nil` ergänzen (Binding aus der Section), oder B über `.onChange(of: phase)` statt per Verzögerung präsentieren.

### F05 — drei Dialoge im Body
- **Fix**: die drei `confirmationDialog`-Modifier in einen `ViewModifier` (`DatePromptDialogs`) oder in `private var`-View-Hilfen ziehen.

### F06 — nicht beobachtete UI-Pfade
- **Fix**: keiner nötig für Go-Live; bei Gelegenheit dauerhaften XCUITest für die Dialogkette anlegen (Muster: `JournalRouteFadenUITests.oeffneNeueReise`), inkl. Abbrechen-Pfad.

## Go-Live-Triage
Kein Finding blockiert: kein Datenverlust (Invariante beim Speichern, Backfill beobachtet), kein Security-/GDPR-Scope (keine neue Datenverarbeitung außerhalb des Geräts), Gate grün. Alle sechs Findings → `.planning/BACKLOG.md`.
