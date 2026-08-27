# ADR-004: Einmalkauf statt Freemium-Abo als Monetarisierung

**Status:** Accepted (2026-08-27)
**Datum:** 2026-08-27
**Autor:** Knowledge (Winston-Run ShipTrip 1.8.5, Task D4), auf Basis von Andres
Entscheid vom 2026-08-23
**Querverweis:** löst die ADR-004-Reservierung „Welle C2 StoreKit-2-Freemium" auf

---

## Kontext

Der Umsetzungsplan vom Juli 2026 (`docs/umsetzungsplan-audit-2026-07.md`) hat
ShipTrip auf einen Freemium-Kurs gestellt: Welle C2 sah StoreKit-2-Abos
(`shiptrip.premium.monthly` 4,99 € / `.yearly` 34,99 €, 7 Tage Trial), einen
Entitlement-Layer `PremiumStore`, ein Paywall-Sheet und Premium-Gates auf
iCloud-Sync (D2), KI-Flat (D1) und ein Foto-Kontingent vor. Die Preise waren
dort ausdrücklich als unvalidierte Annahme geführt (Offene Frage E3,
„Marktanker aus Audit; vor C2 kurz validieren"). ADR-004 war für genau diese
Welle vorreserviert und blieb ungeschrieben.

Umgesetzt wurde von alldem nichts: Der Code enthält bis 1.8.x keinen
StoreKit-, Entitlement- oder Paywall-Anteil, die App ist vollständig
funktionsfrei zugänglich. Gleichzeitig ist ShipTrip ein Ein-Personen-Projekt
ohne Backend (ADR-007: „kein Backend, keine Domain, keine laufenden Kosten").
Ein Abo verkauft eine fortlaufende Gegenleistung — regelmäßige Updates,
laufende Dienste, Support-Zusage — die dieses Projekt nicht dauerhaft zusagen
will. Der Widerspruch zwischen der in `CLAUDE.md` festgeschriebenen Richtung
„Premium-Reisetagebuch mit Freemium-Abo" und der tatsächlichen Produktabsicht
sollte nicht länger implizit bleiben.

## Entscheidung

Wir monetarisieren ShipTrip als **einmaligen In-App-Kauf** (non-consumable),
nicht als Freemium-Abo. Es gibt kein Abo-Produkt, keine Trial-Periode und
keine wiederkehrende Abrechnung. Die ADR-004-Reservierung für
„Welle C2 StoreKit-2-Freemium" ist damit aufgelöst; Welle C2 des
Umsetzungsplans gilt in ihrer Abo-Form als überholt, ebenso der Preisanker E3.

Diese Entscheidung legt die **Produktrichtung** fest, nicht die Umsetzung.
Produkt-ID, Preis, Kaufzeitpunkt, der Schnitt zwischen frei nutzbarem Kern
und freigeschaltetem Umfang sowie die technische StoreKit-2-Anbindung
(`Transaction.currentEntitlements`, Wiederherstellen-Aktion, StoreKit-Tests)
sind ein späteres, eigenes Umsetzungs-Thema mit eigener Entscheidung. Bis
dahin bleibt die App bewusst ohne Kauf-Code.

## Konsequenzen

Positiv:

- Kein Abo-Code in der App: kein `PremiumStore`, kein Paywall-Sheet, keine
  Entitlement-Prüfungen in Views — bestehende Funktionen müssen nicht
  nachträglich hinter Gates gezogen werden.
- Kein Abo-Overhead im App-Review und in den Store-Metadaten
  (Trial-Offenlegung, Kündigungshinweise, Abo-Verwaltung, Preisänderungs-
  Zustimmung).
- „Premium" ist im Projektvokabular wieder eindeutig eine Qualitätsaussage
  (Optik, Politur) und keine Preisstufe — das entspannt die UX-Sprache in
  Pitch-Decks und Feature-Doku.
- Keine Zusage einer fortlaufenden Gegenleistung, die ein Solo-Projekt
  einlösen müsste.

Negativ:

- Kein wiederkehrender Umsatz: laufende Kosten müssen aus Einmalzahlungen
  gedeckt werden oder entfallen.
- Die beiden im Plan als Abo-Träger gedachten Features brauchen ein neues
  Kostenmodell — vor allem die **KI-Flat** (Welle D1, KI-Proxy), deren Kosten
  pro Nutzer laufen und die ein Einmalkauf nicht unbegrenzt tragen kann.
  iCloud-Sync (D2) ist davon weniger betroffen, weil er auf dem
  iCloud-Kontingent des Nutzers läuft.
- Der Preisanker E3 verfällt ersatzlos; ein Einmalpreis ist noch nicht
  gesetzt und muss eigenständig hergeleitet werden.
- Spätere Preiserhöhungen erreichen nur Neukäufer; Bestandsnutzer bleiben
  dauerhaft freigeschaltet.

Neutral:

- Der Umsetzungsplan und die Audit-Dokumente bleiben unverändert als
  historische Quellen bestehen (`docs/umsetzungsplan-audit-2026-07.md`,
  `audit/audit-2026-07-10.html`). Wo sie Freemium, Abo-Preise oder
  Premium-Gates beschreiben, sind sie ab hier gegenüber dieser ADR nachrangig
  und dokumentieren nur noch den damaligen Kurs.
- In `docs/adr/README.md` wird ausschließlich die ADR-004-Zeile aufgelöst;
  die Reservierungen ADR-003 (Welle B2 Journal-Kern) und ADR-005 (Welle D1
  KI-Proxy) bleiben bestehen.
- Die „Premium"-Erwähnungen in `docs/ux-pitch-decks/` und
  `docs/features/phase-2-visuelle-politur.md` meinen visuelle Qualität und
  bleiben unangetastet; einzige Ausnahme sind die Mockup-Badges „Premium" im
  Einstellungs-Screen (`premium-reisetagebuch-mockup.html`), die einen
  Abo-Gate-Zustand zeigen und damit historisch sind.

## Alternativen

**A: Freemium-Abo wie in Welle C2 geplant.**
Abgelehnt: verkauft eine fortlaufende Gegenleistung, die ein Solo-Projekt ohne
Backend nicht dauerhaft zusagen will; die Preisannahme E3 wurde nie validiert.

**B: Vollständig kostenlos ohne Kauf.**
Abgelehnt: deckt weder Entwicklungsaufwand noch Sachkosten (Developer-Programm,
späterer KI-Proxy) und macht jede kostenverursachende Funktion unbezahlbar.

**C: Bezahl-App (Kauf vor dem Download) statt In-App-Einmalkauf.**
Abgelehnt: kein Ausprobieren vor dem Kauf, was bei einem Reisetagebuch die
Einstiegshürde massiv erhöht; der In-App-Kauf erlaubt eine frei nutzbare Basis
mit einmaliger Freischaltung.

## Referenzen

- `docs/umsetzungsplan-audit-2026-07.md` — historisch: Welle C2
  (StoreKit-2-Freemium), Preisanker E3, Premium-Gates D1/D2
- `audit/audit-2026-07-10.html` — historisch: Audit-Befund „Freemium-UI fehlt"
- `.planning/TASKPLAN-1.8.0.md` — Task D4, Andres Entscheid vom 2026-08-23
- `docs/adr/README.md` — ADR-Index, aufgelöste Reservierung
- `CLAUDE.md` — Produktrichtung, angeglichen mit dieser ADR
