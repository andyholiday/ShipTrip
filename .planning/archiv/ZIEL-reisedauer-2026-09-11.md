# ZIEL — Release 1.7.1: Push-Duplikate beseitigt, Einreichungs-Pflichtpunkte geschlossen

**Run:** 2026-08-23 · Wave A aus `.planning/TASKPLAN-1.8.0.md` · Tier: **Big**
(parallele Devs) · Ausführung: Einzel-Agents · Codex: **Standard** (Gates #1–#3)

## Ziel (1 Satz)

Release 1.7.1 liefert genau eine Erinnerung pro Reise und Zeitpunkt (auch auf
Geräten, die heute schon Duplikate gespeichert haben) und schließt die
Audit-Pflichtpunkte P0/P1 (Koordinatenverlust, Gemini-Disclosure, Pluralformen,
Datenschutz/Support-Link, Altersfreigabe-Doku, CHANGELOG).

## Success-Kriterien (messbar)

1. **Eine Erinnerung pro Reise und Art.** Notification-Identifier werden aus
   `Cruise.id` (UUID) gebildet, nie aus `persistentModelID`. Mehrfaches
   Speichern/Bearbeiten derselben Reise erzeugt keine zusätzlichen Pending
   Requests. Repro-Test vor dem Fix nachweislich rot, danach grün.
2. **Altlasten werden bereinigt.** Beim App-Start werden Pending Requests mit
   dem Legacy-Prefix `cruise-` entfernt und für alle zukünftigen Reisen gemäß
   den **aktuellen** Erinnerungs-Einstellungen (Tage-vorher, Abreise-Toggle,
   Erinnerungen aktiv/inaktiv, Permission erteilt) idempotent neu geplant; die
   Reconcile-Logik ist als reine Funktion unit-getestet (ohne
   UNUserNotificationCenter).
3. **Koordinaten überleben das Bearbeiten.** Im Hafen-Bearbeiten-Sheet
   (`TempPortFormSheet.savePort`) werden Koordinaten nur neu gesucht, wenn sich
   Name oder Land geändert haben; Regressionstest rot→grün.
4. **Disclosure vor dem Senden.** Im KI-Import-Sheet steht DE und EN sichtbar
   über dem Analysieren-Button: „Der eingefügte Text wird zur Auswertung an
   Google Gemini übertragen." — Katalog-Eintrag existiert in beiden Sprachen.
5. **Keine „1 Reisen".** Diese Zähl-Strings haben Pluralregeln DE+EN:
   `CruiseListView.swift:75,77` · `CruiseHeroCardView.swift:52,176` ·
   `StatsView.swift:57,63,218` · `MapView.swift:356` · `RouteStopSheetView.swift:63` ·
   `CruiseDetailView.swift:140,260` · `DealsView.swift:242,282` ·
   `SettingsView.swift:432,526,679`. Hero-Karte zeigt „Morgen" statt „In 1 Tagen".
   (`CruiseFormView.swift:374` bewusst ausgenommen → Backlog, fremder Dev-Scope.)
6. **Datenschutz & Support erreichbar.** Info-Bereich der Einstellungen enthält
   Link zur Datenschutzerklärung und Support-Kontakt (DE/EN).
7. **Doku stimmt.** Altersfreigabe-Entscheidung „4+ bleibt" in
   `release-configuration.md` dokumentiert; in `CHANGELOG.md` sind die noch unter
   `[Unreleased]` stehenden Build-23-Einträge (z. B. CloudKit-Production vom
   08.08.) in `[1.7.0]` einsortiert, und `[1.7.1]`/`[Unreleased]` führt alle
   obigen Änderungen.
8. **Beweis.** Volle Unit-Suite grün auf der Projekt-Toolchain mit
   `gate-run.json` (Exit 0); Test-Builds seriell, Simulatoren aufgeräumt.
