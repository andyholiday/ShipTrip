# Narrativ — Onboarding (Erststart), Release 1.8.0

Abgeleitet aus Code und vorhandenen App-Screenshots (`audit/screenshots/`),
nicht aus einem Interview. Umfang bewusst eine Seite: die Design-Phase läuft
für diese Aufgabe als **Light-Variante** (eine Richtung, kein Pitch, kein
externer Benchmark — die bestehende App *ist* der Benchmark).

## Persona

Andrea, 52, hat gerade eine Kreuzfahrt nach Norwegen gebucht und ShipTrip
installiert, weil sie ihre Reisen sonst in Handyfotos und einem Notizzettel
verliert. Sie öffnet die App zum ersten Mal am Abend auf dem Sofa, hat zwei
Minuten Geduld und will wissen, ob sich das Anlegen lohnt.

## Kernmoment

**Die erste Reise anlegen.** Nicht der Welcome-Screen — der ist nur die
Rampe dorthin. Alles im Flow, was Andrea nicht schneller zu diesem Moment
bringt, ist Ballast.

## Härtefall

**Karte 3, der Soft-Ask für Erinnerungen.** Sie ist die einzige Karte, die
etwas *fordert* statt zu zeigen, sie steht mitten im Flow und sie verbrennt
bei falscher Behandlung eine einmalige Ressource (der iOS-Dialog lässt sich
nicht zurückholen). Layout-Problem: zwei Handlungsoptionen, die
gleichrangig lesbar sein müssen, ohne dass die gewünschte Option sich
optisch selbst bevorzugt — plus ein Satz, der ehrlich sagt, was als
Nächstes passiert.

## Emotionales Ziel

„Das ist meins, und ich sehe sofort, wofür es gut ist." Weite, gutes Licht,
echte Reisefotos statt Illustration; ruhig, aufgeräumt, kein Gedränge.

## Anti-Gefühl

**Nie wie ein Formular, nie wie ein Verkaufsprospekt, nie wie ein
Bittsteller.** Konkret: keine Registrierung, keine Werbeversprechen, kein
Dialog, der um Erlaubnis bettelt oder die Ablehnung kleinschreibt.

## Inhaltstemperatur

Bildstark auf Karte 1 und 4, textlastig-ruhig auf Karte 2 und 3. Der
Wechsel ist Absicht: er gibt dem Flow einen Rhythmus statt vier gleicher
Seiten.

## Inventar — die vier Karten

| Karte | Screen-Name | Zweck | Aktionen |
|---|---|---|---|
| 1 | `karte-1` | Wertversprechen: wofür ShipTrip da ist | Weiter · Überspringen |
| 2 | `karte-2` | Kern-Features: Karte · Fotos · Erinnerungen | Weiter · Überspringen |
| 3 | `karte-3` | Soft-Ask Erinnerungen (Härtefall) | Erinnerungen aktivieren · Später · Überspringen |
| 4 | `karte-4` | Start-CTA | Erste Reise anlegen · Beispielreise ansehen |

## Flow-Map

- Einstieg: automatisch beim ersten App-Start, solange
  `hasCompletedOnboarding` (@AppStorage) `false` ist; zusätzlich manuell
  über Einstellungen → „Einführung erneut ansehen".
- Vorwärts: Karte 1 → 2 → 3 → 4, per Primär-Button oder Wischen.
- Rückwärts: Wischen nach rechts, jederzeit, ohne Zustandsverlust.
- Abkürzung: „Überspringen" (Karte 1–3) springt auf Karte 4, **nicht** aus
  dem Flow heraus — der Erststart soll nicht ohne eine Startentscheidung
  enden. Karte 4 hat kein „Überspringen" mehr; ihre beiden Aktionen sind
  die einzigen Ausgänge.
- Ausgang: „Erste Reise anlegen" → Reise-Formular · „Beispielreise ansehen"
  → Demo-Reise wird erzeugt und geöffnet. Beide setzen
  `hasCompletedOnboarding = true`.

## Bekannte Lücke

`design-library/references/patterns/onboarding-activation.md` empfiehlt
**maximal drei Schritte**. Der Flow hat vier, weil Kriterium 1 aus
`.planning/ZIEL.md` vier Karten festlegt. Der billigste Weg auf drei wäre,
Karte 1 und 2 zu verschmelzen (Foto-Hero plus die drei Feature-Zeilen auf
einer Karte). Das ist eine Produktentscheidung, keine Designfrage — hier
nur benannt, nicht getroffen.
