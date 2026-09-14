# Review — T8b Stopp-Karten-UI (Route-Journal-Faden, J3neu)

- **Iteration**: 1 / 3
- **Reviewer**: quality-agent (statischer Pass, keine eigene Test-Runde)
- **Datum**: 2026-08-27
- **Prüf-Diff**: `git diff d438233..2f1186a` (Worktree `ShipTrip-worktrees/merge`, release/1.8.5)
- **Geladene Skills**: code-review, swift-standards, swiftui
- **Verdict**: **GO-mit-Backlog** (approve; keine offenen Blocker innerhalb T8b)
- **Stats**: critical 0, major 3, minor 5 — Blocker-Empfehlung: 0 für T8b, 2 für das 1.8.5-Release-Gate

## Evidenz-Basis

Verifizierende Test-Runde lag bereits vor (frischer Test-Build-Spawn), **kein Doppel-Lauf**:
`/Users/andre-studio/Documents/0.Projekte/ShipTrip-worktrees/t8b-stoppkarten/.winston-evidence/20260827T125425Z/gate-run.json`
— `status: verified`, commit `7da881f`, `build` exit 0, `tests` exit 0, Xcode 26.6, 55/55.
Artefakt valide (schema_version 1, beide Kommandos mit Log + sha256), keine Weichspüler-Kommandos.

Statischer Pass zusätzlich gefahren:
`guard.py sizes --files <6 neue Dateien>` → `ok (6 geprueft, 0 Soft-Warnungen)`, exit 0.
Größte neue Datei: `RouteJournalSection.swift` 240 Zeilen. `CruiseDetailView.swift` 615 Zeilen
ist **bekannter Vorbestand** (Backlog) und wird hier nicht erneut gemeldet — der Diff senkt sie
netto um 70 Zeilen.

GDPR-Check: **nicht ausgelöst** — reine Anzeige-Schicht, keine neue Datenverarbeitung, kein
Export/Netz/Log-Pfad berührt. Security-Check: **nicht ausgelöst** — keine neue Angriffsfläche
(keine Eingabe-Verarbeitung, keine Persistenz-Mutation, keine externen Aufrufe).

## J3neu — Darstellungsregeln Regel für Regel

| Regel (Contract) | Fundstelle | Status |
|---|---|---|
| (b) Effektiver Zustand = Übersteuerung ?? Automatik-Default | `RouteJournalSection.swift:123` → `RouteCollapseState.isExpanded` | erfüllt |
| (b) Klapp-Zustand nur In-Memory, kein Schema-Eingriff | `RouteJournalSection.swift:34` (`@State`) | erfüllt |
| (b) Reset bei `NSCalendarDayChanged` **und** Szenen-Reaktivierung | `:67-70`, `:173-187` — beide Pfade auf `refreshIfDayChanged()`, das `todayAnchor` neu setzt **und** `collapseState.resetForDayChange()` ruft | erfüllt |
| (b) Aktiv-Tag ohne Stopp → alles zu | Delegiert an `RouteCollapseDefaults.make` (T8a, `:73-78`); View erzeugt keinen Ersatz-Default | erfüllt |
| (b) Sammelblock ohne Klapp-Kopf, immer offen | `RouteExtraEntriesBlock.swift:24-51` — kein Toggle, keine Stopp-ID; `RouteJournalSection.swift:56-62` außerhalb der Stopp-`ForEach` | erfüllt |
| (b) Header-Kontrolle „Alle auf-/zuklappen", jederzeit | `RouteJournalSection.swift:80-92`, `:158-168` | erfüllt |
| (b) Zugeklappt = nur kompakte Zeile, keine `PortMemoryCard`, keine Journal-Zeilen | `RouteStopCard.swift:44-65` (alles hinter `if isExpanded`) | erfüllt |
| (b) Trefferflächen getrennt: Kopf klappt, Karteninhalt navigiert | `RouteStopCard.swift:84-115` (Button = Kopf) vs. `:45-51` (`PortMemoryCard` + `onTapGesture`) | erfüllt — mit Erreichbarkeitslücke, s. F03 |
| (c) Datum nur bei Abweichung vom `arrival`-Tag / im Sammelblock | `RouteJournalEntryRow.swift:130-136`, `RouteExtraEntriesBlock.swift:47` (`showsDate: true`) | erfüllt |
| (c) `lineLimit(3)` + „Weiterlesen" nach `JournalExcerpt` | `RouteJournalEntryRow.swift:53`, `:58-67` | erfüllt |
| (c) Stimmungs-Emoji nur bei bekanntem Rohwert (Unknown-Preservation) | `RouteJournalMood.swift:48-50`, `RouteJournalEntryRow.swift:91-93` | erfüllt |
| (d) Stopp-Aktion „Tagebuch-Eintrag" nur aufgeklappt | `RouteStopCard.swift:64`, `:123-134` | erfüllt (Wiring offen, F02) |
| (d) Sammelblock-Plus mit J2-Defaults | `RouteJournalSection.swift:60` (`onAddEntry(nil)`) | erfüllt |
| (e) Stopp ohne Einträge = kein leerer Abschnitt | `RouteStopCard.swift:53-62` (leerer `ForEach` rendert nichts) | erfüllt |
| (e) Route leer → Leerzustand bleibt, Einträge im Sammelblock | `RouteJournalSection.swift:44-62` | erfüllt |
| ForEach im ScrollView, `Port.id` als Key | `RouteJournalSection.swift:47` (`id: \.id`); `CruiseDetailView.swift:37,49` | erfüllt |
| **F04-Auflage: jeder Datumsvergleich über `RouteDayKey`** | Grep über alle 5 neuen View-Dateien: **kein** eigener `Calendar`-Vergleich, kein `startOfDay`, kein `Date ==`. Einziges `Calendar` ist der injizierbare Default-Parameter in `RouteJournalEntryRow.swift:133`, der unverändert an `RouteDayKey.localDay` durchgereicht wird. `dayText` formatiert `entryDate` in `.gmt` (`:141-145`) | erfüllt |

## Bewertung der Dev-Entscheidungen

**`onAddEntry: (Port?) -> Void`, `nil` = Sammelblock/J2-Defaults — trägt.**
Minimale Signatur, die beide Einstiegspunkte aus (d) abbildet, ohne einen Vorbelegungs-Typ zu
erfinden, den T8c ohnehin definiert. Semantik am Deklarationsort dokumentiert
(`RouteJournalSection.swift:27-29`). Naht-Risiko für T8d: der Vorbelegungs-**Tag**
(`arrival`-Tag-Tripel als 12:00 UTC, J3neu (d)) steckt implizit im übergebenen `Port` — T8c muss
ihn über `RouteDayKey`/`JournalDay` ableiten und nicht aus `port.arrival` roh übernehmen.
Beim Wiring explizit prüfen (F08).

**„Bearbeiten" zusätzlich im Kontextmenü — trägt nur halb.**
Die Auflage ist korrekt erkannt (zugeklappter Stopp und Seetag ohne Momente haben keinen
Karteninhalt, der navigieren könnte), aber ein Long-Press-Kontextmenü ist kein entdeckbarer
Ersatz für den bisherigen Ein-Tap-Pfad. Siehe F03.

## Gate-r3-Abnahme (statisch, ohne Screenshot)

| Kriterium | Befund |
|---|---|
| Systemmaterial unter Nav/Tab | N/A — T8b fasst den `ScrollView`-Rahmen und die Nav-Konfiguration von `CruiseDetailView` nicht an |
| Kein Clipping | Kopfzeile `minHeight: 44` ohne `lineLimit` → bricht statt zu schneiden (`RouteStopCard.swift:112`); Foto-Vorschau `contentMode: .fit` in fester 56-pt-Box (`RouteJournalEntryRow.swift:101-109`); Text mit `fixedSize(horizontal: false, vertical: true)` (`:55`) |
| EINE Flächenfamilie | Section `secondarySystemBackground` + `DesignRadius.sm` (unverändert aus IST); Eintragszeile `tertiarySystemBackground` + `DesignRadius.sm` — **identisch** zum Karten-Idiom von `PortMemoryCard.swift:29-30`. Keine neue Fläche eingeführt |
| Ein Icon-Tint | Aktions-Icons durchgängig `Color.accentColor` (`RouteJournalSection.swift:87,97`, `RouteExtraEntriesBlock.swift:37`, `RouteStopCard.swift:132`), Zustands-Chevron `.secondary` (`RouteStopCard.swift:110`) — deckungsgleich mit dem IST-Abschnitt |
| Foto-Aspect | `.fit`, kein `.fill`/`clipped` → kein abgeschnittener Kopf; bewusst kommentiert (`RouteJournalEntryRow.swift:24-27`) |
| Placeholder-Kontrast | `quaternarySystemFill` hinter der `.fit`-Vorschau (`:108`) — sichtbar in Light und Dark |
| `String(localized:)` mit deutschen Wortlaut-Keys | Im **Code** erfüllt (alle A11y-Strings explizit, alle sichtbaren Literale als `LocalizedStringKey`). Im **Katalog** nicht — F01 |

## SwiftData-/Swift-6-Hygiene

- `@Model` erreicht **keinen** T8a-Planer-Typ. Mapping am Rand:
  `RouteJournalSection.swift:196-200` (`Port` → `RouteStopInput`) und `:222-232`
  (`JournalEntry` → `JournalEntryInput`). Die Planer sehen nur Wert-Structs.
- `RouteJournalMood` ist ein `Sendable`-`enum` ohne Modellbezug; `RouteStopCard`/
  `RouteJournalEntryRow` halten `@Model`-Referenzen ausschließlich als View-Properties
  (MainActor-Kontext) — keine Aktorgrenzen-Verletzung, keine `@Model`-Objekte über
  `Sendable`-Grenzen.
- Tageswechsel-Notification bewusst über `.receive(on: RunLoop.main)` auf den Main-Thread
  gehoben, bevor `@State` mutiert wird (`:180-187`) — richtiger Reflex (Einschränkung: F06).
- Keine Force-Unwraps, keine `try!`, keine Suppressions im Diff.

## Findings

| ID | Severity | Blocker (Empfehlung) | Datei:Zeile | Kategorie | Titel |
|---|---|---|---|---|---|
| F01 | major | nein für T8b · **ja fürs Release-Gate** | `ShipTrip/Localizable.xcstrings` | l10n | 13 neue Strings fehlen im String-Katalog → kein EN |
| F02 | major | nein für T8b · **ja fürs Release-Gate** | `CruiseDetailView.swift:312-313` | correctness | Journal-Aktionen sind No-Ops (T8d-Wiring offen) |
| F03 | major | nein | `RouteStopCard.swift:44-51,68-79` | ux | Hafen-Formular bei zugeklapptem Stopp/Seetag nur per Long-Press |
| F04 | minor | nein | `RouteJournalSection.swift:111-131,144-149,191-208` | performance | `sortedPorts`/`collapseDefaults` mehrfach pro `body` neu berechnet |
| F05 | minor | nein | `RouteJournalEntryRow.swift:118` | l10n | `"\(count) Fotos"` ohne Plural-Variante → „1 Fotos" |
| F06 | minor | nein | `RouteJournalSection.swift:182-187` | correctness | `RunLoop.main` verzögert den Tageswechsel während Scrollen |
| F07 | minor | nein | `RouteJournalSection.swift:144-168` | tests | `isEverythingExpanded`/`toggleAll` als einzige neue Nicht-View-Logik ungetestet |
| F08 | minor | nein | `RouteJournalSection.swift:27-29` | naht | Vorbelegungs-Tag der Stopp-Erfassung nur implizit im `Port` |

### F01 — 13 neue user-sichtbare Strings fehlen im String-Katalog
- **Datei**: `ShipTrip/Localizable.xcstrings` (Quellen: `RouteJournalSection.swift:90,91,99,104`;
  `RouteStopCard.swift:50,72,77,117,118,127,133`; `RouteExtraEntriesBlock.swift:29,39`;
  `RouteJournalMood.swift:38-42`; `RouteJournalEntryRow.swift:62,118`)
- **Severity**: major · **Blocker**: nein für T8b, ja für das 1.8.5-Release-Gate
- **Kategorie**: l10n / Contract-Pflicht-Randbedingung
- **Problem**: Der Katalog (415 Keys, `sourceLanguage: de`) enthält **keinen** der neuen Keys:
  `Weiterlesen`, `Weitere Einträge`, `Tagebuch-Eintrag`, `Tagebuch-Eintrag hinzufügen`,
  `aufgeklappt`, `zugeklappt`, `Alle aufklappen`, `Alle zuklappen`, `Großartig`, `Gut`, `Okay`,
  `Nicht so gut`, `Schlecht`, `%lld Fotos`. Wiederverwendete Keys (`Route`, `Bearbeiten`,
  `Löschen`, `Hafen hinzufügen`, `Hafen bearbeiten`) sind vorhanden und `translated`.
  J3neu „Pflicht-Randbedingungen (T8)" verlangt DE/EN über den String-Katalog; ohne EN-Unit
  fällt die englische App auf die deutschen Wortlaut-Keys zurück — sichtbar u. a. als
  Stimmungs-Labels in VoiceOver. Der Katalog ist im Worktree unverändert (`git status` sauber),
  die Extraktion wurde also nicht nachgezogen.
- **Fix**: Xcode-Extraktion laufen lassen bzw. die 14 Keys manuell ergänzen und die
  `en`-`stringUnit`s auf `translated` setzen. Sinnvoll gebündelt mit den T8c-Strings am Ende
  der Welle (T8d), nicht als Einzel-Commit hier.

### F02 — Journal-Aktionen sind derzeit No-Ops
- **Datei**: `CruiseDetailView.swift:312-313`
- **Severity**: major · **Blocker**: nein für T8b, ja für das Release-Gate
- **Kategorie**: correctness / Wiring
- **Problem**: `onOpenEntry: { _ in }` und `onAddEntry: { _ in }` sind bewusst leer (Kommentar
  `:310-311` verweist auf T8d). Damit reagieren im aktuellen Merge-Stand drei sichtbare
  Affordances nicht: der „Tagebuch-Eintrag"-Button jedes aufgeklappten Stopps
  (`RouteStopCard.swift:123`), der Plus-Button des Sammelblocks
  (`RouteExtraEntriesBlock.swift:33`) sowie Zeilen-Tap und „Weiterlesen"
  (`RouteJournalEntryRow.swift:59,81,86`). Innerhalb der Welle ist das die korrekte
  Reihenfolge (T8b baut die Lesansicht, T8c den Editor) — es darf nur nicht so releast werden.
- **Fix**: Kein Fix in T8b. T8d-Abnahme muss explizit prüfen, dass alle vier Aufrufstellen
  verdrahtet sind; solange T8c nicht gemergt ist, ist der Stand nicht release-fähig.

### F03 — Hafen-Formular bei zugeklapptem Stopp und Seetagen nur per Long-Press erreichbar
- **Datei**: `RouteStopCard.swift:44-51` (Navigation nur am `PortMemoryCard`-Inhalt),
  `:68-79` (Kontextmenü)
- **Severity**: major · **Blocker**: nein (ein Pfad existiert)
- **Kategorie**: ux / Regression gegenüber IST
- **Problem**: Vor T8b öffnete ein Tap auf die **ganze** Stopp-Zeile das Hafen-Formular
  (`selectedPort`, alter Code `CruiseDetailView.swift:344-347`). Jetzt navigiert nur der
  `PortMemoryCard`-Inhalt — den es bei zugeklapptem Stopp gar nicht gibt und bei Seetagen ohne
  erfasste Momente nie (`PortMemoryCard.shouldRender`). In diesen Fällen bleibt als einziger
  Weg das Long-Press-Kontextmenü: funktional vorhanden, aber nicht entdeckbar; Seetage sind
  damit praktisch nur noch per verstecktem Pfad editierbar. Die Trennung selbst ist von J3neu (b)
  gefordert und richtig umgesetzt — nur die Ersatz-Affordance fehlt.
- **Fix (T8d, eine der Varianten)**: (a) nur das Chevron als Klapp-Trefferfläche, restliche
  Kopfzeile navigiert; oder (b) im aufgeklappten Zustand eine sichtbare Zeile „Hafen bearbeiten"
  neben „Tagebuch-Eintrag"; oder (c) Chevron-Button + Kopfzeilen-Tap = navigieren. Variante (b)
  ist der kleinste Eingriff und kollidiert mit nichts.

### F04 — Mehrfachberechnung in `body`
- **Datei**: `RouteJournalSection.swift:111-131` (`stopCard` liest `firstPortSortOrder`/
  `lastPortSortOrder`, die je `sortedPorts` neu sortieren), `:144-149` + `:84,89`
  (`isEverythingExpanded` ruft `collapseDefaults` zweimal pro `body`, zusätzlich zu `:40`)
- **Severity**: minor · **Blocker**: nein
- **Problem**: `sortedPorts` sortiert `cruise.route` bei **jedem** Zugriff; über die `ForEach`
  ergibt das O(n² log n) Sortier-Aufwand pro `body`-Durchlauf, dazu 3× `RouteCollapseDefaults.make`.
  Bei realistischen Routen (< 30 Stopps) unkritisch, aber der IST-Code hatte `sortedPorts` und
  die beiden `sortOrder`-Grenzen bewusst einmal als `let` im `body` (`CruiseDetailView.swift:322-324`
  alt) — die Eigenschaft ging beim Extrahieren verloren.
- **Fix**: In `body` (`:39-40`) neben `layout`/`defaults` auch `let ports = sortedPorts` und die
  beiden Grenz-`sortOrder` einmal binden und als Parameter an `stopCard(for:…)` durchreichen;
  `isEverythingExpanded` auf `func isEverythingExpanded(defaults:)` umstellen.

### F05 — Foto-Zähler ohne Plural-Variante
- **Datei**: `RouteJournalEntryRow.swift:118`
- **Severity**: minor · **Blocker**: nein
- **Problem**: `String(localized: "\(sortedPhotos.count) Fotos")` erzeugt den Key `%lld Fotos`
  ohne Plural-Variation; bei genau einem Foto liest VoiceOver „1 Fotos" (EN später „1 Photos").
- **Fix**: Key im Katalog als Plural-Variation anlegen (`one`/`other`), zusammen mit F01.

### F06 — Tageswechsel über `RunLoop.main`
- **Datei**: `RouteJournalSection.swift:182-187`
- **Severity**: minor · **Blocker**: nein
- **Problem**: `.receive(on: RunLoop.main)` stellt nur im Default-Runloop-Mode zu; während aktiven
  Scrollens (Tracking-Mode) wird die Zustellung bis zum Scroll-Ende **verzögert**. Der Wert wird
  nicht verschluckt, und der `scenePhase`-Pfad fängt den praktisch relevanten Fall (App war im
  Hintergrund) ohnehin ab — deshalb minor.
- **Fix**: `.receive(on: DispatchQueue.main)`; Semantik (Main-Thread vor `@State`-Mutation) bleibt.

### F07 — `isEverythingExpanded`/`toggleAll` ungetestet
- **Datei**: `RouteJournalSection.swift:144-168`
- **Severity**: minor · **Blocker**: nein
- **Problem**: Die Testumfangs-Leiter (Feature → Tests für das Neue) ist mit
  `RouteJournalRowPresentationTests` für die extrahierte Anzeige-Logik sauber bedient, und
  `RouteCollapseState` ist in T8a gedeckt. Ungetestet bleibt nur die View-interne Entscheidung
  „alles auf → zuklappen, sonst aufklappen" inkl. der Sonderfall-Ränder (leere Route,
  Mischzustand). Kein Testschuld-Blocker, aber die Logik ist die einzige neue, die nicht in einem
  reinen Typ sitzt.
- **Fix (optional, T8d)**: `isEverythingExpanded` als `static func` mit
  `(stopIDs, state, defaults)`-Signatur herausziehen und mit zwei Fällen testen.

### F08 — Vorbelegungs-Tag der Stopp-Erfassung nur implizit
- **Datei**: `RouteJournalSection.swift:27-29`, `RouteStopCard.swift:34-35`
- **Severity**: minor · **Blocker**: nein
- **Problem**: J3neu (d) verlangt beim Einstieg über einen Stopp Tag = `arrival`-Tag-Tripel des
  Stopps, persistiert als 12:00 UTC. Die Signatur `(Port?) -> Void` transportiert den Stopp,
  den Tag aber nur implizit über `port.arrival` — ein roher `arrival`-Zeitstempel als `entryDate`
  wäre eine Zeitzonen-Vertragsverletzung.
- **Fix**: Keine Änderung in T8b. Beim T8c-Wiring sicherstellen, dass der Editor
  `RouteDayKey.localDay(port.arrival)` bzw. `JournalDay`-Normalisierung verwendet; als
  Prüfpunkt in die T8d-Abnahme aufnehmen.

## Naht-Hygiene für T8d

- `RouteJournalMood` (T8b) ist sauber isoliert: reines `Sendable`-`enum` über `moodRaw`, ohne
  Modell- oder View-Abhängigkeit, mit Unknown-Preservation und Tests. Für die Zusammenführung mit
  einem T8c-Mood-Typ ist es der bessere Kandidat als Ziel-Typ; der Merge ist mechanisch
  (Emoji-/Label-Tabelle + `known(rawValue:)`), keine Semantik-Kollision absehbar.
- Vier Callback-Aufrufstellen für T8c: `CruiseDetailView.swift:312-313` (beide), erreichbar über
  `RouteStopCard.onOpenEntry/onAddEntry` und `RouteExtraEntriesBlock.onOpenEntry/onAddEntry`.
- `CruiseDetailView` ist mit 615 Zeilen weiter über dem Hardlimit — Vorbestand im Backlog; T8d
  sollte beim Einhängen der T8c-Sheets nicht weiter aufbauen.

## Empfehlung

**GO-mit-Backlog.** T8b erfüllt die J3neu-Darstellungsregeln vollständig, hält die F04-Auflage
(alle Datumsvergleiche über `RouteDayKey`) ein, verletzt keine SwiftData-/Aktorgrenze und bleibt
in allen neuen Dateien deutlich unter den Größenlimits. Kein Finding blockiert die Fortsetzung
der Welle. F01 und F02 sind vor dem 1.8.5-Release-Gate zwingend zu schließen (beide sind
T8d-Wiring-Arbeit), F03 gehört als sichtbare Affordance in denselben Schritt.
