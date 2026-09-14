# Review — Architektur-Gate #4: Share-Extension `ShipTripShare` (ADR-010 + Contracts H1–H6)

- **Iteration**: 1 / 3
- **Reviewer**: quality-agent (Claude-intern, adversarial; ersetzt Codex-Gate)
- **Datum**: 2026-09-10
- **Prüfgegenstand**: Entwurf, kein Code. Worktree
  `/Users/andre-studio/Documents/0.Projekte/ShipTrip-worktrees/widget-1.9.0`,
  Branch `feature/share-extension`
- **Verdikt**: **request-changes / No-Go** — Entwurf darf so nicht an die Developer
- **Stats**: critical 2 · major 10 · minor 9 — **Blocker 9**, Backlog 12

## Test-Run-Status (ehrlich)

`git status` auf dem Branch zeigt genau drei geänderte/neue Dateien, alle Markdown:
`docs/adr/ADR-010-…md`, `docs/architecture/contracts/share-extension-handoff.md`,
`docs/adr/README.md`. **Änderungsklasse „docs" ⇒ die Testumfangs-Leiter verlangt
keinen Testlauf.** Es existiert folglich **kein `gate-run.json` und es ist auch keins
geschuldet**; niemand behauptet an dieser Stelle „Tests grün". Gefahren wurde:

- Statischer Pass: `guard.py sizes --files <3 geänderte>` → `sizes: ok (3 geprueft,
  0 Soft-Warnungen)`, Exit 0.
- Ein eigenständiger Swift-Beleg zu F02 (Path-Traversal), Ausgabe unten im Finding.

Die Test-Pflicht entsteht mit Workstream B; ZIEL #7 (`gate-run.json` Exit 0) ist im
Entwurf keinem Arbeitsstrang zugeordnet — siehe F09.

## Summary

Der Entwurf ist handwerklich gut: Er trennt Extension und Import sauber, hält den
SwiftData-/CloudKit-Store aus dem Extension-Prozess heraus, macht den Vordergrund-Scan
zum tragenden Weg und kennzeichnet Unverifiziertes als unverifiziert. Genau der
tragende Teil ist belastbar.

Zwei Dinge kippen das Gate. **Erstens** ist der „Best-effort-Beschleuniger"
(Responder-Chain-`openURL:`) nicht, wie der ADR schreibt, ein Weg der „in künftigen
iOS-Versionen wegfallen kann" — Apple DTS lehnt ihn ausdrücklich ab, er umgeht eine
`NS_EXTENSION_UNAVAILABLE`-Sperre über die ObjC-Runtime, und auf iOS 18 (das
Deployment-Minimum ist 18.5) wird er berichtet als bereits wirkungslos. **Zweitens**
öffnet der einzige Zweck dieses Beschleunigers — der Query-Parameter `file=` — die
einzige Angriffsfläche des ganzen Designs, und die dafür vorgeschriebene Prüfung
verhindert Path-Traversal nachweislich nicht. Beide Befunde zeigen in dieselbe
Richtung: **der `file=`-Pfad samt Router-Case ist ersatzlos streichbar**, und mit ihm
verschwinden H1, das Sicherheitsrisiko und zwei ZIEL-Kriterien in ihrer heutigen
Fassung. Das ist eine Andre-Entscheidung, kein Developer-Detail.

Dazu kommt eine Klasse von Lücken, die alle dieselbe Ursache hat: **H4/H6 sind
gegenüber dem Widget-Präzedenzfall unvollständig** (Entitlements-Build-Setting,
Anzeigename, pbxproj-Integration, Info.plist-Herkunft). Mit dem beschriebenen Umfang
baut die Extension nicht, heißt im Teilen-Sheet falsch, oder der Übergabeordner ist
zur Laufzeit still nicht erreichbar.

## Urteil je Prüffrage

| Q | Frage | Urteil | Ein Satz |
|---|---|---|---|
| Q1 | ZIEL 1–7, 9 erfüllt? | **fail** | 2/5/6 tragen; 1, 4, 7 und 9 sind lückenhaft (F06, F04, F09, F17), 3 steht auf einem Mechanismus, den Apple ablehnt (F01/F03). |
| Q2 | Vordergrund-Scan + Responder-Chain akzeptabel? | **fail** | Der Scan trägt und ist richtig gewählt, der Beschleuniger ist unbrauchbar; es gibt einen von Apple genannten, robusteren Weg (Local Notification), den der Entwurf nicht prüft. |
| Q3 | Aktivierungsprädikat + `UTImportedTypeDeclarations` korrekt? | **unklar** | Prädikat-Syntax stimmt (nur in Apple-Archivdoku belegt), die Innen-Zählform weicht vom Apple-Beispiel ab (F11); die Doppeldeklaration ist unschädlich, aber die Plist-Herkunft ist eine Store-Falle (F05). |
| Q4 | Path-Traversal / Löschregel / Atomarität / 24 h | **fail** | Traversal ist **nicht** ausgeschlossen (F02, mit Beleg); Löschregel-Präfix und tmp+move-Atomarität sind sauber, 24 h sind sinnvoll. |
| Q5 | Simplicity — etwas überdesignt? | **fail** | Ja: `file=`, `.pendingShareFile`, H1 und `HostAppOpener` sind auch im Erfolgsfall redundant (F03). |
| Q6 | Signing/Build-Muster vollständig? | **fail** | Fastfile/ExportOptions/SETUP.md sind vollständig gedacht, aber `CODE_SIGN_ENTITLEMENTS`, Anzeigename und die halbe pbxproj-Integration fehlen (F06–F08). |
| Q7 | Workstreams schreib-disjunkt? | **pass** (mit Auflage) | Disjunkt inkl. `project.pbxproj` — aber nur, weil `ShipTripTests` eine synchronisierte Gruppe ohne Exceptions ist; das steht nirgends und muss als Auflage in den Contract (F21). |
| Q8 | Contracts baubar ohne Rückfrage? | **fail** | Nein — neun Blocker, davon zwei mit Architektur-Wirkung. |

## Findings

| ID | Sev | Blocker | Datei:Zeile | Kategorie | Titel |
|-----|----------|-----|---------------------------------------------------|--------------|-----------------------------------------------------------|
| F01 | critical | ja  | ADR-010:63-71 · contract:186, :190 | architektur  | Responder-Chain-`openURL:` ist von Apple abgelehnt und auf iOS 18 wirkungslos |
| F02 | critical | ja  | contract:41 (H1) · ADR-010:74-77 | security     | Vorgeschriebene Namensprüfung verhindert Path-Traversal nicht |
| F03 | major    | ja  | contract:35-59 (H1), :44 | simplicity   | `file=` + `.pendingShareFile` sind auch im Erfolgsfall redundant |
| F04 | major    | ja  | contract:98-103 · ShareImportCoordinator.swift:70-78 | tests        | ZIEL-#4-Unit-Test ist wie spezifiziert nicht konstruierbar |
| F05 | major    | ja  | contract:155-159 · ShipTrip-Info.plist:5-8 | build/store  | „identisch zur App-Seite" schleppt `UIBackgroundModes` in die Extension |
| F06 | major    | ja  | contract:209 (H6) | build        | Anzeigename im Teilen-Sheet fehlt — ZIEL #1 verfehlt |
| F07 | major    | ja  | contract:209 (H6) | build        | `CODE_SIGN_ENTITLEMENTS` fehlt — App Group zur Laufzeit still tot |
| F08 | major    | ja  | contract:210-211 (H6) | build        | pbxproj-Integrationsumfang unvollständig — Extension baut/installiert nicht |
| F09 | major    | ja  | contract:234-236 | prozess      | Verifikationsplan deckt ZIEL #1 und #7 nicht ab, kein Owner |
| F10 | major    | nein | contract:165-172 | konsistenz   | Rückfallposition `public.file-url` reproduziert genau den in H4 abgelehnten Nachteil |
| F11 | major    | nein | contract:143-148 | korrektheit  | Prädikat-Innenform weicht vom Apple-Beispiel ab; Anhang-Auswahl unspezifiziert |
| F12 | major    | nein | contract:113-116 · ShareImportCoordinator.swift:44,56-58 | korrektheit  | Zweite anstehende Datei bleibt bis zum 24-h-Aufräumen liegen |
| F13 | minor    | nein | contract:198-200 · scripts/check-l10n.py:164 | ci           | Neuer String Catalog fällt automatisch ins L10n-Gate |
| F14 | minor    | nein | contract:186 | präzision    | `HostAppOpener` ohne Datei/Target benannt |
| F15 | minor    | nein | contract:133-134 | präzision    | Principal Class nicht spezifiziert |
| F16 | minor    | nein | contract:174-178 | modernität   | Typunsichere `loadFileRepresentation`-Variante gewählt |
| F17 | minor    | nein | contract:220-236 | prozess      | ZIEL #9 (Doku/CHANGELOG) keinem Workstream zugeordnet |
| F18 | minor    | nein | contract:90 | präzision    | `pendingFiles`: Fehler-/Sortierverhalten unspezifiziert |
| F19 | minor    | nein | fastlane/Fastfile:9-10 | hygiene      | `APP_STORE_VERSION`/`APP_STORE_BUILD` veraltet (Bestand, nicht dieser Change) |
| F20 | minor    | nein | contract:198-200 | präzision    | Vier Extension-Strings ohne finalen DE/EN-Wortlaut |
| F21 | minor    | nein | contract:220-236 | prozess      | Parallelisierungsplan nennt keine Dateipfade; pbxproj-Exklusivität nicht festgeschrieben |

---

### F01 — Responder-Chain-`openURL:` ist von Apple abgelehnt und auf iOS 18 wirkungslos

- **Datei**: `docs/adr/ADR-010-…md:63-71`, `docs/architecture/contracts/share-extension-handoff.md:186` und `:190`
- **Severity**: critical · **Blocker: ja**
- **Problem**: Der ADR stuft den Weg als „verbreitetes Community-Wissen" ein, das „in
  künftigen iOS-Versionen wegfallen kann". Die Verifikation ergibt ein deutlich
  schärferes Bild:
  - **Apple DTS (Quinn, Developer Forums 764570), wörtlich:** „App extensions are not
    allowed to open URLs directly. This isn't accidental, but a deliberate design
    choice on Apple's part. **Don't try to bypass such restrictions using Silly Runtime
    Hacks™.** That just opens yourself up to compatibility problems down the pike." —
    und ausdrücklich zu genau dieser `nextResponder` + `performSelector:@selector(openURL:)`-Konstruktion:
    „You've used the Objective-C runtime to bypass that build-time restriction, and
    that's now failing."
  - **Apple Frameworks Engineer (Forums 773342), wörtlich:** „There's no supported way
    for you to launch your app directly from App Extensions, except Today and Widgets".
  - **iOS 18 (Community-Bericht im selben Thread, nicht Apple):** „BUG IN CLIENT OF
    UIKIT: … Force returning false (NO)." Das Deployment-Minimum des Projekts ist
    **18.5** — der Beschleuniger wäre also voraussichtlich ab dem ersten Tag tot.
  - App-Store-Risiko: die Konstruktion umgeht eine `NS_EXTENSION_UNAVAILABLE`-Sperre
    per ObjC-Runtime. *Ein wörtliches Review-Guidelines-Zitat, das das benennt, wurde
    nicht gefunden* — die Einordnung stützt sich auf die DTS-Aussage, nicht auf 2.5.1.
- **Fix**: `HostAppOpener` und den gesamten Best-effort-Pfad **ersatzlos streichen**
  (H5-Tabellenzeile 3, Ablaufschritte 1–2, ADR-„Entscheidung" Punkt 2). Der tragende
  Weg 1 bleibt unverändert und ist korrekt gewählt.
- **Ersatz, falls die Zweistufigkeit Andre zu teuer ist** — derselbe DTS-Text nennt den
  unterstützten Weg wörtlich: „If your app extension needs to get the user's attention,
  do that by posting a local notification." Die Extension stellt nach dem Kopieren eine
  lokale Notification („Reise empfangen — tippen zum Importieren"); ein Tap öffnet die
  App, `scenePhase == .active` feuert, der Scan importiert. Das ist ein Tap statt einer
  manuellen App-Suche, hängt an keiner undokumentierten API, und das Projekt hat
  Notification-Infrastruktur bereits (`NotificationService`, `aps-environment` in
  `ShipTrip/ShipTrip.entitlements`). Kosten: Permission-Abfrage-Abhängigkeit —
  bei verweigerter Berechtigung greift der heutige Statustext als Fallback.
  Verifikationsstand: DTS-Forums-Aussage, **keine** Referenzdoku-Seite.

### F02 — Vorgeschriebene Namensprüfung verhindert Path-Traversal nicht

- **Datei**: `docs/architecture/contracts/share-extension-handoff.md:41` (H1, Zeile
  `<name>`), Anspruch in `docs/adr/ADR-010-…md:74-77`
- **Severity**: critical · **Blocker: ja**
- **Problem**: H1 formuliert die Absicht korrekt („Kein `/`, kein `\`, kein `..`"),
  schreibt als **Prüfung** aber vor: „`UUID(uuidString:)` auf den Stamm muss gelingen
  und die Endung (case-insensitiv) `shiptrip` sein". „Stamm" und „Endung" sind nicht
  definiert; die naheliegendste Swift-Umsetzung (`URL(fileURLWithPath:)`,
  `deletingPathExtension().lastPathComponent`, `.pathExtension`) erfüllt diese
  Vorschrift wörtlich und **akzeptiert Traversal**, weil `lastPathComponent` den
  Verzeichnisanteil gerade wegschneidet. Ausgeführter Beleg:

  ```
  AKZEPTIERT | in=2C4A230C-….shiptrip          aufgeloest=/AppGroup/ShareInbox/2C4A230C-….shiptrip
  AKZEPTIERT | in=../2C4A230C-….shiptrip        aufgeloest=/AppGroup/2C4A230C-….shiptrip
  AKZEPTIERT | in=../../../Library/Preferences/2C4A230C-….shiptrip
                                                aufgeloest=/Library/Preferences/2C4A230C-….shiptrip
  AKZEPTIERT | in=a/b/2C4A230C-….shiptrip       aufgeloest=/AppGroup/ShareInbox/a/b/2C4A230C-….shiptrip

  queryItem 'file' nach URLComponents-Dekodierung = ../2C4A230C-….shiptrip
  ```

  Die letzte Zeile zeigt zusätzlich: `URLComponents.queryItems` dekodiert
  Prozent-Sequenzen **bereits beim Lesen**, `..%2F…` kommt als `../…` an. H1s Satz
  „keine Prozent-Sequenzen nach dem Dekodieren" ist damit keine wirksame Hürde.
  Zusammen mit H3 (`inboxURL` + Name) verlässt die aufgelöste URL den Übergabeordner.
  Angriffsweg: eine beliebige Webseite/Nachricht mit `shiptrip://import?file=…`.
  Wirkung bleibt sandbox-intern (Import einer beliebigen für die App lesbaren Datei),
  aber der ADR verkauft „nie einen Pfad … per Konstruktion" als Sicherheitseigenschaft,
  und die liefert der Contract nicht.
- **Fix (wenn F03 nicht gezogen wird)** — zwei Gurte:
  1. Prüfung auf dem **rohen String**, nicht über `URL`:
     `^[0-9A-Fa-f]{8}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{12}\.shiptrip$`
     (case-insensitiv, Länge exakt 45), zusätzlich `UUID(uuidString:)` auf die ersten
     36 Zeichen.
  2. In H3 nach dem Zusammensetzen nachprüfen:
     `resolved.deletingLastPathComponent().standardizedFileURL == inbox.standardizedFileURL`,
     sonst verwerfen und auf den Scan zurückfallen.
  3. Unit-Tests mit `../`, `..%2F`, `a/b/`, Leerstring, doppelter `file=`-Parameter.
- **Besserer Fix**: F03 — dann entfällt der Parameter und mit ihm dieses Finding.

### F03 — `file=` + `.pendingShareFile` sind auch im Erfolgsfall redundant

- **Datei**: `docs/architecture/contracts/share-extension-handoff.md:35-59` (H1 komplett), `:44`
- **Severity**: major · **Blocker: ja** (Scope-Entscheidung, ändert die Naht zwischen A und B)
- **Problem**: Der Parameter existiert ausschließlich, um dem
  Responder-Chain-Öffnen (F01) mitzuteilen, *welche* Datei gemeint ist. Selbst wenn
  dieses Öffnen funktionierte, wäre er wirkungslos: **gelingt das Öffnen, kommt die App
  in den Vordergrund, `scenePhase` wechselt auf `.active`, und der Scan importiert die
  anstehende Datei ohnehin** (contract:120-121). Der einzige Unterschied ist die
  Auswahl bei mehreren wartenden Dateien — und H3 hält selbst fest, der Ordner enthalte
  „in der Regel genau eine Datei" (contract:124-125). Dafür bezahlt der Entwurf mit:
  einem neuen Router-Case, dem gesamten H1-Vertrag, zwei zusätzlichen Testfällen und
  der einzigen Angriffsfläche des Designs (F02).
- **Fix**: H1 streichen; `IncomingLink` bleibt bei zwei Cases (`IncomingLinkRouter.swift:15-20`
  unverändert); falls ein Öffnen-Versuch bleibt, dann mit der unveränderten C3-URL
  `shiptrip://import`. **Konflikt mit ZIEL #3, der den Router-Case ausdrücklich
  verlangt — das ist eine Andre-Entscheidung, keine Developer-Freiheit.** Empfehlung:
  ZIEL #3 streichen bzw. auf „Scan trägt" umformulieren.
- **Nebeneffekt**: `ShareImportCleanupTests.swift` und `IncomingLinkRouterTests.swift`
  bleiben unverändert; ZIEL #4 (Löschregel) bleibt davon unberührt und sinnvoll.

### F04 — ZIEL-#4-Unit-Test ist wie spezifiziert nicht konstruierbar

- **Datei**: `docs/architecture/contracts/share-extension-handoff.md:98-103` (H3),
  Bestand `ShipTrip/Views/Share/ShareImportCoordinator.swift:70-78`
- **Severity**: major · **Blocker: ja**
- **Problem**: `shouldRemoveAfterImport(_:)` ist eine statische Funktion ohne Naht; die
  Erweiterung soll den Übergabeordner aus dem globalen `ShareHandoffStore.inboxURL()`
  ziehen. Der Contract räumt selbst ein: „Ist `inboxURL()` `nil` (Unit-Test-Bundle ohne
  Entitlement), zählt nur Inbox/tmp wie bisher." Genau in der Umgebung, in der der Test
  laufen soll, ist der neue Zweig also entweder tot oder umgebungsabhängig — ZIEL #4
  verlangt aber einen Test, der **vor dem Fix rot** ist. Die bestehenden Tests
  (`ShipTripTests/ShareImportCleanupTests.swift:18-49`) rufen die Funktion direkt auf
  und haben keinen Einhängepunkt.
- **Fix**: Naht per Default-Argument, alle vier bestehenden Aufrufstellen und Tests
  bleiben unverändert:
  ```swift
  static func shouldRemoveAfterImport(
      _ url: URL,
      inbox: URL? = ShareHandoffStore.inboxURL()
  ) -> Bool
  ```
  Der neue Test übergibt ein Wegwerf-Verzeichnis und prüft beide Richtungen
  (Datei im Übergabeordner ⇒ `true`, Geschwister-Ordner mit gleichem Präfix ⇒ `false`).
  In H3 explizit als Signatur festschreiben.

### F05 — „identisch zur App-Seite" schleppt `UIBackgroundModes` in die Extension

- **Datei**: `docs/architecture/contracts/share-extension-handoff.md:155-159`,
  Quelle der Falle: `ShipTrip-Info.plist:5-8`
- **Severity**: major · **Blocker: ja**
- **Problem**: H4 weist die UTI-Deklaration der Extension als „identisch zur App-Seite"
  an. Die naheliegende Umsetzung ist, `ShipTrip-Info.plist` zu kopieren und
  umzuschreiben — die trägt aber `UIBackgroundModes = [remote-notification]`,
  `CFBundleDocumentTypes` und `CFBundleURLTypes`. Apple, wörtlich (App Extension
  Programming Guide, ExtensionCreation): „If you include the `UIBackgroundModes` key in
  your app extension's `Info.plist` file, **the extension will be rejected by the App
  Store**." Der Widget-Präzedenzfall macht es richtig: `ShipTripWidget/Info.plist` ist
  minimal und enthält nur das `NSExtension`-Dictionary.
- **Fix**: H4 umformulieren auf: Extension-Plist wird **vom Widget-Muster abgeleitet**
  (`NSExtension`-Dict + `NSExtensionPrincipalClass`), plus `UTImportedTypeDeclarations`
  mit exakt den Werten aus `ShipTrip-Info.plist:9-29`. Ausdrücklich verboten:
  `UIBackgroundModes`, `CFBundleDocumentTypes`, `CFBundleURLTypes`.
- **Nebenbefund (verifiziert, entlastet den Entwurf)**: Die Doppeldeklaration
  App-exportiert / Extension-importiert ist unschädlich — Apple: „If both imported and
  exported declarations for a UTI exist, the exported declaration takes precedence over
  imported one." Ob die Extension die Deklaration überhaupt braucht, ist **in der
  Apple-Doku nicht auffindbar**; der Contract sagt das bereits richtig und darf so
  bleiben.

### F06 — Anzeigename im Teilen-Sheet fehlt — ZIEL #1 verfehlt

- **Datei**: `docs/architecture/contracts/share-extension-handoff.md:209` (H6, Build-Settings)
- **Severity**: major · **Blocker: ja**
- **Problem**: ZIEL #1 verlangt wörtlich, dass im Teilen-Sheet **„ShipTrip"** erscheint.
  Der angezeigte Name einer Share-Extension ist ihr `CFBundleDisplayName`; fehlt der,
  fällt iOS auf `PRODUCT_NAME` = `$(TARGET_NAME)` zurück und das Sheet zeigt
  **„ShipTripShare"**. Das Widget-Target setzt den Schlüssel deshalb explizit
  (`INFOPLIST_KEY_CFBundleDisplayName = ShipTrip`, `project.pbxproj:699-754`); H6s
  Build-Setting-Liste nennt ihn nicht.
- **Fix**: `INFOPLIST_KEY_CFBundleDisplayName = ShipTrip` in H6 aufnehmen und im
  Simulator-Nachweis (F09) explizit gegen den Sheet-Text prüfen.

### F07 — `CODE_SIGN_ENTITLEMENTS` fehlt — App Group zur Laufzeit still tot

- **Datei**: `docs/architecture/contracts/share-extension-handoff.md:209` (H6)
- **Severity**: major · **Blocker: ja**
- **Problem**: H6 listet Entitlements als Datei (`:208`) und Build-Settings (`:209`)
  getrennt, verbindet beide aber nie. Ohne
  `CODE_SIGN_ENTITLEMENTS = ShipTripShare/ShipTripShare.entitlements` (Widget-Beleg:
  `project.pbxproj:699-754`) wird die `.entitlements`-Datei nie angewandt,
  `containerURL(forSecurityApplicationGroupIdentifier:)` liefert `nil`, und der gesamte
  Übergabeweg ist **still** tot — die Extension meldet nur „Übergabe fehlgeschlagen",
  ohne dass die Ursache sichtbar wäre. Weitere in H6 fehlende, aber
  build-/signing-entscheidende Settings gegenüber dem Widget: `INFOPLIST_FILE`,
  `GENERATE_INFOPLIST_FILE = YES`, `PRODUCT_BUNDLE_IDENTIFIER`, `PRODUCT_NAME`,
  `CODE_SIGN_STYLE = Automatic`, `DEVELOPMENT_TEAM = LH324Y9MG7`,
  `LD_RUNPATH_SEARCH_PATHS` (inkl. `@executable_path/../../Frameworks`),
  `SUPPORTED_PLATFORMS`, `SWIFT_EMIT_LOC_STRINGS = YES` (String Catalog!),
  `CURRENT_PROJECT_VERSION`.
- **Fix**: H6-Zeile ersetzen durch: „Build-Konfiguration **1:1 aus dem Widget-Target
  klonen** (`project.pbxproj:699-754`, Debug **und** Release); abweichend nur
  `PRODUCT_BUNDLE_IDENTIFIER`, `INFOPLIST_FILE`, `CODE_SIGN_ENTITLEMENTS`,
  `INFOPLIST_KEY_CFBundleDisplayName`." Die heutige Teil-Aufzählung verleitet dazu,
  nur die genannten zu setzen.

### F08 — pbxproj-Integrationsumfang unvollständig — Extension baut/installiert nicht

- **Datei**: `docs/architecture/contracts/share-extension-handoff.md:210-211` (H6,
  „Einbettung" + „Geteilte Quellen")
- **Severity**: major · **Blocker: ja**
- **Problem**: H6 nennt nur „Embed Foundation Extensions" und `membershipExceptions`.
  Das Projekt ist vollständig auf *file system synchronized groups* umgestellt
  (`objectVersion = 77`, leere `PBXSourcesBuildPhase`-Blöcke) — ein neues Target
  erfordert dort neun weitere Objekte, die der Contract nicht nennt. Belege jeweils aus
  dem Widget:
  1. `PBXNativeTarget` + `XCConfigurationList` + zwei `XCBuildConfiguration`
     (`:251-272`, `:699-754`, `:794-802`)
  2. neue `PBXFileSystemSynchronizedRootGroup` für `ShipTripShare/` (`:114-122`)
  3. **Exception-Set „Info.plist aus dem Copy ausschließen"**
     (`membershipExceptions = (Info.plist,)`, `:86-92`) — fehlt das, landet die
     Info.plist zusätzlich als Ressource im Bundle
  4. Exception-Set „`ShipTrip`-Ordner-Dateien ins Share-Target" für
     `ShareShared/ShareHandoffStore.swift` + `Services/ShareArchiveLimits.swift`
     (Muster `:59-70`)
  5. `PBXFileReference` (`explicitFileType = wrapper.app-extension`, `:55`) +
     Products-Group-Eintrag (`:173`)
  6. `PBXBuildFile` mit `ATTRIBUTES = (RemoveHeadersOnCopy,)` (`:10`) und Eintrag in die
     bestehende `PBXCopyFilesBuildPhase` „Embed Foundation Extensions"
     (`:38-48`, `dstSubfolderSpec = 13`)
  7. `PBXTargetDependency` + `PBXContainerItemProxy` am App-Target (`:28-34`, `:192-194`, `:395-399`)
  8. Eintrag in `targets` (`:317`) und `TargetAttributes` (`:294-296`)
- **Fix**: Diese Liste mit den Zeilenbelegen wörtlich in H6 aufnehmen. Sie ist auch die
  Abnahme-Checkliste für Workstream A.

### F09 — Verifikationsplan deckt ZIEL #1 und #7 nicht ab, kein Owner

- **Datei**: `docs/architecture/contracts/share-extension-handoff.md:234-236`
- **Severity**: major · **Blocker: ja**
- **Problem**: Der serielle Abschluss nennt **nur** den Gerätetest. ZIEL #1 verlangt
  einen **Simulator-Screenshot** des Teilen-Sheets der Dateien-App, ZIEL #7 einen
  **E2E-Lauf im Simulator** plus grüne berührte Suite und `gate-run.json` Exit 0.
  Beides gehört heute keinem Workstream — ein Plan ohne Abnahme-Evidenz produziert am
  nächsten Gate zwangsläufig ein No-Go. Ebenfalls unerwähnt: der Build-Nummer-Bump auf
  31 für ZIEL #8 (`CURRENT_PROJECT_VERSION` in **allen drei** Targets, heute 30).
- **Fix**: Schritt „V — Nachweis (seriell, nach A+B)" in den Plan aufnehmen:
  Wegwerf-Simulator anlegen/booten, App+Appex installieren, Dateien-App → Teilen →
  Screenshot (Sheet muss „ShipTrip" zeigen, F06) → Import → Ergebnis-Sheet-Screenshot;
  berührte Suite über den Evidenz-Helfer fahren (`gate-run.json`); `check-l10n.py`
  (F13); danach Build-Bump auf 31 und erst dann der Gerätetest.

### F10 — Rückfallposition `public.file-url` reproduziert den in H4 abgelehnten Nachteil

- **Datei**: `docs/architecture/contracts/share-extension-handoff.md:165-172`
- **Severity**: major · **Blocker: nein** (Contingency, greift erst nach rotem Gerätetest
  und ist bereits Winston-pflichtig)
- **Problem**: H4 lehnt die Dictionary-Form mit der Begründung ab, sie „matcht **jeden**
  Dateityp — ShipTrip stünde dann auch bei PDFs im Sheet" (`:150-153`). Die vereinbarte
  Rückfallposition `UTI-CONFORMS-TO "public.file-url"` hat exakt dieselbe Wirkung — der
  Contract weicht damit still auf, was er zwei Absätze vorher verworfen hat.
- **Fix**: Nachteil beim Namen nennen und die Ursachenbehebung voranstellen: Greift das
  Prädikat am Gerät nicht, ist die erste Hypothese eine **nicht registrierte
  UTI-Deklaration** (App installiert? Deklaration exportiert?), nicht ein zu enges
  Prädikat. Der Aufweich-Fallback ist letzte Option, mit explizitem „ShipTrip erscheint
  dann bei allen Dateien".

### F11 — Prädikat-Innenform weicht vom Apple-Beispiel ab; Anhang-Auswahl unspezifiziert

- **Datei**: `docs/architecture/contracts/share-extension-handoff.md:143-148`
- **Severity**: major · **Blocker: nein**
- **Problem**: Apples dokumentiertes Beispiel schließt die innere `SUBQUERY` mit
  `.@count == $extensionItem.attachments.@count` („**alle** Anhänge passen"), der
  Contract mit `.@count == 1` („**genau einer** passt"). Die Contract-Form ist damit
  **permissiver**: Liefert ein Host zwei Anhänge (z. B. Datei + `public.url`-Begleiter),
  aktiviert die Extension trotzdem — und der Ablauf in H4/H5 geht stillschweigend von
  genau einem Anhang aus. Wird dann `attachments[0]` genommen, kann das der falsche sein.
- **Fix**: (a) Innenform auf Apples Schreibweise
  `.@count == $extensionItem.attachments.@count` ziehen — das ist zugleich exakt die
  „genau eine Datei"-Semantik, die ZIEL #1 fordert; (b) in H4 festschreiben, dass der
  Anhang per `attachments.first(where: { $0.hasItemConformingToTypeIdentifier("com.andre.shiptrip.cruise") })`
  gewählt wird, nie per Index.
- **Verifikationsstand nachziehen**: Die bare-string-Form ist **verifiziert**, aber
  ausschließlich in einem *retired* Apple-Dokument (App Extension Programming Guide,
  ExtensionScenarios); in der aktuellen `developer.apple.com/documentation`-Referenz
  gibt es dazu **keinen** Ersatzartikel. Ebenfalls verifiziert und im Contract korrekt:
  `$attachment.registeredTypeIdentifiers`, `ANY … UTI-CONFORMS-TO`, sowie die
  TRUEPREDICATE-Ablehnung („If any app extensions in your containing app include the
  string `TRUEPREDICATE`, the app will be rejected."). Der Contract sollte die
  Archiv-Herkunft benennen, damit die Quelle bei einem künftigen Bruch auffindbar ist.

### F12 — Zweite anstehende Datei bleibt bis zum 24-h-Aufräumen liegen

- **Datei**: `docs/architecture/contracts/share-extension-handoff.md:113-116`;
  Bestand `ShipTrip/Views/Share/ShareImportCoordinator.swift:44` und `:56-58`
- **Severity**: major · **Blocker: nein**
- **Problem**: `importPendingHandoffIfIdle()` läuft laut Contract „nur in `.idle`". Nach
  einem Import steht der Zustand aber auf `.finished(...)`, bis der Nutzer das
  Ergebnis-Sheet schließt (`dismiss()` → `.idle`). Teilt der Nutzer zwei Reisen und
  öffnet dann die App, wird die erste importiert, die zweite ignoriert — und der
  Contract schickt sie „auf den nächsten Vordergrund-Wechsel". Kommt der nicht,
  löscht die 24-h-Regel die Datei ungefragt. Das ist genau der Ausgangsbefund („es tut
  sich gar nichts"), nur seltener.
- **Fix**: `.idle` als Gate beibehalten (das schützt das Ergebnis-Sheet), aber am Ende
  von `dismiss()` einen erneuten Scan auslösen. Eine Zeile, deckt den Fall vollständig.
  In H3 als Satz aufnehmen.

### Minor-Findings (Kurzform)

- **F13** `docs/…/share-extension-handoff.md:198-200` — Ein neuer
  `ShipTripShare/Localizable.xcstrings` wird von `scripts/check-l10n.py:164`
  (`rglob("*.xcstrings")`) automatisch erfasst und damit vom CI-L10n-Gate geprüft.
  Fix: als Definition-of-Done in Workstream A aufnehmen (DE/EN vollständig,
  `python3 scripts/check-l10n.py` grün).
- **F14** `:186` — `HostAppOpener` wird ohne Datei und Target benannt. Entfällt bei F01.
- **F15** `:133-134` — „Principal Class ist ein eigener `UIViewController`" sagt nicht,
  ob per `NSExtensionPrincipalClass` oder `NSExtensionMainStoryboard`. Fix:
  `NSExtensionPrincipalClass = $(PRODUCT_MODULE_NAME).ShareViewController`, kein Storyboard.
- **F16** `:174-178` — `loadFileRepresentation(forTypeIdentifier:completionHandler:)` ist
  korrekt beschrieben (Apple wörtlich: „writes a copy of the file's data to a temporary
  file, which the system deletes when the completion handler returns" — die
  Synchronitäts-Auflage im Contract ist damit **verifiziert und richtig**). Seit iOS 16
  gibt es die typsichere Variante `loadFileRepresentation(for:openInPlace:completionHandler:)`
  mit identischem Löschverhalten bei `openInPlace: false`. Fix: darauf umstellen, passt
  zum `UTType`-Bezeichner.
- **F17** `:220-236` — ZIEL #9 (CHANGELOG `[Unreleased]`,
  `docs/features/kreuzfahrt-teilen.md` Known-Limitation entfernen, `CLAUDE.md` um das
  dritte Target ergänzen) ist keinem Workstream zugeordnet. Fix: an Schritt V hängen.
- **F18** `:90` — `pendingFiles(in:)`: Verhalten bei unlesbaren `resourceValues` und bei
  gleichem Änderungsdatum unspezifiziert. Fix: unlesbare Einträge überspringen,
  Tiebreak über den Dateinamen.
- **F19** `fastlane/Fastfile:9-10` — `APP_STORE_VERSION = "1.7.0"`, `APP_STORE_BUILD = 23`
  sind gegenüber 1.9.0/Build 30 veraltet. **Bestand, nicht von diesem Change verursacht**
  → Backlog.
- **F20** `:198-200` — Die vier Extension-Strings sind beschrieben, aber ohne finalen
  DE/EN-Wortlaut. Fix: Wortlaut in den Contract, wie es C8 für die App-Seite tut.
- **F21** `:220-236` — Der Parallelisierungsplan beschreibt A und B in Prosa, ohne
  Dateipfade. **Die Prüfung ergibt echte Schreib-Disjunktheit** (siehe unten), aber nur
  aus einem nicht dokumentierten Grund. Fix: Pfadlisten und die pbxproj-Exklusivität
  festschreiben.

## Q7 im Detail — Schreib-Disjunktheit der Workstreams

| Strang | Schreibt |
|---|---|
| S0 (seriell) | `ShipTrip/ShareShared/ShareHandoffStore.swift` (neu) · `ShipTrip/Utilities/IncomingLinkRouter.swift` *(entfällt bei F03)* |
| A — Extension | `ShipTripShare/*` (neu) · **`ShipTrip.xcodeproj/project.pbxproj`** · `fastlane/Fastfile` · `docs/SETUP.md` · `build/ExportOptions.plist` |
| B — App-Seite | `ShipTrip/Views/Share/ShareImportCoordinator.swift` · `ShipTrip/ShipTripApp.swift` · `ShipTripTests/*` |

**Ergebnis: disjunkt, inklusive `project.pbxproj`** — aber der Grund ist implizit und
gehört in den Contract: `ShipTripTests` ist eine `PBXFileSystemSynchronizedRootGroup`
**ohne** Exception-Set (`project.pbxproj:104`), neue Testdateien werden also automatisch
ins Test-Target aufgenommen und erfordern **keinen** pbxproj-Edit. Damit ist die
pbxproj allein Sache von A.

Zwei Auflagen: (1) Die `membershipExceptions` in A referenzieren
`ShareShared/ShareHandoffStore.swift`, das erst S0 anlegt — die Reihenfolge S0 → A ist
zwingend, nicht optional. (2) `ShipTripApp.swift` gehört ausschließlich B; A darf die
Datei nicht anfassen (heute nicht ausgeschlossen, da H5/H6 keine Pfade nennen).

## Was der Entwurf richtig macht (nicht wegkürzen)

- Der **Vordergrund-Scan als tragender Weg** ist die richtige Entscheidung und wird
  durch die Apple-Recherche voll bestätigt: „There's no supported way for you to launch
  your app directly from App Extensions, except Today and Widgets" — ein Design, das auf
  einem aktiven Öffnen aufbaut, wäre falsch gewesen. Alternative E ist zu Recht abgelehnt.
- **Kein SwiftData/CloudKit in der Extension** (ADR-010 Alternative A) — korrekt und
  konsistent mit ADR-009.
- **tmp + `moveItem` als Atomaritätsgarantie** ist richtig; zusammen mit der
  Namensprüfung in `pendingFiles` sieht die App nie eine halbe Datei, und `.tmp`-Reste
  werden nie eingesammelt.
- **Löschregel per normalisiertem Präfix** knüpft korrekt an
  `ShareImportCoordinator.swift:70-85` an; die Symlink-Normalisierung ist zu Recht als
  Pflicht benannt.
- **Synchrones Kopieren im Completion-Handler** ist verifiziert notwendig und im
  Contract richtig begründet.
- Die **Trennung „verifiziert / unverifiziert"** im ADR ist vorbildlich — F01 ist keine
  Verschleierung, sondern eine zu milde Einstufung.

## Backlog-Kandidaten (Nicht-Blocker, für `.planning/BACKLOG.md`)

Bewusst **nicht** von mir eingetragen — dieser Lauf ist read-only bis auf dieses
Artefakt; Übertragung durch Winston.

```
- [major] docs/architecture/contracts/share-extension-handoff.md:165-172 — public.file-url-Fallback reproduziert den in H4 abgelehnten Nachteil
- [major] docs/architecture/contracts/share-extension-handoff.md:143-148 — Prädikat-Innenform vs. Apple-Beispiel; Anhang-Auswahl per hasItemConformingToTypeIdentifier
- [major] docs/architecture/contracts/share-extension-handoff.md:113-116 — zweite anstehende Datei bleibt liegen; Re-Scan in dismiss()
- [minor] docs/architecture/contracts/share-extension-handoff.md:198-200 — L10n-Gate für neuen String Catalog in DoD aufnehmen
- [minor] docs/architecture/contracts/share-extension-handoff.md:133-134 — NSExtensionPrincipalClass festschreiben
- [minor] docs/architecture/contracts/share-extension-handoff.md:174-178 — auf loadFileRepresentation(for:openInPlace:) umstellen
- [minor] docs/architecture/contracts/share-extension-handoff.md:220-236 — ZIEL #9 (Doku/CHANGELOG) einem Schritt zuordnen
- [minor] docs/architecture/contracts/share-extension-handoff.md:90 — pendingFiles: Fehler- und Tiebreak-Verhalten spezifizieren
- [minor] docs/architecture/contracts/share-extension-handoff.md:198-200 — finalen DE/EN-Wortlaut der vier Extension-Strings festlegen
- [minor] docs/architecture/contracts/share-extension-handoff.md:220-236 — Dateipfade je Workstream + pbxproj-Exklusivität festschreiben
- [minor] fastlane/Fastfile:9-10 — APP_STORE_VERSION/APP_STORE_BUILD veraltet (1.7.0/23 vs. 1.9.0/30), Bestand
- [minor] ShipTripTests/ — keine Tests für ShareImportCoordinator.handleIncomingURL/Single-Flight (Bestandslücke)
```

## Verifikationsquellen (extern, 2026-09-10)

| Aussage | Stand | Quelle |
|---|---|---|
| `NSExtensionActivationRule` als bare predicate string, `$attachment.registeredTypeIdentifiers`, `UTI-CONFORMS-TO` | verifiziert, **Archivdoku** | ExtensibilityPG/ExtensionScenarios.html |
| `TRUEPREDICATE` ⇒ App-Store-Ablehnung | verifiziert, Archivdoku | ExtensibilityPG/ExtensionScenarios.html |
| `NSExtensionContext.open` nur Today + iMessage | verifiziert, aktuelle Referenz | documentation/foundation/nsextensioncontext/open(_:completionhandler:) |
| Kein `sharedApplication` in Extensions | verifiziert | ExtensibilityPG/ExtensionOverview.html |
| `UIBackgroundModes` in Extension-Plist ⇒ Ablehnung | verifiziert | ExtensibilityPG/ExtensionCreation.html |
| `loadFileRepresentation`: Temp-Datei wird bei Handler-Rückkehr gelöscht | verifiziert | documentation/foundation/nsitemprovider/loadfilerepresentation(fortypeidentifier:completionhandler:) |
| Exportierte UTI-Deklaration schlägt importierte | verifiziert | understanding_utis/understand_utis_declare |
| Responder-Chain-`openURL:` von Apple abgelehnt („Silly Runtime Hacks™") | Apple **DTS-Forumsaussage**, keine Referenzdoku | developer.apple.com/forums/thread/764570 |
| „No supported way to launch your app from App Extensions, except Today and Widgets" | Apple **Engineer-Forumsaussage** | developer.apple.com/forums/thread/773342 |
| Local Notification als empfohlener Ersatz | Apple **DTS-Forumsaussage** | developer.apple.com/forums/thread/764570 |
| iOS 18 „Force returning false (NO)" für `UIApplication.openURL(_:)` | **Community-Bericht**, nicht Apple | developer.apple.com/forums/thread/764570 |
| Erbt eine Extension die UTI-Deklaration der Container-App? | **nicht gefunden** | — |
| Review-Guidelines-Zitat gegen den Responder-Chain-Hack | **nicht gefunden** | — |
| Share-Extension darf App-Intent im Foreground-Modus starten? | **widerlegt** (`openAppWhenRun`: „generates an error if the app intent runs in an app extension") | documentation/appintents/appintent/openappwhenrun |

## Go/No-Go

**No-Go.** Neun Blocker, davon zwei mit Architektur-Wirkung (F01, F02/F03). Der
tragende Teil des Entwurfs bleibt bestehen — die Korrektur macht ihn **kleiner**, nicht
größer.

### Die drei wichtigsten Fixes für die nächste Runde

1. **F01 + F03 zusammen als eine Entscheidung an Andre**: Responder-Chain-Öffnen und
   `file=`-Parameter ersatzlos streichen (H1 und H5-Zeile 3 entfallen, `IncomingLink`
   bleibt zweistellig). Betrifft ZIEL #2 (Halbsatz) und ZIEL #3 (ganzes Kriterium).
   Optionaler Ersatz für die Zweistufigkeit: Local Notification aus der Extension.
   Nebeneffekt: F02 ist damit erledigt.
2. **F05–F08 als ein Paket „Contract gegen Widget-Präzedenz vervollständigen"**:
   Info.plist-Herkunft (kein `UIBackgroundModes`), `CODE_SIGN_ENTITLEMENTS`,
   `INFOPLIST_KEY_CFBundleDisplayName = ShipTrip`, vollständige pbxproj-Objektliste mit
   den Widget-Zeilenbelegen. Ohne dieses Paket baut, signiert oder heißt die Extension falsch.
3. **F04 + F09**: `shouldRemoveAfterImport` bekommt eine Test-Naht (Default-Parameter
   `inbox:`), und der Plan bekommt einen Schritt V mit Simulator-Screenshot,
   `gate-run.json` und Build-Bump — sonst sind ZIEL #4, #1 und #7 nicht nachweisbar.

Nach Einarbeitung genügt eine **Delta-Review** des Contracts (Iteration 2), kein
Vollgate.
