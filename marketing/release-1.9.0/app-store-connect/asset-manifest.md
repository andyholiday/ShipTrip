# ShipTrip 1.9.0 App Store Connect asset manifest

Prepared: 2026-09-14

## Screenshots

All screenshots are PNG files at 1320 x 2868 pixels without an alpha channel.
Order 2 (`02-widgets.png`) is new in 1.9.0; orders 1, 3, 4 and 5 are the
unchanged 1.7.0 images, renumbered.

| Locale | Order | File | SHA-256 |
| --- | ---: | --- | --- |
| de-DE | 1 | `screenshots/de-DE/01-deine-kreuzfahrt.png` | `e3aeb23e4e8b3e5187a7c59bbe34f3334e74f03e5081b5c736736787ef6dd745` |
| de-DE | 2 | `screenshots/de-DE/02-widgets.png` | `9bdd453067feb13e730e155b4abd52844d1deaac7457791f6863228164b16c0d` |
| de-DE | 3 | `screenshots/de-DE/03-hafen-momente.png` | `abfa388eb5470280d64e2958cdee1ebf06bbf769dd7931ed0b417db3a49760fa` |
| de-DE | 4 | `screenshots/de-DE/04-icloud-sync.png` | `0d32d2b25921411faeb2d39773c114d3436869870f846d452748c976be820c81` |
| de-DE | 5 | `screenshots/de-DE/05-reiselogbuch.png` | `635bfbe6a1464392254dcb684ef0b0304edc7b6b7035eae532bfa39f1b6037bd` |
| en-US | 1 | `screenshots/en-US/01-your-cruise.png` | `a478f6c001b09caf4a3fdeb80a9b7f8e35d6666c7d164d8f5f553637e06a2e57` |
| en-US | 2 | `screenshots/en-US/02-widgets.png` | `5044774d352cc5a58bf0b647da0e64ec4cd799c899114f4d9a426150af3a50ed` |
| en-US | 3 | `screenshots/en-US/03-port-moments.png` | `b9dc4fe170124e1afc10e8af5b2335a4360bf7752823f9436772984d3e524b32` |
| en-US | 4 | `screenshots/en-US/04-icloud-sync.png` | `17c321ef5d0ce39fa938d6005c4f96c00d119e7b8d9e071db863ee69dd463581` |
| en-US | 5 | `screenshots/en-US/05-travel-logbook.png` | `345805e39c6fa646b1ac7940812ae532e709199b425724fd909fff7adbe299c1` |

## Upload order

1. Select version 1.9.0 and the valid build.
2. Upload the localized screenshots in the listed order (widgets second).
3. Keep the 1.7.0 app previews and poster frames; they are unchanged.

## Provenance of the widget shot

Render template and assets: `../app-store-v2/`. The three widget tiles are the
gate-verified gallery renderings of the shipped "Dynamic Instrument" direction
(`docs/design/directions/shots/dynamic/`, commit fa42266) for German, and a fresh
harness run of `ShipTripUITests/WidgetScreenshotUITests` for English. No widget
pixel was redrawn; the images are only cropped and scaled.
