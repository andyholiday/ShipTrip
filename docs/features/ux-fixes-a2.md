# Welle A2 — UX-Fixes

**Status:** Abgeschlossen
**Testsuite:** 73/73 Unit-Tests PASS (`ExpenseSortingTests` neu hinzugekommen)
**Quelle:** [Umsetzungsplan Audit 2026-07](../umsetzungsplan-audit-2026-07.md#welle-a2--ux-fixes-findings-notifications-inert-m-hero-voiceover-m-dynamic-type-m-kein-einzel-löschen-m-karte-empty-location-m-komma-parsing-m-ausgaben-sortierung-m-foto-grid-full-res-m),
[Voll-Audit 2026-07-03](../../audit/audit-2026-07-03.html)

## Beschreibung

Welle A2 behebt acht UX-Findings mittlerer Schwere aus dem Voll-Audit: eine
aufdringliche Notification-Anfrage ohne Kontext, eine nicht als solche
erkennbare Hero-Karte, mangelnde Dynamic-Type-Unterstuetzung im Stats-Strip
und der Hero-Karte, fehlendes Einzel-Loeschen fuer Haefen/Ausgaben, eine
Weltkarte mit ungenutzter Standort-Berechtigung ohne Empty-State,
locale-blindes Zahlenformat bei Ausgaben-Eingaben sowie eine unsortierte,
nicht zoombare Foto-Galerie.

---

## A2.1 — Kontextuelle Notification-Permission (CruiseFormView)

### Was / Warum

Der System-Berechtigungsdialog fuer Benachrichtigungen erschien bisher ohne
Kontext direkt beim Speichern. Neu: eine Statusmaschine prüft den aktuellen
Autorisierungsstatus vor dem Planen einer Erinnerung. Bei `authorized`,
`provisional` oder `ephemeral` wird direkt geplant. Bei `notDetermined` zeigt
ein Begruendungs-Sheet den Zweck der Benachrichtigung, bevor der
System-Prompt ausgeloest wird. Bei `denied` erscheint einmalig ein Hinweis
mit Link zu den Einstellungen statt eines wiederholten, wirkungslosen
Anfrageversuchs. `NotificationService.isAuthorized()` akzeptiert jetzt auch
`provisional`/`ephemeral` als gueltigen Zustand. Ein `isSaving`-Flag
verhindert Doppel-Speicherungen waehrend der asynchronen
Berechtigungspruefung.

### Berührte Dateien

- `ShipTrip/Views/Cruises/CruiseFormView.swift`
- `ShipTrip/Services/NotificationService.swift`

### Acceptance-Status

Erfüllt. Manuell verifiziert anhand aller vier Autorisierungspfade
(`authorized`/`provisional`/`ephemeral`, `notDetermined`, `denied`,
Doppel-Save-Sperre).

---

## A2.2 — Hero-Karte als erkennbarer Button (CruiseListView)

### Was / Warum

Die Hero-Card auf der Hauptansicht war optisch als Kachel gestaltet, aber
nicht als Button erkennbar bzw. fuer VoiceOver beschriftet. Sie ist jetzt ein
echter Button mit `accessibilityLabel` „Reise \<Titel\> öffnen".

### Berührte Dateien

- `ShipTrip/Views/Cruises/CruiseListView.swift`

### Acceptance-Status

Erfüllt (Code-Review). VoiceOver-Verhalten am Geraet/Simulator noch nicht
gesichtet (siehe Offene Punkte).

---

## A2.3 — Dynamic-Type-Unterstuetzung (Stats-Strip, Hero-Card)

### Was / Warum

Feste Hoehen in `CruiseStatsStripView` und `CruiseHeroCardView` liessen Text
bei groesseren Systemschriftgroessen abschneiden. Beide Views nutzen jetzt
`@ScaledMetric` fuer die betroffenen Hoehen sowie `minimumScaleFactor` von
mindestens 0,85 fuer die Zahlen-Labels.

### Berührte Dateien

- `ShipTrip/Views/Cruises/CruiseStatsStripView.swift`
- `ShipTrip/Views/Cruises/CruiseHeroCardView.swift`

### Acceptance-Status

Erfüllt (Code-Review). Verhalten bei extremen Dynamic-Type-Stufen am
Geraet/Simulator noch nicht gesichtet (siehe Offene Punkte).

---

## A2.4 — Einzel-Loeschen fuer Haefen/Ausgaben (CruiseDetailView)

### Was / Warum

Einzelne Haefen oder Ausgaben liessen sich bisher nur ueber das Bearbeiten
der gesamten Reise entfernen. Neu: ein `contextMenu` pro Zeile erlaubt das
direkte Loeschen. Bewusst kein Swipe-to-Delete, da die Zeilen innerhalb einer
`ScrollView` (nicht `List`) liegen — `contextMenu` folgt damit dem
bestehenden App-Muster aus `CruiseListView`.

### Berührte Dateien

- `ShipTrip/Views/Cruises/CruiseDetailView.swift`

### Acceptance-Status

Erfüllt (Code-Review). Interaktionsverhalten am Geraet/Simulator noch nicht
gesichtet (siehe Offene Punkte).

---

## A2.5 — Karte ohne Standort-Berechtigung + Empty-State (MapView)

### Was / Warum

`MapView` hielt bislang einen `CLLocationManager` samt
Standort-Berechtigungsanfrage vor, obwohl die Karte ausschliesslich
Reiserouten aus gespeicherten Hafen-Koordinaten zeigt und keine
Standortdaten des Nutzers benoetigt. `CLLocationManager` und die
zugehoerigen Info.plist-Berechtigungsschluessel wurden vollstaendig entfernt
(aus `project.pbxproj` fuer Debug- und Release-Konfiguration). Neu: ein
Empty-State-Overlay erscheint, wenn keine kartierbaren Haefen vorhanden sind,
statt einer leeren Karte.

### Berührte Dateien

- `ShipTrip/Views/Map/MapView.swift`
- `ShipTrip.xcodeproj/project.pbxproj`

### Acceptance-Status

Erfüllt (Code-Review). Kein manueller Berechtigungsdialog mehr; Empty-State
noch nicht am Geraet/Simulator gesichtet (siehe Offene Punkte).

---

## A2.6 — Locale-basierte Ausgaben-Eingabe + Sortierung

### Was / Warum

Die Betrag-Eingabe bei Ausgaben nutzte bisher ein starres Zahlenformat, das
bei Komma-Dezimaltrennzeichen (z. B. deutsche Locale) fehlschlagen konnte.
Neu: die Eingabe nutzt `.currency`-Formatierung nach Geraete-Locale; besitzt
die Locale keine Waehrung, wird ein neutrales Zahlenformat verwendet — **kein
EUR-Fallback** mehr fuer die Eingabe (siehe Offene Punkte fuer verbleibende
Anzeige-Stellen). Neue Ausgaben haben das Datumsfeld jetzt standardmaessig
aktiviert; bestehende Ausgaben ohne Datum bleiben unangetastet. Die Anzeige
sortiert Ausgaben chronologisch, undatierte Eintraege erscheinen zuletzt.

### Berührte Dateien

- `ShipTrip/Views/Cruises/ExpenseFormView.swift`
- `ShipTrip/Views/Cruises/CruiseDetailView.swift`

### Acceptance-Status

Erfüllt. Neue Suite `ShipTripTests/ExpenseSortingTests.swift` (5 Tests) deckt
die chronologische Sortierung inkl. undatierter Eintraege ab.

---

## A2.7 — Foto-Galerie: Pager, async Decoding, Zoom (CruiseDetailView)

### Was / Warum

Die Foto-Galerie zeigte Thumbnails ohne Zoom-Moeglichkeit und dekodierte
Bilder synchron. Neu: ein Pager auf Thumbnail-Basis mit asynchronem,
wertbasiertem Decoding (Lade- und Fehler-Platzhalter waehrend des
Ladevorgangs) sowie eine Zoom-Vollbildansicht (`PhotoZoomView`), die das
Foto in voller Aufloesung nachlaedt.

### Berührte Dateien

- `ShipTrip/Views/Cruises/CruiseDetailView.swift` (inkl. neuer
  `PhotoZoomView`)

### Acceptance-Status

Erfüllt (Code-Review). Zoom-Geste und Lade-/Fehlerzustaende am
Geraet/Simulator noch nicht gesichtet (siehe Offene Punkte).

---

## Offene Punkte

- VoiceOver-, Dynamic-Type- und Swipe-/Context-Menu-Verhalten (A2.2–A2.5,
  A2.7) sind bislang nur per Code-Review geprueft, nicht am Geraet/Simulator
  gesichtet — geplant vor dem 1.6.0-Release.
- EUR-Fallback bleibt an sechs weiteren Anzeige-Stellen bestehen (A2.6 hat
  nur die Eingabe umgestellt) — neuer Task **A3.11a**.
- Neue user-sichtbare Strings aus dieser Welle sind noch nicht im String
  Catalog (`Localizable.xcstrings`) gepflegt; Sync erfolgt beim naechsten
  Xcode-Build.

## Verwandte Entscheidungen

- [ADR-002: CloudKit-Sync, stabile IDs und ZIP-Export](../adr/ADR-002-cloudkit-sync-und-stabile-ids.md)
