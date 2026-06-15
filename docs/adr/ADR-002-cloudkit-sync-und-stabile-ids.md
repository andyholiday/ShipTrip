# ADR-002: CloudKit-Sync, stabile IDs und ZIP-Export

**Status:** Accepted  
**Datum:** 2026-06-14  
**Autor:** Andre (via Phase-1-Planung / Codex-Plan-Review)  
**Querverweis:** ADR-001 (Schema-Stabilitaet als gemeinsame Motivation)

---

## Kontext

ShipTrip verwaltet Reisedaten (Kreuzfahrten, Haefen, Ausgaben, Fotos), die fuer
Nutzer dauerhaft wertvoll sind. Phase 1 ("Vertrauen & Substanz") hat drei
eng gekoppelte Ziele:

1. **Geraeteuebergreifende Datenverfuegbarkeit** — Nutzer erwarten, dass ihre
   Daten auf iPhone und iPad synchron sind.
2. **Zuverlaessiges Backup** — Datenverlust beim Geraetewechsel oder App-Neustart
   muss ausgeschlossen sein.
3. **Exportfaehigkeit** — Nutzer sollen ihre Daten portieren koennen; der bisherige
   Base64-in-JSON-Export aus dem Audit (H4) skaliert nicht mit wachsenden Fotomengen.

Die drei Ziele sind technisch voneinander abhaengig: CloudKit-Mirroring setzt ein
stabiles, konfliktstabiles Schema voraus; ein robuster Export benoetigt stabile IDs
fuer Rundtripstabilitaet; und sowohl CloudKit als auch Export erfordern, dass die
Modelle konkrete Constraints erfuellen.

Das Modell besitzt derzeit keine expliziten `id`-Felder (SwiftData erzeugt zwar
intern `PersistentIdentifier`, dieser ist aber nicht export-stabil). `Photo.imageData`
ist `Data` ohne Default (problematisch unter CloudKit). Es existiert noch kein
Export-ZIP-Format.

Hinweis: Die iCloud-Capability und die Container-Registrierung
(`iCloud.com.andre.ShipTrip`) sind manuelle Schritte in Xcode, die ausschliesslich
Andre durchfuehren kann. Die genaue Container-ID ist in Xcode zu bestaetigen.

---

## Entscheidung

Dieses ADR buendelt fuenf eng gekoppelte Entscheidungen, die gemeinsam die
Backup- und Sync-Infrastruktur bilden.

### 1. Sync-Mechanismus: SwiftData + CloudKit Private Container

Wir nutzen SwiftData-CloudKit-Mirroring ueber einen **privaten** iCloud-Container
(`iCloud.com.andre.ShipTrip` — genaue ID in Xcode zu bestaetigen). Der Container
ist primaer fuer Single-User-Backup und Multi-Geraete-Sync; kein Shared-Container,
keine CKShare-Logik.

### 2. Konfliktaufloesung: App-Level Last-Writer-Wins via `updatedAt`

CloudKit bietet keine serverseitige Merge-Logik fuer SwiftData-Mirroring. Wir
implementieren **Last-Writer-Wins** auf App-Ebene: Jedes gespeicherte Modell traegt
ein `updatedAt: Date`-Feld, das bei **jeder Nutzeraenderung explizit** per Code
aktualisiert werden muss (SwiftData bumpt es nicht automatisch). Bei einem
Sync-Konflikt gewinnt der Record mit dem juengeren `updatedAt`.

`Cruise` besitzt `updatedAt` bereits. `Deal` und alle weiteren persistenten Modelle
erhalten das Feld, sofern noch nicht vorhanden.

### 3. CloudKit-Schema-Constraints der Modelle

CloudKit-Mirroring erfordert folgende Modell-Eigenschaften:

- Jedes nicht-optionale gespeicherte Attribut muss einen **Default-Wert** besitzen.
- Beziehungen muessen **optional** deklariert sein (`.cascade`-Regeln bleiben, aber
  die Gegenseite muss optional sein).
- **`@Attribute(.unique)` ist verboten** — CloudKit unterstuetzt keine Unique-Constraints.
- `Photo.imageData` ist aktuell `Data` ohne Default; es erhaelt entweder
  `= Data()` als Default **oder** wird optional (`Data?`), um CloudKit-Kompatibilitaet
  herzustellen.

### 4. Stabile IDs und App-Level-Deduplizierung

Da `@Attribute(.unique)` unter CloudKit nicht erlaubt ist, erhaelt jedes
persistente Modell ein explizites Feld `var id: UUID = UUID()`. Dieses Feld ist
kein Unique-Constraint in der Datenbank, wird aber von der App als logischer
Schluessel verwendet.

Deduplizierung ist **App-Aufgabe**: Bei Import und Sync wird primaer auf `id`
gematcht. Fuer Legacy-Importe ohne `id` greift ein Heuristik-Fallback
(`title + startDate + ship` fuer `Cruise`, analoges Schema fuer andere Modelle).

### 5. Export-Format: ZIP mit externen Bilddateien

Der bestehende Base64-in-JSON-Export wird durch ein **ZIP-Archiv** ersetzt:

- `data.json` — alle strukturierten Daten (ohne Bild-Bytes)
- `images/<id>.jpg` o. ae. — Bilddateien mit stabiler `id` als Dateiname

Die stabile `id` wird in den Export geschrieben und beim Import unveraendert
uebernommen (nie neu generiert), sodass Rundtrips id-stabil sind.

Der Import bleibt **rueckwaertskompatibel**: Das alte JSON+Base64-Format wird
weiterhin erkannt und verarbeitet. Fehlende Bilddateien im ZIP werden toleriert
(Photo-Objekt wird ohne Bild angelegt oder uebersprungen — genaues Verhalten wird
bei Implementierung festgelegt).

---

## Migrationsstrategie (explizit, nicht optional)

Das Aktivieren von CloudKit auf einem bestehenden lokalen Store ist ein
**Migrationsereignis**, kein reiner Konfigurations-Flip. Folgende Schritte sind
verbindlich:

**(a) Schema-Aenderungen zuerst, CloudKit danach**  
Alle Modell-Anpassungen (Hinzufuegen von `id`, `updatedAt`-Feldern, Default-Werte,
optionale Beziehungen) werden als **Lightweight-Automatic-Migration** deployed.
In dieser Phase ist CloudKit noch deaktiviert. Ziel: Alle bestehenden Zeilen erhalten
ein persistiertes `id` und behalten es unveraendert.

**(b) CloudKit-Aktivierung als separates Release**  
Erst nachdem Schritt (a) im App-Store gelandet und in Produktion verifiziert ist,
wird CloudKit-Mirroring aktiviert. Kein zusammengefasstes Release.

**(c) Nutzerkommunikation vor dem Update**  
In den Release-Notes wird explizit empfohlen, vor dem Update einen manuellen
Export als Backup anzulegen.

**(d) Smoke-Test vor jedem CloudKit-Release**  
Sync muss auf einem bevoelkerten Store mit einem echten iCloud-Account (nicht
Simulator) verifiziert werden, bevor der Build an TestFlight geht.

**(e) Manuelle Xcode-Schritte (nur Andre)**  
iCloud-Capability hinzufuegen, Container `iCloud.com.andre.ShipTrip` registrieren,
Push-Notification-Background-Mode aktivieren — alles in Xcode, nicht
automatisierbar.

---

## Konsequenzen

**Positiv**

- Geraeteuebergreifende Synchronisation ohne eigenen Server.
- ZIP-Export skaliert mit beliebig grossen Fotomengen.
- Stabile `id`-Felder machen Export/Import und Deduplizierung zuverlaessig.
- CloudKit-Mirroring ist fuer Single-User-Backup der einfachste Ansatz, der
  Apple-Plattform-nativ ist und keine Backend-Infrastruktur benoetigt.

**Negativ / Risiken**

- Der Migrations-Zweischritt (Schema + CloudKit separat) erfordert Disziplin beim
  Release-Management; ein Fehler hier kann Nutzerdaten beschaedigen.
- CloudKit-Schema-Constraints (keine Unique-Constraints, optionale Beziehungen)
  sind weniger ausdrucksstark als ein unkontrolliertes lokales Schema; Schemabrueche
  im laufenden Betrieb sind in CloudKit kaum rueckgaengig zu machen.
- `updatedAt` muss in jedem Schreibpfad manuell gebumpt werden — wird das
  vergessen, fuehrt LWW zu stillem Datenverlust. Code-Review-Checkliste ist noetig.
- Rueckwaertskompatibilitaet beim Import erhoet die Komplexitaet der
  `ExportImportService`-Implementierung.

**Neutral**

- Jedes Modell traegt ein zusaetzliches `id: UUID`-Feld und ein `updatedAt: Date`-
  Feld. Overhead ist vernachlaessigbar.

---

## Alternativen

**Option A: Serverseitige Konfliktaufloesung via eigenes Backend**  
Abgelehnt. ShipTrip ist eine Single-User-App; ein eigenes Backend fuer
Konfliktmerging ist Overengineering. CloudKit LWW genuegt fuer den Anwendungsfall
"letzte Aenderung gewinnt" bei einem Nutzer auf mehreren Geraeten.

**Option B: CKShare / benutzerdefinierte CloudKit-Operationen**  
Abgelehnt. SwiftData-Mirroring abstrahiert die CKRecord-Ebene vollstaendig.
Eigene CKShare-Logik wuerde diese Abstraktion durchbrechen und den Wartungsaufwand
drastisch erhoehen, ohne fuer den Kern-Anwendungsfall einen Mehrwert zu bieten.

**Option C: JSON+Base64-Export beibehalten**  
Abgelehnt. Das Format skaliert nicht: Ein einziges Foto mit 3 MB produziert eine
Base64-Sequenz von ca. 4 MB. Bei 50+ Fotos werden Exports unhandlich gross und
koennen App-Memory-Limits treffen. ZIP mit externen Dateien ist das
Standardverfahren fuer diesen Anwendungsfall (vgl. Audit-Befund H4).

**Option D: `@Attribute(.unique)` auf `id` setzen und auf CloudKit verzichten**  
Abgelehnt. Unique-Constraints und CloudKit-Mirroring schliessen sich gegenseitig
aus. Da CloudKit als primaerer Sync-Mechanismus beschlossen wurde, faellt Unique-
Constraint auf Datenbankebene weg; Eindeutigkeit wird App-seitig sichergestellt.

---

## Implementierungsaufgaben (getrieben von diesem ADR)

Dieses ADR treibt folgende Task-Kategorien, die in Phase 1 umgesetzt werden:

- **T-SCHEMA**: Modell-Anpassungen (stabile `id`, `updatedAt` auf allen Modellen,
  Default-Wert fuer `Photo.imageData`, optionale Beziehungen pruefen)
- **T-EXPORT**: ZIP-Export/-Import in `ExportImportService`, rueckwaertskompatible
  Base64-Erkennung
- **T-CK**: CloudKit-Capability (manuell Andre), Container-Konfiguration,
  Smoke-Tests auf bevoelkertem Store

---

## Referenzen

- ADR-001 — `isDemo`-Attribut im Release-Schema (geteilte Schema-Stabilitaets-Motivation)
- `docs/features/phase-0-fixes-und-demo-modus.md` — Ausgangslage und Audit-Befunde
- `docs/features/phase-1-vertrauen-und-substanz.md` — Implementiert durch Phase 1
- `ShipTrip/Models/Cruise.swift`, `Deal.swift`, `Photo.swift`, `Port.swift`,
  `Expense.swift` — betroffene Modelle
- Apple Dokumentation: SwiftData + CloudKit (`ModelConfiguration(cloudKitDatabase:)`)
- SwiftData-Skill (`~/.claude/skills/swiftdata/SKILL.md`), Abschnitt 6 "CloudKit sync"
