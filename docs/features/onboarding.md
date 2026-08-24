# Onboarding (Erststart)

Vier-Karten-Flow beim ersten App-Start: Wertversprechen, Kern-Features,
Soft-Ask für die Erinnerungen, Startentscheidung („Erste Reise anlegen" oder
„Beispielreise ansehen"). Der Flow hängt als `fullScreenCover` über dem bereits
montierten Hauptbaum, läuft einmal (`hasCompletedOnboarding`) und lässt sich
über Einstellungen → *Info* → „Intro erneut zeigen" zurückholen.

Quellen:
[OnboardingFlowView.swift](../../ShipTrip/Views/Onboarding/OnboardingFlowView.swift),
[OnboardingCards.swift](../../ShipTrip/Views/Onboarding/OnboardingCards.swift),
[OnboardingComponents.swift](../../ShipTrip/Views/Onboarding/OnboardingComponents.swift),
[OnboardingModel.swift](../../ShipTrip/Views/Onboarding/OnboardingModel.swift),
[OnboardingTheme.swift](../../ShipTrip/Views/Onboarding/OnboardingTheme.swift),
Einbindung in
[ShipTripApp.swift](../../ShipTrip/ShipTripApp.swift) und
[SettingsView.swift](../../ShipTrip/Views/Settings/SettingsView.swift).
Design-Vorgabe: [Design-Spec Onboarding](../design/design-spec-onboarding.md).

## Acceptance-Status

Stand 1.8.0 (Welle B, Task B1 Design + B2 Implementierung, 2026-08-24):

- Erfüllt: Der Flow erscheint genau beim ersten Start und danach nur noch auf
  Anforderung aus den Einstellungen. Schalter und Sichtbarkeit liegen in
  `OnboardingPresentation` und sind ohne UI geprüft
  ([OnboardingModelTests.swift](../../ShipTripTests/OnboardingModelTests.swift)).
- Erfüllt: Der System-Dialog für Mitteilungen erscheint ausschließlich nach
  „Erinnerungen aktivieren". „Später" und „Überspringen" setzen kein Flag außer
  dem Flow-Fortschritt; die kontextuelle Nachfrage beim ersten Speichern einer
  Reise (`CruiseFormView`) bleibt unberührt. Die System-Abfrage liegt hinter
  einer injizierbaren Naht und ist darüber getestet.
- Erfüllt: „Beispielreise ansehen" — sowohl die Taste als auch die ganzflächig
  antippbare Reise-Karte — lädt über `DemoDataService.loadDemoData(into:)`, also
  ausschließlich `isDemo`-Objekte ([Beispielreise](beispielreise.md)).
- Erfüllt: Visuelles Gate bestanden (Repair-Runde 1, 2026-08-24) — siehe
  [gate-notes.md](../design/directions/onboarding/gate-notes.md).
- Erfüllt: Inhaltsspalte scrollt, Kopf- und Fußzeile stehen außerhalb; die
  Aktionen bleiben bei großen Dynamic-Type-Graden an derselben Stelle.
- Offen: Die EN-Fassung fehlt. Alle sichtbaren Strings stehen als
  `String(localized:)` im Code, sind aber noch nicht im String Catalog
  übersetzt; die DE/EN-Abnahme läuft zentral über C5 (Lokalisierungs-Gate).
- Offen: UI-Tests für den Flow sind Teil von B5 und noch nicht abgeschlossen.
  Der aktuelle Nachweis endet bei Unit-Tests plus Durchklick.
- Offen: VoiceOver-Reihenfolge und die Kaskade unter „Reduce Motion" sind live
  nicht abgenommen (Design-Spec, Abschnitte 5 und 6).

## Known Limitations

- Beide Ausgänge auf Karte 4 enden auf der Reiseliste: „Erste Reise anlegen"
  öffnet kein Formular, „Beispielreise ansehen" springt nicht in die geladene
  Reise. Die Deep-Link-Naht Cover → `CruiseListView` ist als Folge-Task
  triagiert (`.planning/BACKLOG.md`, B2-Review F06)
  ([OnboardingFlowView.swift](../../ShipTrip/Views/Onboarding/OnboardingFlowView.swift)).
- Drei Minor-Notes des visuellen Gates bleiben offen und sind als Nicht-Blocker
  im Backlog: Achse und Polarität des Etiketts auf der Reise-Karte sowie das
  Größenverhältnis von Foto-Karte und Primär-Aktion auf Karte 4. Die
  Backlog-Einträge nennen noch Prototyp-Pfade; im Produktivcode betreffen sie
  [OnboardingComponents.swift](../../ShipTrip/Views/Onboarding/OnboardingComponents.swift)
  und [OnboardingCards.swift](../../ShipTrip/Views/Onboarding/OnboardingCards.swift).
- Die Mini-Reise-Karte ist eine eigene View und nicht die `CruiseHeroCardView`
  der App: jene bindet ein `Cruise`-Modell und trägt einen anderen Scrim. Beide
  Karten haben damit zwei Quellen und können auseinanderlaufen.
- Die Onboarding-Token (`actionLabel`, `actionBorder`, `bodyText`, Abstände,
  Maße) liegen lokal im Onboarding-Ordner, nicht im App-Theme. Der App-weite
  Grau-Token und die `AccentColor`-Frage sind bewusst unangetastet (Backlog).
