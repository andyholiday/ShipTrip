# Nachtjob-Brief: Karten-Redesign + TestFlight-Release

> Geplant von Andre am 2026-07-09, Ausführung 2026-07-10 ~02:00 (Europe/Berlin).
> Dieses Dokument ist die verbindliche Spezifikation für den nächtlichen Lauf.
> Der Job läuft vollautonom — keine Rückfragen an Andre, Entscheidungen selbst
> treffen und dokumentieren.
>
> **Modus (Andre, 2026-07-09):** Claude **solo** — keine Codex- und keine
> Gemini-Reviews/Gates (Codex-Limit erreicht). Winston-Quality-Gates laufen
> Claude-intern (quality-Agent statt Codex-Review).

## Ziel

Der Karten-Bereich (`ShipTrip/Views/Map/`) wird komplett überarbeitet. Andre
gefällt der aktuelle Zustand nicht. Erfolgskriterium: Am Morgen liegt ein neues
TestFlight-Build vor — für Andre (interne Gruppe „VIP Tester") **und** für die
externe Testerin Stefanie (externe Gruppe „VIP Extern", inkl. eingereichtem
Beta-Review).

## Design-Referenz

https://www.magnific.com/de/vektoren-premium/road-trip-planer-smartphone-schnittstellenvorlage-gps-navigation-mobile-app-seitenlayout-automatische-routenplanung-suchbildschirm-fuer-zielorte-reiseroute-anwendung-flache-benutzeroberflaeche-telefonanzeige_26165549.htm

Stilrichtung dieser Referenz (Road-Trip-Planer, flat UI): helle, aufgeräumte
Karte, weiche abgerundete Karten/Sheets, klare Routenlinien mit deutlichen
Start-/Ziel-Markern, Stop-Liste als vertikale Timeline mit Punkten, moderne
Chips/Buttons. Die Referenz-URL beim Lauf per WebFetch laden und die
Design-Sprache konkret extrahieren; falls die Seite nicht erreichbar ist, mit
der obigen Beschreibung + `design-library`-Skill + Benchmark arbeiten.

## Harte Anforderungen (Andre wörtlich)

1. **Routen sauber und modern darstellen** — die Linienführung und Pins sollen
   hochwertig wirken (Stichwort: geschwungene/kurvige Routen statt gerader
   Segmente — das offene Item B4.3b-3).
2. **Burger-Menü oben rechts** zur Routen-Auswahl. Standardmäßig sind **alle**
   Routen sichtbar; mit **einem Klick** lassen sich alle abwählen.
   (Heute: Funnel-Menü oben links + „Routen"-Capsule in der Bottom-Card —
   beides wird durch das neue Burger-Menü oben rechts ersetzt.)
3. **Tap auf eine Route → Hochswipe-Menü (Bottom Sheet)** öffnet sich unten mit
   den Routen-Details (Häfen/Stops). **Tap auf einen Ort** im Sheet springt die
   Karte direkt an diese Stelle. (Das ist das offene Item B4.3b-2 —
   `presentationDetents` oder eigener Detent-Sheet.)
4. **Modern und ansprechend** — Design-Agents/Skills nutzen und recherchieren
   (designer-Agent, `design-library`, `design-benchmark`, `swiftui`-Skill).

## Bestandsaufnahme (Stand 2026-07-09)

- `ShipTrip/Views/Map/MapView.swift` (543 Z.) — kompletter Weltkarten-Screen:
  `Map` + `MapPolyline` (Zeile ~151), Zwei-Zoom-Stufen-Logik
  (`MapZoomBucketPlanner`, Schwelle 10°), Rollen-Pins via `MapMarkerPlanner`
  (Zeilen 29–83), Filter über zwei `Menu`s (`routeMenuItems`, ~388–436),
  Bottom-Info-Card als `.ultraThinMaterial`-Overlay (`routeSelectionCard`,
  ~287–347). State: `selectedRouteIDs: Set<UUID>`, `primaryCruiseID`,
  `selectedStopID`.
- `ShipTrip/Views/Map/MapStopBadgeView.swift` (39 Z.) — nummerierte Stop-Badges.
- `ShipTrip/Views/Map/MapCalloutView.swift` (40 Z.) — Pin-Callout mit Foto.
- `ShipTrip/Components/PortPinView.swift` (93 Z.) — geteilte Rollen-Pins
  (`PortPinType`: Start orange / Hafen blau / Endpunkt grün / Seetag).
- Datenfluss: `Cruise.route: [Port]`, `Port.latitude/longitude/sortOrder/
  isSeaDay/hasValidCoordinates`. Rundreisen-Kollaps in `MapMarkerPlanner`.
- Design-Tokens: `ShipTrip/Utilities/Color+Theme.swift` — `oceanBlue`,
  `navyDark`, `sunsetOrange`, `seaGreen`, Pin-Tokens, `routeColors`/
  `routeColor(at:)`, `DesignRadius` (sm 10 / md 16 / lg 28).
- Vorarbeiten: `docs/features/karten-redesign-b4.md` (offene Items B4.3b-2
  Bottom-Sheet, B4.3b-3 Kurven), Design-Deck
  `docs/ux-pitch-decks/b4-karten-redesign.html`,
  `.planning/b4-design-benchmark.md`, `.planning/b4-fertigloesungen-research.md`
  (Entscheidung: nativ MapKit bleiben, kein Fremd-SDK).
- Einziger bestehender `presentationDetents`-Einsatz:
  `CruiseFormView.swift:984` (Höhe 320) — als Muster nutzbar.

## Technische Leitplanken

- Swift 6, SwiftUI, natives MapKit (ADR-Entscheidung: kein Fremd-SDK).
- Kurvige Routen: z. B. `MapPolyline` mit interpolierten Zwischenpunkten
  (Quadratic-Bezier/Great-Circle-Sampling) — recherchieren, was mit SwiftUI-Map
  sauber geht; Zoom-Stufen-Logik (`MapZoomBucketPlanner`) erhalten.
- Neue user-sichtbare Strings zweisprachig als `String(localized:)`.
- Bestehende Tokens/Komponenten wiederverwenden (`Color+Theme`, `PortPinView`,
  `MapStopBadgeView`); Stil des Codes spiegeln (deutsche Doc-Kommentare,
  `// MARK:`).
- Bestehende Unit-Tests (`MapMarkerPlanner`/`MapSelectionPlanner`/
  `MapZoomBucketPlanner` in `ShipTripTests/`) müssen weiter grün sein;
  neue Logik (Sheet-Sync, Kurven-Sampling, Select-All/None) testen.
- Build/Test über Xcode-MCP (`BuildProject`, `RunAllTests`) oder
  `xcodebuild -scheme ShipTrip`; Test-Builds strikt seriell.
- Verifikation im Simulator: Screenshots der neuen Karte (hell/dunkel,
  Welt-Zoom + Routen-Zoom + geöffnetes Sheet) unter `audit/screenshots/`
  ablegen und selbst ansehen.

## Ablauf (Wellen)

1. **Design** — designer-Agent(s) + `design-library`/`design-benchmark`/
   `ui-mockup-html`: Referenz analysieren und **3 unterscheidbare
   Design-Richtungen** erarbeiten (klickbares HTML-Deck unter
   `docs/ux-pitch-decks/karten-redesign-v2-richtungen.html`, CSS-only
   iPhone-Mockups, alle nativ SwiftUI/MapKit baubar). Winston wählt die
   stärkste Richtung **begründet** aus (Begründung ins Abschluss-Protokoll)
   und leitet daraus das Design-Spec ab
   (`.planning/karten-redesign-v2-spec.md`) mit Layout, Burger-Menü,
   Sheet-Detents, Routen-Stil, Token-Mapping.
2. **Implementierung** — developer-Agent(s): MapView-Umbau gemäß Spec
   (Burger-Menü oben rechts, Alle-an/aus, Bottom-Sheet mit Stop-Liste +
   Kamera-Sprung, kurvige Routen, Politur).
3. **Qualität** — quality-Agent: Build grün, alle Tests grün, Simulator-
   Screenshots prüfen (Review-Artefakt `.planning/quality-review-karten-v2.md`).
   Max. 3 Iterationen Feedback-Loop.
4. **Release** — golive-Agent: CHANGELOG.md (Keep a Changelog), Version
   **1.7.0 (Build 16)** setzen, Commit(s) auf `main` + Push, Archiv + Export +
   TestFlight-Upload, „Was ist zu testen"-Text (de-DE) setzen, Build zur
   internen Gruppe **und** zur externen Gruppe „VIP Extern" hinzufügen +
   Beta-Review einreichen.

## Release-Anleitung (aus Projektgedächtnis, verbindlich)

Details in `~/.claude/projects/-Users-andreja-Documents-0-Projekte-ShipTrip/memory/shiptrip-release-setup.md` — vor der Release-Welle lesen. Kernpunkte:

- Env-Quelle: `source ~/.secrets/appstore-connect.env` → `ASC_KEY_ID`,
  `ASC_ISSUER_ID`, `ASC_KEY_PATH`. App-ID `6756786576`, Team `LH324Y9MG7`.
- Xcode-Signing-Workaround: `fastlane fetch_profile`, dann Export mit
  manuellem Signing (Profil „ShipTrip App Store", Cert „Apple Distribution:
  André Jaszka (LH324Y9MG7)").
- Upload-Lane erwartet hart `build/export/ShipTrip.ipa` — IPA ggf. dorthin
  kopieren; dann `fastlane upload_testflight`.
- Externe Verteilung (Spaceship über fastlane-Ruby-Env, siehe Memory-Datei):
  `add_beta_groups_to_build(build_id:, beta_group_ids: [VIP-Extern-ID])`,
  danach `post_beta_app_review_submissions(build_id:)` — ohne diese Einreichung
  bekommt Stefanie das Build nicht.

### Sicherheitsregeln (wörtlich in jeden golive/Upload-Spawn-Prompt)

1. Den `.p8`-Key **niemals** kopieren oder als Datei/JSON auf Platte schreiben —
   ausschließlich per Pfad referenzieren (`key_filepath: ENV['ASC_KEY_PATH']`).
2. **Niemals** `.inspect`/`puts obj.inspect` auf Spaceship-API/Token/Response/
   Build-Objekte — nur benannte Attribute ausgeben.
3. `fastlane run <action>` auf ASC-/Credential-Actions ist als Diagnose
   **verboten** (druckt den Roh-Key) — nur die bestehenden Fastfile-Lanes nutzen.
4. Nach der Release-Session `/tmp/spaceship*.log` auf Streuner prüfen.

## Abnahmekriterien

- [ ] 3 Design-Richtungen als HTML-Deck vorhanden; Richtungs-Wahl begründet
      dokumentiert; die gewählte Richtung wurde umgesetzt.
- [ ] Neue Karte entspricht den 4 harten Anforderungen oben.
- [ ] Build + alle Tests grün; Screenshots hell/dunkel erstellt und geprüft.
- [ ] CHANGELOG + Version 1.7.0 (16), Commits auf `main`, gepusht.
- [ ] TestFlight-Upload erfolgreich; Build in „VIP Tester" verfügbar.
- [ ] Build zu „VIP Extern" hinzugefügt + Beta-Review-Submission im Zustand
      `WAITING_FOR_REVIEW` (Apple-Freigabe selbst dauert dann noch).
- [ ] Kurzes Abschluss-Protokoll nach `.planning/karten-redesign-nachtjob-log.md`
      (was gemacht, was offen, Screenshots-Verweise) für Andres Morgen-Review.
