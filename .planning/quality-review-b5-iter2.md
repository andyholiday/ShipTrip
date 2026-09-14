# Quality Review — Welle B5 — Iteration 2 (Fokus-Re-Check)

**Datum:** 2026-07-04
**Scope:** Nur die 3 Majors aus iter1 + Gate-2-Punkte, kein Voll-Review, kein Build.

## Verdikt: GO

### MAJOR-1 (CruiseFormView Ship-Reset bei Reederei-Wechsel) — FIXIERT
`originalLineOptionID` (CruiseFormView.swift:206-208) bindet `currentSelection` in
`shipOptions(for:)` (Zeile 213-218) jetzt nur noch an die Reederei, unter der die Reise
ursprünglich geladen wurde. Nachvollzogen: Wechsel AIDA→MSC im Edit-Formular liefert für
`shipOptions(for: "msc")` `currentSelection: nil` (da `"msc" != originalLineOptionID`),
kein phantom-`.unlisted`-Eintrag mit dem alten Schiffsnamen mehr, der Reset
(`ship = ""`) im `.onChange`-Handler greift korrekt. `resolvedShippingLineName`/
`resolvedShipName` (statische, testbare Helper) lösen Preserve-vs-Clear sauber auf;
`existing:` wird für `ship` aus dem **live** State übergeben (nicht dem Modell), für
`shippingLine` aus dem Modellfeld — beides korrekt für die jeweilige Semantik. Neu-
Anlage-Pfad (`cruise == nil`) bleibt unberührt (`originalLineOptionID` wird `nil`,
`currentSelection` immer `nil`). DealFormView analog konsistent (nur `shippingLine`,
kein Ship-Picker — korrekt, da nicht in ADR-Scope).

Restliche Beobachtung (nicht blockierend): Die `originalLineOptionID`-Scoping-Logik
selbst ist `private` in der View und daher nicht direkt unit-testbar; die 13 neuen Tests
in `ShippingLinePreserveOnSaveTests.swift` decken nur die statischen
`resolved*Name`-Formeln ab, nicht das Zusammenspiel mit `originalLineOptionID`. Fix ist
per Code-Trace verifiziert korrekt, aber ohne Test gegen Regression abgesichert.

### MAJOR-2 (historicalShips generell im Picker) — FIXIERT
`ShippingLineCatalogService.shipOptions` (Zeile 67-73) filtert `historicalShips` jetzt
auf `$0 == currentSelection` — erscheinen nur noch, wenn sie exakt dem aktuell
gespeicherten (Bestands-)Schiff entsprechen. Test
`historicalShipsAreExcludedForNewSelections` bestätigt: kein Auftauchen bei
`currentSelection: nil`, korrektes (einmaliges, kein Duplikat) Erscheinen bei
`currentSelection: "AIDAcara"`.

### MAJOR-3 (Preserve-on-save ungetestet) — ADRESSIERT
`ShippingLinePreserveOnSaveTests.swift` (13 Tests) deckt `resolvedShippingLineName`/
`resolvedShipName` (Cruise + Deal) für unberührt/aktiv-geleert/neu-gewählt/
`.unlisted`-Rundlauf ab. Das ist die entscheidende Verzweigungslogik der Preserve-on-
save-Regel und jetzt regressionssicher. Rest-Lücke wie oben (originalLineOptionID-
Scoping) bleibt bestehen, aber die eigentliche Datenverlust-Logik (Kern des
Gate-4-Findings) ist jetzt abgedeckt.

## Gate-2-Punkte

- **Gate2-1 (throws + try context.save()):** Alle acht Schreibfunktionen in
  `ShippingLineCatalogService.swift` sind jetzt `throws` und rufen `try context.save()`
  vor dem Return auf. `ShippingLineManagementView.swift`: alle Aufrufstellen
  (`deleteCustomLine`, `deleteCustomShip`, `toggleLineHidden`, `toggleShipHidden`,
  `CustomLineFormSheet.save()`, `CustomShipFormSheet.save()`) sind in `do/catch`
  gewrappt, mit `actionErrorMessage`/`errorMessage`-Alerts statt stillem Dismiss.
  Vollständig, keine Lücke gefunden.
- **Gate2-2 (Dedup CustomShips über collisionKey):** `dedupeShips` in
  `ShippingLineCatalogDedup.swift:115-134` gruppiert jetzt über
  `ShippingLineNameMatching.collisionKey` (diakritik-insensitiv) statt
  `normalizedShipKey`. Dedizierter Diakritik-Test
  (`dedupesCustomShipDuplicatesWithDiacriticVariant`) vorhanden und konsistent mit der
  lokalen Kollisionsprüfung in `createCustomShip`.
- **Gate2-3 (userCleared-State):** `userClearedLine`/`userClearedShip` in
  `CruiseFormView`, `userClearedLine` in `DealFormView` vorhanden, korrekt über die
  `.onChange`-Handler gesetzt und in die `resolved*Name`-Helper eingespeist.

## Zusammenfassung
Keine offenen Blocker. Ein nicht-blockierender Hinweis für später: Test-Abdeckung für
das Zusammenspiel `originalLineOptionID` ↔ `shipOptions(for:)` (View-Ebene) nachziehen,
falls die Formulare künftig refactored werden.
