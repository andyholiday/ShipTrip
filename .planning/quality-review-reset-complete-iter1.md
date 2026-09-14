# Review — Reset-Komplettierung (fix/reset-complete)

- **Iteration**: 1 / 3
- **Reviewer**: quality-agent (frischer Spawn)
- **Datum**: 2026-08-25
- **Prüfgegenstand**: Worktree `ShipTrip-worktrees/fix-reset-complete`, `3c0069a` → `b87aabf` → `92ac699` gegen `release/1.8.0` (`7d9d03d`)
- **Verdikt**: request-changes
- **Stats**: critical: 0, major: 4, minor: 2 — Blocker: 2, Backlog: 4

## Summary

Der Fix macht, was er behauptet: API-Key raus, Präferenzen raus, Onboarding-Flag als
`false` erhalten. Rot-Beweis und Grün-Beweis sind echt (Verhaltens-Assertion, kein
Compile-Fehler). Zwei Dinge blockieren die Abnahme: (1) der Reset schaltet die
Kalender-Spiegelung still ab und macht damit den bisherigen Aufräum-Pfad kaputt —
ShipTrip-Termine bleiben ab jetzt dauerhaft im Nutzer-Kalender stehen (Regression
gegenüber `7d9d03d`); (2) der Bestätigungs-Dialog verschweigt weiterhin, dass der
KI-API-Key unwiederbringlich gelöscht wird — genau die Aktion, für die der
Schwester-Pfad „Alle Daten löschen" einen eigenen zweiten Dialog aufmacht.

## Findings

| ID  | Sev   | Blocker | File:Line | Kategorie | Titel |
|-----|-------|---------|-----------|-----------|-------|
| F01 | major | **ja**  | ShipTrip/Views/Settings/SettingsView.swift:1078-1081 | correctness / Regression | Reset lässt Kalendertermine verwaist zurück |
| F02 | major | **ja**  | ShipTrip/Views/Settings/SettingsView.swift:885-892 | UX / Ehrlichkeit | Bestätigungs-Alert verschweigt Key- und Einstellungs-Löschung |
| F03 | major | nein    | ShipTrip/Utilities/AppPreferencesReset.swift:20-31 | tests | Keine Unit-Abdeckung für `AppPreferencesReset` |
| F04 | major | nein    | ShipTrip/Views/Settings/SettingsView.swift:1080 | tests | Keychain-Löschung im Reset-Pfad unverifiziert |
| F05 | minor | nein    | ShipTrip/Utilities/AppPreferencesReset.swift:23-27 | design | Allowlist aus String-Literalen — Drift-Risiko |
| F06 | minor | nein    | ShipTripTests/OnboardingModelTests.swift:30 | tests | `-only-testing` verwirft `OnboardingPresentationTests` still |

### F01 — Reset lässt Kalendertermine verwaist zurück
- **File**: `ShipTrip/Views/Settings/SettingsView.swift:1078-1081` (`resetApp`), Wirkung in `ShipTrip/Views/CalendarSyncObserver.swift:29-31`
- **Severity**: major · **Blocker: ja**
- **Problem**: Weder `deleteAllData` noch `resetApp` entfernt die per Sync angelegten
  EventKit-Termine. **Bisher** (`7d9d03d`) hat das der `CalendarSyncObserver`
  erledigt: Reisen gelöscht → `syncToken` ändert sich → `synchronize(cruises: [])` →
  `desiredKeys` leer → alle verwalteten Termine werden gelöscht und das Mapping
  geleert. **Neu** entfernt `AppPreferencesReset.run` synchron im selben Aufruf
  `CalendarSyncPreferences.enabledKey`; wenn der `.task(id:)` das nächste Mal läuft,
  greift `guard isEnabled` nicht mehr. Ergebnis: die Termine bleiben dauerhaft im
  Kalender des Nutzers stehen — nach einer Aktion, die „wie frisch installiert"
  verspricht. Das ist keine Altlast, sondern eine durch diesen Diff eingeführte
  Regression. Auch die zweite Aufräum-Tür ist zu: `removeAllManagedEvents()` hängt am
  Umlegen des Sync-Schalters (`SettingsView:514`) — der steht nach dem Reset bereits
  auf „aus". Die Mapping-Erhaltung des Devs mildert das nur theoretisch (Recovery nur,
  wenn der Nutzer Sync erneut aktiviert und denselben Kalender wählt).
- **Fix** (minimal, in `resetApp()` vor dem Präferenz-Reset):
  ```swift
  private func resetApp() {
      guard deleteAllData(alsoDeleteApiKey: true) else { return }
      try? CalendarSyncService.shared.removeAllManagedEvents()
      AppPreferencesReset.run(in: .standard)
  }
  ```
  Das löscht die Termine **und** leert das Mapping — die „Buchhaltung"-Begründung des
  Devs wird damit besser bedient als durch Stehenlassen. `try?` ist hier vertretbar
  (fehlender Kalenderzugriff darf den Reset nicht blockieren); der Kommentar sollte das
  benennen.

### F02 — Bestätigungs-Alert verschweigt Key- und Einstellungs-Löschung
- **File**: `ShipTrip/Views/Settings/SettingsView.swift:885-892`
- **Severity**: major · **Blocker: ja**
- **Problem**: Der Alert sagt weiterhin „Alle Kreuzfahrten und Wunschreisen werden
  gelöscht und das Intro startet neu." Tatsächlich wird jetzt zusätzlich der
  KI-API-Key aus der Keychain vernichtet und alle Einstellungen zurückgesetzt. Der
  Schwester-Pfad „Alle Daten löschen" hält die Key-Löschung für so gewichtig, dass er
  dafür einen **eigenen** Rückfrage-Dialog aufmacht (`:876-877`, `:893-897`) — im
  Reset-Pfad passiert dasselbe jetzt stillschweigend. Der Footer allein reicht nicht:
  die Einwilligung holt der Alert. Die Begründung „Katalog war gesperrt" trägt nicht —
  derselbe Commit hat den Footer-String in `Localizable.xcstrings` geändert, und der
  Alert-String liegt dort bereits übersetzt vor.
- **Fix**: Alert-`message` auf den tatsächlichen Umfang ziehen, z. B. „Diese Aktion
  kann nicht rückgängig gemacht werden. Alle Reisen, dein KI-API-Key und alle
  Einstellungen werden gelöscht, das Intro startet neu." — plus EN-Eintrag in
  `Localizable.xcstrings` (alte Variante bleibt für „Alle Daten löschen" bestehen).

### F03 — Keine Unit-Abdeckung für `AppPreferencesReset`
- **File**: `ShipTrip/Utilities/AppPreferencesReset.swift:20-31`
- **Severity**: major · **Blocker: nein** → Backlog
- **Problem**: Neue Logik, kein Unit-Test. Verifiziert ist per UI-Test genau **ein**
  Schlüssel (`colorScheme`); die übrigen sieben sind ungeprüfte String-Literale. Ich
  habe alle acht manuell gegen ihre `@AppStorage`/`forKey`-Fundstellen abgeglichen —
  sie stimmen heute. `run(in:)` nimmt bereits ein injizierbares `UserDefaults`, der
  Test kostet zehn Zeilen.
- **Fix** (Stub, `ShipTripTests/AppPreferencesResetTests.swift`):
  ```swift
  @Test("Der Reset räumt alle Präferenzen und lässt den Onboarding-Schalter als false stehen")
  func resetLeertPraeferenzen() throws {
      let defaults = try #require(UserDefaults(suiteName: "reset-test-\(UUID())"))
      defer { defaults.removePersistentDomain(forName: defaults.description) }
      for key in AppPreferencesReset.removableKeys { defaults.set("x", forKey: key) }
      defaults.set(true, forKey: OnboardingPresentation.hasCompletedKey)
      AppPreferencesReset.run(in: defaults)
      for key in AppPreferencesReset.removableKeys { #expect(defaults.object(forKey: key) == nil) }
      #expect(defaults.object(forKey: OnboardingPresentation.hasCompletedKey) as? Bool == false)
  }
  ```
  Der letzte `#expect` ist der eigentliche Wert: er hält den dreiwertigen Flag-Vertrag
  (`nil` ≠ `false`) fest, an dem die Bestands-Abhakung aus Gate 3 hängt.

### F04 — Keychain-Löschung im Reset-Pfad unverifiziert
- **File**: `ShipTrip/Views/Settings/SettingsView.swift:1080`
- **Severity**: major · **Blocker: nein** → Backlog
- **Problem**: Kein Test deckt ab, dass nach dem Reset kein Key mehr in der Keychain
  liegt. Weder `GeminiServiceTests` noch ein UI-Test fassen `clearApiKey()` an. Nicht
  blockierend, weil der Diff nur ein bestehendes Flag umlegt
  (`alsoDeleteApiKey: false` → `true`) und dieser Pfad in „Alle Daten löschen" seit
  Längerem produktiv läuft — aber die Aussage „Key ist weg" ist heute Annahme, nicht
  Beweis.
- **Fix**: `AppResetUITests` um einen Durchlauf ergänzen, der vorher einen Key
  hinterlegt und nach dem Reset den „kein Key"-Zustand der Einstellungen prüft
  (`hasApiKey`, `SettingsView:211/215`, ist UI-sichtbar).

### F05 — Allowlist aus String-Literalen
- **File**: `ShipTrip/Utilities/AppPreferencesReset.swift:23-27`
- **Severity**: minor · **Blocker: nein** → Backlog
- **Problem**: `removableKeys` ist eine handgepflegte Allowlist; fünf der acht
  Einträge sind Literale, die an ihrer Definitionsstelle (`SettingsView`,
  `MainTabView`, `CruiseFormView`) ebenfalls als Literal stehen — es gibt keine
  Compile-Zeit-Verbindung. Jede künftige `@AppStorage`-Präferenz wird vom Reset
  **stillschweigend nicht** erfasst; genau der Bug, den Andre gerade gemeldet hat,
  entsteht so von selbst wieder. Eine Blocklist wäre die robustere Bauform, aber sie
  müsste die Mapping- und Migrations-Schlüssel korrekt ausnehmen — kein Umbau für
  diesen Run.
- **Fix (später)**: Präferenz-Schlüssel als benannte Konstanten zentralisieren (Muster
  `CalendarSyncPreferences`), `@AppStorage` darauf umstellen, Literale in
  `removableKeys` ersetzen.

### F06 — `-only-testing` verwirft `OnboardingPresentationTests` still
- **File**: `ShipTripTests/OnboardingModelTests.swift:30` (Suite `OnboardingPresentationTests`) vs. `:170` (`OnboardingModelTests`)
- **Severity**: minor · **Blocker: nein** → Backlog
- **Problem**: Die Datei enthält **zwei** Suites. `-only-testing:ShipTripTests/OnboardingModelTests`
  trifft nur die zweite. Im Grün-Lauf des Devs (`20260825T180552Z`, „17/17") sind die
  sieben Tests der Suite `OnboardingPresentationTests` — also ausgerechnet die
  Schalter-Semantik (`nil` vs. `false`, stille Migration) — nie gelaufen. Ich habe sie
  nachgezogen: 7/7 grün. Kein Verhaltensproblem, aber die Evidenz war schmaler als
  behauptet.
- **Fix**: In künftigen Gate-Kommandos beide Suites selektieren oder die Suites in
  getrennte Dateien ziehen.

## Antworten auf die Prüffragen

1. **Kalender-Mapping** — siehe F01. Weder `deleteAllData` noch `resetApp` entfernt
   Termine; bisher übernahm das der Observer, der Fix schneidet ihm den Strom ab.
   Mapping erhalten + Sync aus = die schlechteste Kombination: die Termine bleiben,
   und nichts räumt sie mehr weg. Die Migrations-Flags (`idBackfillCompleted.v1`,
   `shippingLineCatalogDedupCompleted.v1`) stehen zu lassen ist dagegen **richtig** —
   sie beschreiben den Zustand des Stores, nicht eine Nutzer-Einstellung; ein Rücksetzen
   würde nach dem Reset einen sinnlosen Backfill über einen leeren Store auslösen.
2. **Keychain-Lücke** — kein Blocker (F04). Der Diff legt nur ein bestehendes,
   produktiv genutztes Flag um; ungetestet, aber nicht ungeprüft riskant.
3. **Alert-Text** — Blocker (F02). Nicht wegen des Wordings an sich, sondern weil die
   Key-Löschung im Schwester-Pfad eine eigene Rückfrage wert ist und hier ohne
   Erwähnung passiert. Die „Katalog gesperrt"-Begründung hält nicht.
4. **Flag-Überleben** — ja, verifiziert. `removableKeys` enthält
   `OnboardingPresentation.hasCompletedKey` **nicht**; `AppPreferencesReset.run` ruft
   `requestReplay` → `defaults.set(false, forKey:)`. Im Testlauf erscheint das
   Onboarding nach dem Reset (2/2 `AppResetUITests` grün). Einschränkung: der UI-Test
   unterscheidet `false` nicht von `nil` — ohne Reisen liefert `startupDecision` in
   beiden Fällen `.present`. Der Vertrag ist damit im Code korrekt, aber nur statisch
   belegt; F03 schließt die Lücke.
5. **Allowlist** — ja, reine Allowlist. Künftige Präferenzen fallen stillschweigend
   durch (F05). Kein Fix in diesem Run.

## Statischer Pass

- `guard.py sizes`: `SettingsView.swift` 1105 Zeilen (> 500 hart) — **vorbestehend**
  (Basis: 1106), der Diff macht die Datei um eine Zeile kleiner. Kein neues Finding.
  `AppPreferencesReset.swift` 45 Zeilen, `AppResetUITests.swift` unauffällig.
- Swift 6: `AppPreferencesReset` ist ein `enum` mit unveränderlichem
  `static let [String]` (Sendable), `run(in:)` nonisolated und nur vom MainActor
  aufgerufen — sauber. Keine Force-Unwraps, kein `try!` im Diff. Stil (deutsche
  Doc-Kommentare, `// MARK:`) gespiegelt.
- Scope-Treue: gehalten. Vier Dateien, alle im Reset-Pfad. Test-Diff (112 Zeilen,
  überwiegend Extraktion gemeinsamer Helfer) ≈ Code-Diff — vertretbar.
- GDPR-Trigger (Löschpfad berührt): Key-Löschung ist eine **Verbesserung** der
  Löschvollständigkeit. Gegenläufig: F01 lässt Nutzerdaten in einem externen Speicher
  (System-Kalender) nach einer expliziten Löschaktion stehen — das ist das stärkste
  Argument für die Blocker-Einstufung von F01.
- Security-Trigger: keine neue Angriffsfläche; `KeychainService.delete` bestehend.

## Test-Run (change-scoped, eigener Wegwerf-Simulator `ci-quality-reset`)

| Gate | Tests | Ergebnis |
|------|-------|----------|
| regression-unit (`OnboardingModelTests`, `CalendarSyncServiceMigrationTests`) | 15 | 15 passed, 0 failed |
| regression-ui (`AppResetUITests`, `OnboardingUITests`, `OnboardingSampleTripUITests`) | 6 | 6 passed, 0 failed |
| regression-presentation (`OnboardingPresentationTests`, Nachtrag zu F06) | 7 | 7 passed, 0 failed |

Summe 28/28 grün, Zahlen aus den xcresult-Bundles (nicht aus der Log-Prosa).

- `.winston-evidence/20260825T181251Z/gate-run.json` — `status: verified`, beide Gates Exit 0
- `.winston-evidence/20260825T181534Z/gate-run.json` — `status: verified`, Exit 0

**Fremd-Evidenz geprüft:**
- Rot (`20260825T180117Z`, Commit `3c0069a`): Exit 65, Abbruch an
  `AppResetUITests.swift:110` mit `XCTAssertTrue failed — Nach dem Reset steht das
  Farbschema nicht wieder auf „System"`. Das ist ein **Verhaltens**-Rot am Bestand
  (Produktionscode = `7d9d03d`), kein Compile-Fehler und kein Rot gegen einen neu
  eingeführten Typ. Gültig.
- Grün (`20260825T180552Z`, Commit `b87aabf`): Exit 0, `status: verified`. Gültig —
  aber die Testmenge war schmaler als die Behauptung, siehe F06.

## Verdikt

**no-go** — 2 Blocker (F01, F02). F03–F06 gehören ins Backlog, nicht in die Fix-Runde.
