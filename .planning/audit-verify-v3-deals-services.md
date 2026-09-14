# Audit-Verifikation v3: Deals/Services (Bezug: Voll-Audit 2026-07-10, Commit 687657c)

Read-only Verifikation, kein Build/Testlauf. Alle Zeilennummern Stand heute (2026-07-10, main HEAD 687657c).

---

## H4 — Hero-Deal nicht löschbar

**Urteil: CONFIRMED**

- `ShipTrip/Views/Deals/DealsView.swift:71-84` (`dealsList`): `filteredDeals.first` wird als `DealHeroView` gerendert (Zeile 73-77), außerhalb und vor dem `ForEach(Array(filteredDeals.dropFirst()))` (Zeile 79-81), das allein `.onDelete(perform: deleteListDeals)` trägt.
- `deleteListDeals` (Zeile 87-91) mappt Offsets explizit auf `filteredDeals[index + 1]` — bestätigt, dass Index 0 (der Hero) strukturell vom Lösch-Pfad ausgeschlossen ist.
- `DealHeroView` (Zeile 95-164): einziger Interaktionspunkt ist `Button { showingEditSheet = true }` → `.sheet { DealFormView(deal: deal) }`. Kein `.swipeActions`, kein `.contextMenu`, kein Lösch-Button.
- `DealFormView` (Zeile 273-427): Toolbar hat nur `.cancellationAction` ("Abbrechen") und `.confirmationAction` ("Speichern"), Zeile 368-376. Keine Lösch-Aktion irgendwo im Formular — gilt auch für den Bearbeiten-Modus (`isEditing`).
- Verifiziert: im ganzen File keine weitere `.swipeActions`/`.contextMenu`/Delete-Referenz (Volltext geprüft).

**Konsequenz:** Sowohl der neueste Eintrag (Standardsortierung `\Deal.createdAt, order: .reverse`) als auch — bei aktiver Suche — der erste Treffer sind über keinen UI-Pfad löschbar.

**Fix-Hinweis:** Löschpfad muss unabhängig von Position sein — z. B. `.swipeActions`/Kontextmenü direkt auf `DealHeroView`, oder Delete-Button im `DealFormView`-Toolbar (analog zu anderen Formularen im Projekt), statt sich auf den Listenindex zu verlassen.

---

## M4 — Notification-Settings wirken nicht auf geplante Erinnerungen

**Urteil: CONFIRMED**

- `ShipTrip/Views/Settings/SettingsView.swift:316-391` (`NotificationSettingsView`): `notifyBeforeCruise`, `notifyOnCruiseDay`, `reminderDaysBefore` sind reine `@AppStorage`-Bindings (317-319). Keine Seiteneffekt-Logik beim Ändern (kein `.onChange`, kein Reschedule-Call).
- `ShipTrip/Services/NotificationService.swift` bietet **keine** Bulk-/Reschedule-all-Methode. Vorhanden: `scheduleCruiseReminder` (63-103), `scheduleDepartureReminder` (106-138), `removeReminders(cruiseID:)` (140-146, pro Reise), `scheduleAllReminders(cruiseID:...)` (149-160, ebenfalls pro Reise), `removeAllPendingNotifications()` (165-167, nur komplettes Löschen, kein Reschedule).
- Neuplanung geschieht nachweislich nur in `ShipTrip/Views/Cruises/CruiseFormView.swift:848-894` (`saveCruise`-Task), ausgelöst durch erneutes Speichern **genau dieser** Reise. Bestehende, bereits geplante Erinnerungen anderer Reisen bleiben nach einer Settings-Änderung unverändert (z. B. `reminderDaysBefore` geändert → alte, bereits gefeuerte Trigger-Zeit bleibt bestehen, bis die jeweilige Reise erneut gespeichert wird).
- `.denied`-Fall: `SettingsView.swift:342-346` zeigt bei `!isAuthorized` nur `Button("Berechtigung anfordern") { requestAuthorization() }` → `NotificationService.shared.requestAuthorization()` (383-390). Kein Check auf `authorizationStatus()`, kein Fallback auf `UIApplication.openSettingsURLString`. iOS zeigt den nativen Prompt nach einer expliziten Ablehnung nicht erneut — der Button ist dann faktisch wirkungslos.
- Bemerkenswert: Das richtige Pattern existiert bereits im Projekt, nur an anderer Stelle — `CruiseFormView.swift:468-480` öffnet bei `.denied` explizit `UIApplication.openSettingsURLString` im Save-Flow. In `SettingsView.swift` ist dieses Pattern nicht wiederverwendet.

**Fix-Hinweis:** (1) Für echtes "Settings wirken sofort" bräuchte es entweder eine Reschedule-all-Methode in `NotificationService`, die über alle `Cruise`-Objekte iteriert, oder zumindest ein UI-Hinweis "Änderung gilt erst beim nächsten Speichern der Reise". (2) Den bereits vorhandenen Settings-Öffnen-Pattern aus `CruiseFormView.swift:468-480` in `NotificationSettingsView.requestAuthorization()` übernehmen, wenn `authorizationStatus() == .denied`.

---

## M9 — In-Memory-Fallback-Store voll bearbeitbar

**Urteil: CONFIRMED**

- `ShipTrip/ShipTripApp.swift:37-60`: Bei Fehler beim persistenten `ModelContainer`-Init (37-44) wird ein In-Memory-`ModelConfiguration` versucht (47); bei Erfolg (48) läuft die App normal weiter mit `usingTemporaryStore = true` (54), kein eingeschränkter Modus.
- `body` (84-107): `MainTabView()` wird bei vorhandenem Container immer voll gerendert (86-88), unabhängig von `usingTemporaryStore`. Der einzige Unterschied ist ein `.alert` (89-102), gesteuert über `@State showTemporaryStoreAlert = true` (82), das nur beim ersten Erscheinen sichtbar ist und nach "OK" (96) oder jedem Dismiss (93: `set: { _ in showTemporaryStoreAlert = false }`) dauerhaft verschwindet — kein erneutes Einblenden, kein persistentes Banner, keine Schreibsperre.
- Es gibt keinerlei Read-only-Gate oder Banner-Persistenz im restlichen File.

**Konsequenz:** Nutzer kann nach einmaligem Wegklicken des Alerts beliebig Reisen/Fotos/Ausgaben anlegen, die beim nächsten App-Start verloren sind, ohne weiteren Hinweis.

**Fix-Hinweis:** Entweder persistentes Banner (z. B. in `MainTabView` oder global über `.safeAreaInset`) solange `usingTemporaryStore == true`, oder expliziter Read-only-Modus mit Export-Aufforderung, statt eines einmaligen Alerts.

---

## M10 — Wunschreisen "Beste Option" ohne Vergleichslogik + URL nicht öffenbar

**Urteil: CONFIRMED**

- **"Beste Option"-Badge:** `DealsView.swift:109-121` (innerhalb `DealHeroView.coverImage`-Overlay) zeigt das Badge, sobald `deal.discountPercent != nil` für den jeweiligen `featuredDeal` (= `filteredDeals.first`, sortiert nach `createdAt` absteigend, Zeile 14; bzw. erster Suchtreffer bei aktiver Suche). Keine Vergleichslogik gegen andere Deals (kein Sortieren/Filtern nach `discountPercent`-Höhe irgendwo im File). Der "beste" Eintrag ist schlicht der neueste mit irgendeinem Rabatt — auch ein 2%-Rabatt triggert das Badge, selbst wenn ein älterer Eintrag 50% hat.
- **URL nicht tapbar:** `deal.url` wird ausschließlich in `DealFormView` als reines `TextField` gespeichert/editiert (Zeile 354-358, 392, 419-Zuweisung beim Speichern). Weder `DealRowView` (203-270) noch `DealHeroView` (95-200) zeigen die URL überhaupt an — geschweige denn als tappbaren `Link`/Button. Auch innerhalb des Formulars selbst ist es nur ein Textfeld ohne "Öffnen"-Aktion. Nutzer muss die URL manuell kopieren, es gibt keinen Weg, sie direkt zu öffnen.

**Fix-Hinweis:** (1) "Beste Option" nur vergeben, wenn `discountPercent` tatsächlich das Maximum über `deals` ist (oder Badge-Text in etwas Neutrales wie "Rabatt" ändern). (2) In `DealRowView`/`DealHeroView`/`DealFormView` einen `Link(destination:)`-Button für `deal.url` ergänzen (z. B. "Zur Buchungsseite" mit `if let url = deal.url, let parsedURL = URL(string: url)`).

---

## M11 — Gemini-Datenabfluss unkommuniziert + Keychain-Key-Wechsel destruktiv

**Urteil: CONFIRMED** (alle drei Teilbefunde)

1. **Datenabfluss:** `ShipTrip/Services/GeminiService.swift:55-93` (`extractCruiseData`) baut einen Prompt, der den kompletten übergebenen `text` (den gesamten eingefügten Buchungstext des Nutzers, potenziell inkl. Name, Kabinennummer, Buchungsnummer, Reisedaten) unverändert einbettet (Zeile 91-92: `Text zur Analyse:\n\(text)`). `generateContent` (133-155) sendet diesen Prompt per POST an `https://generativelanguage.googleapis.com/...` (Zeile 17, 138-155) — also an Google-Server.
2. **Fehlende Kommunikation am CTA:** `CruiseFormView.swift:1394-1454` (`AIImportSheet`) zeigt nur Prompt-Text "Füge den Text deiner Buchungsbestätigung ein:" (1404) und Button "Analysieren" (1446-1450) — keinerlei Hinweis, dass der Text an Google/Gemini übertragen wird. `SettingsView.swift:44-45` (Footer der KI-Funktionen-Section) erwähnt nur "Mit einem Gemini API-Key können Kreuzfahrt-Daten automatisch aus Text extrahiert werden" — nennt zwar "Gemini", aber keine explizite Datenübertragungs-/Drittanbieter-Offenlegung an der Stelle, wo der Nutzer tatsächlich Text einfügt und einwilligt.
3. **Destruktiver Key-Wechsel:** `ShipTrip/Services/KeychainService.swift:24-40` (`save`) ruft in Zeile 28 unbedingt `delete(key)` auf, **bevor** `SecItemAdd` (38) versucht wird. Es gibt kein Rollback, falls `SecItemAdd` fehlschlägt — der Rückgabewert wird zwar über `@discardableResult` durchgereicht, aber `GeminiService.setApiKey` (31-33) prüft ihn nicht. Ein transienter Keychain-Fehler beim Hinzufügen des neuen Keys zerstört damit einen zuvor funktionierenden Key ersatzlos.

**Fix-Hinweis:** (1) Im `AIImportSheet` und/oder vor erstmaliger Aktivierung einen expliziten Hinweis "Text wird zur Analyse an Google Gemini gesendet" einbauen (idealerweise mit einmaliger Bestätigung). (2) `KeychainService.save` auf "add, bei `errSecDuplicateItem` dann update" umstellen statt "delete-then-add", oder zumindest den alten Wert zwischenspeichern und bei Fehlschlag von `SecItemAdd` zurückschreiben.

---

## L1 — Notification-Kernpfad nicht end-to-end getestet

**Urteil: CONFIRMED**

- `ShipTripTests/ShipTripTests.swift:582-590` dokumentiert selbst explizit als Kommentar, dass echtes Scheduling/Feuern **nicht** getestet wird (Begründung: Simulator-Unit-Test-Host hat keine Berechtigung und `pendingNotificationRequests()` persistiert nichts).
- Tatsächliche Tests im `NotificationServiceTests`-Suite (591-628): (a) `prefixFilterLogic` (596-618) ist ein reiner Logik-Test, der den Prefix-Filter-Algorithmus **dupliziert** nachbaut (`identifiers.filter { $0.hasPrefix(prefix) }`), ohne die echte `removeReminders`-Methode aufzurufen. (b) `removeRemindersNocrash` (623-627) ruft zwar die echte Methode auf, prüft aber nichts außer "wirft nicht" — keine Assertion über tatsächliches Verhalten.
- `NotificationService.swift` (15-173): `final class ... Sendable`, Singleton über `static let shared` (17), private `init()` (19). Kein Protokoll, keine injizierbare Abstraktion über `UNUserNotificationCenter` — jede Methode ruft `UNUserNotificationCenter.current()` direkt auf (z. B. 38, 98, 143, 145, 166, 171). Damit ist ein echtes End-to-End-Testen des Scheduling-Pfads (z. B. via Mock) architektonisch nicht möglich, ohne den Service umzubauen.

**Fix-Hinweis:** Wenn End-to-End-Vertrauen gewünscht ist, müsste `NotificationService` ein injizierbares Protokoll (z. B. `NotificationCenterProtocol` mit `add`/`pendingNotificationRequests`/`removePendingNotificationRequests`) bekommen, das in Tests durch ein In-Memory-Mock ersetzt wird — analog zum bereits injizierbaren `URLSession` in `GeminiService.swift:21-23`. Ohne das bleibt der Kernpfad nur über manuelle/UI-Tests auf echtem Gerät verifizierbar.

---

## Zusammenfassung

Alle 6 Befunde: **CONFIRMED**, keine Widersprüche zum Audit-Claim. Kleinere Abweichungen zu den im Audit genannten Zeilennummern (heutiger Stand vs. Audit-Zeitpunkt), aber Kernaussagen und betroffene Strukturen decken sich vollständig. Bei M4 zusätzlicher Fund: das richtige "Einstellungen öffnen"-Pattern existiert bereits im Code (`CruiseFormView.swift:468-480`), ist aber nicht in `SettingsView.swift` wiederverwendet — güns­tiger Fix-Hebel.
