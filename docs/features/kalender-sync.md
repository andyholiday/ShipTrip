# Kalender-Sync

Stand: 1.8.7, Wellen 0-2 gemergt (Modus-Umkehr, anklickbarer Ort,
Rollback-Meldung, Erinnerungs-Reconcile). Release-Schnitt steht aus.

ShipTrip trägt Reisen in einen vom Nutzer gewählten Gerätekalender ein, damit
Reisezeitraum und Route dort sichtbar sind, wo ohnehin geplant wird. Der Sync
ist einseitig: ShipTrip schreibt in den Kalender, liest von dort aber keine
Änderungen zurück. Quelle: `ShipTrip/Services/CalendarSyncService.swift`,
`CalendarEventPlanner.swift`, `CalendarSyncPreferences.swift`,
`CalendarSyncModeMigration.swift`, `CalendarMigrationCoordinator.swift`, UI
unter `ShipTrip/Views/Settings/CalendarSyncSettingsView.swift` und
`NotificationSettingsView.swift`.

## Verhalten heute

- **Aktivierung:** Einstellungen → *Kalender*. Ohne `fullAccess` auf EventKit
  läuft kein Sync; fehlt der eingestellte Kalender, meldet der Sync
  `CalendarSyncError.calendarMissing`.
- **Umfang (`CalendarSyncMode`):** zwei unabhängige Schalter — *Stopps
  eintragen* und *Gesamte Reise als Eintrag* — die auf vier Fälle abbilden:
  `itineraryOnly` (Default), `tripOnly`, `tripAndItinerary`, `none`. Stopps
  sind je ein Eintrag pro Hafen (Ankunft/Abfahrt als Zeitraum, sonst
  Ganztages-Eintrag) und pro Seetag; *Gesamte Reise* ist der eine
  Ganztages-Eintrag über den Reisezeitraum. Sind beide Schalter aus, weist die
  Ansicht darauf hin, dass keine Einträge angelegt werden. Beide Schalter sind
  auch bei ausgeschaltetem Sync bedienbar; jede Änderung löst bei
  eingeschaltetem Sync sofort einen Abgleich aus.
- **Default-Leseort:** `CalendarSyncPreferences.mode(in:)` ist die einzige
  Stelle, an der der Default `itineraryOnly` steht — Service, Observer und
  Einstellungen lesen darüber.
- **Bestands-Migration (`CalendarSyncModeMigration`):** läuft als erste
  Anweisung jedes `synchronize` und ist idempotent, Merker
  `calendarSyncModeMigratedV2`. Wer den Umfang schon einmal bewusst gewählt
  hat, behält ihn. Sonst entscheidet der Bestand: Steht zu einem
  Mapping-Schlüssel mit Suffix `/trip` noch ein Termin im Kalender, wird
  `tripOnly` festgeschrieben — der Ganzreise-Termin bleibt also, und es
  entstehen keine ungefragten Stopp-Einträge. Ohne solchen Termin gilt der neue
  Default. Ohne Kalenderzugriff fällt keine Entscheidung und der Merker bleibt
  aus, damit der nächste Lauf es nachholt.
- **Ort:** Hafen-Einträge mit gepflegter Koordinate bekommen eine
  `EKStructuredLocation` mit `geoLocation`, damit der Kalender Karte und
  Navigation öffnet; Titel bleibt `"Name, Land"`. Ohne Koordinate fällt der
  Eintrag auf den reinen Text-Ort zurück, Reise- und Seetagstermine tragen gar
  keine Koordinate.
- **Marker-URL:** Jeder Entwurf hat einen stabilen Schlüssel
  (`cruise/<UUID>/trip` bzw. `cruise/<UUID>/route/<Port-UUID>`), der als
  `shiptrip://calendar/<Schlüssel>` in `EKEvent.url` steht. Daran erkennt
  ShipTrip eigene Termine wieder.
- **Mapping:** Schlüssel → EventKit-Identifier liegt in `UserDefaults`
  (`calendarSyncManagedEventIdentifiers`). Es ist die primäre Wahrheit; nur was
  dort steht, gilt als verwaltet und wird je aufgeräumt.
- **Lösch-Journal:** Ersetzte Termine wandern nach dem Commit in
  `calendarSyncPendingRemovalIdentifiers` und werden erst danach gelöscht.
  Bricht der Vorgang dazwischen ab, arbeitet der nächste App-Start das Journal
  nach. Der Nachlauf ist idempotent — ein Identifier ohne Termin gilt als
  erledigt.
- **Dedup-Regeln:** Passt der zugeordnete Termin zum Zielkalender, wird er
  aktualisiert. Sonst sucht ShipTrip die Marker-URL im Zielkalender. Nur wenn
  gar kein Mapping-Eintrag existiert — der Restore-Fall nach Backup oder
  Neuinstallation — wird zusätzlich über die übrigen beschreibbaren Kalender
  gesucht. So entstehen keine Duplikate, ohne dass ein Kalenderwechsel
  wirkungslos wird.
- **Kalenderwechsel:** `migrateManagedEvents(cruises:)` läuft
  create-before-delete — die Einträge entstehen erst im neuen Kalender, danach
  verschwinden die alten über das Lösch-Journal. Termine werden nie zwischen
  Kalendern umgehängt. Scheitert das Anlegen, setzt
  `CalendarMigrationCoordinator` erst den bisherigen Zielkalender zurück und
  stellt danach die Termine wieder her. Scheitert auch das, meldet die Ansicht
  den Doppelfehler als Hinweis („Prüfe deinen Kalender und synchronisiere
  danach erneut") statt still zu bleiben. Die breite Marker-Suche ist im
  Wechsel bewusst abgeschaltet.
- **Erinnerungen:** Änderungen an Vorlauf oder Erinnerungs-Schaltern in
  Einstellungen → *Erinnerungen* stoßen über `onChange` sofort einen
  `NotificationReconciler`-Lauf an, statt bis zum nächsten App-Start zu warten.
- **Demo-Daten:** Reisen mit `isDemo` sind vom Sync ausgenommen, siehe
  [Beispielreise](beispielreise.md).
- **Abschalten:** `removeAllManagedEvents()` löscht alle verwalteten Termine
  und leert das Mapping.

## Testnaht statt Architektur-Entscheidung

`CalendarEventStoring` ist eine schmale Fassade um `EKEventStore` mit genau den
Methoden, die der Sync benutzt. Sie existiert allein, damit ein Test-Double
`save`/`remove`/`commit` gezielt scheitern lassen kann; sie ist keine
Abstraktionsebene für alternative Kalender-Backends. Deshalb gibt es dazu
keinen ADR.

## Acceptance-Status

Kriterien nach `.planning/ZIEL.md` (Kalender-Paket 1.8.7).

| Kriterium | Status | Beleg |
| --- | --- | --- |
| 1 — Umfang umgedreht, Opt-in, Bestands-Migration | erledigt | `CalendarSyncModeMigrationTests`, `CalendarSyncPlannerTests`, `KalenderUmfangUITests` |
| 2 — Anklickbarer Ort über `structuredLocation` | erledigt | `CalendarSyncModeMigrationTests` (strukturierter Ort, Koordinaten-Filter) |
| 3a — Bestandserkennung nach Restore ohne Duplikate | erledigt | `CalendarSyncHardeningTests` |
| 3b — Kalenderwechsel create-before-delete | erledigt | `CalendarSyncServiceMigrationTests` |
| 3c — Rollback getestet, Scheitern sichtbar | erledigt | `CalendarMigrationCoordinatorTests` |
| 3d — Erinnerungs-Änderung löst sofort Reconcile aus | erledigt, Testtiefe offen | `NotificationSettingsReconcileTests` (nur Weiterleiter) |
| 4 — Tests je Verhaltensänderung, Bestand grün | erledigt mit Lücken | Q1a F06/F07, siehe Known Limitations |
| 5 — Release-Reife 1.8.7 | offen | Release-Schnitt und Versionsanhebung nur auf Zuruf |

## Known Limitations

- **Restore ohne Mapping:** Fehlt nach Neuinstallation oder Backup-Rückspielung
  die UserDefaults-Domain, sieht die Bestands-Migration keinen Ganzreise-Termin
  und entscheidet `itineraryOnly`. Verloren geht nichts — die Aufräumschleife
  läuft nur über gemappte Schlüssel —, aber der alte Ganzreise-Termin bleibt
  als unverwaltete Karteileiche im Kalender stehen: nie wieder aktualisiert und
  von „Sync abschalten" nicht erfasst.
- **Zwei Geräte, verschiedene Zielkalender:** Die Einstellungen sind
  gerätelokal, die Kalenderdaten nicht. Nutzen zwei Geräte desselben Accounts
  unterschiedliche Zielkalender, kann die breite Marker-Suche einen Termin
  wechselseitig neu anlegen und den anderen löschen.
- **Reconcile-Tasks nicht serialisiert:** Schnelles Bedienen des Vorlauf-Steppers
  startet mehrere überlappende Abgleiche; ein älterer Lauf kann nach dem
  neueren fertig werden und den vorletzten Vorlauf festschreiben. Heilt beim
  nächsten App-Start.
- **Testlücken (Backlog Q1a):** Der Reconcile-Test prüft den Weiterleiter, nicht
  die `onChange`-Verdrahtung (F06); der Rollback-Test trifft die
  `calendarMissing`-Guard, nicht den Teilabbruch mitten im Anlegen (F07).
- **Lösch-Journal bei dauerhaftem Fehler:** Schlägt `remove` dauerhaft fehl,
  bleibt `calendarSyncPendingRemovalIdentifiers` unbegrenzt gefüllt und wird bei
  jedem Start erneut versucht — ohne Obergrenze für Versuche.
- **Source-Grenzen:** Ein Wechsel über EventKit-Source-Grenzen (iCloud → lokal
  → Google) ist für gespeicherte Termine nicht dokumentiert zugesichert; der
  Sync umgeht das durch Neuanlage, verlässt sich aber nicht darauf.
