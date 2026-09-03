# Home-Screen-Widget

Stand: 1.9.0 in Arbeit (T0–T4 gemergt, W1-Fix eingearbeitet). Release-Schnitt,
Screenshot-Abnahme und Signing stehen aus — siehe Acceptance-Status.

Das Widget zeigt die Reiselage auf Home- und Sperrbildschirm: bei laufender Reise
den aktuellen Stopp mit Zeiten und den nächsten, vor einer Reise den Countdown,
sonst den Hinweis, dass keine Reise geplant ist. Ein Tipp öffnet die App
(WidgetKit-Standard, kein Deep-Link auf eine Reise).

Quellen: `ShipTrip/WidgetShared/WidgetSnapshot.swift`, `WidgetSnapshotStore.swift`,
`WidgetState.swift`, `WidgetStateResolver.swift`, `WidgetTimelinePlanner.swift`,
`WidgetSnapshotPublishing.swift`; App-Seite `ShipTrip/Services/WidgetSnapshotWriter.swift`
und `WidgetSnapshotPublisher.swift`; Extension `ShipTripWidget/` (Provider, Views,
`WidgetFormatting.swift`, `Localizable.xcstrings`).

## Familien

`systemSmall`, `systemMedium`, `accessoryRectangular`, `accessoryCircular`
(`StaticConfiguration`, kein Konfigurations-Intent). Jede Familie rendert alle vier
Zustände; `accessoryCircular` zeigt nur Symbol plus höchstens einen Kurzwert.

## Zustände und Wortlaut

Die Ableitung ist eine pure Funktion: `WidgetStateResolver.resolve(_:now:calendar:)`
bildet Snapshot plus Zeitpunkt auf genau einen Zustand ab. Demo-Reisen sind in keinem
Zweig enthalten (sie stehen gar nicht erst im Snapshot).

- **Aktiv** — Reise ab `startDate` bis zum Ende des Kalendertags von `endDate`; bei
  mehreren gewinnt der früheste Start. Gezeigt werden der aktuelle Eintrag der
  kanonischen Ordnung (`sortOrder`, bei Gleichstand `arrival`, dann `id`) mit
  „Ankunft HH:MM · Abfahrt HH:MM" sowie „Nächster Stopp: *Name*, *Datum*". Ist der
  aktuelle Eintrag ein Seetag, steht *Seetag* als aktueller Stopp. Nach dem letzten
  Eintrag tritt „Reiseende *Datum*" an die Stelle des nächsten Stopps; steht der erste
  Eintrag noch bevor, zeigt das Widget *Einschiffung* und den Reisezeitraum.
- **Countdown** — keine aktive, aber eine künftige Reise (frühester Start): Titel,
  Schiff und Restzeit im Wortlaut „Heute!", „Morgen", „In 12 Tagen", „In 3 Wochen",
  „In ca. 6 Wochen", „In 2 Monaten".
- **Keine Reise geplant** — „Keine neue Reise geplant" plus „Letzte Reise vor *N*
  Tagen/Wochen/Monaten" (bzw. „heute"/„gestern beendet"). Gibt es überhaupt keine
  Reise: „Noch keine Reise — leg deine erste an".
- **Nicht verfügbar** — „Öffne ShipTrip zum Aktualisieren", wenn der Snapshot fehlt
  (`.missing`), unlesbar ist (`.unreadable`, kaputtes JSON oder fremde
  `schemaVersion`) oder älter als 14 Tage ist (`.stale`).

Zeitlose Einträge — Ankunft außerhalb `[startDate, Ende des endDate-Tages]` — tragen
keine Uhrzeiten; ihr Tag ist `startDate` plus Index in der kanonischen Ordnung.

## Datenweg

Das Widget liest nie den SwiftData-Store, sondern eine Snapshot-Datei im geteilten
Container (Begründung: [ADR-009](../adr/ADR-009-widget-app-group-snapshot.md)).

- **App Group** `group.com.andre.ShipTrip`, Datei `widget-snapshot.json`
  (`WidgetSnapshotStore`). Schreiben atomar; scheitert es, bleibt die vorige Datei als
  Last-known-good stehen. Lesen wirft nie und stürzt nie ab.
- **Trigger:** ein zentraler Hook in `ShipTripApp` auf `ModelContext.didSave`, dazu
  `scenePhase == .active` und `NSPersistentStoreRemoteChange` als Sicherheitsnetz. Alle
  laufen durch `WidgetSnapshotPublisher.publish()` mit **1 s Debounce**, danach
  `WidgetCenter.shared.reloadAllTimelines()`. Fehler werden geloggt, nie geworfen — ein
  Widget-Problem darf keinen Speichervorgang der App abbrechen.
- **Kappung:** höchstens 3 Reisen (aktive, nächste geplante, jüngste vergangene),
  höchstens 40 Stopps je Reise (bei längeren Routen ein Fenster um den aktuellen
  Stopp), Datei < 64 KB. Keine Fotos, Koordinaten, Ausgaben oder Journaleinträge.
- **Stale-Regel:** ist `generatedAt` älter als 14 Tage, zeigt das Widget den
  Aktualisierungshinweis statt möglicher Falschdaten.
- **Timeline:** `WidgetTimelinePlanner.entryDates(for:now:calendar:)` liefert die
  Zeitpunkte möglicher Wechsel (Ankunft/Abfahrt des aktuellen und nächsten Stopps,
  Mitternachte, Reisestart, Reiseende) — höchstens 12, mit `.after`-Policy auf den
  letzten Eintrag.

## Architektur-Regeln

- `ShipTrip/WidgetShared/` ist der einzige von App und Extension geteilte Code und
  kennt **nur Foundation**: kein SwiftData, kein SwiftUI, kein WidgetKit, keine
  `String(localized:)`. Alle Werte sind `Sendable`, `Calendar` und `TimeZone` werden
  injiziert. Wortlaut und Formatierung entstehen erst im Widget-Target
  (`WidgetFormatting`), Zeitpunkte sind überall absolute Instants.
- **Jede neue Datei unter `WidgetShared/` muss in `ShipTrip.xcodeproj/project.pbxproj`
  in das `membershipExceptions`-Set des Widget-Targets eingetragen werden.** Der Ordner
  ist Teil der synchronisierten App-Gruppe; das Widget-Target bekommt daraus nur die
  namentlich aufgeführten Dateien. Ohne Eintrag baut die App weiter, die Extension
  nicht. (Die Planannahme, neue Dateien würden automatisch Mitglied, war falsch — sie
  kostete den Nachtrag in b8f4055.)
- Der SwiftData-/CloudKit-Store bleibt unverändert: kein Schema-Change, keine
  Store-Verlagerung, keine Migration.

## Acceptance-Status

Bezug: `.planning/ZIEL.md` (v5.1) K1–K5. Testbeleg für alle „runtime-verifiziert"-Zeilen
ist der Lauf über vier Widget-Suiten mit 38/38 grün
(`.winston-evidence/20260903T152731Z/gate-run.json`).

| Kriterium | Stand | Beleg |
|-----------|-------|-------|
| K1 Zustände | runtime-verifiziert | `WidgetStateResolverTests` (18), Store-Tests (6) |
| K2 Familien | **offen** | Views und Katalog DE/EN liegen; Abnahme T5 fehlt |
| K3 Datenweg | runtime-verifiziert | `WidgetSnapshotPublisherTests` (8) |
| K4 Timeline | runtime-verifiziert nach W1-Fix | `WidgetTimelinePlannerTests` (6), Fix bed8003 |
| K5 Release-Hygiene | in Arbeit | Doku und Katalog fertig; Bump/Gate (T5), Signing (T7) offen |

K3 deckt didSave, Anlegen/Bearbeiten/Löschen, Demo-Filter, Koaleszierung,
Failure-Injection und die Kappung ab.

## Known Limitations

- **Fremdgerät-Änderungen erst nach App-Lauf:** Der Snapshot ist so aktuell wie der
  letzte Vordergrund-Lauf dieser App. Eine auf einem anderen Gerät angelegte Reise
  sieht das Widget erst danach; dafür existiert die 14-Tage-Stale-Regel.
- **Import-Pfad ohne eigenen Test:** Anlegen, Bearbeiten, Löschen, Beispielreise und
  „Alle löschen" sind je durch einen Test belegt, der Import-Pfad nicht — er hängt am
  selben `didSave`-Hook, ist aber unbewiesen.
- **`accessoryCircular` zeigt die Abfahrtszeit, nicht die verbleibenden Tage:**
  `ActiveInfo` führt bewusst keinen vorberechneten Tageswert, und die Ansicht darf
  nicht selbst mit einem `Calendar` rechnen.
- **Kappung ist sichtbar:** Routen jenseits von 40 Stopps zeigt das Widget nur im
  Fenster um den aktuellen Stopp; mehr als drei relevante Reisen kennt es nicht.
- **Zwei Datenrepräsentationen:** SwiftData-Modelle und Snapshot-DTOs müssen bei
  Feldänderungen gemeinsam gepflegt werden; `schemaVersion` fängt nur Fehlversionen ab.

## Related Decisions

- [ADR-009: Widget liest einen Codable-Snapshot aus der App
  Group](../adr/ADR-009-widget-app-group-snapshot.md)
- [ADR-002: CloudKit-Sync, stabile IDs und
  ZIP-Export](../adr/ADR-002-cloudkit-sync-und-stabile-ids.md)
