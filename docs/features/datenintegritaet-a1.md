# Welle A1 — Datenintegrität

**Status:** Abgeschlossen
**Testsuite:** 68/68 Unit-Tests PASS (`CruiseFormRouteReconciliationTests`,
`ExportImportHardeningTests` neu hinzugekommen)
**Quelle:** [Umsetzungsplan Audit 2026-07](../umsetzungsplan-audit-2026-07.md#welle-a1--datenintegrität),
[Voll-Audit 2026-07-03](../../audit/audit-2026-07-03.html)

## Beschreibung

Welle A1 behebt vier Datenintegritäts-Findings aus dem Voll-Audit: den
Edit-Datenverlust beim Bearbeiten von Reisen (importierte Ausflüge und
Hafenbilder gingen verloren, Port-IDs wurden neu vergeben), fehlende
Hafenbilder im ZIP-Export, unzureichend gehärtete ZIP-Imports (Pfad-Traversal,
Dekompressionsbomben) sowie eine unvollständige „Alle Daten löschen"-Funktion.

---

## A1.1 — Edit-Datenverlust-Fix (CruiseFormView)

### Was / Warum

Bisher wurden beim Speichern einer bearbeiteten Reise alle bestehenden
`Port`-Objekte gelöscht und aus `tempPorts` neu angelegt. Damit gingen
importierte Ausflüge (`excursionsRaw`) und Hafenbilder (`imageData`) verloren,
und jeder Hafen erhielt eine neue `id` — ein Bruch der in
[ADR-002](../adr/ADR-002-cloudkit-sync-und-stabile-ids.md) festgelegten
ID-Stabilität.

Die neue Funktion `reconcileRoute(...)` gleicht `tempPorts` mit den
bestehenden `Port`-Objekten per stabiler `id` ab: bekannte Ports werden
in-place aktualisiert, nur tatsächlich entfernte Ports werden gelöscht, neue
Ports eingefügt. `TempPort` transportiert dafür zusätzlich `id`,
`excursionsRaw` und `imageData`; `TempPortFormSheet` übernimmt diese Felder
beim Öffnen eines bestehenden Hafens zum Bearbeiten. Doppelte IDs innerhalb
von `tempPorts` (inkonsistenter Zwischenzustand) werden vor dem Abgleich
dedupliziert.

### Berührte Dateien

- `ShipTrip/Views/Cruises/CruiseFormView.swift` (`reconcileRoute`, `TempPort`,
  `TempPortFormSheet`, `saveCruise`)

### Acceptance-Status

Erfüllt. Abgedeckt durch `ShipTripTests/CruiseFormRouteReconciliationTests.swift`
(Edit einer Reise mit Ausflügen/Hafenbild erhält Daten und Port-`id` bei
unveränderten sowie bei geänderten Ports).

---

## A1.2 — Hafenbilder im ZIP-Export

### Was / Warum

Der ZIP-Export schrieb bisher nur Reise- und Ausflugsfotos, keine
Hafenbilder. Hafenbilder werden jetzt unter
`images/<cruiseId>/ports/<index>` als Rohbytes exportiert; `imageUrl` im
`data.json` verweist auf diesen Pfad. Der Import las Hafenbilder bereits
zuvor korrekt ein, sodass der Roundtrip jetzt verlustfrei ist. Der Legacy-JSON-
Export (ohne ZIP) bleibt unverändert (`imageUrl` weiterhin `nil`).

### Berührte Dateien

- `ShipTrip/Services/ExportImportService.swift` (Export-Pfad für Port-Bilder)

### Acceptance-Status

Erfüllt. Roundtrip-Test mit Port-Bild in
`ShipTripTests/ExportImportHardeningTests.swift` bestätigt Verlustfreiheit.

---

## A1.3 — Import-Härtung (ZIP-Slip, Dekompressionsbomben, Duplikate)

### Was / Warum

Der ZIP-Import verarbeitete Einträge und `data.json`-Pfadreferenzen bisher
ohne Pfad-Validierung und ohne Größenlimits. Neu:

- **Safe-Path-Resolver** (`resolveSafePath`): prüft rohe Pfadkomponenten vor
  jeder Normalisierung gegen Traversal-Aliase (`..`, absolute Pfade) und
  erzwingt, dass der aufgelöste Pfad ein Präfix des Zielordners bleibt.
- **Größenlimits** gegen Dekompressionsbomben: 50 MB pro Eintrag, 500 MB
  kumuliert — geprüft für komprimierte **und** unkomprimierte Größe, jeweils
  vor jeder Speicher-Allokation. Das Gesamtarchiv ist zusätzlich auf 550 MB
  gedeckelt. `STORED`-Einträge (keine Kompression) verlangen
  `compressedSize == uncompressedSize`, sonst Ablehnung (`sizeMismatch`).
- **Datei-interne Cruise-ID-Duplikate** (mehrere Reisen mit derselben `id`
  innerhalb einer importierten Datei) werden erkannt und übersprungen statt
  dupliziert übernommen.
- Maschinenlesbare Zahlenformate (Koordinaten) nutzen `en_US_POSIX` statt
  Geräte-Locale, damit z. B. Komma-Dezimaltrennzeichen den Import nicht
  brechen.

### Berührte Dateien

- `ShipTrip/Services/ExportImportService.swift` (`resolveSafePath`,
  Größenlimit-Konstanten, `ImportError.sizeMismatch`, POSIX-Locale)

### Acceptance-Status

Erfüllt. `ShipTripTests/ExportImportHardeningTests.swift` deckt: präpariertes
Slip-ZIP wird abgelehnt, überdimensionierter Größen-Header wird abgelehnt,
datei-interne ID-Duplikate führen zu genau einer importierten Reise.

---

## A1.4 — „Alle Daten löschen" vollständig (SettingsView)

### Was / Warum

Die Funktion löschte bisher Modelldaten, aber weder geplante
Benachrichtigungen noch (optional) den Gemini-API-Key, und ein
fehlschlagendes `save()` konnte zu inkonsistentem Zustand führen. Neu:
Löschung und `save()` laufen zuerst; schlägt `save()` fehl, werden die
gestagten Deletes zurückgenommen (kein Seiteneffekt, Alert an den Nutzer).
Erst nach erfolgreichem Speichern werden geplante Erinnerungen entfernt
(`NotificationService.removeAllPendingNotifications()`). Der Gemini-API-Key
wird nur gelöscht, wenn der Nutzer dies in einem expliziten Folge-Dialog
(„KI-API-Key auch löschen?") bestätigt.

### Berührte Dateien

- `ShipTrip/Views/Settings/SettingsView.swift` (`deleteAllData`,
  Bestätigungsdialog)

### Acceptance-Status

Erfüllt (manuell verifiziert): nach Löschen sind keine Erinnerungen mehr
geplant; Key-Wahl im Dialog wird respektiert; fehlgeschlagenes Speichern
hinterlässt keine Seiteneffekte.

---

## Offene Punkte

- Fallback-Deduplizierung ohne UUID (z. B. Titel + Datum) innerhalb einer
  importierten Datei existiert weiterhin nicht — nur der neue
  Cruise-ID-Duplikat-Check (A1.3) greift.
- Port- und Expense-ID-Duplikate *innerhalb* eines Imports sind nicht
  gehärtet (nur auf Cruise-Ebene geprüft).
- Kein isolierter Test für den reinen `sizeMismatch`-Fall (STORED-Eintrag mit
  `compressedSize != uncompressedSize`) unabhängig vom Größenlimit-Test.

## Verwandte Entscheidungen

- [ADR-002: CloudKit-Sync, stabile IDs und ZIP-Export](../adr/ADR-002-cloudkit-sync-und-stabile-ids.md)
