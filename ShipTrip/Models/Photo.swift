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
    /// Die Bilddaten
    @Attribute(.externalStorage)
    var imageData: Data
    
    /// Sortierreihenfolge
    var sortOrder: Int
    
    /// Erstellungsdatum
    var createdAt: Date
    
    /// Zugehörige Kreuzfahrt
    var cruise: Cruise?
    
    init(imageData: Data, sortOrder: Int = 0) {
        self.imageData = imageData
        self.sortOrder = sortOrder
        self.createdAt = Date()
    }
}
