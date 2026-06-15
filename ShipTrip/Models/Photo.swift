//
//  Photo.swift
//  ShipTrip
//
//  Created by ShipTrip on 18.12.25.
//

import SwiftData
import Foundation

/// Foto einer Kreuzfahrt
@Model
final class Photo {
    /// Stabile App-seitige ID (kein Unique-Constraint; CloudKit-kompatibel)
    var id: UUID = UUID()

    /// Die Bilddaten
    @Attribute(.externalStorage)
    var imageData: Data = Data()

    /// Vorschaubild (wird von einem späteren Task befüllt)
    var thumbnailData: Data?

    /// Sortierreihenfolge
    var sortOrder: Int = 0

    /// Erstellungsdatum
    var createdAt: Date = Date()

    /// Letztes Änderungsdatum (für Last-Writer-Wins bei CloudKit-Sync)
    var updatedAt: Date = Date()

    /// Zugehörige Kreuzfahrt
    var cruise: Cruise?

    init(imageData: Data, sortOrder: Int = 0) {
        self.imageData = imageData
        self.sortOrder = sortOrder
        self.createdAt = Date()
    }
}
