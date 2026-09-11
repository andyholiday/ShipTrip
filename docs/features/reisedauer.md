# Reisedauer in Nächten

Stand: Branch `feature/reisedauer-naechte`, runtime-verifiziert, wartet auf den nächsten
TestFlight-Build.

## Zweck

Start, Ende und Dauer einer Reise sind im Formular ein gekoppelter Wert: Wer das Startdatum
verschiebt, bekommt das Enddatum mitgeschoben, statt es von Hand nachzuziehen. Quelle:
`ShipTrip/Utilities/CruiseDateTriad.swift`, `ShipTrip/Views/Cruises/CruiseDatesSection.swift`,
`ShipTrip/Views/Cruises/CruiseFormView.swift`, `ShipTrip/Models/Cruise.swift`.

## Verhalten

Der Abschnitt **Reisezeitraum** im Reiseformular (Anlegen und Bearbeiten) zeigt Startdatum,
Enddatum und eine Zeile **Nächte** (Stepper, ≥ 0). Drei Kopplungsregeln:

- **Enddatum geändert** → Nächte werden neu gerechnet, ohne Rückfrage.
- **Nächte geändert** → Dialog „Nächte geändert" mit *Startdatum anpassen* / *Enddatum
  anpassen* / *Abbrechen*. Der Stepper-Wert bleibt stehen, bis geantwortet wurde.
- **Startdatum geändert** → Dialogkette A → B.

Die Dialogkette:

1. **Dialog A — „Startdatum verschoben"**: *Enddatum mitverschieben* (Nächte bleiben) /
   *Nächte anpassen* (Enddatum bleibt) / *Abbrechen* (Startdatum springt auf den zuletzt
   bestätigten Wert zurück). Dialog A erscheint erst, wenn der Startdatum-Wert 0,5 s
   unverändert blieb — so erzeugt ein Scrollen im Rad-Picker genau eine Frage. Bezugspunkt
   ist immer das zuletzt bestätigte Startdatum, N ist die Gesamtverschiebung seither.
2. **Dialog B — „Hafen- und Seetag-Daten um N Tage … verschieben?"**: erscheint direkt nach
   der Antwort auf A, aber **nur**, wenn es etwas zu verschieben gibt — Route nicht leer
   **und** N ≠ 0 (`CruiseDateTriad.needsRouteShiftPrompt`). *Verschieben* schiebt alle
   Ankunfts- und Abfahrtszeiten der Route (Häfen und Seetage) um N Kalendertage; die Uhrzeit
   bleibt erhalten, auch über einen Sommerzeitwechsel. Die Richtung steht im Titel („nach
   hinten" / „nach vorne"), statt ein negatives N zu zeigen.

Programmatische Setzungen des Formulars (Laden einer Reise, KI-Import) fragen nichts, sie
ziehen nur Bezugspunkt und Nächtezahl nach. Gespeichert wird die Reise wie bisher; der
Kalender-Sync zieht über den `updatedAt`-Beobachter von selbst nach, siehe
[Kalender-Sync](kalender-sync.md).

## Datenmodell

`Cruise.nights: Int = 0` — additiv mit Default und ohne Unique-Constraint, damit die
CloudKit-Lightweight-Migration trägt (ADR-002).

- **Invariante:** beim Speichern gilt immer `nights == Kalendertage(startDate, endDate)`,
  gerechnet auf Tagesgrenzen.
- **Backfill:** Bestandsreisen tragen 0 und bekommen die Nächtezahl beim Laden ins Formular
  aus Start und Ende; ein nicht passender gespeicherter Wert wird überschrieben.
- `duration` (Tage = Nächte + 1) bleibt unverändert.

## Bausteine

- `CruiseDateTriad` (`ShipTrip/Utilities/`) — reiner, kalender-parametrisierter Wert mit den
  Kopplungsregeln (`changingStart`, `changingEnd`, `changingNights`), der Tagesarithmetik
  (`dayShift`, `shifted`) und der Regel für Dialog B. Kein SwiftData-Bezug, ohne View
  testbar.
- `CruiseDatesSection` (`ShipTrip/Views/Cruises/`) — die Formular-Section: Präsentation,
  Dialog-Zustandsautomat (`idle` → `dialogA` → `dialogB` bzw. `nightsDialog`) und
  Rückschreiben der neuen Triade. `CruiseFormView` liefert Bindings, `routeIsEmpty` und die
  Verschiebefunktion für die Route.
- Neue UI-Texte liegen als `String(localized:)` in DE und EN im String Catalog.

## Tests

- `ShipTripTests/CruiseDateTriadTests.swift` — Suite „Reisedauer": Repro-Test
  („Start um 3 Tage verschieben nimmt Ende und Nächte mit"), Backfill, alle drei
  Kopplungsregeln, Sommerzeitwechsel, rückwärts gezählte Tagesspanne, Regel für Dialog B.
- `ShipTripTests/CalendarSyncPlannerTests.swift` — eine verschobene Reise liefert dieselben
  stabilen Event-Schlüssel mit neuen Daten (Update statt Neuanlage).
- Diff-Coverage der Logik (`CruiseDateTriad`, `Cruise`): 100 %; Views 87,7 % über
  Wegwerf-UI-Läufe. Volle Unit-Suite grün (654 Tests).

## Acceptance-Status

Kriterien nach `.planning/ZIEL.md` (Run 2026-09-11), Belege aus dem Quality-Gate
(runtime-verifiziert, `gate-run.json` Exit 0).

| Kriterium | Status | Beleg |
| --- | --- | --- |
| 1 — `nights` additiv, Backfill, Invariante | erledigt | `CruiseDateTriadTests`, Upgrade-Smoke |
| 2 — Nächte-Zeile, Kopplungsregeln als reine Funktionen | erledigt | `CruiseDateTriadTests` |
| 3 — Dialogkette A → B, Ruhephase, Routen-Shift | erledigt | Simulator-Läufe, Unit-Tests |
| 4 — Kalender-Sync: stabile Schlüssel, neue Daten | erledigt | `CalendarSyncPlannerTests` |
| 5 — Neue Texte lokalisiert (DE/EN) | erledigt | String Catalog |
| 6 — Berührte Suite grün, Gate Exit 0 | erledigt | 654/654, Diff-Coverage 100 % Logik |
| 7 — Changelog, Feature-Doku, CLAUDE.md | erledigt | dieses Dokument, `CHANGELOG.md` |
| 8 — Bestätigung am Gerät | offen | wartet auf den nächsten TestFlight-Build |

## Known Limitations

- **Zeitfenster der verzögerten Dialoge:** „Speichern" innerhalb der 0,5-s-Ruhephase
  speichert mit stehendem Enddatum, ohne zu fragen; eine erneute Start-Änderung in den
  350 ms vor Dialog B lässt B ausfallen, die erste Verschiebung geht für die Route verloren.
- **Hängender Programmatik-Merker:** Setzt das Formular ein Datum programmatisch auf den
  bereits eingestellten Wert (KI-Import, erneutes `onAppear`), bleibt der Merker stehen und
  die nächste echte Nutzeränderung wird still übernommen, ohne Dialog A.
- **`storedNights` wird nicht gelesen:** Der Parameter ist Teil der Signatur, die Nächtezahl
  stammt aber immer aus Start und Ende. Die Signatur täuscht eine Verwendung vor.
- **Nicht beobachtete UI-Pfade:** Abbrechen-Revert in Dialog A und der `.moveStart`-Pfad
  sind unit-getestet, aber in keinem dauerhaften XCUITest abgedeckt.
- **`CruiseFormView` bleibt über dem Größen-Limit** (1033 Zeilen, vorbestehend, +52) — der
  nächste Split-Schritt steht im Backlog.
- Nicht im Scope: Validierung „Hafen liegt im Reisezeitraum" und der Präzedenz-Bug in
  `Date+Extensions.durationInDays`.

## Links

- [ADR-002: CloudKit-Sync und stabile IDs](../adr/ADR-002-cloudkit-sync-und-stabile-ids.md)
- [Kalender-Sync](kalender-sync.md)
- Changelog: `CHANGELOG.md`, Abschnitt `[Unreleased]` → *Hinzugefügt*
