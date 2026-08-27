//
//  JournalEntryDetailView.swift
//  ShipTrip
//
//  Eintrags-Detailansicht — Ziel von „Weiterlesen" (ADR-003, Contract J3neu (c)).
//

import SwiftUI
import SwiftData

/// Der ganze Eintrag: voller Text, Stimmung, Reisetag + Datum, Hafen und alle
/// Fotos mit ihren Bildunterschriften.
///
/// **Einziger Ort fuer Bearbeiten und Löschen (J3neu (c)/(d)):** die Route-Zeilen
/// fuehren nur hierher, es gibt keine Zweitpfade. Geloescht wird ausschliesslich
/// ueber `JournalDeletePaths`, damit die Nullify-Bumps der Matrix J2a wirklich
/// laufen.
///
/// **Einstieg (T8d-Vertrag):** in einen `NavigationStack` **pushen** (die View
/// bringt bewusst keinen eigenen mit, damit sie sich in den Route-Faden der
/// `CruiseDetailView` einfuegt). Der Eintrag wird ueber seine stabile `id`
/// aufgeloest — so bleibt das Navigations-Ziel `Hashable` und ueberlebt einen
/// Neuaufbau der Liste.
struct JournalEntryDetailView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @Query private var matches: [JournalEntry]

    @State private var isEditing = false
    @State private var isConfirmingDelete = false

    init(entryID: UUID) {
        _matches = Query(
            filter: #Predicate<JournalEntry> { entry in
                entry.id == entryID
            },
            sort: \JournalEntry.createdAt
        )
    }

    var body: some View {
        Group {
            if let entry = matches.first {
                content(for: entry)
            } else {
                // Zwischenbild nach dem Loeschen und bei einem verwaisten Ziel.
                ContentUnavailableView(
                    String(localized: "Eintrag nicht gefunden"),
                    systemImage: "book.closed"
                )
            }
        }
        .navigationTitle(String(localized: "Tagebuch-Eintrag"))
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - Inhalt

    private func content(for entry: JournalEntry) -> some View {
        List {
            Section { header(for: entry) }

            if !entry.text.isEmpty {
                Section(String(localized: "Erinnerung")) {
                    // Voller Text — bewusst ohne `lineLimit`; der Auszug mit
                    // „Weiterlesen" bleibt der Route-Zeile vorbehalten.
                    Text(entry.text)
                        .font(.body)
                        .textSelection(.enabled)
                }
            }

            if !sortedPhotos(of: entry).isEmpty {
                Section(String(localized: "Fotos")) {
                    ForEach(sortedPhotos(of: entry)) { photo in
                        photoRow(photo)
                    }
                }
            }

            Section { deleteButton }
        }
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button(String(localized: "Bearbeiten")) { isEditing = true }
                    .disabled(entry.cruise == nil)
            }
        }
        .sheet(isPresented: $isEditing) {
            if let cruise = entry.cruise {
                JournalEntryEditorView(cruise: cruise, entry: entry)
            }
        }
        .confirmationDialog(
            String(localized: "Eintrag löschen?"),
            isPresented: $isConfirmingDelete,
            titleVisibility: .visible
        ) {
            Button(String(localized: "Löschen"), role: .destructive) { delete(entry) }
            Button(String(localized: "Abbrechen"), role: .cancel) {}
        } message: {
            Text(String(localized: "Die angehängten Fotos bleiben in der Reise-Galerie."))
        }
    }

    private func header(for entry: JournalEntry) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                if let mood = JournalMood.known(forRaw: entry.moodRaw) {
                    Text(mood.emoji)
                        .font(.title2)
                        .accessibilityLabel(mood.label)
                }
                Text(dayHeadline(for: entry))
                    .font(.headline)
            }

            if let port = entry.port {
                Label(port.name, systemImage: "mappin.and.ellipse")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 2)
    }

    private func photoRow(_ photo: Photo) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            // `.fit`: die Detailansicht zeigt das ganze Bild — kein Ausschnitt,
            // der Koepfe beschneidet (Aspect-Regel der Abnahme-Checkliste).
            AsyncPhotoView(imageData: photo.imageData, contentMode: .fit, maxPixelSize: 1200)
                .frame(maxWidth: .infinity, minHeight: 220, maxHeight: 260)
                .clipShape(RoundedRectangle(cornerRadius: DesignRadius.sm))

            if !photo.caption.isEmpty {
                Text(photo.caption)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(
            photo.caption.isEmpty ? String(localized: "Foto ohne Bildunterschrift") : photo.caption
        )
    }

    private var deleteButton: some View {
        Button(role: .destructive) {
            isConfirmingDelete = true
        } label: {
            Label(String(localized: "Eintrag löschen"), systemImage: "trash")
        }
    }

    // MARK: - Abgeleitete Werte

    /// „Tag 3 · 12. Juni 2026" — die Reisetag-Nummer entfaellt, wenn der Eintrag
    /// vor dem Starttag liegt oder die Reise fehlt.
    private func dayHeadline(for entry: JournalEntry) -> String {
        let dateText = JournalEntryDayDisplay.dayText(for: entry.entryDate, style: .long)
        guard let start = entry.cruise?.startDate,
              let day = JournalEntryDayDisplay.tripDayNumber(
                  entryDate: entry.entryDate, cruiseStart: start
              )
        else { return dateText }
        return "\(String(localized: "Tag \(day)")) · \(dateText)"
    }

    private func sortedPhotos(of entry: JournalEntry) -> [Photo] {
        entry.photos.sorted { $0.sortOrder < $1.sortOrder }
    }

    // MARK: - Aktionen

    /// Loeschen ausschliesslich ueber `JournalDeletePaths` (T8-Auflage): der Pfad
    /// haengt die Fotos ab und bumpt jedes einzelne — SwiftData-Nullify allein
    /// taete das nicht, und der Loeschvorgang ginge beim CloudKit-Merge verloren.
    private func delete(_ entry: JournalEntry) {
        let now = Date()
        let cruise = entry.cruise
        JournalDeletePaths.deleteEntry(entry, in: modelContext, at: now)
        cruise?.updatedAt = now
        dismiss()
    }
}
