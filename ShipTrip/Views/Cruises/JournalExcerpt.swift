//
//  JournalExcerpt.swift
//  ShipTrip
//
//  Auszug-/„Weiterlesen"-Regel der Eintragszeile (ADR-003, Contract J3neu (c)).
//

import Foundation

/// Entscheidet, ob eine Eintragszeile die Aktion „Weiterlesen" zeigt.
///
/// Die Regel ist bewusst **deterministisch und ohne Rendering** formuliert
/// (J3neu (c)): sie fragt nicht, ob SwiftUI den Text tatsaechlich abgeschnitten
/// hat, sondern misst den Rohtext. Damit ist sie testbar und stabil ueber
/// Schriftgroessen, Dynamic Type und Geraetebreiten hinweg.
enum JournalExcerpt {

    /// Zeilenbegrenzung des Auszugs — `Text(...).lineLimit(JournalExcerpt.lineLimit)` (T8b).
    static let lineLimit = 3

    /// Ab **mehr** als so vielen Zeichen erscheint „Weiterlesen".
    static let characterThreshold = 160

    /// Ab **mehr** als so vielen Zeilenumbruechen erscheint „Weiterlesen".
    static let lineBreakThreshold = 3

    /// „Weiterlesen" erscheint, wenn der Text laenger als 160 Zeichen ist **oder**
    /// mehr als 3 Zeilenumbrueche enthaelt.
    ///
    /// Gezaehlt werden Grapheme-Cluster (`String.count`) — was der Nutzer als ein
    /// Zeichen sieht, zaehlt als eines. Als Umbruch zaehlt jeder
    /// `Character.isNewline`; `\r\n` ist ein einzelnes Grapheme-Cluster und damit
    /// **ein** Umbruch, nicht zwei.
    static func needsReadMore(_ text: String) -> Bool {
        if text.count > characterThreshold { return true }
        return text.count(where: \.isNewline) > lineBreakThreshold
    }
}
