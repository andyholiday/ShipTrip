# Review — D1 „ISO-Ländercodes in PortSuggestion + Locale.localizedString(forRegionCode:)"

- **Iteration**: 1 / 3
- **Reviewer**: quality-agent (frischer Spawn, Ein-Runden-Regel)
- **Datum**: 2026-08-27
- **Commit**: b2998cb · Basis `release/1.8.5` · Worktree `ShipTrip-worktrees/t3-laendercodes`
- **Verdikt**: approve
- **Stats**: critical: 0, major: 0 (neu), minor: 1 — Blocker: 0, Backlog: 1
- **Evidenz**: `.winston-evidence/20260827T070747Z/gate-run.json` (build=0, tests=0)

## Summary

Diff von 410 Zeilen: ein neues `enum PortCountryCatalog` (112 Mappings
Bestandsname→ISO-3166-1-Alpha-2), zwei abgeleitete `PortSuggestion`-Properties,
sechs reine Anzeigestellen umgestellt, ADR-008, neue Testdatei. Die Umsetzung
hält, was ADR-008 beschreibt: Persistenz, Export-/Teilen-Format und
SwiftData-Schema bleiben unangetastet, der Bestandsname bleibt der gespeicherte
Wert, der ISO-Code ist reine Anzeige-Ableitung. Keine Blocker.

## Unabhängig nachgerechnete Acceptance-Punkte

Nicht aus dem Testlauf übernommen, sondern gegen die Rohdaten geprüft:

- **Abdeckung vollständig und exakt.** `PortSuggestion.popular` (1.956 Einträge)
  enthält **117 verschiedene** Ländernamen. 112 sind gemappt, 5 sind die in
  ADR-008 dokumentierten Fallbacks (`Antikes Athen`, `Byzantinisches Reich`,
  `Britisch-Hongkong`, `China`, `Bonaire`). 117 = 112 + 5, Rest leer.
- **Keine Karteileichen.** Null Tabellenschlüssel ohne Vorkommen in den
  Referenzdaten — die Tabelle ist aus dem Bestand abgeleitet, nicht geraten.
- **Deterministisch.** Keine doppelt vergebenen Codes; `[String: String]` als
  `static let`, Lookup rein und seiteneffektfrei.
- **Codes stichprobenhaft korrekt** bei den heiklen Aliassen: CI, FO, GG, IM,
  CV, SX, KN, LC, VG/VI, KY, FM, CD, GB, HK, TW, CW, FK, GL, GP, MQ.
- **Keine Force-Unwraps** im Diff; der Fallback läuft über `guard let … else
  { return countryName }` — kein Fehlerpfad, sondern der dokumentierte Normalfall.
- **Persistenzgrenze dicht.** `CruiseFormView.swift:1048` und
  `PortFormView.swift:225` weisen bei Auswahl weiterhin `suggestion.country`
  (Rohwert) zu; die `TextField`-Bindings der manuellen Eingabe bleiben roh.
  `ExportImportService.swift:159` und `ExportImportService+Import.swift:185`
  unverändert auf `port.country`. Kein lokalisierter Name kann in die Datenbank
  oder in eine Export-Datei gelangen.
- **Zählstellen korrekt roh gelassen**: `Cruise.countriesVisited` (Cruise.swift:153),
  `StatsView.swift:243`, sowie die Identitäts-Keys in `CruiseHeroCardView.swift:153`
  und `CruiseDetailView.swift:232` — dort wäre Lokalisierung ein Bug gewesen.
- **Surgical Changes eingehalten.** Kein Refactoring in den drei berührten
  Bestandsdateien, nur die Namensquelle getauscht.

## Findings

| ID  | Severity | Blocker | File:Line                              | Kategorie     | Titel                                          |
|-----|----------|---------|----------------------------------------|---------------|------------------------------------------------|
| F01 | minor    | nein    | ShipTrip/Services/CalendarEventPlanner.swift:115 | consistency | Kalender-Ort weiter auf dem DE-Rohwert |

### F01 — Kalender-Event-Ort bleibt beim deutschen Bestandsnamen

- **File**: `ShipTrip/Services/CalendarEventPlanner.swift:115`
- **Severity**: minor · **Blocker**: nein
- **Problem**: `let location = port.country.isEmpty ? port.name : "\(port.name), \(port.country)"`
  ist die siebte nutzersichtbare Ausgabe des Ländernamens, wurde aber nicht auf
  den Katalog gehoben. Auf einem EN-Gerät steht im Kalendereintrag „Barcelona,
  Spanien", während Reise-Detail und Karte „Spain" zeigen. Der `title` direkt
  darüber ist `String(localized:)` — die Umgebung lokalisiert also durchaus.
  ADR-008 listet unter Entscheidung 5 nur sechs Anzeigestellen und erwähnt den
  Kalender nicht; die Auslassung ist damit undokumentiert, nicht bewusst.
- **Warum kein Blocker**: kein Datenverlust, kein Absturz, keine Kernfluss-Störung.
  Der deutsche Name bleibt für Apples Ortsauflösung brauchbar, und eine Änderung
  würde bei bestehenden Kalendereinträgen ein Update des `location`-Felds über
  den gesamten Bestand auslösen — das gehört bewusst entschieden, nicht in einen
  Anzeige-Fix hineingezogen.
- **Fix-Vorschlag (für den Backlog, nicht für diesen Run)**: entweder
  `PortCountryCatalog.localizedName(for: port.country)` einsetzen **und** ADR-008
  Entscheidung 5 auf sieben Stellen erweitern, oder die Auslassung in ADR-008
  als bewusst begründen (Ortsauflösung/Bestandsstabilität).

## Bereits andernorts getriggerte, hier bestätigte Punkte (kein neuer Eintrag)

- **Dateigrößen**: `guard.py sizes` meldet Exit 1 für `CruiseFormView.swift`
  (1.538), `CruiseDetailView.swift` (679) und `PortFormView.swift` (539) — alle
  drei sind bei `release/1.8.5` **zeilengleich**, also vorbestehend und nicht von
  diesem Diff verursacht. Der D2-Split ist in diesem Branch noch nicht enthalten.
  Bereits im Backlog (Run 1.8.5 Welle 1).
- **Anzeige/Eingabefeld-Naht** (EN-Gerät: Liste „Spain", Feld „Spanien") ist in
  ADR-008 unter „Negativ / bewusst in Kauf genommen" dokumentiert und steht
  bereits als T3-Naht im Backlog.
- **Wikidata-Datenmüll** (historische Entitäten) steht bereits als T3-Befund im Backlog.

## GDPR / Security

Nicht einschlägig — Trigger fehlen. Der Diff verarbeitet keine personenbezogenen
Daten (Ländername eines öffentlichen Hafens aus statischen Referenzdaten), öffnet
keine Angriffsfläche, ruft kein Netzwerk, parst keine Fremdeingabe und ändert
weder Persistenz noch Export-Format.

## Test-Run

Wegwerf-Simulator (`simctl create` iPhone 17 / iOS 26.5, `bootstatus -b`,
trap-Cleanup, danach gelöscht). Kein fremder Simulator übernommen.

| Gate  | Befehl                                                   | Exit |
|-------|----------------------------------------------------------|------|
| build | `xcodebuild build-for-testing -scheme ShipTrip -destination id=$SIM_UDID` | 0 |
| tests | `xcodebuild test-without-building -scheme ShipTrip -destination id=$SIM_UDID -only-testing:ShipTripTests` | 0 |

**419 Tests, 419 bestanden, 0 rot, 0 übersprungen** (aus `d1-full.xcresult`,
nicht geschätzt). Neue Suite „Ländercodes der Hafen-Referenzdaten" grün, ebenso
`Cruise.countriesVisited`, die Export-Roundtrip-Suiten (Beleg für „Format
unangetastet"), `MapMarkerPlanner.*`, `CruiseFormView Route Reconciliation`,
`TempPort-Koordinaten`. Keine Compiler-Warnung in einer der geänderten Dateien
(73 Warnungen im Build sind vorbestehend und liegen anderswo).

### Zwei dokumentierte Abweichungen

1. **`gates.yaml` `tests`-Befehl bewusst nicht verwendet.** Der Kanon lautet
   `xcodebuild test -scheme …`; der Projekt-Kanon verbietet ihn (LLDB-Hänger)
   und schreibt `build-for-testing` + `test-without-building` vor. `gates.yaml`
   räumt dem Projekt-Kanon ausdrücklich Vorrang ein. Kein Weichspüler: die
   Zerlegung ist strenger, nicht laxer.
2. **Abweichung nach oben von der Testumfangs-Leiter** (Feature-Klasse hätte
   „neue Testdatei + direkt berührte Bestandstests" verlangt, gelaufen ist das
   volle Unit-Bundle): Ein erster Lauf mit `-only-testing:ShipTripTests/<Datei>`
   lief zwar grün (27/27), traf aber nur 4 der 7 gewählten Suiten — `-only-testing`
   adressiert **Typnamen**, und `PortFormViewTests.swift`,
   `MapMarkerPlannerTests.swift`, `ExportRoundtripTests.swift` deklarieren
   abweichend benannte Structs; nicht getroffene Filter werden still übersprungen.
   Insbesondere `CruiseCountriesVisitedTests` lief dabei **nicht**. Statt
   Typnamen zu raten wurde das Unit-Bundle vollständig gefahren — billig (Build
   war bereits gecached) und ohne Auswahlfehler-Risiko. Das erste, unvollständige
   Artefakt (`20260827T070543Z`) ist überholt; maßgeblich ist `20260827T070747Z`.

## Verdikt

**approve / GO.** Keine offenen Blocker. F01 geht als Backlog-Zeile mit, kein
Fix-Auftrag in diesem Run.
