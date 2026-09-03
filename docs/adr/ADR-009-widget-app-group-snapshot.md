# ADR-009: Widget liest einen Codable-Snapshot aus der App Group statt aus dem SwiftData-Store

**Status:** Accepted
**Datum:** 2026-09-03
**Autor:** Andre (Entscheid „Variante A", Session 12) · Plan `TASKPLAN-widget-1.9.0.md`, Codex-Gate #1+#4
**Querverweis:** ADR-002 (CloudKit-Sync, stabile IDs, Store-Constraints)

---

## Kontext

Für 1.9.0 bekommt ShipTrip ein Home-Screen-Widget (`ShipTripWidget`), das je nach
Reiselage den aktuellen Hafen mit Zeiten und den nächsten Stopp, einen Countdown
zur nächsten geplanten Reise oder den Hinweis „keine Reise geplant" zeigt.

Eine WidgetKit-Extension ist ein **eigener Prozess mit eigenem Sandbox-Container**.
Sie sieht den Datenbestand der App nur, wenn beide Targets einen Speicherbereich
teilen. Randbedingungen:

- Der Bestand liegt in einem SwiftData-Store mit aktiviertem CloudKit-Mirroring
  (ADR-002). Der Store trägt Nutzerdaten mehrerer Releases; sein Speicherort ist
  seit dem ersten Release der Default-Pfad im App-Container.
- Das Widget braucht davon nur einen Bruchteil: Reisetitel, Schiff, Start-/Enddatum
  und die Route mit Stopp-Namen, Zeiten und Seetag-Flag. Keine Fotos, keine
  Koordinaten, keine Ausgaben, kein Journal.
- Timeline-Provider laufen unter engem Zeit- und Speicherbudget und werden vom
  System auch im Hintergrund aufgerufen. Ein CloudKit-gespiegelter Store im
  Extension-Prozess würde dort Sync-, Migrations- und Merge-Arbeit auslösen.
- Ein Umzug der Store-Datei in die App Group ist eine einmalige, nicht
  zurücknehmbare Migration am Nutzerdatenbestand — mit CloudKit-Beteiligung und
  ohne einfachen Rückweg, wenn sie schiefgeht.

Andre hat diese Abwägung am 2026-09-03 explizit als **Variante A** entschieden:
Widget-Nutzen ja, Eingriff in den produktiven Store nein.

## Entscheidung

**1. App und Widget teilen die App Group `group.com.andre.ShipTrip`.**
Beide Targets tragen das Entitlement `com.apple.security.application-groups`.
Inhalt des geteilten Containers ist genau **eine** Datei: `widget-snapshot.json`.

**2. Der Snapshot ist ein versioniertes Codable-Wertmodell, keine Datenbank.**
`WidgetSnapshot` (`schemaVersion: Int = 1`, `generatedAt: Date`,
`cruises: [CruiseSummary]`) enthält nur die oben genannten Felder. Harte Grenzen:
**max. 3 Reisen** (aktive, nächste geplante, jüngste vergangene), **max. 40 Stopps**
je Reise, Datei **< 64 KB**. Reisen mit `isDemo == true` kommen nie hinein. Alle
Zeitpunkte sind absolute Instants; Kalendertage rechnet erst der Leser in der
Gerätezeitzone.

**3. Geschrieben wird ausschließlich app-seitig und serialisiert.**
Alle Writes laufen über `actor WidgetSnapshotWriter`, ausgelöst durch einen
zentralen Hook auf `ModelContext.didSave` (plus `scenePhase == .active` und
`NSPersistentStoreRemoteChange` als Sicherheitsnetz), koalesziert über einen
Debounce. Der Write ist atomar; schlägt er fehl, bleibt die vorige Datei als
**Last-known-good** stehen. Fehler werden geloggt, nie geworfen — kein
Widget-Problem darf einen Cruise-Save, einen Import oder einen Reset abbrechen.

**4. Gelesen wird defensiv, nie blockierend.**
`WidgetSnapshotStore.load()` liefert `.snapshot | .missing | .unreadable`.
Unbekannte `schemaVersion` und Decode-Fehler ergeben `.unreadable`, nie einen
Crash. Ist `generatedAt` älter als **14 Tage**, gilt der Snapshot als veraltet und
das Widget zeigt einen Aktualisierungshinweis statt möglicher Falschdaten.

**5. Der SwiftData-/CloudKit-Store bleibt unangetastet.**
Kein Schema-Change, keine Store-Verlagerung, keine Migration, kein SwiftData und
kein CloudKit im Widget-Target. Der geteilte Code unter `ShipTrip/WidgetShared/`
kennt nur Foundation.

## Alternativen

- **Store in die App Group verschieben (Variante B).** Das Widget läse den echten
  Bestand, auch von anderen Geräten frisch gesynct. Abgelehnt: Migration des
  produktiven Nutzerdatenbestands samt CloudKit-Mirroring, ohne einfachen
  Rückweg, für ein Feature, das mit einem 64-KB-Auszug auskommt. Zusätzlich
  CloudKit-Arbeit im Extension-Prozess unter dessen Budget. Bleibt als
  **Backlog-Option**, falls später Live-Daten ohne App-Start nötig werden.
- **Widget ohne geteilte Daten.** Kein App-Group-Entitlement, keine
  Signing-Änderung — das Widget könnte dann nur statische Inhalte oder einen
  App-Öffnen-Button zeigen. Abgelehnt: verfehlt die Anfrage vollständig, deren
  Kern die Reisedaten sind.
- **Snapshot in `UserDefaults(suiteName:)` der App Group.** Einfacher, aber ohne
  atomaren Write und ohne Größenkontrolle. Abgelehnt.

## Konsequenzen

**Positiv**

- Der produktive Store bleibt exakt wie in ADR-002 beschrieben; das Widget kann
  ihn weder migrieren noch beschädigen.
- Der Timeline-Provider liest eine kleine JSON-Datei — deterministisch, schnell,
  ohne Sync-Nebenwirkungen.
- Die Zustandsableitung ist eine pure Funktion über einem Wertmodell und damit
  ohne Simulator und ohne SwiftData unit-testbar.
- Bricht der Schreibweg, degradiert das Widget sichtbar (`.missing`,
  `.unreadable`, `.stale`) statt still falsche Zeiten zu zeigen.

**Neutral**

- Eine zusätzliche Datei im App-Group-Container, deren Inhalt eine Ableitung ist.
  Sie darf jederzeit gelöscht werden; der nächste App-Start baut sie neu.
**Negativ / bewusst in Kauf genommen**

- **Der Snapshot ist so aktuell wie der letzte App-Lauf.** Kommt eine Reise auf
  einem anderen Gerät dazu, sieht das Widget sie erst nach dem nächsten
  Vordergrund-Lauf dieser App. Genau dafür existiert die 14-Tage-Stale-Regel.
- **Zwei Datenrepräsentationen** (SwiftData-Modelle und Snapshot-DTOs) müssen bei
  Feldänderungen gemeinsam gepflegt werden; `schemaVersion` fängt Fehlversionen
  ab, verhindert die Doppelpflege aber nicht.
- **Die Kappung ist sichtbar:** Routen jenseits von 40 Stopps zeigt das Widget nur
  im Fenster um den aktuellen Stopp; mehr als drei relevante Reisen kennt es nicht.
- **Neue Signing-Pflicht:** Die App Group muss im Developer-Portal an beiden
  App-IDs hängen, und das App-Store-Profil für `com.andre.ShipTrip` ist neu
  auszustellen. Vor jedem Upload sind beide Entitlement-Sätze zu prüfen
  (Release-Schritt T7 im Taskplan).

## Implemented by

- [Home-Screen-Widget](../features/widget.md)

## Referenzen

- `.planning/ZIEL.md` (v5.1, 2026-09-03) — Erfolgskriterium 3 „Datenweg Snapshot (Variante A)"
- `.planning/TASKPLAN-widget-1.9.0.md` — Leitentscheidungen 1–9, Codex-Gate #1+#4
- `ShipTrip/WidgetShared/WidgetSnapshot.swift`, `WidgetSnapshotStore.swift` — Schema und Lesestrategie
- `ShipTrip/Services/WidgetSnapshotWriter.swift`, `WidgetSnapshotPublisher.swift` — Schreibweg
- [ADR-002: CloudKit-Sync, stabile IDs und ZIP-Export](ADR-002-cloudkit-sync-und-stabile-ids.md)
