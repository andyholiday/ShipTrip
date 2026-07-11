//
//  Date+Extensions.swift
//  ShipTrip
//
//  Created by ShipTrip on 18.12.25.
//

import Foundation

extension Date {
    // MARK: - Formatters
    
    /// Deutsches Datumsformat (dd.MM.yyyy)
    var germanFormatted: String {
        formatted(.dateTime.day().month().year())
    }
    
    /// Kurzes Format (dd.MM.)
    var shortFormatted: String {
        formatted(.dateTime.day().month())
    }
    
    /// Monat und Jahr (Januar 2025)
    var monthYear: String {
        formatted(.dateTime.month(.wide).year())
    }
    
    // MARK: - Calculations
    
    /// Tage bis zu diesem Datum
    var daysFromNow: Int {
        Calendar.current.dateComponents([.day], from: Date(), to: self).day ?? 0
    }
    
    /// Ist das Datum in der Zukunft?
    var isFuture: Bool {
        self > Date()
    }
    
    /// Ist das Datum in der Vergangenheit?
    var isPast: Bool {
        self < Date()
    }
    
    /// Jahr als Int
    var year: Int {
        Calendar.current.component(.year, from: self)
    }
    
    /// Monat als Int
    var month: Int {
        Calendar.current.component(.month, from: self)
    }
    
    // MARK: - Relative Descriptions
    
    /// Relative Beschreibung für Kreuzfahrt-Start
    var cruiseStartDescription: String {
        let days = daysFromNow
        
        switch days {
        case ..<0:
            return String(localized: "Bereits vorbei")
        case 0:
            return String(localized: "Heute!")
        case 1:
            return String(localized: "Morgen")
        case 2...7:
            return String(localized: "In \(days) Tagen")
        case 8...14:
            return days >= 14
                ? String(localized: "In \(days / 7) Wochen")
                : String(localized: "In \(days / 7) Woche")
        case 15...30:
            return String(localized: "In ca. \(days / 7) Wochen")
        default:
            return days >= 60
                ? String(localized: "In \(days / 30) Monaten")
                : String(localized: "In \(days / 30) Monat")
        }
    }
}

extension DateInterval {
    /// Formatierter Zeitraum
    var formatted: String {
        "\(start.germanFormatted) – \(end.germanFormatted)"
    }
    
    /// Dauer in Tagen
    var durationInDays: Int {
        Calendar.current.dateComponents([.day], from: start, to: end).day ?? 0 + 1
    }
}
