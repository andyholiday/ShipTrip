# ZIEL — Journal-Kern 1.8.5

(Aktiviert 2026-08-27, Session 7 — ersetzt das abgenommene Teilen-Ziel.
Andre-Entscheide: voller B2-Umfang inkl. Foto-Captions + Stimmung ·
D1 + D4 laufen im selben Run mit · Marketing-Version 1.8.5 ·
**Re-Anchoring 2026-08-27:** kein separater Tagebuch-Strang — Einträge
leben im Route-Abschnitt; Logbuch-Design-Richtung verworfen, keine neue
Designphase.)

**Ziel (1 Satz):** ShipTrip bekommt ein Reisetagebuch: Zu jeder Kreuzfahrt
lassen sich Journal-Einträge anlegen — die Erinnerung (Text, Fotos) steht
beim Erfassen an erster Stelle, Eckdaten (Tag, Hafen, Stimmung) folgen als
Zweitschritt — und erscheinen direkt in der Route der Reise-Detailansicht,
verankert am jeweiligen Hafen bzw. Reisetag.

## Messbare Erfolgskriterien

1. **Datenmodell & Migration:** `JournalEntry`-@Model (Tag/Datum, optionaler
   Port-Bezug, Text, Stimmung) + `Photo.caption: String = ""` — CloudKit-konform
   (Defaults, optionale Relationships, keine `.unique`-Constraints). Ein
   Alt-Store aus 1.8.0 öffnet nach dem Update verlustfrei; Migrationstest vor
   Release auf einem echten Gerät nachgewiesen.
2. **Editor „Erinnerung zuerst":** Der Eintrag-Editor beginnt mit der
   Erinnerung (Text und Fotos inkl. Bildunterschrift); Tag/Datum, Hafen und
   Stimmung folgen als zweiter Schritt und sind mit sinnvollen Defaults
   vorbelegt (heutiger Reisetag, passender Hafen — Auslegung von „Eckdaten
   als Zweitschritt", nicht wörtliche Andre-Vorgabe).
3. **Route-Integration (Re-Anchoring 2026-08-27):** Journal-Einträge
   erscheinen im Route-Abschnitt der Reise-Detailansicht am jeweiligen
   Stopp/Reisetag (Auszug + „Weiterlesen"; Fotos mit Captions); Einträge
   lassen sich dort anlegen, öffnen, bearbeiten und löschen. Klapp-Logik:
   Während einer aktiven Reise ist nur der aktuelle Tag aufgeklappt
   (Wechsel 0:00 lokale Zeit), davor/danach die komplette Route; manuelles
   Auf-/Zuklappen und „alles aufklappen" jederzeit möglich. Das UI bleibt
   im bestehenden Route-/Karten-Idiom (keine neue Design-Richtung);
   bindende Spec ist J3neu im journal-editor-contract + ADR-003-Nachtrag.
4. **Tests & Bestand:** Migration Alt-Store→neu, Entry-CRUD und unveränderte
   Aggregate (Statistiken, Export, Teilen) sind durch Tests belegt; alle
   Bestandstests bleiben grün. Beispielreise-Konvention gilt: `isDemo`-Objekte
   bleiben aus Export/Sync/Erinnerungen ausgefiltert (Auslegung der
   Bestands-Konvention; Demo-Journaleinträge sind KEINE Pflicht dieses Runs).
5. **Backup & Teilen (Andre-Entscheid 2026-08-27, „Beides in 1.8.5"):**
   Journal-Einträge und Foto-Captions wandern sowohl im ZIP-Export/Import
   (Backup) als auch in der `.shiptrip`-Teilen-Datei mit; Roundtrip-Tests
   beweisen Verlustfreiheit, und Alt-Dateien ohne Journal-Daten importieren
   weiterhin fehlerfrei (Abwärtskompatibilität).
6. **Wave-D-Reste & Release:** D2 erledigt (CruiseFormView-Dialoge in eigene
   Dateien, „Hafen-Momente"-Duplikat zusammengeführt) — Vorstufe vor dem
   Journal-UI. D1 erledigt (ISO-Ländercodes + zugehörige ADR). D4 erledigt
   (ADR-004 „Einmalkauf" persistiert, Reservierung aufgelöst, Produktrichtung
   in CLAUDE.md/docs angeglichen). Journal-Architektur in ADR-003
   festgeschrieben (Gate #4). Marketing-Version auf 1.8.5 gehoben,
   CHANGELOG-Eintrag gesetzt.
