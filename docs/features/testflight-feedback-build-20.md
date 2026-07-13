# TestFlight-Feedback: iCloud- und Kalender-Sync (Build 20)

## User Story

Als ShipTrip-Nutzer möchte ich meine Reisedaten über meinen privaten iCloud-
Account geräteübergreifend verfügbar halten und Reisen optional in einen von mir
gewählten Kalender spiegeln.

## Ausgangspunkt

Zwei TestFlight-Rückmeldungen vom 12.07.2026 forderten iCloud-Sync sowie einen
konfigurierbaren Kalender-Sync. Beim Kalender sollen Nutzer den Zielkalender und
die Detailstufe wählen können; Seetage sollen ihren Routen-Kontext zeigen.

## Scope

- SwiftData-Mirroring in die private CloudKit-Datenbank des Containers
  `iCloud.com.andre.ShipTrip`.
- Sichtbarer iCloud-Accountstatus unter „Mehr“.
- Opt-in-Kalender-Sync mit vollständigem EventKit-Zugriff und Auswahl eines
  beschreibbaren Zielkalenders.
- Modi „Nur Reisen“ und „Reisen, Häfen & Seetage“.
- Aktualisieren und Entfernen ausschließlich der von ShipTrip verwalteten Events.
- Demo-Reisen werden nicht in den Kalender gespiegelt.

Nicht enthalten sind Kalender-Freigaben, serverseitige Kalenderdienste oder
gemeinsam genutzte CloudKit-Datenbanken.

## Integration

- `ShipTripCloudSync` erstellt die persistente `ModelConfiguration` und liest den
  CloudKit-Accountstatus.
- `Cruise` hält CloudKit-kompatible optionale Storage-Beziehungen; berechnete
  Properties bewahren die bestehende App-API.
- `CalendarEventPlanner` erzeugt stabile, testbare Event-Entwürfe. Eine Reise ist
  ein ganztägiger Termin inklusive Endtag. Häfen nutzen vorhandene Zeiten;
  Seetage sind ganztägig und nennen, falls vorhanden, vorherigen und nächsten
  Hafen.
- `CalendarSyncService` verwaltet EventKit-Berechtigung, Zielkalender,
  deterministische `shiptrip://calendar/...`-Marker und lokale Event-ID-Mappings.
- `CalendarSyncObserver` synchronisiert bei aktiver App nach Reise- oder
  Einstellungsänderungen.

## Verifikation und Release-Status

- Planner- und CloudKit-Konfiguration besitzen fokussierte Unit-Tests.
- 293 Unit-Tests und 11 funktionale UI-Tests waren für Build 20 grün.
- Ein Simulator-Smoke-Test hat Erstellen und Entfernen eines echten
  Kalendertermins bestätigt.
- Ein echter Build-19→20-Upgrade-Smoke erhält eine bestehende Reise samt Route
  und öffnet weiterhin den bisherigen `default.store`.
- `docs/cloudkit/ShipTrip.ckdb` ist in der CloudKit-Development-Umgebung
  installiert.
- Build 20 wurde archiviert, produktiv signiert, zu TestFlight hochgeladen und
  erreichte in App Store Connect `processingState=VALID`. Die Production-
  Promotion des CloudKit-Schemas wurde für den nachfolgenden Build 21 beibehalten;
  ein echter iCloud-Geräte-Smoke war mangels verfügbarem entsperrtem Gerät nicht
  erneut durchführbar.
