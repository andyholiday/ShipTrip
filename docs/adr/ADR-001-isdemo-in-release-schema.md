# ADR-001: `isDemo`-Attribut bleibt build-konfigurationsunabhaengig im Schema

**Status:** Accepted  
**Datum:** 2026-06-14  
**Autor:** Andre (via Phase-0-Review)

---

## Kontext

Im Zuge von Phase 0 wurde ein Demo-Modus eingefuehrt, der Testdaten fuer
Praesentationen und Onboarding bereitshaelt. Die neuen Felder `isDemo: Bool = false`
wurden in `Cruise` und `Deal` ergaenzt, damit `DemoDataService` Demo-Eintraege
zuverlaessig selektieren und wieder entfernen kann.

Beim Entwurf entstand die Frage, ob `isDemo` per `#if DEBUG`-Direktive nur in
Debug-Builds in das SwiftData-Schema aufgenommen werden soll — so wie der
Demo-Toggle in `SettingsView` und `DemoDataService.swift` selbst. SwiftData leitet
das persistente Schema zur Laufzeit direkt aus den `@Model`-Klassen ab; ein
bedingtes Attribut fuehrt also zu unterschiedlichen Schemas je nach Build-Konfiguration.

Das Projekt plant im Rahmen von Phase 1 ("Vertrauen & Substanz") die Aktivierung
von CloudKit-Mirroring. CloudKit erfordert ein identisches Schema auf allen Geraeten
und in allen Build-Konfigurationen; schemadivergente Debug-/Release-Builds koennen
zu nicht aufloesbaren Migrationskonflikten fuehren.

Dieser Sachverhalt wurde in `docs/features/phase-0-fixes-und-demo-modus.md`
(Bekannte Einschraenkungen, Punkt b und d) als offene Entscheidung notiert und soll
mit diesem ADR formalisiert werden.

---

## Entscheidung

`isDemo: Bool = false` wird in `Cruise` und `Deal` als regulaeres SwiftData-Attribut
**ohne** `#if DEBUG`-Wrapper gefuehrt. Es ist in allen Build-Konfigurationen
(Debug, Release, TestFlight) Bestandteil des persistenten Schemas.

Nur die Nutzerflaeche (Demo-Toggle in `SettingsView`) und die Service-Schicht
(`DemoDataService.swift`) bleiben vollstaendig in `#if DEBUG` eingekapselt. Im
Release-Build ist das Feld immer `false` und wird nie beschrieben.

---

## Konsequenzen

**Positiv**

- Das SwiftData-Schema ist build-konfigurationsunabhaengig und stabil.
- Es ist keine Migration zwischen Debug- und Release-Build noetig, wenn ein
  Entwickler zwischen Konfigurationen wechselt oder TestFlight nutzt.
- Das Schema ist CloudKit-kompatibel ohne nachtraegliche Korrekturen (vgl. ADR-002).
- Demo-Daten koennen durch `isDemo == true` exakt gefiltert und per
  SwiftData-Cascade sauber geloescht werden.

**Neutral**

- Jede `Cruise`- und `Deal`-Zeile im Release-Store traegt eine harmlose
  `isDemo`-Spalte mit dem Wert `false`. Der Speicheroverhead ist vernachlaessigbar
  (1 Byte pro Zeile in der SQLite-Darstellung).

**Negativ / Risiken**

- Das Feld ist im Release-Store sichtbar (z. B. per DB-Browser). Das ist kein
  Sicherheitsproblem, da der Wert immer `false` ist und keine sensiblen Daten
  enthaelt.
- Wenn kuenftig ein echter Release-Mechanismus fuer Demo-Inhalte benoetigt wird
  (z. B. App-Store-Preview), ist `isDemo` bereits vorhanden — das Verhalten muss
  dann aber bewusst freigegeben werden (kein unbeabsichtigter Seiteneffekt).

---

## Alternativen

**Option A: `isDemo` per `#if DEBUG` aus dem Release-Schema ausblenden**  
Abgelehnt. SwiftData leitet das Schema aus der Klassenstruktur zur Laufzeit ab.
Unterschiedliche Schemas zwischen Debug und Release erzwingen eine Lightweight- oder
Custom-Migration bei jedem Konfigurations-Wechsel. Mit CloudKit-Mirroring (Phase 1)
ist ein schema-divergenter Ansatz unvereinbar, da CloudKit das Schema auf allen
Teilnehmergeraeten identisch voraussetzt.

**Option B: Demo-Daten durch einen separaten In-Memory-Container isolieren**  
Abgelehnt. Ein zweiter Container waere aufwaendiger zu verwalten, verhindert das
einfache Loeschen via Cascade, und der Demo-Modus beschraenkt sich explizit auf
Debug-Builds — der Mehraufwand steht in keinem Verhaeltnis zum Nutzen.

---

## Referenzen

- `docs/features/phase-0-fixes-und-demo-modus.md` — Bekannte Einschraenkungen (b) und (d)
- `ShipTrip/Models/Cruise.swift` — Implementierung des Felds
- `ShipTrip/Models/Deal.swift` — Implementierung des Felds
- `ShipTrip/Services/DemoDataService.swift` — `#if DEBUG`-Kapselung der Service-Schicht
- ADR-002 — CloudKit-Sync und stabile IDs (teilt dieselbe Schema-Stabilitaets-Motivation)
