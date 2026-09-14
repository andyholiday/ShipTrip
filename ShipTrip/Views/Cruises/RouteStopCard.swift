//
//  RouteStopCard.swift
//  ShipTrip
//
//  Ein Stopp im Route-Journal-Faden: Klapp-Kopf + aufgeklappter Inhalt
//  (Contract J3neu (b)/(c)/(d)/(e)).
//

import SwiftUI

/// Ein Route-Stopp (Hafen oder Seetag) als klappbare Karte.
///
/// **Zugeklappt:** nur die kompakte Kopfzeile (Pin, Name, Land, Datum).
/// **Aufgeklappt:** zusätzlich die `PortMemoryCard` (nach deren
/// `shouldRender`-Regel), die Journal-Eintragszeilen und die Aktion
/// „Tagebuch-Eintrag".
///
/// Trefferflächen sind getrennt (J3neu (b)): die **Kopfzeile klappt**, der
/// **Karteninhalt navigiert** ins Hafen-Formular. Weil ein zugeklappter Stopp
/// und ein Seetag ohne Momente keinen Karteninhalt haben, liegt „Bearbeiten"
/// zusätzlich im Kontextmenü — sonst wäre das Formular dort nicht erreichbar.
struct RouteStopCard: View {
    let port: Port
    let pinType: PortPinType
    let isExpanded: Bool
    /// Einträge dieses Stopps in Anzeige-Reihenfolge (`RouteJournalPlanner`).
    let entries: [JournalEntry]
    let onToggle: () -> Void
    /// Öffnet das Hafen-Formular (bestehende `selectedPort`-Navigation).
    let onSelectPort: () -> Void
    let onDeletePort: () -> Void
    /// Öffnet die Eintrags-Detailansicht (T8c).
    let onOpenEntry: (UUID) -> Void
    /// Öffnet den J2-Editor, vorbelegt mit diesem Stopp (T8c).
    let onAddEntry: () -> Void

    /// Mindesthöhe der Kopfzeile — Tap-Ziel ≥ 44 pt.
    private static let headerMinHeight: CGFloat = 44

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            header

            if isExpanded {
                if PortMemoryCard.shouldRender(for: port) {
                    PortMemoryCard(port: port)
                        .contentShape(Rectangle())
                        .onTapGesture { onSelectPort() }
                        .accessibilityAddTraits(.isButton)
                        .accessibilityHint(Text("Hafen bearbeiten"))
                } else {
                    // Ohne Karteninhalt (Seetag, Hafen ohne Momente) gäbe es
                    // sonst nur das Kontextmenü als Weg ins Formular (T9b F03).
                    editPortButton
                }

                ForEach(entries) { entry in
                    RouteJournalEntryRow(
                        entry: entry,
                        showsDate: RouteJournalEntryRow.showsDate(
                            entryDate: entry.entryDate,
                            stopArrival: port.arrival
                        ),
                        onOpen: { onOpenEntry(entry.id) }
                    )
                }

                addEntryButton
            }
        }
        .padding(.vertical, 4)
        .contextMenu {
            Button {
                onSelectPort()
            } label: {
                Label("Bearbeiten", systemImage: "pencil")
            }
            Button(role: .destructive) {
                onDeletePort()
            } label: {
                Label("Löschen", systemImage: "trash")
            }
        }
    }

    // MARK: - Kopfzeile (klappt)

    private var header: some View {
        Button {
            onToggle()
        } label: {
            HStack(spacing: 12) {
                PortPinView(type: pinType)

                VStack(alignment: .leading) {
                    Text(port.name)
                        .font(.subheadline)
                        .fontWeight(.medium)
                    if !port.isSeaDay {
                        Text(PortCountryCatalog.localizedName(for: port.country))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                Spacer()

                Text(port.arrival.formatted(date: .abbreviated, time: .omitted))
                    .font(.caption)
                    .foregroundStyle(.secondary)

                // Rein dekorativ: den Zustand sagt bereits der A11y-Value der
                // Kopfzeile („aufgeklappt"/„zugeklappt").
                Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .accessibilityHidden(true)
            }
            .frame(minHeight: Self.headerMinHeight)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityValue(isExpanded
                            ? String(localized: "aufgeklappt")
                            : String(localized: "zugeklappt"))
        .accessibilityHint(Text("Tippen zum Auf- oder Zuklappen"))
        .accessibilityIdentifier("routeStop.header.\(port.name)")
    }

    // MARK: - Aktionen im aufgeklappten Stopp

    /// Sichtbarer Ein-Tap-Einstieg ins Hafen-Formular — gleiches Idiom wie
    /// „Tagebuch-Eintrag", damit die Karte eine Aktionszeile behält.
    private var editPortButton: some View {
        Button {
            onSelectPort()
        } label: {
            Label("Hafen bearbeiten", systemImage: "pencil")
                .font(.caption.weight(.semibold))
                .frame(minHeight: Self.headerMinHeight, alignment: .leading)
        }
        .buttonStyle(.plain)
        .foregroundStyle(Color.accentColor)
        .accessibilityIdentifier("routeStop.editPort.\(port.name)")
    }

    // MARK: - Erfassung (J3neu (d))

    private var addEntryButton: some View {
        Button {
            onAddEntry()
        } label: {
            Label("Tagebuch-Eintrag", systemImage: "square.and.pencil")
                .font(.caption.weight(.semibold))
                .frame(minHeight: Self.headerMinHeight, alignment: .leading)
        }
        .buttonStyle(.plain)
        .foregroundStyle(Color.accentColor)
        .accessibilityLabel(String(localized: "Tagebuch-Eintrag hinzufügen"))
        .accessibilityIdentifier("routeStop.addEntry.\(port.name)")
    }
}

// MARK: - Preview

#Preview {
    let port = Port(name: "Civitavecchia", country: "Italien", latitude: 42.09, longitude: 11.79)
    port.excursions = ["Kolosseum", "Vatikan-Tour"]

    let entry = JournalEntry(
        text: """
        Früh raus, mit dem Zug nach Rom. Die Schlange am Kolosseum war lang, \
        aber der Blick von oben hat alles wettgemacht.
        """,
        moodRaw: "great"
    )

    return ScrollView {
        VStack(alignment: .leading, spacing: 16) {
            RouteStopCard(
                port: port, pinType: .homePort, isExpanded: true, entries: [entry],
                onToggle: {}, onSelectPort: {}, onDeletePort: {},
                onOpenEntry: { _ in }, onAddEntry: {}
            )
            RouteStopCard(
                port: port, pinType: .port, isExpanded: false, entries: [entry],
                onToggle: {}, onSelectPort: {}, onDeletePort: {},
                onOpenEntry: { _ in }, onAddEntry: {}
            )
        }
        .padding()
        .background(Color(.secondarySystemBackground))
    }
}

/// Dynamic-Type-Gegenprobe: Name, Land und Datum der Kopfzeile umbrechen, statt
/// abgeschnitten zu werden — die Karte hat bewusst kein `lineLimit(1)` und keine
/// feste Höhe auf Textelementen.
#Preview("Große Schrift") {
    let port = Port(name: "Civitavecchia", country: "Italien", latitude: 42.09, longitude: 11.79)

    return ScrollView {
        RouteStopCard(
            port: port, pinType: .port, isExpanded: true,
            entries: [JournalEntry(text: "Kurzer Eintrag", moodRaw: "good")],
            onToggle: {}, onSelectPort: {}, onDeletePort: {},
            onOpenEntry: { _ in }, onAddEntry: {}
        )
        .padding()
    }
    .environment(\.dynamicTypeSize, .accessibility3)
}
