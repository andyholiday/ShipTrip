//
//  RouteJournalEntryRow.swift
//  ShipTrip
//
//  Eintragszeile im Route-Journal-Faden (Contract J3neu (c)).
//

import SwiftUI

/// Kompakte Zeile eines Journal-Eintrags unter einem Route-Stopp oder im
/// Sammelblock „Weitere Einträge".
///
/// Zeigt Stimmungs-Emoji, optional das Datum, einen `lineLimit(3)`-Auszug des
/// Textes samt „Weiterlesen" (Regel in `JournalExcerpt`) und kleine
/// Foto-Vorschauen. Captions gibt es erst in der Detailansicht (J3neu (c)).
struct RouteJournalEntryRow: View {
    let entry: JournalEntry
    /// Datum anzeigen? Nur wenn es vom `arrival`-Tag des Stopps abweicht oder
    /// die Zeile im Sammelblock steht (J3neu (c)) — siehe `showsDate(...)`.
    let showsDate: Bool
    /// Öffnet die Eintrags-Detailansicht (T8c).
    let onOpen: () -> Void

    /// Kantenlänge einer Foto-Vorschau. Der Inhalt wird **eingepasst**
    /// (`contentMode: .fit`), nicht beschnitten — so kann kein Kopf am oberen
    /// Bildrand wegfallen.
    private static let thumbnailSize: CGFloat = 56

    /// Zielgröße fürs Downsampling der Vorschau (vgl. `PortMemoryCard.heroMaxPixelSize`).
    private static let thumbnailMaxPixelSize: CGFloat = 200

    /// Mehr Vorschauen würden die Zeile sprengen; der Rest steht als Zähler daneben.
    private static let maxThumbnails = 4

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            if let mood {
                Text(mood.emoji)
                    .font(.body)
                    .accessibilityLabel(mood.label)
            }

            VStack(alignment: .leading, spacing: 6) {
                if showsDate {
                    Text(JournalEntryDayDisplay.dayText(for: entry.entryDate))
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }

                if !entry.text.isEmpty {
                    Text(entry.text)
                        .font(.subheadline)
                        .lineLimit(JournalExcerpt.lineLimit)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)
                }

                if JournalExcerpt.needsReadMore(entry.text) {
                    Button {
                        onOpen()
                    } label: {
                        Text("Weiterlesen")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(Color.accentColor)
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("journalEntryRow.readMore")
                }

                if !sortedPhotos.isEmpty {
                    thumbnailStrip
                }
            }

            Spacer(minLength: 0)
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.tertiarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: DesignRadius.sm))
        .contentShape(Rectangle())
        .onTapGesture { onOpen() }
        // Eine Zeile = ein Accessibility-Element mit zusammengesetztem Label
        // (Stimmung, Datum, Auszug); `.combine` erhält dabei die Aktion des
        // „Weiterlesen"-Buttons. Die Zeile selbst ist antippbar, deshalb trägt
        // sie den Button-Trait — sonst kündigt VoiceOver sie als reinen Text an.
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isButton)
        .accessibilityHint(Text("Öffnet den ganzen Eintrag"))
        .accessibilityIdentifier("journalEntryRow")
        .accessibilityAction { onOpen() }
    }

    // MARK: - Bausteine

    private var mood: JournalMood? {
        JournalMood.known(forRaw: entry.moodRaw)
    }

    private var sortedPhotos: [Photo] {
        entry.photos.sorted { $0.sortOrder < $1.sortOrder }
    }

    private var thumbnailStrip: some View {
        HStack(spacing: 6) {
            ForEach(sortedPhotos.prefix(Self.maxThumbnails)) { photo in
                AsyncPhotoView(
                    imageData: photo.thumbnailData ?? photo.imageData,
                    contentMode: .fit,
                    maxPixelSize: Self.thumbnailMaxPixelSize
                )
                .frame(width: Self.thumbnailSize, height: Self.thumbnailSize)
                .background(Color(.quaternarySystemFill))
                .clipShape(RoundedRectangle(cornerRadius: 6))
            }

            if sortedPhotos.count > Self.maxThumbnails {
                Text("+\(sortedPhotos.count - Self.maxThumbnails)")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
        }
        // Plural über den Katalog-Key `%lld Fotos` — „1 Foto" statt „1 Fotos".
        .accessibilityLabel(String(localized: "\(sortedPhotos.count) Fotos"))
    }

    // MARK: - Reine Logik (testbar ohne SwiftUI-Rendering)

    /// Zeigt die Zeile ihr eigenes Datum? Nach J3neu (c) nur, wenn der
    /// Eintragstag vom `arrival`-Tag des tragenden Stopps abweicht.
    ///
    /// Der Vergleich läuft — wie in den Planern (T8a) — ausschließlich über
    /// `RouteDayKey`: `entryDate` über den UTC-Kalender, `arrival` über den
    /// Geräte-Kalender. Ein eigener `Calendar`-Vergleich in der View würde den
    /// Zeitzonen-Vertrag brechen.
    static func showsDate(
        entryDate: Date,
        stopArrival: Date,
        calendar: Calendar = .current
    ) -> Bool {
        RouteDayKey.entryDay(entryDate) != RouteDayKey.localDay(stopArrival, calendar: calendar)
    }
}
