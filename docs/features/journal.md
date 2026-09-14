# Journal (Reisetagebuch)

**Stand:** Modell (T7), Export/Teilen (T7b) und Bedienoberfläche (T8a–T8d)
gebaut. Das Journal hat **keinen eigenen Strang**: Einträge hängen im
bestehenden **Route-Abschnitt** der Reise-Detailansicht — ein Tagesfaden aus
Stopp-Karten statt einer zweiten, parallelen Tagesliste (J3neu, ADR-003).
**Code:** Modell `ShipTrip/Models/JournalEntry.swift`, `JournalDay.swift`,
`JournalDeletePaths.swift`, `Photo.swift` (`caption`, `journalEntry`),
Rückbeziehungen in `Cruise.swift`/`Port.swift`; UI unter
`ShipTrip/Views/Cruises/` — `RouteJournalSection`, `RouteStopCard`,
`RouteJournalEntryRow`, `RouteExtraEntriesBlock`, `JournalEntryDetailView`,
`JournalEntryEditorView`, `JournalMoodPicker`, `CruiseJournalNavigation` plus
die reinen Planer `RouteCollapsePlanner`, `RouteJournalPlanner`,
`JournalEditorDefaults`, `JournalEntryDayDisplay`, `JournalExcerpt`.
**Tests:** Modell/Logik als Unit-Tests (`JournalEntryModelTests`,
`JournalDayTests`, `JournalLWWMatrixTests`, `JournalAggregateRegressionTests`,
`JournalStoreFixtureMigrationTests` gegen `ShipTripTests/Fixtures/store-1.8.0/`,
`JournalDeletePathBindingTests`, `JournalExportRoundtripTests`,
`JournalExportLegacyCompatibilityTests`, `RouteCollapsePlannerTests`,
`RouteJournalPlannerTests`, `RouteJournalRowPresentationTests`,
`JournalEditorDefaultsTests`, `JournalEntryDayDisplayTests`,
`JournalExcerptTests`, `JournalMoodTests`); Kern-Flow als UI-Test
(`ShipTripUITests/JournalRouteFadenUITests`).

## So funktioniert der Route-Faden

- **Ein Stopp = eine Karte.** Häfen *und* Seetage sind gleichwertige Träger.
  Zugeklappt zeigt die Karte nur die Kopfzeile (Pin, Name, Land, Datum);
  aufgeklappt zusätzlich die `PortMemoryCard`, die Eintragszeilen und die
  Aktion „Tagebuch-Eintrag".
- **Zuordnung (J3neu (a)):** Eintrag mit Hafen-Bezug → genau dieser Stopp
  (Hafen schlägt Datum). Ohne Hafen-Bezug → erster Stopp desselben Tages.
  Kein Träger → Sammelblock „Weitere Einträge" am Ende des Abschnitts, der
  nur erscheint, wenn er Einträge enthält.
- **Klapp-Automatik (J3neu (b)):** vor Reisebeginn und nach Reiseende alles
  aufgeklappt, während der Reise nur die Stopps des heutigen Tages (hat heute
  keinen Stopp, bleibt alles zu). Manuelles Tippen übersteuert; der Schalter
  im Abschnitts-Kopf klappt alles auf bzw. zu. Der Zustand ist **nicht
  persistent** — bei Tageswechsel werden Defaults neu berechnet und alle
  Übersteuerungen verworfen.
- **Ein Weg zum Eintrag (J3neu (c)/(d)):** Eintragszeilen führen ausschließlich
  in die Detailansicht; **Bearbeiten und Löschen gibt es nur dort**, nicht im
  Faden. Der Editor öffnet als Sheet — „Erinnerung zuerst, Eckdaten als
  Zweitschritt" (J2), Eckdaten vorbelegt aus dem Stopp, aus dem heraus erfasst
  wurde.
- **Gelöscht wird nur über `JournalDeletePaths`,** damit die Nullify-Bumps der
  Matrix J2a wirklich laufen (SwiftData bumpt sie nicht von selbst).

## Acceptance-Status

Kriterien aus dem Run-Ziel 1.8.5 (Journal-Kern). Kriterium 3 trug ursprünglich
den Wortlaut „Tagebuch-Strang"; mit Contract-Rev. 2026-08-27/3 (J3neu) wurde
der separate Strang verworfen und durch die Route-Verankerung ersetzt.

| Nr. | Kriterium (Kurzfassung) | Status |
|---|---|---|
| 1 | `JournalEntry` + `Photo.caption`, CloudKit-konform, Alt-Store öffnet verlustfrei | Erfüllt bis auf den Gerätetest |
| 2 | Editor „Erinnerung zuerst" mit vorbelegten Eckdaten | Erfüllt (T8c) |
| 3 | Journal-Einträge im Route-Abschnitt der Reise-Detailansicht (J3neu) | Erfüllt (T8a–T8d) |
| 4 | Tests für Migration, Entry-CRUD, unveränderte Aggregate | Erfüllt |
| 5 | Journal in ZIP-Export und `.shiptrip`-Teilen-Datei | Erfüllt (T7b) |

Die Integration in den vollen Build ist mit T8d-1 (6e891c8) erfolgt; die
Vollsuite läuft auf dem aktuellen Stand grün (553 Unit-Tests, 4 UI-Tests),
Statistiken, Export und Teilen sind regressionsfrei. Offen bleiben nur der
Gerätetest 1.8.0 → 1.8.5 auf echter Hardware und die CloudKit-Schema-Promotion
(siehe „Known Limitations").

- **1:** `JournalEntry` trägt `id`, `text`, `entryDate`, `moodRaw`, `createdAt`,
  `updatedAt` — alle nicht-optionalen Attribute mit Default, alle Beziehungen
  optional, kein `.unique`-Constraint (ADR-002-Regeln). `Photo` ist additiv um
  `caption: String = ""` und die Rückbeziehung `journalEntry` erweitert.
  `JournalStoreFixtureMigrationTests` öffnet einen eingefrorenen 1.8.0-Store mit
  dem neuen Schema: Reisen und Häfen überleben samt Beziehungen, `caption`
  startet leer, die neue Tabelle ist leer und sofort beschreibbar, und ein
  zweites Öffnen bleibt stabil. Der Nachweis auf einem echten Gerät (1.8.0 →
  1.8.5 drüber) steht aus.
- **2/3:** Die Zuordnungs- und Klapp-Regeln liegen als reine, SwiftUI-freie
  Structs vor (`RouteJournalPlanner`, `RouteCollapsePlanner`,
  `JournalEditorDefaults`) und sind damit isoliert getestet; die Views setzen
  sie nur um. `JournalRouteFadenUITests` fährt den Kern-Flow (anlegen → in der
  Stopp-Karte sehen → öffnen → bearbeiten → löschen), die Klapp-Automatik in
  beiden Phasen und den Sammelblock durch die echte App.
- **4:** `JournalLWWMatrixTests` deckt die Mutations-Matrix J2a zeilenweise ab —
  inklusive der Nullify-Pfade in `JournalDeletePaths`, die SwiftData nicht von
  selbst bumpt; `JournalDeletePathBindingTests` hält fest, dass die UI-Einstiege
  wirklich an diesen Pfaden hängen. `JournalDayTests` prüft den
  Zeitzonen-Vertrag (Normalisierung auf 12:00 UTC des Tag-Tripels, Vergleiche
  über Tag-Tripel statt lokalem `startOfDay`). `JournalAggregateRegressionTests`
  hält Foto-Zählung und Hafen-Anläufe unverändert, obwohl Fotos jetzt zusätzlich
  an Einträgen hängen können.
- **5:** `JournalExportRoundtripTests` und
  `JournalExportLegacyCompatibilityTests` sichern Hin- und Rückweg sowie das
  Verhalten gegenüber älteren Dateien.

## Lokalisierung & Bedienungshilfen

Alle user-sichtbaren Strings der Journal-Ansichten liegen mit deutschem
Wortlaut-Key und englischer Übersetzung im `Localizable.xcstrings`
(Quellsprache Deutsch, `de` deshalb implizit). Zähler laufen über
Plural-Keys (`%lld Fotos`), Datumsangaben über `Date.FormatStyle`.

Bedienungshilfen: die Klapp-Kopfzeile meldet ihren Zustand als
Accessibility-*Value* („aufgeklappt"/„zugeklappt") plus Hinweis, das Chevron
ist als rein dekorativ ausgeblendet. Eintragszeilen sind ein zusammengesetztes
Element mit Button-Trait und Öffnen-Aktion. Die Stimmungs-Auswahl markiert die
Wahl nicht nur farblich, sondern über den `isSelected`-Trait; alle Tap-Ziele
sind mindestens 44 pt hoch. Stabile `accessibilityIdentifier` (`routeStop.*`,
`journalEntryRow`, `journalDetail.*`, `journalEditor.*`) tragen zugleich die
UI-Tests.

## Known Limitations

- **Leere Route = kein Einstieg:** Ohne Route-Stopp gibt es im Abschnitt nur
  „Hafen hinzufügen" — der Sammelblock zeigt zwar trägerlose Einträge, bringt
  aber selbst keinen Erfassungs-Einstieg mit, solange er leer ist. Wer in einer
  Reise ohne Häfen schreiben will, muss zuerst einen Stopp anlegen.
- **Klapp-Zustand überlebt die Ansicht nicht:** bewusst kein persistentes Feld
  (kein Schema-/CloudKit-Eingriff, J3neu (b)) — eine frisch geöffnete
  Detailansicht steht wieder auf dem Automatik-Default.
- **`updatedAt` wird nie automatisch gebumpt:** Jeder Schreib- und Lösch-Pfad
  muss die Bumps selbst ausführen; deshalb sind `port` und `photosStorage`
  von außen nur lesbar, Schreibzugriff läuft über `setPort`, `attach`, `detach`
  und `JournalDeletePaths`. Neue Pfade müssen diese Regel einhalten, sonst
  verliert der CloudKit-Merge Änderungen.
- **CloudKit-Schema ist noch nicht promotet:** Der neue Record-Type
  `CD_JournalEntry` und die neuen Felder müssen vor dem Release nach ADR-002
  in Development installiert und nach Production promotet werden.
- **Import-Asymmetrie bleibt:** 1.8.0-Installationen importieren neue Dateien
  fehlerfrei, verlieren Journal und Captions dabei aber still (DTO-Contract in
  ADR-003, Abschnitt „Export- und Teilen-Integration").
- **Kein `isDemo` auf `JournalEntry`:** Die Demo-Filterung läuft über
  `cruise?.isDemo` wie bei allen Kind-Modellen. Die Beispielreise bringt
  bislang keine Journal-Einträge mit.
- **Unbekannte Stimmungs-Rohwerte** (etwa aus einer neueren App-Version via
  Sync) bleiben verbatim erhalten, werden aber wie „keine Stimmung" behandelt.

## Related Decisions

- [ADR-003: Journal-Kern](../adr/ADR-003-journal-kern.md)
- [Journal-Editor-Contract (J1–J5, J3neu)](../architecture/contracts/journal-editor-contract.md)
- [ADR-002: CloudKit-Sync und stabile IDs](../adr/ADR-002-cloudkit-sync-und-stabile-ids.md)
- [ADR-007: Kreuzfahrt teilen](../adr/ADR-007-kreuzfahrt-teilen.md)
