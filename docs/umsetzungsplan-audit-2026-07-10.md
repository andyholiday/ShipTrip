# ShipTrip — Umsetzungsplan Audit 2026-07-10 (Stabilitätswellen S1–S4)

Bezug: `audit/audit-2026-07-10.html` (GO-WITH-CHANGES, Commit `687657c`, v1.7.0 Build 18).
Alle 23 Befunde wurden am 10.07.2026 durch 5 unabhängige read-only Verifizierer am echten
Code bestätigt — Berichte unter `.planning/audit-verify-v{1..5}-*.md`. Ergebnis: 23×
CONFIRMED (M8-Teilaspekt „App-Namen" nur PARTIALLY; M6b Test-Host-Flake und L4c
Zero-State-Optik ohne Lauf/Screenshot nicht prüfbar). Drei Zusatzfunde der Verifikation
sind eingearbeitet und im Original-Audit **nicht** enthalten. Plan-Review: Codex-Gate
(gpt-5.6-sol) GO-WITH-CHANGES am 10.07. — alle 11 Auflagen in dieser Fassung umgesetzt.

Dieser Plan ergänzt `docs/umsetzungsplan-audit-2026-07.md` (Audit 03.07.); dessen Phasen
B1–B3 (Journal-Kern) bleiben der Produktkurs **nach** den Stabilitätswellen.

## Betriebsregeln für die Umsetzung (Winston)

- **Einzel-Agents** (Andre-Vorgabe 10.07.): jeder Task ein spezialisierter Sub-Agent,
  **max. 150k Token / 20 min** pro Agent. Tasks, die das reißen würden, sind hier bereits
  gesplittet (Codex-Auflagen #9/#10).
- **Single-Writer-Prinzip:** Jede Datei hat pro Welle genau EINEN schreibenden Task.
  Lokalisierungs-Strings in fremd-besessenen Dateien stellt der Datei-Besitzer um; den
  String-Katalog schreibt ausschließlich S2.1b-1.
- Gates pro Welle: Gate #1 (Plan-Delta), Gate #2 pro Code-Return, Quality-Verify nach
  Welle, Knowledge incremental (Feature-MD + Changelog), Gate #3 vor Release.
- Test-Builds strikt seriell (Build-Token), Cleanup Pflicht (DerivedData +
  `simctl --set testing delete all`).

## Andre-Entscheidungen (10.07.2026, Abend)

1. **Scope der Umsetzung: NUR High-Findings (H1–H8).** Aktive Tasks: S1.1–S1.5,
   S2.1a, S2.1b-1/-2, S2.2. Alle Medium-/Low-Tasks (S2.3a/b, S2.4, S3.x, S4.x) sind
   zurückgestellt, bis Andre sie aufruft. Zwei Detail-Anpassungen: der M5-Komma-Parser
   bleibt Teil von S1.2 (liegt in denselben Zeilen wie H2 — der neue Editor würde sonst
   mit bekanntem Datenfehler ausgeliefert); der M10-Anteil (Badge/URL) ist aus S1.3
   gestrichen — dort bleibt nur H4. Da S2.4 ruht, übernimmt S2.1a zusätzlich die
   H6-Strings in `GeminiService.swift:214-228` (kein Scope-Konflikt mehr).
2. **Keine CI-Automatik** (M7 ohnehin zurückgestellt). H7-Verifikation: Bundle-Check im
   Build (S1.5); der signierte Archive-Privacy-Report läuft beim nächsten regulären
   TestFlight-Release-Preflight mit.
3. **M1-Klarstellung:** Andres Punkt „Verhalten bei fehlerhaften ZIPs" ist H8 → in Scope
   (S2.2). M1 selbst (Export enthält keine Wunschreisen/eigenen Reedereien/Einstellungen)
   ist Medium und zurückgestellt.
4. **M9** (Verhalten im In-Memory-Notbetrieb) ist Medium und zurückgestellt; keine
   Entscheidung nötig, solange die Welle nur Highs umfasst.

## Welle S1 · Release-Sicherheit (P0, ~1–2 Tage) — 5 Tasks, alle parallel

Schreib-Scopes disjunkt (S1.2 ist einziger Schreiber an CruiseFormView, S1.1 einziger an
CruiseListView/CruiseDetailView, S1.4 einziger an ExportImportService).
Test-Build-Phasen seriell über Build-Token.

- [ ] **S1.1 CruiseListView + CruiseDetailView: Filter-Dead-End + Löschen mit Bestätigung und Rollback** (H1, H5)
  Scope: `Views/Cruises/CruiseListView.swift`, `Views/Cruises/CruiseDetailView.swift`.
  Fix: Filter-Menü/Reset-CTA auch im Empty-State (`ContentUnavailableView` mit
  „Filter zurücksetzen"-Action, ~Zeile 85); `confirmationDialog` vor beiden
  Context-Menü-Löschungen (141-147, 220-226). Lösch-Sequenz überall (Liste UND Detail):
  `modelContext.delete` → `try save()` → bei Fehler `rollback()` + sichtbares
  Fehlerfeedback → erst NACH erfolgreichem Save Notification entfernen (Codex-Auflage #7;
  Muster „Alle Daten löschen"). Der fire-and-forget-Pfad in CruiseDetailView wird
  mit-saniert, nicht nur abgeglichen.
  Akzeptanz: UI-Test „Filter ohne Treffer → Reset erreichbar"; UI-Test Lösch-Dialog;
  Unit-/Verhaltens-Check Save-Fehlerpfad (Rollback + Reise bleibt sichtbar, Erinnerung
  bleibt bestehen). Agent: developer · Skills: swiftui, swift-standards, xctest-ios.

- [ ] **S1.2 Hafen-Editoren: manuelle Eingabe + Validierung** (H2, M5)
  Scope: `Views/Cruises/PortFormView.swift` + `TempPortFormSheet` in
  `Views/Cruises/CruiseFormView.swift` (~990–1166).
  Fix: expliziter Modus-Switch Suche ↔ manuelle Eingabe statt `if name.isEmpty`
  (122-135); Bestands-Ports editierbar machen; Locale-bewusster Dezimal-Parser
  (NumberFormatter, deutsche Kommas) statt `Double(latitude) ?? 0` (234-235); Constraint
  Abfahrt ≥ Ankunft auch in `TempPortFormSheet.savePort()` (1131-1166, Muster aus
  PortFormView Zeile 140).
  Akzeptanz: Unit-Tests Komma-Parsing (Grenzfälle „53,5"/„-33,86"), Datums-Constraint;
  manuelle Neuanlage + Korrektur eines Bestands-Ports per UI-Test. Agent: developer ·
  Skills: swiftui, swift-standards, xctest-ios.

- [ ] **S1.3 Deals: Hero-Deal löschbar** (H4; M10-Anteil Badge/URL zurückgestellt —
  Andre-Scope 10.07.)
  Scope: `Views/Deals/DealsView.swift` (inkl. DealFormView darin).
  Fix: einheitlicher bestätigter Lösch-Pfad für Hero (Context-Menü) UND Formular
  (Delete-Button mit Confirm).
  Akzeptanz: UI-Test „neuester Deal löschbar".
  Agent: developer · Skills: swiftui, swift-standards, xctest-ios.

- [ ] **S1.4 Import: Seetag-Fehlklassifikation** (H3)
  Scope: `Services/ExportImportService.swift`, `ShipTripTests/ExportImportHardeningTests.swift`
  (+ Roundtrip-Tests).
  Fix: `isSeaDay` als **optionales** DTO-Feld (`decodeIfPresent`) — Alt-ZIPs und
  Legacy-/Web-JSON ohne Feld bleiben dekodierbar (Codex-Auflage #4). Priorität beim
  Import: explizites Flag > Namens-Match („Seetag"/„Sea Day") als Fallback; `lat == nil`
  klassifiziert NICHT mehr (Zeile 359). Export (`buildExportCruises`, 183) überschreibt
  nie den echten Hafennamen.
  Akzeptanz: Regressionstest „koordinatenloser echter Hafen übersteht
  Export→Import→Export mit Name+Land"; getrennte Fixtures für Alt-Format (ohne Flag) und
  Neu-Format (mit Flag), beide grün. Agent: developer · Skills: swiftdata,
  swift-standards, xctest-ios.

- [ ] **S1.5 Privacy-Manifest** (H7)
  Scope: neu `ShipTrip/PrivacyInfo.xcprivacy` + Target-Aufnahme (project.pbxproj).
  Fix: `NSPrivacyAccessedAPICategoryUserDefaults` UND `…FileTimestamp` deklarieren
  (Zusatzfund: `ZipArchiveReader.swift:69` `attributesOfItem` → FileTimestamp).
  Reason-Codes im Task GEGEN DIE AKTUELLE Apple-Doku verifizieren (context7/WebFetch),
  nicht CA92.1 blind übernehmen.
  Akzeptanz: Manifest im Build-Produkt enthalten (Build-Log/Bundle-Check), Kategorien
  decken alle Fundstellen (inkl. CruiseFormView:884/936, IdBackfill:47,
  ShippingLineCatalogDedup:38). Der signierte **Archive-Privacy-Report ist Pflichtpunkt
  in S3.4** (nicht „sofern möglich"). Agent: developer · Skills: swift-ios,
  app-store-submit, xcode-mcp.

## Welle S2 · Sprach- & Datenvertrauen (P1, ~2–3 Tage) — 7 Tasks

Single-Writer-Aufteilung (Codex-Blocker #2 aufgelöst): ExportImportService gehört in S2
ausschließlich S2.2; GeminiService ausschließlich S2.4; SettingsView ausschließlich
S2.3a. Jeder Task stellt die Lokalisierungs-Strings SEINER Dateien um; den Katalog
schreibt allein S2.1b-1.

Parallel-Gruppen: **S2.1a ∥ S2.2 ∥ S2.3a ∥ S2.3b** → danach **S2.4** (braucht
SettingsView von S2.3a) → danach **S2.1b-1** (sammelt alle neuen Keys) → **S2.1b-2**.

- [ ] **S2.1a Lokalisierung — Code-Stellen außerhalb fremder Scopes** (H6, Teil 1)
  Scope: `Utilities/Date+Extensions.swift:63-75`, `Services/ZipArchiveWriter.swift:223`
  + die vom V4-Bericht gelisteten dynamischen Titel (nur in Dateien, die kein anderer
  S1/S2-Task schreibt — Konfliktliste vor Spawn gegen Task-Scopes prüfen).
  Hinweis: die hartkodierten Strings in `ExportImportService.swift:493-497` stellt
  **S2.2** um, die in `GeminiService.swift:214-228` stellt **S2.4** um (Single-Writer).
  Akzeptanz: kein user-sichtbarer String ohne Lokalisierungs-Pfad in den Scope-Dateien.
  Agent: developer · Skills: swift-standards, swiftui.

- [ ] **S2.2 ZIP-Integrität beim Restore** (H8; + H6-Anteil ExportImportService; needs: S1.4)
  Scope: `Services/ZipArchiveReader.swift`, `Services/ExportImportService.swift`,
  `ShipTripTests/ExportImportHardeningTests.swift`.
  Fix: CRC-32-Verifikation pro Entry, Local-Header-Signatur-Check, Local/Central-Namens-
  Konsistenz, Entry-Count-Validierung (throw statt stilles `break`/`continue`); fehlende/
  ungültige Medien in `ImportResult` zählen und in der Import-UI ausweisen; bei
  Strukturfehler atomar abbrechen (kein Teil-Import). Test-ZIP-Builder schreibt
  **standardmäßig echte CRCs**; expliziter CRC-Override nur für Korruptionstests —
  Zip-Slip-/Bomben-Suiten mit anpassen (Codex-Auflage #5). Nebenher: Strings
  `ExportImportService.swift:493-497` auf `String(localized:)` (H6-Anteil).
  Akzeptanz: Tests mit korruptem CRC, truncated Central Directory, fehlendem Medium —
  jeweils klare Fehlermeldung bzw. sichtbarer Zähler; alle bestehenden
  Hardening-/Roundtrip-Tests grün. Agent: developer · Skills: swift-standards, xctest-ios.

- [ ] **S2.3a Settings: Notifications wirken sofort + ehrlicher Export-Scope** (M4, M1-Default)
  Scope: `Views/Settings/SettingsView.swift`, `Services/NotificationService.swift`.
  Fix: `rescheduleAll(...)`-Methode im NotificationService + Aufruf bei Settings-Änderung;
  `.denied`-Fall → „Systemeinstellungen öffnen" (Pattern wiederverwenden:
  `CruiseFormView.swift:468-480`); Export-UI ehrlich „Reisen exportieren" + Hinweis auf
  nicht enthaltene Daten (Deals, eigene Reedereien/Schiffe, Einstellungen).
  Akzeptanz: Unit-Test rescheduleAll-Logik (Prefix-Filter-Muster aus Bestand);
  Export-Texte DE/EN konsistent. Agent: developer · Skills: swiftui, swift-standards,
  xctest-ios.

- [ ] **S2.3b Persistenter In-Memory-Fallback-Banner** (M9)
  Scope: `ShipTripApp.swift`, `Views/MainTabView.swift`.
  Fix: persistenter Warn-Banner bei In-Memory-Fallback (statt Einmal-Alert,
  ShipTripApp:82-102) + Retry-Pfad (Store-Neuaufbau versuchen); Default ohne
  Schreibsperre (Andre-Entscheidung 4).
  Akzeptanz: Banner bleibt über Tab-/Navigation-Wechsel bestehen; Retry erreichbar;
  UI-Smoke im Fallback-Zustand (launch-argument-getriggert). Agent: developer · Skills:
  swiftui, xctest-ios.

- [ ] **S2.4 Gemini-Vertrauen: Disclosure + atomarer Key-Wechsel** (M11; + H6-Anteil GeminiService; needs: S2.3a, S1.2)
  Scope: `Services/KeychainService.swift`, `Services/GeminiService.swift`,
  `Views/Settings/SettingsView.swift` (Key-Eingabe-Flow — deshalb nach S2.3a),
  AIImportSheet in `Views/Cruises/CruiseFormView.swift` (~1394-1454 — deshalb nach S1.2).
  Fix: Drittanbieter-Hinweis direkt am Sende-CTA („Text wird an Google Gemini
  übertragen"); Key-Wechsel-Algorithmus fest (Codex-Auflage #6): Kandidat **ohne
  Persistenz validieren** → bei vorhandenem Eintrag `SecItemUpdate` → bei
  `errSecItemNotFound` `SecItemAdd`, Accessibility-Attribut (ThisDeviceOnly) unverändert;
  Rückgabewert in `setApiKey` prüfen, Fehler an UI. Strings `GeminiService.swift:214-228`
  auf `String(localized:)` (H6-Anteil).
  Akzeptanz: Unit-Tests Key-Wechsel: Fehlschlag-Pfad (alter Key intakt), Erstanlage-Pfad
  (kein alter Key), Accessibility bleibt; Disclosure-String als `String(localized:)`
  (Katalog-Eintrag folgt in S2.1b-1). Agent: developer · Skills: swift-standards, swiftui.

- [ ] **S2.1b-1 Lokalisierung — Katalog + Vollabgleich** (H6, Teil 2; needs: S2.1a, S2.2, S2.4)
  Scope: `ShipTrip/Localizable.xcstrings` (einziger Katalog-Schreiber).
  Fix: die 63 fehlenden Keys (Liste: Anhang `.planning/audit-verify-v4-l10n-privacy.md`)
  + alle in S2.1a/S2.2/S2.3a/S2.3b/S2.4/S1.x neu entstandenen Keys mit EN-Übersetzung
  ergänzen; statischen Abgleich Code ↔ Katalog wiederholen (Prüfkommando aus V4-Bericht).
  Akzeptanz: Abgleich = 0 fehlende Keys; alle Keys mit nicht-leerer EN-Unit.
  Agent: developer · Skills: swiftui.

- [ ] **S2.1b-2 EN-UI-Smoke** (H6, Teil 3; needs: S2.1b-1)
  Scope: neuer UI-Smoke-Test in `ShipTripUITests/`.
  Fix: Launch mit `-AppleLanguages (en)`, Kern-Screens (Liste, Karte, Stats, Settings,
  Deals) auf bekannte deutsche Marker-Strings prüfen.
  Akzeptanz: EN-Smoke grün im seriellen Testlauf. Agent: developer · Skills: xctest-ios.

## Welle S3 · Release-Prozess & Doku-Wahrheit (P2, ~2 Tage) — 6 Tasks

- [ ] **S3.1a Shared Scheme + Testpläne** (M7, Teil 1)
  Scope: `ShipTrip.xcodeproj/xcshareddata/xcschemes/` (Shared Scheme NEU — aktuell
  existiert gar keine .xcscheme-Datei!), zwei `.xctestplan` (Unit / UI getrennt, Capture
  separat s. S3.2).
  Akzeptanz: Scheme + Testpläne versioniert, `xcodebuild -list` zeigt das Shared Scheme.
  Agent: developer · Skills: xcode-mcp, xctest-ios.

- [ ] **S3.1b Fastlane-Kette + Runbook** (M7, Teil 2; needs: S3.1a)
  Scope: `Gemfile` + `Gemfile.lock` (Fastlane gepinnt), `fastlane/Fastfile`
  (`build_and_test`-Lane), NEU `docs/release-runbook.md` (Archive→Export→Upload,
  verweist auf `docs/APP_STORE_CONNECT.md`).
  Akzeptanz: Lane definiert + Runbook vollständig; noch kein Realdurchlauf (→ S3.1c).
  Agent: developer · Skills: fastlane-ios (gh-actions nur falls Andre CI wählt).

- [ ] **S3.1c Serieller Realdurchlauf** (M7, Teil 3 + M6b; needs: S3.1b, S3.2)
  Scope: kein Code — Ausführung + Protokoll.
  Fix: `bundle exec fastlane build_and_test` einmal real durchlaufen lassen (strikt
  seriell, Build-Token); dabei den kombinierten Unit+UI-Lauf beobachten → adressiert
  M6b (Test-Host-Flake) mit einem echten Datenpunkt; Flake ggf. als Issue festhalten.
  Akzeptanz: grüner Realdurchlauf dokumentiert (Log-Auszug in `.planning/`), Cleanup
  danach (DerivedData + `simctl --set testing delete all`). Agent: developer · Skills:
  fastlane-ios, xctest-ios.

- [ ] **S3.2 Screenshot-Capture vom Test-Gate lösen** (M6a, L2; needs: S3.1a)
  Scope: `ShipTripUITests/HauptansichtScreenshotTests.swift`, Testplan-Konfiguration.
  Fix: Capture-Ausgabe nach XCTAttachment/DerivedData statt hartem Repo-Pfad; Capture-
  Fälle in eigene, nur explizit gestartete Testplan-Konfiguration; Benennung stellt klar,
  dass KEINE visuelle Baseline geprüft wird (L2). Versionierte PNGs unter
  `audit/screenshots/` werden im Normallauf nie mehr überschrieben.
  Akzeptanz: normaler UI-Lauf verändert `git status` nicht; Capture-Lauf nur auf Abruf.
  Agent: developer · Skills: xctest-ios.

- [ ] **S3.3 Doku-/Metadaten-Sync** (M8; needs: ALLE S1- und S2-Tasks + S3.1b — läuft als
  letzter Doku-Schritt der Welle, damit Changelog/Privacy-Texte den Endstand beschreiben)
  Scope: `docs/MODELS.md` (8 statt 5 Modelle), `README.md` (Badge 1.5.1→aktuell),
  `APP_STORE_LISTING.md` (kanonische Fassung festlegen, App-Name vereinheitlichen),
  `PRIVACY_POLICY.md` + `docs/privacy.html` (JSON→ZIP, Gemini-Disclosure angleichen),
  `docs/umsetzungsplan-audit-2026-07.md` (B4.3b-Checkboxen mit CHANGELOG abgleichen),
  `CHANGELOG.md` (Unreleased-Einträge S1–S3).
  Akzeptanz: kein Widerspruch mehr zwischen den genannten Quellen (Stichproben-Matrix im
  Return). Agent: knowledge · Skills: changelog, markdown-standards.

- [ ] **S3.4 Submission-Preflight** (Codex-Auflage #11; needs: S3.1c, S3.3)
  Scope: kein Feature-Code — Release-Verifikation.
  Fix: signiertes Device-Archive erstellen, **Archive-/ASC-Privacy-Report prüfen**
  (Pflicht-Gate aus S1.5), Test-Upload (validate-Lane), ASC-Live-Metadaten gegen die
  kanonische Listing-Datei abgleichen, offene Checkliste in `docs/APP_STORE_CONNECT.md`
  abarbeiten/aktualisieren. ⚠️ ASC-Schritte ohne `.p8`-Ausgabe (kein `.inspect`, kein
  `app_store_connect_api_key`-Print — bekannte Vorfälle).
  Akzeptanz: Privacy-Report deckt Manifest-Kategorien; Validate grün; Metadaten-Abgleich
  dokumentiert. Externe Publikation bleibt expliziter Andre-Checkpoint.
  Agent: golive · Skills: fastlane-ios, app-store-submit, testflight.

## Welle S4 · Politur & größere Refactors (planbar, nach S1–S3 oder nach B2)

- [ ] **S4.1 Import/Export-Pipeline entkoppeln + Roundtrip-Fidelität** (M3 + M1-Fidelität;
  + ADR-007 + Gate #4 falls Andre Voll-Backup wählt)
  Nichtisolierte I/O-Pipeline (weg vom klassenweiten `@MainActor`), Streaming/Chunking
  statt Voll-Materialisierung (Peak ≈ 2× Fotomenge), doppeltes Voll-Einlesen im Reader
  beseitigen, Fortschritt + Cancellation; stabile Foto-IDs + vollständige Zeitstempel im
  DTO (M1-Fidelität — Format-Versionierung beachten). Agent: developer · Skills:
  swift-standards, swiftdata (Konzept-Check vorab als Mini-Spike).
- [ ] **S4.2 NotificationService injizierbar** (L1): UNUserNotificationCenter hinter
  Protokoll, Logik-Tests; echte Zustellung bleibt Device-Gate (bekannte Grenze).
- [ ] **S4.3 Hafen-Momente-Duplikat auflösen** (L3): ~200 Zeilen 1:1-Dup
  (`PortFormView.swift:282-472` ↔ `CruiseFormView.swift:1175-1367`) in gemeinsame
  Komponente — NUR entlang des echten Duplikats, kein Groß-Refactoring.
- [ ] **S4.4 Kleine UX-Lücken** (L4): Foto-Ladefehler sichtbar statt `try?`
  (PortFormView:222-231, CruiseFormView:1120-1129); Rating auf „unbewertet"
  zurücksetzbar (RatingInputView, CruiseFormView:1458-1483); L4c: Port-Zero-State auf
  langer Route per Screenshot-Review beurteilen (Sim-Lauf), erst dann ggf. fixen.
- [ ] **S4.5 L5 dokumentieren, nicht fixen:** Dedup-Flag-Risiko als Prüfpunkt in das
  bestehende CloudKit-Gate (Welle D2 im Plan 2026-07) eintragen.

## Danach: Produktkurs (Audit-Empfehlung, unverändert)

Nach S1–S3 KEINE weitere Kartenpolitur — nächster Produktblock ist Aktivierung +
Journal-Kern: **B1 → B2 (ADR-003 + Gate #4) → B3** aus
`docs/umsetzungsplan-audit-2026-07.md`. S4 kann dahinter oder in Lücken laufen.

## Findings-Abdeckung (23/23)

| Befund | Task | | Befund | Task |
|---|---|---|---|---|
| H1 | S1.1 | | M6 | S3.2 (a) + S3.1c (b, Realdatenpunkt) |
| H2 | S1.2 | | M7 | S3.1a/b/c |
| H3 | S1.4 | | M8 | S3.3 |
| H4 | S1.3 | | M9 | S2.3b |
| H5 | S1.1 | | M10 | S1.3 |
| H6 | S2.1a + S2.2/S2.4 (Anteile) + S2.1b-1/-2 | | M11 | S2.4 |
| H7 | S1.5 + S3.4 (Privacy-Report-Gate) | | L1 | S4.2 |
| H8 | S2.2 | | L2 | S3.2 |
| M1 | S2.3a (Scope-Ehrlichkeit) + S4.1 (Fidelität) | | L3 | S4.3 |
| M3 | S4.1 | | L4 | S4.4 (inkl. L4c-Screenshot-Review) |
| M4 | S2.3a | | L5 | S4.5 |
| M5 | S1.2 | | | |
