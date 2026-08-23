# Taskplan 1.8.0 — nach App-Store-Freigabe 1.7.0 (23)

Stand: 2026-08-23 · Quelle: Andres Anfrage (Push-Bug, Onboarding) + `audit/audit-2026-08-14.html`
(Richtung 1–3) · Status: **Entscheidungen 1/2/4 getroffen (2026-08-23), B4 offen**

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
| **B4** | Permission-Priming: Erinnerungen als Karte im Onboarding **oder** beim ersten Reise-Speichern belassen (Empfehlung: belassen, kontextuell ist besser); Kalender bleibt bei Toggle | B2 | S |
| **B5** | UI-Test Onboarding-Durchlauf + Skip | B2 | S |

## Wave C · Wiederholbar ausliefern (Audit Richtung 2) — parallel zu Wave B möglich

| ID | Task | needs | Aufwand |
|----|------|-------|---------|
| **C1** | Geteiltes Xcode-Schema + `.xctestplan` einchecken; Screenshot-Pfad per ENV + XCTSkip (F17, 9 UI-Tests) | — | S |
| **C2** | `Gemfile` mit gepinnter Fastlane; schlanke GitHub-Actions-CI (Build + Unit-Tests); Kalenderrechte im Testlauf via `simctl privacy grant` | C1 | M |
| **C3** | Export um Deal, eigene Reedereien, eigene Schiffe, Ausblendungen ergänzen (Audit 2.2); rückwärtskompatibel | — | M |
| **C4** | Export streamen, vom Main-Thread lösen, Importgrenze 550 MB abstimmen (Audit 2.3 / H-B) | C3 | M |
| **C5** | Lokalisierungs-Gate als Vor-Release-Skript (36 fehlende EN-Strings nachziehen; 4 hart-deutsche Push-Texte) | C2 | S–M |
| **C6** | Git-Historie entlasten (Videos auslagern), `.gitignore`-Lücken | — | S |
| **C7** | Doku-Nachzug: MODELS (8 Modelle), ARCHITECTURE „Datenfluss", CONTRIBUTING (Swift Testing) | — | S |

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
- Export verliert halbe Sterne + einen Zeitstempel
- DE-Store-Text verspricht nicht existente Suche

## Reihenfolge-Empfehlung

1. **Wave A** sofort (Tage) — enthält den Push-Bug und alle P0/P1-Punkte; Release-Kandidat 1.7.1 oder 1.8.0.
2. **Wave B + C** parallel (1–2 Wochen) — Onboarding ist Produkt, C1/C2 ist Unterbau.
3. **D1** direkt nach C2; **D2** danach; D3/D4 erst nach Andres Entscheidungen.

## Release-Schnitt (entschieden 2026-08-23)

- **1.7.1** = Wave A komplett (Push-Bug + P0/P1) — jetzt.
- **1.8.0** = Wave B (Onboarding) + Wave C; D1/D2 nach Kapazität.

Offen: **B4** — Erinnerungs-Berechtigung: V1 kontextuell lassen (Empfehlung) ·
V2 Soft-Ask-Karte im Onboarding · V3 Hard-Ask beim Start (abgelehnt).
