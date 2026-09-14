//
//  WidgetPreviewGalleryView.swift
//  ShipTrip
//
//  Debug-Galerie fuer die Widget-Screenshots (Taskplan 1.9.0, LE 10 / ZIEL K2).
//
//  Home-Screen- und Sperrbildschirm-Widgets lassen sich im Simulator nicht
//  automatisiert erfassen — WidgetKit rendert sie in einem fremden Prozess,
//  auf den XCUITest keinen Zugriff hat. Deshalb sind die Familien-Ansichten
//  des Widget-Targets zusaetzlich Mitglied des App-Targets (pbxproj-Exception)
//  und werden hier in Widget-Rahmengroesse gezeigt. `WidgetScreenshotUITests`
//  startet die App mit `-widgetPreview`, scrollt jede Zelle in Sicht und
//  schreibt einen Element-Screenshot.
//
//  Debug-only: die Datei ist im Release-Build nicht vorhanden, der Abzweig in
//  `ShipTripApp` ebenso wenig.
//

import SwiftUI
import UIKit

#if DEBUG

// MARK: - Familie

/// Die vier unterstuetzten Familien mit ihrer Rahmengroesse auf einem
/// iPhone 16. Die Werte stammen aus Apples Groessentabelle fuer 430×932-pt-
/// Geraete und sind bewusst fest verdrahtet: die Galerie soll unabhaengig vom
/// Simulator immer denselben Ausschnitt liefern.
enum WidgetPreviewFamily: String, CaseIterable {

    case small
    case medium
    case rectangular
    case circular

    var size: CGSize {
        switch self {
        case .small: CGSize(width: 170, height: 170)
        case .medium: CGSize(width: 364, height: 170)
        case .rectangular: CGSize(width: 172, height: 76)
        case .circular: CGSize(width: 76, height: 76)
        }
    }

    /// Sperrbildschirm-Familien bekommen keinen Papier-Hintergrund, sondern
    /// den dunklen Untergrund, auf dem sie real liegen.
    var isLockScreen: Bool {
        self == .rectangular || self == .circular
    }

    var title: String {
        switch self {
        case .small: "systemSmall"
        case .medium: "systemMedium"
        case .rectangular: "accessoryRectangular"
        case .circular: "accessoryCircular"
        }
    }
}

// MARK: - Zustand

/// Die vier Zustaende aus `WidgetState`.
enum WidgetPreviewStateKind: String, CaseIterable {

    case active
    case countdown
    case idle
    case unavailable

    /// - Parameter adversarial: bei grossem Schriftgrad nimmt der aktive
    ///   Zustand die Fixture mit den absichtlich langen Namen — dort ist sie
    ///   der Pruefstein (Taskplan 1.9.0, LE 10). Bei normalem Schriftgrad
    ///   zeigt die Galerie die realistische Fixture, damit die Belegbilder das
    ///   uebliche Bild zeigen und nicht den Sonderfall.
    func state(adversarial: Bool) -> WidgetState {
        switch self {
        case .active:
            adversarial
                ? WidgetPreviewFixtures.activeLongNames.state
                : WidgetPreviewFixtures.activePort.state
        case .countdown: WidgetPreviewFixtures.countdown.state
        case .idle: WidgetPreviewFixtures.idle.state
        case .unavailable: WidgetPreviewFixtures.unavailable.state
        }
    }
}

// MARK: - Galerie

struct WidgetPreviewGalleryView: View {

    /// Schriftgrad des Laufs — er entscheidet, welche aktive Fixture die
    /// Galerie zeigt (siehe `WidgetPreviewStateKind.state(adversarial:)`).
    @Environment(\.dynamicTypeSize) private var typeSize

    /// Startet die App in der Galerie statt im Hauptbaum.
    static let launchArgument = "-widgetPreview"

    /// Identifier der Scroll-Flaeche, an der der UI-Test wischt.
    static let scrollIdentifier = "widget-gallery"

    /// `widget-<familie>-<zustand>` — der Identifier, den der UI-Test abfragt
    /// und der zugleich den Dateinamen des Screenshots bildet.
    static func identifier(
        _ family: WidgetPreviewFamily,
        _ state: WidgetPreviewStateKind
    ) -> String {
        "widget-\(family.rawValue)-\(state.rawValue)"
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 28) {
                ForEach(WidgetPreviewFamily.allCases, id: \.self) { family in
                    section(family)
                }
            }
            .padding(.vertical, 24)
            .frame(maxWidth: .infinity)
        }
        .accessibilityIdentifier(Self.scrollIdentifier)
        .background(Color(uiColor: .systemGroupedBackground))
        .preferredColorScheme(Self.forcedColorScheme)
    }

    // MARK: Aufbau

    private func section(_ family: WidgetPreviewFamily) -> some View {
        VStack(spacing: 12) {
            Text(family.title)
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.secondary)

            ForEach(WidgetPreviewStateKind.allCases, id: \.self) { state in
                cell(family, state)
            }
        }
    }

    private func cell(
        _ family: WidgetPreviewFamily,
        _ state: WidgetPreviewStateKind
    ) -> some View {
        VStack(spacing: 6) {
            WidgetPreviewFrame(
                family: family,
                state: state.state(adversarial: typeSize.isAccessibilitySize)
            )
                .accessibilityElement(children: .contain)
                .accessibilityIdentifier(Self.identifier(family, state))

            Text(state.rawValue)
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
    }

    // MARK: Erscheinungsbild

    /// Erscheinungsbild aus `-colorScheme light|dark` (Konvention der
    /// bestehenden Screenshot-Suite). Ohne Argument entscheidet das System.
    private static var forcedColorScheme: ColorScheme? {
        let arguments = ProcessInfo.processInfo.arguments
        guard let index = arguments.firstIndex(of: "-colorScheme"),
              let value = arguments[safe: index + 1]
        else { return nil }
        switch value {
        case "dark": return .dark
        case "light": return .light
        default: return nil
        }
    }
}

// MARK: - Rahmen

/// Eine Zelle in exakter Widget-Groesse. Der Rahmen ist das Element, das der
/// UI-Test fotografiert — deshalb liegt weder Beschriftung noch Abstand darin.
private struct WidgetPreviewFrame: View {

    let family: WidgetPreviewFamily
    let state: WidgetState

    var body: some View {
        content
            .padding(family.isLockScreen ? 8 : 14)
            .frame(width: family.size.width, height: family.size.height)
            .background(background)
            .foregroundStyle(family.isLockScreen ? AnyShapeStyle(.white) : AnyShapeStyle(.primary))
            .clipShape(
                RoundedRectangle(
                    cornerRadius: family == .circular ? 38 : 22,
                    style: .continuous
                )
            )
    }

    @ViewBuilder
    private var content: some View {
        switch family {
        case .small: SmallWidgetView(state: state)
        case .medium: MediumWidgetView(state: state)
        case .rectangular: RectangularWidgetView(state: state)
        case .circular: CircularWidgetView(state: state)
        }
    }

    /// Home-Screen-Familien tragen den Papierton des Widgets, die
    /// Sperrbildschirm-Familien den dunklen Untergrund, auf dem sie real
    /// liegen (dort liefert das System den Hintergrund, nicht das Widget).
    private var background: some ShapeStyle {
        family.isLockScreen
            ? AnyShapeStyle(Color(white: 0.16))
            : AnyShapeStyle(WidgetStyle.surface)
    }
}

// MARK: - Hilfsmittel

private extension Array {

    /// Ein Index-Zugriff, der ueber das Ende hinaus `nil` liefert statt zu
    /// stuerzen — die Launch-Argumente sind nicht garantiert vollstaendig.
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}

// MARK: - Vorschau

#Preview("Galerie") {
    WidgetPreviewGalleryView()
}
#endif

// MARK: - Abzweig

extension View {

    /// Ersetzt den Hauptbaum durch die Widget-Galerie, sobald die App mit
    /// `-widgetPreview` startet (Taskplan 1.9.0, LE 10).
    ///
    /// Der Aufruf haengt am Ende der Modifier-Kette in `ShipTripApp`, damit der
    /// Aufbau des `ModelContainer` unangetastet bleibt: greift der Abzweig,
    /// wird der Hauptbaum samt seiner Hooks schlicht nicht montiert. Im
    /// Release-Build ist die Methode die Identitaet — die Galerie existiert
    /// dort nicht.
    @ViewBuilder
    func widgetPreviewOverride() -> some View {
#if DEBUG
        if ProcessInfo.processInfo.arguments.contains(WidgetPreviewGalleryView.launchArgument) {
            WidgetPreviewGalleryView()
        } else {
            self
        }
#else
        self
#endif
    }
}
