# Kalender-Sync

Stand: 1.8.7, Welle 0 gemergt — Welle 1 (Modus-Umkehr, anklickbarer Ort,
Rollback-Meldung, Erinnerungs-Reconcile) ist geplant und noch nicht enthalten.

ShipTrip trägt Reisen in einen vom Nutzer gewählten Gerätekalender ein, damit
Reisezeitraum und Route dort sichtbar sind, wo ohnehin geplant wird. Der Sync
ist einseitig: ShipTrip schreibt in den Kalender, liest von dort aber keine
Änderungen zurück. Quelle: `ShipTrip/Services/CalendarSyncService.swift`,
`CalendarEventPlanner.swift`, UI unter
`ShipTrip/Views/Settings/CalendarSyncSettingsView.swift`.

## Verhalten heute

- **Aktivierung:** Einstellungen → *Kalender*. Ohne `fullAccess` auf EventKit
  läuft kein Sync; fehlt der eingestellte Kalender, meldet der Sync
  `CalendarSyncError.calendarMissing`.
- **Umfang (`CalendarSyncMode`):** `tripOnly` schreibt nur einen
  Ganztages-Eintrag über die gesamte Reise, `tripAndItinerary` zusätzlich je
  einen Eintrag pro Stopp — Häfen mit Ankunft/Abfahrt als Zeitraum, ohne Zeiten
  und Seetage als Ganztages-Eintrag. Default ist heute noch `tripOnly`.
- **Ort:** Hafen-Einträge tragen `"Name, Land"` als reinen Text-Ort. Ein
  strukturierter, anklickbarer Ort ist Welle 1.
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
  Kalendern umgehängt. Scheitert das Anlegen, bleibt der Bestand unangetastet
  und der Fehler wird durchgereicht. Die breite Marker-Suche ist hier bewusst
  abgeschaltet.
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

| Kriterium | Status |
| --- | --- |
| 1 — Sync-Umfang umgedreht, Opt-in „Gesamte Reise", Migration | in Arbeit (Welle 1) |
| 2 — Anklickbarer Ort über `structuredLocation` | in Arbeit (Welle 1) |
| 3a — Bestandserkennung nach Restore ohne Duplikate | erledigt (Welle 0) |
| 3b — Kalenderwechsel create-before-delete | erledigt (Welle 0) |
| 3c — Rollback-Pfad getestet und Scheitern sichtbar | in Arbeit (Welle 1) |
| 3d — Erinnerungs-Toggle löst sofort Reconcile aus | in Arbeit (Welle 1) |
| 4 — Tests je Verhaltensänderung, Bestand grün | teilweise (F15/F16 erledigt) |
| 5 — Release-Reife 1.8.7 | in Arbeit |

Welle 0 belegt 3a und 3b durch `ShipTripTests/CalendarSyncHardeningTests.swift`
und `CalendarSyncServiceMigrationTests.swift`; die Test-Fixtures mutieren nicht
mehr `UserDefaults.standard` und lassen keine Testkalender zurück (F15, F16).

## Known Limitations

- **Zwei Geräte, verschiedene Zielkalender:** Die Einstellungen sind
  gerätelokal, die Kalenderdaten nicht. Nutzen zwei Geräte desselben Accounts
  unterschiedliche Zielkalender, kann die breite Marker-Suche einen Termin
  wechselseitig neu anlegen und den anderen löschen — statt wie früher per
  Umhängen jetzt über das Lösch-Journal, aber weiterhin sichtbar.
- **Lösch-Journal bei dauerhaftem Fehler:** Schlägt `remove` dauerhaft fehl,
  bleibt `calendarSyncPendingRemovalIdentifiers` unbegrenzt gefüllt und wird
  bei jedem Start erneut versucht. Es gibt weder eine Obergrenze für Versuche
  noch ein Verwerfen unerreichbarer Identifier.
- **Source-Grenzen:** Ein Wechsel über EventKit-Source-Grenzen (iCloud → lokal
  → Google) ist für gespeicherte Termine nicht dokumentiert zugesichert; der
  Sync umgeht das durch Neuanlage, verlässt sich aber nicht darauf.
