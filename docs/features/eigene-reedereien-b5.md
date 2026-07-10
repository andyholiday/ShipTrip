# Welle B5 — Eigene Reedereien & Schiffe verwalten

**Status:** Abgeschlossen (B5.1, B5.2, B5.3)
**Testsuite:** 143/143 Unit-Tests PASS
**Quelle:** [Umsetzungsplan Audit 2026-07](../umsetzungsplan-audit-2026-07.md#welle-b5--eigene-reedereien--schiffe-verwalten-feedback-custom-reedereischiff-fehlt-m-referenz-vorschläge-nicht-ausblendbar-m--quelle-testflight-feedback-2026-07-03--app-store-review-3-2805--adr-006--gate-4),
TestFlight-Feedback 2026-07-03 und App-Store-Review ★3 28.05.

## Beschreibung

Welle B5 ergänzt den bisher rein hartkodierten Reederei-/Schiffskatalog
(`ShippingLine.all`) um ein Overlay aus nutzereigenen Reedereien und
Schiffen sowie um die Möglichkeit, einzelne Katalog-Vorschläge auszublenden.
Nutzer, deren Reederei oder Schiff im Katalog fehlt (kleine Anbieter,
Flusskreuzfahrten, Neubauten), können jetzt einen eigenen, wiederverwendbaren
Eintrag anlegen statt nur Freitext einzugeben. Der Katalog selbst bleibt
unangetastet; Picker in `CruiseFormView` und `DealsView` zeigen Katalog- und
eigene Einträge gemischt und alphabetisch sortiert. Architektur- und
Datenmodell-Entscheidung sind in [ADR-006](../adr/ADR-006-eigene-reedereien-und-schiffe-overlay-modell.md)
festgehalten (Overlay-Modell, kein Schema-Change an `Cruise`/`Deal`).

## Berührte Dateien / Module

- `ShipTrip/Models/CustomShippingLine.swift`, `CustomShip.swift`,
  `HiddenCatalogItem.swift` — drei neue, flache SwiftData-Modelle (CloudKit-
  konform: Defaults, keine Relationships, keine Uniques).
- `ShipTrip/Models/ShippingLineOption.swift` — DTOs `ShippingLineOption`/
  `ShipOption` (Quellen `catalog`/`custom`/`unlisted`) + `ShippingLineCatalogError`.
- `ShipTrip/Models/ShippingLine.swift` — `normalizedShipKey(_:)` aus
  `findByShipName` extrahiert; neue `ShippingLineNameMatching.collisionKey(_:)`
  für diakritik-insensitive Kollisions-/Sortierprüfung.
- `ShipTrip/Services/ShippingLineCatalogService.swift` — Merge-/Sortier-/
  Filter-Funktionen (`shippingLineOptions`, `shipOptions`) sowie schreibende
  Operationen (create/update/delete Custom-Reederei/-Schiff, hide/unhide
  Katalog-Reederei/-Schiff), reine `ModelContext`-basierte Funktionen ohne
  View-seitige Merge-Logik.
- `ShipTrip/Utilities/ShippingLineCatalogDedup.swift` — Post-Sync-Launch-
  Repair analog `IdBackfill.swift`, registriert im `.task`-Block von
  `ShipTrip/Views/Cruises/CruiseListView.swift`, eigenes Flag
  `shippingLineCatalogDedupCompleted.v1`.
- `ShipTrip/Views/Settings/ShippingLineManagementView.swift` — neue
  Verwaltungsansicht: eigene Reedereien/Schiffe anlegen, bearbeiten, löschen;
  Katalog-Einträge aus-/einblenden; Fehler-Alerts bei Namenskollision;
  Lösch-Hinweis, dass bestehende Reisen unverändert bleiben.
- `ShipTrip/Views/Settings/SettingsView.swift` — Navigationseinstieg zur
  Verwaltungsansicht.
- `ShipTrip/Views/Cruises/CruiseFormView.swift`, `ShipTrip/Views/Deals/DealsView.swift`
  — Picker zeigen Katalog + Custom gemischt/sortiert; Preserve-on-save-Fix
  (`resolvedShippingLineName`/`resolvedShipName`, `.unlisted`-Option für
  historische Werte, expliziter „Wählen…"-Reset über `userCleared`);
  `originalLineOptionID` verhindert Phantom-Schiffe beim Reederei-Wechsel im
  Bearbeiten-Formular.
- `ShipTrip/ShipTripApp.swift` — Schema-Registrierung der drei neuen Modelle.
- Tests: `ShipTripTests/ShippingLineCatalogServiceTests.swift`,
  `ShippingLineCatalogDedupTests.swift`, `ShippingLinePreserveOnSaveTests.swift`.

## Acceptance-Status (ADR-006, Tests 1–8)

Alle acht in ADR-006 definierten Acceptance-Tests sind durch Unit-Tests
abgedeckt:

1. Katalog + Custom gemischt, alphabetisch nach `collisionKey` sortiert — erfüllt.
2. Ausgeblendete Katalog-Reederei/-Schiff verschwindet aus den Optionen — erfüllt.
3. Unhide stellt den Eintrag an ursprünglicher Sortierposition wieder her — erfüllt.
4. Namenskollision (Katalog oder bestehender Custom-Eintrag) wird abgelehnt, kein Duplikat — erfüllt.
5. Löschen einer `CustomShippingLine` lässt bestehende `Cruise`/`Deal`-Freitexte
   unverändert und löscht zugehörige `CustomShip`-Zeilen mit (App-seitiges Cascade) — erfüllt.
6. `findByShipName` bleibt für alle Katalog-Schiffe funktional unverändert (Regressionstest) — erfüllt.
7. Post-Sync-Dedup: simulierte Cross-Device-Duplikate (`CustomShippingLine`,
   `CustomShip`, `HiddenCatalogItem`) werden deterministisch auf einen Gewinner
   reduziert, Rewiring vor Löschung — erfüllt.
8. Preserve-on-save: Bearbeiten und Speichern einer Reise mit gelöschter/
   ausgeblendeter Reederei/Schiff ohne Auswahländerung überschreibt den
   gespeicherten Namen nicht mit `""`/`nil` — erfüllt, für `CruiseFormView`
   und `DealsView`.

**Known Limitation:** Die `originalLineOptionID`-Bindung, die beim
Reederei-Wechsel im Bearbeiten-Formular Phantom-Schiffe (aus der vorherigen
Reederei übernommene Schiffsauswahl) verhindert, ist nur code-verifiziert
(`CruiseFormView.swift:206-214`), nicht durch einen dedizierten Unit-/UI-Test
abgesichert.

**Known Limitation (Codex-Gate #3, bewusste Scope-Entscheidung):**
`ExportImportService` nimmt die neuen Overlay-Daten (`CustomShippingLine`,
`CustomShip`, `HiddenCatalogItem`) nicht mit. Bestehende Reisen behalten beim
Export ihre `shippingLine`/`ship`-Freitexte, aber eigene Katalogeinträge und
Ausblendungen gehen bei Gerätewechsel per ZIP-Export/-Import verloren.
Nachziehen sinnvoll zusammen mit der geplanten Export-Härtung bzw.
CloudKit-Sync (Welle D2).

## Non-Goals (aus ADR-006, unverändert)

- `ShippingLine.findByShipName` (KI-Erfassung) bleibt katalog-only — eigene
  Schiffe werden bei der KI-gestützten Erfassung nicht erkannt.
- `shippingLineLogo` auf `Cruise`/`Deal` sowie `StatsView` zeigen für eigene
  Reedereien weiterhin nur den generischen Emoji-Fallback (`🛳️`), kein
  Custom-Logo.
- Kein Hidden-Zustand für eigene Einträge (löschen statt verstecken), kein
  Logo-Upload für eigene Reedereien, keine automatische Reparatur verwaister
  Hide-Keys bei Katalog-Umbenennungen.

## Welle D (2026-07-10, Build 18)

**Quelle:** TestFlight-Feedback zu Build 17. Zwei Nachbesserungen an der in
Welle B5 gebauten Verwaltung eigener Reedereien/Schiffe: ein Stock-Cover statt
generischem Ozean-Platzhalter, und direkte Weiterleitung zum ersten Schiff
nach dem Anlegen einer eigenen Reederei.

### D1 — Stock-Cover für eigene Reedereien/Schiffe

`ShippingLine.coverAssetCandidates(shippingLine:ship:)` (`ShipTrip/Models/ShippingLine.swift`)
bekommt einen neuen Fallback-Zweig: Schlägt der Katalog-Lookup
(`find(byName:)`/`findByShipName`) komplett fehl und ist mindestens einer der
beiden Namen nicht leer, wird deterministisch ein Stock-Bild aus dem
eingefrorenen Pool `ShippingLine.stockCoverPool` gewählt — 70 Assets
(`cover_line_<id>_1` bis `_5`) aus den 14 Katalog-Reedereien. Die Auswahl
läuft über eine feste FNV-1a-64-Hash-Implementierung (`fnv1aHash`) über die
normalisierten, zusammengesetzten Namen — bewusst **nicht** über Swifts
`Hasher`, da dessen Seed pro Prozessstart zufällig ist und die Zuordnung sonst
bei jedem App-Start wechseln würde.

Kandidaten-Reihenfolge im Fallback-Zweig (Katalog-Pfad bleibt unverändert):

1. `cover_ship_<slug>` (bestehender Legacy-Kandidat) — schützt Fälle wie
   „Cunard Line" + „Queen-Mary 2" (Tippfehler/Variante eines Katalog-Namens),
   die weiterhin ihr passendes Schiffs-Cover behalten, statt auf den neuen
   Stock-Pool umgeleitet zu werden.
2. Stock-Pool-Asset (neu, D1).
3. `cover_ocean_route` (bestehender neutraler Fallback) — wird immer als
   letzter Kandidat angehängt; nur wenn beide Namen leer sind, ist er der
   einzige Kandidat.

**Known Limitation:** Die Zuordnung ist namensbasiert. Ändert ein Nutzer den
in der Reise gespeicherten Reederei- oder Schiffsnamen, kann sich das
zugeloste Cover-Bild ändern. Pool-Liste und Hash-Funktion sind bewusst
eingefroren (statische Liste, kein dynamischer Bezug auf `ShippingLine.all`),
damit künftige Katalog-Erweiterungen bestehende Zuordnungen nicht verschieben.

### D2 — Nach Reederei-Anlage direkt zum ersten Schiff

`CustomLineFormSheet` (`ShipTrip/Views/Settings/ShippingLineManagementView.swift`)
meldet eine neu angelegte Reederei über einen `onCreated`-Callback, der nur
beim erfolgreichen Neuanlegen feuert — nicht beim Bearbeiten und nicht bei
Abbruch/Fehler. `ShippingLineManagementView` puffert die neue Reederei
zwischen (`pendingNewLine`) und übernimmt sie erst in `sheet(..., onDismiss:)`
in den Navigations-Trigger `newLineDestination`, damit sich Sheet-Dismiss- und
Push-Animation nicht überlappen. Die `navigationDestination(item:)` öffnet
`ShipManagementView` mit `presentShipFormInitially: true`, was das
Schiff-Anlegeformular über einen One-Shot-Guard
(`hasPresentedInitialShipForm`) genau einmal automatisch öffnet — erneutes
`onAppear` (z. B. nach Rückkehr in die Ansicht) löst es nicht erneut aus.

Abbruch-Pfade: Abbrechen im Reederei-Anlegeformular ruft `onCreated` nicht
auf, es gibt daher keine Navigation. Bearbeiten einer bestehenden Reederei
übergibt gar keinen `onCreated`-Callback und löst folglich nie eine
Navigation aus. Abbrechen im automatisch geöffneten Schiff-Formular lässt den
Nutzer in der (leeren) Schiff-Liste der neu angelegten Reederei zurück, ohne
dass sich das Formular erneut öffnet.

### Tests (Welle D)

- `CruiseCoverFallbackTests` in `ShipTripTests/CruiseAggregateTests.swift` um
  10 Fälle erweitert: Determinismus und Streuung der Stock-Zuordnung, exakte
  Kandidaten-Reihenfolge, zwei fest verdrahtete Frozen-Hash-Spotchecks,
  Leerwert-Guards (ein bzw. beide Namen leer), Katalog- und
  Near-Miss-Regressionen (bekannte Reederei/unbekanntes Schiff und
  umgekehrt bleiben unverändert), sowie Eindeutigkeit und Ladbarkeit aller 70
  Pool-Assets aus dem Asset-Katalog.
- Neue UI-Test-Datei `ShipTripUITests/ReedereiAnlegenUITests.swift`: Happy
  Path (automatisches Öffnen des Schiff-Formulars nach Reederei-Anlage,
  Abbruch landet in der Schiff-Liste der neuen Reederei, One-Shot-Guard
  verhindert erneutes Öffnen) und Abbruch-Pfad (Abbrechen im
  Reederei-Formular löst keine Auto-Navigation aus).

**Acceptance:** Quality-Gate GO, alle Tests grün (Stand 2026-07-10, Build 18).

## Related Decisions

- [ADR-006: Eigene Reedereien & Schiffe als Overlay über dem statischen Katalog](../adr/ADR-006-eigene-reedereien-und-schiffe-overlay-modell.md)
