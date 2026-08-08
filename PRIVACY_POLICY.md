# Datenschutzerklärung / Privacy Policy

**ShipTrip – Kreuzfahrt-Reisetagebuch**

*Zuletzt aktualisiert / Last updated: 6. August 2026*

---

## Deutsch

### 1. Verantwortlicher und Kontakt

Verantwortlich für ShipTrip ist:

**André Jaszka**<br>
E-Mail: [privacy@jaszka.com](mailto:privacy@jaszka.com)

### 2. Das Wichtigste in Kürze

- ShipTrip benötigt kein Benutzerkonto und betreibt keine eigenen Server.
- Reisedaten werden auf Ihrem Gerät und – bei verfügbarer iCloud-Anmeldung – in
  Ihrem privaten Apple-CloudKit-Bereich gespeichert.
- ShipTrip enthält keine Werbung, kein Tracking und keine
  Drittanbieter-Analytics-SDKs.
- Kalender-Sync, lokale Erinnerungen, Fotoauswahl, Export/Import und der
  KI-Import über Google Gemini sind optionale Funktionen.
- Der Gemini-Import funktioniert nur mit einem von Ihnen bereitgestellten
  Google-Gemini-API-Key. Bei seiner Nutzung wird der von Ihnen eingefügte Text
  direkt an Google übertragen.

### 3. In ShipTrip verarbeitete Daten

Je nach Nutzung verarbeitet ShipTrip insbesondere:

- Kreuzfahrttitel, Reisezeitraum, Reederei und Schiff
- Kabinen- und Buchungsangaben
- Routen, Häfen, Liegezeiten, Seetage und Ausflüge
- Notizen, Bewertungen und Ausgaben
- von Ihnen ausgewählte Reise- und Hafenfotos
- Wunschreisen sowie eigene Reedereien und Schiffe
- App-Einstellungen, Kalenderauswahl und Zuordnungen zu von ShipTrip
  erstellten Kalendereinträgen
- einen optionalen Gemini-API-Key

### 4. Lokale Speicherung und privates iCloud/CloudKit

ShipTrip speichert App-Daten lokal mit SwiftData. Wenn Sie auf dem Gerät bei
iCloud angemeldet sind und iCloud für ShipTrip verfügbar ist, synchronisiert
Apple diese Daten einschließlich hinzugefügter Fotos über den privaten
CloudKit-Bereich Ihres Apple-Accounts. Der Entwickler betreibt hierfür keinen
eigenen Server und kann auf diesen privaten CloudKit-Bereich nicht zugreifen.

Für die Verarbeitung durch Apple gelten die
[Apple-Datenschutzrichtlinien](https://www.apple.com/legal/privacy/).

### 5. Optionaler KI-Import mit Google Gemini

Der KI-Import ist standardmäßig nicht eingerichtet. Er wird erst verfügbar,
wenn Sie in den Einstellungen einen eigenen Gemini-API-Key hinterlegen.

- Der API-Key wird in der iOS-Keychain mit der Einstellung
  `ThisDeviceOnly` gespeichert.
- Bei der Key-Prüfung sendet ShipTrip einen kurzen Test-Prompt zusammen mit dem
  Key direkt an die Gemini API.
- Bei jedem von Ihnen gestarteten KI-Import sendet ShipTrip den vollständigen
  Text, den Sie in das Importfeld eingefügt haben, sowie Anweisungen zur
  Datenextraktion direkt an Google. Fotos oder andere Dateien werden dabei
  nicht automatisch übertragen.
- ShipTrip erhält weder Ihren API-Key noch den Buchungstext oder die Antwort
  von Google auf einem eigenen Server.

Nach Googles aktuellen Angaben werden Prompts, Kontext und Ausgaben für die
Missbrauchserkennung grundsätzlich 55 Tage gespeichert. Bei unbezahlten
Diensten kann Google Eingaben und Ausgaben außerdem zur Verbesserung seiner
Produkte verwenden; autorisierte menschliche Prüfer können Inhalte bearbeiten.
Bei Paid Services werden Prompts und Antworten laut Google nicht zur
Produktverbesserung verwendet, unterliegen aber weiterhin der
Missbrauchsüberwachung und gegebenenfalls gesetzlichen Aufbewahrungspflichten.

Übermitteln Sie daher keine sensiblen, vertraulichen oder unnötigen
personenbezogenen Daten. Für die Nutzung gelten die
[Gemini API Additional Terms](https://ai.google.dev/gemini-api/terms), die
[Hinweise zur Missbrauchsüberwachung](https://ai.google.dev/gemini-api/docs/usage-policies)
und die [Google-Datenschutzrichtlinie](https://policies.google.com/privacy).
Google verlangt für die API-Nutzung ein Mindestalter von 18 Jahren und für
API-Clients im Europäischen Wirtschaftsraum, der Schweiz und dem Vereinigten
Königreich einen Paid Service. Verwenden Sie die Gemini-Funktion nur, wenn Sie
diese Voraussetzungen erfüllen.

### 6. Optionaler Kalender-Sync und Erinnerungen

Wenn Sie Kalender-Sync aktivieren, bittet ShipTrip um vollständigen Zugriff auf
Kalenderereignisse. Die App zeigt beschreibbare Systemkalender zur Auswahl an
und erstellt, aktualisiert oder entfernt darin ShipTrip-Termine mit
Reisetiteln, Daten, Hafen-/Ortsangaben und appbezogenen Notizen. Abhängig vom
gewählten Kalender kann das Betriebssystem diese Einträge an Apple oder einen
anderen von Ihnen eingerichteten Kalenderanbieter synchronisieren. Für diese
Verarbeitung gelten die Bedingungen des jeweiligen Anbieters. ShipTrip
überträgt keine Kalenderdaten an eigene Server.

Reiseerinnerungen werden als lokale iOS-Mitteilungen auf dem Gerät geplant.
ShipTrip verwendet dafür keinen eigenen Push-Server.

### 7. Fotos

ShipTrip erhält nur die Fotos, die Sie über den iOS-Fotoauswahldialog bewusst
auswählen. Diese werden Bestandteil Ihrer App-Daten und können über Ihren
privaten CloudKit-Bereich synchronisiert oder in einem von Ihnen erstellten
Export enthalten sein.

### 8. Export und Import

Sie können Kreuzfahrten einschließlich der zugehörigen Fotos als ZIP-Archiv
exportieren und ZIP- oder unterstützte JSON-Dateien importieren. Ein Export
wird nur auf Ihre Anforderung erstellt und über das iOS-Teilen-Menü an ein von
Ihnen gewähltes Ziel übergeben. Ab diesem Zeitpunkt bestimmen Sie und der
gewählte Empfänger über die weitere Verarbeitung. Die temporäre Exportdatei
wird nach Schließen des Teilen-Menüs entfernt; Kopien außerhalb der App müssen
Sie selbst löschen.

### 9. Empfänger und Diagnosedaten

Je nach Nutzung können Daten an folgende Stellen gelangen:

| Empfänger | Daten | Anlass |
|---|---|---|
| Apple iCloud/CloudKit | App-Daten einschließlich ausgewählter Fotos | Privater Geräte-Sync |
| Gewählter Kalenderanbieter | Erstellte ShipTrip-Kalendereinträge | Nur bei aktiviertem Kalender-Sync |
| Google Gemini API | API-Key, Test-Prompt bzw. eingefügter Buchungstext und Modellantwort | Nur bei selbst eingerichteter und aktiv verwendeter KI-Funktion |
| Von Ihnen gewähltes Exportziel | Inhalte des ZIP-Exports | Nur bei selbst gestartetem Export |

ShipTrip integriert keine Drittanbieter-Dienste für Werbung, Tracking oder
Nutzungsanalyse. Apple kann abhängig von Ihren Geräte- und
App-Store-Einstellungen Diagnose- und Absturzdaten verarbeiten und dem
Entwickler bereitstellen.

### 10. Speicherdauer und Löschung

- App-Daten bleiben lokal und im privaten CloudKit-Bereich gespeichert, bis
  Sie sie löschen. Löschungen werden über CloudKit zwischen Ihren Geräten
  synchronisiert; für Apple-Backups und technische Aufbewahrung gelten Apples
  Bedingungen.
- „Alle Daten löschen“ entfernt die in ShipTrip gespeicherten Reise- und
  Katalogdaten sowie geplante lokale Mitteilungen. Wenn ein Gemini-Key
  vorhanden ist, können Sie ausdrücklich wählen, ob er ebenfalls gelöscht
  werden soll. Er kann außerdem separat in den Einstellungen entfernt werden.
- Von ShipTrip verwaltete Kalendereinträge können durch Deaktivieren des
  Kalender-Syncs entfernt werden, sofern der Kalenderzugriff noch erlaubt ist.
  Andernfalls löschen Sie die Einträge im jeweiligen Kalender oder erlauben
  den Zugriff vorübergehend erneut.
- Exportierte Dateien und bei Kalender- oder Cloud-Anbietern gespeicherte
  Kopien müssen gegebenenfalls dort gelöscht werden.
- Eine reine Deinstallation entfernt nicht zwingend Daten aus iCloud oder der
  iOS-Keychain. Nutzen Sie deshalb vor der Deinstallation die jeweiligen
  Löschfunktionen, wenn Sie diese Daten entfernen möchten.
- Für Gemini gelten die von Google veröffentlichten Speicherfristen.

### 11. Ihre Rechte

Soweit personenbezogene Daten durch einen Verantwortlichen verarbeitet
werden, können Ihnen insbesondere Rechte auf Auskunft, Berichtigung, Löschung,
Einschränkung, Datenübertragbarkeit und Beschwerde bei einer
Datenschutzaufsichtsbehörde zustehen. Da der Entwickler keinen Zugriff auf
Ihren privaten lokalen oder CloudKit-Datenbestand hat, verwalten Sie diese
Daten unmittelbar in der App beziehungsweise über Ihren Apple-Account.

### 12. Änderungen

Diese Erklärung kann bei Änderungen der App oder der beteiligten Dienste
aktualisiert werden. Auf dieser Seite wird jeweils der aktuelle Stand
veröffentlicht.

---

## English

### 1. Controller and contact

ShipTrip is provided by:

**André Jaszka**<br>
Email: [privacy@jaszka.com](mailto:privacy@jaszka.com)

### 2. Summary

- ShipTrip requires no user account and operates no developer-owned servers.
- Travel data is stored on your device and, when iCloud is available, in the
  private CloudKit area of your Apple Account.
- ShipTrip contains no advertising, tracking, or third-party analytics SDKs.
- Calendar sync, local reminders, photo selection, export/import, and AI import
  through Google Gemini are optional features.
- Gemini import works only with a Google Gemini API key supplied by you. When
  used, the text you paste is transmitted directly to Google.

### 3. Data processed in ShipTrip

Depending on how you use the app, ShipTrip processes:

- cruise titles, travel dates, cruise lines, and ships
- cabin and booking details
- routes, ports, port times, sea days, and excursions
- notes, ratings, and expenses
- travel and port photos selected by you
- wish-list trips and custom cruise lines or ships
- app settings, calendar selection, and mappings for calendar events created
  by ShipTrip
- an optional Gemini API key

### 4. Local storage and private iCloud/CloudKit

ShipTrip stores app data locally using SwiftData. If you are signed in to
iCloud and iCloud is available for ShipTrip, Apple synchronizes this data,
including photos you add, through the private CloudKit area of your Apple
Account. The developer operates no server for this purpose and cannot access
your private CloudKit area.

Apple's processing is governed by the
[Apple Privacy Policy](https://www.apple.com/legal/privacy/).

### 5. Optional AI import with Google Gemini

AI import is not configured by default. It becomes available only after you
store your own Gemini API key in Settings.

- The API key is stored in the iOS Keychain using the `ThisDeviceOnly`
  accessibility setting.
- When validating the key, ShipTrip sends a short test prompt and the key
  directly to the Gemini API.
- Each time you initiate an AI import, ShipTrip sends the complete text you
  pasted into the import field, together with extraction instructions,
  directly to Google. Photos and other files are not sent automatically.
- ShipTrip does not receive your API key, booking text, or Google's response on
  any developer-owned server.

Google currently states that prompts, context, and outputs are generally
retained for 55 days for abuse monitoring. For unpaid services, Google may also
use inputs and outputs to improve its products, and authorized human reviewers
may process content. For Paid Services, Google states that prompts and
responses are not used for product improvement, but abuse monitoring and legal
retention obligations still apply.

Do not submit sensitive, confidential, or unnecessary personal information.
Use is governed by the
[Gemini API Additional Terms](https://ai.google.dev/gemini-api/terms),
[Abuse monitoring documentation](https://ai.google.dev/gemini-api/docs/usage-policies),
and [Google Privacy Policy](https://policies.google.com/privacy). Google
requires API users to be at least 18 years old and requires a Paid Service for
API clients made available in the European Economic Area, Switzerland, or the
United Kingdom. Use the Gemini feature only if you meet these requirements.

### 6. Optional calendar sync and reminders

If you enable calendar sync, ShipTrip requests full access to calendar events.
The app displays writable system calendars and creates, updates, or removes
ShipTrip events containing travel titles, dates, port/location details, and
app-related notes. Depending on the calendar you select, the operating system
may synchronize these events with Apple or another calendar provider you have
configured. That provider's terms apply. ShipTrip does not transmit calendar
data to developer-owned servers.

Travel reminders are scheduled as local iOS notifications on your device.
ShipTrip uses no developer-owned push server.

### 7. Photos

ShipTrip receives only photos you deliberately select through the iOS photo
picker. They become part of your app data and may be synchronized through your
private CloudKit area or included in an export you create.

### 8. Export and import

You can export cruises and related photos as a ZIP archive and import ZIP or
supported JSON files. An export is created only at your request and passed
through the iOS share sheet to a destination you select. From that point, you
and the selected recipient determine further processing. The temporary export
file is removed after the share sheet closes; you must delete copies outside
the app yourself.

### 9. Recipients and diagnostics

Depending on feature use, data may be provided to:

| Recipient | Data | Reason |
|---|---|---|
| Apple iCloud/CloudKit | App data including selected photos | Private device sync |
| Selected calendar provider | ShipTrip calendar events | Only when calendar sync is enabled |
| Google Gemini API | API key, test prompt or pasted booking text, and model response | Only when you configure and actively use AI import |
| Export destination selected by you | Contents of the ZIP export | Only when you initiate an export |

ShipTrip integrates no third-party advertising, tracking, or usage analytics
services. Depending on your device and App Store settings, Apple may process
diagnostic and crash data and make it available to the developer.

### 10. Retention and deletion

- App data remains locally and in your private CloudKit area until you delete
  it. Deletions synchronize through CloudKit; Apple's terms govern backups and
  technical retention.
- “Delete All Data” removes travel and catalog data stored by ShipTrip and
  pending local notifications. If a Gemini key exists, you can explicitly
  choose whether to delete it as well. It can also be removed separately in
  Settings.
- Calendar events managed by ShipTrip can be removed by disabling calendar
  sync while calendar access remains granted. Otherwise, delete them in the
  relevant calendar or temporarily grant access again.
- Exported files and copies stored by calendar or cloud providers may need to
  be deleted there.
- Uninstalling the app alone may not remove data from iCloud or the iOS
  Keychain. Use the relevant deletion controls before uninstalling if you want
  those items removed.
- Google's published retention periods apply to Gemini processing.

### 11. Your rights

Where personal data is processed by a controller, you may have rights including
access, correction, deletion, restriction, portability, and the right to lodge
a complaint with a data protection authority. Because the developer cannot
access your private local or CloudKit data, you manage that data directly in
the app or through your Apple Account.

### 12. Changes

This policy may be updated when the app or participating services change. The
current version will be published on this page.
