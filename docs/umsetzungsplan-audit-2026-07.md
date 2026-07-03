# ShipTrip — Umsetzungsplan Audit 2026-07-03 (alle 3 Richtungen + alle Findings)

> Quelle: `audit/audit-2026-07-03.html` (Codex + Gemini GO-WITH-CHANGES).
> Dieses Dokument ist die Arbeitsgrundlage für die Umsetzung. Jede Welle nennt
> Tasks, betroffene Findings, Dateien und ein prüfbares Erfolgskriterium.
> Reihenfolge ist abhängigkeitssortiert: **Phase 0 → A → B → C → D.**
> Fortschritt bitte direkt hier abhaken (`[ ]` → `[x]`).

## Betriebsregeln für die Umsetzung (Winston)

- Gate-Tier pro Welle: **Medium** (Codex-Gate #1 Plan je Welle, #2 je Code-Return,
  #3 vor Wellen-Abschluss). Architektur-Entscheidungen (B2, C2, D1, D2) → Gate #4 + ADR.
- Test-Builds strikt seriell (Build-Token), Cleanup Pflicht
  (`xcodebuild clean` + DerivedData + `xcrun simctl --set testing delete all`).
- Nach jeder Welle: Quality-Pass → Knowledge incremental (Feature-MD + CHANGELOG).
- TestFlight-Releases: nach Phase A (1.6.0), nach B (1.7.0), nach C (2.0.0).
- Sub-Agents read/write nur im zugewiesenen Datei-Scope; Reports am Ende via
  SendMessage an main.

## Offene Andre-Entscheidungen (Defaults, falls nicht widersprochen)

| # | Frage | Default |
|---|-------|---------|
| E1 | Hafen-Ausflüge/-Bilder als Feature behalten? | **Ja, erhalten** — Edit-Fix + Export nehmen sie mit (A1) |
| E2 | Deals-/Wunschreisen-Tab | **Behalten, nicht bewerben**; Rolle wird in D3 final entschieden |
| E3 | Abo-Preise | **4,99 €/Monat / 34,99 €/Jahr, 7 Tage Trial** (Marktanker aus Audit; vor C2 kurz validieren) |

---

## Phase 0 — Sofort (Stunden) · Repo & Maschine

- [ ] **0.1 Platte freiräumen (Andre, manuell!)** — Ziel ≥ 20 GB frei auf
  `/System/Volumes/Data`. Kandidaten aus dem Audit: CoreSimulator-Devices ~7,2 GB
  (`xcrun simctl delete unavailable` + alte Geräte), `~/Library/Caches/ms-playwright`
  1,6 GB, ShipIt-Cache 717 MB. *Blockiert alle Builds — zuerst!*
- [x] **0.2 Mode-Flip bereinigen** ✅ 2026-07-03, Commit `92b228d` — alle Dateien 755→644 zurückgesetzt
  (`find . -type f -perm 0755` auf Nicht-Executables), als eigener Commit
  „chore: restore file modes". Erfolgskriterium: `git diff` zeigt keine
  old mode/new mode-Zeilen mehr.
- [x] **0.3 Cover-WIP sichern** ✅ 2026-07-03, Commits `eb097ba` (Feature) +
  `0eaa335` (Docs/Audit); Tests 48/48 grün; TimelineRow = tot → A3.10 —
  das uncommittete „Reederei-Cover"-Feature
  (ShippingLine-Cover-Pool + ~200 Imagesets + 43 geänderte Dateien) als
  Feature-Commit auf main (Build muss grün sein; Tests 48/48). Dabei klären:
  `CruiseTimelineRowView` (204 Z.) — gehört sie zur WIP oder ist sie tot?
  Tot → in A3 entfernen. Erfolgskriterium: `git status` sauber.

## Phase A — Richtung 1 „Festigen" (1–2 Wochen) → TestFlight 1.6.0

### Welle A1 · Datenintegrität (Findings: Edit-Datenverlust [H], Port-Bild-Export [H], Zip-Slip [M], Dekompressions-Bombe [M], Delete-All [M], Import-ID-Duplikate [L])
- [x] **A1.1 Edit-Fix:** ✅ 2026-07-03 (reconcileRoute, duplikat-tolerant + rollback) `TempPort` um `id`, `excursionsRaw`, `imageData` erweitern;
  `saveCruise` aktualisiert Ports in-place per stabiler `id` (nur echte Removals
  löschen, Neue einfügen). Dateien: `CruiseFormView.swift`.
  ✓ Test: Edit einer Reise mit Ausflügen/Hafenbild erhält Daten + Port-UUIDs.
- [x] **A1.2 Port-Bilder in Export:** ✅ 2026-07-03 ZIP-Pfad `images/<cruiseId>/ports/<index>` +
  `imageUrl` setzen; Import liest bereits. Datei: `ExportImportService.swift`.
  ✓ Test: Roundtrip mit Port-Bild verlustfrei.
- [x] **A1.3 Import-Härtung:** ✅ 2026-07-03 (+ Port-/Expense-ID-Dedup, Import-rollback) Eintragsnamen normalisieren + Prefix-Check gegen
  Zielordner (kein `..`/absolut); `uncompressedSize`-Limit pro Eintrag (50 MB)
  und gesamt (500 MB) — bewusst strenger als das Audit-Beispiel (200 MB);
  dateiinterne ID-Duplikate im Import erkennen.
  ✓ Tests: präpariertes Slip-ZIP abgelehnt, Bomben-Header abgelehnt, Duplikat-Datei → 1 Reise.
- [x] **A1.4 deleteAllData vollständig:** ✅ 2026-07-03 (+ rollback bei Save-Fehler) `removeAllPendingNotifications()` +
  Dialog „auch KI-API-Key löschen?" (→ `KeychainService.delete`) + `try save()`.
  Datei: `SettingsView.swift`. ✓ Manuell: nach Löschen keine Reminder, Key-Wahl respektiert.

### Welle A2 · UX-Fixes (Findings: Notifications inert [M], Hero-VoiceOver [M], Dynamic Type [M], kein Einzel-Löschen [M], Karte Empty/Location [M], Komma-Parsing [M], Ausgaben-Sortierung [M], Foto-Grid Full-Res [M])
- [x] **A2.1** ✅ 2026-07-03 (Statusmaschine + isSaving-Sperre) — Notification-Permission kontextuell beim ersten Speichern einer
  zukünftigen Reise anfragen (mit Begründungs-Sheet). `CruiseFormView`/`NotificationService`.
- [x] **A2.2** ✅ 2026-07-03 (Hero-Button + heroCard-Identifier, UI-Test grün) — Hero-Karte als `Button` + `accessibilityLabel("Reise <Titel> öffnen")`. `CruiseListView`.
- [x] **A2.3** ✅ 2026-07-03 (@ScaledMetric) — Fixe Höhen → `minHeight`/`@ScaledMetric` (StatsStrip 58, Hero 286,
  StatCells); AX-Preview-Check. 
- [x] **A2.4** ✅ 2026-07-03 (contextMenu-Delete) — Swipe-to-Delete für Häfen/Ausgaben — vorhandene `deletePort`/
  `deleteExpense` anbinden. `CruiseDetailView`.
- [x] **A2.5** ✅ 2026-07-03 (Location komplett entfernt) — MapView: Empty-State-Overlay; `CLLocationManager`-Anfrage entfernen
  (kein Feature braucht sie) inkl. Info.plist-Key-Prüfung.
- [x] **A2.6** ✅ 2026-07-03 (currency/number-Fallback + Sortierung) — Ausgaben-Eingabe locale-basiert (`.currency`-Format statt `,`→`.`);
  Ausgaben nach Datum sortiert, Datum default-an. `ExpenseFormView`, `CruiseDetailView`.
- [x] **A2.7** ✅ 2026-07-03 (Thumbnails + AsyncPhotoView + Zoom) — Foto-Galerie Detail: Thumbnails im Grid/Pager, Full-Res nur Zoom;
  async Decoding + Platzhalter-State. `CruiseDetailView`.

### Welle A3 · Code-Politur (Findings: Key-in-URL [L-M], kSecAttrAccessible [L-M], print-PII [L], Status-Sniffing [L], Häfen-Zählung [L], Radius-Wildwuchs [M], PortSuggestion-Scans [L], Export-Temp [L], IdBackfill-Flag [L], Int:Identifiable [L], toter Code [M/L], God-File [M])
- [ ] **A3.1** Gemini-Key als `x-goog-api-key`-Header; Keychain-Save mit
  `kSecAttrAccessibleWhenUnlockedThisDeviceOnly`; Request-Timeout setzen.
- [ ] **A3.2** `print` → `os.Logger` (NotificationService, EmptyStateView);
  Nutzerinhalte mit `.private`.
- [ ] **A3.3** Status-Enum (`.success/.failure`) statt `contains("✓")` in
  CruiseFormView/SettingsView/DataManagement + A11y-Announcement.
- [ ] **A3.4** Häfen-Zählung vereinheitlichen (ohne Seetage, oder Label „Stopps").
- [ ] **A3.5** Radius-Token (sm 10 / md 16 / lg 28) in `Color+Theme`/eigenem
  DesignToken-File; `cardStyle()` konsequent nutzen oder entfernen.
- [ ] **A3.6** PortSuggestion: normalisierten Suchindex einmalig vorberechnen.
- [ ] **A3.7** Export-Temp: eindeutiger Dateiname + Löschen nach Share-Abschluss.
- [ ] **A3.8** IdBackfill: UserDefaults-Flag nach Erfolg, Läufe überspringen.
- [ ] **A3.9** `Int: @retroactive Identifiable` → Wrapper-Typ.
- [ ] **A3.10** Toten Code auflösen: EmptyStateView (nutzen oder löschen),
  Expense-Farb-Duplikat, TimelineRow gemäß 0.3-Entscheidung.
- [ ] **A3.11a** EUR-Fallback-Muster (`?? "EUR"`) an 6 Anzeige-Stellen
  (Expense.swift:102, Deal.swift:90/95, StatsView:115/192, CruiseDetailView:213/345)
  auf locale-neutrales Format angleichen — Befund aus A2.6-Review.
- [ ] **A3.11** ZIP-Stack extrahieren: `ZipArchiveWriter.swift`/`ZipArchiveReader.swift`/
  `CRC32.swift` — reine Verschiebung, Tests bleiben grün.

### Welle A4 · Fundament & Wahrheit (Findings: Swift-5-Drift [H], Non-Sendable [M], Doku-Drift [M], README/SETUP stale [L], Test-Lücken)
- [ ] **A4.1** `SWIFT_VERSION = 6.0` + strict concurrency; Fehler abarbeiten
  (LocationManager `@MainActor`, GeminiService-Singleton Sendable/@MainActor).
  ✓ Build grün unter Swift 6, 48+ Tests grün.
- [ ] **A4.2** Doku-Sync: MODELS.md aus Schema neu schreiben; API.md
  (NotificationService real, Gemini-Signaturen, ExportImportService neu);
  ARCHITECTURE.md (Threading-Absatz, Service-Tabelle, Ordner, Tab-Namen);
  README (iOS 18.5, Export erledigt); SETUP (Xcode 26.5, keine APNs-Capability
  — Stand heute; Push/Background Modes kommen erst mit CloudKit, s. D2.1;
  Fastlane/ASC-Secrets dokumentieren); CHANGELOG „48 Unit + 12 UI".
- [ ] **A4.3** Test-Lücken minimal schließen: GeminiService (URLProtocol-Mock:
  Erfolg, 401, 429, kaputtes JSON), KeychainService-Roundtrip,
  Import-Härtungs-Tests aus A1.3.
- [ ] **A4.4 Release:** Version 1.6.0, CHANGELOG, TestFlight via Fastlane.

## Phase B — Richtung 2 „Echtes Reisetagebuch" (3–5 Wochen) → TestFlight 1.7.0

### Welle B1 · Erststart & Aktivierung (Findings: kein Onboarding [H], Offline-USP unbeworben [M])
- [ ] **B1.1** Onboarding-Flow (3 Karten: Tagebuch · Weltkarte · **100 % offline
  auf See**) mit Ausgängen „Erste Reise anlegen" / „Beispielreise ansehen".
- [ ] **B1.2** Demo-Datensatz im Release verfügbar machen (Service aus `#if DEBUG`
  lösen, UI-Schalter nur im Onboarding/Einstellungen, 1-Tap-Entfernung bleibt;
  isDemo-Schema unverändert). ✓ Fresh-Install-Durchlauf.
- [ ] **B1.3** KI-Wert-Screen vor der Key-Wand (alte Phase-2-Welle-4) — Übergang bis D1.
- [ ] **B1.4** APP_STORE_LISTING: Offline-Claim prominent, Screenshots-Plan.

### Welle B2 · Journal-Kern (Finding: Journal fehlt [H]) — **ADR-003 + Gate #4**
- [ ] **B2.1** `JournalEntry`-@Model (Tag/Datum, optionaler Port-Bezug, Text,
  Stimmung; CloudKit-konform: Defaults, optionale Relationships, keine Uniques)
  + `Photo.caption: String = ""`. Migrations-Strategie dokumentieren
  (Lehre aus [[shiptrip-swiftdata-migration-id-gotcha]]: Migrationstest auf
  echtem Gerät VOR Release!).
- [ ] **B2.2** Tagebuch-Strang in `CruiseDetailView` (chronologisch, Tag-Karten
  mit Pin-Farb-Akzent) + Eintrag-Editor + Foto-Caption-UI.
- [ ] **B2.3** Tests: Migration Alt-Store → neu; Entry-CRUD; Aggregate unverändert.

### Welle B3 · Teilen & Rückblick (Finding: kein Teilen [H])
- [ ] **B3.1** „Reise teilen" im Detail-Menü: Story-Karte via `ImageRenderer`
  (Cover/Geo-Fallback + Route-SVG + Kennzahlen + dezentes ShipTrip-Branding), offline.
- [ ] **B3.2** PDF-Reise-Rückblick (mehrseitig: Tage + Fotos + Karte) — wird in
  C2 Premium-Feature.
- [ ] **B3.3 Release 1.7.0** + Feature-MDs + CHANGELOG.

## Phase C — Richtung 3a „Companion & Abo" (3–4 Wochen) → TestFlight 2.0.0

### Welle C1 · Heute-Dashboard (lokal, risikoarm)
- [ ] **C1.1** Heute-Panel im Listenkopf bei `isOngoing`: „Tag X von Y", heutiger
  Hafen + Liegezeiten aus `route`, Quick-Actions (Eintrag/Foto/Ausgabe → B2-Editor);
  Countdown-Variante vor Reisestart. 100 % offline.
- [ ] **C1.2** Tests für Tages-/Hafen-Auflösung (Zeitzonen!).

### Welle C2 · StoreKit-2-Freemium — **ADR-004 + Gate #4** (Finding: Freemium-UI fehlt [L], Preise = Annahme E3)
- [ ] **C2.1** Produkte: `shiptrip.premium.monthly` 4,99 € / `.yearly` 34,99 €
  (7 Tage Trial). `.storekit`-Config + StoreKit-Tests.
- [ ] **C2.2** Entitlement-Layer (`PremiumStore`: `Transaction.currentEntitlements`,
  `Transaction.updates`-Listener, Restore).
- [ ] **C2.3** Paywall-Sheet (Leistungen: KI-Flat [ab D1], iCloud-Sync [ab D2],
  PDF-Rückblick, unbegrenzte Fotos) + Gating: PDF-Export (B3.2) und Foto-Limit
  (>10/Reise) hinter Premium; Kern bleibt frei.
- [ ] **C2.4 Release 2.0.0** (Abo-Review-Notes; vorher Preisvalidierung E3 +
  kurzes Nischen-Go/No-Go — Audit-Rohindex „Nische real aber schmal [H]").

## Phase D — Richtung 3b „Managed-KI & Sync" (4+ Wochen)

### Welle D1 · KI-Proxy — **ADR-005 + Gate #4** (Findings: BYO-Key [H], Prompt-PII [L])
- [ ] **D1.1** Schlanker Proxy (Cloudflare Worker o. ä.): Key serverseitig,
  Zero-Data-Retention (keine Prompt-Speicherung), anonymer Monats-Zähler,
  Free 3/Monat · Premium unbegrenzt, Rate-Limit/Missbrauchsschutz, App-Attest prüfen.
- [ ] **D1.2** App: `AIService`-Abstraktion (Proxy default, BYO-Key als
  Power-Option; hier Phase 2.5 einschieben: Mistral-BYO-Key als 2. Provider).
  PII-Hinweis vor dem Senden („gesamter Text geht an Google"); KI-Antwort als
  untrusted behandeln — Feld-Validierung gegen Prompt-Injection.
- [ ] **D1.3** Kosten-Monitoring + Kill-Switch; PRIVACY_POLICY aktualisieren.

### Welle D2 · iCloud/CloudKit als Premium (abh.: A1 ID-Stabilität, A4 Swift 6)
- [ ] **D2.1** ⚠️ **iOS Hard-Pause:** Andre setzt Capability in Xcode
  (iCloud-Container `iCloud.com.andre.ShipTrip`, Background Modes, Push) — dann weiter.
- [ ] **D2.2** `cloudKitDatabase` aktivieren; Migrations-/Sync-Smoke-Test auf
  echtem Gerät (ADR-002-Plan); Dedup-Wächter (id-basiert) beobachten.
- [ ] **D2.3** Premium-Gate für Sync + Settings-Status „Aktiv".

### Welle D3 · Positionierung (Findings: Deals-Tab [M], Social/Fotobuch [L])
- [ ] **D3.1** Entscheidung E2 final: Wunschreisen-Tab behalten/zurückstufen/hinter
  „Mehr" — inkl. finaler Tab-Benennung (Rohindex „Tab-Benennung [L]";
  Merkliste→Wunschreisen ist bereits erfolgt).
- [ ] **D3.2** ASO-Update: Offline-USP, „einziges Kreuzfahrt-Tagebuch", Keyword-Set.
  Positionierungs-Notiz: Hafen-DB allein ist kein Moat — Differenzierung läuft
  über Journal-Kern + Offline-USP (Rohindex „Hafen-DB kein Moat [M]").
- [ ] **D3.3** Backlog-Kandidaten (nicht scopen): Fotobuch-Druck, Familien-Sharing.

---

## Findings-Abdeckungs-Matrix (28 konsolidierte Befunde + Zeile „Test-Lücken")

| Finding (Kurz) | Task |
|---|---|
| Edit-Datenverlust + Port-UUIDs [H] | A1.1 |
| Port-Bilder nicht exportiert [H] | A1.2 |
| Kein Onboarding [H] | B1.1–B1.2 |
| Journal-Kern fehlt [H] | B2 |
| Kein Teilen [H] | B3 |
| KI hinter BYO-Key [H] | B1.3 (kurzfristig) + D1 (echt) |
| Swift-5-Drift [H] | A4.1 |
| Platte voll [H] | 0.1 |
| Zip-Slip + Bombe [M] | A1.3 |
| Delete-All-Lücken [M] | A1.4 |
| Notifications inert [M] | A2.1 |
| Hero-VoiceOver + Dynamic Type [M] | A2.2–A2.3 |
| Kein Einzel-Löschen [M] | A2.4 |
| Doku-Drift MODELS/API/ARCH [M] | A4.2 |
| Repo-Hygiene WIP + Mode-Flip [M] | 0.2–0.3 |
| Foto-Grid Full-Res [M] | A2.7 |
| Komma-Parsing + Ausgaben-Sortierung [M] | A2.6 |
| God-File ExportImport [M] | A3.11 |
| Karte Empty/Location [M] | A2.5 |
| Offline-USP unbeworben / Deals-Tab [M] | B1.4 + D3 |
| Non-Sendable Singletons [M] | A4.1 |
| Key-in-URL + Keychain-Attribut [L-M] | A3.1 |
| Toter/duplizierter Code [M/L] | A3.10 (+0.3) |
| Kleinkram ①–⑨ [L] | A3.2–A3.9, A4.2 |
| Import-ID-Duplikate [L] | A1.3 |
| Prompt-PII/Timeout [L] | A3.1 + D1.2 |
| IdBackfill-Startkosten [L] | A3.8 |
| Freemium-UI fehlt [L] | C2 |
| Test-Lücken Services | A4.3 |
