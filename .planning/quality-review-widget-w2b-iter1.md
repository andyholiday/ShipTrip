# Review — W2b: T4 Widget-UI (statisch)

- **Iteration**: 1 / 3
- **Reviewer**: quality-agent (frischer Spawn)
- **Datum**: 2026-09-03
- **Worktree**: `/Users/andre-studio/Documents/0.Projekte/ShipTrip-worktrees/widget-1.9.0` @ HEAD `bed8003`
- **Diff-Scope**: Commit `06df8ad` (`ShipTripWidget/**`, 10 Dateien, +1422/-51)
- **Geladene Skills**: `code-review`, `swiftui`, `swift-standards`, `ux-review` (nur Checkliste)
- **Verdict**: **approve** (Go, mit Vorbehalt — s. „Testlage")
- **Stats**: critical: 0, major: 3, minor: 7 — Blocker: 0, ins Backlog: 10

## Summary

Die vier Familien-Ansichten setzen die Anfrage sauber um: aktueller Hafen **mit
Ankunfts- und Abfahrtszeit**, nächster Hafen bzw. Seetag, Countdown und
Leerlauf-Hinweis sind in `systemSmall`, `systemMedium` und
`accessoryRectangular` bei Standard-Schriftgrad vollständig vorhanden;
`accessoryCircular` reduziert erlaubterweise auf Symbol + Kurzwert und trägt
den vollen Satz im VoiceOver-Label. Der Provider ist korrekt (Planner-Termine,
Neuauflösung je Entry, `.after(letzter Eintrag)`) — die beiden W1-Backlog-Punkte
F04 und F05 sind erledigt. Katalog-Gegenprobe: **32 Quell-Keys, 32
Katalog-Keys, 0 fehlend, 0 verwaist, 32/32 mit `en`**. Keine Force-Unwraps,
keine Datei-/Netzzugriffe in Views, `guard.py sizes` grün.

Kein Blocker. Die drei `major` betreffen (a) einen Pflichtinhalt, der nur in der
Sperrbildschirm-Familie und nur ab Dynamic Type XXL entfällt, (b) den
Reisetitel im Countdown der Rectangular-Familie und (c) das komplette Fehlen
von Unit-Tests auf `WidgetFormatting` — der einzigen neuen reinen Logik im Diff.

## Testlage (ehrlich)

**Es wurde kein Test-/Build-Lauf gefahren.** Der Spawn-Auftrag verbietet
`xcodebuild` und Simulator explizit (Build-Token bei W2a). Es gibt daher
**kein `evidence_path`/`gate-run.json` zu diesem Review**. Statischer Pass
gelaufen: `guard.py sizes --files <9 geänderte .swift>` → `ok (9 geprueft, 0
Soft-Warnungen)`, größte Datei 198 Zeilen (Limit 400/500).

Das „Go" ist deshalb ein **statisches Go**: es sagt, dass der Code die Anfrage,
ZIEL K1/K2 und die Coding-Standards erfüllt. Es ersetzt **nicht** den grünen
Build beider Targets und den Screenshot-Beleg aus ZIEL K2 (12 Bilder DE/Light
+ EN + Dark, „kein abschneidendes … bei Dynamic Type L und XXL"). Ohne diese
Runde ist kein Release-Go möglich.

## Findings

| ID  | Severity | Blocker | File:Line | Kategorie | Titel |
|-----|----------|---------|-----------|-----------|-------|
| F01 | major | nein | `ShipTripWidget/Views/RectangularWidgetView.swift:68-70` | correctness | Ab Dynamic Type XXL entfällt die Zeile „Nächster Stopp"/„Reiseende" — Pflichtinhalt der Anfrage |
| F02 | major | nein | `ShipTripWidget/WidgetFormatting.swift:1-198` | tests | Keine Unit-Tests auf `WidgetFormatting` — Countdown-Tabelle und Plural-Zweige unbelegt |
| F03 | major | nein | `ShipTripWidget/Views/RectangularWidgetView.swift:41-44` | correctness | Countdown zeigt nie den Reisetitel, ab XXL auch nicht das Startdatum |
| F04 | minor | nein | `ShipTripWidget/Views/SmallWidgetView.swift:51-52,65-70` | correctness | Ab XXL entfällt der Reisetitel; im Zweig „Reise ohne Route" verlangt ZIEL K1 ihn |
| F05 | minor | nein | `ShipTripWidget/Views/RectangularWidgetView.swift:47-51` | ux | Leerlauf ohne Historie stapelt zwei widersprüchliche Aussagen |
| F06 | minor | nein | `ShipTripWidget/WidgetFormatting.swift:33,72` | i18n | `dateRange` und `stopDetailCompact` teilen den Identitäts-Key `"%@ – %@"` |
| F07 | minor | nein | `ShipTrip/WidgetShared/WidgetTimelinePlanner.swift:33-34` | correctness | Leerlauf/`unavailable` liefern Horizont < 24 h (ZIEL K4) |
| F08 | minor | nein | `ShipTripWidget/Views/WidgetStyle.swift:19-34` | maintainability | Journal-Farben dupliziert ohne Sync-Guard gegen `Color+Theme.swift` |
| F09 | minor | nein | `ShipTripWidget/PreviewFixtures.swift:8-12` | tests | Header verspricht XXL-Sichtbarkeit, keine `#Preview` setzt `dynamicTypeSize` |
| F10 | minor | nein | `ShipTripWidget/WidgetFormatting.swift:49-57` | correctness | `shortStopName`-Trennzeichenliste ungetestet und ohne Land-Fallback |

---

### F01 — Ab Dynamic Type XXL entfällt die Zeile „Nächster Stopp"/„Reiseende"

- **File**: `ShipTripWidget/Views/RectangularWidgetView.swift:68-70`
- **Severity**: major · **Blocker**: nein
- **Kategorie**: correctness (Wortlaut der Original-Anfrage)
- **Problem**: Andres Anfrage nennt zwei Pflichtelemente für die aktive Reise:
  aktueller Hafen mit Zeiten **und** der nächste Hafen bzw. der Seetag. In
  `accessoryRectangular` ist die dritte Zeile hinter `if !isTight` gehängt;
  `isTight` greift schon ab `.xxLarge` (`:24`) — das ist die zweitkleinste der
  nicht-Accessibility-Stufen und eine verbreitete Nutzereinstellung. Ab dort
  zeigt die Sperrbildschirm-Kachel nur noch Hafen + Zeiten, der Ausblick fehlt.
  Gleiches gilt für „Reiseende" nach dem letzten Stopp (`:84-85`).
- **Warum kein Blocker**: (1) Die Zeiten selbst — der von der Task-Spec als
  Blocker-Kandidat markierte Inhalt — überleben XXL in **allen** drei
  System-Familien (`SmallWidgetView.swift:61`, `MediumWidgetView.swift:157-159`,
  `RectangularWidgetView.swift:67` sind alle unbedingt). (2) Die primären
  Home-Screen-Familien `systemSmall`/`systemMedium` behalten den nächsten Stopp
  auch bei XXL (`SmallWidgetView.swift:75-81` schaltet nur auf die kurze
  Variante ohne Datum um, `MediumWidgetView.swift:89-105` kürzt nur die
  Spaltenüberschrift). (3) Der Inhalt bleibt über VoiceOver erreichbar:
  `RectangularWidgetView.swift:32` setzt
  `WidgetFormatting.accessibilityLabel(for:)`, und dessen `activeLabel`
  (`WidgetFormatting.swift:182-191`) enthält `nextStopLine` bzw. `cruiseEndLine`
  unabhängig vom Schriftgrad. (4) Die Kürzung ist eine bewusste, im Header
  dokumentierte Abwägung gegen ein abschneidendes „…", das ZIEL K2 verbietet.
- **Fix (für W3, nicht für diesen Run)**: Im Screenshot-Durchgang von ZIEL K2
  `accessoryRectangular` bei `.xxLarge` mit `activeLongNames` schießen. Passen
  drei Zeilen ohne Clipping in die Kachel, ersatzlos das `if !isTight` in
  `:68-70` streichen. Passen sie nicht, stattdessen die *zweite* Zeile
  komprimieren und den Ausblick behalten — z. B.
  `secondary(WidgetFormatting.time(departure))` statt `stopDetailCompact`, damit
  Zeile 3 frei wird. Entscheidung am Bild treffen, nicht am Quelltext.

### F02 — Keine Unit-Tests auf `WidgetFormatting`

- **File**: `ShipTripWidget/WidgetFormatting.swift:1-198` (besonders `:95-116`, `:126-145`, `:49-57`)
- **Severity**: major · **Blocker**: nein
- **Kategorie**: tests
- **Problem**: `WidgetFormatting` ist reine, seiteneffektfreie Logik — der am
  billigsten testbare Code im ganzen Diff — und hat null Abdeckung.
  `ShipTripTests/` enthält `WidgetSnapshotStoreTests`, `WidgetStateResolverTests`,
  `WidgetTimelinePlannerTests`, `WidgetSnapshotPublisherTests`, aber nichts zum
  Widget-Target: die synchronisierte Gruppe `ShipTripTests`
  (`project.pbxproj:89-92`) hat keine `membershipExceptions`, also ist keine
  Datei aus `ShipTripWidget/` im Testtarget.
  Ungedeckt bleibt damit ausgerechnet die Stelle, die laut Leitentscheidung 4
  eine *bewusste Duplikation* ist: die Countdown-Tabelle muss
  `cruiseStartDescription` (`Date+Extensions.swift:58ff`) nachbilden. Driftet
  eine der beiden, merkt das niemand.
  (Ich habe den Abgleich in diesem Review manuell gemacht — Schwellen `..<0` /
  `0` / `1` / `2...7` / `8...14` / `15...30` / `default` und die
  `>= 14`- bzw. `>= 60`-Verzweigungen sind **identisch**. Das ist ein Befund von
  heute, keine Garantie für morgen.)
- **Fix**: `ShipTripWidget/WidgetFormatting.swift` per
  `PBXFileSystemSynchronizedBuildFileExceptionSet` zusätzlich ins Target
  `ShipTripTests` aufnehmen (dasselbe Muster wie `project.pbxproj:59-70` für
  `WidgetShared`), dann `ShipTripTests/WidgetFormattingTests.swift` anlegen:

  ```swift
  @Test("Countdown-Wortlaut deckt sich mit cruiseStartDescription",
        arguments: [0, 1, 2, 7, 8, 13, 14, 15, 30, 31, 59, 60, 120])
  func countdownMirrorsAppWording(days: Int) {
      let date = Calendar.current.date(byAdding: .day, value: days, to: Date())
      #expect(WidgetFormatting.countdown(daysUntilStart: days) == date?.cruiseStartDescription)
  }

  @Test("Zeitloser Eintrag zeigt den Tag statt erfundener Uhrzeiten")
  func stopDetailWithoutTimes() {
      let stop = WidgetStopInfo(id: UUID(), name: "Kiel", country: nil,
                                isSeaDay: false, day: .now, arrival: nil, departure: nil)
      #expect(WidgetFormatting.stopDetail(stop) == WidgetFormatting.day(stop.day))
  }
  ```
  Dazu je ein Fall für `shortStopName` (s. F10) und `lastCruise` an den
  Schwellen 0/1/2/8/14/15/31/60.

### F03 — Countdown im Rectangular ohne Reisetitel

- **File**: `ShipTripWidget/Views/RectangularWidgetView.swift:41-44`
- **Severity**: major · **Blocker**: nein
- **Kategorie**: correctness
- **Problem**: Andres Anfrage: „soll ein contdown **mit der reise** im widget
  angezeigt werden"; ZIEL K1 präzisiert für den Countdown-Zweig „Reisetitel,
  Schiff, Startdatum und Restzeit". `RectangularWidgetView` zeigt Schiff (`:41`),
  Restzeit (`:42`) und — nur bei kleinem Schriftgrad — das Startdatum (`:43-44`).
  `info.title` kommt in dieser Familie **nie** vor, obwohl `CountdownInfo` ihn
  führt (`WidgetState.swift:85`). `SmallWidgetView.swift:91-92` und
  `MediumWidgetView.swift:111` zeigen ihn korrekt.
- **Warum kein Blocker**: Die Reise ist über Schiffsname + Startdatum
  identifizierbar, und das VoiceOver-Label (`WidgetFormatting.swift:172-173`)
  nennt den Titel. Kein Nutzer sieht einen leeren oder falschen Zustand.
- **Fix**: In `:41` den Titel als Kopfzeile führen und das Schiff in die
  Sekundärzeile ziehen — Titel ist die stärkere Identität, das Schiff die
  Beigabe:
  ```swift
  case .countdown(let info):
      headline(symbol: WidgetSymbol.ship, text: info.title)
      secondary(WidgetFormatting.countdown(daysUntilStart: info.daysUntilStart))
      if !isTight { secondary(info.ship, lines: 1) }
  ```
  Das Startdatum entfällt dabei zugunsten des Titels; die Restzeit trägt die
  Zeitinformation ohnehin.

### F04 — Reisetitel entfällt ab XXL, auch im Zweig „Reise ohne Route"

- **File**: `ShipTripWidget/Views/SmallWidgetView.swift:51-52` i. V. m. `:65-70`
- **Severity**: minor · **Blocker**: nein
- **Kategorie**: correctness
- **Problem**: ZIEL K1 schreibt für die aktive Reise ohne Route „Reisetitel +
  Schiff + Zeitraum" vor. `SmallWidgetView` blendet den Titel ab `.xxLarge` aus
  (`:51`), sodass in diesem Zweig nur Schiff (`:66`) und Zeitraum (`:67-70`)
  bleiben. In den anderen aktiven Zweigen ist der Verlust unkritisch (der
  Hafenname trägt die Information), hier ist der Titel der einzige Reisebezug.
- **Fix**: Im routenlosen Zweig den Titel als Headline statt des Schiffs setzen
  und das Schiff in die Caption ziehen — dann überlebt der Pflichtinhalt XXL
  ohne Zeilengewinn:
  ```swift
  } else {
      WidgetHeadline(symbol: WidgetSymbol.ship, text: info.title, lineLimit: isTight ? 3 : 2)
      WidgetCaption(text: isTight ? info.ship
          : "\(info.ship) · \(WidgetFormatting.dateRange(from: info.cruiseStart, to: info.cruiseEnd))",
          lines: 2)
  }
  ```
  (Die Zusammensetzung gehört dann als eigener Key nach `WidgetFormatting` —
  Views formatieren laut Header-Vertrag nichts selbst.)

### F05 — Leerlauf ohne Historie stapelt zwei widersprüchliche Aussagen

- **File**: `ShipTripWidget/Views/RectangularWidgetView.swift:47-51`
- **Severity**: minor · **Blocker**: nein
- **Kategorie**: ux (Nielsen #4 Konsistenz & Standards)
- **Problem**: Gibt es überhaupt keine Reise (`daysSinceLastCruise == nil`),
  rendert die Kachel „Keine neue Reise geplant" (`:47`) **und** darunter „Noch
  keine Reise — leg deine erste an" (`:51`). Zwei Leer-Aussagen übereinander,
  die erste sagt implizit „es gab mal welche". `SmallWidgetView.swift:114-116`
  und `MediumWidgetView.swift:138-140` zeigen in genau diesem Fall korrekt nur
  `noCruiseAtAll`. Familienübergreifende Inkonsistenz im selben Zustand.
- **Fix**: Die Headline in den `if let`-Zweig ziehen:
  ```swift
  case .idle(let info):
      if let days = info.daysSinceLastCruise {
          headline(symbol: WidgetSymbol.idle, text: WidgetFormatting.noPlannedCruise)
          secondary(WidgetFormatting.lastCruise(daysSince: days), lines: isTight ? 1 : 2)
      } else {
          headline(symbol: WidgetSymbol.idle, text: WidgetFormatting.noCruiseAtAll)
      }
  ```

### F06 — `dateRange` und `stopDetailCompact` teilen einen Identitäts-Key

- **File**: `ShipTripWidget/WidgetFormatting.swift:33` und `:72`
- **Severity**: minor · **Blocker**: nein
- **Kategorie**: i18n
- **Problem**: Beide erzeugen den Katalog-Key `"%@ – %@"`, dessen `en`-Wert
  wieder `"%@ – %@"` ist. Der Kommentar in `:31` nennt das bewusst, aber es
  koppelt zwei semantisch verschiedene Dinge (Datumsspanne „14. Mai – 21. Mai"
  vs. Uhrzeitspanne „08:00 – 17:00") an einen Übersetzungsslot. Will EN je
  „8:00 AM to 5:00 PM" für das eine und „May 14 – May 21" für das andere, ist
  das nicht mehr möglich, ohne beide Aufrufer zu ändern.
- **Fix**: Beide Aufrufe auf String-Interpolation ohne `String(localized:)`
  umstellen (`"\(day(start)) – \(day(end))"`) und die zwei Keys aus dem Katalog
  nehmen — ein reiner Bindestrich zwischen zwei bereits lokalisierten Werten
  braucht keinen Übersetzungsslot. Alternativ zwei getrennte Keys mit Kommentar
  (`String(localized:comment:)`) anlegen.

### F07 — Leerlauf-Timeline mit Horizont < 24 h

- **File**: `ShipTrip/WidgetShared/WidgetTimelinePlanner.swift:33-34`
- **Severity**: minor · **Blocker**: nein
- **Kategorie**: correctness (außerhalb des Diff-Scopes `06df8ad`, aber im Kontext geprüft)
- **Problem**: ZIEL K4 verlangt „Horizont mindestens 24 h". `.idle` und
  `.unavailable` liefern nur `[now, nextMidnight]`. Um 23:50 Uhr endet die
  Timeline zehn Minuten später. Die deklarierte Konstante
  `minimumHorizon` (`:19`) wird **nur im Test**
  (`WidgetTimelinePlannerTests.swift:129`, nur für Countdown/Aktiv) benutzt, im
  Planner selbst nie — die 24-h-Zusage ist damit für zwei von vier Zuständen
  weder erzwungen noch geprüft.
- **Warum kein Blocker**: Die `.after(letzter Eintrag)`-Policy im Provider
  (`ShipTripWidget.swift:66`) sorgt dafür, dass WidgetKit um Mitternacht neu
  anfragt — die Anzeige bleibt korrekt. Der Effekt ist ein etwas häufigerer
  Reload-Verbrauch, kein falscher Inhalt. Die Verkürzung ist in `:30-31`
  begründet dokumentiert.
- **Fix**: In `:34` die Tagesmitternachte auch für den Leerlauf nutzen, dann
  gilt der Horizont in allen Zweigen:
  `return [now] + dailyMidnights(after: now, count: 2, calendar: calendar)` —
  und die Zusicherung im Test auf `.idle`/`.unavailable` ausweiten
  (`WidgetTimelinePlannerTests.swift:148`).

### F08 — Journal-Farben dupliziert ohne Sync-Guard

- **File**: `ShipTripWidget/Views/WidgetStyle.swift:19-34`
- **Severity**: minor · **Blocker**: nein
- **Kategorie**: maintainability
- **Problem**: `surface` (#15212E / #FBF7F0) und `accent` (#36A9F0 / #0C8CE9)
  sind Hex-Nachbildungen von `Color.journalSurface` bzw.
  `Color.oceanBlue`/`oceanLight` aus `ShipTrip/Utilities/Color+Theme.swift`. Die
  Duplikation ist im Header begründet (eigenes Bundle, kein App-Import) und
  richtig — aber nichts hält die beiden Orte zusammen. Ändert die App ihren
  Papierton, driftet das Widget stumm, und der Fehler fällt erst auf einem
  Screenshot auf.
- **Fix**: Kein Code-Fix nötig. Einen Rückverweis-Kommentar in
  `Color+Theme.swift` an den drei Definitionsstellen setzen
  (`// Spiegelbild in ShipTripWidget/Views/WidgetStyle.swift — beide ändern`),
  damit die nächste Änderung die zweite Stelle findet. Die saubere Lösung
  (Asset-Katalog in der App Group) ist für 1.9.0 zu teuer.

### F09 — Previews decken den dokumentierten XXL-Fall nicht ab

- **File**: `ShipTripWidget/PreviewFixtures.swift:8-12`, Previews `:144-190`
- **Severity**: minor · **Blocker**: nein
- **Kategorie**: tests / doc
- **Problem**: Der Header verspricht, die zwei adversarial langen Fixtures seien
  da, „damit die Layout-Kuerzungen bei Dynamic Type XXL schon in der Vorschau
  sichtbar werden". Keine der vier `#Preview`-Deklarationen setzt aber
  `dynamicTypeSize` — und die WidgetKit-Preview-Form
  `#Preview(as:) { ShipTripWidget() } timeline:` nimmt einen
  `WidgetConfiguration` entgegen, an den sich `.environment(_:_:)` nicht hängen
  lässt. Die Zusage ist mit dieser Preview-Form nicht einlösbar; die Fixtures
  zeigen bei XXL im Canvas denselben Stand wie bei L.
- **Fix**: Header-Kommentar auf das korrigieren, was gilt („die langen Fixtures
  machen die Kürzungen sichtbar, sobald der Schriftgrad im Simulator/Canvas
  hochgesetzt wird"). Der XXL-Beleg gehört ohnehin nach W3: Simulator →
  Einstellungen → Anzeige & Helligkeit → Textgröße, dann die 12 Screenshots aus
  ZIEL K2. F01 und F04 hängen an genau diesem Beleg.

### F10 — `shortStopName`: Trennzeichenliste ungetestet

- **File**: `ShipTripWidget/WidgetFormatting.swift:49-57`
- **Severity**: minor · **Blocker**: nein
- **Kategorie**: correctness
- **Problem**: Die Funktion schneidet am ersten Treffer aus
  `["—", "–", " - ", ","]` ab und behält den Kopf, wenn er ≥ 3 Zeichen hat. Zwei
  unbelegte Annahmen: (1) Das Komma ist in der Liste, also wird aus
  „Sankt Petersburg, Russland" korrekt „Sankt Petersburg" — aber aus einem
  Hafennamen, dessen Kopf kürzer als 3 Zeichen ist (z. B. „Ko, Thailand"), wird
  nichts gekürzt und der volle Name landet in einer `lineLimit(1)`-Zeile
  (`RectangularWidgetView.swift:98`), wo `minimumScaleFactor(0.6)` ihn
  staucht. (2) `WidgetStopInfo` führt ein `country`-Feld
  (`WidgetState.swift:46`), das hier ungenutzt bleibt — der Ländername ließe
  sich zuverlässiger abtrennen als über Zeichenraten.
- **Fix**: Kein Umbau nötig, aber Abdeckung: die Fälle im Test aus F02
  mitnehmen (`"Puerto de la Cruz — Islas Canarias"` → `"Puerto de la Cruz"`,
  `"Kiel"` → `"Kiel"`, Seetag → `"Seetag"`, Kopf < 3 Zeichen → unverändert).
  Falls `country` bei echten Daten gefüllt ist, ist
  `full.replacingOccurrences(of: ", \(country)", with: "")` der ehrlichere Weg —
  das vor dem Umbau an echten `PortSuggestion`-Daten prüfen.

## Beantwortung der Prüffragen

**1. Wortlaut der Anfrage je Zustand** — erfüllt, mit einer Einschränkung.
Aktiv/aktueller Hafen mit Zeiten: `SmallWidgetView.swift:56-61`,
`MediumWidgetView.swift:70-77` (via `column(detail:)` → `:157-159`),
`RectangularWidgetView.swift:63-67`. Nächster Hafen bzw. Seetag
(`WidgetFormatting.stopName` → `:42-44` gibt bei `isSeaDay` „Seetag"):
`SmallWidgetView.swift:75-81`, `MediumWidgetView.swift:89-96`,
`RectangularWidgetView.swift:69` (**entfällt ab XXL → F01**). Countdown mit
Reise + Restzeit: `SmallWidgetView.swift:91-103`,
`MediumWidgetView.swift:111-126`, `RectangularWidgetView.swift:41-44`
(**ohne Titel → F03**). Leerlauf mit „keine neue Reise" + Abstand zur letzten:
`SmallWidgetView.swift:110-113`, `MediumWidgetView.swift:134-136`,
`RectangularWidgetView.swift:47-49`. Circular reduziert erlaubt
(`CircularWidgetView.swift:45-72`) und trägt den vollen Satz im
Accessibility-Label (`:40`).

**2. Provider** — alles korrekt. `getTimeline` nutzt
`WidgetTimelinePlanner.entryDates` (`ShipTripWidget.swift:52-53`) und ruft
`WidgetStateResolver.resolve(load, now: entryDate, …)` je Entry neu auf
(`:57`) — dadurch werden auch Stale-Übergänge innerhalb der Timeline richtig
abgebildet. Policy `.after(last.date)` (`:66`), mit sinnvollem Fallback
`.after(now + 1 h)` bei leerer Liste (`:61-64`). `placeholder` liefert
`sampleEntry` (`:35-37`), `getSnapshot` respektiert `context.isPreview`
(`:39-41`). `Calendar.autoupdatingCurrent` kommt nur in dieser Datei vor
(`:49`, `:87`) — in `Views/` kein einziges `Calendar`, `Date()`, `Timer`,
`URLSession` oder `FileManager` (verifiziert per Grep). **`appGroupURL()` nil**:
`:74-78` fällt auf `NSTemporaryDirectory()` zurück, dort liegt nie eine Datei,
`load()` liefert `.missing` → `.unavailable(.missing)` → „Öffne ShipTrip zum
Aktualisieren". Kein Crash, kein Force-Unwrap.

**3. Countdown-/Abstands-Wortlaut** — deckungsgleich mit
`cruiseStartDescription` (`Date+Extensions.swift:58ff`): identische Schwellen
`..<0 / 0 / 1 / 2...7 / 8...14 / 15...30 / default` und identische
`>= 14`- bzw. `>= 60`-Verzweigungen (`WidgetFormatting.swift:95-116`).
Plural-Handling erfolgt **nicht** über Katalog-Varianten `one/other`, sondern
über getrennte Keys plus Swift-Verzweigung — genau wie in der App. Das ist für
alle erreichbaren Werte korrekt: `2...7` → immer Plural; `8...13` → `days/7 == 1`
→ Singular-Key; `14` → `2` → Plural; `15...30` → `2…4`; `31...59` →
`days/30 == 1` → „In 1 Monat"; `≥ 60` → `≥ 2` → Plural. In EN dieselbe Zuordnung
(`In %lld month` / `In %lld months`). `lastCruise` (`:126-145`) spiegelt das
1:1. **Keine** rohe Interpolation à la `Text("\(x)")` in `Views/`
(Grep: 0 Treffer für `Text("`); `shortCount` (`:159-161`) formatiert über
`.formatted(.number.grouping(.never))`, also locale-korrekt.
Abgesichert ist das alles nicht → F02.

**4. Katalog** — sauber. `Localizable.xcstrings`: `sourceLanguage: de`,
**32 Katalog-Keys, 32 aus dem Quelltext extrahierte Keys, 0 fehlend, 0
verwaist, 32/32 mit `en`-Localization im Zustand `translated`**. Dass kein Key
eine explizite `de`-Localization trägt, ist bei `sourceLanguage: de` korrekt —
der Key *ist* der deutsche Wortlaut. Zielmitgliedschaft geprüft:
`project.pbxproj:98-105` synchronisiert den Ordner `ShipTripWidget/` ins
Widget-Target, `:71-77` nimmt davon nur `Info.plist` aus — der Katalog ist also
Target-Ressource; `knownRegions` (`:286-290`) führt `de, en, Base`.
`configurationDisplayName`/`description` sind lokalisiert
(`ShipTripWidget.swift:118-119` → `WidgetFormatting.displayName` / `.widgetDescription`,
`:150-153`); die `Text(_:)`-Initialisierung ist hier richtig, weil der String
bereits aufgelöst ist. **W1-F05 erledigt**, kein `Text(verbatim:)` mehr im Ordner.

**5. XXL-Schutz** — nachvollziehbar dokumentiert (Header jeder Familie) und je
Familie umgesetzt: `isTight = typeSize >= .xxLarge`
(`SmallWidgetView.swift:22`, `MediumWidgetView.swift:20`,
`RectangularWidgetView.swift:24`), `lineLimit` wächst dabei (2→3,
`SmallWidgetView.swift:59`, `MediumWidgetView.swift:21`),
`minimumScaleFactor` 0,7 in den Headlines (`WidgetStyle.swift:76`, mit
Begründung `:58-60`), 0,8 in den Captions (`:93`), 0,6 in der schmalen
Rectangular-Headline (`:99`). **Die Zeiten entfallen bei XXL nirgends** —
`SmallWidgetView.swift:61`, `MediumWidgetView.swift:157-159` und
`RectangularWidgetView.swift:67` sind alle unbedingt. Der von der Task-Spec
benannte Blocker-Kandidat tritt damit **nicht** ein. Was entfällt: Reisetitel
(Small, F04), Spaltenüberschriften (Medium, unkritisch — die Symbole und die
Links/Rechts-Anordnung tragen die Bedeutung weiter), Ausblickzeile
(Rectangular, F01), Startdatum im Countdown (Rectangular, F03).
Ob die Kürzungen ausreichen, um „kein abschneidendes …" (ZIEL K2) zu
erreichen, ist statisch nicht entscheidbar — das ist der Screenshot-Beleg in W3.

**6. WidgetKit-Regeln** — eingehalten. `containerBackground(for: .widget)`
liegt einmal zentral in `ShipTripWidgetEntryView.swift:21` und deckt damit
jeden Familien- und jeden Zustandspfad ab; für die Sperrbildschirm-Familien
wird bewusst `Color.clear` gesetzt (`:42-49`), der Kreis bringt sein
`AccessoryWidgetBackground()` selbst mit (`CircularWidgetView.swift:26`). Das
einzige `padding` im ganzen Ordner (`CircularWidgetView.swift:37`) sitzt
**innerhalb** des `ZStack` auf dem Inhalts-`VStack`, nicht außen am
Accessory-Wurzelknoten — regelkonform. `widgetAccentable()` sitzt an der
richtigen Stelle: nur auf der ersten Zeile der Rectangular-Familie
(`RectangularWidgetView.swift:102`), nicht auf dem Sekundärtext. Keine Timer,
keine `Date()`-Aufrufe, keine Datei- oder Netzzugriffe in `Views/`
(Grep-verifiziert). Kein Import des App-Moduls; `import UIKit` in
`WidgetStyle.swift:12` ist für die `UIColor`-Trait-Closure nötig und in einer
Extension zulässig.

**7. Swift 6** — sauber. **Null** Force-Unwraps, `as!`, `try!` im Diff
(Grep über alle 9 Swift-Dateien). `ShipTripWidgetEntry` ist explizit `Sendable`
(`ShipTripWidget.swift:22`), alle transportierten Werttypen ebenfalls
(`WidgetState.swift:18/42/62/83/95/109`). `WidgetFormatting` und `WidgetStyle`
sind zustandslose `enum`-Namespaces. `guard.py sizes --files <9 geänderte>` →
`sizes: ok (9 geprueft, 0 Soft-Warnungen)`, Exit 0; größte Datei
`WidgetFormatting.swift` mit 198 Zeilen, alle Views ≤ 178 — deutlich unter dem
Soft-Limit 400. `PreviewFixtures.swift` steht vollständig unter `#if DEBUG`
(`:15`–`:191`), fällt also nicht in den Release-Build.

**8. W1-Backlog** — beide erledigt. **F04** (`policy: .never`, ein Eintrag):
behoben, `ShipTripWidget.swift:52-66` nutzt jetzt `entryDates` und
`.after(last.date)`. **F05** (Gallery-Texte hart deutsch, Katalog leer):
behoben, s. Prüffrage 4. Der dritte offene Widget-Punkt aus W1,
**F06** (`BACKLOG.md:272`, WidgetShared-Dateien brauchen manuelle
`membershipExceptions`), bleibt bestehen — er betrifft die pbxproj, nicht
diesen Diff, und ist weiterhin `minor`.

## Backlog-Kandidaten (für `.planning/BACKLOG.md`)

```
- [major] ShipTripWidget/Views/RectangularWidgetView.swift:68-70 — Widget 1.9.0: ab Dynamic Type XXL entfaellt die Ausblick-Zeile (naechster Stopp / Reiseende); in W3 am Screenshot entscheiden, ob drei Zeilen passen (Quality W2b F01)
- [major] ShipTripWidget/WidgetFormatting.swift:1-198 — Widget 1.9.0: keine Unit-Tests auf WidgetFormatting; Countdown-Tabelle driftet unbemerkt gegen cruiseStartDescription, Datei ins ShipTripTests-Target aufnehmen (Quality W2b F02)
- [major] ShipTripWidget/Views/RectangularWidgetView.swift:41-44 — Widget 1.9.0: Countdown zeigt nie den Reisetitel, ab XXL auch nicht das Startdatum (Quality W2b F03)
- [minor] ShipTripWidget/Views/SmallWidgetView.swift:51-52 — Widget 1.9.0: Reisetitel entfaellt ab XXL, im Zweig "Reise ohne Route" ist er laut ZIEL K1 Pflicht (Quality W2b F04)
- [minor] ShipTripWidget/Views/RectangularWidgetView.swift:47-51 — Widget 1.9.0: Leerlauf ohne Historie stapelt zwei widerspruechliche Leer-Aussagen, Small/Medium zeigen nur eine (Quality W2b F05)
- [minor] ShipTripWidget/WidgetFormatting.swift:33 — Widget 1.9.0: dateRange und stopDetailCompact teilen den Identitaets-Key "%@ – %@" (Quality W2b F06)
- [minor] ShipTrip/WidgetShared/WidgetTimelinePlanner.swift:33-34 — Widget 1.9.0: Leerlauf/unavailable liefern Horizont < 24 h, minimumHorizon wird nur im Test benutzt (Quality W2b F07)
- [minor] ShipTripWidget/Views/WidgetStyle.swift:19-34 — Widget 1.9.0: Journal-Farben dupliziert ohne Rueckverweis in Color+Theme.swift (Quality W2b F08)
- [minor] ShipTripWidget/PreviewFixtures.swift:8-12 — Widget 1.9.0: Header verspricht XXL-Sichtbarkeit, WidgetKit-Previews koennen dynamicTypeSize nicht setzen (Quality W2b F09)
- [minor] ShipTripWidget/WidgetFormatting.swift:49-57 — Widget 1.9.0: shortStopName-Trennzeichenliste ungetestet, country-Feld ungenutzt (Quality W2b F10)
```

## Verdict

**approve — Go für W2b, 0 Blocker.**

Der Diff erfüllt die Original-Anfrage in allen vier Zuständen und allen vier
Familien bei Standard-Schriftgrad, hält ZIEL K1 und die Swift-6-Standards ein
und schließt beide W1-Backlog-Punkte. Alle zehn Findings sind Nicht-Blocker und
gehen ins Backlog.

**Vorbehalt, der nicht in der Verdict-Zeile verschwinden darf:** Dies ist ein
rein statisches Review ohne Build und ohne Testlauf (Auftragslage: Build-Token
bei W2a). Es gibt kein `gate-run.json` zu diesem Review. Der Release-Go nach
ZIEL K2 — grüner Build beider Targets plus 12 Screenshots je Familie × Zustand
in DE/Light, je ein EN- und ein Dark-Beleg, „kein abschneidendes …" bei
Dynamic Type L **und** XXL — steht aus und ist Sache von W3. F01, F03, F04 und
F09 sind genau die Punkte, die dieser Durchgang entscheiden muss.
