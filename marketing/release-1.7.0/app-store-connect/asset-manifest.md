# ShipTrip 1.7.0 App Store Connect asset manifest

Prepared: 2026-08-06

## Screenshots

All screenshots are PNG files at 1320 x 2868 pixels without an alpha channel.

| Locale | Order | File | SHA-256 |
| --- | ---: | --- | --- |
| de-DE | 1 | `screenshots/de-DE/01-deine-kreuzfahrt.png` | `e3aeb23e4e8b3e5187a7c59bbe34f3334e74f03e5081b5c736736787ef6dd745` |
| de-DE | 2 | `screenshots/de-DE/02-hafen-momente.png` | `abfa388eb5470280d64e2958cdee1ebf06bbf769dd7931ed0b417db3a49760fa` |
| de-DE | 3 | `screenshots/de-DE/03-icloud-sync.png` | `0d32d2b25921411faeb2d39773c114d3436869870f846d452748c976be820c81` |
| de-DE | 4 | `screenshots/de-DE/04-reiselogbuch.png` | `635bfbe6a1464392254dcb684ef0b0304edc7b6b7035eae532bfa39f1b6037bd` |
| en-US | 1 | `screenshots/en-US/01-your-cruise.png` | `a478f6c001b09caf4a3fdeb80a9b7f8e35d6666c7d164d8f5f553637e06a2e57` |
| en-US | 2 | `screenshots/en-US/02-port-moments.png` | `b9dc4fe170124e1afc10e8af5b2335a4360bf7752823f9436772984d3e524b32` |
| en-US | 3 | `screenshots/en-US/03-icloud-sync.png` | `17c321ef5d0ce39fa938d6005c4f96c00d119e7b8d9e071db863ee69dd463581` |
| en-US | 4 | `screenshots/en-US/04-travel-logbook.png` | `345805e39c6fa646b1ac7940812ae532e709199b425724fd909fff7adbe299c1` |

## App previews

Both previews are 18 seconds long, 886 x 1920 portrait, H.264 High Profile Level 4.0, YUV 4:2:0, 30 fps, about 10.5 Mbps, without audio, and below 500 MB.

| Locale | File | Size | SHA-256 |
| --- | --- | ---: | --- |
| de-DE | `previews/de-DE/shiptrip-app-preview-de-18s.mp4` | 23,585,249 bytes | `35c2451f13a9ed7d303f283ee3a2b5cea2b63211dbb4e9e180250246dc68b9e4` |
| en-US | `previews/en-US/shiptrip-app-preview-en-18s.mp4` | 23,560,654 bytes | `90d304e0e215dee1a091ca7be06db94f7185796fc548eb54cf4516ff40a2969e` |

Poster frames are PNG files at 886 x 1920 pixels without an alpha channel.

## Metadata validation

The German and English app name, subtitle, promotional text, keywords, description, and release notes are within the App Store Connect character limits. URLs and reviewer notes are stored alongside the localized metadata.

## Upload order

1. Select version 1.7.0 and valid build 23.
2. Upload localized screenshots in the listed order.
3. Upload the matching localized app preview and select its poster frame.
4. Paste localized metadata and reviewer notes.
5. Set public worldwide availability and Germany as the base storefront at EUR 0.99 with automatically generated equivalent prices.
6. Complete the privacy and agreement checks in `release-configuration.md` before submission.

## Verification evidence

- Hyperframes checks: German and English projects each passed with zero lint, runtime, layout, motion, or contrast findings.
- Functional test suite: 319 passed, 0 failed, 1 skipped on 2026-08-06. Nine audit-only screenshot exporters were excluded because of their obsolete absolute output path.
- Release simulator build: passed on 2026-08-06 with two existing warnings.
