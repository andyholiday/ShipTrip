# Quality Review — Welle I1 (S1.1–S1.5, S2.1a) · Iteration 1

Scope: uncommitted working-tree diff (git status), gegen `docs/umsetzungsplan-audit-2026-07-10.md`.
Read-only, kein Build/Testlauf durchgeführt (Build-Token beim Orchestrator).

## Verdict: GO (mit 2 Kann-Fixes)

Keine critical- oder acceptance-blockierenden Findings. Alle geprüften Akzeptanzkriterien
sind statisch erfüllt. Zwei major/minor UX-Konsistenz-Findings, kein Blocker.

## 1. Akzeptanzkriterien je Task

- **S1.1** (CruiseListView/CruiseDetailView, H1+H5): erfüllt. `ContentUnavailableView` mit
  Reset-Action im Empty-State (`CruiseListView.swift:88-95`); `confirmationDialog` vor
  beiden Context-Menü-Löschungen; Sequenz `delete → save() → catch{rollback()+Alert} →
  Notification-Removal NACH Save` in beiden Views identisch umgesetzt
  (`CruiseListView.swift:352-368`, `CruiseDetailView.swift:434-448`). Fire-and-forget-Pfad
  in Detail korrekt mit-saniert (Notification-Removal verschoben hinter `try save()`).
- **S1.2** (PortFormView + TempPortFormSheet, H2+M5): erfüllt. Expliziter
  `isManualEntry`-Zustand statt `if name.isEmpty` (`PortFormView.swift:64-67`,
  `loadExistingData()` setzt ihn bei Bestandsport); `parseCoordinate()` (Komma+Punkt,
  `nil` bei ungültig) ersetzt `Double(_:) ?? 0`; Save-Button zusätzlich per
  `isCoordinateValid` gesperrt. `clampedDeparture()` in `CruiseFormView.swift:993` deckt
  Abfahrt≥Ankunft auch in `TempPortFormSheet.savePort()` (Zeile 1149) ab, plus
  `DatePicker(..., in: arrivalDate...)` als zusätzliche UI-Sperre. Unit-Tests für
  Grenzfälle „53,5"/„-33,86"/Müll/leer sowie clampedDeparture vorhanden und aussagekräftig.
- **S1.3** (DealsView, H4): erfüllt. Hero (Context-Menü) UND Formular (Toolbar-Button)
  haben jetzt einen bestätigten Lösch-Pfad mit derselben Save/Rollback-Sequenz.
- **S1.4** (ExportImportService, H3): erfüllt. `isSeaDay: Bool? = nil` per
  `decodeIfPresent`-Semantik (Codable-Synthese), Priorität explizites Flag > Namens-Fallback,
  `lat == nil` klassifiziert nicht mehr. Vier neue Tests decken Alt-Format-Fallback (mit und
  ohne Namens-Match) sowie Neu-Format-Override in beide Richtungen ab — inhaltlich gut,
  keine Trivial-Asserts.
- **S1.5** (PrivacyInfo.xcprivacy, H7): Manifest vorhanden mit
  `NSPrivacyAccessedAPICategoryUserDefaults` (Reason CA92.1) und `…FileTimestamp` (Reason
  3B52.1). Grep bestätigt: alle `UserDefaults`-Zugriffe im Code (`IdBackfill.swift`,
  `ShippingLineCatalogDedup.swift`, `CruiseFormView.swift:884/936`,
  `NotificationService.swift`) sind app-eigene Keys ohne App-Group/Shared-Container — CA92.1
  ("Access info from same app") passt. 3B52.1 passt zum genannten
  `ZipArchiveReader.swift:69`-`attributesOfItem`-Zusatzfund. Build-Aufnahme ins Produkt
  (project.pbxproj-Membership) konnte ich statisch nicht verifizieren (kein Build erlaubt) —
  das ist aber ausdrücklich Sache des parallel laufenden Build-Checks, nicht dieses Reviews.
- **S2.1a** (Date+Extensions, ZipArchiveWriter, GeminiService-Anteil): erfüllt. Alle
  hartkodierten Strings in den drei genannten Dateien jetzt `String(localized:)`. Die
  GeminiService-Übernahme ist durch Andres Entscheidung 1 gedeckt (S2.4 ruht) — kein
  Scope-Konflikt. `ExportImportService.swift:493-497` wurde korrekt NICHT angefasst
  (bleibt S2.2).

## 2. Simplicity First / Surgical Changes

Kein Over-Engineering gefunden. Alle Diffs sind eng auf die genannten Zeilenbereiche
begrenzt. `parseCoordinate`/`clampedDeparture` sind angemessen simple Free-Functions ohne
unnötige Abstraktion. Keine unangeforderten Refactorings in Nachbarcode. Die
`accessibilityIdentifier("filterMenuButton")`-Ergänzung ist testgetrieben (von der neuen
UI-Test-Datei benötigt) und minimal.

## 3. Konsistenz der Lösch-Muster — 2 Findings

**Finding A (minor) — uneinheitlicher Alert-Titel für identischen Fehlerfall.**
`CruiseListView.swift:131` und `CruiseDetailView.swift:108` betiteln den
Save-Fehler-Alert `"Info"` (deckungsgleich mit dem etablierten Muster aus
`SettingsView.swift:494` `deleteAllData`). `DealsView.swift:188` und `:446` betiteln
denselben Fehlerfall (`"Löschen fehlgeschlagen: " + error.localizedDescription`) mit
`"Fehler"`. Beide Titel-Strings existieren bereits im Katalog, aber die Abweichung
fragmentiert unnötig ein und denselben Anwendungsfall.
Fix-Vorschlag: `DealsView` auf `"Info"` umstellen (matcht Projekt-Konvention) — 4 Stellen.

**Finding B (major) — Presentation-Widget uneinheitlich für dieselbe Lösch-Bestätigung.**
`CruiseListView.swift:114` (neu) und `DealHeroView` (`DealsView.swift:176`, neu) nutzen
`.confirmationDialog` (Action-Sheet). `CruiseDetailView.swift:100` (unverändert,
vorbestehend) und `DealFormView` (`DealsView.swift:440`, neu) nutzen `.alert`. Damit hat
S1.1 für exakt dieselbe Aktion ("Kreuzfahrt löschen?", identischer Titel-String) in Liste
und Detail zwei unterschiedliche UI-Pattern, und `DealsView` hat *innerhalb derselben
Datei* für "Eintrag löschen?" beide Widget-Typen parallel (Hero: Dialog, Formular: Alert).
Der Task-Text forderte explizit "Lösch-Sequenz überall (Liste UND Detail)" — die
Datenfluss-Sequenz (delete→save→rollback→Notification) ist tatsächlich identisch, aber die
Bestätigungs-UI ist es nicht. Nicht akzeptanzkritisch (beide sind valide iOS-Pattern für
destruktive Bestätigung, Titel-Wortlaut ist korrekt gleich), aber ein systemweites
UI-Pattern-Inkonsistenz-Finding im Sinne der Major-Definition.
Fix-Vorschlag: einheitlich auf `.alert` ziehen (matcht die 2 vorbestehenden Stellen
CruiseDetailView + SettingsView — 3:2 Präzedenz) — betrifft `CruiseListView.swift:114-129`
und `DealHeroView` in `DealsView.swift:176-186`.

**Nebenbefund (kein neues Finding, nur Hinweis):** `DealsView.deleteListDeals` (Zeile 88-92,
swipe-to-delete auf Nicht-Hero-Zeilen, in diesem Diff unangetastet) hat weiterhin keine
Bestätigung und keinen save/rollback-Fehlerpfad. Das liegt außerhalb des S1.3-Scopes (H4
betraf nur die Erreichbarkeit des Hero-Löschens), daher kein Fix hier nötig — nur zur
Kenntnisnahme für einen möglichen Folge-Task.

## 4. Test-Qualität

- `CruiseLoeschenFilterUITests.swift`: Die Filter-Kombination "2025 + AIDA Cruises" als
  garantierter Null-Treffer ist gegen `DemoDataService.swift` verifiziert — "Norwegische
  Fjorde" ist die einzige AIDA-Cruise und immer `today+21` Tage (nie 2025), die beiden
  anderen Demo-Reisen sind 2025, aber nicht AIDA. Die referenzierten
  `accessibilityIdentifier`s (`heroCard`, `filterMenuButton`) existieren exakt dort, wo der
  Test sie erwartet. Kein Snapshot-only, prüft echtes Verhalten (Reset + Listenrückkehr,
  Dialog-Abbrechen vs. Bestätigen). Solide.
- `DealLoeschenUITests.swift`: legt den Test-Eintrag selbst an (unabhängig von Demo-Daten,
  da Hero über `\Deal.createdAt` `.reverse` sortiert ist) — robuster als eine
  Demo-Daten-Annahme. `press(forDuration: 1.2)` für Kontextmenü ist Standard-Pattern im
  Projekt (siehe `CruiseLoeschenFilterUITests` mit 1.0s), leicht abweichende Dauer (1.0 vs.
  1.2s) ist funktional irrelevant, aber unnötige Streuung — minor Nit, kein Fix nötig.
- `ExportImportHardeningTests.swift` (Seetag-Klassifikation): vier Tests decken die volle
  Faltmatrix ab (Alt-Format ± Namens-Match, Neu-Format ± Namens-Match-Override) inkl.
  Re-Export-Roundtrip-Check, dass Name/Land nicht überschrieben werden. Gute Testtiefe,
  keine trivialen Asserts.
- `PortFormViewTests.swift`: `parseCoordinate`- und `clampedDeparture`-Suiten decken die im
  Task genannten Grenzfälle ab (Komma, negativ, Punkt, Müll, leer/whitespace;
  Abfahrt<Ankunft/gleich/danach). Angemessen.

## 5. Lokalisierung — konsolidierte Liste neuer Keys (Input für S2.1b-1)

Per Katalog-Abgleich (`Localizable.xcstrings`) bereits vorhandene, korrekt wiederverwendete
Keys aus diesem Diff: `"Kreuzfahrt löschen?"`, `"Filter zurücksetzen"`,
`"Diese Aktion kann nicht rückgängig gemacht werden."`, `"Manuell eingeben"`,
`"Eintrag hinzufügen"`, `"Fehler"`, `"Info"`, `"Löschen"`, `"Abbrechen"`, `"OK"`.

**Neue, im Katalog fehlende Keys** (Stand dieses Diffs, für S2.1b-1):

1. `"Eintrag löschen?"` — DealsView (Hero-Dialog-Titel + Form-Alert-Titel)
2. `"Löschen fehlgeschlagen: "` — Präfix-String, verwendet in CruiseListView,
   CruiseDetailView, DealsView (×2); **war bereits vor dieser Welle in SettingsView
   verwendet und fehlte dort schon im Katalog** (Alt-Lücke, keine Neu-Einführung durch
   diese Welle, aber jetzt mit 4 weiteren Verwendungsstellen — sollte in S2.1b-1 sowieso
   mit rein).
3. `"Ungültige Koordinate – bitte z. B. „53,5" oder „53.5" eingeben"` — PortFormView
   Validierungshinweis
4. GeminiService (8 Keys): `"Kein API-Key konfiguriert"`, `"Ungültige URL"`,
   `"Ungültige Anfrage"`, `"Ungültiger API-Key"`, `"API-Kontingent überschritten"`,
   `"Netzwerkfehler"`, `"Serverfehler (\(code))"`, `"Ungültige Antwort"`
5. ZipArchiveWriter (4 Keys, alle mit Interpolation): `"ZIP-Eintragsname konnte nicht als
   UTF-8 kodiert werden: \(name)"`, `"Zu viele ZIP-Einträge (\(count)); Maximum ist
   \(UInt16.max)"`, `"ZIP-Eintrag '\(name)' ist zu groß (\(size) Bytes); Maximum ohne ZIP64
   ist \(UInt32.max) Bytes"`, `"ZIP-Archiv zu groß (\(size) Bytes); Maximum ohne ZIP64 ist
   \(UInt32.max) Bytes"`
6. Date+Extensions (9 Keys, teils neu gesplittet wegen Pluralisierung):
   `"Bereits vorbei"`, `"Heute!"`, `"Morgen"`, `"In \(days) Tagen"`, `"In \(days / 7)
   Woche"`, `"In \(days / 7) Wochen"`, `"In ca. \(days / 7) Wochen"`, `"In \(days / 30)
   Monat"`, `"In \(days / 30) Monaten"`

Abgleich-Kommando verwendet: Python-JSON-Parse gegen `ShipTrip/Localizable.xcstrings`
`strings`-Dict (exakter Key-Match). Kein user-sichtbarer String in den S1.x/S2.1a-Scope-
Dateien ohne `String(localized:)`-Pfad gefunden — Akzeptanzkriterium S2.1a erfüllt.

## 6. GDPR / OWASP

Keine neuen personenbezogenen Daten, keine neuen Netzwerk-/Storage-Zugriffe außerhalb der
bereits deklarierten Kategorien. Löschpfade stärken eher das Recht auf Löschung (Bestätigung
+ Rollback statt stillem Fehlschlag). `parseCoordinate` validiert Eingaben statt sie
stillschweigend auf 0 zu klemmen — verbessert Robustheit, keine Injection-Fläche (reiner
NumberFormatter, kein Eval/Parsing von Code). `error.localizedDescription` in Alerts ist
vorbestehendes Projekt-Pattern (SettingsView), keine Neu-Einführung durch diese Welle.

## Bekannte akzeptierte Ausnahme

`PortFormView.swift` = 531 Zeilen (>500-Limit). Bestätigt per `wc -l`. Laut Auftrag bewusst
zurückgestellt (S4.3-Refactor), kein Finding.

Geladene Skills: code-review, swift-standards, swiftui
