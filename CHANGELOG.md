# Changelog

Alle nennenswerten Änderungen am Projekt werden hier dokumentiert.

Das Format basiert auf [Keep a Changelog](https://keepachangelog.com/de/1.1.0/),
und dieses Projekt folgt [Semantic Versioning](https://semver.org/lang/de/).

## [Unreleased]

### Geplant

- ADR-konforme Reihenfolge für optionale Beziehungen und CloudKit-Aktivierung
  festlegen; Build 19 enthält noch das alte Relationship-Schema.
- Wetter-API Integration
- Hafen-Bilder mit KI-Generierung

---

## [1.8.5] - 2026-08-28

### Hinzugefuegt

- **Journal-Kern, Datenschicht**: Reisen können Journal-Einträge tragen —
  Freitext, Kalendertag, Stimmung, optionaler Hafen-Bezug und angehängte Fotos,
  mehrere Einträge pro Tag erlaubt. Fotos bekommen zusätzlich eine
  Bildunterschrift (`caption`); angehängte Fotos bleiben zugleich Kinder der
  Reise, sodass Galerie, Statistiken, Export und Teilen sich unverändert
  verhalten. Der Kalendertag ist ein Date-only-Wert (kanonisch 12:00 UTC des
  Tag-Tripels), damit ein Zeitzonenwechsel an Bord den Tag nicht verschiebt.
  Die Schema-Erweiterung ist rein additiv, ein Store aus 1.8.0 öffnet damit
  ohne Datenverlust (belegt gegen eine eingefrorene 1.8.0-Store-Fixture; der
  Nachweis auf einem echten Gerät steht noch aus). Einträge und
  Bildunterschriften wandern in das ZIP-Backup und in die
  `.shiptrip`-Teilen-Datei mit; ältere Dateien ohne diese Felder werden
  weiterhin gelesen, und eine 1.8.0-Installation importiert die neuen Dateien
  fehlerfrei, übernimmt Journal und Bildunterschriften dabei aber nicht.
  ([Feature-Doku](docs/features/journal.md),
  [ADR-003](docs/adr/ADR-003-journal-kern.md))

- **Tagebuch im Route-Abschnitt der Reise**: Das Journal bekommt keinen eigenen
  Bereich, sondern hängt im Routen-Abschnitt der Reise-Detailansicht. Jeder
  Stopp — Hafen wie Seetag — ist eine aufklappbare Karte mit seinen Einträgen
  und der Aktion „Tagebuch-Eintrag". Ein Eintrag mit Hafen-Bezug erscheint an
  genau diesem Hafen, einer ohne Bezug am ersten Stopp seines Tages, und was
  keinen Träger findet, sammelt der Block „Weitere Einträge" am Ende des
  Abschnitts. Während einer laufenden Reise stehen nur die Stopps des heutigen
  Tages offen — davor und danach alle —, Antippen übersteuert das, der Schalter
  im Abschnitts-Kopf klappt alles auf oder zu, und über Mitternacht rechnet die
  Ansicht die Vorgabe neu. Der Editor öffnet als Blatt mit der Erinnerung
  zuerst; Datum, Stopp und Stimmung sind aus der Karte vorbelegt, aus der heraus
  er gestartet wurde, Fotos lassen sich mit Bildunterschrift anhängen. Bearbeiten
  und Löschen gibt es ausschließlich in der Eintrags-Detailansicht, die eine
  angetippte Zeile öffnet. Alle Beschriftungen liegen in Deutsch und Englisch
  vor. ([Feature-Doku](docs/features/journal.md),
  [ADR-003](docs/adr/ADR-003-journal-kern.md))

- **Kreuzfahrt teilen**: Eine einzelne Reise lässt sich über das Menü der
  Reise-Detailansicht („Reise teilen") verschicken. Die Aktion erzeugt eine
  `.shiptrip`-Datei und gibt sie zusammen mit einem Nachrichtentext ins
  System-Share-Sheet (Nachrichten, WhatsApp, Mail); der Text nennt den Umfang
  der Reise und trägt den `shiptrip://import`-Link. Bei der Beispielreise fehlt
  der Eintrag. Die Datei hat dieselbe Archivstruktur wie das
  Backup, aber auf genau eine Reise beschränkt und mit Fotos, die auf 2048 px
  verkleinert, als JPEG neu gespeichert und von allen Metadaten inklusive GPS
  befreit werden; Originale und das Voll-Backup bleiben unverändert. Auf der
  Gegenseite öffnet eine angetippte `.shiptrip`-Datei die App und wird
  automatisch importiert, mit sichtbarer Ergebnis-Meldung: Vor der ersten
  Änderung am Bestand prüft die App Version, Umfang und Größe der Datei, eine
  bereits vorhandene Reise wird nicht doppelt angelegt, und eine seit dem Teilen
  geänderte Fassung des Absenders weist die Meldung als Versionskonflikt aus
  (kein Zusammenführen). Ein Tipp auf den Link allein öffnet die App mit dem
  Hinweis, die angehängte Datei zu öffnen — Träger der Daten bleibt die Datei.
  ([Feature-Doku](docs/features/kreuzfahrt-teilen.md),
  [ADR-007](docs/adr/ADR-007-kreuzfahrt-teilen.md))

- **Erststart-Onboarding (vier Karten)**: Beim ersten Start führt ein Flow über
  Wertversprechen, die drei Kern-Features, eine Frage nach den Erinnerungen und
  die Startentscheidung. Die Erlaubnis-Frage sagt vorher, was danach passiert:
  der System-Dialog erscheint ausschließlich nach „Erinnerungen aktivieren";
  „Später" und „Überspringen" lösen keinen aus und lassen die bestehende
  Nachfrage beim ersten Speichern einer Reise unberührt. Am Ende stehen zwei
  gleich große Wege — „Erste Reise anlegen" oder „Beispielreise ansehen", das
  lädt die als Demo markierten Beispieldaten. Der Flow läuft einmal und lässt
  sich über Einstellungen → *Info* → „Intro erneut zeigen" zurückholen.
  ([Feature-Doku](docs/features/onboarding.md),
  [Design-Spec](docs/design/design-spec-onboarding.md))

- **Beispielreise auch außerhalb des Debug-Builds**: Die Beispieldaten waren
  bisher komplett in `#if DEBUG` gekapselt und damit in der ausgelieferten App
  nicht vorhanden. Sie stehen jetzt in den Einstellungen unter *Beispielreise*
  und am Ende des Erststart-Flows bereit. Alles Erzeugte ist als Demo markiert,
  lässt sich mit einer Aktion wieder entfernen — Nutzerdaten bleiben dabei
  unberührt — und bleibt aus Export, Kalender-Sync und Erinnerungen
  ausgefiltert. Der Store-weite Reset bleibt Debug-only.
  ([Feature-Doku](docs/features/beispielreise.md),
  [ADR-001](docs/adr/ADR-001-isdemo-in-release-schema.md))

- **„App zurücksetzen" unter Einstellungen → *Daten verwalten***: Bringt die App
  ohne Neuinstallation in den Auslieferungszustand. Gelöscht werden alle Reisen
  und Wunschreisen, der hinterlegte KI-API-Key, sämtliche Einstellungen
  (Erscheinungsbild, Erinnerungs-Vorlauf, Kalender-Sync) sowie die von der App
  im Kalender angelegten Termine; danach startet das Intro wie beim ersten
  Öffnen und führt anschließend auf die Hauptseite (Reisen-Tab), nicht zurück
  in die Einstellungen. Bestätigungsdialog und Fußnote nennen genau diesen
  Umfang.

- **Vollständige englische Fassung (396 Schlüssel DE/EN)**: Der String Catalog
  ist auf den Stand nach Onboarding, Beispielreise und erweitertem Export
  gezogen — 75 neue Schlüssel mit EN-Übersetzung, acht verwaiste entfernt. Reine
  Interpolationsketten sind als nicht zu übersetzen markiert statt mit einer
  Schein-Übersetzung versehen.

- **Lokalisierungs-Gate in der CI**: `scripts/check-l10n.py` liest den
  String Catalog und schlägt fehl, sobald ein Schlüssel ohne englischen Wert
  existiert — inklusive leerer Werte, einzelner Plural-Zweige und einzelner
  Substitutionen. Der Job läuft ohne Xcode und Simulator parallel zum Build.

- **UI-Tests für den Erststart**: Drei Szenarien decken den Durchlauf über alle
  vier Karten, den Überspringen-Pfad auf die Startentscheidung und die
  Persistenz über einen Neustart ab. Der Erststart-Zustand kommt dabei über
  Debug-only-Startargumente statt aus dem Restzustand des Simulators; ein
  Gegenstück davon hält das Cover in der bestehenden UI-Suite geschlossen.
  ([Feature-Doku](docs/features/onboarding.md))

- **Backup sichert jetzt den ganzen Bestand**: Bisher schrieb der Export nur
  die Kreuzfahrten. Wunschreisen, eigene Reedereien, eigene Schiffe und
  ausgeblendete Katalog-Einträge liegen jetzt mit im Archiv und kommen beim
  Import zurück; die Fußnoten unter *Export* und *Import* benennen den Umfang.
  Ältere Backups bis Version 1.7 bleiben lesbar.
  ([Feature-Doku](docs/features/export-backup.md),
  [ADR-006](docs/adr/ADR-006-eigene-reedereien-und-schiffe-overlay-modell.md))

- **Automatischer Build in der CI**: Ein GitHub-Actions-Workflow baut das
  Projekt auf macOS mit gepinntem Xcode 26.6 und fährt die Unit-Tests gegen
  einen Wegwerf-Simulator, dem die Kalender-Berechtigung vorab erteilt wird.
  Build und Test laufen getrennt; bei Fehlschlag hängen die xcresult-Bundles
  als Artefakt am Lauf. Fastlane ist über ein `Gemfile` exakt auf 2.237.0
  festgelegt. Die UI-Suite bleibt vorerst außerhalb des Laufs.

- **Reproduzierbares Schema und Testplan im Repository**: Das geteilte
  Xcode-Schema `ShipTrip` und `ShipTrip.xctestplan` sind eingecheckt, damit
  `xcodebuild -scheme ShipTrip` überall dieselbe Konfiguration auflöst statt
  auf Xcodes automatisch erzeugtes Schema zu treffen.

### Geaendert

- **Ländernamen folgen der Gerätesprache**: Die ~1.800 Häfen der Referenzdaten
  trugen ihr Land als deutschen Klartext, der auch auf englischsprachigen
  Geräten so angezeigt wurde. Die 117 Bestandsnamen sind jetzt auf
  ISO-3166-Codes abgebildet; Hafen-Auswahl, Routen-Zeilen, Karten-Stopp-Liste
  und das zugehörige VoiceOver-Label lesen den Namen aus der Geräte-Locale
  („Greece" statt „Griechenland"). Gespeichert, exportiert und geteilt wird
  weiterhin der bisherige Wert — kein Schema- oder Formatwechsel. Auf deutschen
  Geräten ändern sich dadurch **neun Beschriftungen** auf den Systemnamen: USA →
  „Vereinigte Staaten", Großbritannien → „Vereinigtes Königreich", VAE →
  „Vereinigte Arabische Emirate", Kap Verde → „Cabo Verde", US-Jungferninseln →
  „Amerikanische Jungferninseln", Elfenbeinküste → „Côte d'Ivoire",
  Demokratische Republik Kongo → „Kongo-Kinshasa", Föderierte Staaten von
  Mikronesien → „Mikronesien", Brunei → „Brunei Darussalam". Jede davon lässt
  sich einzeln zurücknehmen, indem die betreffende Alias-Zeile in
  `PortCountryCatalog` entfällt — dann bleibt der Bestandsname stehen, wie schon
  bei „China" und „Bonaire".
  ([ADR-008](docs/adr/ADR-008-iso-laendercodes-fuer-hafen-referenzdaten.md))

- **Produktrichtung: Einmalkauf statt Freemium-Abo**: Die Monetarisierung ist
  als Einmalkauf festgeschrieben; die Reservierung für ein StoreKit-2-Freemium
  ist damit aufgelöst. Reine Entscheidungs- und Doku-Änderung, in der App ist
  bisher nichts davon gebaut.
  ([ADR-004](docs/adr/ADR-004-einmalkauf.md))

- **Reise-Formular in einzelne Dateien aufgeteilt**: Die vier bisher in
  `CruiseFormView.swift` eingebetteten Dialoge (Erinnerungs-Nachfrage,
  Hafen-Erfassung während der Reiseerstellung, KI-Import, Bewertungsauswahl)
  liegen jetzt in eigenen Dateien unter `ShipTrip/Views/Cruises/`, und die
  wortgleich doppelt vorhandene „Hafen-Momente"-Section existiert nur noch
  einmal (`HafenMomenteSection`). Reines Verschieben und Zusammenführen ohne
  Verhaltens- oder Layout-Unterschied; Vorstufe für den Journal-Editor.

- **Reise-Übersicht zählt „Anläufe", die Bilanz „Häfen"**: Beide Ansichten
  trugen dieselbe Beschriftung für zwei verschiedene Kennzahlen — die
  Übersicht zählt jeden Anlauf inklusive Mehrfachbesuchen, die Bilanz nur
  eindeutige Häfen. Die Zahlen (etwa 57 gegenüber 43) widersprechen sich
  dadurch nicht mehr; beide Kennzahlen bleiben erhalten.

- **Export läuft strömend und außerhalb des Hauptthreads**: Das Archiv wurde
  bisher vollständig im Speicher aufgebaut — rund zwei Kopien der
  Bildbibliothek. Jetzt schreibt der Export Bild für Bild direkt in die
  Zieldatei; der Spitzenverbrauch richtet sich nach dem größten Einzelbild
  statt nach der Gesamtgröße. Ein laufender Export lässt sich abbrechen.
  ([Feature-Doku](docs/features/export-backup.md))

- **Doku zu Modellen, Datenfluss und Test-Setup nachgezogen**: `docs/MODELS.md`
  beschreibt alle acht SwiftData-Modelle samt Katalog-Overlay und
  Dedup-Regeln, `docs/ARCHITECTURE.md` den Export-/Import-Datenfluss mit
  seinen Grenzen, `docs/CONTRIBUTING.md` die Trennung von Swift Testing für
  Unit- und XCTest für UI-Tests.

- **`.gitignore` deckt die Video-Renderprojekte ab**: Generierte Render-,
  Snapshot- und Thumbnail-Ordner sowie Video-Dateiendungen werden nicht mehr
  als unversionierte Änderungen angeboten; die Quelldateien der Projekte
  bleiben versionierbar. Es wurde nichts gelöscht und keine Historie
  umgeschrieben.

### Behoben

- **Journal-Editor verlor frisch gewählte Fotos**: Wer direkt nach dem Auswählen
  auf „Speichern" tippte, sicherte den Eintrag ohne die noch übertragenen Bilder
  — sie verschwanden still mit dem geschlossenen Blatt. „Speichern" bleibt jetzt
  gesperrt, solange Fotos übertragen werden (Hinweis „Fotos werden geladen …"),
  und ein fehlgeschlagener Transfer wird gemeldet statt kommentarlos zu fehlen.
  ([Feature-Doku](docs/features/journal.md))
- **Erinnerungen nach dem Soft-Ask erst beim nächsten Start**: „Erinnerungen
  aktivieren" im Erststart fragte nur die Berechtigung ab und plante nichts;
  bereits vorhandene Reisen bekamen ihre Erinnerungen deshalb verspätet. Nach
  erteilter Berechtigung läuft jetzt sofort derselbe Abgleich wie beim
  App-Start. Die Schalter in den Erinnerungs-Einstellungen bleiben unangetastet.
  ([Feature-Doku](docs/features/onboarding.md))
- **Erststart-Flow wäre beim Update aus 1.7.x erschienen**: Ein fehlender
  Schalter galt als „noch nie durchlaufen". Der Start unterscheidet jetzt
  dreiwertig zwischen fehlendem, zurückgesetztem und gesetztem Schalter und hakt
  eine Bestandsinstallation mit vorhandenen Reisen still ab. Ein über die
  Einstellungen angefordertes Wiedersehen bleibt davon unberührt.
  ([Feature-Doku](docs/features/onboarding.md))
- **Erststart-Flow über der Datenverlust-Warnung**: Fällt der Start auf den
  In-Memory-Store zurück, standen Warnung und Erststart-Cover gleichzeitig
  bereit. Die Warnung hat jetzt Vorrang; das Cover bleibt zurück, ohne den
  Schalter zu setzen, und der Erststart steht beim nächsten gesunden Start
  unverändert an.
  ([Feature-Doku](docs/features/onboarding.md))
- **Mehrfach-Tap auf „Erinnerungen aktivieren"** forderte mehrere
  System-Dialoge an; beide Aktionen der Karte sind während der laufenden Abfrage
  gesperrt.
- **Sechs Eckdaten-Titel und vier Push-Texte blieben immer deutsch**: Die
  Titel *Schiff*, *Reederei*, *Zeitraum*, *Dauer*, *Kabine* und *Buchung* im
  Reise-Detail wurden als einfacher String durchgereicht, die vier
  Erinnerungs-Texte als rohe Interpolation zusammengesetzt — beide konnten den
  String Catalog nie erreichen. Sie sind jetzt übersetzbar und in EN vorhanden.
- **Lokalisierungs-Gate meldete einen kaputten Katalog als vollständig**: Ein
  Katalog ohne `strings`-Feld lief durch eine leere Schleife und galt als grün;
  ungültiges JSON platzte als Traceback. Das Gate prüft jetzt die Grundstruktur
  vorab und meldet den Bruch als regulären Fund.
- **CI baute ohne die gepinnte Xcode-Version weiter**: Ein fehlendes
  `Xcode_26.6.app` war nur eine Warnung, der Lauf ging mit einem beliebigen
  Standard-Xcode grün durch. Der Schritt bricht jetzt ab und verifiziert
  zusätzlich die tatsächlich aktive Version.
- **Halbe Sterne gingen im Backup verloren**: Die Bewertung wurde als ganze
  Zahl exportiert, 4,5 Sterne kamen als 4 zurück. Sie wird jetzt in voller
  Auflösung gesichert.
- **Fotos wurden beim Import zu Dubletten**: Die Foto-Identität stand nicht im
  Archiv, jeder Import legte neue Objekte an. Die Kennung wird jetzt
  mitgeschrieben und übernommen; innerhalb eines Archivs oder gegen bereits
  vorhandene Fotos doppelte Kennungen werden erkannt, ohne den Import
  abzubrechen.
- **Seetage verloren Land und Koordinaten**: Der Export leerte beide Felder für
  Seetage, nach dem Import fehlten sie. Sie bleiben jetzt erhalten.
- **Export-Knopf war ohne Reisen gesperrt**: Wer nur Wunschreisen, eigene
  Reedereien, eigene Schiffe oder Ausblendungen gepflegt hatte, kam nicht an
  ein Backup. Der Knopf sperrt erst, wenn nichts Exportierbares vorhanden ist.
- **Export konnte Archive erzeugen, die der eigene Import ablehnt**: Schreiben
  und Lesen kannten unterschiedliche Größengrenzen. Beide Richtungen prüfen
  jetzt gegen dieselben Grenzen, und zwar vor dem Schreiben.
  ([Feature-Doku](docs/features/export-backup.md))
- **Unvollständige Backups meldeten Erfolg**: Ein zwischenzeitlich geleertes
  Hafenbild landete als leerer Eintrag im Archiv, ein Abbruch oder ein
  Schreibfehler ließ eine halbe Datei zurück, die von einem vollständigen
  Backup nicht zu unterscheiden war. Jetzt gilt: entweder das Archiv enthält
  alle Medien, oder es entsteht keine Datei.
- **Löschen während eines laufenden Exports**: Export, Import und „Alle Daten
  löschen" waren nur einzeln gegen sich selbst gesperrt. Die drei Aktionen
  sperren sich jetzt gegenseitig.
- **Screenshot-Tests scheiterten auf fremden Rechnern**: Die neun
  Screenshot-UI-Tests schrieben auf einen fest verdrahteten Pfad. Das
  Zielverzeichnis kommt jetzt aus `SHIPTRIP_SCREENSHOT_DIR`; fehlt die
  Variable, werden die Tests übersprungen statt zu scheitern.
- **Gelöschte Hafen- und Foto-Bezüge eines Tagebuch-Eintrags konnten per Sync
  zurückkehren**: Vier Wege entfernten Häfen oder Fotos direkt — das Löschen
  eines Hafens im Reise-Detail, das Zusammenführen doppelter Häfen und der
  Route-Abgleich beim Speichern des Reise-Formulars sowie das Abwählen eines
  Fotos. Der betroffene Eintrag galt dabei als unverändert, sodass ein anderes
  Gerät seinen älteren Stand mit dem gelösten Bezug hätte durchsetzen können.
  Alle vier Wege markieren den Eintrag jetzt als geändert.
  ([Feature-Doku](docs/features/journal.md))

---

## [1.7.1] - 2026-08-23

### Hinzugefuegt

- **Hinweis vor der KI-Erfassung**: Das Sheet zur KI-gestützten Reise-Erfassung
  weist in DE und EN darauf hin, dass der eingefügte Text zur Auswertung an
  Google Gemini übertragen wird.
- **Datenschutzerklärung und Support in den Einstellungen**: Der Info-Bereich
  verlinkt jetzt die Datenschutzerklärung (sprachabhängig DE/EN) und den
  Support-Kontakt.

### Geaendert

- **Erinnerungs-Einstellungen gelten jetzt auch für bereits gespeicherte und
  importierte Reisen**: Beim App-Start werden die Erinnerungen aller
  zukünftigen Reisen anhand der aktuellen Einstellungen (Erinnerungen aktiv,
  Tage vorher, Abreise-Erinnerung) neu geplant. Bisher wirkten Änderungen an
  den Einstellungen nur auf Reisen, die danach gespeichert wurden.
  ([Feature-Doku](docs/features/erinnerungen.md))

### Behoben

- **Erinnerung kam mehrfach gleichzeitig**: Der Kennzeichner einer geplanten
  Mitteilung stammte aus der SwiftData-internen Objekt-ID, die sich beim
  Speichern und nach dem iCloud-Abgleich ändert; iOS ersetzte die vorhandene
  Mitteilung deshalb nicht, sondern legte eine weitere an. Erinnerungen hängen
  jetzt an der stabilen Reise-ID (`Cruise.id`) und werden vor jedem Planen
  entfernt. Beim App-Start räumt ein Abgleich zusätzlich bereits gespeicherte
  Doppel und Alt-Einträge früherer Versionen auf; Demo-Reisen bleiben
  ausgenommen.
  ([Feature-Doku](docs/features/erinnerungen.md),
  [ADR-002](docs/adr/ADR-002-cloudkit-sync-und-stabile-ids.md))
- **Hafen bearbeiten verwarf selbst gesetzte Koordinaten**: Beim Speichern
  eines Hafens im Reise-Formular lief die Katalogsuche auch dann erneut, wenn
  nur andere Felder geändert wurden — bei katalogfremden Hafennamen verschwand
  der Pin danach wortlos von der Karte. Der Katalog wird jetzt nur noch bei
  geändertem Namen oder Land befragt; Leerzeichen und Groß-/Kleinschreibung
  zählen dabei nicht als Änderung, und ohne Treffer bleiben vorhandene
  Koordinaten erhalten.
- **„1 Reisen" und „In 1 Tagen"**: Zähl-Texte in Reiseliste, Hero-Karte,
  Statistik, Karte, Reise-Detail, Deals und Einstellungen tragen jetzt echte
  Pluralformen in DE und EN. Ein Tag vor Reisebeginn steht „Morgen" statt
  „In 1 Tagen".

---


## [1.7.0] - 2026-07-10

### Hinzugefuegt

- **CloudKit-Production-Schema (08.08.2026)**: Die acht ShipTrip-Record-Types,
  zugehörigen Indizes und Security Roles wurden von Development nach Production
  promotet. Der anschließend exportierte Production-Stand liegt unter
  `docs/cloudkit/ShipTrip-production.ckdb` und entspricht semantisch dem
  dokumentierten Development-Schema.

- **Kalender-Sync mit sichtbarem Arbeitszustand (Build 21,
  TestFlight-Feedback vom 13.07.2026)**: Manuelles Synchronisieren zeigt nun
  während der Operation einen lokalisierten Fortschrittszustand; erneute Starts
  und abhängige Eingaben bleiben bis zum Abschluss gesperrt.
  ([Feature-Doku](docs/features/testflight-feedback-build-21.md))

- **iCloud-Sync (Build 20, TestFlight-Feedback vom 12.07.2026)**: SwiftData
  verwendet nun den privaten Container `iCloud.com.andre.ShipTrip`; die App zeigt
  den aktuellen iCloud-Accountstatus in den Einstellungen. Das zugehörige Schema
  liegt unter `docs/cloudkit/ShipTrip.ckdb` und ist in Development installiert.
  Build 20 wurde erfolgreich zu TestFlight hochgeladen; die Production-Promotion
  ist Teil des Build-21-Release-Gates.
  ([Feature-Doku](docs/features/testflight-feedback-build-20.md),
  [ADR-002](docs/adr/ADR-002-cloudkit-sync-und-stabile-ids.md))
- **Optionaler Kalender-Sync (Build 20, TestFlight-Feedback vom 12.07.2026)**:
  Nutzer können vollständigen Kalenderzugriff erteilen, einen beschreibbaren
  Zielkalender wählen und entweder nur Reisen oder zusätzlich Häfen und Seetage
  spiegeln. Seetage benennen nach Möglichkeit den vorherigen und nächsten Hafen;
  Deaktivieren entfernt die von ShipTrip verwalteten Termine.
  ([Feature-Doku](docs/features/testflight-feedback-build-20.md))

- **Privacy-Manifest**: `PrivacyInfo.xcprivacy` deklariert
  `NSPrivacyAccessedAPICategoryUserDefaults` (CA92.1) und
  `NSPrivacyAccessedAPICategoryFileTimestamp` (3B52.1).
  ([Feature-Doku](docs/features/audit-highs-2026-07-10.md#h7--fehlendes-privacy-manifest-task-s15))
- **101 neue Lokalisierungs-Keys mit EN-Übersetzung** (u. a. Deals-, Stats-,
  Hafen-Editor- und Export/Import-Texte, Gemini-Disclosure) sowie ein
  EN-UI-Smoke-Test über die Kernbildschirme.
  ([Feature-Doku](docs/features/audit-highs-2026-07-10.md#h6--unvollständige-lokalisierung-tasks-s21a-s22s24-anteile-s21b-1-2))

- **Karte: Bottom-Sheet mit Stop-Timeline**: Tap auf eine Route (Linie oder
  Marker) öffnet ein Sheet mit Peek-/Medium-/Large-Detents — Peek zeigt
  Routentitel und Substats, Medium eine scrollbare, mit der Karte
  synchronisierte Stop-Liste, Large zusätzlich einen „Öffnen"-Button zur
  Reise-Detailansicht. Tap auf einen Stopp im Sheet springt die Kartenkamera
  dorthin und kollabiert das Sheet zurück auf Peek.
  ([Feature-Doku](docs/features/karten-redesign-v2-journal-atlas.md))
- **Karte: Burger-Menü zur Routenauswahl**: ersetzt das bisherige Filter-Menü,
  neue „Alle ausblenden"/„Alle Reisen anzeigen"-Zeile blendet mit einem Tap alle
  Routen aus bzw. wieder ein; einzelne Routen bleiben wie bisher per Tap
  ab-/anwählbar, die letzte verbleibende Route lässt sich weiterhin nicht per
  Einzel-Tap auf null reduzieren.
  ([Feature-Doku](docs/features/karten-redesign-v2-journal-atlas.md))
- **Karte: kurvige Routen statt gerader Linien**: Routen folgen jetzt einer
  Catmull-Rom-Spline durch alle Hafen-Koordinaten statt gerader
  `MapPolyline`-Segmente, mit einem farbigen Schatten-Underlay für mehr Tiefe.
  ([Feature-Doku](docs/features/karten-redesign-v2-journal-atlas.md))
- **Eigene Reederei anlegen führt jetzt direkt zum ersten Schiff** (Build 18,
  Tester-Feedback): nach dem Anlegen einer eigenen Reederei öffnet sich
  automatisch die zugehörige Schiff-Verwaltung mit bereits geöffnetem
  Schiff-Anlegeformular, statt den Nutzer in der Reederei-Liste zurückzulassen.
  Bearbeiten einer bestehenden Reederei ist davon unberührt.
  ([Feature-Doku](docs/features/eigene-reedereien-b5.md#d2--nach-reederei-anlage-direkt-zum-ersten-schiff))

### Geaendert

- **Karte: solides Navy-Chrome statt Glasmorphismus**: Recenter- und
  Burger-Button sind jetzt solide runde Buttons (`Color.navyDark`, weißes
  Icon) statt `.ultraThinMaterial`; der Recenter-Button wandert dafür von oben
  rechts nach oben links. Der Pin-Halo auf der Karte nutzt jetzt
  `Color.journalSurface` statt hartkodiertem `.white`.
  ([Feature-Doku](docs/features/karten-redesign-v2-journal-atlas.md))
- **Karte: Routen-Burger-Menü als eigenes Popover-Panel** (Build 17,
  Tester-Feedback): ersetzt das native `Menu` durch ein selbst gebautes,
  opakes Popover (max. 300pt breit) mit einheitlichem 24pt-Icon-Kreis-System
  (gefüllt+Haken aktiv, Outline inaktiv, statt wechselnder Glyphen) und
  einzeiligen Routentiteln mit mittiger Kürzung statt mehrzeiligem Umbruch.
  ([Feature-Doku](docs/features/karten-politur-c.md))
- **Karte: Routen-Detail-Sheet optisch aufgewertet** (Build 17,
  Tester-Feedback): Stop-Badges zeigen jetzt einen Farbverlauf statt Flat-Fill,
  die ausgewählte Stop-Zeile erscheint als abgesetzter Chip mit Rand statt als
  Full-Bleed-Wash, und Downward-Swipe zum Schließen reagiert direkter (System-
  Resize-Verhalten statt Konflikt mit der internen Stop-Liste).
  ([Feature-Doku](docs/features/karten-politur-c.md))
- **Karte: mittlerer Zoom zeigt jetzt lesbare Stopps** (Build 17,
  Tester-Feedback): die Welt-/Reise-Zoom-Schwelle ist breitengrad-korrigiert
  (vermeidet vorzeitigen Welt-Zoom bei nördlichen Routen), dicht beieinander
  liegende Stopps fassen sich zu einem „+N"-Pill zusammen statt sich zu
  überlagern, und ein Tap darauf zoomt hinein, bis sich die Stopps einzeln
  auflösen.
  ([Feature-Doku](docs/features/karten-politur-c.md))
- **Eigene Reedereien/Schiffe bekommen ein Stock-Cover statt generischem
  Ozean-Platzhalter** (Build 18, Tester-Feedback): Reisen, deren Reederei-/
  Schiffs-Kombination sich nicht im Katalog auflösen lässt, zeigen jetzt
  deterministisch eines von 70 fotorealistischen Stock-Covern statt des
  neutralen `cover_ocean_route`-Fallbacks; Katalog-Reedereien sind unverändert.
  ([Feature-Doku](docs/features/eigene-reedereien-b5.md#d1--stock-cover-für-eigene-reedereienschiffe))

### Behoben

- **Zielkalender-Wechsel ließ bestehende Termine im alten Kalender zurück
  (Build 23)**: Wählt der Nutzer bei aktivem Kalender-Sync einen anderen Zielkalender,
  erscheint jetzt ein Bestätigungsdialog; „Abbrechen" lässt die Auswahl und
  beide Kalender unverändert. Nach der Bestätigung werden alle von ShipTrip
  verwalteten Termine im neuen Kalender angelegt und im alten entfernt;
  scheitert der Umzug, wird der bisherige Zielkalender wiederhergestellt und
  der Fehler angezeigt. Die Termine werden dabei gelöscht und neu angelegt
  statt verschoben, weil EventKit einen Kalenderwechsel über Source-Grenzen
  hinweg (iCloud, lokal, Google) nicht zuverlässig zusichert.

- **Fotografische Reise-Cover statt Illustrationen (Build 22)**: Die in Build 21
  versehentlich freigeschalteten 111 stilisierten `cover_ship_*`-Assets sind aus
  allen großen Hero-Covern ausgeschlossen. Die Auswahl verwendet nur noch 73
  visuell geprüfte Fotos und verdrahtet Reisetitel und Route mit kuratierten
  Regions-Pools für Norwegen, Kanaren, Karibik, Ostsee und Mittelmeer.
  ([Feature-Doku](docs/features/testflight-cover-hotfix-build-22.md))

- **Passendere und abwechslungsreichere Fallback-Cover (Build 21,
  TestFlight-Feedback vom 13.07.2026)**: Vorhandene schiffsspezifische Assets
  haben Vorrang vor generischen Bildern; der Stock-Pool nutzt zusätzlich
  vorhandene Schiffs-Cover und bezieht Reise-/Zielkontext in die stabile Auswahl
  ein, um Wiederholungen zwischen verschiedenen Reisen zu reduzieren.
  ([Feature-Doku](docs/features/testflight-feedback-build-21.md))

- **Reiseliste: Filter ohne sichtbaren Reset-Weg**: Der Empty-State bei einem
  Jahres-/Reederei-Filter ohne Treffer zeigt jetzt einen
  „Filter zurücksetzen"-Button.
  ([Feature-Doku](docs/features/audit-highs-2026-07-10.md#h1--filter-dead-end-in-der-reiseliste-task-s11))
- **Reise löschen ohne Bestätigung/Rollback**: Löschen einer Reise (Liste und
  Detail) lief bisher ohne Bestätigungsdialog und ohne Rollback bei
  fehlgeschlagenem Speichern; die neue `CruiseDeletionSequence` bestätigt,
  speichert und macht bei Fehler den Löschvorgang rückgängig, bevor
  Erinnerungen entfernt werden.
  ([Feature-Doku](docs/features/audit-highs-2026-07-10.md#h5--löschen-ohne-bestätigungrollback-task-s11))
- **Hafen-Editor: instabiler Modus-Switch Suche/manuell**: Expliziter
  Modus-Switch inkl. Rückweg „Zur Suche"; Bestands-Häfen sind jetzt in beiden
  Modi editierbar; locale-toleranter Komma-/Punkt-Parser für Koordinaten.
  ([Feature-Doku](docs/features/audit-highs-2026-07-10.md#h2--instabiler-modus-switch-im-hafen-editor-task-s12-inkl-m5))
- **Hero-Deal nicht löschbar**: Löschen mit Bestätigungsdialog jetzt sowohl
  aus der Kartenansicht als auch aus dem Formular möglich.
  ([Feature-Doku](docs/features/audit-highs-2026-07-10.md#h4--hero-deal-nicht-löschbar-task-s13))
- **ZIP-Import klassifizierte koordinatenlose Häfen fälschlich als Seetag**
  und überschrieb dabei den echten Hafennamen; `isSeaDay` ist jetzt ein
  optionales, explizites Flag mit Namens-Fallback nur für Alt-Formate ohne
  das Feld.
  ([Feature-Doku](docs/features/audit-highs-2026-07-10.md#h3--seetag-fehlklassifikation-beim-import-task-s14))
- **ZIP-Restore ungehärtet**: CRC-32-Verifikation pro Eintrag,
  Local-Header-Signatur- und Namenskonsistenz-Checks, beidseitige
  Entry-Count-Validierung und Bildvalidierung via ImageIO verhindern jetzt
  stille Teil-Importe; ungültige/fehlende Medien werden gezählt und im
  Import-Alert ausgewiesen.
  ([Feature-Doku](docs/features/audit-highs-2026-07-10.md#h8--ungehärteter-zip-restore-task-s22))

- **Karte: weiße Karte nach „Alle anzeigen/ausblenden"** (Build 17,
  Tester-Feedback): das Burger-Menü blieb nach dem Umschalten aller Routen
  geöffnet und sein Hintergrund verdeckte die darunter korrekt gezoomte Karte;
  das Menü schließt jetzt zuverlässig.
  ([Feature-Doku](docs/features/karten-politur-c.md))

### Entfernt

- **Bottom-Info-Card und „Routen"-Capsule-Button auf der Karte**: vollständig
  ersetzt durch das neue Bottom-Sheet bzw. das Burger-Menü.
  ([Feature-Doku](docs/features/karten-redesign-v2-journal-atlas.md))

---

## [1.6.3] - 2026-07-04

### Hinzugefuegt

- **Hafen-Momente erfassen**: Cover-Foto-Kachel, antippbare vordefinierte
  Ausflug-Chips (Stadtbummel, Strand, Wanderung, Bootstour, Museum, Shopping) +
  Freitext, Umsortieren über einen expliziten „Reihenfolge ändern"-Modus mit
  Auf-/Ab-Pfeil-Buttons ersetzen die bisherigen generischen Formularfelder in
  `PortFormView` und `TempPortFormSheet`.
  ([Feature-Doku](docs/features/hafen-momente-b7.md#b71-a2--geführter-erfassungsschritt-hafen-momente))
- **`PortMemoryCard` in der Reise-Detailansicht**: volle-Breite-Karte mit
  16:9-Hero-Foto, Liegezeit-Badge und Ausflug-Chips ersetzt in der Route-Sektion
  von `CruiseDetailView` den bisherigen kleinen Thumbnail-plus-Text-Block;
  einladender Dashed-Border-Zero-State, solange noch kein Hafenbild erfasst wurde.
  ([Feature-Doku](docs/features/hafen-momente-b7.md#b72-b2--portmemorycard-in-der-route-sektion))
- **Karte: Zwei-Stufen-Zoom mit nummerierten Wegpunkt-Badges und Tap-Callout**:
  Welt-Zoom zeigt routenfarbige Dots statt einheitlicher Pins (löst die
  einfarbigen Zwischenstopps aus B4.3a), Reise-Zoom zeigt nummerierte,
  routenfarbige Wegpunkt-Badges für Zwischenstopps; Tap auf Pin/Badge öffnet
  einen Callout mit Hafenname und Foto-Thumbnail.
  ([Feature-Doku](docs/features/karten-redesign-b4.md#b43b-1--zwei-stufen-zoom-wegpunkt-badges-tap-callout))
- **Erklärtexte zur Reederei-/Schiff-Verwaltung**: Die Einstellungen sowie die
  Verwaltungsansicht selbst erklären jetzt an drei Stellen, wozu eigene
  Reedereien/Schiffe angelegt werden können und dass Katalog-Einträge sich
  ausblenden statt löschen lassen.
  ([Feature-Doku](docs/features/feedback-fixes-b6.md#b63--einstellungen-hinweis-zur-reederei-schiff-verwaltung))

### Geaendert

- **Kartenmarker konsistent zur Detailansicht**: `MapView` nutzt jetzt dasselbe
  Rollensystem (Start/Hafen/Endpunkt/Seetag) wie die Reise-Detailansicht statt
  einer eigenen Marker-Darstellung; eine Rundreise mit identischem Start- und
  Endhafen zeigt jetzt einen kombinierten Marker statt zweier überlagerter Pins;
  Zwischenstopps werden bei mehreren gleichzeitig angezeigten Routen nicht mehr
  auf Start/Ende gekappt.
  ([Feature-Doku](docs/features/karten-redesign-b4.md#b43a--konsistenz-fix))

### Behoben

- **Ausflug ließ sich nicht sichtbar entfernen**: Die Lösch-Funktion existierte
  nur als versteckte Wisch-Geste. Ein sichtbarer Lösch-Button pro Ausflugs-Zeile
  ersetzt bzw. ergänzt sie jetzt in `PortFormView` und `TempPortFormSheet`.
  ([Feature-Doku](docs/features/feedback-fixes-b6.md#b61--ausflug-entfernen--edit-datenverlust-fix))
- **Edit-Datenverlust bei Häfen mit leerem Land**: Der Speichern-Button in
  `PortFormView` war für Häfen mit leerem Land dauerhaft deaktiviert, obwohl das
  „Land"-Feld nur bei leerem Namen überhaupt sichtbar war — jede Bearbeitung
  eines solchen (regulär über `TempPortFormSheet` anlegbaren) Hafens wurde beim
  Speichern stillschweigend verworfen. Der Button ist jetzt nur noch bei leerem
  Namen deaktiviert.
  ([Feature-Doku](docs/features/feedback-fixes-b6.md#b61--ausflug-entfernen--edit-datenverlust-fix))

---

## [1.6.2] - 2026-07-04

### Hinzugefuegt

- **Eigene Reedereien & Schiffe verwalten**: Neben dem hartkodierten Katalog
  (`ShippingLine.all`) können jetzt eigene Reedereien und Schiffe angelegt
  werden (kleine Anbieter, Flusskreuzfahrten, Neubauten). Einzelne
  Katalog-Vorschläge lassen sich pro Reederei oder Schiff ausblenden. Picker
  in `CruiseFormView` und `DealsView` zeigen Katalog- und eigene Einträge
  gemischt und alphabetisch sortiert an.
  ([Feature-Doku](docs/features/eigene-reedereien-b5.md),
  [ADR-006](docs/adr/ADR-006-eigene-reedereien-und-schiffe-overlay-modell.md))

### Behoben

- **Edit-Datenverlust bei Reederei-/Schiffsauswahl**: Bearbeiten einer Reise
  mit zwischenzeitlich gelöschter oder ausgeblendeter Reederei/Schiff konnte
  den gespeicherten Namen beim bloßen Öffnen und Speichern stillschweigend
  auf leer zurücksetzen. `CruiseFormView` und `DealsView` erhalten die
  ursprüngliche Auswahl jetzt beim Speichern, solange der Nutzer sie nicht
  aktiv ändert.
  ([Feature-Doku](docs/features/eigene-reedereien-b5.md),
  [ADR-006](docs/adr/ADR-006-eigene-reedereien-und-schiffe-overlay-modell.md))

---

## [1.6.1] - 2026-07-03

### Hinzugefuegt

- **Hafenbild- und Ausflüge-Erfassung**: `PortFormView` und `TempPortFormSheet`
  (in `CruiseFormView`) erhalten einen `PhotosPicker`-Abschnitt (wählen/ersetzen/
  entfernen) und einen Ausflüge-Editor (hinzufügen, Swipe-to-Delete) für die
  bereits vorhandenen, bisher aber nicht erfassbaren Felder `Port.imageData`/
  `excursionsRaw`. `CruiseDetailView` zeigt Hafenbild-Thumbnail und Ausflugsliste
  jetzt in der Routen-Ansicht. ([Feature-Doku](docs/features/feedback-fixes-a5.md#a51--erfassungs-ui--anzeige-für-hafenbild--ausflüge))
- **23 neue Südhalbkugel-/Südatlantik-Häfen** in der Hafendatenbank (u. a.
  Kapstadt, Durban, Walvis Bay, Mindelo, Praia, Port Louis, Sansibar, Mombasa,
  Buenos Aires, Montevideo). ([Feature-Doku](docs/features/feedback-fixes-a5.md#a52--referenzdaten-südhalbkugel-häfen--aidastella-zuordnung))
- **Auto-Datum bei neuem Hafen**: Das Ankunftsdatum wird jetzt mit dem Folgetag
  des letzten Routen-Stopps vorbelegt (bzw. dem Reise-Startdatum bei leerer
  Route). ([Feature-Doku](docs/features/feedback-fixes-a5.md#a53--auto-datum-bei-neuem-hafen))

### Behoben

- **AIDAstella-Zuordnung bei der KI-Erfassung**: `ShippingLine.findByShipName`
  vergleicht jetzt whitespace-normalisiert, damit „AIDA Stella" (KI-Erfassung)
  weiterhin auf „AIDAstella" (Referenzdaten) matcht. Das Schiff war zuvor bereits
  vollständig in den Daten vorhanden — der gemeldete Fehler war ein
  String-Matching-Problem, kein fehlender Datensatz.

---

## [1.6.0] - 2026-07-03

### Hinzugefuegt

- **Hafenbilder im ZIP-Export**: `ExportImportService` schreibt Hafenbilder
  jetzt unter `images/<cruiseId>/ports/<index>` und setzt `imageUrl`; Roundtrip
  ist damit verlustfrei (Import las Hafenbilder bereits zuvor korrekt ein).
  ([Feature-Doku](docs/features/datenintegritaet-a1.md))
- **Bestätigungsdialog fuer API-Key-Loeschung**: „Alle Daten löschen" fragt
  jetzt explizit, ob der Gemini-API-Key mitgelöscht werden soll, statt ihn
  stillschweigend zu behalten oder zu entfernen.
- **Hybrid-Hauptansicht „Meine Reisen"**: Die flache Liste gleichfoermiger
  Full-Bleed-Karten wurde durch ein dreischichtiges Layout ersetzt:
  ein schlanker Statistik-Strip (lifetime-Totals: Reisen, Laender, Seetage,
  Haefen), eine redaktionelle Hero-Card fuer die Fokus-Reise, und kompakte
  Timeline-Zeilen gruppiert nach Jahrestrennern.
  ([Feature-Doku](docs/features/hauptansicht-hybrid.md))
- **Hero-Card mit Cover-Foto und Geo-SVG-Fallback**: Die Hero-Card zeigt das
  erste Reisefoto als Hintergrundbild mit Scrim-Overlay. Ohne Foto rendert
  `CruiseGeoFallbackView` eine Routenlinie aus Port-Koordinaten auf Ozeanblau-
  Verlauf — kein Placeholder-Icon.
- **Fokus-Reise-Priorisierung**: `heroCruise` waehlt laufende Reise
  (`isOngoing`) > naechste bevorstehende > zuletzt vergangene.
- **Lifetime-Aggregatwerte**: Neue Array-Extension auf `Cruise` liefert
  `uniqueCountryCount`, `totalSeaDays` und `totalPortStops` fuer den Stats-Strip.
- **Neue Unit-Tests (84 gesamt)**: `CruiseAggregateTests` und
  `HeroSelectionTests` testen alle drei Aggregat-Properties und die Hero-
  Auswahl-Prioritaet; `DemoDataServiceTests` sichert Demo-Seeding-Idempotenz.
- **Screenshot-Tests**: `HauptansichtScreenshotTests` verifizieren Photo-Hero-
  und Geo-Fallback-Branch in Light und Dark Mode.

### Geaendert

- **Zeitstrahl-Zeilen gerahmt**: `CruiseTimelineRowView` erhaelt ein
  Card-Treatment (`secondarySystemBackground`, cornerRadius 10), passend zum
  Statistik-Strip und zur Hero-Card. `CruiseListView` reduziert den vertikalen
  `listRowInsets`-Abstand von 6 auf 4 Pt fuer kompaktere Optik.
- **Differenzierte Hafen-Nadeln nach Rolle** in drei Kontexten:
  - Detail-Route-Liste (`PortPinView`): neuer Typ `endPort` (Token
    `endPortPin = seaGreen`, Icon `mappin.and.ellipse.circle.fill`); Start =
    Heimathafen (orange), Hafen (blau), Endpunkt (gruen), Seetag (Wellen).
    Factory `PortPinType.init(isSeaDay:isFirst:isLast:)`.
  - Geo-Route in der Hero-Card (`CruiseGeoFallbackView`): Start (orange) und
    Endpunkt (gruen) als groessere Punkte mit weissem Ring; Zwischenstopps als
    kleine weisse Punkte.
  - Weltkarte (`MapView`): Start = Pin, Zwischenhaefen = kleine Punkte,
    Endpunkt = Zielflagge (`flag.checkered.circle.fill`) — Farbe bleibt pro
    Reise unveraendert.
- **Einheitlicher Hafen-Pin**: Gemeinsame `PortPinView`-Komponente fuer alle
  Hafen-Kontexte (Karte, Detailansicht); Pin-Farben als semantische Token in
  `Color+Theme` (`portPin`, `homePortPin`, `seaDayPin`). Ersetzt verstreute,
  hartkodierte Icon-/Farb-Duplikate.
- **Schiffslisten aktualisiert (Stand Juni 2026)**: Neue Schiffe ergaenzt (u.a.
  Mein Schiff Relax/Flow, AIDAstella, Disney Treasure/Destiny/Adventure).
  Ausgeschiedene Schiffe (Mein Schiff Herz, AIDAcara/vita/aura, Costa Firenze)
  wandern in eine `historicalShips`-Liste: nicht mehr in der Auswahl fuer neue
  Reisen, fuer Bestandsreisen aber weiterhin korrekt aufgeloest (Reederei-Logo).
- **Foto-zentrierte Reise-Karten**: `CruiseCardView` zeigt das erste Reisefoto
  als vollflaechi­ges Cover (210 pt) mit Text-Overlay und Scrim. Ohne Foto:
  Verlauf oceanBlue → navy mit Ferry-Symbol.
- **Hero-Header im Reise-Detail**: `CruiseDetailView` erhaelt einen grossen
  Hero-Header (280 pt Foto-Pager / 220 pt Verlauf-Fallback) und eine
  Eckdaten-Zeile mit Reisetagen, Hafen, Laendern und Gesamtausgaben.
- **Hero-Datumsformat geraetebasiert**: `.formatted(date: .abbreviated, time: .omitted)`
  ersetzt den statischen `DateFormatter("dd.MM.yy")`.
- **Lokalisierung Hero-Card und Timeline**: Vier neue String-Catalog-Schluessel
  (`"In %lld Tagen"`, `"%lldT"`, `"Details →"`, `"Keine Treffer"`) mit DE/EN-
  Uebersetzung; Countdown-Badge nutzt einen einzigen interpolierten Schuessel.
- **Filter-Leer-Zustand**: `ContentUnavailableView.search` ersetzt den leeren
  Bildschirm, wenn ein Suchfilter keine Treffer liefert.
- **Erinnerungs-Anfrage kontextuell**: Die Benachrichtigungs-Berechtigung wird
  beim Speichern zukuenftiger Reisen jetzt zustandsabhaengig angefragt: bei
  bereits erteilter (auch `provisional`/`ephemeral`) Berechtigung wird direkt
  geplant, bei `notDetermined` zeigt ein Begruendungs-Sheet den Zweck vor dem
  System-Prompt, bei `denied` erscheint einmalig ein Hinweis mit
  Einstellungen-Link statt eines wirkungslosen erneuten Anfrageversuchs.
  ([Feature-Doku](docs/features/ux-fixes-a2.md))
- **Barrierefreiheit Hauptansicht**: Die Hero-Card ist jetzt ein echter Button
  mit beschreibendem `accessibilityLabel`; Stats-Strip und Hero-Card nutzen
  `@ScaledMetric` und `minimumScaleFactor` fuer Dynamic Type.
  ([Feature-Doku](docs/features/ux-fixes-a2.md))
- **Einzel-Loeschen fuer Haefen/Ausgaben**: Ein `contextMenu` pro Zeile in der
  Reise-Detailansicht erlaubt das direkte Loeschen einzelner Haefen und
  Ausgaben, ohne die gesamte Reise zu bearbeiten.
  ([Feature-Doku](docs/features/ux-fixes-a2.md))
- **Karte ohne Standort-Berechtigung**: `MapView` benoetigt keine
  Standortdaten des Nutzers mehr; `CLLocationManager` und die zugehoerigen
  Berechtigungsschluessel wurden entfernt. Ein Empty-State-Overlay erscheint,
  wenn keine kartierbaren Haefen vorhanden sind.
  ([Feature-Doku](docs/features/ux-fixes-a2.md))
- **Ausgaben-Eingabe locale-basiert**: Die Betrag-Eingabe nutzt jetzt
  `.currency`-Formatierung nach Geraete-Locale (neutrales Zahlenformat ohne
  Waehrung, falls die Locale keine besitzt); die Anzeige sortiert Ausgaben
  chronologisch, undatierte Eintraege zuletzt.
  ([Feature-Doku](docs/features/ux-fixes-a2.md))
- **Fluessigere Foto-Galerie**: Ein Pager auf Thumbnail-Basis mit asynchronem
  Decoding (Lade-/Fehler-Platzhalter) sowie eine Zoom-Vollbildansicht
  (`PhotoZoomView`) mit Full-Res-Nachladen.
  ([Feature-Doku](docs/features/ux-fixes-a2.md))
- **Einheitliche Corner-Radien (`DesignRadius`)**: Drei Radius-Stufen (sm 10 /
  md 16 / lg 28) ersetzen verstreute Magic Numbers ueber zehn View-Dateien;
  vormals 22er/24er-Radien wandern bewusst auf `lg = 28`. Ungenutztes
  `cardStyle()`-Modifier entfernt.
  ([Feature-Doku](docs/features/code-politur-a3.md))
- **Einheitliche Haefen-Zaehlung**: `CruiseDetailView` und `StatsView` zaehlen
  Haefen jetzt konsistent ohne Seetage.
  ([Feature-Doku](docs/features/code-politur-a3.md))
- **Schnellere Hafen-Suche**: `PortSuggestion` nutzt einen vorberechneten
  Suchindex statt bis zu vier Linearscans pro Tastenanschlag; Trefferprioritaet
  unveraendert.
  ([Feature-Doku](docs/features/code-politur-a3.md))
- **`IdBackfill` laeuft nur noch einmal**: Ein UserDefaults-Flag
  (`idBackfillCompleted.v1`) verhindert den bisher bei jedem App-Start
  wiederholten Reparaturlauf; das Flag wird nur bei vollstaendigem Erfolg auf
  dem echten persistenten Store gesetzt.
  ([Feature-Doku](docs/features/code-politur-a3.md))
- **Export-Temp-Dateien mit UUID-Namen**: Werden nach Abschluss des
  Share-Vorgangs zuverlaessig geloescht, auch bei Abbruch.
  ([Feature-Doku](docs/features/code-politur-a3.md))
- **Strukturiertes Logging statt `print`**: `NotificationService` nutzt jetzt
  `os.Logger`; Nutzerinhalte sind als `.private` markiert.
  ([Feature-Doku](docs/features/code-politur-a3.md))
- **Typisierte Feedback-Zustaende statt String-Sniffing**: `CruiseFormView`
  und `SettingsView` nutzen ein `FeedbackStatus`-Enum mit
  VoiceOver-Announcement statt `contains("✓")`-Textpruefung.
  ([Feature-Doku](docs/features/code-politur-a3.md))
- **`PortEditIndex` statt `Int: @retroactive Identifiable`**: Dedizierter
  Wrapper ersetzt die app-weite Retroactive-Konformitaet in `CruiseFormView`.
  ([Feature-Doku](docs/features/code-politur-a3.md))
- **ZIP-Stack extrahiert**: `CRC32`, `ZipArchiveWriter` und `ZipArchiveReader`
  liegen jetzt in eigenen Dateien; `ExportImportService` deutlich verkleinert
  (reine Extraktion, keine Verhaltensaenderung).
  ([Feature-Doku](docs/features/code-politur-a3.md))
- **EUR-Fallback vollstaendig entfernt**: Die letzten sechs Anzeige-Stellen
  nutzen jetzt `Double.formattedCurrencyOrNumber` (Geraete-Locale) statt
  `?? "EUR"`.
  ([Feature-Doku](docs/features/code-politur-a3.md))

### Entfernt

- **`CruiseCardView` entfernt**: Die 139-Zeilen-Komponente war seit dem
  Hybrid-Redesign in der Produktion nicht mehr referenziert. Der genutzte
  Helfer `RatingBadge` wurde zuvor in eine eigene Datei
  `ShipTrip/Views/Cruises/RatingBadge.swift` ausgelagert, die weiterhin von
  `CruiseHeroCardView` verwendet wird.
- **Toter Code (Welle A3)**: `EmptyStateView.swift` geloescht, eine
  referenzlose `CruiseTimelineRowView`-Struct-Leiche entfernt sowie
  `Expense.colorName` und `Color.expenseColor` (beide ungenutzt) geloescht.
  ([Feature-Doku](docs/features/code-politur-a3.md))

### Behoben

- **Edit-Datenverlust bei Reisen mit Ausflügen/Hafenbild**: Bearbeiten einer
  Reise löschte bisher alle Häfen und legte sie neu an, wodurch importierte
  Ausflüge (`excursionsRaw`), Hafenbilder (`imageData`) verloren gingen und
  Port-`id`s neu vergeben wurden. `reconcileRoute()` in `CruiseFormView`
  aktualisiert bestehende Ports jetzt in-place per stabiler `id`.
  ([Feature-Doku](docs/features/datenintegritaet-a1.md),
  [ADR-002](docs/adr/ADR-002-cloudkit-sync-und-stabile-ids.md))
- **„Alle Daten löschen" unvollstaendig**: Geplante Erinnerungen wurden nicht
  entfernt; ein fehlschlagendes `save()` konnte inkonsistente Zustaende
  hinterlassen. Loeschung + `save()` laufen jetzt mit Rollback bei Fehler,
  danach werden alle geplanten Benachrichtigungen entfernt.
  ([Feature-Doku](docs/features/datenintegritaet-a1.md))
- **Statistik-Tab „Reisetage" zeigte faelschlich Seetage-Anzahl**: Die Kachel
  summierte `totalSeaDays` (Ports mit `isSeaDay == true`), was haeufig 0
  ergab. Sie nutzt jetzt das neue Array-Aggregat `[Cruise].totalTravelDays`
  (Summe der `duration`-Werte) und zeigt damit die echte Gesamt-Reisedauer
  ueber alle Kreuzfahrten.
- **Doppelte Anzeige von Reisen nach Update auf 1.5.0**: SwiftDatas
  Lightweight-Migration vergab allen Altdatensaetzen denselben `id`-Default-Wert.
  Einmalige Start-Reparatur `IdBackfill` weist kollidierenden Datensaetzen
  neue eindeutige UUIDs zu (idempotent, ohne Datenverlust).
  ([ADR-002](docs/adr/ADR-002-cloudkit-sync-und-stabile-ids.md))
- **Hero-Card zeigte Cover-Foto nicht nach Stale Demo-Daten**: Der
  Idempotenz-Guard in `loadDemoData` verhinderte das erneute Seeden bei
  aelteren Demo-Datensaetzen ohne Foto. `HauptansichtScreenshotTests` setzt
  nun vor jedem Lauf Demo-Daten zurueck und laed frisch nach.
- **Flaky UI-Tests**: `Thread.sleep(forTimeInterval:)` in
  `HauptansichtScreenshotTests` durch `waitForExistence(timeout:)` ersetzt.

### Security

- **ZIP-Import gehaertet**: Ein Safe-Path-Resolver prueft ZIP-Eintraege und
  `data.json`-Pfadreferenzen gegen Pfad-Traversal (`..`, absolute Pfade)
  ausserhalb des Zielordners. Groessenlimits (50 MB pro Eintrag, 500 MB
  kumuliert, je fuer komprimierte und unkomprimierte Groesse vor jeder
  Allokation geprueft) verhindern Dekompressionsbomben; das Gesamtarchiv ist
  auf 550 MB gedeckelt. Datei-interne Cruise-ID-Duplikate werden erkannt und
  uebersprungen statt dupliziert importiert.
  ([Feature-Doku](docs/features/datenintegritaet-a1.md))
- **Gemini-API-Key nicht mehr in der Request-URL**: Der Key wird jetzt als
  `x-goog-api-key`-Header gesetzt (30s-Request-Timeout). Keychain-Items nutzen
  `kSecAttrAccessibleWhenUnlockedThisDeviceOnly` und wandern damit nicht mehr
  in iCloud-/Geraete-Backups.
  ([Feature-Doku](docs/features/code-politur-a3.md))

---

## [1.5.0] - 2026-06-15

### Hinzugefuegt

- **Demo-Modus** (nur Debug-Build): Beispiel-Kreuzfahrten und -Angebote koennen
  ueber die Einstellungen geladen und sauber entfernt werden
  (`DemoDataService`, `isDemo`-Tag auf Cruise und Deal).
- **Test-Grundgeruest**: 27 Unit-Tests (Swift Testing) fuer Cruise, Deal, Expense,
  PortSuggestion, Export/Import-Roundtrip und Notification-Praefix-Logik;
  3 UI-Tests — als Sicherheitsnetz fuer alle weiteren Phasen.
- **ZIP-Export** (`ExportImportService`): Neue Export-Option erzeugt ein
  ZIP-Archiv mit `data.json` und externalen Bilddateien unter `images/`; Fotos
  werden als Rohbytes ohne Re-Encoding gespeichert (verlustfrei). Stabile IDs
  (`cruise.id`, `port.id`, `expense.id`) werden im Export mitgefuehrt und beim
  Import unveraendert uebernommen.
  ([ADR-002](docs/adr/ADR-002-cloudkit-sync-und-stabile-ids.md))
- **Foto-Thumbnails**: `ImageDownsampler` (ImageIO, max. 600 px) erzeugt
  Vorschaubilder fuer Listenansichten; einmaliger Launch-Backfill (`ThumbnailBackfill`)
  befuellt bestehende Fotos ohne Thumbnails im Hintergrund.
- **Zweisprachigkeit DE/EN**: String Catalog (`Localizable.xcstrings`) mit 177
  uebersetzten Strings; Entwicklungssprache ist Deutsch.

### Geaendert

- **Stabile Modell-IDs und CloudKit-ready-Schema**: Alle persistenten Modelle
  (`Cruise`, `Deal`, `Expense`, `Photo`, `Port`) erhalten `var id: UUID = UUID()`,
  explizite `inverse:`-Beziehungen, Default-Werte auf allen Attributen und
  `updatedAt: Date` fuer Last-Writer-Wins. CloudKit-Sync ist bewusst **nicht**
  aktiviert (kein `cloudKitDatabase` in `ModelConfiguration`, keine iCloud-Entitlements);
  die Aktivierung folgt als separater Build.
  ([ADR-002](docs/adr/ADR-002-cloudkit-sync-und-stabile-ids.md))
- **Waehrung geraetebasiert**: `Expense.formattedAmount` nutzt
  `Locale.current.currency` statt hartem `"EUR"`.
- **Tab umbenannt**: „Angebote" heisst jetzt „Merkliste" (ehrlichere Benennung;
  `MainTabView`, `DealsView`).
- **SwiftData-Reaktivitaet**: `refreshID = UUID()`-Redraw-Hack in
  `CruiseDetailView` entfernt; Property ist jetzt `@Bindable var cruise: Cruise`.
- **Stabiles Store-Laden**: `ShipTripApp` versucht beim Start den persistenten
  Store; schlaegt dieser fehl, wird auf einen In-Memory-Store ausgewichen und der
  Nutzer erhaelt einen Alert. Schlaegt auch der Fallback fehl, zeigt eine
  `ContentUnavailableView` (`StoreUnavailableView`) einen klaren Fehlerhinweis —
  kein `fatalError` mehr.
- Debug-Logs entfernt: 3 `print("DEBUG: …")`-Aufrufe aus `GeminiService` (x2)
  und `CruiseFormView` (x1) entfernt — diese loggten im Release-Build sensible
  Daten.
- Tote `DeveloperSettingsView` und das 5-Tap-Easter-Egg aus den Einstellungen
  entfernt.

### Behoben

- **Benachrichtigungen**: Erinnerungen werden jetzt tatsaechlich geplant und
  entfernt. `NotificationService` uebergibt nur noch Werttypen (keine
  `@Model`-Objekte ueber Aktorgrenzen); respektiert Einstellungen
  `notifyBeforeCruise`, `notifyOnCruiseDay` und `reminderDaysBefore`.
  Aufruf beim Speichern, Bearbeiten und Loeschen einer Reise.
- **Stiller Import-Datenverlust**: `ExportImportService` liefert jetzt
  `ImportResult` mit Zaehlung importierter, doppelter und ungueltig
  uebersprungener Eintraege; der Nutzer sieht nach dem Import einen
  informativen Alert.
- **Enddatum-Validierung**: `saveCruise` erzwingt `endDate >= startDate` und
  zeigt bei Verstoss einen Alert (deckt auch den KI-Import-Pfad ab).
- **GitHub-Link in Einstellungen**: Korrigiert auf
  `https://github.com/andyholiday/ShipTrip`.
- **ZIP-Overflow**: Expliziter Fehler bei mehr als 65.535 ZIP-Eintraegen oder
  einzelnen Eintraegen ueber UInt32-Grenze (kein stilles Truncaten).
- **Legacy-Import rueckwaertskompatibel**: Alter Base64-JSON-Import wird weiterhin
  erkannt und korrekt verarbeitet; fehlende Bilddateien in ZIP-Importen werden
  toleriert (Photo wird uebersprungen, Cruise bleibt erhalten).

---

## [1.4.1] - 2024-12-23

### Neu
- 🏷️ **Coming Soon Badge**: Zukünftige Reisen werden mit "Coming Soon" markiert
- 🚪 **Kabinennummer**: Neues Feld für die Kabinennummer (Issue #4)
- 🚢 **Schiff-Auswahl**: Dropdown mit Schiffen der gewählten Reederei (Issue #5)
- 📤 **Export/Import**: Kabinennummer wird mit exportiert/importiert
- 🤖 **KI-Erfassung**: Kabinennummer wird automatisch erkannt

### Behoben
- 🐛 SwiftData Migration für neue Felder

---

## [1.0.4] - 2024-12-23

### Behoben
- 🐛 **Dark Mode**: App startete immer im Light Mode, obwohl Dark Mode gewählt (Issue #12)
- 🐛 **Export/Import**: Hafenzeiten wurden nicht korrekt übertragen (Issue #11)
- 🐛 **Karten-Standort**: Location-Button funktioniert jetzt korrekt (Issue #10)
- 🐛 **Reederei-Erkennung**: KI erkennt jetzt Reederei aus Schiffsnamen (Issue #6)

### Verbessert
- 📍 **Routen-Anzeige**: Komplette Liegezeiten (Ankunft – Abfahrt) in Detailansicht
- 🚢 **100+ Schiffe** zu Reederei-Datenbank hinzugefügt für bessere Auto-Detection

---

## [1.0.3] - 2024-12-21

### Hinzugefügt
- 🗺️ **~120 neue Häfen hinzugefügt**
  - **Kanarische Inseln komplett**: Alle Inseln mit allen Namensvarianten (Santa Cruz, Arrecife, Puerto del Rosario, San Sebastián de La Gomera, etc.)
  - **Türkei**: Bodrum, Istanbul, Kusadasi, Izmir, Antalya, Marmaris, etc.
  - **Marokko**: Agadir, Casablanca, Tanger, Essaouira
  - **Deutschland**: Bremerhaven, Hamburg, Kiel, Warnemünde
  - **Portugal**: Lissabon, Porto, Leixões
  - **Spanien**: Cádiz, A Coruña, Vigo, Bilbao, Málaga, Valencia, etc.
  - **Frankreich**: Le Havre, Cannes, Nizza, Ajaccio, Bastia
  - **Italien**: Genua, Livorno, Bari, Triest, Palermo, Messina, etc.
  - **Nordeuropa**: Southampton, Amsterdam, Kopenhagen, Oslo, Stockholm

### Behoben
- 🐛 **Kritischer Bug**: Häfen wurden auf Karte nicht angezeigt (Issue #1)
- 🐛 **Kritischer Bug**: Häfen wurden an falschen Orten angezeigt (Issue #2)
- 🔧 **Verbessertes Port-Matching**:
  - Klammer-Hinweise werden jetzt verwendet (z.B. "San Sebastián (La Gomera)" findet korrekten Hafen)
  - Akzent-Normalisierung (z.B. "Argostóli" findet "Argostoli")
  - Vollständige Matches haben höchste Priorität
  - Länder-Prüfung verbessert

---

## [1.0.2] - 2024-12-20

### Hinzugefügt
- 🗺️ **Hafendatenbank massiv erweitert**
  - Von ~290 auf ~1.800 Häfen (Wikidata Import)
  - Karibik, Norwegen, VAE/Oman, Asien komplett abgedeckt
  - Beliebte Kreuzfahrt-Häfen mit gängigen Namen
  - Aliase für verschiedene Schreibweisen (z.B. "Willemstad (Curacao)")

- 🎨 **UI-Verbesserungen**
  - Route-Symbole: 📍 Mappin für Häfen, 🌊 Wellen für Seetage
  - Land wird bei Seetagen ausgeblendet

### Behoben
- 🔧 Compiler-Fehler in Color+Theme.swift
- 🔧 "Seetage" → "Reisetage" in Statistik (war irreführend)
- 🔧 Länder-Zählung zählt keine leeren Strings mehr
- 🔧 Route in Cards wird jetzt sortiert angezeigt
- 🔧 Version wird dynamisch aus Bundle gelesen
- 🔧 iCloud zeigt "Geplant" statt fälschlich "Aktiv"
- 🔧 macOS-Kompatibilität (ToolbarItem Placement)
- 🔧 Deprecated `autocapitalization` API ersetzt

---

## [1.0.1] - 2024-12-19

### Hinzugefügt
- 📦 **Export/Import Funktion**
  - Export als JSON mit Base64-Fotos
  - Import von ZIP (Web-App kompatibel) und JSON
  - Duplikat-Erkennung beim Import
  - Native ZIP-Parsing ohne externe Dependencies

- 📜 **App Store Vorbereitung**
  - Privacy Policy (DE/EN) auf GitHub Pages
  - App Store Beschreibung und Keywords
  - Apple Developer Account & Zertifikate
  - TestFlight Build hochgeladen

### Geändert
- Bundle ID: `com.andre.ShipTrip`

---


## [1.0.0] - 2024-12-19

### Hinzugefügt
- 🚢 **Kreuzfahrt-Management**
  - Kreuzfahrten erstellen, bearbeiten, löschen
  - Detailansicht mit allen Informationen
  - Foto-Galerie pro Reise
  - Bewertungssystem (1-5 Sterne)
  - Buchungsnummer und Kabinentyp

- 🤖 **KI-Import (Gemini 2.5 Flash)**
  - Buchungsbestätigungen per KI analysieren
  - Automatische Extraktion von Reisedaten
  - Hafen-Erkennung mit Datum/Uhrzeit
  - Seetag-Erkennung

- 🗺️ **Interaktive Weltkarte**
  - Routen-Visualisierung mit MapKit
  - Zoom zu einzelnen Routen
  - Mehrere Reisen gleichzeitig anzeigen
  - Ein-/Ausblenden von Routen

- 🌊 **Seetage**
  - Seetage in der Route erfassen
  - Automatische Filterung auf der Karte
  - Visuelle Unterscheidung zu Häfen

- 📊 **Statistiken**
  - Kreuzfahrten pro Jahr (Bar Chart)
  - Ausgaben nach Kategorie (Pie Chart)
  - Top Reedereien
  - Besuchte Länder & Häfen

- 💰 **Ausgaben-Tracking**
  - Ausgaben pro Reise erfassen
  - Kategorien (Ausflüge, Essen, Shopping, etc.)
  - Gesamtübersicht

- 🔔 **Push-Benachrichtigungen**
  - Erinnerung 1 Tag vor Reisestart
  - Berechtigung in Einstellungen

- 🛳️ **~200 Häfen weltweit**
  - Europa, Karibik, Asien, Ozeanien, Afrika
  - Autocomplete bei Hafen-Suche
  - Automatische Koordinaten-Zuordnung

- 🎨 **Design**
  - Native iOS 17 Design
  - Dark Mode Support
  - Custom App Icon

### Technisch
- SwiftUI 5.0
- SwiftData (SQLite)
- MapKit
- Swift Charts
- Keychain Services
- UserNotifications
- Gemini 2.5 Flash API

---

## Versioning

- **MAJOR**: Inkompatible API-Änderungen
- **MINOR**: Neue Features, abwärtskompatibel
- **PATCH**: Bugfixes

[Unreleased]: https://github.com/andyholiday/ShipTrip/compare/v1.8.5...HEAD
[1.8.5]: https://github.com/andyholiday/ShipTrip/compare/v1.7.1...v1.8.5
[1.7.1]: https://github.com/andyholiday/ShipTrip/compare/v1.7.0...v1.7.1
[1.7.0]: https://github.com/andyholiday/ShipTrip/compare/v1.6.3...v1.7.0
[1.6.3]: https://github.com/andyholiday/ShipTrip/compare/v1.6.2...v1.6.3
[1.6.2]: https://github.com/andyholiday/ShipTrip/compare/v1.6.1...v1.6.2
[1.6.0]: https://github.com/andyholiday/ShipTrip/compare/v1.5.1...v1.6.0
[1.5.0]: https://github.com/andyholiday/ShipTrip/compare/v1.4.1...v1.5.0
[1.4.1]: https://github.com/andyholiday/ShipTrip/compare/v1.0.4...v1.4.1
[1.0.0]: https://github.com/andyholiday/ShipTrip/releases/tag/v1.0.0
