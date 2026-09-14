//
//  ProtoScreens.swift
//  Screen-Registry — muss exakt mit proto.json "screens" übereinstimmen.
//

import SwiftUI

enum ProtoScreens {
    static let entry = "journal"

    /// Reihenfolge = Reihenfolge in proto.json.
    static let names: [String] = [
        "journal",          // Kopf des Tagebuch-Strangs (Tag 1–3)
        "journal.tag3",     // Härtefall: Seetag mit drei Einträgen
        "journal.tag5",     // Tag 4–6 inkl. Empty-Zustand Tag 5
        "journal.motion",   // Kaskade, spielt einmal und kommt zur Ruhe
        "editor",           // Schritt 1 „Erinnerung" vollständig
        "editor.scrolled"   // Schritt 2 „Eckdaten" vollständig
    ]

    static func contains(_ name: String) -> Bool { names.contains(name) }

    @ViewBuilder
    static func view(for name: String) -> some View {
        switch name {
        case "journal.tag3":
            JournalThreadScreen(anchorDay: 3)
        case "journal.tag5":
            JournalThreadScreen(anchorDay: 4)
        case "journal.motion":
            JournalThreadScreen(animate: true)
        case "editor":
            JournalEditorScreen()
        case "editor.scrolled":
            JournalEditorScreen(anchorStepTwo: true)
        default:
            JournalThreadScreen()
        }
    }
}
