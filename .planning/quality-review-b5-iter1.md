# Quality Review — Welle B5 „Eigene Reedereien & Schiffe" — Iteration 1

**Datum:** 2026-07-04
**Reviewer:** Quality-Inspector (statisch, kein Build/Test-Lauf — siehe Constraint)
**Maßstab:** ADR-006 (Contract + Acceptance-Tests 1-8), ADR-002 (CloudKit), CLAUDE.md

## Verdikt: NO-GO

Grund: Zwei Major-Findings betreffen exakt die Problemklasse, die dieses ADR eigentlich
beheben sollte (Datenverlust/-inkonsistenz bei Reederei/Schiff), und sind aktuell
ungetestet. Dev-A (Models/Service/Dedup/Tests) ist solide und ADR-konform; die Lücken
liegen in der Dev-B-Integration (CruiseFormView) bzw. im gemeinsamen Contract-Verhalten
von `shipOptions`.

---

## Findings

### MAJOR-1 — Reederei-Wechsel im Edit-Formular resettet das Schiff nicht mehr korrekt
`ShipTrip/Views/Cruises/CruiseFormView.swift` (private `shipOptions(for:)`-Helper, ~Zeile
199-204, verwendet im Picker-Body und im `.onChange(of: selectedLineOption)`-Handler)

`shipOptions(for lineOptionID:)` ruft den Service **immer** mit
`currentSelection: cruise?.ship` auf — unabhängig davon, welche `lineOptionID` gerade
abgefragt wird (aktuell gewählte Reederei im UI, nicht die ursprüngliche). Der Service
synthetisiert daraufhin für **jede** angefragte Reederei eine `.unlisted`-Option mit dem
ursprünglichen Schiffsnamen, sobald dieser dort nicht gefunden wird.

Konkretes Szenario: Cruise wird mit Reederei „AIDA" / Schiff „AIDAstella" bearbeitet.
Nutzer wechselt die Reederei auf „MSC". Der `.onChange`-Handler prüft
`!shipOptions(for: "msc").contains(where: { $0.name == ship })` — da `shipOptions(for:
"msc")` wegen `currentSelection == "AIDAstella"` (statisch, aus `cruise.ship`) eine
`.unlisted`-Option „AIDAstella" unter MSC synthetisiert, ist die Bedingung `false`, der
Reset (`ship = ""`) feuert **nicht**. Der Schiff-Picker für MSC zeigt „AIDAstella" als
unauffällige, wählbare Option; speichert der Nutzer ohne bewusste Neuauswahl, entsteht
`shippingLine == "MSC Cruises"` mit `ship == "AIDAstella"` — eine Reederei/Schiff-
Kombination, die nie existiert hat. Das unterläuft exakt die in ADR-006 Abschnitt 5
intendierte Konsistenzgarantie, nur in neuer Form.

Root Cause: Der Service-Contract `currentSelection` ist für „Preserve beim initialen
Laden" gedacht, wird hier aber auch für die **live** Picker-Darstellung nach Nutzer-
interaktion wiederverwendet. Fix-Vorschlag: `currentSelection` nur für die ursprünglich
geladene Reederei übergeben (z. B. `originalLineOptionID` separat mitführen und
`currentSelection: lineOptionID == originalLineOptionID ? cruise?.ship : nil`), oder für
den interaktiven Picker-Aufruf grundsätzlich `currentSelection: nil` verwenden und die
Preserve-Logik ausschließlich in `loadExistingData()` anwenden.

**Kein Test deckt dieses Verhalten ab** (keine View-Level-Tests zu `CruiseFormView`
existieren; die Service-Tests prüfen nur die statische `currentSelection`→`.unlisted`-
Zuordnung, nicht die Interaktion beim Reederei-Wechsel).

### MAJOR-2 — `historicalShips` erscheinen jetzt immer im Schiff-Picker, auch bei neuen Reisen
`ShipTrip/Services/ShippingLineCatalogService.swift:62-69` (`shipOptions`)

`shipOptions` hängt `line.historicalShips` bedingungslos an — auch wenn
`currentSelection == nil` (neue Kreuzfahrt). Das widerspricht dem bestehenden,
expliziten Doc-Kommentar auf `ShippingLine.historicalShips`
(`ShipTrip/Models/ShippingLine.swift:16-17`): „nicht mehr in der Auswahl für **neue**
Reisen, aber für Bestandsreisen aus der Vergangenheit erhalten." Vor diesem Feature
tauchten historische Schiffe nur als Sonderfall auf, wenn das bereits gespeicherte
`cruise.ship` selbst historisch war. Jetzt sieht jeder Nutzer beim Anlegen einer neuen
Reise ausgemusterte Schiffe (z. B. „AIDAcara", „AIDAvita") gleichberechtigt neben den
aktiven — Regression gegenüber dokumentiertem Produktverhalten, nicht durch das ADR
gefordert. Bestätigt auch als bewusste Designentscheidung in Dev-As eigenem Test
(`ShippingLineCatalogServiceTests.swift:80-101`, `currentSelection: nil` erwartet
trotzdem „AIDAcara").

Fix-Vorschlag: `historicalShips` nur einbeziehen, wenn der Name `currentSelection`
entspricht (analog zur alten Sonderfall-Injektion), sonst nur `line.ships` für die
reguläre Auswahl anzeigen.

### MAJOR-3 — Acceptance-Test 8 (Preserve-on-save) ist nicht auf View-Ebene abgesichert
Betrifft `CruiseFormView.swift`/`DealsView.swift` insgesamt; keine entsprechenden Tests
in `ShipTripTests/`.

ADR-006 erklärt Preserve-on-save ausdrücklich zum Pflichtbestandteil, „verifiziert über
Acceptance-Test 8". Vorhanden ist nur der Service-Baustein-Test (`currentSelection` →
`.unlisted`-Option, `ShippingLineCatalogServiceTests.swift:262-300`) — kein Test
simuliert den tatsächlichen `loadExistingData()` → `saveCruise()`/`saveDeal()`-Rundlauf
mit einer gelöschten/versteckten Reederei, den das ADR als Kernszenario beschreibt.
Genau diese Lücke hätte MAJOR-1 vermutlich sichtbar gemacht.

### Minor
- `ShippingLineCatalogService.shippingLineOptions`/`shipOptions`: Sortier-Comparator
  berechnet `collisionKey` pro Vergleich neu statt einmal vorab zu cachen (Performance-
  Nit, bei ~15 Reedereien/~100 Schiffen irrelevant, nur der Vollständigkeit halber
  erwähnt).

---

## Was gut ist (Dev-A)

- Modelle (`CustomShippingLine`, `CustomShip`, `HiddenCatalogItem`) exakt
  CloudKit-konform (ADR-002): Default-Werte überall, keine Relationships, keine
  `.unique`.
- `ShippingLineCatalogDedup` ist sauber vom `IdBackfill`-Muster abgeleitet: `@MainActor`,
  idempotent, versioniertes Flag, Fallback-Store-Gating, Rewiring-vor-Delete korrekt
  umgesetzt und getestet (inkl. Tie-Break-Determinismus).
- Kollisions-/Cascade-Delete-Logik in `ShippingLineCatalogService` ist vollständig und
  gut getestet (Acceptance-Tests 1-7 abgedeckt).
- Schema-Registrierung in `ShipTripApp.swift` korrekt, bestehende 7 Test-Schema-Helfer
  unangetastet wie vom ADR gefordert.
- Keine GDPR-/Security-relevanten Funde: keine neuen Berechtigungen, kein Logging von
  Nutzerdaten (nur Fehler-Strings in `ShippingLineCatalogDedup`).

## Was gut ist (Dev-B)

- `ShippingLineManagementView`/`ShipManagementView` rufen ausschließlich
  Service-Funktionen auf, keine eigene Merge-Logik.
- Lösch-Bestätigungen mit klarem Cascade-Hinweis vorhanden; Duplikat-Fehler werden
  inline angezeigt.
- `DealsView`-Umbau bleibt korrekt auf `shippingLine` beschränkt (kein Ship-Picker,
  ADR-konform als Non-Goal).
- Lokalisierung folgt dem etablierten Muster (`Text`/`Label` mit Literal =
  `LocalizedStringKey`, `String(localized:)` nur wo ein `String`-Wert gebraucht wird);
  `Localizable.xcstrings` unangetastet.

## Test-Status (statisch geprüft, nicht selbst ausgeführt — Build-Token beim Orchestrator)

Neue Testdateien vorhanden und inhaltlich plausibel für Acceptance-Tests 1-7:
`ShippingLineCatalogServiceTests.swift` (10 Tests), `ShippingLineCatalogDedupTests.swift`
(9 Tests). Kein View-Level-Test für Acceptance-Test 8 (siehe MAJOR-3).

## Empfehlung für nächste Iteration (Top 3)

1. `CruiseFormView.shipOptions(for:)`: `currentSelection` nur für die ursprünglich
   geladene Reederei binden, nicht für jede im UI angefragte (MAJOR-1).
2. `ShippingLineCatalogService.shipOptions`: `historicalShips` nur bei Match mit
   `currentSelection` einblenden, nicht generell (MAJOR-2).
3. Mindestens einen Integrationstest für den Preserve-on-save-Rundlauf ergänzen
   (`loadExistingData()`+Save mit gelöschter/versteckter Reederei) — Acceptance-Test 8
   ist sonst nicht wirklich abgesichert (MAJOR-3).
