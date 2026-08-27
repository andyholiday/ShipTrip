//
//  RouteJournalMood.swift
//  ShipTrip
//
//  Anzeige-Seite der Stimmungs-Skala im Route-Journal-Faden (Contract J4).
//

import Foundation

/// Die fünf bekannten Stimmungs-Rohwerte in ihrer Anzeige-Form.
///
/// Der Rohwert (`JournalEntry.moodRaw`) ist der stabile Vertrag (J4), Emoji und
/// Label sind Darstellung. **Unknown-Preservation** (ADR-003,
/// `moodRaw`-Stabilitätsvertrag): ein unbekannter Rohwert liefert hier `nil` —
/// die Zeile zeigt dann wie bei `""` gar keine Stimmung, während der Rohwert im
/// Modell unangetastet bleibt.
enum RouteJournalMood: String, CaseIterable, Sendable {
    case great
    case good
    case okay
    case bad
    case awful

    /// Anzeige-Emoji nach J4.
    var emoji: String {
        switch self {
        case .great: return "🤩"
        case .good:  return "🙂"
        case .okay:  return "😐"
        case .bad:   return "🙁"
        case .awful: return "😢"
        }
    }

    /// Lokalisiertes Label — VoiceOver liest es statt des Emoji-Namens.
    var label: String {
        switch self {
        case .great: return String(localized: "Großartig")
        case .good:  return String(localized: "Gut")
        case .okay:  return String(localized: "Okay")
        case .bad:   return String(localized: "Nicht so gut")
        case .awful: return String(localized: "Schlecht")
        }
    }

    /// Bekannte Stimmung zu einem Rohwert; `nil` bei `""` **und** bei jedem
    /// unbekannten Rohwert (Unknown-Preservation).
    static func known(rawValue: String) -> RouteJournalMood? {
        RouteJournalMood(rawValue: rawValue)
    }
}
