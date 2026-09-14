# Review — T8c: Eintrags-Detailansicht + Eintrag-Editor (Journal 1.8.5)

- **Iteration**: 1 / 3
- **Reviewer**: quality-agent (statische Tiefenprüfung, kein Build/Test-Lauf — Token nicht bei mir)
- **Datum**: 2026-08-27
- **Prüf-Diff**: `git diff 2f1186a..8f1df20` (Worktree `ShipTrip-worktrees/merge`, release/1.8.5)
- **Soll**: `docs/architecture/contracts/journal-editor-contract.md` (J1/J2/J2a/J3neu/J4), ADR-003
- **Geladene Skills**: code-review, swift-standards, swiftui, swiftdata, xctest-ios
- **Verdikt**: **GO-mit-Backlog**
- **Stats**: critical 0, major 2, minor 3 — Blocker-Empfehlung: 0 für das T8c-Gate, 1 vor Go-Live 1.8.5

## Evidenz

- Verifizierende Test-Runde (fremder Spawn): `/Users/andre-studio/Documents/0.Projekte/ShipTrip-worktrees/t8c-detail-editor/.winston-evidence/20260827T130104Z/gate-run.json` — commit 4b5bbc3, build=0, tests=0, 24/24 aus xcresult. Kein eigener Lauf (Ein-Runden-Regel).
- Statischer Pass: `guard.py sizes --files <10 neue Dateien>` → `sizes: ok (10 geprueft, 0 Soft-Warnungen)`, exit 0. Größte Datei `JournalEntryEditorView.swift` = 376 Zeilen, unter 400-soft.

## Was der Contract verlangt und was da ist (Soll-Ist, verdichtet)

| Contract | Ist | OK |
|---|---|---|
| J2 Reihenfolge „Erinnerung zuerst" | `memorySection` (Text → Fotos+Caption → Picker) vor `factsSection` (Tag → Hafen → Stimmung), ein Scroll-Flow (`Form`) — Editor:97-100, :123-150, :198-220 | ja |
| J2 Pflichtregel | `canSave = !trimmedText.isEmpty \|\| !pendingPhotos.isEmpty \|\| !attachedPhotos.isEmpty` — Editor:242-244; Footer-Text „Schreib etwas oder wähl mindestens ein Foto." Editor:147 (Wortlaut exakt) | ja |
| J2 Caption je Foto, Default `""` | `photoRow` TextField, `captionDrafts`-Puffer, kein Zwischenspeichern — Editor:169-194, :257-262 | ja |
| J2 Datums-Default + Klemmen als Tag-Tripel | `JournalEditorDefaults.localDay/clamped` über `RouteDayKey` — Defaults:22-57 | ja |
| J2 Hafen-Default = erster Stopp des Tages nach `sortOrder` | `JournalEditorDefaults.portID` mit `min(by:)` auf sortOrder + deterministischem Tiebreak — Defaults:99-117 | ja |
| J2 Save-Semantik: ein Insert, ein `now`, Abbrechen verwirft | `save()` mit einem `now`, alle Mutationen erst dort; `PendingPhoto` existiert nur im `@State` — Editor:301-312, :369-375 | ja |
| J2a: nur echte Änderungen bumpen | `applyFieldChanges` vergleicht vorher (Text, Tag-Tripel via `RouteDayKey.entryDay` vs `.localDay`, moodRaw) — Editor:327-333; `applyPortChange` guard auf `port?.id` — :335-339 | ja |
| J2a Anlegen: `updatedAt == createdAt` | `JournalEntry(…, now:)` + alle Folge-Bumps mit demselben `now` — Editor:316-323 | ja |
| J2a Foto anhängen/abhängen/Caption | `target.attach/detach`, `photo.setCaption` (Model-API aus T7, Bumps dort) — Editor:341-367 | ja |
| J3neu (c): Detail zeigt vollen Text, Stimmung, Reisetag + Datum, Hafen, alle Fotos mit Caption | Detail:60-147, `dayHeadline` :161-169 | ja |
| J3neu (c)/(d): Bearbeiten + Löschen **nur** in der Detailansicht | einziger Editor-Einstieg per `.sheet` Detail:90-94, einziger Delete Detail:149-155/180-186 | ja |
| J4 Rohwerte + Unknown-Preservation | `JournalMood` ohne Platzhalter-Case; Picker arbeitet auf `moodRaw`, unbekannter Wert bleibt unangetastet bis zum aktiven Tipp — Mood:19-62, MoodPicker:19-49 | ja |
| Zeitzonen-Vertrag (Anzeige) | `dayText` fest `.gmt`, `tripDayNumber` über Tag-Tripel-Anker — DayDisplay:28-64 | ja |

### Delete-Audit (grep-belegt)

Im T8c-Diff gibt es **keinen** direkten `modelContext.delete` auf ein Journal-Objekt. Der einzige Löschpfad ist `JournalEntryDetailView.swift:183` → `JournalDeletePaths.deleteEntry(entry, in: modelContext, at: now)`; der Pfad hängt die Fotos via `detachAllPhotosForDeletion` ab und bumpt jedes einzelne (J2a letzte Nullify-Zeile). Foto-Entfernen im Editor ist **kein** Löschen, sondern `target.detach(photo, at: now)` (Editor:346-348) — das Foto bleibt Kind der Reise, exakt wie J1 („Fotos bleiben in der Reise-Galerie") es verlangt. Caption-Änderung geht über `photo.setCaption` (Editor:350-352), bumpt nur das Foto. **Sauber.**

`cruise.updatedAt = now` (Editor:310, Detail:184) ist über J2a hinaus, entspricht aber dem Bestandsmuster (`ExpenseFormView.swift:132`, `PortFormView.swift:286`, `CruiseDetailView.swift:424/430`) — konsistent, kein Finding.

### SwiftData / Swift 6

Kein `@Model` über eine Aktorgrenze: `save()`/`delete()` laufen im MainActor-Kontext der View, der `Task` in `loadPickedPhotos` (Editor:288-297) erbt den MainActor und reicht nur `Data` durch. `@Query` mit `#Predicate` auf der stabilen `id` (Detail:33-40) ist der richtige Weg, ein Navigations-Ziel `Hashable` zu halten, statt ein `@Model`-Objekt zu pushen. Fotos folgen dem Bestands-Idiom (`.externalStorage` über `Photo`, Thumbnail synchron wie `CruiseFormView`). Kein `isDemo`-Verstoß: `JournalEntry` trägt bewusst kein `isDemo` (J1), Filterung läuft über `cruise?.isDemo` in den Export-/Kalender-Pfaden — T8c fügt keinen Pfad hinzu, der das umgehen könnte.

### Gate-r3-Checkliste (statisch)

Systemmaterial/-flächen (`Form`, `List`, `Color(.tertiarySystemFill)`) ✓ · Clipping über `RoundedRectangle(cornerRadius: DesignRadius.sm)` an beiden Bild-Stellen ✓ · eine Flächenfamilie (Systemfüllungen; Auswahl-Fläche im Picker ist eine andere Rolle, kein zweiter Look) ✓ · Foto-Aspect `.fit` in Editor (:177) und Detail (:132), Kopf-Beschnitt ausgeschlossen ✓ · Placeholder-Kontrast `.secondary` statt `.tertiary`, im Code begründet (Editor:157-160) ✓ · Icon-Tint → siehe F04.

## Findings

| ID | Severity | Blocker (Empfehlung) | Datei:Zeile | Kategorie | Titel |
|---|---|---|---|---|---|
| F01 | major | nein fürs T8c-Gate, **ja vor Go-Live 1.8.5** | ShipTrip/Localizable.xcstrings (fehlend) | l10n | 24 neue `String(localized:)`-Stellen ohne Katalog-Eintrag → EN-Nutzer sehen Deutsch |
| F02 | major | nein → Backlog | ShipTrip/Views/Cruises/JournalEntryEditorView.swift:301-367 | tests | Die J2a-Orchestrierung in `save()` ist als private View-Methode nicht testbar und untestet |
| F03 | minor | nein → Backlog | ShipTrip/Views/Cruises/JournalEntryEditorView.swift:74, :278-284 | ux/contract | Prefill-Hafen wird beim Datumswechsel überschrieben (literal J2-konform, überraschend bei J3neu-(d)-Einstieg) |
| F04 | minor | nein → Backlog | ShipTrip/Views/Cruises/JournalEntryEditorView.swift:187 | design | Hartes `.red` statt semantischer Rolle/Theme-Farbe am Entfernen-Icon |
| F05 | minor | nein → Backlog | ShipTrip/Views/Cruises/JournalEntryDetailView.swift:90-94 | robustheit | `.sheet` ohne `else`-Zweig: bei `entry.cruise == nil` erschiene ein leeres Sheet |

### F01 — Neue user-sichtbare Strings fehlen im String-Katalog
- **Datei**: `ShipTrip/Localizable.xcstrings` (unverändert im Diff), Aufrufer in `JournalEntryDetailView.swift:49,54,65,103,145,153,168`, `JournalEntryEditorView.swift:141,144,147,159,166,183,192,199,201,211`, `JournalMood.swift:42-46,61`, `JournalMoodPicker.swift:26`
- **Severity**: major · **Kategorie**: Contract → J3neu „Pflicht-Randbedingungen (T8): Lokalisierung DE/EN … über den String-Katalog"
- **Problem**: 24 Aufrufstellen (18 distinkte Keys) haben keinen Eintrag in `Localizable.xcstrings`. Der Katalog hat 407 von 415 Keys mit `en`-Übersetzung — die Projekt-Konvention ist also lückenlose EN-Abdeckung. `String(localized:)` allein liefert keine Übersetzung: ein englischsprachiges Gerät zeigt „Eckdaten", „Woran willst du dich erinnern?", „Großartig". Xcodes Auto-Extraktion legt beim Build höchstens den Key mit State `new` an, nie eine EN-Übersetzung.
- **Fix**: Build laufen lassen (extrahiert die Keys), dann die 18 Keys mit EN-Werten füllen und den Katalog committen. Sinnvollerweise gebündelt in T8d/Knowledge, sobald T8b und T8c zusammenliegen — ein zweiter Katalog-Durchgang wäre sonst unvermeidlich.

### F02 — J2a-Orchestrierung im Editor ist untestet
- **Datei**: `ShipTrip/Views/Cruises/JournalEntryEditorView.swift:301-367`
- **Severity**: major · **Kategorie**: tests
- **Problem**: Die 24 neuen Tests decken die extrahierte reine Logik vorbildlich ab (`JournalEditorDefaults` 13, `JournalEntryDayDisplay` 6, `JournalMood` 5). Nicht abgedeckt ist die eigentlich riskante Stelle: **welche** Mutation `save()` bei welchem Zustandsunterschied auslöst — die „nur bei echter Änderung bumpen"-Vergleiche (`:328`, `:329-331`, `:332`, `:337`), die Detach-vor-Caption-Reihenfolge (`:346-352`) und die `sortOrder`-Fortschreibung (`:355-366`). Der Contract weist die J2a-Zeilen den T7-Tests zu, die decken aber die Model-API ab, nicht die Auswahl des Aufrufs durch den Editor. Ein vertauschter Vergleich (z. B. `RouteDayKey.localDay` auf beiden Seiten in `:329`) bliebe grün.
- **Fix**: `applyFieldChanges`/`applyPortChange`/`applyPhotoChanges` als reine Diff-Berechnung in ein `JournalEditorSavePlan`-Struct ziehen (Eingabe: Ist-Werte + Formularzustand, Ausgabe: Liste der auszuführenden Mutationen) und diese Liste testen; die View führt den Plan nur noch aus. Alternativ bewusst als Backlog akzeptieren, da die Model-Bumps selbst T7-getestet sind.

### F03 — Prefill-Hafen zählt nicht als manuelle Wahl
- **Datei**: `ShipTrip/Views/Cruises/JournalEntryEditorView.swift:74` (`didChoosePortManually = false` trotz `prefill.portID`), Wirkung in `:278-284`
- **Severity**: minor · **Kategorie**: contract/ux
- **Bewertung (angeforderte Auslegung)**: **Contract-konform.** J2 Schritt 2 sagt wörtlich „Bei Datumswechsel neu berechnet, solange der User nicht manuell gewählt hat" — eine Vorbelegung ist per Definition keine Wahl des Users. Die Gegenrichtung beim Bearbeiten (`:89` `didChoosePortManually = true`) ist ebenfalls richtig und wird von J3neu (a) Regel 1 gedeckt: „Der Hafen-Bezug hat Vorrang vor dem Datum (auch wenn der User den Eintrag später umdatiert hat)". Ein gespeicherter Bezug ist eine Tatsache, ein Default nicht — die Asymmetrie ist die korrekte Lesart, nicht ein Versehen.
- **Restrisiko**: Beim J3neu-(d)-Einstieg an einem aufgeklappten Stopp ist der vorbelegte Hafen für den User ununterscheidbar von einer eigenen Wahl. Ändert er dort den Tag, wechselt der Hafen still auf den Stopp des neuen Tages (oder auf „Kein Hafen"). Der Contract erlaubt das, aber es widerspricht der Absicht des Einstiegs.
- **Fix (optional, Backlog)**: `JournalEntryPrefill.stop(…)` als manuelle Wahl behandeln (`didChoosePortManually = prefill.portID != nil`), `.noStop` unverändert. Ein-Zeilen-Änderung, entscheidet Winston/Andre — das ist eine Produktfrage, keine Defekt-Frage.

### F04 — Hartes `.red` am Entfernen-Icon
- **Datei**: `ShipTrip/Views/Cruises/JournalEntryEditorView.swift:185-188`
- **Severity**: minor · **Kategorie**: design/Icon-Tint
- **Problem**: `Button(role: .destructive)` trägt die destruktive Rolle bereits; das zusätzliche `.foregroundStyle(.red)` setzt eine literale Farbe statt der semantischen Rolle bzw. des Projekt-Themes (`Utilities/Color+Theme`). In Dark Mode und bei erhöhtem Kontrast weicht literales `.red` von der Systemrolle ab.
- **Fix**: `.foregroundStyle(.red)` streichen (die `.destructive`-Rolle tönt bei `.buttonStyle(.plain)` nicht automatisch — dann stattdessen die im Projekt etablierte Destruktiv-Farbe aus `Color+Theme` verwenden).

### F05 — Leeres Sheet bei verwaistem Eintrag
- **Datei**: `ShipTrip/Views/Cruises/JournalEntryDetailView.swift:90-94`
- **Severity**: minor · **Kategorie**: robustheit
- **Problem**: `if let cruise = entry.cruise` ohne `else` — träfe `nil`, präsentierte SwiftUI ein leeres Sheet ohne Ausweg außer Wischen. Aktuell unerreichbar, weil der Bearbeiten-Button `:87` genau darauf `.disabled` ist; die Absicherung hängt damit an zwei Stellen, die auseinanderlaufen können.
- **Fix**: `else { ContentUnavailableView(…) }` ergänzen oder — sauberer — auf `.sheet(item:)` mit dem `Cruise` als Item umstellen, dann kann der Zustand gar nicht erst entstehen.

## Beobachtung außerhalb des T8c-Diffs (kein T8c-Finding, für T8d)

`JournalDeletePaths.deletePort` und `JournalDeletePaths.deletePhoto` haben im gesamten `ShipTrip/`-Baum **keinen** Aufrufer. Die bestehenden Löschstellen gehen weiter direkt über den Kontext:

- `ShipTrip/Views/Cruises/CruiseDetailView.swift:422` — `modelContext.delete(port)`
- `ShipTrip/Views/Cruises/CruiseFormView.swift:69`, `:85` — `modelContext.delete(port)`
- `ShipTrip/Views/Cruises/CruiseFormView.swift:788` — `modelContext.delete(photo)`

Damit laufen zwei Zeilen der Matrix J2a **nicht**: „Foto aus Galerie löschen (hing an Eintrag) → `entry.updatedAt` bump, explizit im Lösch-Pfad" und „Hafen löschen → Nullify `entry.port` → `entry.updatedAt` bump, explizit im Lösch-Pfad". Folge beim CloudKit-Merge: SwiftData nullifiziert die Beziehung, aber ohne Bump gewinnt beim LWW ein älterer Stand des Eintrags und stellt den toten Bezug wieder her.

Alle vier Stellen sind bei `2f1186a` unverändert vorhanden (`git show 2f1186a:…` geprüft) — T8c hat sie weder verursacht noch berührt, und das Verdrahten war T8c nicht beauftragt. **Empfehlung an Winston: als eigenen T8d-Punkt aufnehmen und vor dem 1.8.5-Go-Live schließen.** Es ist die einzige mir bekannte offene J2a-Lücke.

## Verdikt

**GO-mit-Backlog** für T8c. Keine critical-Findings, kein Contract-Verstoß in der beauftragten Fläche, Lösch-Pfade sauber, J2/J2a/J3neu Feld für Feld getroffen, Dateigrößen im Rahmen, Tests der extrahierten Logik dicht und aussagekräftig. F01 (Lokalisierung) ist kein T8c-Gate-Blocker, muss aber vor dem Go-Live von 1.8.5 geschlossen sein; F02–F05 gehören ins Backlog.
