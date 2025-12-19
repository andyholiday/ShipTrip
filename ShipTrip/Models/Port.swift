//
//  Port.swift
//  ShipTrip
//
//  Created by ShipTrip on 18.12.25.
//

import SwiftData
import Foundation
import CoreLocation

/// Hafen auf einer Kreuzfahrt-Route
@Model
final class Port {
    // MARK: - Properties
    
    /// Name des Hafens
    var name: String
    
    /// Land
    var country: String
    
    /// Breitengrad
    var latitude: Double
    
    /// Längengrad
    var longitude: Double
    
    /// Ankunftsdatum/-zeit
    var arrival: Date
    
    /// Abfahrtsdatum/-zeit
    var departure: Date
    
    /// Sortierreihenfolge in der Route
    var sortOrder: Int
    
    /// Ist dies ein Seetag (kein Landgang)?
    var isSeaDay: Bool = false
    
    /// Optionales Bild des Hafens
    @Attribute(.externalStorage)
    var imageData: Data?
    
    /// Geplante Ausflüge (kommasepariert)
    var excursionsRaw: String = ""
    
    /// Ausflüge als Array
    var excursions: [String] {
        get {
            excursionsRaw.isEmpty ? [] : excursionsRaw.components(separatedBy: ", ")
        }
        set {
            excursionsRaw = newValue.joined(separator: ", ")
        }
    }
    
    /// Prüft ob es ein echter Hafen mit bekannten Koordinaten ist für Kartenanzeige
    var hasValidCoordinates: Bool {
        !isSeaDay && !(latitude == 0 && longitude == 0)
    }
    
    // MARK: - Relationships
    
    /// Zugehörige Kreuzfahrt
    var cruise: Cruise?
    
    // MARK: - Initialization
    
    init(
        name: String,
        country: String,
        latitude: Double,
        longitude: Double
    ) {
        self.name = name
        self.country = country
        self.latitude = latitude
        self.longitude = longitude
        self.arrival = Date()
        self.departure = Date()
        self.sortOrder = 0
        self.isSeaDay = false
    }
    
    /// Convenience-Initializer mit CLLocationCoordinate2D
    convenience init(name: String, country: String, coordinate: CLLocationCoordinate2D) {
        self.init(
            name: name,
            country: country,
            latitude: coordinate.latitude,
            longitude: coordinate.longitude
        )
    }
    
    // MARK: - Computed Properties
    
    /// CLLocationCoordinate2D für MapKit
    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }
    
    /// Aufenthaltsdauer am Hafen in Stunden
    var stayDuration: Int {
        let hours = Calendar.current.dateComponents([.hour], from: arrival, to: departure).hour ?? 0
        return max(0, hours)
    }
    
    /// Formatierte Ankunftszeit
    var formattedArrival: String {
        arrival.formatted(date: .abbreviated, time: .shortened)
    }
    
    /// Formatierte Abfahrtszeit
    var formattedDeparture: String {
        departure.formatted(date: .abbreviated, time: .shortened)
    }
}
