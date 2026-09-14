//
//  JournalMood.swift
//  ShipTrip
//
//  Anzeige-Abbildung der Stimmungs-Rohwerte (ADR-003, Contract J4).
//

import Foundation

/// Die fuenf bekannten Stimmungs-Rohwerte aus J4 samt Darstellung.
///
/// Der `rawValue` ist der export- und sync-stabile Vertrag (J4) — er wird nie
/// umbenannt und nie wiederverwendet. Emoji und Label sind reine Darstellung.
///
/// **Unbekannte Rohwerte bilden bewusst kein Case:** nach dem
/// `moodRaw`-Stabilitaetsvertrag (ADR-003) bleiben sie im Modell verbatim
/// erhalten, waehrend die UI den „keine Stimmung"-Fallback zeigt. Deshalb
/// liefern die Fabriken hier `nil` statt eines Platzhalter-Cases.
enum JournalMood: String, CaseIterable, Identifiable, Sendable {
    case great
    case good
    case okay
    case bad
    case awful

    var id: String { rawValue }

    /// Anzeige-Emoji (Vorschlag aus J4).
    var emoji: String {
        switch self {
        case .great: "🤩"
        case .good: "🙂"
        case .okay: "😐"
        case .bad: "🙁"
        case .awful: "😢"
        }
    }

    /// Lokalisiertes Label — auch das VoiceOver-Label der Stimmungs-Auswahl.
    var label: String {
        switch self {
        case .great: String(localized: "Großartig")
        case .good: String(localized: "Gut")
        case .okay: String(localized: "Okay")
        case .bad: String(localized: "Nicht so gut")
        case .awful: String(localized: "Schlecht")
        }
    }

    /// Bekannte Stimmung zu einem gespeicherten Rohwert.
    ///
    /// `nil` bedeutet „keine Stimmung" (`""`) **oder** einen unbekannten Rohwert
    /// aus einer neueren App-Version bzw. einem Fremd-Import — beide zeigen
    /// denselben Fallback, ohne dass der gespeicherte Wert angetastet wird.
    static func known(forRaw raw: String) -> JournalMood? {
        JournalMood(rawValue: raw)
    }

    /// Label fuer „keine Stimmung" (auch der Fallback bei unbekanntem Rohwert).
    static var noneLabel: String {
        String(localized: "Keine Stimmung")
    }
}
