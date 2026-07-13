# TestFlight-Feedback: Cover-Auswahl und Sync-Fortschritt (Build 21)

## User Story

Als ShipTrip-Nutzer möchte ich abwechslungsreiche, zum Schiff und zur Reise
passende Fallback-Cover sehen und beim manuellen Kalender-Sync erkennen, dass die
App noch arbeitet.

## Ausgangspunkt

Zwei TestFlight-Rückmeldungen zu Build 20 vom 13.07.2026 melden:

- Stock-Cover werden zu häufig wiederholt und passen teilweise nicht zu Schiff
  oder Reiseziel.
- Nach „Jetzt synchronisieren“ fehlt ein sichtbar anhaltender
  Fortschrittszustand.

Die TestFlight-API meldete dazu weiterhin keine Crash-Feedbacks.

## Scope

- Vorhandene schiffsspezifische Assets werden vor generischen Reederei- oder
  Stock-Covern priorisiert.
- Der vorhandene Stock-Pool wird um bereits vorhandene Schiffs-Cover erweitert.
- Die deterministische Auswahl berücksichtigt Reise- bzw. Zielkontext, bleibt
  für dieselbe Reise aber stabil.
- Der manuelle Kalender-Sync besitzt einen sichtbaren, lokalisierten
  Arbeitszustand und verhindert parallele Starts.
- CloudKit-Production-Schema, Datenschutzhinweise und Release-Dokumentation
  werden vor dem Build-21-Upload mit dem ausgelieferten Verhalten abgeglichen.

Nicht enthalten sind neue Bildgenerierung, eine Persistenzmigration für
Cover-Zuordnungen oder Änderungen am Kalender-Datenmodell.

## Abnahmekriterien

- Ein vorhandenes exaktes Schiffs-Cover gewinnt vor einem generischen Cover.
- Alle Stock-Pool-Einträge sind eindeutig und aus dem Asset-Katalog ladbar.
- Verschiedener Reise-/Zielkontext kann für dieselbe unbekannte
  Reederei-/Schiff-Kombination unterschiedliche Cover liefern; derselbe Kontext
  liefert stabil dasselbe Ergebnis.
- „Jetzt synchronisieren“ zeigt während der Operation eine Fortschrittsanzeige,
  deaktiviert den erneuten Start und endet im bisherigen Erfolgs-/Fehlerstatus.
- Fokustests, vollständige Unit-Tests und der Release-Build sind grün.
- Das CloudKit-Schema ist in Production nachweisbar und der neue Build erreicht
  in App Store Connect mindestens `processingState=VALID`.

## Integration

- Cover-Auswahl: `ShippingLine.coverAssetCandidates(...)` und die realen
  Aufrufer in Reise-Hero, Reise-Detail und Wunschreisen.
- Sync-Fortschritt: `CalendarSyncSettingsView` und ein testbarer
  Operationszustand im Einstellungen-Pfad.
- Release: `docs/cloudkit/ShipTrip.ckdb`, ADR-002, Datenschutz- und
  TestFlight-Dokumentation.

## Verifikation und Release-Status

- 296 Unit-Tests in 60 Suites: 0 Fehler.
- 31 UI-Tests: 30 bestanden, 1 expliziter Build-19-Migrationstest ohne
  vorbereitetes Alt-Store-Artefakt übersprungen, 0 Fehler.
- Fokustests für Cover-Auswahl und Sync-Operationszustand: grün.
- Das eingecheckte Schema entspricht der live exportierten Development-Umgebung;
  der Production-Export enthielt vor der Promotion nur den Systemtyp `Users`.
- Archiv und automatischer App-Store-Export für Version 1.7.0 (21) waren
  erfolgreich. Die exportierte IPA ist gültig signiert, enthält
  `aps-environment=production`, CloudKit-Umgebung `Production` und
  `get-task-allow=false`.
- Die IPA wurde erfolgreich hochgeladen. App Store Connect meldet
  `processingState=VALID`; intern ist Build 21 `IN_BETA_TESTING`, extern
  `WAITING_FOR_BETA_REVIEW`. Build 20 wurde dafür abgelöst und ist abgelaufen.
- Deutsche und englische Testhinweise sind am Build hinterlegt; die interne
  Gruppe „VIP Tester“ und die externe Gruppe „VIP Extern“ sind zugeordnet.
- Noch offen ist ausschließlich die kontogebundene Promotion des CloudKit-
  Schemas über die CloudKit Console. Der echte iCloud-Geräte-Smoke bleibt mangels
  verfügbarem entsperrtem Gerät als dokumentierte Einschränkung bestehen.
