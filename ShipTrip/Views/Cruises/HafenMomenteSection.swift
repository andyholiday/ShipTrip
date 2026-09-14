//
//  HafenMomenteSection.swift
//  ShipTrip
//
//  Welle D2: Die "Hafen-Momente"-Section lag zuvor wortgleich zweimal im Code –
//  einmal in `PortFormView`, einmal in `TempPortFormSheet`. Sie liegt jetzt einmal
//  hier und wird von beiden Formularen über Bindings auf Hafenbild und Ausflüge
//  eingebunden.
//

import SwiftUI
import PhotosUI

// MARK: - Hafen-Momente (B7.1/A2)
//
// Hafenbild + Ausflüge als ein geführter Erfassungsschritt statt zwei generischer
// Formularfelder (Design-Vorschlag A2, docs/ux-pitch-decks/b6-hafen-momente.html).
// In eigene Sub-Views zerlegt (Compiler-Fix Gate #2): eine einzelne, große
// ViewBuilder-Expression in `body` überforderte den Type-Checker.

/// Die komplette "Hafen-Momente"-Section: Cover-Foto, Chip-Schnellauswahl,
/// Ausflugsliste (mit Reorder/Delete) und Freitext-Eingabe.
struct HafenMomenteSection: View {
    /// Hafenbild des bearbeiteten Hafens – das einbindende Formular speichert es.
    @Binding var imageData: Data?
    /// Ausflüge des bearbeiteten Hafens – das einbindende Formular speichert sie.
    @Binding var excursions: [String]

    @State private var selectedPhotoItem: PhotosPickerItem?
    @State private var newExcursionText = ""
    // B7.1/A2 (Gate #2 Fix, Plan B): natives List-EditMode zeigt die Reorder-Griffe in der
    // echten Form/List zuverlässig NICHT (zweifach per UI-Test widerlegt, s. Team-Report).
    // Ersetzt durch explizite Auf-/Ab-Buttons pro Zeile im Reorder-Modus – kein EditMode nötig.
    @State private var isReorderingExcursions = false

    var body: some View {
        Section(String(localized: "Hafen-Momente")) {
            coverPhotoTile
            excursionChipScroller
            excursionList
            excursionReorderToggle
            addExcursionRow
        }
        .onChange(of: selectedPhotoItem) { _, newItem in
            loadImage(from: newItem)
        }
    }

    /// Kreuzfahrt-typische Schnellauswahl für Ausflüge – reduziert Tipparbeit an Bord
    /// (oft schlechtes Netz/wenig Zeit), Freitext bleibt daneben weiterhin möglich.
    private var excursionSuggestions: [String] {
        [
            String(localized: "Stadtbummel"),
            String(localized: "Strand"),
            String(localized: "Wanderung"),
            String(localized: "Bootstour"),
            String(localized: "Museum"),
            String(localized: "Shopping")
        ]
    }

    @ViewBuilder
    private var coverPhotoTile: some View {
        if let imageData, let uiImage = UIImage(data: imageData) {
            VStack(alignment: .leading, spacing: 8) {
                Image(uiImage: uiImage)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(maxWidth: .infinity, minHeight: 160, maxHeight: 160)
                    .clipShape(RoundedRectangle(cornerRadius: DesignRadius.md))
                    .clipped()

                HStack {
                    PhotosPicker(selection: $selectedPhotoItem, matching: .images) {
                        Label(String(localized: "Bild ersetzen"), systemImage: "photo.on.rectangle.angled")
                    }
                    Spacer()
                    Button(role: .destructive) {
                        self.imageData = nil
                        selectedPhotoItem = nil
                    } label: {
                        Label(String(localized: "Entfernen"), systemImage: "trash")
                    }
                }
                .font(.subheadline)
            }
        } else {
            PhotosPicker(selection: $selectedPhotoItem, matching: .images) {
                VStack(spacing: 8) {
                    Image(systemName: "photo.badge.plus")
                        .font(.system(size: 32))
                    Text(String(localized: "Cover-Foto hinzufügen"))
                        .font(.subheadline)
                }
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, minHeight: 140)
                .background(Color(.secondarySystemBackground))
                .clipShape(RoundedRectangle(cornerRadius: DesignRadius.md))
            }
            .buttonStyle(.plain)
        }
    }

    private var excursionChipScroller: some View {
        ScrollView(.horizontal) {
            HStack(spacing: 8) {
                ForEach(excursionSuggestions, id: \.self) { suggestion in
                    Button {
                        addExcursion(suggestion)
                    } label: {
                        Text(suggestion)
                            .font(.subheadline)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(Color.accentColor.opacity(0.15))
                            .foregroundStyle(Color.accentColor)
                            .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                    // Gesten-Konflikt vermeiden: ohne festen contentShape kollidiert der Tap
                    // sonst mit dem vertikalen Scroll-Gesture des umgebenden Form (Gate-Hinweis
                    // aus dem Design-Deck, s6).
                    .contentShape(Rectangle())
                }
            }
        }
        .scrollIndicators(.hidden)
    }

    /// Ausflugsliste. Reorder erfolgt über `excursionMoveButtons` in `excursionRow`, nicht
    /// über natives List-EditMode (Plan B, s. `isReorderingExcursions`).
    private var excursionList: some View {
        ForEach(Array(excursions.enumerated()), id: \.offset) { index, excursion in
            excursionRow(index: index, excursion: excursion)
        }
        .onDelete { excursions.remove(atOffsets: $0) }
    }

    private func excursionRow(index: Int, excursion: String) -> some View {
        HStack {
            Text(excursion)
            Spacer()
            if isReorderingExcursions {
                excursionMoveButtons(index: index)
            } else {
                excursionDeleteButton(index: index)
            }
        }
    }

    private func excursionDeleteButton(index: Int) -> some View {
        Button {
            excursions.remove(at: index)
        } label: {
            Image(systemName: "minus.circle.fill")
                .foregroundStyle(.red)
        }
        .buttonStyle(.plain)
        // .plain entfernt die Standard-Polsterung des Buttons; ohne festen Frame +
        // contentShape bliebe die tatsächlich tappbare Fläche auf die reinen
        // Glyphen-Pixel beschränkt (unzuverlässig, ~44pt-Mindestgröße laut HIG
        // unterschritten).
        .frame(width: 44, height: 44)
        .contentShape(Rectangle())
        .accessibilityLabel(String(localized: "Ausflug entfernen"))
    }

    /// Auf-/Ab-Buttons statt nativem List-EditMode (Gate #2 Fix, Plan B): die native
    /// Reorder-Affordance über `.environment(\.editMode, …)` rendert in der echten Form/List
    /// zuverlässig KEINE Move-Griffe (zweifach per UI-Test belegt). Index-basiertes
    /// `swapAt`, oberste Zeile ohne "Nach oben", unterste ohne "Nach unten".
    private func excursionMoveButtons(index: Int) -> some View {
        HStack(spacing: 4) {
            Button {
                excursions.swapAt(index, index - 1)
            } label: {
                Image(systemName: "chevron.up")
            }
            .buttonStyle(.plain)
            .frame(width: 44, height: 44)
            .contentShape(Rectangle())
            .accessibilityLabel(String(localized: "Nach oben"))
            .accessibilityIdentifier("excursion-\(index)-moveUp")
            .disabled(index == 0)

            Button {
                excursions.swapAt(index, index + 1)
            } label: {
                Image(systemName: "chevron.down")
            }
            .buttonStyle(.plain)
            .frame(width: 44, height: 44)
            .contentShape(Rectangle())
            .accessibilityLabel(String(localized: "Nach unten"))
            .accessibilityIdentifier("excursion-\(index)-moveDown")
            .disabled(index == excursions.count - 1)
        }
    }

    /// Umschalter für den Reorder-Modus – erst ab zwei Ausflügen sinnvoll.
    @ViewBuilder
    private var excursionReorderToggle: some View {
        if excursions.count > 1 {
            Button {
                isReorderingExcursions.toggle()
            } label: {
                Label(
                    isReorderingExcursions ? String(localized: "Fertig") : String(localized: "Reihenfolge ändern"),
                    systemImage: "arrow.up.arrow.down"
                )
            }
            .buttonStyle(.plain)
            .font(.subheadline)
        }
    }

    private var addExcursionRow: some View {
        HStack {
            TextField(String(localized: "Ausflug hinzufügen"), text: $newExcursionText)
                .onSubmit { addExcursion() }
            Button {
                addExcursion()
            } label: {
                Image(systemName: "plus.circle.fill")
            }
            .accessibilityLabel(String(localized: "Ausflug hinzufügen"))
            .disabled(sanitizedExcursionEntry(newExcursionText) == nil)
        }
    }

    // MARK: - Actions

    private func addExcursion() {
        guard let entry = sanitizedExcursionEntry(newExcursionText) else { return }
        excursions.append(entry)
        newExcursionText = ""
    }

    /// Fügt einen vordefinierten Ausflug-Chip hinzu (B7.1/A2). Erlaubt bewusst Duplikate
    /// (derselbe Chip mehrfach antippbar) – konsistent mit dem Freitext-Pfad, der
    /// gleichnamige Ausflüge schon immer zuließ (siehe `RemoveExcursionTests`, Index-Löschung).
    private func addExcursion(_ suggestion: String) {
        excursions.append(suggestion)
    }

    private func loadImage(from item: PhotosPickerItem?) {
        guard let item else { return }
        Task {
            if let data = try? await item.loadTransferable(type: Data.self) {
                await MainActor.run {
                    imageData = data
                }
            }
        }
    }
}
