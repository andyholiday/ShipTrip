# Home-Screen-Widget

Stand: 1.9.0 released (Version 1.9.0 / Build 29, TestFlight-Upload 2026-09-07).
Screenshot-Nachweis, Signing-Gate und Upload liegen vor — siehe Acceptance-Status.

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
  kanonischen Ordnung (aktuell ist das halboffene Zeitfenster `[Ankunft, Abfahrt)`,
  Ordnung nach `sortOrder`, bei Gleichstand `arrival`, dann `id`; haben mehrere Stopps
  gleichzeitig begonnen, gewinnt der in dieser Ordnung letzte) mit
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
- **Kaltstart:** ein `.task` am Wurzel-Aufbau der App veröffentlicht einmal je Start, damit
  ein frisch installiertes Gerät nicht ohne Snapshot bleibt, bis zufällig gespeichert wird
  (`ShipTripApp.swift`).
- **Separater Lesekontext:** gelesen wird je Veröffentlichung aus einem frischen
  `ModelContext(container)` (`autosaveEnabled = false`), nie aus dem `mainContext` — so
  landen offene, noch ungespeicherte Änderungen nie im Widget. Scheitert der Fetch,
  bricht der Publisher ab (kein Schreiben, kein Reload) und der Last-known-good bleibt
  stehen. Jeder Schreibvorgang trägt eine monotone Generationsnummer; der Writer
  verwirft überholte Aufträge, und nur der jüngste Lauf löst den Reload aus.
- **Kappung:** höchstens 3 Reisen (aktive, nächste geplante, jüngste vergangene),
  höchstens 40 Stopps je Reise (bei längeren Routen ein Fenster um den aktuellen
  Stopp), Datei < 64 KB. Keine Fotos, Koordinaten, Ausgaben oder Journaleinträge.
- **Stale-Regel:** ist `generatedAt` älter als 14 Tage, zeigt das Widget den
  Aktualisierungshinweis statt möglicher Falschdaten.
- **Timeline:** `WidgetTimelinePlanner.entryDates(for:now:calendar:)` liefert die
  Zeitpunkte möglicher Wechsel (Ankunft/Abfahrt des aktuellen und nächsten Stopps,
  Mitternachte, Reisestart, Reiseende) — höchstens 12, mit `.after`-Policy auf den
  letzten Eintrag. Die Liste reicht in jedem Zustand mindestens 24 Stunden und lässt
  zwischen zwei Einträgen höchstens 24 Stunden (Zwischenschritt am 25-Stunden-Tag).
  Auch „Keine Reise geplant" und „Nicht verfügbar" füllen diesen Horizont mit
  Mitternachts-Einträgen, statt nur einen einzigen Zeitpunkt zu liefern.

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

## Nachweis K2 / Screenshot-Harness

WidgetKit rendert die echten Widgets in einem fremden Prozess, den XCUITest nicht
erreicht. Belegbilder entstehen deshalb über eine Debug-Galerie in der App.

- **Galerie:** `ShipTrip/Views/Debug/WidgetPreviewGalleryView.swift` zeigt alle vier
  Familien in allen vier Zuständen in Widget-Rahmengröße. Sie ersetzt den Hauptbaum nur,
  wenn die App mit dem Launch-Argument `-widgetPreview` startet (`widgetPreviewOverride()`
  in `ShipTripApp.swift`).
- **Damit die Galerie dieselben Ansichten zeigt wie das Widget**, sind die Dateien aus
  `ShipTripWidget/Views/` und `WidgetFormatting.swift` zusätzlich Mitglied des
  App-Targets (`membershipExceptions` in `ShipTrip.xcodeproj/project.pbxproj`).
- **Suite:** `ShipTripUITests/WidgetScreenshotUITests.swift` (4 Tests) scrollt jede Zelle
  in Sicht und legt die Bilder unter `audit/screenshots/widget-*.png` ab.
- **Stolperstein:** Der Ausgabeordner kommt aus `SHIPTRIP_SCREENSHOT_DIR`. Fehlt die
  Variable, überspringt sich die Suite per `XCTSkip` **still** und meldet trotzdem grün.
  Bei `test-without-building` genügt es nicht, sie in der Shell zu setzen — sie muss in den
  `EnvironmentVariables`-Block der `.xctestrun`-Datei injiziert werden, sonst erreicht sie
  den Testprozess nie.

## Gestaltung

Die Richtung „Dynamic Instrument" stammt aus Andres Mockup-Bogen
(`docs/design/mookup_widgets.png`, Konzept 03); der nachgebaute Ausschnitt liegt als
[Konzeptbild](../design/assets/konzept-03-dynamic-instrument.png) im Repo. Die
Home-Screen-Familien sind ein dunkles Instrument — Navy-Grund in hellem wie dunklem
Erscheinungsbild, Cyan ausschließlich für Werte und Fortschritt, ein Ring um das
Zustandssymbol als Leitmotiv. Alle Werte stehen in
`ShipTripWidget/Views/WidgetStyle.swift`.

### Farben

| Token | Wert | Verwendung |
|-------|------|------------|
| `surfaceTop` / `surfaceBottom` | `#101E2E` / `#0B1622` | Kachelverlauf `surface` |
| `accent` | `#22D3EE` | Werte, Ring, Zeitleiste |
| `accentSoft` | `#38BDF8` | Startton des Verlaufs `progress`, diagonal |
| `primaryText` / `secondaryText` | Weiß / Weiß 72 % | Namen / Land, Schiff, Datum |
| `tertiaryText` / `track` | Weiß 55 % / Weiß 14 % | Beiwerk / offener Teil des Rings |

Kontrast Cyan auf Navy: 10,2:1; Nebentext rund 9:1, Beiwerk rund 5,4:1.

### Ring-Instrument je Familie

| Familie | Durchmesser | Linienstärke | Besonderheit |
|---------|-------------|--------------|--------------|
| `systemSmall` | 52 pt | 5 pt | Kopfzeile mit Uhrzeit neben dem Ring |
| `systemMedium` | 72 pt aktiv, sonst 54 pt | 6 pt | 42 % der Kachelhöhe, am Konzept gemessen |
| `accessoryRectangular` | 24 pt (+ 2 pt Vorlauf) | 3,5 pt | `monochrome`, `widgetAccentable` |
| `accessoryCircular` | Familiengröße | 4 pt | eigener Kreis über `AccessoryWidgetBackground` |

Der Ring zeigt den Anteil der verstrichenen Liegezeit (`WidgetProgress.elapsed`); ohne
Zeiten bleibt er als geschlossene, gedämpfte Spur stehen.

### Typografie und Zeitleiste

- Große Zahlen: `Font.widgetNumeral` — `.rounded`, `.bold`, `monospacedDigit`;
  32 pt im Kleinformat, 40 pt im Mittelformat (eng: 24 bzw. 28 pt). Die Einheit
  (`widgetUnit`, semibold) misst 55 % der Zahlengröße.
- Namen: `WidgetHeadline`, bold, 14–18 pt, `minimumScaleFactor` 0,7.
- Werte: `WidgetValueLine`, semibold, `monospacedDigit`, cyan.
- Kapitälchen-Zeile: `WidgetTagline`, 7 pt, Laufweite 1,4.
- Zeitleiste im Mittelformat: Spur 3 pt in `track`, Fortschritt im `progress`-Verlauf,
  Punkt 9 pt in `accent`.

### Bilder

Beide Assets liegen in `ShipTripWidget/Assets.xcassets` und stammen aus Codex Imagegen;
Kopien der Quellbilder unter `docs/design/assets/`.

| Asset | Größe | Einsatz |
|-------|-------|---------|
| `WidgetShipHero` | 600 × 600 px | Countdown (Medium): rund auf 84 pt, 2,5 pt cyaner Rand |
| `WidgetShipGhost` | 900 × 600 px | Silhouette hinter Medium aktiv: 150 × 142 pt, ausmaskiert |

### Regeln

- **Sperrbildschirm bleibt systemgerendert:** kein eigener Grund und keine eigenen
  Farben — übernommen werden nur Ring und Hierarchie (`monochrome: true`,
  `widgetAccentable`).
- **Ab Dynamic Type XXL hat Text Vorrang:** Ring, Bilder und der Balken der Zeitleiste
  entfallen, der gewonnene Platz geht an die Namen. Der Schriftgrad ist gedeckelt —
  `...xxLarge` auf dem Home-Screen, `...large` auf dem Sperrbildschirm.
- **Galerie-Screenshots brauchen das Asset-Katalog-Mitglied:** `Assets.xcassets` des
  Widgets steht in der `membershipExceptions`-Liste des App-Targets
  (`ShipTrip.xcodeproj/project.pbxproj`); ohne den Eintrag bleiben die Bilder in der
  Debug-Galerie leer.

Belege: [Kontaktbogen](../design/kontaktbogen-widget.html), Galerie-Shots unter
`docs/design/directions/shots/dynamic/`.

Stand der Abnahme: Gate r2 und Quality-Iteration 1 „go mit Backlog" (2026-09-13);
Gerätebestätigung durch Andre offen.

## Acceptance-Status

Bezug: `.planning/ZIEL.md` (v5.1) K1–K5. Testbeleg für alle „runtime-verifiziert"-Zeilen
sind 49/49 grün über vier Widget-Suiten — Store 7, Resolver 21, Planner 8, Publisher 13
(`.winston-evidence/20260903T161424Z/gate-run.json`, Commit 3735daf). Die volle Unit-Suite
lief vor den Fix-Runden 2 und 3 mit 619/619
(`.winston-evidence/20260903T154931Z/gate-run.json`).

| Kriterium | Stand | Beleg |
|-----------|-------|-------|
| K1 Zustände | runtime-verifiziert | `WidgetStateResolverTests` (21), Store-Tests (7) |
| K2 Familien | runtime-verifiziert | `WidgetScreenshotUITests` 4/4, 23 Bilder gesichtet |
| K3 Datenweg | runtime-verifiziert | `WidgetSnapshotPublisherTests` (13) |
| K4 Timeline | runtime-verifiziert | `WidgetTimelinePlannerTests` (8) |
| K5 Release-Hygiene | erfüllt | Signing-Gate T7 grün, TestFlight 1.9.0 (29) hochgeladen |

K2 ist per Sichtprüfung der 23 Bilder unter `audit/screenshots/widget-*.png` (Haupt-Repo,
unversioniert) abgenommen; Lauf `.winston-evidence/20260903T164049Z/gate-run.json`,
Commit 53b0833. ZIEL K2 erlaubt dabei ausdrücklich, dass der Reisetitel als Sekundärzeile
kürzt.

K3 deckt didSave, Anlegen/Bearbeiten/Löschen, Demo-Filter, Koaleszierung,
Failure-Injection, den separaten Lesekontext, den Fetch-Fehler-Abbruch und die Kappung ab.

K5 ist mit dem Signing-Gate T7 abgenommen: Die App Group `group.com.andre.ShipTrip` hängt
an beiden App-IDs, das Archiv signiert mit je einem Profil pro Target („ShipTrip App Store
1.9.0" für die App, „ShipTrip Widget App Store" für die Extension), und `codesign` weist
die Entitlements für App **und** Appex nach. Build 29 liegt in TestFlight; die
Signing-Befehle stehen unter [SETUP.md](../SETUP.md#fastlane--testflight-release).

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
- **Widget-Ansichten liegen auch im App-Binary:** Für die Screenshot-Galerie sind sie
  Mitglied des App-Targets. Außerhalb der Debug-Galerie ruft die App sie nicht auf; im
  Release wird der Code also mitgeliefert, ohne benutzt zu werden.
- **Zeitzonenwechsel während einer Reise ist nicht gesondert behandelt:** Alle
  Kalendertage entstehen in der jeweils aktuellen Gerätezeitzone; ein Wechsel an Bord
  verschiebt damit Tagesgrenzen im Widget.
- **Die 64-KB-Grenze ist nicht zur Laufzeit geprüft:** Sie ist nur durch einen Test am
  Maximalbestand belegt (`WidgetSnapshotStoreTests`); es gibt keinen Wächter, der einen
  zu großen Snapshot abweist.
- **Zwei Datenrepräsentationen:** SwiftData-Modelle und Snapshot-DTOs müssen bei
  Feldänderungen gemeinsam gepflegt werden; `schemaVersion` fängt nur Fehlversionen ab.

## Related Decisions

- [ADR-009: Widget liest einen Codable-Snapshot aus der App
  Group](../adr/ADR-009-widget-app-group-snapshot.md)
- [ADR-002: CloudKit-Sync, stabile IDs und
  ZIP-Export](../adr/ADR-002-cloudkit-sync-und-stabile-ids.md)
