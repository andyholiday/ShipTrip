# Review — Architektur-Gate #4, Iteration 2 (Delta): Share-Extension `ShipTripShare`

- **Iteration**: 2 / 3
- **Reviewer**: quality-agent (frischer Spawn, read-only)
- **Datum**: 2026-09-10
- **Prüfgegenstand**: ADR-010 + `share-extension-handoff.md` in der Fassung
  Iteration 2, Worktree
  `/Users/andre-studio/Documents/0.Projekte/ShipTrip-worktrees/widget-1.9.0`,
  Branch `feature/share-extension`
- **Verdikt**: **approve / Go — unter zwei Auflagen (A1, A2), Wortlaut unten**
- **Stats**: critical 0 · major 2 · minor 7 — **Blocker 0**, Auflagen 2, Backlog 7
- **Geladene Skills**: code-review, xctest-ios, owasp-security (nur A03-Blick auf
  den entfallenen `file=`-Pfad), context7-query (nicht benötigt — Apple-Fakten
  über einen Tiefe-1-Zulieferer per WebFetch developer.apple.com)

## Test-Run-Status (ehrlich)

Änderungsklasse des Prüfgegenstands ist **docs**: `docs/adr/ADR-010-…md` (neu),
`docs/architecture/contracts/share-extension-handoff.md` (neu),
`docs/adr/README.md` (eine Indexzeile). Die Testumfangs-Leiter verlangt dafür
keinen Testlauf; es existiert **kein `gate-run.json` und es ist keins
geschuldet**. Niemand behauptet hier „Tests grün".

Gefahren wurde:
- `guard.py sizes --files <3 Dateien>` → `sizes: ok (3 geprueft, 0
  Soft-Warnungen)`, Exit 0.
- Statische Belegprüfung gegen `project.pbxproj`, `ShipTrip-Info.plist`,
  `fastlane/Fastfile`, `docs/SETUP.md`, `build/ExportOptions.plist`,
  `ShipTripApp.swift`, `ShareImportCoordinator.swift`,
  `ShareImportResultSheet.swift`, `NotificationReconciler.swift` (unten).
- Apple-Fakten zu H5 über einen Zulieferer, ausschließlich developer.apple.com.

**Beobachtung zum Ablauf:** Während dieses Laufs sind
`ShipTrip/ShareShared/ShareHandoffStore.swift` und
`ShipTripTests/ShareHandoffStoreTests.swift` im Worktree aufgetaucht (S0), also
vor dem grünen Gate. Ich habe S0 gegen H2 gegengelesen (siehe G09) — es ist
deckungsgleich, kein Nacharbeitsbedarf. Die Reihenfolge war trotzdem Glück:
hätte das Gate H2 geändert, wäre S0 Ausschuss gewesen.

## 1. Blocker F01–F09 aus Iteration 1

| ID | Thema | Geschlossen | Beleg (ein Satz) |
|-----|-------|-------------|------------------|
| F01 | Responder-Chain-`openURL:` | **ja** | H5 (`:227-229`) sagt „Kein Versuch, die App zu öffnen. Weder `extensionContext.open` … noch Responder-Chain"; ADR Alternative E (`:147-152`) führt den Weg als abgelehnt, Ersatz ist die lokale Mitteilung. |
| F02 | Path-Traversal | **ja** | H2 (`:68`) schreibt `isValidHandoffName` als **reine String-Prüfung** fest (Länge exakt 45, Zeichen 1–36 = UUID, 37–45 = `.shiptrip`), die Scan-Regel (`:67`) nimmt nur reguläre Nicht-Symlink-Dateien direkt im Ordner — kein externer Parameter wählt je einen Pfad. |
| F03 | `file=` + `.pendingShareFile` | **ja** | H1 (`:47-52`) ist auf „keine Änderung" reduziert, `IncomingLinkRouter*` werden nicht angefasst; ZIEL #3 ist entsprechend umformuliert („Kein neuer URL-Parameter, kein neuer Router-Fall"). |
| F04 | ZIEL-#4-Test nicht konstruierbar | **ja** | H3 (`:102-105`, `:124-127`) gibt beiden Funktionen den Default-Parameter `inbox:`, die Tests laufen gegen ein Wegwerf-Verzeichnis und sind ausdrücklich „**Vor dem Fix rot**". |
| F05 | `UIBackgroundModes` in der Extension | **ja** | H4 (`:157-172`) nennt `ShipTripWidget/Info.plist` als Vorlage, listet die vier erlaubten Schlüssel abschließend und verbietet `UIBackgroundModes`, `CFBundleDocumentTypes`, `CFBundleURLTypes`, `UTExportedTypeDeclarations` namentlich. |
| F06 | Anzeigename im Teilen-Sheet | **ja** | H6 (`:284`) führt `INFOPLIST_KEY_CFBundleDisplayName = ShipTrip` als **Pflicht**, Schritt V.4 (`:372-373`) prüft den Sheet-Text im Screenshot. |
| F07 | `CODE_SIGN_ENTITLEMENTS` | **ja** | H6 (`:284`) sagt „1:1 aus dem Widget-Target klonen" mit genau drei Abweichungen und listet alle 19 Settings — ich habe die Liste gegen `project.pbxproj:699-754` abgeglichen, sie ist **vollständig und wortgleich**. |
| F08 | pbxproj-Integrationsumfang | **ja** | H6 (`:293-323`) enthält die 15-Objekte-Tabelle mit Widget-Zeilenbelegen; Stichprobe unten: **9 von 15 Belegen geprüft, alle korrekt**. |
| F09 | Verifikationsplan / Owner | **ja** | Schritt V (`:359-386`) mit Owner („Winston delegiert an einen Build/Test-Agenten"), Sheet-Screenshot (ZIEL #1), E2E + `gate-run.json` (ZIEL #7), L10n-Gate, Build-Bump 31 (ZIEL #8), Doku (ZIEL #9) und Gerätetest zuletzt. |

**9 von 9 geschlossen.** Auch die Nicht-Blocker F10, F11, F12, F13, F15, F16,
F17, F18, F20, F21 sind eingearbeitet; F14 entfällt mit F01; F19 steht korrekt
als Backlog im Contract (`:388-393`).

## 2. Stichprobe pbxproj (H6-Objektliste)

Geprüft gegen `ShipTrip.xcodeproj/project.pbxproj` im Worktree — verlangt waren
5, geprüft habe ich 9:

| # | Behauptung | Zeile | Befund |
|---|---|---|---|
| 1 | `PBXBuildFile` „…appex in Embed Foundation Extensions", `ATTRIBUTES = (RemoveHeadersOnCopy, )` | `:10` | **stimmt**, wörtlich |
| 3 | `PBXCopyFilesBuildPhase` „Embed Foundation Extensions", `dstSubfolderSpec = 13` | `:38-48` | **stimmt** |
| 4 | `PBXFileReference` `.appex`, `explicitFileType = "wrapper.app-extension"` | `:55` | **stimmt** |
| 5 | Exception-Set „ShipTrip"-Ordner im Widget-Target (`WidgetShared/*`) | `:59-70` | **stimmt** |
| 6 | Referenz darauf in `exceptions` der Root-Group `ShipTrip` | `:96-103` | **stimmt**, exakt der Block |
| 7 | Exception-Set mit `membershipExceptions = (Info.plist,)` | `:86-92` | **stimmt** |
| 8 | `PBXFileSystemSynchronizedRootGroup` Widget, **nicht** in `children` der Main-Group | `:114-122`, `:157-166` | **stimmt**, Main-Group enthält nur ShipTrip/Tests/UITests/Products |
| 11 | `PBXNativeTarget` Widget, `productType = app-extension` | `:251-272` | **stimmt**, exakt der Block |
| 15 | `XCConfigurationList` + Debug/Release | `:794-802`, `:699-754` | **stimmt**; Debug und Release sind bis auf den Namen identisch |

Zusatzbelege ebenfalls korrekt: `Fastfile:312-320` (Widget-`get_provisioning_profile`),
`docs/SETUP.md:179-184` + `:187-188`, `build/ExportOptions.plist:13-19`,
`ShipTrip-Info.plist:9-29` (UTI-Werte decken sich mit der H4-Tabelle),
`scripts/check-l10n.py:164` (`rglob("*.xcstrings")`),
`NotificationReconciler.swift:32` (`identifierPrefix = "reminder."` — der
Identifier `share.handoff` kollidiert nachweislich nicht),
`TARGETED_DEVICE_FAMILY = 1` in App **und** Widget (kein Familien-Mismatch für
ein drittes Target).

## 3. Neue Findings aus Iteration 2

| ID | Sev | Blocker | Datei:Zeile | Titel |
|-----|-------|---------|-------------|-------|
| G01 | major | nein (**Auflage A1**) | contract:136-138 · ShipTripApp.swift:291-303 | Re-Scan an der `dismiss()`-Stelle kann das Folge-Sheet verschlucken und den Coordinator festnageln |
| G02 | major | nein (**Auflage A2**) | contract:131-138 · ShipTripApp.swift:250,268 | Scan läuft auch im Wegwerf-Store; Übergabedatei wird trotzdem gelöscht |
| G03 | minor | nein | contract:117-128 · ShareImportCoordinator.swift:89 | Die Scan-Extension muss in derselben Datei liegen (`startImport` ist `private`) |
| G04 | minor | nein | contract:131-138 | „genau drei Aufrufstellen" sind vier Code-Stellen |
| G05 | minor | nein | contract:231-244 | Mitteilung wird geplant, während die Extension-UI noch steht |
| G06 | minor | nein | ADR-010:65 · contract:248 | „Antippen öffnet ShipTrip (Systemverhalten)" ist unverifiziert, aber nicht so getaggt |
| G07 | minor | nein | contract:140-142 | `.linkHint` blockiert den Scan — Hinweis „keine Datei", obwohl eine wartet |
| G08 | minor | nein | contract:131-138 | Selbst-Teilen aus ShipTrip heraus löst nach Rückkehr ein „bereits vorhanden"-Sheet aus |
| G09 | minor | nein | ShipTrip/ShareShared/ShareHandoffStore.swift | S0 wurde vor dem grünen Gate implementiert (inhaltlich deckungsgleich) |

### G01 — Re-Scan an der `dismiss()`-Stelle kann das Folge-Sheet verschlucken

- **Datei**: `contract:136-138` (H3, Aufrufstelle 3), Bestand
  `ShipTrip/ShipTripApp.swift:291-303`
- **Severity**: major · **Blocker: nein**, aber **Auflage A1**
- **Problem**: H3 verlangt den Re-Scan „nach `shareImportCoordinator.dismiss()`
  … (beide `dismiss`-Stellen)". Beide Stellen liegen im Präsentationspfad: eine
  im `set:`-Closure der `Binding<ShareImportPresentation?>` (`:297`), eine im
  Schließen-Callback des Sheets (`:301`). Der Scan setzt den Zustand synchron
  auf `.importing`; das ist noch harmlos, weil
  `ShareImportPresentation.init?(state:)` für `.idle` **und** `.importing` `nil`
  liefert (`ShareImportResultSheet.swift:37-41`). Gefährlich ist der Ausgang:
  schlägt der Import der zweiten Datei **schnell** fehl (defektes Archiv,
  Preflight-Abbruch — wenige Millisekunden), steht `.failed` noch **während der
  Dismiss-Animation** (~0,3 s) an, und die Bindung wird wieder non-nil. SwiftUI
  präsentiert dann nicht neu — genau das dokumentiert der Kommentar an
  `:285-290` („only presenting a single sheet is supported"). Ergebnis:
  Coordinator steht auf `.failed`, kein Sheet auf dem Schirm, `dismiss()`
  erreichbar nur über ein Sheet, das nicht existiert ⇒ **jeder weitere Import
  ist bis zum App-Neustart blockiert** (Single-Flight), und die Datei ist
  bereits gelöscht. Das ist eine schärfere Variante des Ausgangsbefunds „es tut
  sich gar nichts".
- **Fix (Auflage A1, ein Satz in H3)** — ersetzt Aufrufstelle 3:
  > 3. `.onDisappear` am Inhalt des Ergebnis-Sheets
  >    (`ShareImportResultSheet`) — läuft **nach** abgeschlossener Dismiss-
  >    Animation und deckt beide Schließwege (Swipe und Button) mit **einer**
  >    Stelle ab. Nicht im `set:`-Closure der Sheet-Bindung und nicht im
  >    Button-Callback aufrufen: ein dort gesetzter Zustand fällt in die
  >    laufende Dismiss-Animation und SwiftUI verwirft die Neu-Präsentation
  >    kommentarlos.
  Damit werden aus vier Code-Stellen drei (löst zugleich G04).

### G02 — Scan läuft auch im Wegwerf-Store, Datei wird trotzdem gelöscht

- **Datei**: `contract:131-138` (H3, Verdrahtung), Bestand
  `ShipTrip/ShipTripApp.swift:250` (`if let container = modelContainer`), `:268`
  (`usingTemporaryStore`)
- **Severity**: major · **Blocker: nein**, aber **Auflage A2**
- **Problem**: Fällt SwiftData auf den In-Memory-Ersatzstore zurück, zeigt die
  App die Warnung „Daten nicht verfügbar" (`:265-278`) — der neue Scan feuert
  trotzdem bei `.active` und beim Szenenaufbau. Er importiert in den
  Wegwerf-Store, meldet im Ergebnis-Sheet „1 importiert" und **löscht die
  Übergabedatei** (`ShareImportCoordinator.swift:99-105`, Erfolg wie Fehler).
  Nach dem Neustart ist die Reise weg. Anders als beim heutigen
  `onOpenURL`-Weg passiert das ohne jede Nutzeraktion. Entschärfend: das
  Original (iMessage-Anhang / Datei) existiert weiter, der Nutzer kann erneut
  teilen — deshalb major statt critical und kein Blocker.
- **Fix (Auflage A2, ein Satz in H3)**:
  > Der Scan unterbleibt, solange `usingTemporaryStore == true` — in den
  > Ersatzstore importierte Reisen wären nach dem Neustart verloren, die
  > Übergabedatei aber gelöscht. Die Datei bleibt liegen und wird beim nächsten
  > gesunden Start importiert (die 24-h-Regel der Extension begrenzt das).

### Minor-Findings (Kurzform, alle Backlog)

- **G03** `contract:117-128` — `importPendingHandoffIfIdle` ist als
  `extension ShareImportCoordinator` skizziert und ruft `startImport(of:)`, das
  `private` und damit **dateiprivat** ist (`ShareImportCoordinator.swift:89`).
  Die Extension muss deshalb in **derselben Datei** stehen. Das ergibt sich aus
  dem Parallelisierungsplan (B schreibt nur zwei Dateien), steht aber nirgends —
  ein Satz in H3 erspart Developer B die Rückfrage oder eine unnötige
  Sichtbarkeitsänderung.
- **G04** `contract:131-138` — „genau drei Aufrufstellen", die dritte nennt aber
  „beide `dismiss`-Stellen" = vier Code-Stellen. Mit A1 sind es wieder drei.
- **G05** `contract:231-244` — Reihenfolge in H5 plant die Mitteilung (Schritt 2)
  **vor** dem Abschlusstext (Schritt 3): das Banner erscheint über der noch
  stehenden Extension-UI und doppelt deren Aussage; tippt der Nutzer es dort an,
  stirbt die Extension vor `completeRequest`. Fix: Mitteilung als letzten
  Schritt unmittelbar vor `completeRequest` planen.
- **G06** `ADR-010:65`, `contract:248` — „Antippen der Mitteilung öffnet ShipTrip
  (Systemverhalten)" ist als Faktum formuliert. Der Zulieferer-Check findet dazu
  **keine** Apple-Referenzaussage (Archiv sagt nur: „A Today widget (and no
  other app extension type) can ask the system to open its containing app").
  Fix: ein `(unverifiziert)` an diesen Satz — Schritt V.5 prüft es ohnehin.
- **G07** `contract:140-142` — Steht der Zustand auf `.linkHint`
  (`shiptrip://import`), verwirft der Scan. Der Nutzer sieht „Öffne die
  angehängte .shiptrip-Datei", obwohl eine Übergabedatei wartet. Selbstheilend
  über den Re-Scan nach `dismiss` (A1). Nur Textrisiko, keine Datenwirkung.
- **G08** `contract:131-138` — Mit der Extension erscheint ShipTrip auch im
  **eigenen** Teilen-Sheet („Kreuzfahrt teilen" → ShipTrip). Nach Rückkehr feuert
  der Scan und zeigt „bereits vorhanden" (Dedup greift, keine Datenwirkung).
  Erwähnenswert im Contract, damit es im Gerätetest nicht als Bug gilt.
- **G09** `ShipTrip/ShareShared/ShareHandoffStore.swift` (126 Zeilen, während
  dieses Laufs entstanden) — gegen H2 gegengelesen: Namenslänge 45, reine
  String-Prüfung mit `UUID(uuidString:)` + case-insensitiver Endung, Scan nicht
  rekursiv mit `isRegularFile`/`isSymbolicLink`-Filter, Sortierung
  Änderungsdatum + Tiebreak Dateiname, fehlender Ordner ⇒ `[]`,
  `inboxURL` legt bewusst nichts an. **Deckungsgleich, kein Nacharbeitsbedarf.**
  Prozessbefund: S0 lief vor dem grünen Gate.

## 4. Apple-Fakten-Nachprüfung zu H5 (neu in Iteration 2)

Über einen Tiefe-1-Zulieferer, ausschließlich developer.apple.com:

| Aussage | Stand | Quelle |
|---|---|---|
| `trigger: nil` ⇒ sofortige Zustellung | **verifiziert** | `unnotificationrequest/init(identifier:content:trigger:)`: „Specify `nil` to deliver the notification right away." |
| `UNUserNotificationCenter` „for your app **or app extension**" | **verifiziert** (Klassenebene) | `usernotifications/unusernotificationcenter` |
| Share-Extension darf `add(_:)` aufrufen | **nicht gefunden** (keine Extension-Einschränkung, kein `NS_EXTENSION_UNAVAILABLE` an `current()`/`add(_:)`) | ebd. |
| Extension teilt die Autorisierung der Container-App | **nicht gefunden** — Doku spricht durchgängig von „your app" | `getnotificationsettings(completionhandler:)` |
| Mitteilung wird der Container-App zugeschrieben / Tap öffnet sie | **nicht gefunden** | Archiv ExtensionOverview |

Der Contract stuft genau diese Punkte selbst als unverifiziert ein und hat eine
Rückfallposition (`:252-259`: Schritte 1–2 entfernen, Abschlusstext bleibt,
Import-Weg unverändert). Das ist die richtige Behandlung — **einzige Lücke ist
G06**, der Tap-Satz trägt das Etikett noch nicht.

## 5. Baubarkeit ohne Rückfrage

**Developer A (Extension): ja.** Plist-Schlüssel abschließend, Prädikat wörtlich,
Principal Class benannt, Ladefunktion benannt, Entitlements-Inhalt benannt,
Build-Settings vollständig (gegen pbxproj verifiziert), pbxproj-Objektliste
abhakbar, Abnahme-Kommando genannt, Strings final. Restfreiheit ohne
Rückfragebedarf: das Layout von `ShareViewController` (nur „Text + Schließen"
vorgegeben) und dessen Accessibility-Identifier — beides nicht in ZIEL/Tests
referenziert. Offen bleibt bewusst nur, ob das Prädikat am Gerät greift; dafür
stehen Diagnose-Reihenfolge und Notnagel im Contract.

**Developer B (App-Seite): ja, nach A1/A2/G03.** Signaturen, Test-Nähte,
Testdateien, Rot-Vorher-Kriterium, Zustandsregeln und `container.mainContext`
als Kontextquelle sind eindeutig. Ohne A1 baut B einen erreichbaren
Blockadezustand ein, ohne G03 stolpert er über die `private`-Sichtbarkeit.

**Schreib-Disjunktheit** bleibt gegeben und ist jetzt mit Pfaden und dem Grund
für die pbxproj-Exklusivität dokumentiert (`:345-351`) — `ShipTripTests` als
`PBXFileSystemSynchronizedRootGroup` ohne Exception-Set habe ich in
`project.pbxproj:104-108` nachgeprüft: stimmt.

## 6. Backlog-Kandidaten (Übertragung durch Winston)

```
- [minor] docs/architecture/contracts/share-extension-handoff.md:117-128 — Scan-Extension muss in ShareImportCoordinator.swift liegen (startImport ist private)
- [minor] docs/architecture/contracts/share-extension-handoff.md:131-138 — "genau drei Aufrufstellen" sind vier Code-Stellen
- [minor] docs/architecture/contracts/share-extension-handoff.md:231-244 — Mitteilung erst unmittelbar vor completeRequest planen
- [minor] docs/adr/ADR-010-share-extension-app-group-handoff.md:65 — "Antippen oeffnet ShipTrip" als (unverifiziert) taggen
- [minor] docs/architecture/contracts/share-extension-handoff.md:140-142 — .linkHint blockiert den Scan, Hinweistext irrefuehrend
- [minor] docs/architecture/contracts/share-extension-handoff.md:131-138 — Selbst-Teilen ShipTrip→ShipTrip erzeugt "bereits vorhanden"-Sheet
- [minor] .planning/ — S0 wurde vor dem gruenen Gate #4 implementiert (Prozess, inhaltlich deckungsgleich)
```

## 7. Go/No-Go

**Go.** Alle neun Blocker der Iteration 1 sind geschlossen, keiner davon
kosmetisch: der abgelehnte Runtime-Hack ist ersatzlos raus, die einzige
Angriffsfläche ist mit ihm verschwunden, die Traversal-Prüfung ist jetzt eine
String-Prüfung ohne `URL`-Umweg, und die Build-/Signing-Lücken sind gegen das
Widget-Target belegt statt behauptet. Der Entwurf ist **kleiner** geworden und
gleichzeitig belastbarer. Kein neuer Blocker.

**Zwei Auflagen vor dem B-Spawn** (Wortlaut oben, beides je ein Satz in H3;
Winston trägt sie ein, kein weiteres Gate nötig):

- **A1** — Re-Scan über `.onDisappear` des Ergebnis-Sheets statt in der
  Sheet-Bindung / im Button-Callback (G01).
- **A2** — Kein Scan bei `usingTemporaryStore` (G02).

Werden A1/A2 nicht eingetragen, ist dieses Go hinfällig: der Contract führt
Developer B dann in eine erreichbare Import-Blockade.
