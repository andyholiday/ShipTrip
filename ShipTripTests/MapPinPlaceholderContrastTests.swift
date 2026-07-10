//
//  MapPinPlaceholderContrastTests.swift
//  ShipTripTests
//
//  Verifiziert den WCAG-Kontrast des Pin-Platzhalter-Rands aus `RouteStopSheetView`
//  (Design-Politur Welle C, F3) rechnerisch — direkt gegen die echten `Color`-Konstanten aus
//  `Color+Theme.swift` und die Opacity-Tokens aus `MapPinPlaceholderTokens`, nicht gegen im
//  Test erneut abgetippte Hex-Werte. Ersetzt die vorherige reine Handrechnung im Code-Kommentar
//  durch eine verifizierte Aussage (Fix-Runde 1, F03a).
//

import Testing
import Foundation
import SwiftUI
import UIKit
@testable import ShipTrip

@Suite("Pin-Platzhalter-Rand — WCAG-Kontrast gegen journalSurface")
struct MapPinPlaceholderContrastTests {

    /// WCAG-2.1-Zielwert für UI-Komponenten-Kontrast (Text-Kontrast wäre 4.5:1, für einen
    /// dekorativen Rand gilt der niedrigere UI-Komponenten-Schwellenwert).
    private static let requiredContrast = 3.0

    @Test("Light: navyDark-Rand bei borderOpacityLight erreicht ≥3:1 gegen journalSurfaceLight")
    func lightBorderMeetsContrastFloor() {
        let contrast = Self.contrastRatio(
            foreground: .navyDark,
            foregroundOpacity: MapPinPlaceholderTokens.borderOpacityLight,
            background: .journalSurfaceLight
        )
        #expect(contrast >= Self.requiredContrast)
    }

    @Test("Dark: weißer Rand bei borderOpacityDark erreicht ≥3:1 gegen journalSurfaceDark")
    func darkBorderMeetsContrastFloor() {
        let contrast = Self.contrastRatio(
            foreground: .white,
            foregroundOpacity: MapPinPlaceholderTokens.borderOpacityDark,
            background: .journalSurfaceDark
        )
        #expect(contrast >= Self.requiredContrast)
    }

    @Test("Regressions-Guard: die im Design-Spec verworfenen 0.14/0.16-Werte hätten die Prüfung NICHT bestanden")
    func previouslyRejectedValuesFailContrastFloor() {
        // Dokumentiert, warum 0.55/0.40 statt der ursprünglich vorgeschlagenen 0.14/0.16 gewählt
        // wurden (siehe Design-Spec Gate #5b) — schützt davor, dass die Opacity-Werte versehentlich
        // wieder auf die zu schwachen Ausgangswerte zurückgesetzt werden.
        let rejectedLight = Self.contrastRatio(foreground: .navyDark, foregroundOpacity: 0.14, background: .journalSurfaceLight)
        let rejectedDark = Self.contrastRatio(foreground: .white, foregroundOpacity: 0.16, background: .journalSurfaceDark)

        #expect(rejectedLight < Self.requiredContrast)
        #expect(rejectedDark < Self.requiredContrast)
    }

    // MARK: - WCAG-Hilfsfunktionen

    /// Kontrastverhältnis zwischen einer teiltransparenten `foreground`-Farbe (alpha-geblendet
    /// auf `background`) und `background` selbst — WCAG-2.1-Formel `(L1+0.05)/(L2+0.05)`. Liest
    /// die tatsächlichen RGB-Komponenten über `UIColor` aus den echten `Color`-Konstanten, statt
    /// Hex-Werte im Test erneut abzutippen (Ziel von F03a).
    private static func contrastRatio(foreground: Color, foregroundOpacity: Double, background: Color) -> Double {
        let fg = components(of: foreground)
        let bg = components(of: background)

        let blended = (
            r: foregroundOpacity * fg.r + (1 - foregroundOpacity) * bg.r,
            g: foregroundOpacity * fg.g + (1 - foregroundOpacity) * bg.g,
            b: foregroundOpacity * fg.b + (1 - foregroundOpacity) * bg.b
        )

        let lBlended = relativeLuminance(blended)
        let lBackground = relativeLuminance(bg)

        let lighter = max(lBlended, lBackground)
        let darker = min(lBlended, lBackground)
        return (lighter + 0.05) / (darker + 0.05)
    }

    private static func components(of color: Color) -> (r: Double, g: Double, b: Double) {
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        UIColor(color).getRed(&r, green: &g, blue: &b, alpha: &a)
        return (Double(r), Double(g), Double(b))
    }

    private static func relativeLuminance(_ c: (r: Double, g: Double, b: Double)) -> Double {
        func linear(_ channel: Double) -> Double {
            channel <= 0.03928 ? channel / 12.92 : pow((channel + 0.055) / 1.055, 2.4)
        }
        return 0.2126 * linear(c.r) + 0.7152 * linear(c.g) + 0.0722 * linear(c.b)
    }
}
