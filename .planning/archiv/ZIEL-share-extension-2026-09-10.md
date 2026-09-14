# ZIEL — Share-Extension: .shiptrip aus iMessage und Teilen-Sheet importieren (Run 2026-09-10)

**Ziel (1 Satz):** Eine `.shiptrip`-Datei lässt sich aus iMessage und aus dem iOS-Teilen-Sheet
(z. B. Dateien-App → Teilen) über einen Eintrag „ShipTrip" in die App importieren, mit demselben
Ergebnis-Sheet wie beim Öffnen aus der Dateien-App.

**Original-Anfrage (Andre):** „Ich habe mir die Datei per iMessage aufs Handy geschickt, und wenn
ich draufklicke, tut sich gar nichts." → Rest-Lücke nach Build 30: iMessage-Anhang bietet nur
„Weiterleiten", Teilen-Sheet listet ShipTrip nicht. Clarify 2026-09-10: **Minimal-Variante**
(Extension reicht Datei nur weiter), Fix-Branch **ab `feature/widget-1.9.0`**.

**Messbare Kriterien:**
1. Neues Target `ShipTripShare` (Share Extension) mit `NSExtensionActivationRule` für genau eine
   Datei vom Typ `com.andre.shiptrip.cruise`; im Teilen-Sheet der Dateien-App erscheint „ShipTrip"
   (Simulator-Screenshot als Beweis).
2. Die Extension kopiert die Datei atomar nach `<AppGroup>/ShareInbox/<UUID>.shiptrip` und zeigt
   „An ShipTrip übergeben". Kein SwiftData-/CloudKit-Container in der Extension. Kein Responder-Chain-
   Trick zum App-Öffnen; stattdessen Best-effort lokale Mitteilung, deren Antippen die App öffnet.
3. Die App scannt bei `scenePhase == .active` den ShareInbox-Ordner und importiert gefundene Dateien
   über `ShareImportCoordinator` mit dem bekannten Ergebnis-Sheet; Unit-Test für den Scan, vor dem Fix
   rot. Kein neuer URL-Parameter, kein neuer Router-Fall (Gate-#4-Entscheidung 2026-09-10).
4. `shouldRemoveAfterImport` erkennt zusätzlich den App-Group-Übergabeordner als löschbar, lässt
   In-Place-Dateien weiter unangetastet; Unit-Test dafür, vor dem Fix rot.
5. Architektur-Entscheidung als ADR unter `docs/adr/` (App-Group-Übergabe + URL-Contract), Gate #4 grün.
6. `fastlane/Fastfile` Lane `fetch_profile` (und Signing-Variablen) um `ShipTripShare` ergänzt.
7. E2E im Simulator: Dateien-App → Teilen → ShipTrip → Reise importiert; berührte Suite grün,
   `gate-run.json` Exit 0.
8. Andre bestätigt am Gerät (Build 31, TestFlight): iMessage-Anhang antippen → Teilen → ShipTrip →
   Reise importiert.
9. CHANGELOG unter [Unreleased]; `docs/features/kreuzfahrt-teilen.md` Known Limitation
   „Keine Share-Extension" entfernt; CLAUDE.md nennt das neue Target.

**Nicht im Scope:** Import-Vorschau in der Extension · Version-Bump über 1.9.0 hinaus.
