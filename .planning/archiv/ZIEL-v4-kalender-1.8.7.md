# ZIEL — Kalender-Paket 1.8.7

(Aktiviert 2026-09-02, Session 11 — ersetzt das abgenommene Journal-Ziel
v3, archiviert unter `.planning/archiv/ZIEL-v3-journal-1.8.5.md`.
Andre-Entscheide 2026-09-02: voller Umfang „alles zusammen" (beide
Kalender-Wünsche + die vier Major-Härtungen) · Bestand behalten: wer schon
Ganzreise-Events hat, bekommt das Opt-in beim Update automatisch aktiviert.
Basis: release/1.8.6 = f6cdf05.)

**Ziel (1 Satz):** Der Kalender-Sync von ShipTrip trägt standardmäßig nur
noch die einzelnen Stopps mit anklickbarem Ort in den Kalender ein, der
Ganzreise-Eintrag wird zum expliziten Opt-in, und der Sync ist gegen
Duplikate, Datenverlust und stille Fehler gehärtet.

## Messbare Erfolgskriterien

1. **Sync-Umfang umgedreht (Andre-Wunsch 1):** Default für neue Nutzer ist
   „nur Stopps" — kein Ganztages-Eintrag über die gesamte Reise. In den
   Einstellungen gibt es ein explizites Opt-in „Gesamte Reise als Eintrag";
   Ein-/Ausschalten löst einen Reconcile aus (Ganzreise-Events werden
   angelegt bzw. entfernt). **Bestand:** Nutzer, die beim Update bereits
   verwaltete Ganzreise-Events im Kalender haben, bekommen das Opt-in
   automatisch aktiviert — nichts verschwindet ungefragt aus dem Kalender.
   Die bestehende Auswahl `CalendarSyncMode` (`tripOnly` /
   `tripAndItinerary`, CalendarEventPlanner.swift) wird migriert: ein
   heutiger `tripOnly`-Nutzer bekommt keine ungefragten Stopp-Einträge,
   ein `tripAndItinerary`-Nutzer behält beides. Genaue UI-Form (zwei
   Schalter vs. Picker) entscheidet der Plan.
2. **Anklickbarer Ort (Andre-Wunsch 2):** Stopp-Einträge tragen einen
   strukturierten Ort (`EKEvent.structuredLocation` mit Koordinaten aus dem
   `Port`), sodass der Kalender Karte/Navigation öffnet. Stopps ohne
   Koordinaten fallen auf den Text-Ort zurück, ohne den Sync zu brechen.
3. **Härtung (die 4 Majors aus dem Backlog):** (a) `matchingEvent`
   (CalendarSyncService.swift) findet bestehende verwaltete Events auch
   nach Restore/Neuinstallation — keine Duplikate — **ohne** dass ein
   Kalenderwechsel wirkungslos wird (breite Suche über beschreibbare
   Kalender nur im Restore-/Leer-Mapping-Fall, sonst weiter Zielkalender).
   (b) Kalender-Wechsel/Migration läuft create-before-delete: erst neu
   anlegen, dann alt löschen — nie Events über Source-Grenzen verschieben.
   (c) Rollback-Pfad der Migration (`restorePreviousCalendarEvents`,
   SettingsView) ist getestet, und sein Scheitern wird dem Nutzer sichtbar
   gemeldet. (d) Erinnerungs-Toggle/Offset-Änderung (SettingsView) löst
   sofort einen Reconcile aus statt erst beim nächsten App-Start.
4. **Tests & Bestand:** Jede Verhaltensänderung an CalendarSyncService ist
   durch Unit-Tests belegt (Sync-Umfang-Default, Opt-in-Reconcile,
   Bestands-Erkennung, structuredLocation, Dedup über Kalender,
   create-before-delete, Rollback). Bugfix-Härtungen tragen einen
   Rot-Beweis. Alle Bestandstests bleiben grün; `isDemo`-Reisen bleiben aus
   dem Sync ausgefiltert. Von den Kalender-Minors sind F15 (Tests mutieren
   UserDefaults.standard) und F16 (Testkalender-Leak) Pflicht, weil die
   neuen Tests dieselbe Infrastruktur nutzen; F06–F08, F13, F14 sind
   Backlog-Kandidaten, kein Kriterium.
5. **Release-Reife:** Marketing-Version 1.8.7, CHANGELOG-Eintrag,
   Feature-Doku zum Kalender-Sync aktualisiert; Release-Schnitt und
   TestFlight nur auf Andres Zuruf.
