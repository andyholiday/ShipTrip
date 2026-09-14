# ZIEL — Reisedauer in Nächten: Start, Ende und Nächte gekoppelt (Run 2026-09-11)

**Ziel (1 Satz):** Beim Anlegen und Bearbeiten einer Reise sind Startdatum, Enddatum und eine neue
Zeile „Nächte" immer miteinander verknüpft; verschiebt sich das Startdatum, wandert das Enddatum
mit, die Hafen-Daten werden auf Nachfrage mitverschoben, und der Kalender-Sync zieht nach.

**Original-Anfrage (Andre, wörtlich):** „Wenn ich eine bestehende Reise nehme und die bearbeiten
möchte, und dann zum Beispiel das Startdatum ändere, ändert sich nicht automatisch das Enddatum.
Ich möchte, dass wir eine zusätzliche Zeile beim Reiseanlegen und Reisebearbeiten hinterlegen, wo
man die Dauer der Reise in Nächten hinterlegen kann. Wenn ich dann jetzt zum Beispiel das
Startdatum ändere, soll anhand der Dauer der Reise das Enddatum sich auch ändern, und ein Pop-up
erscheint bei der Änderung, ob denn auch die einzelnen Häfen, die Daten der Häfen, das obere
Startdatum und Enddatum angepasst werden sollen. Zusätzlich muss natürlich auch sichergestellt
werden, dass, wenn man die Reise dann speichert […] und die Kalender-Synchronisation aktiv hat, im
Kalender dann auch die Reise angepasst wird."
Clarify 2026-09-11: Pop-up **sofort bei der Datumsänderung** (nicht erst beim Speichern) · „Nächte"
ist **ein eigenes Feld im Modell**; werden zuerst Start/Ende angegeben, wird Nächte berechnet;
wird Nächte geändert, fragt die App, ob Start- oder Enddatum angepasst wird — alle drei Werte
sind immer gekoppelt. Clarify 2 (2026-09-11, wörtlich): „Wenn das Startdatum verschoben wird, soll
gefragt werden, ob das Enddatum verschoben werden soll, oder sich die Nächte anzahl angepasst werden
soll gemäß der neuen berechneten Nächte. Und danach soll direkt ein Dialog kommen, ob die Daten der
Häfen und Seetage auch angepasst werden sollen, aber dieser Dialog soll nur kommen, wenn sich
tatsächlich etwas ändert."

**Marktlösung:** entfällt — reine Formularlogik im eigenen Modell, kein Fertigprodukt denkbar.

**Basis:** Branch `feature/reisedauer-naechte` ab `feature/share-extension` (Spitze der
1.9.0-Linie), eigener Worktree unter `../ShipTrip-worktrees/reisedauer`.

**Definition:** Nächte = Kalendertage zwischen Start und Ende (`endDate − startDate` in Tagen,
Kalender-Tagesgrenzen). Die bestehende `duration` (Tage = Nächte + 1) bleibt unverändert.

**Messbare Kriterien:**
1. `Cruise` bekommt ein persistentes Attribut `nights: Int = 0` (additiv, CloudKit-konform: Default,
   kein Unique). Bestehende Reisen ohne Wert werden beim Laden ins Formular aus Start/Ende
   nachgefüllt; beim Speichern gilt immer `nights == Kalendertage(start, end)`. Unit-Test dafür.
2. Formular (Anlegen **und** Bearbeiten) zeigt eine Zeile „Nächte" (Stepper oder Zahlenfeld, ≥ 0)
   unter Start-/Enddatum. Kopplungsregeln, als reine, testbare Funktionen außerhalb der View:
   Ende ändern → Nächte = Ende − Start (ohne Rückfrage) ·
   Nächte ändern → Dialog „Startdatum anpassen / Enddatum anpassen / Abbrechen" ·
   Start ändern → Dialog A „Enddatum mitverschieben (Nächte bleiben) / Nächte anpassen (Enddatum
   bleibt) / Abbrechen". Repro-Test „Start verschieben lässt Ende stehen und Nächte unverändert" ist
   vor dem Fix rot, danach grün.
3. Direkt nach Dialog A erscheint Dialog B „Hafen- und Seetag-Daten um N Tage mitverschieben?"
   (Ja/Nein) — **nur**, wenn sich tatsächlich etwas ändert: Route nicht leer **und** N ≠ 0.
   Ja → alle Ankunfts-/Abfahrtsdaten der Route (Häfen und Seetage) um N Tage. Rad-Picker-Schutz:
   Dialog A erscheint erst, wenn der Startdatum-Wert 0,5 s unverändert blieb; N ist die
   Gesamtverschiebung seit der letzten Antwort. Unit-Tests: Verschiebefunktion (Seetag, negatives N)
   und Regel „Dialog B nur bei Route ≠ leer ∧ N ≠ 0"; die Ruhephase wird im Simulator beobachtet.
4. Kalender-Sync: Unit-Test beweist, dass eine geänderte Reise denselben stabilen Event-Schlüssel
   mit den neuen Start-/Enddaten liefert (Update statt Neuanlage), Trip-Event und Hafen-Events.
   Kein neuer Sync-Aufruf im Formular — der bestehende `updatedAt`-Beobachter bleibt der Auslöser.
5. Neue UI-Texte über `String(localized:)`, DE und EN im String Catalog.
6. Berührte Suite grün, `gate-run.json` Exit 0 (runtime-verifiziert); Test-Diff ≤ Code-Diff.
7. CHANGELOG unter [Unreleased]; Feature-Doku mit Acceptance-Status; CLAUDE.md nur, wenn sich die
   Struktur ändert.
8. Andre bestätigt am Gerät (nächster TestFlight-Build): Start verschieben → Ende wandert mit →
   Häfen-Dialog → Kalender zeigt neuen Termin. (Bewusst offen bis zum Build.)

**Nicht im Scope:** Validierung „Hafen liegt im Reisezeitraum" · Präzedenz-Bug in
`Date+Extensions.durationInDays` (→ Backlog) · Version-Bump.

**Status:** abgeschlossen 2026-09-11 (Kriterium 8 bewusst offen: Gerätebestätigung im nächsten TestFlight-Build)
