# ADR-010: Share-Extension reicht `.shiptrip`-Dateien per App-Group-Übergabeordner an die App weiter

**Status:** Proposed (Iteration 2 nach Gate #4, 2026-09-10)
**Datum:** 2026-09-10
**Autor:** Architect (Winston-Run „Share-Extension 1.9.0"), auf Basis von Andres
Entscheid „Minimal-Variante" (Extension reicht nur weiter, keine Import-Vorschau)
**Querverweis:** ADR-007 (Kreuzfahrt teilen, Import-Pfad), ADR-009 (App Group
`group.com.andre.ShipTrip`, Extension-Target-Muster)

---

## Kontext

Seit Build 30 lässt sich eine Reise als `.shiptrip`-Datei teilen (ADR-007). Der
Empfangsweg funktioniert aber nur über die Dateien-App: Ein iMessage-Anhang
bietet lediglich „Weiterleiten", und das iOS-Teilen-Sheet listet ShipTrip nicht
als Ziel — die App meldet zwar Dokumenttyp und URL-Schema an, aber keine
Extension vom Typ `com.apple.share-services` (dokumentierte Lücke in
`docs/features/kreuzfahrt-teilen.md`). Andres Originalbefund: „wenn ich
draufklicke, tut sich gar nichts."

Randbedingungen:

- Der Import-Pfad ist fertig und gehärtet: `IncomingLinkRouter` →
  `ShareImportCoordinator` → `SharePreflight` (Stufe A, off-main) →
  `importFromJSONData` (Stufe B, MainActor). Er hängt an `onOpenURL` in
  `ShipTripApp` und löscht nach dem Import nur App-eigene Kopien
  (`shouldRemoveAfterImport`: `Documents/Inbox` und `tmp`).
- Eine App-Extension ist ein eigener Prozess mit eigenem Container. Sie hat
  **keinen** Zugriff auf `UIApplication.shared` (Apple, App Extension
  Programming Guide, verifiziert). Der SwiftData-/CloudKit-Store der App darf
  dort nicht geöffnet werden (Constraint; dieselbe Begründung wie ADR-009).
- Es gibt **keinen unterstützten Weg**, aus einer Share-Extension die
  Container-App zu öffnen: `NSExtensionContext.open(_:)` ist in iOS nur für
  Today- und iMessage-Extensions zugesichert (Apple-Referenz, verifiziert);
  der Responder-Chain-Umweg über `openURL:` wird von Apple DTS ausdrücklich
  abgelehnt („Don't try to bypass such restrictions using Silly Runtime
  Hacks™", Forums 764570) und ist laut Community-Bericht auf iOS 18 wirkungslos.
  Apple DTS nennt als unterstützten Weg, Aufmerksamkeit zu erzeugen: „posting a
  local notification".
- Die App Group `group.com.andre.ShipTrip` existiert bereits (ADR-009), samt
  Signing-Prozedur mit manuellen Profilen je Target (`docs/SETUP.md`).
- Andre will die Minimal-Variante: Die Extension zeigt höchstens einen kurzen
  Status, keine Reise-Vorschau — aber der Weg muss real funktionieren.

## Entscheidung

Wir bauen eine Share-Extension `ShipTripShare` (Bundle
`com.andre.ShipTrip.Share`, Extension-Point `com.apple.share-services`), die
genau eine Datei vom Typ `com.andre.shiptrip.cruise` annimmt, sie in den
Übergabeordner `ShareInbox/` des App-Group-Containers kopiert und die Arbeit
dann der App überlässt. Die Extension enthält keinen Import-Code, keinen
SwiftData-Container, keine Reise-Vorschau und **keinen Versuch, die App zu
öffnen**.

**Ein einziger Import-Trigger:** Bei jedem Wechsel in den Vordergrund
(`scenePhase == .active`, zusätzlich einmalig beim Szenenaufbau und nach dem
Schließen des Ergebnis-Sheets) prüft `ShareImportCoordinator` den
Übergabeordner und importiert die älteste anstehende Datei über den
bestehenden Pfad. Dieser Weg braucht keine API, die einer Extension verwehrt
ist — er funktioniert, sobald der Nutzer ShipTrip öffnet.

**Abkürzung für den Nutzer (best-effort):** Nach erfolgreicher Ablage plant die
Extension eine lokale Mitteilung („Reise bereit zum Import — antippen öffnet
ShipTrip", Zustellung sofort). Antippen bringt ShipTrip in den Vordergrund, der
Scan importiert. Die Mitteilung nutzt die Benachrichtigungs-Berechtigung der
App; fehlt sie, unterbleibt die Mitteilung still und der Abschlusstext der
Extension bleibt der einzige Hinweis. Verifikationsstand: `UNUserNotificationCenter`
ist laut Apple-Referenz „for your app or app extension" vorgesehen
(verifiziert); ob eine **Share**-Extension die Berechtigung der Container-App
teilt, ist **unverifiziert** (Apple DTS: „I suspect that it'll vary based on
the extension type"). Rückfallposition, falls der Simulator-Nachweis (Contract,
Schritt V) keine Mitteilung liefert: Mitteilungs-Code entfernen, nur der
Abschlusstext bleibt — das Design ändert sich dadurch nicht.

Der Übergabeordner ist eine dritte App-eigene Quelle für
`shouldRemoveAfterImport`; nach dem Import (Erfolg wie Fehler) wird die Datei
gelöscht. `shiptrip://import` und der Router bleiben **unverändert** (kein
`file=`-Parameter, kein neuer Router-Fall). Verträge, Prädikat, Plist-Schlüssel,
pbxproj-Objektliste und Signing stehen in
`docs/architecture/contracts/share-extension-handoff.md`.

## Konsequenzen

**Positiv**

- ShipTrip erscheint im Teilen-Sheet (Nachrichten, Dateien, Mail, WhatsApp);
  der iMessage-Weg „Anhang → Teilen → ShipTrip" wird real.
- Import, Preflight, Limits, Dedup und Konflikt-Hinweis bleiben an genau einer
  Stelle (ADR-007) — die Extension dupliziert nichts davon.
- Der gesamte Weg hängt an dokumentierten, stabilen Bausteinen (App-Group-
  Container, `scenePhase`, bestehender Coordinator, `UNUserNotificationCenter`)
  und ist ohne Gerät unit-testbar (Namensprüfung, Ordner-Scan, Löschregel —
  alle mit injizierbarem Ordner).
- Keine Angriffsfläche über URLs: Die App liest nur Dateien, die sie selbst im
  Übergabeordner findet; kein externer Parameter wählt jemals einen Pfad.
- Kein zweiter Store, kein CloudKit in der Extension (Constraint erfüllt,
  Muster ADR-009).

**Negativ / bewusst in Kauf genommen**

- Ohne Berechtigung für Mitteilungen ist die Übergabe zweistufig: Teilen, dann
  App selbst öffnen. Das ist der Preis dafür, dass der Weg nie an einer
  undokumentierten API hängt.
- Dritter signierter Target: neue App-ID im Developer-Portal, drittes
  Distribution-Profil, dritte Zeile in `fetch_profile`, `SETUP.md`-Archiv-
  Befehl und `build/ExportOptions.plist` (Muster Widget). Die pbxproj-
  Integration umfasst rund fünfzehn Objekte (Contract H6 listet sie).
- Eine Datei liegt zwischen Teilen und Import unverschlüsselt im
  App-Group-Container (wie zuvor in `Documents/Inbox`). Die 24-Stunden-
  Aufräumregel der Extension begrenzt Liegenbleiber.
- Zwei Foundation-only-Dateien werden per `membershipExceptions` in ein
  weiteres Target gezogen (`ShareHandoffStore`, `ShareArchiveLimits`); neue
  Abhängigkeiten dort brechen den Extension-Build (bekannte Regel aus
  `WidgetShared/`).

**Neutral**

- Ob Nachrichten das Anhangs-Item mit dem exportierten UTI registriert (und
  das Aktivierungs-Prädikat damit greift), ist nur am Gerät verifizierbar —
  ein Simulator hat kein iMessage. Der Contract benennt Diagnose-Reihenfolge
  und Rückfallposition (H4).
- Der `linkHint`-Fall von `shiptrip://import` bleibt unverändert.

## Alternativen

**A: Import-Kern in der Extension (Datei dort preflighten und importieren).**
Abgelehnt: erfordert den SwiftData-/CloudKit-Store im Extension-Prozess
(Constraint, ADR-009-Begründung) oder einen zweiten Store mit anschließendem
Merge — beides ein Vielfaches an Risiko für ein Weiterreichen. Auch ohne Store
wäre die Vorschau ein zweiter Parser-Pfad (ADR-007, Alternative A).

**B: Übergabe per App Group, Vordergrund-Scan, lokale Mitteilung (gewählt).**
Extension kopiert, App importiert. Kleinste Änderung am Bestand; der Import
bleibt an einem Ort; kein Baustein außerhalb der Apple-Dokumentation.

**C: Nur Dokumenttyp/„Öffnen in" (Status quo, kein Extension-Target).**
Abgelehnt: löst den Befund nicht — Nachrichten bietet für den Anhang kein
„Öffnen in ShipTrip", und das Teilen-Sheet zeigt ohne Share-Extension nur
Ziele mit `com.apple.share-services`. Bleibt als unterstützter Nebenweg
(Dateien-App) bestehen.

**D: Action-Extension statt Share-Extension.**
Abgelehnt: gleiche API-Einschränkungen beim Öffnen der App, aber schlechtere
Sichtbarkeit (zweite Reihe im Sheet, ohne App-Icon-Prominenz); kein Vorteil.

**E: App-Öffnen per Responder-Chain-`openURL:` plus `shiptrip://import?file=`.**
Abgelehnt (Iteration 1 hatte dies als Best-effort vorgesehen): von Apple DTS
ausdrücklich abgelehnt, auf iOS 18 laut Bericht wirkungslos, App-Store-Risiko —
und der `file=`-Parameter wäre die einzige Angriffsfläche des Designs gewesen
(Review F02), ohne im Erfolgsfall etwas zu leisten, was der Vordergrund-Scan
nicht ohnehin tut (F03).

**F: App Intent mit `openAppWhenRun` aus der Extension.**
Abgelehnt: Apple-Referenz zu `openAppWhenRun`: „generates an error if the app
intent runs in an app extension" (verifiziert im Review).

## Änderungen Iteration 2 (Gate #4, Review 2026-09-10)

Alle neun Blocker des Reviews sind eingearbeitet; Nicht-Blocker sind im
Contract entweder übernommen oder als Backlog markiert.

| Finding | Änderung |
|---|---|
| F01 | Responder-Chain-Öffnen komplett gestrichen (Entscheidung, Alternative E). Ersatz: lokale Mitteilung nach Ablage, best-effort, still ohne Berechtigung. |
| F02 | Entfällt mit F03. Zusätzlich schreibt H2 die Scan-Regel fest: nur reguläre Dateien, keine Symlinks, direkt im Ordner, Name nach Schema. |
| F03 | `file=`-Parameter, Router-Case `.pendingShareFile` und Vertrag H1 gestrichen; `IncomingLink` bleibt zweistellig; H1 = „keine Änderung". |
| F04 | `shouldRemoveAfterImport(_:inbox:)` und `importPendingHandoffIfIdle(modelContext:inbox:)` mit Default-Parameter — Unit-Tests laufen mit Wegwerf-Ordner ohne App-Group-Container (H3). |
| F05 | H4 listet die Extension-Plist-Schlüssel explizit; Herkunft ist `ShipTripWidget/Info.plist`, nicht die App-Plist; `UIBackgroundModes`, `CFBundleDocumentTypes`, `CFBundleURLTypes` ausdrücklich verboten. |
| F06 | `INFOPLIST_KEY_CFBundleDisplayName = ShipTrip` in H6, Prüfpunkt im Simulator-Nachweis. |
| F07 | `CODE_SIGN_ENTITLEMENTS` und die vollständige Build-Setting-Liste (Klon des Widget-Targets) in H6. |
| F08 | Vollständige pbxproj-Objektliste mit Zeilenbelegen des Widget-Targets in H6 (Kopiervorlage). |
| F09 | Schritt V (Nachweis) mit Simulator-Screenshot, E2E, `gate-run.json`, L10n-Gate, Build-Bump 31, Doku (ZIEL #1, #7, #8, #9) — Owner benannt. |

## Referenzen

- `docs/architecture/contracts/share-extension-handoff.md` — Verträge H1–H6,
  Parallelisierungsplan, Schritt V
- `.planning/quality-review-share-extension-gate4-iter1.md` (Hauptrepo) —
  Review-Findings F01–F21
- `docs/adr/ADR-007-kreuzfahrt-teilen.md`,
  `docs/architecture/contracts/share-cruise-contracts.md` (C3, C6, C10)
- `docs/adr/ADR-009-widget-app-group-snapshot.md` — App Group, Extension-Muster
- `docs/features/kreuzfahrt-teilen.md` — Abschnitt „Keine Share-Extension"
- `docs/SETUP.md` — „Archiv-Signing seit 1.9.0 (App Groups)"
- `ShipTrip/Views/Share/ShareImportCoordinator.swift`,
  `ShipTrip/Utilities/IncomingLinkRouter.swift`, `ShipTrip/ShipTripApp.swift`,
  `ShipTrip/Services/ExportImportService+ShareImport.swift`,
  `ShipTrip/Services/ShareArchiveLimits.swift`,
  `ShipTrip.xcodeproj/project.pbxproj` (Widget-Target als Vorlage)
- Apple (verifiziert 2026-09-10): App Extension Programming Guide —
  ExtensionOverview (kein `sharedApplication`, `NS_EXTENSION_UNAVAILABLE`),
  ExtensionScenarios (Prädikat-String, `UTI-CONFORMS-TO`, TRUEPREDICATE-
  Ablehnung; **Archivdoku**), ExtensionCreation (`UIBackgroundModes` in
  Extension ⇒ Ablehnung); Foundation `NSExtensionContext.open(_:completionHandler:)`
  (Today + iMessage); `NSItemProvider.loadFileRepresentation(forTypeIdentifier:)`
  (Temp-Datei wird nach Rückkehr des Handlers gelöscht) und
  `loadFileRepresentation(for:openInPlace:completionHandler:)` (iOS 16+);
  UserNotifications `UNUserNotificationCenter` („for your app or app extension"),
  `UNNotificationRequest.init(identifier:content:trigger:)` (`trigger: nil` ⇒
  sofortige Zustellung); UTI-Deklaration („exported declaration takes precedence").
- Apple DTS/Engineer, Developer Forums 764570 und 773342 (Forumsaussagen, keine
  Referenzdoku): kein unterstützter Weg zum App-Öffnen aus Extensions außer
  Today/Widgets; Empfehlung lokale Mitteilung; Unsicherheit je Extension-Typ.
- Unverifiziert (Modellwissen): Berechtigungs-Teilung der Mitteilung zwischen
  Share-Extension und Container-App; Registrierung des exportierten UTI an
  Nachrichten-Anhängen; Notwendigkeit von `UTImportedTypeDeclarations` in der
  Extension; Rückgabe von `containerURL(forSecurityApplicationGroupIdentifier:)`
  (im Projekt durch `WidgetSnapshotStore` belegt).

## Revisionen

- 2026-09-10: Erstfassung (Proposed).
- 2026-09-10: Iteration 2 nach Gate #4 — Responder-Chain und `file=` gestrichen,
  lokale Mitteilung als Ersatz, Test-Nähte, vollständige Target-Integration
  (siehe „Änderungen Iteration 2"). Status weiterhin Proposed.
