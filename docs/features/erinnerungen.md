# Erinnerungen (lokale Push-Mitteilungen)

Vorab- und Abreise-Erinnerungen zu einer Reise, geplant über
`UNUserNotificationCenter`.

Quellen:
[NotificationService.swift](../../ShipTrip/Services/NotificationService.swift),
[NotificationReconciler.swift](../../ShipTrip/Services/NotificationReconciler.swift),
Callsites in
[CruiseFormView.swift](../../ShipTrip/Views/Cruises/CruiseFormView.swift),
[CruiseListView.swift](../../ShipTrip/Views/Cruises/CruiseListView.swift),
[CruiseDetailView.swift](../../ShipTrip/Views/Cruises/CruiseDetailView.swift).

## Acceptance-Status

Stand 1.7.1 (2026-08-23):

- Erfüllt: Notification-Identifier werden aus der stabilen `Cruise.id` gebildet,
  nicht mehr aus `persistentModelID`. Mehrfaches Speichern derselben Reise legt
  keine zusätzliche Pending Request an; Repro-Test war vor dem Fix rot.
- Erfüllt: `removeReminders` läuft vor jedem Planen, auch bei Neuanlage.
- Erfüllt: `NotificationReconciler` läuft bei jedem App-Start (nach
  `IdBackfill`), entfernt Requests mit dem Legacy-Prefix `cruise-` und plant
  alle zukünftigen Reisen gemäß den aktuellen Erinnerungs-Einstellungen und der
  erteilten Berechtigung idempotent nach. Adds laufen vor Removes, damit ein
  fehlgeschlagenes Add keine bestehende Erinnerung entfernt. Demo-Reisen sind
  ausgenommen.
- Erfüllt: Die Reconcile-Logik ist als reine Funktion unit-getestet
  ([NotificationReconcileTests.swift](../../ShipTripTests/NotificationReconcileTests.swift)),
  ohne `UNUserNotificationCenter`.
- Offen: kein Test über die reale iOS-Notification-Registry; der Beweis für
  „genau eine Mitteilung" endet an der Seam `NotificationScheduling`.

## Known Limitations

- Eine Änderung am Erinnerungs-Toggle oder am Tage-vorher-Offset in den
  Einstellungen stößt keinen sofortigen Abgleich an. Sie wirkt auf
  Bestandsreisen erst beim nächsten App-Start oder beim nächsten Speichern der
  jeweiligen Reise
  ([SettingsView.swift](../../ShipTrip/Views/Settings/SettingsView.swift)).
- Die Vorab-Erinnerung erbt die Uhrzeit des reinen Datumswerts `startDate`
  (00:00). Bei importierten Reisen aus einer anderen Zeitzone kann sie dadurch
  am falschen lokalen Tag feuern. Vorbestehend, nicht Teil von 1.7.1
  ([NotificationService.swift](../../ShipTrip/Services/NotificationService.swift)).
- `prefixFilterLogic` in
  [ShipTripTests.swift](../../ShipTripTests/ShipTripTests.swift) beschreibt noch
  das alte `cruise-<id>-`-Schema und prüft damit kein aktuelles Verhalten mehr.

## Related Decisions

- [ADR-002: CloudKit-Sync, stabile IDs und ZIP-Export](../adr/ADR-002-cloudkit-sync-und-stabile-ids.md)
  — liefert die stabile `Cruise.id`, aus der der Identifier gebildet wird.
