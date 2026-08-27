//
//  JournalMoodPicker.swift
//  ShipTrip
//
//  Stimmungs-Auswahl in Schritt 2 des Journal-Editors (ADR-003, Contract J2/J4).
//

import SwiftUI

/// Fuenf Stimmungen plus „keine" als eine Reihe antippbarer Ziele.
///
/// Arbeitet direkt auf dem **Rohwert** (`moodRaw`), nicht auf `JournalMood`:
/// ein unbekannter Rohwert bleibt so unangetastet erhalten und zeigt lediglich
/// den „keine Stimmung"-Zustand an (Unknown-Preservation, ADR-003). Erst ein
/// aktiver Tipp ueberschreibt ihn.
struct JournalMoodPicker: View {
    @Binding var moodRaw: String

    /// Ausgewaehlte bekannte Stimmung; `nil` = keine **oder** unbekannter Rohwert.
    private var selected: JournalMood? {
        JournalMood.known(forRaw: moodRaw)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(String(localized: "Stimmung"))
                .font(.subheadline)
                .foregroundStyle(.secondary)

            HStack(spacing: 4) {
                ForEach(JournalMood.allCases) { mood in
                    option(
                        label: mood.label,
                        isSelected: selected == mood,
                        action: { moodRaw = mood.rawValue }
                    ) {
                        Text(mood.emoji).font(.title2)
                    }
                }

                option(
                    label: JournalMood.noneLabel,
                    isSelected: selected == nil,
                    action: { moodRaw = "" }
                ) {
                    Image(systemName: "slash.circle")
                        .font(.title3)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(.vertical, 4)
    }

    /// Ein Auswahl-Ziel: mindestens 44 pt hoch, Auswahl als gefuellte Flaeche
    /// **und** als VoiceOver-Trait (nicht nur farblich).
    private func option<Content: View>(
        label: String,
        isSelected: Bool,
        action: @escaping () -> Void,
        @ViewBuilder content: () -> Content
    ) -> some View {
        Button(action: action) {
            content()
                .frame(maxWidth: .infinity, minHeight: 44)
                .background {
                    RoundedRectangle(cornerRadius: DesignRadius.sm)
                        .fill(isSelected ? Color.accentColor.opacity(0.18) : Color.clear)
                }
                .contentShape(RoundedRectangle(cornerRadius: DesignRadius.sm))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : [.isButton])
    }
}

#Preview("Stimmung") {
    @Previewable @State var raw = JournalMood.good.rawValue

    Form {
        JournalMoodPicker(moodRaw: $raw)
    }
}
