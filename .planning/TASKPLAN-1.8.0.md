# Taskplan 1.8.0 — nach App-Store-Freigabe 1.7.0 (23)

Stand: 2026-08-24 · Quelle: Andres Anfrage (Push-Bug, Onboarding) + `audit/audit-2026-08-14.html`
(Richtung 1–3) + Export-Abdeckungsprüfung 2026-08-24 · Status: **alle Entscheidungen getroffen — B4 = V2 Soft-Ask-Karte (Andre, 2026-08-24)**

Tier: **Big** (≥ 3 Waves, parallele Devs) → Gates #1 (Plan), pro Diff eine tiefe Prüfung,
#3 Final, #4 bei ADR, Knowledge nach jedem Quality-Go, Pre-Run-Gate vor Wave A.

---

## Wave A · Bugfix & Pflicht (vor der nächsten Einreichung) — parallel, 3 Devs

| ID | Task | needs | Aufwand | Dateien |
|----|------|-------|---------|---------|
| **A1** | **Push 3× gleichzeitig** — Notification-Identifier von `String(describing: persistentModelID)` auf stabile `Cruise.id` (UUID) umstellen; `removeReminders` immer vor `scheduleAllReminders` (auch bei Neuanlage); einmaliger Reconcile beim App-Start (Legacy-Prefix `cruise-` löschen, zukünftige Reisen idempotent neu planen); Planner-Funktion `(vorhanden, gewünscht) → (remove, add)` unit-testbar. Rot-Beweis: Test zeigt am bestehenden Stand mehrere Requests für dieselbe Reise. | — | S–M | `Services/NotificationService.swift:89,125,141`, `Views/Cruises/CruiseFormView.swift:843,848`, `CruiseListView.swift:352`, `CruiseDetailView.swift:442`, `ShipTripApp.swift`, Tests |
| **A2** | Hafen-Koordinatenverlust beim Bearbeiten (Audit 1.2 / H-A): Katalog-Lookup nur bei geändertem Name/Land; Regressionstest | — | S | `CruiseFormView.swift:1138-1166` |
| **A3** | Gemini-Disclosure im KI-Import (Audit 1.1 / S2.4): lokalisierter Satz DE/EN über „Analysieren" | — | S | `CruiseFormView.swift:1405-1465`, `Localizable.xcstrings` |
| **A4** | Pluralformen Startbildschirm (Audit 1.3): 9 Stellen, „morgen" statt „in 1 Tagen" | — | S | `CruiseListView.swift:75-77`, `CruiseHeroCardView.swift:52`, Katalog |
| **A5** | Datenschutz-Link + Support-Adresse im Info-Bereich (Audit R1) | — | S | `SettingsView.swift:178-189` |
| **A6** | **Entschieden (Andre, 2026-08-23): Altersfreigabe 4+ bleibt.** Nur Entscheidung in `release-configuration.md` dokumentieren, Blocker abhaken | — | XS | `release-configuration.md:32`, `SettingsView.swift:562-603` |
| **A7** | CHANGELOG-Schnitt auf 1.7.0 nachziehen, `[Unreleased]` neu öffnen | — | S | `CHANGELOG.md` |

**Schnitt nach Codex-Gate #1 (NO-GO → neu geschnitten, 2026-08-23):**
- Pre-Run-Gate: Einzel-Agents · Codex **Standard** · Branch `release/1.7.1`, Devs in eigenen Worktrees.
- **Dev-1 (A1)**: `NotificationService.swift`, `ShipTripTests/` (neu), Callsite-Hunks
  `CruiseFormView.swift:840-915`, `CruiseListView.swift:104-113` (Reconcile NACH `IdBackfill.run`) + `:352`,
  `CruiseDetailView.swift:442`. Keine Strings.
- **Dev-2 (A2)**: Hunk `CruiseFormView.swift:1138-1166` + Test. Keine Strings.
- **Dev-3 (A3+A4+A5)**: **alleiniger Eigentümer `Localizable.xcstrings`**; Hunk `CruiseFormView.swift:1405-1465`,
  Plural-Callsites (Liste in ZIEL.md Krit. 5), `SettingsView.swift:178-189` (+ Plural-Zeilen 432/526/679).
- Rot-Beweis: Dev committet **Test zuerst, Fix danach** (2 Commits); der serielle Test-Build-Agent führt
  Commit 1 (rot) und HEAD (grün) aus. Devs bauen nicht selbst (Build-Token).
- A6/A7 (Knowledge) **nach** Quality-Go, nicht parallel. A6-Ziel: `marketing/release-1.7.0/app-store-connect/release-configuration.md`.
- Reconcile-Contract: läuft bei **jedem** App-Start (idempotent, kein Migrationsflag); gewünschte Menge aus aktuellen
  Settings × Permission × Fire-Date > now; Add-Fehler werden geloggt (os.Logger), nicht verschluckt.
- Backlog (Go-Live-Triage „nicht blockierend"): Reconcile bei Settings-Toggle/Offset-Änderung (`SettingsView.swift:641-688`);
  Plural `CruiseFormView.swift:374`.

## Wave B · Onboarding (neu bauen — heute nicht vorhanden)

Befund: kein Welcome-Flow, kein `@AppStorage`-First-Launch-Flag, kein TipKit, kein StoreKit.
Erststart landet in leerer Liste („Tippe auf +"). Einziges gutes Muster: `ReminderPermissionSheet`
(`CruiseFormView.swift:946-985`) als Permission-Priming. Demo-Daten nur `#if DEBUG`.

| ID | Task | needs | Aufwand |
|----|------|-------|---------|
| **B1** | Design-Phase light (designer): 3 Karten — Wertversprechen (Reisetagebuch), Kern-Features (Karte/Fotos/Erinnerungen), Start-CTA („Erste Reise anlegen" / „Beispielreise ansehen"). Visuelles Gate #5 vor Andre-Return | — | M |
| **B2** | Implementierung: `OnboardingView` + `@AppStorage("hasCompletedOnboarding")`, Einstieg in `ShipTripApp`/`MainTabView`, DE/EN, überspringbar, in Settings erneut aufrufbar | B1 | M |
| **B3** | Demo-Reise für Release freischalten (Audit B1.2): `DemoDataService` aus `#if DEBUG` lösen, `isDemo`-Tag, ein-Klick-Entfernen; Demo-Bilder (F18) bewusst entscheiden | B1 | M |
| **B4** | **Entschieden (Andre, 2026-08-24): V2 Soft-Ask-Karte im Onboarding.** Geht in B1 (Design der Karte) + B2 (Implementierung) auf: System-Dialog erst nach aktiver Zustimmung auf der Karte, "Später" ohne Systemdialog; kontextueller Ask beim ersten Speichern bleibt Fallback. Kalender bleibt bei Toggle | B1, B2 | S |
| **B5** | UI-Test Onboarding-Durchlauf + Skip | B2 | S |

## Wave C · Wiederholbar ausliefern (Audit Richtung 2) — parallel zu Wave B möglich

| ID | Task | needs | Aufwand |
|----|------|-------|---------|
| **C1** | Geteiltes Xcode-Schema + `.xctestplan` einchecken; Screenshot-Pfad per ENV + XCTSkip (F17, 9 UI-Tests) | — | S |
| **C2** | `Gemfile` mit gepinnter Fastlane; schlanke GitHub-Actions-CI (Build + Unit-Tests); Kalenderrechte im Testlauf via `simctl privacy grant` | C1 | M |
| **C3** | Export/Backup vervollständigen (Audit 2.2): Deal, eigene Reedereien, eigene Schiffe, Ausblendungen ergänzen — alle 4 sind SwiftData-Modelle im selben Store; `CustomShip.lineOptionID` (`"custom:<UUID>"`) beim Import stabil übernehmen, sonst verwaisen eigene Schiffe. Im selben Diff die Roundtrip-Lücken (Prüfung 2026-08-24): halbe Sterne (`ExportImportService.swift:27,232` — DTO ist `Int`, trunkiert 4,5→4), Foto-Identität (`Photo.id` exportieren, Import idempotent statt Dubletten), Seetag-Land/-Koordinaten nicht nullen (`:195-197`), Demo-Reisen beim Export filtern (`SettingsView.swift:870`), Export-/Import-Footer-Texte anpassen (`SettingsView.swift:779,795`); rückwärtskompatibel | — | M–L |
| **C4** | Export streamen, vom Main-Thread lösen, Importgrenze 550 MB abstimmen (Audit 2.3 / H-B) | C3 | M |
| **C5** | Lokalisierungs-Gate als Vor-Release-Skript (36 fehlende EN-Strings nachziehen; 4 hart-deutsche Push-Texte) | C2 | S–M |
| **C6** | Git-Historie entlasten (Videos auslagern), `.gitignore`-Lücken | — | S |
| **C7** | Doku-Nachzug: MODELS (8 Modelle), ARCHITECTURE „Datenfluss", CONTRIBUTING (Swift Testing) | — | S |
| **C8** | **Bug (Live-App, Andre 2026-08-24):** Häfen-Zähler inkonsistent — Home-Stats-Streifen zeigt 57, Bilanz 43. Ursache: Home zählt Anlaufpunkte inkl. Mehrfachbesuche (`totalPortStops`, `Cruise.swift:174-176`), Bilanz eindeutige Hafennamen ohne Seetage (`uniquePorts`, `StatsView.swift:235-237`) — gleiche Beschriftung „Häfen" für zwei Metriken. Semantik vereinheitlichen oder Beschriftung differenzieren (z. B. „Anläufe" vs. „Häfen"); Regressionstest | — | S |

## Wave D · Vom Formular zum Reisetagebuch (Audit Richtung 3) — Zielbild 1.8/2.0

| ID | Task | needs | Aufwand |
|----|------|-------|---------|
| **D1** | **Sofort lohnend:** ISO-Ländercode in `PortSuggestion` + `Locale.localizedString(forRegionCode:)` (Audit 3.2 / H-C); ADR (Gate #4) | C2 empfohlen | M |
| **D2** | CruiseFormView aufspalten: 4 eingebettete Dialoge in eigene Dateien; 200-Zeilen-Duplikat „Hafen-Momente" zusammenführen (Audit 3.1 Vorstufe, P5) | C1 | M |
| **D3** | Journal-Kern (ADR-003): Erinnerung als Einstieg, Eckdaten als Zweitschritt | D2, design-phase | XL |
| **D4** | **Entschieden (Andre, 2026-08-23): Einmalkauf festschreiben.** ADR-004 als Entscheidung „kein Freemium, Einmalkauf" schreiben, Reservierung auflösen, Produktrichtung in CLAUDE.md/docs angleichen (Audit 3.3) | — | S |

## Weitere Medium-Befunde (Backlog, kein Wave-Slot)

- ThumbnailBackfill `while true` Endlosschleifen-Risiko (`Utilities/ThumbnailBackfill.swift:27-58`) — erster Test der Datei
- Erinnerungs-Einstellungen wirken nur auf künftige Saves (wird durch A1-Reconcile mit erledigt → prüfen)
- 84 Reederei-Cover ohne Herkunftsnachweis unter MIT; Copyright-Widerspruch
- UI-Tests hängen an deutschen Texten ohne erzwungene App-Sprache
- Kalender-Hintergrund-Sync schluckt Fehler, läuft synchron auf Main
- Hartkodiertes deutsches Datumsformat in Detailansicht
- Export-Roundtrip-Rest (Prüfung 2026-08-24; halbe Sterne jetzt in C3): `Expense.createdAt` wird exportiert,
  aber beim Import nicht zurückgeschrieben (`ExportImportService.swift:214` vs. `:465-483`);
  `createdAt`/`updatedAt` von Cruise/Port/Photo in keinem DTO; Uhrzeit-Anteil von Start-/Enddatum
  geht verloren (tagesgenaues Format, `:79-82`); Original-`sortOrder` nur als Index rekonstruiert
- Ausflugsnamen mit „, " brechen beim Persistenz-Split (`Port.swift:55-61`)
- Reiner JSON-Export ohne Hafen-Fotos (`ExportImportService.swift:182`); deutsche Alt-Kategorien
  bei Ausgaben fallen im Import auf `.other` (`:512-521`)
- Bewusst außerhalb des Backups (bei C3 im UI/Doku erwähnen, nicht exportieren):
  Erinnerungs- + Kalender-Sync-Einstellungen und Theme (UserDefaults), Gemini-API-Key (Keychain)
- DE-Store-Text verspricht nicht existente Suche

## Reihenfolge-Empfehlung

1. **Wave A** sofort (Tage) — enthält den Push-Bug und alle P0/P1-Punkte; Release-Kandidat 1.7.1 oder 1.8.0.
2. **Wave B + C** parallel (1–2 Wochen) — Onboarding ist Produkt, C1/C2 ist Unterbau.
3. **D1** direkt nach C2; **D2** danach; D3/D4 erst nach Andres Entscheidungen.

## Release-Schnitt (entschieden 2026-08-23)

- **1.7.1** = Wave A komplett (Push-Bug + P0/P1) — jetzt.
- **1.8.0** = Wave B (Onboarding) + Wave C; D1/D2 nach Kapazität.

B4 entschieden (2026-08-24): **V2 Soft-Ask-Karte im Onboarding** — in B1/B2 aufgegangen.

## Schnitt Run 1.8.0 — Wave B + C (v2 nach Codex-Gate #1 NO-GO, 2026-08-24)

Pre-Run-Gate: **Einzel-Agents** (Agent-Teams-Env nicht gesetzt) · Codex **Standard** ·
Branch `release/1.8.0` ab main, Devs in eigenen Worktrees, Merges seriell.
Ziel-Artefakt: `.planning/ZIEL.md` (9 Kriterien). Gate #1 lief 2026-08-24: NO-GO,
alle 11 Findings eingearbeitet (siehe Auflagen unten) — kein Gate-Re-Run,
Auflagen gehen wörtlich in die Spawn-Prompts (Lehre 1.7.1).

Codex-Job-Budget (Big, 6): #1 Plan (gelaufen) · #2 C3 · #2 C4 · #2 C5 ·
#3 Final (2 Scopes) = 6 — **keine Reserve**; braucht es #4, Rückfrage an Andre.

**Tiefe Prüfung pro Diff:** C3, C4, C5 → Codex #2 (Datenverlust / Concurrency /
deterministische Katalog-Extraktion) · B2, B3, B5, C1, C2, C8 → Quality ·
C6, C7 → Winston selbst (C6-Auflage: löscht nichts, kein History-Rewrite ohne Andre-Ok).

**String-Katalog-Regel (verschärft, Finding 5+6):** Kein Dev editiert
`Localizable.xcstrings`. Neue UI-Strings via `String(localized:)`; jeder Dev listet
seine neuen Keys im Return. Das App-Target hat `SWIFT_EMIT_LOC_STRINGS = YES` —
deshalb bauen **alle** Test-Build-Agents außer C5 mit `SWIFT_EMIT_LOC_STRINGS=NO`
(xcodebuild-Override) **und** prüfen vor Return hart „kein Diff an
`Localizable.xcstrings`". **C5 ist der eine Katalog-Task**: führt die Extraktion
einmal im konsolidierten Stand aus, trägt DE/EN für alle neuen Keys + 36
Alt-EN-Lücken + 4 Push-Texte nach. Bis C5 gemerged ist, fällt EN auf deutsche
Keys zurück → DE/EN-Abnahme von B2/B5 (ZIEL Krit. 1) erst **nach** C5; vorher
gilt für Onboarding-EN nur „strukturell validiert".

### Welle 1 (parallel)

| Task | Agent | Schreib-Scope |
|------|-------|---------------|
| B1 (+B4-Karte) | designer (design-phase light, Gate #5) | `docs/design/`, `prototype-onboarding/` — kein App-Code |
| C1 | developer | Xcode-Schemes (`xcshareddata`), `.xctestplan`, `ShipTripUITests/HauptansichtScreenshotTests.swift` |
| C3 | developer | `ExportImportService.swift`, `SettingsView.swift` (nur Export-Hunks), `ShipTripTests/Export*` |
| C8 | developer | `Cruise.swift`, `StatsView.swift`, `CruiseStatsStripView.swift`, `ShipTripTests/CruiseAggregateTests.swift` (Finding 7: NICHT `CruiseListView.swift`) |
| C6 | developer (lite) | `.gitignore`; Video-Bestand nur Bericht — nichts löschen, History-Rewrite NUR nach Andre-Ok |
| C7 | knowledge | **exakt drei Dateien** (verifiziert 2026-08-24): `docs/MODELS.md`, `docs/ARCHITECTURE.md`, `docs/CONTRIBUTING.md`; `docs/design/` gehört B1 (Finding 8) |

**C3-Auflagen (Findings 1+4, gehen wörtlich in den Spawn-Prompt):**
- Demo-Ausschluss liegt **im Export-Service/Snapshot-Builder**, nicht am
  SettingsView-Aufruf — und gilt für **Cruises UND Deals** (B3 erzeugt auch
  `isDemo`-Deals, `DemoDataService.swift:228`); Test deckt beides.
- Dual-Decoder: 1.8-Envelope **plus** Fallback auf das 1.7-Top-Level
  `[ExportCruise]`-Array; `decodeIfPresent`/Defaults für alle neuen Collections;
  Legacy-Foto-Referenzen ohne `Photo.id` (heute `[String]`,
  `ExportImportService.swift:291`) bleiben importierbar; echter 1.7-JSON- **und**
  ZIP-Fixture-Test im Repo.

### Welle 2 (Start je Task, sobald `needs` vorliegen)

| Task | needs | Schreib-Scope |
|------|-------|---------------|
| B2 (inkl. B4-Soft-Ask) | B1-Spec (Gate-#5-pass) | `Views/Onboarding/` (neu), `ShipTripApp.swift`, `SettingsView.swift` (Eintrag „Intro erneut zeigen") |
| B3 | C3-Merge | `DemoDataService.swift`, `SettingsView.swift` (Demo-Hunks), Assets-Entscheidung F18 |
| C2 | C1-Merge | `Gemfile`, `.github/workflows/`, Fastlane |
| C4 | C3-Merge | `ExportImportService.swift` (Streaming/off-main) |

**B2-Invariante (Finding 3, wörtlich in den Spawn-Prompt):** Onboarding
ersetzt den `MainTabView` NICHT bedingt — es wird als `fullScreenCover`/Overlay
über dem **montierten** Hauptbaum präsentiert. `IdBackfill.run` →
`NotificationReconciler.run` hängen an `CruiseListView.task`
(`CruiseListView.swift:111`) und laufen in bestehender Reihenfolge, unabhängig
davon, ob das Onboarding sichtbar ist.

**Merge-Reihenfolge B3 vor B2 (Finding 2):** Beide fassen `SettingsView.swift`
an (disjunkte Hunks). B3 merged zuerst; B2 rebased vor seinem Merge auf den
B3-Stand. Naht: B2 ruft bestehende `DemoDataService`-API — B3 ändert nur
Verfügbarkeit (`#if DEBUG` raus), nie die Signatur.

**Release-Kante (Finding 1, hart):** Kein Release/TestFlight-Build mit
B3-Demo-Freischaltung ohne gemergten C3-Demo-Export-Filter.

### Welle 3

| Task | needs | Scope |
|------|-------|-------|
| B5 | B2-Merge | `ShipTripUITests/Onboarding*` (Durchlauf + Skip; DE/EN-Abnahme erst nach C5) |

**Produktentscheid Skip (B2, festgehalten 2026-08-24):** „Überspringen" verlässt
den Flow nicht, sondern springt direkt auf Karte 4 (Startentscheidung) — der
Nutzer wählt immer aktiv zwischen „Erste Reise anlegen" und „Beispielreise
ansehen"; Ausstieg kostet damit zwei Taps (begründet in `OnboardingModel.swift`).

**Produktentscheide Gate #3 Scope A (Winston, 2026-08-24 — von Andre
übersteuerbar):** (1) Onboarding erscheint NUR bei frischer Installation;
1.7.x-Bestandsinstallationen (Store enthält Nutzerdaten) migrieren das Flag
still und sehen kein Cover — die Karte-4-Copy („erste Reise") trägt sonst
nicht. (2) Soft-Ask-CTA „Erinnerungen aktivieren" = iOS-Berechtigung + sofortiger
`NotificationReconciler.run`; die App-Toggles in den Einstellungen bleiben
unangetastet. (3) Bei aktivem In-Memory-Fallback hat die Datenverlust-Warnung
Vorrang, das Onboarding wird zurückgehalten (Flag bleibt false).
| C5 | **alle App-Code-Merges** (B2, B3, C3, C4, C8) + C2-Merge | L10n-Gate-Skript **eingebunden in den CI-Workflow aus C2** (Finding 10), `Localizable.xcstrings` (alleiniger Eigentümer, Extraktion einmalig im konsolidierten Stand) |

### Serielle Kanten (Begründung je Kante)

- B1→B2: Implementierung braucht die durch Gate #5 bestätigte Design-Spec.
- B2→B5: UI-Test braucht die realen Accessibility-Identifier der fertigen Views.
- C1→C2: CI-Workflow referenziert geteiltes Schema + Testplan als Artefakt.
- C3→C4: Streaming-Refactor auf denselben Dateien — parallel wäre Merge-Rework.
- C3→B3: Demo-Export-Filter muss vor der Demo-Release-Freischaltung existieren (Blocker-Finding 1).
- B3-Merge→B2-Merge: gemeinsame Datei `SettingsView.swift` (Finding 2).
- (B2,B3,C3,C4,C8)-Merges + C2→C5: zentraler Katalog-Task extrahiert erst im konsolidierten Stand (Findings 5+9); CI-Einbindung braucht C2.
- Quality-Testrunde nach jeder Welle; Test-Builds strikt seriell (Build-Token), alle außer C5 mit `SWIFT_EMIT_LOC_STRINGS=NO` + Katalog-Diff-Check.

### Abschluss

Gate #3 scope-weise (App-Code konsolidiert · Infra/CI) → Knowledge incremental pro
Quality-Go + Changelog → Gate #6 → Run-Bericht. Kein TestFlight-Upload in diesem
Run ohne Andres Zuruf.
