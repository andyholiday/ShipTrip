//
//  MapZoomBucketPlanner.swift
//  ShipTrip
//
//  Ausgelagert aus MapView.swift (F01, swift-standards Datei-Größenlimit) — reine
//  Verschiebung, keine Verhaltensänderung.
//

import Foundation
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
    /// Schwellenwert in Grad (Design-Politur Welle C, F4). Ursprünglicher Deck-Anker
    /// (`b4-karten-redesign.html`, Slide 6): Welt-Zoom bei Span > 20°. Der frühere binäre
    /// Kompromiss von 10° (geometrisches Mittel aus 5°/20°) war nur nötig, solange es kein
    /// Overlap-Clustering für den mittleren Zoom gab (siehe `MapClusterPlanner`) — mit
    /// Clustering kann der ursprüngliche 20°-Anker direkt verwendet werden.
    static let threshold: Double = 20.0

    /// `centerLatitude` korrigiert die Mercator-Stauchung des Längengrad-Spans in höheren
    /// Breiten (z. B. Nordnorwegen-Routen bis ~70°N): ein reiner Grad-Span überschätzt dort
    /// die tatsächliche Bildschirmbreite. Bei Äquatornähe ist die Korrektur ein No-op
    /// (`cos(0°) = 1`).
    static func bucket(for span: MKCoordinateSpan, centerLatitude: Double) -> MapZoomBucket {
        let correctedLonDelta = span.longitudeDelta * cos(centerLatitude * .pi / 180)
        let effectiveSpan = max(span.latitudeDelta, correctedLonDelta)
        return effectiveSpan > threshold ? .world : .route
    }
}
