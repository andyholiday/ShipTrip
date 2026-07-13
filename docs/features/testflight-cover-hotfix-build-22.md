# TestFlight-Hotfix: fotografische Reise-Cover (Build 22)

## Anlass und Ursache

Build 21 priorisierte anhand des Dateinamens jedes vorhandene
`cover_ship_<schiff>`-Asset. Der Asset-Katalog enthält jedoch zwei visuell
unterschiedliche Gruppen: 70 hochwertige Reederei-Stockfotos und 114
schiffsspezifische Assets, von denen nur drei Fotos und 111 stilisierte
Illustrationen sind. Dadurch erschien etwa „Mein Schiff Relax · Norwegen“ mit
der blauen Illustration `cover_ship_mein_schiff_relax`.

## Umsetzung

- Große Reise- und Wunschreise-Cover dürfen nur noch aus einem expliziten Pool
  von 73 visuell geprüften Fotos gewählt werden: 70 Reederei-Stockfotos plus
  `cover_ship_aidanova`, `cover_ship_mein_schiff_6` und
  `cover_ship_msc_seaside`.
- Unsuffigierte Reederei-Illustrationen, `cover_ocean_route` und die übrigen 111
  `cover_ship_*`-Illustrationen sind aus diesem Pfad ausgeschlossen.
- Eindeutige Zielbegriffe verdrahten kuratierte Foto-Pools für Norwegen,
  Kanaren, Karibik, Ostsee und Mittelmeer.
- Reise-Hero und Reise-Detail übergeben neben Datum und Route auch den
  Reisetitel, damit Titel wie „Norwegen mit Geirangerfjord“ die Bildauswahl
  sicher beeinflussen.
- Die Auswahl bleibt für dieselbe Reise deterministisch.

## Verifikation

- Regressionstest für „Mein Schiff Relax · Norwegen/Geirangerfjord“ beweist,
  dass ein Fjordfoto an erster Stelle steht und die blaue Illustration nicht
  mehr Kandidat ist.
- Alle 73 Pool-Einträge sind eindeutig und mit `UIImage(named:)` ladbar.
- Cover-Fokussuite: 16/16 Tests grün.
- Vollständige Unit-Suite: 297/297 Tests grün.
- UI-Screenshottest `testScreenshot_HeroPhotoClean`: grün; das gerenderte
  Hero-Cover wurde visuell als fotografisches Fjordmotiv kontrolliert.
