# Verifikation V4 — Lokalisierung (H6) + Privacy-Manifest (H7)

Bezug: Voll-Audit 2026-07-10, Commit 687657c. Read-only, statisch-analytisch,
keine Builds/Tests/Codeänderungen.

## H6 — Englische UI fällt in Kernbereichen auf Deutsch zurück

**Urteil: CONFIRMED** (Zahl leicht abweichend von Audit-Schätzung, Kernaussage korrekt)

### (a) Katalog-Schlüssel zählen

```
python3 -c 'import json; d=json.load(open("ShipTrip/Localizable.xcstrings")); print(len(d["strings"]))'
```
→ **185 Schlüssel** im Katalog. `sourceLanguage: "de"`.

### (d) Haben die 185 Schlüssel EN-Übersetzungen?

Alle 185 Einträge geprüft auf `localizations.en.stringUnit.value` (nicht-leer):
**185/185 (100 %) haben eine nicht-leere EN-Übersetzung.** Keiner der Katalog-Einträge
hat ein `extractionState`-Feld (weder "manual" noch "extracted_with_value") — der
Katalog ist vollständig manuell kuratiert, kein automatischer Xcode-Sync bisher
eingecheckt.

→ **Differenzierung wichtig:** Das Problem liegt NICHT bei fehlenden Übersetzungen
vorhandener Keys, sondern ausschließlich bei Code-Strings, die noch nie in den
Katalog aufgenommen wurden.

### (b)+(c) Code-Strings vs. Katalog

Regex-Extraktion aller `String(localized: "literal")`-Aufrufe in `ShipTrip/**/*.swift`
(escape-sicher, mehrzeilig-tolerant):

```
Distinct literal String(localized:) keys im Code: 97
Davon OHNE exakten Katalog-Eintrag: 63
```

Das deckt sich mit den Audit-Beispielen — alle drei genannten Fundstellen bestätigt:
- `CruiseListView.swift:72,74` — beide dort verwendeten Strings fehlen im Katalog
- `MapView.swift:103,105` — "Keine Häfen auf der Karte" / "Füge Häfen zu deinen
  Reisen hinzu, um sie hier zu sehen" fehlen
- `StatsView.swift:50,63` — "Gesamterinnerung" sowie der interpolierte
  Archiv-Satz fehlen

(Audit nannte ~68 — die Abweichung zu 63 kommt vermutlich daher, dass das Audit
zusätzlich `Text("literal")`-Auto-Extraktionen oder ein paar Randfälle
mitgezählt hat; Kernaussage und Größenordnung stimmen.)

### (e) Auto-Sync-Nuance (wichtig für Fix-Umfang)

Geprüft: Xcode kann `String(localized:)`- und `Text("literal")`-Aufrufe beim Build
automatisch in den `.xcstrings`-Katalog synchronisieren (`SWIFT_EMIT_LOC_STRINGS`,
Standard an). Das ändert aber **nichts am Laufzeitverhalten**: Auto-Sync fügt den
Key nur mit Status "neu"/unübersetzt hinzu — es erzeugt KEINE EN-Übersetzung.
Ohne `en`-Eintrag fällt die String-Catalog-Runtime bei englischem Gerät immer auf
die `sourceLanguage` (Deutsch) zurück. Ergebnis: unabhängig davon, ob die 63
fehlenden Keys inzwischen durch einen Build automatisch in die Datei geschrieben
wurden oder nicht — der User sieht in jedem Fall Deutsch, bis jemand manuell eine
EN-Übersetzung einträgt. Die "Katalog-Datei fehlt Key"-Beobachtung und die
"User sieht Deutsch"-Beobachtung sind also deckungsgleich, nicht zwei getrennte
Probleme.

Zusätzlich bestätigt: zwei der im Code interpolierten `String(localized:)`-Aufrufe
SIND bereits korrekt im Katalog vertreten, weil Xcode Interpolationen als
Format-Keys ablegt:
- `"In \(daysUntilStart) Tagen"` → Katalog-Key `"In %lld Tagen"` (vorhanden, übersetzt)
- `CruiseFormView.swift:752` Validierungstext → wortgleich im Katalog vorhanden

Aber mehrere interpolierte Aufrufe fehlen trotzdem komplett (kein passender
Format-Key im Katalog):
- `"Stopp \(role.stopNumber) von \(totalStops)"` (MapView+RouteInteraction.swift:182)
- `"Stopp \(number)"` (MapStopBadgeView.swift:31)
- `"\(routes.count) Reisen"` (MapView.swift:356) — nur die Singular-Form "Reisen" ohne Zahl ist im Katalog
- StatsView.swift:63 Archiv-Zusammenfassungssatz (3-fach interpoliert)
- `CruiseListView.swift:72,74` Untertitel-Sätze

### (e) Dynamische Titel, die Lokalisierung GANZ umgehen (kein `String(localized:)`, keine `Text()`-Auto-Extraktion — echte Bugs, nicht durch Katalog-Pflege allein fixbar)

Gefunden über Grep nach `return "<Großbuchstabe><Kleinbuchstaben>...`, die nie
`String(localized:)` durchlaufen:

1. `ShipTrip/Utilities/Date+Extensions.swift:63-75` — relative Datumsanzeige
   ("Bereits vorbei", "In X Tagen", "In X Wochen", "In ca. X Wochen",
   "In X Monaten") — **plain String-Extension, gibt hartkodiertes Deutsch
   zurück, nie über Catalog/String(localized:).** Wird u. a. für
   Cruise-Countdown-Anzeigen verwendet → zeigt IMMER Deutsch, unabhängig vom
   Katalog-Zustand.
2. `ShipTrip/Services/ExportImportService.swift:493,495,497` — Fehlermeldungen
   ("Keine data.json in der ZIP-Datei gefunden", "Ungültiges Dateiformat",
   "Unsicherer Pfad im Archiv abgelehnt: ...") — `LocalizedError.errorDescription`
   mit hartkodiertem Deutsch.
3. `ShipTrip/Services/GeminiService.swift:214-228` — API-Fehlermeldungen
   ("Kein API-Key konfiguriert", "Ungültige URL", "Ungültiger API-Key",
   "Serverfehler (...)", "Ungültige Antwort").
4. `ShipTrip/Services/ZipArchiveWriter.swift:223` — "Zu viele ZIP-Einträge (...)".

Diese vier Stellen sind eine eigene Fehlerklasse: kein Katalog-Eintrag kann sie
je fixen, weil der Code nie den Catalog-Mechanismus aufruft — Fix erfordert
Code-Änderung (`String(localized:)`-Wrapping), nicht nur Katalog-Pflege.

### Fix-Umfang für H6

1. 63 fehlende Keys (Liste siehe Anhang) in `Localizable.xcstrings` ergänzen +
   EN-Übersetzung eintragen (oder App neu bauen, damit Xcode sie automatisch
   mit Status "neu" einträgt, DANN übersetzen — Auto-Sync allein reicht nicht).
2. 4 Stellen mit hartkodierten Strings (Date+Extensions, ExportImportService,
   GeminiService, ZipArchiveWriter) müssen im Code auf `String(localized:)`
   umgestellt werden, bevor sie überhaupt katalogfähig sind.
3. Nach Code-Fix: erneuter Catalog-Sync-Check nötig, da neue Keys entstehen.

---

## H7 — Privacy-Manifest fehlt trotz Required-Reason-API

**Urteil: CONFIRMED** (Scope sogar etwas größer als im Audit angenommen)

### (a) `.xcprivacy`-Datei

```
find . -iname "*.xcprivacy"
```
→ **Kein Treffer.** Weder im Source-Tree noch sonst im Repo vorhanden.

### (d) pbxproj-Referenz

```
grep -n "xcprivacy\|PrivacyInfo" ShipTrip.xcodeproj/project.pbxproj
```
→ **Keine Referenz.** Das Projekt referenziert keine Privacy-Manifest-Datei,
auch nicht als fehlendes/rotes Build-Phase-Element. Bestätigt: nicht nur
"Datei fehlt", sondern auch "wurde nie ins Projekt aufgenommen".

### (b) UserDefaults / @AppStorage / @SceneStorage — vollständige Liste

`@AppStorage`:
- `MainTabView.swift:13` — `colorScheme`
- `SettingsView.swift:13` — `colorScheme`
- `SettingsView.swift:317-319` — `notifyBeforeCruise`, `notifyOnCruiseDay`, `reminderDaysBefore`

`UserDefaults.standard` direkt:
- `NotificationService.swift:55-56` — liest `notifyBeforeCruise`, `notifyOnCruiseDay`
- `NotificationService.swift:150-152` — liest dieselben plus `reminderDaysBefore`
- `CruiseFormView.swift:884,936` — Flag `hasShownNotificationDeniedHint` (im
  Original-Audit nicht erwähnt, aber real vorhanden)
- `IdBackfill.swift:47` — Completed-Flag für Migrations-Repair
- `ShippingLineCatalogDedup.swift:38` — Completed-Flag für Dedup-Lauf

`@SceneStorage`: keine Treffer.

Alle Nutzungen sind rein app-intern (Einstellungen, Migrations-Flags) — kein
App-Group-Sharing, keine Extension gefunden. → Kategorie
`NSPrivacyAccessedAPICategoryUserDefaults` erforderlich; korrekter Reason-Code
ist aus Apples aktueller offizieller Liste zu wählen (die im Original-Audit
vermutete "CA92.1" passt eher zu App-Group-Fällen — für reinen
Solo-App-Gebrauch ohne Extension ist der einschlägige Code separat gegen
Apples aktuelle Reason-Tabelle zu verifizieren, nicht blind übernehmen).

### (c) Weitere Required-Reason-APIs

- `systemBootTime` (`systemUptime`, `mach_absolute_time`): **keine Treffer.**
- `diskSpace` (`volumeAvailableCapacity`, `NSFileSystemFreeSize` etc.): **keine Treffer.**
- `activeKeyboards` (`UITextInputMode`, `activeInputModes`): **keine Treffer.**
- `fileTimestamp`: **1 zusätzlicher Treffer, im Original-Audit nicht genannt:**
  `ShipTrip/Services/ZipArchiveReader.swift:69` —
  `FileManager.default.attributesOfItem(atPath:)`. Zwar wird im Code nur
  `.size` ausgelesen, aber `attributesOfItem(atPath:)` steht als API-Signatur
  komplett auf Apples Required-Reason-Liste für die Kategorie
  `NSPrivacyAccessedAPICategoryFileTimestamp` — die Deklarationspflicht hängt
  an der API-Nutzung, nicht am konkret gelesenen Attribut.

→ Damit sind **zwei** Kategorien nötig, nicht nur eine: `UserDefaults` UND
`FileTimestamp`.

### Fix-Umfang für H7

1. `PrivacyInfo.xcprivacy` neu anlegen, ins App-Target aufnehmen (Copy-Bundle-Resources).
2. Kategorie `NSPrivacyAccessedAPICategoryUserDefaults` mit passendem Reason-Code
   (gegen aktuelle Apple-Liste verifizieren, nicht den Audit-Vorschlag
   ungeprüft übernehmen).
3. Kategorie `NSPrivacyAccessedAPICategoryFileTimestamp` für
   `ZipArchiveReader.swift:69` (Reason-Code ebenfalls gegen aktuelle Liste
   wählen, je nachdem ob Nutzung "nur eigene App-Daten" abdeckt).
4. `systemBootTime`, `diskSpace`, `activeKeyboards` — keine Deklaration nötig,
   keine Nutzung im Code gefunden.

---

## Anhang: 63 fehlende Katalog-Keys (H6, vollständige Liste)

| Key | Datei(en):Zeile |
|---|---|
| Heimathafen | PortPinView.swift:57; MapView+RouteInteraction.swift:178 |
| Endhafen | PortPinView.swift:58; MapView+RouteInteraction.swift:180 |
| Seetag | PortPinView.swift:59; MapView+RouteInteraction.swift:184 |
| Fehlt eine Reederei oder ein Schiff im Katalog? Hier kannst du eigene Einträge anlegen. | SettingsView.swift:109 |
| Dein Kreuzfahrt-Archiv | SettingsView.swift:183 |
| Archiv, Komfort und Premium-Funktionen an einem Ort. | SettingsView.swift:187 |
| Löschen fehlgeschlagen:  | SettingsView.swift:628; ShippingLineManagementView.swift:126,347 |
| Fehlt deine Reederei oder dein Schiff im Katalog? Lege sie hier selbst an. Katalog-Einträge kannst du per Wisch-Geste ausblenden, statt sie zu löschen. | ShippingLineManagementView.swift:39 |
| Eigene Reedereien | ShippingLineManagementView.swift:43 |
| Katalog-Reedereien | ShippingLineManagementView.swift:67 |
| Einblenden | ShippingLineManagementView.swift:87,385 |
| Ausblenden | ShippingLineManagementView.swift:87,385 |
| Aktion fehlgeschlagen:  | ShippingLineManagementView.swift:159,406 |
| Logo (Emoji) | ShippingLineManagementView.swift:184 |
| Reederei bearbeiten | ShippingLineManagementView.swift:194 |
| Eigene Reederei | ShippingLineManagementView.swift:194 |
| Diese Reederei ist bereits vorhanden — bitte den bestehenden Eintrag verwenden. | ShippingLineManagementView.swift:227 |
| Fehlt das Schiff dieser Reederei im Katalog? Lege es hier selbst an. | ShippingLineManagementView.swift:280 |
| Eigene Schiffe | ShippingLineManagementView.swift:284 |
| Aktive Schiffe (Katalog) | ShippingLineManagementView.swift:306 |
| Historische Schiffe (Katalog) | ShippingLineManagementView.swift:314 |
| Schiff bearbeiten | ShippingLineManagementView.swift:437 |
| Eigenes Schiff | ShippingLineManagementView.swift:437 |
| Dieses Schiff ist bei dieser Reederei bereits vorhanden. | ShippingLineManagementView.swift:465 |
| Beste Option | DealsView.swift:111 |
| Stopp \(role.stopNumber) von \(totalStops) | MapView+RouteInteraction.swift:182 |
| Öffnen | RouteStopSheetView.swift:190 |
| Keine Häfen auf der Karte | MapView.swift:103 |
| Füge Häfen zu deinen Reisen hinzu, um sie hier zu sehen | MapView.swift:105 |
| Route anzeigen | MapView.swift:270 |
| Alle Reisen | MapView.swift:354 |
| \(routes.count) Reisen | MapView.swift:356 |
| Stopp \(number) | MapStopBadgeView.swift:31 |
| Alle Reisen anzeigen | RouteMenuPanelView.swift:49 |
| ausgewählt | RouteMenuPanelView.swift:109 |
| nicht ausgewählt | RouteMenuPanelView.swift:109 |
| Gesamterinnerung | StatsView.swift:50 |
| Dein persönliches Kreuzfahrt-Archiv: \(uniqueCountries) Länder, \(uniquePorts) Häfen und \(cruises.count) Reisen. | StatsView.swift:63 |
| Reise öffnen | CruiseHeroCardView.swift:92 |
| Hafen-Momente | CruiseFormView.swift:1178; PortFormView.swift:283 |
| Stadtbummel | CruiseFormView.swift:1191; PortFormView.swift:296 |
| Strand | CruiseFormView.swift:1192; PortFormView.swift:297 |
| Wanderung | CruiseFormView.swift:1193; PortFormView.swift:298 |
| Bootstour | CruiseFormView.swift:1194; PortFormView.swift:299 |
| Museum | CruiseFormView.swift:1195; PortFormView.swift:300 |
| Shopping | CruiseFormView.swift:1196; PortFormView.swift:301 |
| Bild ersetzen | CruiseFormView.swift:1213; PortFormView.swift:318 |
| Entfernen | CruiseFormView.swift:1220; PortFormView.swift:325 |
| Cover-Foto hinzufügen | CruiseFormView.swift:1230; PortFormView.swift:335 |
| Ausflug entfernen | CruiseFormView.swift:1303; PortFormView.swift:408 |
| Nach oben | CruiseFormView.swift:1320; PortFormView.swift:425 |
| Nach unten | CruiseFormView.swift:1332; PortFormView.swift:437 |
| Fertig | CruiseFormView.swift:1346; PortFormView.swift:451 |
| Reihenfolge ändern | CruiseFormView.swift:1346; PortFormView.swift:451 |
| Ausflug hinzufügen | CruiseFormView.swift:1357,1364; PortFormView.swift:462,469 |
| \(cruises.count) Reisen · \(cruises.uniqueCountryCount) Länder · nächste Reise in \(days) Tagen | CruiseListView.swift:72 |
| \(cruises.count) Reisen · \(cruises.uniqueCountryCount) Länder · Reiselogbuch | CruiseListView.swift:74 |
| Reise \(hero.title) öffnen | CruiseListView.swift:149 |
| Neue Reise | CruiseListView.swift:189 |
| Reiselogbuch | CruiseListView.swift:199 |
| Reisejournal | CruiseDetailView.swift:119 |
| Reise | CruiseTimelineRowView.swift:27 |

(63 Zeilen — deckt sich mit der Extraktion oben.)
