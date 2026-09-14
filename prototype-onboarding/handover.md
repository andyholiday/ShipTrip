# Handover — Onboarding-Erststart (onboarding)

Status: ready_for_test_build

Prototype:  /Users/andre-studio/Documents/0.Projekte/ShipTrip/prototype-onboarding
Bundle ID:  com.proto.onboarding.protoOnboarding
Scheme:     ProtoOnboarding (via xcodegen aus project.yml erzeugt)
Device:     iPhone 17 Pro (402 x 874 pt), iOS 26.5
Modes:      light + dark

Registry (deckt sich mit proto.json "screens"):

    karte-1   Wertversprechen
    karte-2   Kern-Features (Karte / Fotos / Erinnerungen)
    karte-3   Soft-Ask Erinnerungen  — Haertefall
    karte-4   Start-CTA

Jeder Screen rendert denselben Flow, nur mit anderem Startindex. Der
Prototyp ist damit auch von Hand begehbar: App oeffnen, wischen oder
Buttons tippen. Keine Aktion loest etwas aus - es wird nur geblaettert.

Motion:     Stagger / Cascade - List Entrance Cascade
            (design-library/references/systems/motion-benchmarks.md)
            250 ms easeOut, 30 ms Versatz, Cap 6; Reduce Motion schaltet
            sie ab. Wird nicht fotografiert und war nicht Teil der
            Screenshot-Abnahme -> motion: unverified.

Assets:
  copied:   Resources/Assets.xcassets/hero_fjord.imageset  (Kopie von
            ShipTrip/Assets.xcassets/demo_port_geiranger)
            Resources/Assets.xcassets/hero_reise.imageset  (Kopie von
            ShipTrip/Assets.xcassets/cover_ship_aidanova - dasselbe Bild,
            das die Hero-Karte der App fuer "Norwegische Fjorde" zeigt)
  animated: keine
  entfernt: hero_hafen.imageset (Repair-Runde, siehe unten)

Pitch deviation: entfaellt - Light-Lauf ohne Wave P.

Signatur-Move (Iteration 3, Karte 4 neu abgeleitet): „Beispielreise
ansehen" ist kein Button mehr, sondern eine antippbare Mini-Reise-Karte
(224 pt) in der Hero-Karten-Sprache der App - die Wahl steht damit als
zwei sichtbar verschiedene Zukuenfte nebeneinander. Der Primaer-CTA ist
zurueck auf der Flow-Skala (66 pt, .headline). Begruendung und Masse:
docs/design/design-spec-onboarding.md, Abschnitt 10.

Repair-Runde (Gate-Befunde, Abschnitt 11 der Spec) - der Move selbst ist
unveraendert, umgewichtet wurde drumherum:
  - Reise-Karte + Fussnote sitzen jetzt in der Aktions-Gruppe unten;
    Kartenunterkante 648 pt, CTA-Oberkante 758 pt (vorher ~550 pt Abstand).
  - Seitenpunkte fest 28 pt ueber der Primaer-Aktion auf allen vier Karten;
    die feste Aktions-Block-Hoehe (174 pt) ist entfallen.
  - Etikett "Beispielreise" achromatisch statt sunsetOrange; gesaettigt ist
    nur noch die blaue Primaer-Taste.
  - Scrim der Reise-Karte dreistufig (0/45/90 %) nach dem Vorbild der
    App-Hero-Karte; Motiv getauscht (keine Figuren unter den Overlays).
  - actionBorder in beiden Modi systemGray #8E8E93, 1 pt.

## Neu bauen

Das .xcodeproj ist generiert und liegt im Baum. Nach Aenderungen an
project.yml neu erzeugen:

    cd /Users/andre-studio/Documents/0.Projekte/ShipTrip/prototype-onboarding
    xcodegen generate

## Selbst oeffnen

    xcrun simctl create proto-onboarding com.apple.CoreSimulator.SimDeviceType.iPhone-17-Pro \
        com.apple.CoreSimulator.SimRuntime.iOS-26-5
    open -a Simulator
    # dann in Xcode ProtoOnboarding.xcodeproj oeffnen und starten

## Screenshots neu schiessen

Von /Users/andre-studio/Documents/0.Projekte/ShipTrip aus, mit einem
eigenen Wegwerf-Simulator (UDID einsetzen):

    python3 /Users/andre-studio/.claude/skills/design-phase/scripts/shoot.py \
        --project /Users/andre-studio/Documents/0.Projekte/ShipTrip/prototype-onboarding \
        --all --mode both --device <UDID> \
        --out /Users/andre-studio/Documents/0.Projekte/ShipTrip/docs/design/directions/onboarding/shots

Letzter Lauf: 8/8 shots usable, exit 0.
