# Architecture Decision Records

Dieses Verzeichnis enthaelt alle Architecture Decision Records (ADRs) des Projekts ShipTrip.
ADRs folgen dem Michael-Nygard-Format und sind unveraenderlich — spaetere Korrekturen
werden als neue ADR mit `Ersetzt ADR-NNN` erfasst, nicht als Edit.

| Nr.     | Titel                                                              | Status    | Datum      |
|---------|--------------------------------------------------------------------|-----------|------------|
| ADR-001 | `isDemo`-Attribut bleibt build-konfigurationsunabhaengig im Schema | Accepted  | 2026-06-14 |
| ADR-002 | CloudKit-Sync, stabile IDs und ZIP-Export                          | Accepted  | 2026-06-14 |
| ADR-003 | *reserviert* — Welle B2 Journal-Kern (siehe `docs/umsetzungsplan-audit-2026-07.md`) | — | — |
| ADR-004 | *reserviert* — Welle C2 StoreKit-2-Freemium (siehe `docs/umsetzungsplan-audit-2026-07.md`) | — | — |
| ADR-005 | *reserviert* — Welle D1 KI-Proxy (siehe `docs/umsetzungsplan-audit-2026-07.md`) | — | — |
| ADR-006 | Eigene Reedereien & Schiffe als Overlay über dem statischen Katalog | Accepted  | 2026-07-04 |

**Hinweis für neue ADRs:** Der Umsetzungsplan (`docs/umsetzungsplan-audit-2026-07.md`)
reserviert ADR-Nummern pro Welle im Voraus (B2→003, C2→004, D1→005, B5→006).
Vor dem Anlegen eines neuen ADRs dort nachschauen, ob die naechste freie Nummer
bereits einer anderen geplanten Welle zugewiesen ist — die Skill-Regel
„höchste bestehende Nummer + 1" wird von dieser Plan-Reservierung übersteuert.
