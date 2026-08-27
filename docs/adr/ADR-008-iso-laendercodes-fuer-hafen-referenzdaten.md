# ADR-008: ISO-Ländercodes für die Hafen-Referenzdaten

**Status:** Accepted
**Datum:** 2026-08-27
**Autor:** Developer (Taskplan D1 „ISO-Ländercodes", Audit 3.2/H-C)
**Querverweis:** ADR-006 (Referenzdaten-Katalog + Overlay-Muster)

---

## Kontext

`PortSuggestion.popular` (`ShipTrip/Models/PortSuggestion.swift`) ist ein
hartkodierter Katalog von ~1.800 Häfen aus einem Wikidata-Import. Jeder Eintrag
trägt einen `country: String` — **ausschließlich in deutscher Schreibweise**
(„Spanien", „Griechenland", „USA"). Dieser Wert wird bei der Hafen-Auswahl in
`Port.country` kopiert und persistiert.

Seit Phase 1 ist die App zweisprachig (DE/EN, String Catalog). Die Ländernamen
folgen dieser Umstellung bisher nicht: Auf einem englischsprachigen Gerät zeigen
Hafen-Auswahl, Reise-Detail und die Karten-Stopp-Liste weiterhin „Griechenland"
statt „Greece". Der Audit-Befund 3.2/H-C fordert deshalb ISO-3166-Ländercodes in
den Referenzdaten plus Anzeige über `Locale.localizedString(forRegionCode:)`.

Randbedingungen:

- Die Referenzdaten enthalten **117 verschiedene** Ländernamen — nicht 1.800.
  Das Mapping ist damit klein genug für eine explizite Tabelle.
- Der Katalog enthält Wikidata-Artefakte, die keine heutigen Staaten sind
  („Antikes Athen", „Byzantinisches Reich", „Britisch-Hongkong").
- `Port.country` ist persistierter Nutzerdatenbestand und Teil des
  Export-/Teilen-Formats (`ExportImportDTOs.swift`). Eine Änderung des
  gespeicherten Werts wäre eine Formatänderung mit Migrationsbedarf.
- Nutzer können Häfen manuell erfassen und dabei ein beliebiges Land tippen.

## Entscheidung

**1. Der Ländername bleibt der Schlüssel, der ISO-Code kommt aus einer
Mapping-Tabelle — keine Codes pro Hafen.**

Ein neues `enum PortCountryCatalog`
(`ShipTrip/Models/PortSuggestion+Country.swift`) hält eine Tabelle
`Bestandsname → ISO-3166-1-Alpha-2` mit 112 Einträgen. `PortSuggestion` bekommt
zwei abgeleitete Properties:

- `regionCode: String?` — der ISO-Code des Hafenlandes,
- `localizedCountry: String` — der Ländername in der Gerätesprache.

Die ~1.800 Hafenzeilen bleiben unverändert. Ein Code pro Hafen wäre 1.800 Zeilen
redundante Handpflege für eine Information, die vollständig aus dem Land folgt.

**2. Die Tabelle wurde deterministisch aus dem Bestand abgeleitet, nicht
handgepflegt.**

Für jede ISO-Region wurde der deutsche ICU-Name
(`Locale(identifier: "de_DE").localizedString(forRegionCode:)`) berechnet und
gegen die 117 Bestandsnamen abgeglichen. 103 Namen trafen exakt. Die restlichen
14 wurden einzeln bewertet (siehe Konsequenzen). Damit ist die Tabelle
reproduzierbar und bei einem künftigen Referenzdaten-Update mit demselben
Verfahren erweiterbar.

**3. Die Anzeige geht über den Code, der Fallback über den Bestandsnamen.**

```
localizedName(for:) → regionCode(for:) → Locale.current.localizedString(forRegionCode:)
                   ↘ kein Code / kein Locale-Name ⇒ Bestandsname unverändert
```

Der Fallback ist der Normalfall für manuell erfasste Länder und für die
historischen Katalog-Einträge — nicht ein Fehlerpfad.

**4. Persistenz und Export bleiben unangetastet.**

`Port.country` speichert weiterhin den deutschen Bestandsnamen. Der ISO-Code ist
reine Anzeige-Ableitung. Kein SwiftData-Schema-Change, keine CloudKit-Migration,
keine Änderung am Export-/Teilen-Format.

**5. Getauscht wurde nur die Namens-Quelle, keine View-Struktur.**

Sechs reine Anzeigestellen lesen den Ländernamen jetzt über den Katalog:
Hafen-Auswahl in `PortFormView` (Vorschlagsliste + gewählter Hafen),
Hafen-Auswahl in `CruiseFormView` (Vorschlagsliste + Routen-Zeile),
`CruiseDetailView` (Routen-Zeile), `RouteStopSheetView` (Stopp-Liste) und das
VoiceOver-Label in `MapView+RouteInteraction`. Die `TextField`-Bindings der
manuellen Eingabe bleiben auf dem Rohwert — sie schreiben nach `Port.country`.

## Alternativen

- **ISO-Code als gespeichertes Feld auf `Port`.** Sauberer im Datenmodell, aber
  SwiftData-Schema-Change unter den CloudKit-Constraints aus ADR-002 plus
  Backfill für Bestandsdaten plus Export-Formatänderung — deutlich mehr Risiko
  als der Anzeige-Nutzen rechtfertigt. Bleibt möglich, falls später
  code-basierte Features dazukommen (Flaggen, Gruppierung nach Region).
- **Reverse-Lookup zur Laufzeit statt Tabelle.** Den ICU-Index bei jedem Start
  aufbauen und den deutschen Namen darin nachschlagen. Spart die Tabelle, macht
  das Verhalten aber von ICU-Namensänderungen zwischen iOS-Versionen abhängig
  und ist im Review nicht greppbar. Die Ableitung gehört in den Build-Zeitpunkt,
  nicht in den Start.
- **Ländernamen in den String Catalog.** 117 Einträge doppelt pflegen, die das
  System bereits in allen Sprachen kennt. Verworfen.
- **Bestandsdaten auf ISO-Codes umschreiben.** Migration von Nutzerdaten plus
  Bruch mit älteren Export-Dateien für einen reinen Anzeige-Fix.

## Konsequenzen

**Positiv**

- Ländernamen folgen der Gerätesprache; auf EN-Geräten steht „Greece" statt
  „Griechenland".
- Kein Schema-, Migrations- oder Formatrisiko.
- `regionCode` steht als Basis für spätere Features (Flaggen, Regionsstatistik)
  bereit, ohne dass jetzt etwas davon gebaut wird.

**Negativ / bewusst in Kauf genommen**

- **9 deutsche Labels ändern sich** auf den OS-Standardnamen: `USA` →
  „Vereinigte Staaten", `Großbritannien` → „Vereinigtes Königreich", `VAE` →
  „Vereinigte Arabische Emirate", `Kap Verde` → „Cabo Verde",
  `US-Jungferninseln` → „Amerikanische Jungferninseln", `Elfenbeinküste` →
  „Côte d'Ivoire", `Demokratische Republik Kongo` → „Kongo-Kinshasa",
  `Föderierte Staaten von Mikronesien` → „Mikronesien", `Brunei` → „Brunei
  Darussalam". Das ist die Konsequenz daraus, den Systemnamen zur Quelle zu
  machen; die übrigen 103 Namen bleiben auf DE-Geräten wortgleich.
- **5 Bestandsnamen bleiben bewusst ohne Code** und damit unübersetzt:
  - `Antikes Athen`, `Byzantinisches Reich`, `Britisch-Hongkong` — historische
    Entitäten ohne aktuellen ISO-Code (Datenqualitätsartefakte des
    Wikidata-Imports; separat zu bereinigen, nicht hier).
  - `China` (CN) und `Bonaire` (BQ) — der Code existiert, aber der
    ICU-Anzeigename („China, Festland" bzw. „Karibische Niederlande") ist für
    eine Kreuzfahrt-App schlechter als der Bestandsname. Tagged Exception,
    Owner ShipTrip, Review beim nächsten Referenzdaten-Update.
- **Anzeige und Eingabefeld können auseinanderlaufen:** Auf einem EN-Gerät zeigt
  die Vorschlagsliste „Spain", das Feld „Land" nach der Auswahl aber weiterhin
  „Spanien" — weil dort der zu speichernde Rohwert steht. Auf DE-Geräten ist der
  Unterschied unsichtbar. Auflösen ließe sich das nur mit Entscheidung 4
  (gespeicherter Code), siehe Alternativen.
- Neue Länder in künftigen Referenzdaten-Importen brauchen einen Tabelleneintrag.
  Der Test `everyPortCountryIsCoveredOrDocumented` schlägt sonst fehl.

## Verifikation

`ShipTripTests/PortCountryCatalogTests.swift` deckt Mapping, Alias-Fälle,
Whitespace-Toleranz, Fallback ohne Code, die Locale-Anbindung, die Gültigkeit
aller hinterlegten Codes gegen `Locale.Region.isoRegions` und die vollständige
Abdeckung aller im Katalog vorkommenden Länder ab.
