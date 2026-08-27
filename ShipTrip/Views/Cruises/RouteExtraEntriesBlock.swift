//
//  RouteExtraEntriesBlock.swift
//  ShipTrip
//
//  Sammelblock „Weitere Einträge" am Ende des Route-Abschnitts
//  (Contract J3neu (a) Regel 4 / (b) / (d)).
//

import SwiftUI

/// Einträge, die kein Route-Stopp trägt (Tag ohne Stopp, leere Route).
///
/// Von der Klapp-Maschine ausgenommen: **kein** Klapp-Kopf, immer offen. Der
/// Block erscheint nur, wenn er Einträge enthält — der Aufrufer entscheidet das
/// anhand von `RouteJournalPlanner.Assignment.unassignedEntryIDs`.
struct RouteExtraEntriesBlock: View {
    /// Einträge in Anzeige-Reihenfolge (`RouteJournalPlanner`).
    let entries: [JournalEntry]
    /// Öffnet die Eintrags-Detailansicht (T8c).
    let onOpenEntry: (UUID) -> Void
    /// Öffnet den J2-Editor mit den J2-Defaults, ohne Stopp-Vorbelegung (T8c).
    let onAddEntry: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Divider()

            HStack {
                Text("Weitere Einträge")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                Spacer()
                Button {
                    onAddEntry()
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .foregroundStyle(Color.accentColor)
                }
                .accessibilityLabel(String(localized: "Tagebuch-Eintrag hinzufügen"))
            }

            ForEach(entries) { entry in
                // Im Sammelblock trägt jede Zeile ihr eigenes Datum (J3neu (c)) –
                // es gibt keinen Stopp-Tag, gegen den es redundant wäre.
                RouteJournalEntryRow(
                    entry: entry,
                    showsDate: true,
                    onOpen: { onOpenEntry(entry.id) }
                )
            }
        }
        .padding(.top, 4)
    }
}
