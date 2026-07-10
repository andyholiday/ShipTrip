//
//  MapZoomBucketPlanner.swift
//  ShipTrip
//
//  Ausgelagert aus MapView.swift (F01, swift-standards Datei-Größenlimit) — reine
//  Verschiebung, keine Verhaltensänderung.
//

import MapKit

// MARK: - Zoom-Stufen

/// Zwei feste Zoom-Zustände statt echtem MapKit-Clustering (SwiftUI `Map` bietet dafür
/// aktuell keine native Lösung, siehe `.planning/b4-fertigloesungen-research.md`): Welt-Zoom
/// zeigt nur Dots + Polylines, Reise-Zoom zeigt volle Rollen-Pins und nummerierte Badges.
enum MapZoomBucket: Equatable {
    case world
    case route
}

/// Reine, SwiftUI-freie Zuordnung `MKCoordinateRegion.span` → `MapZoomBucket`.
enum MapZoomBucketPlanner {
    /// Schwellenwert in Grad (größerer der beiden Span-Werte). Das Design-Deck
    /// (`b4-karten-redesign.html`, Slide 6) gibt zwei Anker vor: Welt-Zoom bei Span > 20°,
    /// Reise-Zoom bei Span < 5°. Für eine binäre Zwei-Zustands-Schwelle wird das geometrische
    /// Mittel beider Anker verwendet (√(5·20) = 10°) statt eines der beiden Extreme.
    static let threshold: Double = 10.0

    static func bucket(for span: MKCoordinateSpan) -> MapZoomBucket {
        max(span.latitudeDelta, span.longitudeDelta) > threshold ? .world : .route
    }
}
