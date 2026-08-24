# Beispielreise (Demo-Daten)

Stand: 1.8.0 (Welle 2, Task B3)

Die Beispielreise war bis 1.7.1 reine Debug-Funktion. Ab 1.8.0 ist sie ein
Produkt-Feature und auch im Release verfuegbar: neue Nutzer sollen die App mit
echten Inhalten erleben, statt vor leeren Screens zu stehen.

## Verhalten

- **Laden:** Einstellungen → *Beispielreise* → „Beispieldaten laden". Denselben
  Einstiegspunkt nutzt das Onboarding („Beispielreise ansehen", Task B2) ueber
  dieselbe API `DemoDataService.loadDemoData(into:)`.
- **Inhalt:** 3 Kreuzfahrten (Mittelmeer 2025, Norwegische Fjorde, Karibik 2025)
  mit Route, Hafen-Erinnerungen und Ausgaben sowie 2 Wunschreisen/Angebote.
  Vergangene und kommende Reisen, damit Statistik und Hero-Karte gefuellt sind.
- **Idempotent:** Ein zweiter Ladevorgang erzeugt keine Duplikate.

## Kennzeichnung und Entfernen

- Jede erzeugte Kreuzfahrt und jedes Angebot traegt `isDemo == true`; Haefen,
  Ausgaben und Fotos haengen per Cascade daran.
- **Ein-Klick-Entfernen:** Einstellungen → *Beispielreise* →
  „Beispieldaten entfernen" (`DemoDataService.removeDemoData(from:)`) loescht
  ausschliesslich `isDemo`-Objekte. Echte Nutzerdaten bleiben unangetastet —
  abgesichert durch `ShipTripTests/DemoDataServiceTests.swift`.
- Demo-Inhalte werden ausserdem systemweit ausgefiltert: Export/Backup
  (`ExportImportService`), Kalender-Sync und Erinnerungen ignorieren
  `isDemo`-Objekte. Eine Beispielreise landet also nie in einem Backup und
  erzeugt keine Termine oder Push-Nachrichten.
- Debug-only bleibt einzig `resetAndLoadDemoDataForUITesting(in:)`: Der Aufruf
  loescht den kompletten Store fuer deterministische UI-Tests und darf im
  Release nicht existieren.

## F18-Entscheidung: Demo-Bildassets

Die fuenf Imagesets `demo_port_barcelona`, `demo_port_bergen`,
`demo_port_geiranger`, `demo_port_cozumel`, `demo_port_palma` (~1,5 MB) lagen
bisher als Debug-Altlast im Release-`Assets.car`: ausgeliefert, aber vom
Release-Code nie referenziert.

**Entscheidung: behalten.** Mit der Freischaltung der Beispielreise werden sie
im Release legitim gebraucht — `DemoDataService.demoPortMoments` laedt sie als
`Port.imageData` und macht die Hafen-Erinnerungen ueberhaupt erst sichtbar.
Aus toter Fracht wird damit genutzte Nutzlast; F18 ist erledigt, nicht durch
Loeschen, sondern durch Verwendung. Die Motive sind eigens erzeugte, text- und
logofreie Hafenbilder (keine Rechte Dritter).

Verworfene Alternative: Assets loeschen und die Beispielreise ohne Bilder
ausliefern — spart 1,5 MB, kostet aber genau den visuellen Ersteindruck, wegen
dem die Beispielreise im Release ueberhaupt freigeschaltet wurde.
