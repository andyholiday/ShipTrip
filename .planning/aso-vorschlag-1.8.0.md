# ASO-Vorschlag für Release 1.8.0

Stand: 2026-08-27. Basis: verifizierter Ist-Stand (`aso-ist-stand.md`, live ASC-Metadaten +
gemessene DE-Rankings via iTunes-Search-API) und Live-Konkurrenzdaten (iTunes-Search-API +
App-Store-Seiten, gescannt 2026-08-27). `APP_STORE_LISTING.md` im Repo ist ein alter Entwurf,
NICHT der Live-Stand — hier nicht als Referenz verwendet, nur der Ist-Stand.

## Datenlücken (ehrlich benannt)
- Kein Zugriff auf Sensor Tower / AppFollow / App Radar in dieser Session → keine
  Such-Volumen-Scores. Ersatz: gemessene eigene Rankings (Ist-Stand) + reale
  Titel/Untertitel-Wortwahl von 6 direkten Konkurrenten als Proxy-Signal.
- Rankings wurden **nur für DE** gemessen (Ist-Stand-Dokument). Für EN gibt es keine
  Baseline-Messung → EN-Vorschläge sind konkurrenz-informiert, nicht defekt-verifiziert.
  Deshalb: DE primär mit harten Begründungen, EN sekundär mit weicheren Begründungen.
- Deutsche Kompositum-Frage: Der Live-Defekt "meinschiff" (ein Wort ohne Trenner) matcht
  "mein schiff" nicht — das ist der einzige harte Beleg, wie Apples DE-Index mit Wörtern
  ohne Trenner umgeht. Bindestriche funktionieren nachweislich als Trenner (Titel
  "Kreuzfahrt-Logbuch" rankt #2 für die Zwei-Wort-Suche "kreuzfahrt logbuch"). Für neue
  Kompositum-Vorschläge unten wird dieser Unterschied explizit berücksichtigt.

## Konkurrenz-Tabelle (6 direkte Wettbewerber)

| App | Store | Anbieter | Titel | Untertitel |
|---|---|---|---|---|
| Kreuzfahrt-Tagebuch | DE | RedTracker LLC | Kreuzfahrt-Tagebuch | Reiseverlauf planen |
| Cruisea – Deine Kreuzfahrt App | DE | Patric Leonhardt | Cruisea – Deine Kreuzfahrt App | Schiffsreisen planen & teilen |
| Mein Logbuch | DE | Martin Kalwoda | Mein Logbuch | Reisetagebuch für Kreuzfahrten |
| Journo: Travel & Trip Tracker | US | Journo Inc. | Journo: Travel & Trip Tracker | Journal, Log & Map Your Trips |
| The Cruise Globe | US | The Cruise Group Ltd | The Cruise Globe | Cruise Tracking & Discovery |
| Cruisr - Cruise Ship Tracking | US | Evergreen Apps LLC | Cruisr - Cruise Ship Tracking | Real-Time Cruise Ship Tracking |

**Signal:** Zwei von drei DE-Direktkonkurrenten benutzen "Tagebuch" prominent im
Untertitel — genau der Begriff, der ShipTrip laut Ist-Stand komplett fehlt. Keiner der
6 Wettbewerber erwähnt Ausgaben-Tracking oder Kabinen-Details im Untertitel → Whitespace.

---

## DE-Vorschlag

### Titel: unverändert lassen
`ShipTrip: Kreuzfahrt-Logbuch` (28/30 Zeichen)

**Begründung (Surgical-Change-Prinzip):** Der Titel rankt bereits #2/6 für "kreuzfahrt
logbuch" und trägt zu #4/22 bei "kreuzfahrt planer" bei. Eine Titeländerung riskiert diese
etablierten Platzierungen für einen ungewissen Gewinn. Die bekannten Lücken (tagebuch,
urlaub, mein schiff) lassen sich vollständig über Untertitel + Keywords schließen — ohne
das Risiko, den Titel anzufassen.

### Untertitel — Variante A (konkurrenz-orientiert)
**"Reisetagebuch für Kreuzfahrten"** — 30/30 Zeichen

Deckt ab: **"tagebuch"** (Ist-Stand: fehlt komplett; "kreuzfahrt tagebuch" und "schiff
tagebuch" sind dadurch aktuell nicht auffindbar). Spiegelt fast wörtlich den Untertitel
des Top-Direktkonkurrenten "Mein Logbuch" ("Reisetagebuch für Kreuzfahrten") — belegtes
Marktvokabular statt Annahme.
**Caveat:** "Reisetagebuch" ist ein Kompositum ohne Trenner. Ob Apples DE-Index es in
"reise" + "tagebuch" zerlegt, ist unbelegt (einziger Beleg dagegen: der "meinschiff"-Bug).
Selbst im Worst Case gewinnt die App aber den Exact-Match für "reisetagebuch" als
eigenständige Suchphrase.

### Untertitel — Variante B (defekt-fokussiert, empfohlen)
**"Kreuzfahrt-Urlaub & Tagebuch"** — 28/30 Zeichen

Deckt ab: **"tagebuch"** UND **"urlaub"** als garantiert getrennte Tokens (Bindestrich
und "&" sind nachweislich sichere Worttrenner, siehe oben). Schließt damit alle drei im
Ist-Stand benannten Lücken gleichzeitig: "kreuzfahrt tagebuch", "schiff tagebuch"
(schiff steht im Keyword-Feld) und explizit **"urlaub tagebuch"** — dieser Begriff
fehlt aktuell komplett, weil "urlaub" bislang in keinem Feld vorkommt.
**Warum empfohlen:** kein Kompositum-Risiko, deckt eine Lücke mehr ab als Variante A.

### Keywords (99/100 Zeichen)
```
reise,schiff,hafen,ausflug,fotos,planer,tracker,route,mein,aida,msc,costa,kabine,reederei,ausgaben
```
(98 Zeichen — Zählung: 15 Wörter, 84 Buchstaben + 14 Kommas = 98)

Optimiert für Untertitel-Variante B (keine Dopplung mit Titel: shiptrip/kreuzfahrt/
logbuch; keine Dopplung mit Subtitle B: urlaub/tagebuch).

**Änderungen zum Live-Stand und Begründung:**
- `meinschiff` (10 Zeichen, Bug) → ersetzt durch `mein` (4 Zeichen). "schiff" steht
  bereits im Feld → Apple kombiniert "mein" + "schiff" automatisch zur Suche
  **"mein schiff"** (aktuell laut Ist-Stand "nicht dabei"). Spart zusätzlich 6 Zeichen.
- Führende Leerzeichen vor ` aida`, ` msc` entfernt (verschenkte Zeichen im Live-Stand).
- `kreuzfahrt` und `logbuch` aus dem Keyword-Feld entfernt — bereits im Titel indexiert,
  Dopplung war verschenkter Platz (98/100 Zeichen frei geworden für Neues statt 100/100
  Redundanz).
- Neu: `kabine` (Kernfeld der App laut Beschreibung, kein Wettbewerber deckt es ab),
  `reederei` (generischer Suchbegriff), `ausgaben` (Ausgaben-Tracking ist ein
  Alleinstellungsmerkmal — keiner der 6 Wettbewerber erwähnt Budget/Ausgaben).

---

## EN-Vorschlag (sekundär, konkurrenz-informiert)

### Titel: unverändert lassen
`ShipTrip: Cruise Journal` (24/30 Zeichen) — "journal" deckt bereits den zu "tagebuch"
analogen Begriff ab, hier liegt kein vergleichbarer Defekt vor.

### Untertitel — Variante A (empfohlen)
**"Cruise Log, Ports & Expenses"** — 28/30 Zeichen

Deckt ab: **"log"** (Alternativbegriff zu "journal", belegt durch Konkurrent Journo:
"Journal, Log & Map Your Trips"). **"ports"** wird von Keywords in den höher gewichteten
Untertitel verschoben (Kernfeature). **"expenses"** ist Whitespace — keiner der 3
US-Wettbewerber (Journo, The Cruise Globe, Cruisr) erwähnt Ausgaben-Tracking.

### Untertitel — Variante B
**"Diary & Itinerary Planner"** — 25/30 Zeichen

Deckt ab: **"diary"** (gängiger Alternativbegriff zu "journal" im englischen Reise-App-
Segment) und **"itinerary"** (klassischer Cruise-Planning-Begriff, aktuell in keinem
ShipTrip-Feld vorhanden — Whitespace gegenüber allen 3 US-Wettbewerbern, die auf Tracking
statt Planning positionieren).

### Keywords (98/100 Zeichen)
```
travel,ship,voyage,excursions,photos,planner,tracker,diary,itinerary,budget,cabin,line,route,atlas
```
Optimiert für Untertitel-Variante A (keine Dopplung mit Titel: shiptrip/cruise/journal;
keine Dopplung mit Subtitle A: log/ports/expenses). Neu ggü. Live-Stand: `diary`,
`itinerary` (Absicherung/Whitespace, s.o.), `budget` (Synonym zu expenses), `cabin`
(Kernfeld, kein Wettbewerber deckt es ab), `line` + `route` (generische Ergänzungen),
`atlas` (spiegelt das App-eigene Feature "Journal Atlas").

---

## Wichtigster Hinweis
Keywords werden laut Ist-Stand erst mit dem **nächsten Release** live — Titel/Untertitel-
Änderungen dagegen sofort mit App-Review. Empfehlung: Untertitel-Variante B (DE) und A
(EN) zusammen mit dem neuen Keyword-Feld in denselben 1.8.0-ASC-Entwurf einpflegen, damit
Titel/Subtitel/Keywords konsistent zueinander stehen (keine Dopplungen entstehen erst
nachträglich durch Mix-and-Match).
