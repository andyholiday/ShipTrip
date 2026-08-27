# Journal (Reisetagebuch)

**Stand:** Modell-Schicht gemergt (T7, Run 1.8.5). Export/Teilen (T7b) und
Bedienoberfläche (T8) sind geplant, aber noch nicht gebaut.
**Code:** `ShipTrip/Models/JournalEntry.swift`, `ShipTrip/Models/JournalDay.swift`,
`ShipTrip/Models/JournalDeletePaths.swift`, `ShipTrip/Models/Photo.swift`
(`caption`, `journalEntry`), `ShipTrip/Models/Cruise.swift` und
`ShipTrip/Models/Port.swift` (Rückbeziehungen)
**Tests:** `JournalEntryModelTests`, `JournalDayTests`, `JournalLWWMatrixTests`,
`JournalAggregateRegressionTests`, `JournalStoreFixtureMigrationTests`
(gegen `ShipTripTests/Fixtures/store-1.8.0/`)

## Acceptance-Status

Kriterien aus `.planning/ZIEL.md` (Journal-Kern 1.8.5). Verifikationsstand nach
dem T7-Merge: 465/465 Unit-Tests grün.

| Nr. | Kriterium (Kurzfassung) | Status |
|---|---|---|
| 1 | `JournalEntry` + `Photo.caption`, CloudKit-konform, Alt-Store öffnet verlustfrei | Erfüllt bis auf den Gerätetest |
| 2 | Editor „Erinnerung zuerst" mit vorbelegten Eckdaten | Offen (T8) |
| 3 | Tagebuch-Strang in der Reise-Detailansicht | Offen (T8) |
| 4 | Tests für Migration, Entry-CRUD, unveränderte Aggregate | Erfüllt für die Modell-Schicht |
| 5 | Journal in ZIP-Export und `.shiptrip`-Teilen-Datei | Offen (T7b) |

- **1:** `JournalEntry` trägt `id`, `text`, `entryDate`, `moodRaw`, `createdAt`,
  `updatedAt` — alle nicht-optionalen Attribute mit Default, alle Beziehungen
  optional, kein `.unique`-Constraint (ADR-002-Regeln). `Photo` ist additiv um
  `caption: String = ""` und die Rückbeziehung `journalEntry` erweitert.
  `JournalStoreFixtureMigrationTests` öffnet einen eingefrorenen 1.8.0-Store mit
  dem neuen Schema: Reisen und Häfen überleben samt Beziehungen, `caption`
  startet leer, die neue Tabelle ist leer und sofort beschreibbar, und ein
  zweites Öffnen bleibt stabil. Der Nachweis auf einem echten Gerät (1.8.0 →
  1.8.5 drüber) steht aus.
- **4:** `JournalLWWMatrixTests` deckt die Mutations-Matrix J2a zeilenweise ab —
  inklusive der Nullify-Pfade in `JournalDeletePaths`, die SwiftData nicht von
  selbst bumpt. `JournalDayTests` prüft den Zeitzonen-Vertrag (Normalisierung
  auf 12:00 UTC des Tag-Tripels, Vergleiche über Tag-Tripel statt lokalem
  `startOfDay`). `JournalAggregateRegressionTests` hält Foto-Zählung und
  Hafen-Anläufe unverändert, obwohl Fotos jetzt zusätzlich an Einträgen hängen
  können.

## Known Limitations

- **Kein Weg in die App:** Ohne Editor und Tagebuch-Strang (T8) lassen sich
  Einträge nur programmatisch anlegen; user-sichtbar ändert sich mit dem
  Modell-Merge nichts.
- **Einträge überleben weder Backup noch Teilen:** ZIP-Export/Import und die
  `.shiptrip`-Datei kennen die neuen Felder noch nicht (T7b). Der DTO-Contract
  dafür steht in ADR-003, Abschnitt „Export- und Teilen-Integration"; danach
  bleibt die dort dokumentierte Asymmetrie bestehen — 1.8.0-Installationen
  importieren neue Dateien fehlerfrei, verlieren Journal und Captions dabei
  aber still.
- **`updatedAt` wird nie automatisch gebumpt:** Jeder Schreib- und Lösch-Pfad
  muss die Bumps selbst ausführen; deshalb sind `port` und `photosStorage`
  von außen nur lesbar, Schreibzugriff läuft über `setPort`, `attach`, `detach`
  und `JournalDeletePaths`. Neue Pfade müssen diese Regel einhalten, sonst
  verliert der CloudKit-Merge Änderungen.
- **CloudKit-Schema ist noch nicht promotet:** Der neue Record-Type
  `CD_JournalEntry` und die neuen Felder müssen vor dem Release nach ADR-002
  in Development installiert und nach Production promotet werden.
- **Kein `isDemo` auf `JournalEntry`:** Die Demo-Filterung läuft über
  `cruise?.isDemo` wie bei allen Kind-Modellen. Ob die Beispielreise
  Journal-Einträge bekommt, ist eine offene Produktentscheidung.
- **Unbekannte Stimmungs-Rohwerte** (etwa aus einer neueren App-Version via
  Sync) bleiben verbatim erhalten, werden aber wie „keine Stimmung" behandelt.

## Related Decisions

- [ADR-003: Journal-Kern](../adr/ADR-003-journal-kern.md)
- [Journal-Editor-Contract (J1–J5)](../architecture/contracts/journal-editor-contract.md)
- [ADR-002: CloudKit-Sync und stabile IDs](../adr/ADR-002-cloudkit-sync-und-stabile-ids.md)
- [ADR-007: Kreuzfahrt teilen](../adr/ADR-007-kreuzfahrt-teilen.md)
