# Review - Welle D (TestFlight-Feedback Build 17): Stock-Cover-Fallback (F1) + Auto-Weiterleitung Schiff-Formular (F2)

- **Iteration**: 1 / 3
- **Reviewer**: quality-agent
- **Date**: 2026-07-10
- **Verdict**: approve
- **Stats**: critical: 0, major: 0, minor: 3

## Scope

Review beschränkt auf ungestagte Änderungen in:
- `ShipTrip/Models/ShippingLine.swift`
- `ShipTrip/Views/Settings/ShippingLineManagementView.swift`
- `ShipTripTests/CruiseAggregateTests.swift` (Suite `CruiseCoverFallbackTests`, 7 neue `@Test`)
- `ShipTripUITests/ReedereiAnlegenUITests.swift` (neu, 1 UI-Test)

`git status`/`git diff --stat` bestätigt: keine Änderungen außerhalb dieser Allowlist.
Kein Build, kein Testlauf durch mich (Scope-Vorgabe) — Testlauf läuft laut Auftrag
parallel im Orchestrator.

## Summary

Beide Features sind korrekt und vollständig gegen die Anforderungen umgesetzt. F1
(FNV-1a-64-Hash, eingefrorener 70-Item-Pool, Custom-Zweig nur nach komplettem
Katalog-Lookup-Fail, ""+""-Guard) wurde Zeile für Zeile verifiziert inkl. manueller
Nachrechnung der Hash-Werte in Python — Testerwartungen (`cover_line_msc_3` etc.)
stimmen mit der Implementierung überein, keine Tautologie. Alle 70 Pool-Assets
existieren als `.imageset` in `Assets.xcassets` (per `ls` geprüft). F2
(sheet-onDismiss-Übernahme, One-Shot-Guard, `navigationDestination(item:)`) folgt dem
korrekten SwiftUI-Muster gegen überlappende Present/Dismiss-Animationen; Abbruch- und
Re-Entry-Pfade wurden durchgespielt, kein Doppel-Anlage-Risiko gefunden. Keine
Blocker. Drei nicht-blockierende Minor-Findings (Testlücken + Zeilenlänge).

## Findings

| ID  | Severity | File:Line                                          | Category | Title                                                   |
|-----|----------|-----------------------------------------------------|----------|----------------------------------------------------------|
| F01 | minor    | ShipTripTests/CruiseAggregateTests.swift:429-482     | tests    | Guard-Zweig "genau ein Name leer" nicht separat getestet |
| F02 | minor    | ShipTripUITests/ReedereiAnlegenUITests.swift         | tests    | Kein Test für "Reederei-Anlage abbrechen → keine Auto-Navigation" |
| F03 | nit      | ShipTrip/Models/ShippingLine.swift:176-189           | style    | `stockCoverPool`-Zeilen überschreiten 100-Zeichen-Richtwert |

### F01 - Guard-Zweig "genau ein Name leer" nicht separat getestet
- **File**: `ShipTripTests/CruiseAggregateTests.swift:429-482`
- **Severity**: minor
- **Category**: tests
- **Problem**: `stockCoverAssetName` guard ist `guard !normalizedLine.isEmpty || !normalizedShip.isEmpty else { return nil }`
  (OR — mindestens einer der beiden Namen muss vorhanden sein). Getestet sind nur
  "beide gefüllt" (mehrere Tests) und "beide leer" (`emptyLineAndShipYieldOnlyOceanFallback`).
  Der Fall "nur Schiff leer, Reederei gefüllt" bzw. "nur Reederei leer, Schiff gefüllt"
  ist nicht abgedeckt. Ein künftiger Refactor, der die OR- versehentlich zu einer
  AND-Bedingung macht, würde von der aktuellen Suite nicht erkannt.
- **Fix**: Einen achten Test ergänzen, z. B.
  ```swift
  @Test("Nur Reederei-Name gefüllt liefert dennoch ein Stock-Cover")
  func onlyLineNameFilledStillYieldsStockCover() {
      let candidates = ShippingLine.coverAssetCandidates(shippingLine: "Meine Fantasie-Reederei", ship: "")
      #expect(candidates.first != "cover_ocean_route")
  }
  ```

### F02 - Kein Test für Abbruch-Pfad "Reederei-Anlage abbrechen → keine Auto-Navigation"
- **File**: `ShipTripUITests/ReedereiAnlegenUITests.swift`
- **Severity**: minor
- **Category**: tests
- **Problem**: Die Auflage aus dem Auftrag "Abbruch-Pfade sauber" wurde für den
  Schiff-Formular-Abbruch getestet (Schritt 4/5 im vorhandenen Test), aber nicht für
  den Fall, dass der Nutzer das *Reederei*-Anlege-Formular selbst abbricht
  (`onCreated` wird dann nie aufgerufen, `pendingNewLine` bleibt `nil`). Code-seitig
  korrekt verifiziert (kein toter Callback-Pfad), aber nicht automatisiert
  abgesichert.
- **Fix**: Ergänzender UI-Test oder zusätzlicher Schritt: Reederei-Formular öffnen,
  "Abbrechen" tippen, assert, dass man weiterhin in der Reederei-Liste steht und
  `navigationBars["Eigenes Schiff"]`/`textFields["Schiffsname"]` nicht existieren.

### F03 - `stockCoverPool`-Zeilen überschreiten 100-Zeichen-Richtwert
- **File**: `ShipTrip/Models/ShippingLine.swift:176-189`
- **Severity**: nit
- **Category**: style
- **Problem**: Die 14 Pool-Zeilen sind bis zu 162 Zeichen lang (swift-standards
  Soft-Limit: 100 Zeichen). Kein `.swiftlint.yml` im Projekt vorhanden, also nicht
  tool-enforced; bewusste Kompaktheit für die 70-Item-Liste ist nachvollziehbar.
- **Fix**: Optional — je Reederei eine eigene Zeile (5 statt aktuell 1 Zeile pro
  Reederei) für bessere Diff-Lesbarkeit bei künftigen Erweiterungen. Kein Blocker.

## Detailergebnisse je Prüfpunkt

1. **Anforderungen + Auflagen (F1)** — erfüllt:
   - Custom-Zweig nur im `else`-Zweig von `find(byName:) ?? findByShipName(ship)` →
     `ShippingLine.swift:156-161`, korrekt "nur nach komplettem Katalog-Lookup-Fail".
   - `""+""`-Guard: `guard !normalizedLine.isEmpty || !normalizedShip.isEmpty else { return nil }`
     → `ShippingLine.swift:197` — liefert `nil` nur wenn **beide** leer sind, wie im
     Docstring behauptet.
   - FNV-1a-64 statt `Hasher`: Offset-Basis `0xcbf29ce484222325`, Prime `0x100000001b3`,
     XOR-vor-Multiply-Reihenfolge, `&*` (Overflow-Operator) statt trap-fähigem `*` —
     kanonisch korrekt, unabhängig in Python nachgerechnet (`cover_line_msc_3` für
     "Meine Fantasie-Reederei"/"MS Sonnenschein" bestätigt, `cover_line_carnival_2`
     für das zweite Testpaar — beide stimmen mit den Test-Erwartungen überein, keine
     Tautologie).
   - `stockCoverPool` ist eine eingefrorene `static let`-Liste, nicht aus `all`
     abgeleitet → Katalog-Erweiterungen ändern bestehende Custom-Zuordnungen nicht.
   - Katalog-Regression ausgeschlossen: Zweig wird nur bei komplettem Lookup-Fail
     betreten; zwei dedizierte Regressionstests (`catalogLineWithUnknownShipStaysOnLinePool`,
     `unknownLineWithKnownCatalogShipStaysOnPreviousMatch`) bestätigen das.

2. **Anforderungen + Auflagen (F2)** — erfüllt:
   - `onCreated` wird ausschließlich im `else`-Zweig (Neuanlage, nicht Edit) aufgerufen
     → `ShippingLineManagementView.swift:221-224`.
   - Navigation (`newLineDestination = pendingNewLine`) passiert ausschließlich in
     `.sheet(..., onDismiss:)`, also erst nachdem das Anlege-Sheet vollständig
     geschlossen ist — verhindert das bekannte SwiftUI-"presentation in progress"-
     Problem bei überlappenden Sheet-Dismiss-/Push-Animationen.
   - One-Shot: `hasPresentedInitialShipForm` ist `@State` auf `ShipManagementView` —
     da `navigationDestination(item:)` bei jedem Push eine frische View-Instanz (frischer
     State) erzeugt, kein Leck über Navigationszyklen hinweg; zusätzlich schützt der
     Guard vor mehrfachem `onAppear` innerhalb derselben Instanz.
   - Abbruch-Pfade: Schiff-Formular abbrechen → kein Re-Trigger (durch Guard,
     UI-test-verifiziert). Reederei-Formular abbrechen → `onCreated` nie aufgerufen,
     `pendingNewLine` bleibt `nil`, `onDismiss` tut nichts (code-verifiziert, aber
     s. F02 für fehlende Automatisierung).
   - Kein Doppelanlage-Risiko: Der neue Flow öffnet nur das leere Schiff-Formular,
     legt aber kein Schiff automatisch an — die eigentliche Anlage bleibt ein
     expliziter Nutzer-Save. Reederei selbst kann nicht doppelt entstehen (bestehender
     `hasLineCollision`-Guard in `ShippingLineCatalogService.createCustomLine`,
     unverändert).

3. **Korrektheit** — keine Findings. `ShippingLineOption`/`ShipOption` sind bereits
   `Identifiable, Hashable` (Voraussetzung für `navigationDestination(item:)`), unverändert
   in dieser PR. `ShippingLineManagementView` liegt in einer `NavigationStack` (aus
   `SettingsView.swift:26`), `navigationDestination(item:)` ist also gültig platziert.

4. **Testqualität** — 7 Unit-Tests + 1 UI-Test testen reales Verhalten (kein
   Mock-Internals-Testing, keine `@testable`-Zugriffe auf private Methoden). Der
   Hash-Erwartungswert wurde unabhängig nachgerechnet (nicht nur "Test kopiert
   Produktionscode"). UI-Test vermeidet `sleep()`, nutzt scoped Queries
   (`navigationBars[...].buttons[...]`) zur Ambiguitäts-Vermeidung, folgt exakt dem
   etablierten Swipe-/Timeout-Muster aus `AusflugLoeschenUITests.testEinstellungenHinweisSichtbar`.
   Zeitstempel-basierte eindeutige Namen sind eine bewusste, kommentierte Reaktion auf
   den (vorbestehenden) Umstand, dass `CustomShippingLine`-Daten zwischen Testläufen
   auf demselben Simulator bestehen bleiben. Verbleibende Lücken: F01, F02 (beide minor).

5. **Swift 6 / Simplicity / Surgical Changes** — keine Findings. Reine synchrone
   Value-Type-Logik, kein `Task`/`actor`, keine neuen Sendability-Fragen. `git diff --stat`
   bestätigt: nur die vier freigegebenen Dateien geändert, keine Format-/Stil-Änderungen
   an unberührtem Code. Beide Views bereits implizit `@MainActor` (SwiftUI `View`),
   unverändert von dieser PR.

6. **Sicherheit / Datenverlust** — keine Findings. Keine PII involviert (Reederei-/
   Schiffsname sind App-Konfigurationsdaten, kein Personenbezug) → GDPR-Audit nicht
   einschlägig. Kein Netzwerk-/Auth-Code, kein Injection-Vektor (SwiftData `#Predicate`
   bereits parametrisiert, unverändert). Kein Doppelanlage-Risiko (s. Punkt 2).

7. **Größenlimits** — `ShippingLine.swift` 255 Zeilen (unkritisch). Vorbestehende Datei
   `ShippingLineManagementView.swift` liegt nach dieser PR bei 477 Zeilen (Soft-Limit
   400 bereits vor dieser PR überschritten, Hard-Limit 500 noch nicht erreicht — kein
   Blocker, aber Hinweis: nächste Erweiterung sollte eine Aufteilung erwägen).

## Previous iteration status
N/A (Iteration 1).

## Go/No-Go
**GO.** Keine Critical-, keine Major-Findings. Die drei Minor/Nit-Findings sind
optionale Verbesserungen (Testlücken für Randfälle, Zeilenlänge) und blockieren den
Merge nicht.
