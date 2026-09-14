# TASKPLAN — Feature „Kreuzfahrt teilen" (+ Restarbeiten 1.8.0)

Stand 2026-08-25, Session 5. Winston-Orchestrierung, Einzel-Agents.

## Andres Original-Anfrage (wörtlich)

> „ich möchte dass man einzelne Kreuzfahrten exportieren kann, indem man diese
> per Nachricht an jemand anderen schickt und der diese dann einfach in seiner
> app importieren kann. in der nachricht soll dann die exportdatei und ein
> link sein. wenn man dann auf den link klickt wird diese datei automatisch in
> die eigene app imporiert. es sollen alle informationen und bilder zu der
> reise exportiert werden."

## Clarify-Ergebnisse (Andre, 2026-08-25 — bindend)

1. **Link-Mechanik: Datei als Träger.** Die Exportdatei ist das klickbare
   Element — Antippen öffnet ShipTrip und importiert automatisch (eigener
   UTType + Dokumenttyp, `onOpenURL`/Datei-Handler). Zusätzlich ein
   `shiptrip://`-Custom-Scheme-Link als Beigabe. KEINE Domain, KEINE
   Universal Links in diesem Run.
2. **Datenumfang: wirklich alles, immer** — Häfen, Notizen, Fotos und
   Ausgaben, ohne Nachfrage-Dialog.
3. **Bilder: komprimiert** — fürs Teilen auf Bildschirmqualität verkleinert
   (Richtwert max. 2048 px, HEIC/JPEG); Originale beim Absender unangetastet.
   Der normale Voll-Export/Backup bleibt unverändert (Originale).
4. **Codex: frisches Budget** — volle Gates (#1 Plan, #2 pro Diff nach
   Winston-Wahl, #3 Final, #4 Architektur).

## Phase 0 — Abschluss Run 1.8.0 (vor Feature-Start)

Tier: Small/Medium. Reihenfolge:

- [x] **T0.1** `ZZPerfScrollThrowawayUITests.swift` → `.planning/archiv/`
      (unversioniert, kein pbxproj-Eintrag — raus aus dem Test-Target).
- [x] **T0.2** Reset-Komplettierung (developer, Worktree
      `fix/reset-complete`): `resetApp()` löscht zusätzlich Gemini-Key
      (Keychain) + Präferenzen (UserDefaults/@AppStorage); Onboarding-Schalter
      überlebt als `false` (Intro startet neu); Footer-Text + L10n (Katalog
      gesperrt, nur nötige Keys). Rot-Beweis + AppResetUITests change-scoped.
- [x] **T0.3** Eine tiefe Prüfung: Quality (frischer Spawn) + gezielte
      Regression.
- [x] **T0.4** Merge auf `release/1.8.0` (Winston, seriell).
- [x] **T0.5** Frische Installation auf Abnahme-Sim
      „ShipTrip-Abnahme-1.8.0" (UDID `8894FCFD-F089-4C03-A0CF-0C941BBAE173`)
      → **finale Abnahme durch Andre** (Reset komplett + Kriterium 1 aus
      `.planning/ZIEL.md`, dem 1.8.0-Ziel-Artefakt).

## Phase 1 — Feature „Kreuzfahrt teilen" (Big-Tier, voller Prozess)

Start nach Andres 1.8.0-Abnahme (Architektur-Vorarbeit darf früher laufen).

- [x] **F1** `.planning/ZIEL.md` neu schreiben (Feature-B-Ziel + messbare
      Kriterien) + frische Verifikation gegen Original-Anfrage.
- [x] **F2** Architect (Fable): Share-Format (.shiptrip-Datei auf Basis
      ExportImportService-Envelope C3/C4), eigener UTType + Info.plist-
      Dokumenttyp, Custom-Scheme, Import-Flow (onOpenURL, Import-Preview,
      Dedup über stabile UUIDs — CloudKit-Regeln beachten), Foto-Kompression,
      ShareLink/Nachricht-Integration. Nähte zuerst (Contracts) für Fan-Out.
      → ADR via adr-writing + **Codex Gate #4**.
- [x] **F3** **Codex Gate #1** (Plan-Review) → TASKPLAN-Wellen final.
- [x] **F4** Wellen (Schnitt nach Architect-Nähten, ADR-007 + Design §9;
      Contracts C0–C10 in `docs/architecture/contracts/share-cruise-contracts.md`):
      - **W0 Naht-Seed** (serieller Mini-Commit VOR W1∥W2, kleiner
        Developer-Task — abschließende Liste in Contract C0): UTType-
        Konstante + komplette Info.plist-Registrierung (UTType + Dokumenttyp
        + URL-Scheme `shiptrip`) + `ShareArchiveLimits` + `ShareFingerprint`
        + `ExportImportDTOs.swift` (`ExportShareInfo`, `ExportArchive.share`,
        Sendable-DTOs) + Sichtbarkeitszeile (`importFromJSONData` →
        internal). Danach bauen W1 und W2 unabhängig kompilierbar gegen den
        Seed.
      - **W1 Share-Export** (developer, Worktree, ∥ W2): Foto-Transcoder
        (JPEG max. 2048 px, q 0,8; Disk-Spool, RAM O(größtes Bild);
        **alle Metadaten entfernt** — EXIF/GPS/IPTC/XMP, Orientierung
        eingebrannt, GPS-Fixture-Test), `exportCruiseForSharing` auf Basis
        der bestehenden `buildArchive`/`ZipArchiveStreamWriter`-Pfade
        (Envelope v2, genau 1 Cruise + `share`-Metablock inkl.
        `contentFingerprint`).
        *Schreib-Allowlist:* `ShipTrip/Services/ExportImportService.swift`
        (Eigentümer W1) · neue Transcoder-Datei unter `ShipTrip/Services/` ·
        `ShipTripTests/` (neue Share-Export-Tests). **Keine Info.plist-Edits
        (liegt in W0), keine String-Katalog-Keys in W1.**
        *Testumfang (change-scoped, Feature):* Unit-Tests — Envelope-
        Vollständigkeit (Häfen, Notizen, Ausgaben, Deals-Bezüge, Fotos),
        Transcoder (Maße/EXIF-Orientierung), **Regression: Originale +
        bestehender Voll-Export bit-identisch unverändert**, Share-Datei ist
        gültiges Backup (Bestands-Import liest sie).
      - **W2 Import-Flow** (developer, Worktree, ∥ W1 — baut gegen
        Contract-Fixtures aus C0–C10): URL-/Datei-Router + Import-Coordinator
        als **neue Dateien**, Share-Einstieg `importSharedCruise` als
        `ExportImportService+ShareImport.swift` (neue Extension-Datei —
        C10-Invarianten: genau 1 Cruise, leere Sammlungen, `share`-Block
        Pflicht, Versionsmatrix, Preflight off-main auf Sendable-Werten,
        Single-Flight), `onOpenURL`/Dokument-Öffnen, automatischer Import
        mit Ergebnis-Sheet (inkl. Versionskonflikt-Fall via
        `contentFingerprint`), Dedup geerbt (stabile UUID).
        *Schreib-Allowlist:* `ShipTrip/ShipTripApp.swift` (Eigentümer W2;
        Modifier-Reihenfolge: `.modelContainer` außen!) · neue Router-/
        Coordinator-/Sheet-Dateien · `ShipTrip/Services/
        ExportImportService+ShareImport.swift` (neu) ·
        `ExportImportService+Import.swift` (NUR der Archiv-Preflight-Guard
        in `importFromJSONData`, C10-Ausnahmeregel) · `ShipTrip/Models/
        Cruise.swift` (NUR das additive Attribut
        `shareContentFingerprint: String?`, CloudKit-konform) ·
        `ShipTripTests/` (neue Import-Tests) · **String-Katalog: Eigentümer
        während W1∥W2, nur `share.import.*`-Keys**. Die Bestandsdatei
        `ExportImportService.swift` ist darüber hinaus tabu —
        Änderungsbedarf = Blocker-Return an Winston, kein Edit.
        *Testumfang (change-scoped, Feature):* Unit-Tests — Router-Vertrag,
        Import-Ergebnis (neu / „bereits vorhanden" / Versionskonflikt via
        persistiertem Fingerprint), C10-Preflight- und Härtungsfälle
        (defektes ZIP, Zip-Slip, Limits aus `ShareArchiveLimits`,
        manipulierter Envelope, Versionsmatrix-Zellen inkl. `notAShareFile`,
        Mehr-als-1-Cruise-Massenimport-Abwehr) **in BEIDEN Einstiegspfaden
        (Share-Einstieg + manueller Backup-Import)** gegen Contract-Fixtures;
        Fingerprint-Persistenz beim Import.
      - *W1-Return-Notizen (Winston, 2026-08-25):* Share-Export liegt als neue
        Datei `ExportImportService+ShareExport.swift` (500-Zeilen-Limit von
        `ExportImportService.swift`; akzeptierte Allowlist-Abweichung, keine
        Konfliktkante zu W2). `ShareExportError.errorDescription` ist noch
        unlokalisiertes Deutsch → W3 zieht die C8-Keys nach
        („Teilen fehlgeschlagen: %@").
      - *W2-Return-Notizen (Winston, 2026-08-25):* Katalog-Keys sind deutsche
        Wortlaute statt `share.import.*` — Bestands-Konvention des Katalogs
        (401 Keys, sourceLanguage de, keine symbolischen Keys); gilt analog
        für W3. Weitere akzeptierte Abweichungen: data.json in Archiv-Wurzel
        (nur Share-Einstieg) · zweigeteilte Löschung Service/Coordinator ·
        ZIP-Reader-Fehler-Mapping auf limitExceeded/notAShareFile ·
        0/0-Ergebnis nutzt notAShareFile-Wortlaut.
      - *W3-Übergabepunkte aus der W1-Quality-Review (Winston, 2026-08-25):*
        (1) `exportCruiseForSharing` legt die Datei in einem frischen
        Temp-Unterordner an — der Aufrufer (W3-Completion-Handler) muss den
        **Elternordner** löschen, nicht nur die Datei (F07).
        (2) `ExportError.missingMedia` erreicht die Teilen-UI als „Backup
        abgebrochen: …" — W3 präsentiert Export-Fehler über den
        C8-Key „Teilen fehlgeschlagen: %@" und prüft den Wortlaut (F06).
        (3) Produktnotiz: geteilt wird wirklich alles inkl. Buchungs-/
        Kabinennummer — W3 erwägt einen Ein-Satz-Hinweis im Share-Text/UI
        (Andre-Entscheid „alles, ohne Nachfrage" bleibt bindend).
      - **W3 Teilen-UI + Ende-zu-Ende-Beweis** (seriell nach W1+W2 — braucht
        beide Artefakte; frühere UI-Arbeit gegen Contracts bewusst nicht:
        der Mehrwert von W3 ist gerade die Integration): Teilen-Aktion in der
        Reise-Detailansicht (ShareLink/Share-Sheet mit Datei +
        `shiptrip://import`-Beigabe), `isDemo`-Ausschluss, L10n
        (`share.ui.*`-Keys, Katalog sonst gesperrt).
        *Schreib-Allowlist:* Reise-Detail-Views · String-Katalog
        (`share.ui.*`) · `ShipTripUITests/`.
        *Testumfang:* **Roundtrip-Beweis für ZIEL-Kriterium 5 als eigener,
        benannter Test** — UI-/Integrationslauf: Reise mit Fotos exportieren
        → App-Zustand frisch (Reset/Neuinstallation auf Wegwerf-Sim) → Import
        über die Datei → inhaltlicher Identitäts-Abgleich (Felder, Häfen,
        Ausgaben, Deals-Bezüge, Foto-Anzahl; Foto-Auflösung reduziert
        erwartet) + Re-Import-Dedup-Fall. Dazu UI-Test der Teilen-Aktion.
      Pro Diff eine tiefe Prüfung (#2 oder Quality, Winston wählt);
      Test-Builds strikt seriell (Build-Token-Ledger); Merges seriell durch
      Winston.
- [x] **F5** Knowledge inkremental pro Wave · **Codex Gate #3** final ·
      **Gate #6** · Run-Bericht.

Skills im Run: `deep-links` (Scheme/onOpenURL), `swiftui`, `swiftdata`,
`swift-standards`, `xctest-ios`, `adr-writing`, `changelog`.

## Run-Einstellungen (aus Session-4-Handoff, unverändert)

Einzel-Agents · Worktrees unter `../ShipTrip-worktrees/` · Merges seriell auf
`release/1.8.0` durch Winston · Build-Token-Ledger (Test-Builds strikt
seriell, Wegwerf-Sim, Cleanup-Pflicht) · Devs committen im Worktree, pushen
nie · String-Katalog GESPERRT (nur nötige neue Keys) · Fable nur
Orchestrierung/Planung/finale Q-Gates, mechanische Spawns `model: opus` ·
Kein TestFlight/Push ohne Andres Zuruf.
