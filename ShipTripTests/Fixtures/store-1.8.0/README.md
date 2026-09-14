# Fixture: eingefrorener 1.8.0-Store

Hier liegen `default.store`, `default.store-wal` und `default.store-shm` aus
einem echten 1.8.0-Build (Commit `92d19e1`) — die Beweisgrundlage fuer die
additive Lightweight-Migration aus
[ADR-003](../../../docs/adr/ADR-003-journal-kern.md), Abschnitt
„Migrationsstrategie".

**Erzeugen** (braucht das Build-Token, laeuft im Test-Build-Spawn):

```bash
./ShipTripTests/Fixtures/make-store-1.8.0-fixture.sh              # nur Beispielreise
./ShipTripTests/Fixtures/make-store-1.8.0-fixture.sh --manual-pause  # + manuelle Reise mit Fotos
```

Das Script legt einen Wegwerf-Simulator an, baut den 1.8.0-Stand, startet die
App mit `-uiTestingResetAndLoadDemoData` und kopiert die Store-Dateien hierher.
Mit `--manual-pause` wartet es, bis im Simulator zusaetzlich eine manuelle
Reise mit Fotos angelegt wurde (ADR-003, Fixture-Plan Schritt 1).

**Verbrauch:** `ShipTripTests/JournalStoreFixtureMigrationTests.swift`. Fehlt
`default.store`, ueberspringen die Tests sauber (`.enabled(if:)`) — sie werden
gruen, sobald die Dateien hier liegen und committet sind.

Die Dateien sind **eingefroren**: nie mit einem neueren Build ueberschreiben,
die Tests kopieren sie vor dem Oeffnen in ein temporaeres Verzeichnis.
