//
//  Cruise.swift
//  ShipTrip
//
//  Created by ShipTrip on 18.12.25.
//

import SwiftData
import Foundation

/// Kreuzfahrt-Modell mit allen relevanten Informationen
@Model
final class Cruise {
    // MARK: - Properties

    /// Stabile App-seitige ID (kein Unique-Constraint; CloudKit-kompatibel)
    var id: UUID = UUID()

    /// Titel der Kreuzfahrt (z.B. "Mittelmeer Kreuzfahrt 2024")
    var title: String = ""

    /// Startdatum der Reise
    var startDate: Date = Date()

    /// Enddatum der Reise
    var endDate: Date = Date()

    /// Name der Reederei
    var shippingLine: String = ""

    /// Name des Schiffs
    var ship: String = ""

    /// Kabinentyp (z.B. "Balkonkabine")
    var cabinType: String = ""

    /// Kabinennummer (z.B. "8042")
    var cabinNumber: String = ""

    /// Buchungsnummer
    var bookingNumber: String = ""

    /// Persönliche Notizen
    var notes: String = ""

    /// Bewertung (1-5 Sterne)
    var rating: Double = 0

    /// Erstellungsdatum
    var createdAt: Date = Date()

    /// Letztes Änderungsdatum
    var updatedAt: Date = Date()

    /// Markiert Demo-Daten für sauberes Entfernen
    var isDemo: Bool = false

    /// Inhalts-Fingerabdruck der Fassung, die per „Reise teilen" empfangen wurde
    /// (SHA-256-Hex, vom Sender berechnet — siehe `ShareFingerprint`, ADR-007/C1).
    /// `nil` = diese Reise kam nie über einen Share-Import (eigene Reise, Backup).
    /// Wird beim Share-Import einmal gesetzt und nie neu berechnet; ein späterer
    /// Import derselben Reise vergleicht ausschließlich gespeicherte Werte.
    /// Optional und damit CloudKit-konform (additive Lightweight-Migration).
    var shareContentFingerprint: String?

    // MARK: - Relationships

    /// Route mit allen besuchten Häfen
    @Relationship(deleteRule: .cascade, originalName: "route", inverse: \Port.cruise)
    var routeStorage: [Port]?

    /// Ausgaben für diese Kreuzfahrt
    @Relationship(deleteRule: .cascade, originalName: "expenses", inverse: \Expense.cruise)
    var expensesStorage: [Expense]?

    /// Fotos der Kreuzfahrt
    @Relationship(deleteRule: .cascade, originalName: "photos", inverse: \Photo.cruise)
    var photosStorage: [Photo]?

    /// Nicht-optionale App-Sicht auf die CloudKit-kompatible optionale Beziehung.
    var route: [Port] {
        get { routeStorage ?? [] }
        set { routeStorage = newValue }
    }

    /// Nicht-optionale App-Sicht auf die CloudKit-kompatible optionale Beziehung.
    var expenses: [Expense] {
        get { expensesStorage ?? [] }
        set { expensesStorage = newValue }
    }

    /// Nicht-optionale App-Sicht auf die CloudKit-kompatible optionale Beziehung.
    var photos: [Photo] {
        get { photosStorage ?? [] }
        set { photosStorage = newValue }
    }
    
    // MARK: - Initialization
    
    init(
        title: String,
        startDate: Date,
        endDate: Date,
        shippingLine: String,
        ship: String
    ) {
        self.title = title
        self.startDate = startDate
        self.endDate = endDate
        self.shippingLine = shippingLine
        self.ship = ship
        self.cabinType = ""
        self.cabinNumber = ""
        self.bookingNumber = ""
        self.notes = ""
        self.rating = 0
        self.createdAt = Date()
        self.updatedAt = Date()
    }
    
    // MARK: - Computed Properties
    
    /// Dauer der Kreuzfahrt in Tagen
    var duration: Int {
        let days = Calendar.current.dateComponents([.day], from: startDate, to: endDate).day ?? 0
        return days + 1 // Inklusiv Start- und Endtag
    }
    
    /// Prüft ob die Kreuzfahrt in der Zukunft liegt
    var isUpcoming: Bool {
        startDate > Date()
    }
    
    /// Prüft ob die Kreuzfahrt gerade stattfindet
    var isOngoing: Bool {
        let now = Date()
        return startDate <= now && endDate >= now
    }
    
    /// Jahr der Kreuzfahrt
    var year: Int {
        Calendar.current.component(.year, from: startDate)
    }
    
    /// Gesamtkosten aller Ausgaben
    var totalExpenses: Double {
        expenses.reduce(0) { $0 + $1.amount }
    }
    
    /// Anzahl der besuchten Länder (leeres Land – z. B. Seetage oder Häfen ohne erfasstes
    /// Land – zählt nicht mit, siehe CruiseHeroCardView.metaLine)
    var countriesVisited: Set<String> {
        Set(route.map { $0.country }).filter { !$0.isEmpty }
    }
    
    /// Emoji-Logo der Reederei
    var shippingLineLogo: String {
        ShippingLine.all.first { $0.name == shippingLine }?.logo ?? "🛳️"
    }
    
    /// Sortierte Fotos
    var sortedPhotos: [Photo] {
        photos.sorted { $0.sortOrder < $1.sortOrder }
    }
}

// MARK: - Array<Cruise> Aggregat-Helfer

extension Array where Element == Cruise {

    /// Anzahl eindeutiger Länder über alle Kreuzfahrten (Seetage mit leerem Land ausgeschlossen)
    var uniqueCountryCount: Int {
        Set(flatMap { $0.countriesVisited }).filter { !$0.isEmpty }.count
    }

    /// Gesamtanzahl Seetage über alle Kreuzfahrten
    var totalSeaDays: Int {
        flatMap { $0.route }.filter { $0.isSeaDay }.count
    }

    /// Gesamtanzahl Hafen-Anläufe (keine Seetage) über alle Kreuzfahrten.
    /// Mehrfachbesuche desselben Hafens zählen mehrfach — UI-Beschriftung „Anläufe".
    /// Für die Anzahl *unterschiedlicher* Häfen siehe `uniquePortCount`.
    var totalPortStops: Int {
        flatMap { $0.route }.filter { !$0.isSeaDay }.count
    }

    /// Anzahl eindeutiger Häfen (nach Name, keine Seetage) über alle Kreuzfahrten.
    /// Mehrfachbesuche desselben Hafens zählen einmal — UI-Beschriftung „Häfen".
    var uniquePortCount: Int {
        Set(flatMap { $0.route }.filter { !$0.isSeaDay }.map { $0.name }).count
    }

    /// Gesamtanzahl Reisetage (Reisedauer) über alle Kreuzfahrten
    var totalTravelDays: Int {
        reduce(0) { $0 + $1.duration }
    }
}
