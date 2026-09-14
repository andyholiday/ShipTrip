//
//  JournalEditorScreen.swift
//  Screen 2 — „Erinnerung zuerst, Eckdaten als Zweitschritt" (Contract J2).
//
//  Ein Scroll-Flow, zwei Schritte, feste Reihenfolge. Die Rangfolge ist nicht
//  behauptet, sondern gebaut: Schritt 1 liegt auf der Papierfläche, bekommt
//  Titelgröße, Fließtext in 17 pt und den offenen Cursor. Schritt 2 sitzt
//  darunter auf grauem Systemgrund, in Zeilenhöhe statt Blockhöhe, alles
//  vorbelegt — durchwinken ist der Normalfall.
//

import SwiftUI

struct JournalEditorScreen: View {
    /// Beim Erscheinen zu Schritt 2 springen (Registry-Eintrag `editor.scrolled`).
    var anchorStepTwo: Bool = false

    private let stepTwoID = "schritt2"

    var body: some View {
        NavigationStack {
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(spacing: 14) {
                        stepOne
                        stepTwo.id(stepTwoID)
                    }
                    .padding(.horizontal, Proto.Layout.screenInset)
                    .padding(.top, 10)
                    .padding(.bottom, 44)
                }
                .background(Color(.systemBackground))
                .navigationTitle("Neue Erinnerung")
                .navigationBarTitleDisplayMode(.inline)
                // Der Editor ist ein modales Blatt und bekommt den
                // Scroll-Rand-Effekt der Navigationsleiste nicht von selbst:
                // in Runde 2 stand „Neue Erinnerung" auf noch lesbarem
                // Fließtext und „Sichern" auf dem Wort „Vormittag". Dieselbe
                // Abdeckung, die der Strang trägt, hier ausdrücklich bestellt.
                .toolbarBackground(.visible, for: .navigationBar)
                .toolbarBackground(Material.bar, for: .navigationBar)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        // „Abbrechen" wurde vom runden Toolbar-Container auf
                        // „Ab…" gekappt; das X ist das iOS-Idiom für den
                        // Abbruch eines modalen Blatts und kann nicht kappen.
                        Image(systemName: "xmark")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(Proto.oceanBlue)
                            .accessibilityLabel("Abbrechen")
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Text("Sichern")
                            .fontWeight(.semibold)
                            .foregroundStyle(Proto.oceanBlue)
                    }
                }
                .task {
                    if anchorStepTwo {
                        try? await Task.sleep(nanoseconds: 150_000_000)
                        proxy.scrollTo(stepTwoID, anchor: .top)
                    }
                }
            }
        }
    }

    // MARK: - Schritt 1 · Erinnerung

    private var stepOne: some View {
        ProtoRailRow(numeral: "1", tint: Proto.oceanBlue) {
            VStack(alignment: .leading, spacing: 12) {
                VStack(alignment: .leading, spacing: 3) {
                    Text("SCHRITT 1")
                        .font(.protoOverline)
                        .tracking(0.9)
                        .foregroundStyle(.secondary)
                    HStack(alignment: .firstTextBaseline) {
                        Text("Erinnerung")
                            .font(.title3.bold())
                        Spacer()
                        Text("Mi, 11. Juni")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.top, 2)

                Text(ProtoEditorState.text)
                    .font(.body)
                    .lineSpacing(5)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 11)
                    .background(
                        RoundedRectangle(cornerRadius: Proto.Radius.md)
                            .fill(Color.primary.opacity(0.04))
                    )

                VStack(spacing: 8) {
                    ForEach(ProtoEditorState.photos) { photo in
                        PhotoCaptionRow(
                            photo: photo,
                            isEditing: photo.id == ProtoEditorState.editingPhotoID
                        )
                    }
                    addPhotoRow
                }
            }
            .padding(.bottom, 2)
        }
        .padding(Proto.Layout.panelInset)
        .background(Proto.journalSurface)
        .clipShape(RoundedRectangle(cornerRadius: Proto.Radius.lg))
        .shadow(color: .black.opacity(0.08), radius: 14, y: 8)
    }

    private var addPhotoRow: some View {
        HStack(spacing: 10) {
            Image(systemName: "photo.badge.plus")
                .font(.system(size: 16))
                .foregroundStyle(Proto.oceanBlue)
            Text("Foto hinzufügen")
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundStyle(Proto.oceanBlue)
            Spacer()
        }
        .padding(.horizontal, 12)
        .frame(maxWidth: .infinity, minHeight: Proto.Layout.touchTargetMin)
        .background(
            RoundedRectangle(cornerRadius: Proto.Radius.sm)
                .strokeBorder(Proto.timeline,
                              style: StrokeStyle(lineWidth: 1.2, dash: [5, 4]))
        )
    }

    // MARK: - Schritt 2 · Eckdaten

    private var stepTwo: some View {
        ProtoRailRow(numeral: "2", tint: Proto.moodNeutral, dimmed: true) {
            VStack(alignment: .leading, spacing: 10) {
                VStack(alignment: .leading, spacing: 3) {
                    Text("SCHRITT 2")
                        .font(.protoOverline)
                        .tracking(0.9)
                        .foregroundStyle(.secondary)
                    HStack(alignment: .firstTextBaseline) {
                        Text("Eckdaten")
                            .font(.headline)
                        Spacer()
                        Text("vorbelegt")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.top, 2)

                VStack(spacing: 0) {
                    EckdatenRow(icon: "calendar",
                                tint: .secondary,
                                label: "Reisetag",
                                value: ProtoEditorState.dayValue)
                    ProtoHairline()
                    EckdatenRow(icon: "water.waves",
                                tint: Proto.seaDayPin,
                                label: "Hafen",
                                value: ProtoEditorState.portValue)
                }

                Text("Stimmung")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .padding(.top, 4)

                LazyVGrid(columns: [GridItem(.flexible(), spacing: 8),
                                    GridItem(.flexible(), spacing: 8)],
                          spacing: 8) {
                    ForEach(ProtoMood.allCases) { mood in
                        MoodOption(mood: mood,
                                   selected: mood == ProtoEditorState.selectedMood)
                    }
                }
            }
            .padding(.bottom, 2)
        }
        .padding(Proto.Layout.panelInset)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: Proto.Radius.lg))
    }
}

// MARK: - Foto mit Bildunterschrift

private struct PhotoCaptionRow: View {
    let photo: ProtoPhoto
    let isEditing: Bool

    var body: some View {
        HStack(spacing: 10) {
            Image(photo.asset)
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(width: 62, height: 62)
                .clipped()
                .clipShape(RoundedRectangle(cornerRadius: Proto.Radius.sm))

            HStack(spacing: 2) {
                if photo.caption.isEmpty && !isEditing {
                    Text("Bildunterschrift")
                        .font(.subheadline)
                        .foregroundStyle(.tertiary)
                } else {
                    Text(photo.caption)
                        .font(.subheadline)
                        .lineLimit(2)
                }
                if isEditing {
                    // Textcursor — die Caption ist gerade in Eingabe.
                    RoundedRectangle(cornerRadius: 1)
                        .fill(Proto.oceanBlue)
                        .frame(width: 2, height: 17)
                        .padding(.leading, 1)
                }
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 10)
            .frame(maxWidth: .infinity, minHeight: 40, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: Proto.Radius.sm)
                    .fill(Color.primary.opacity(isEditing ? 0.0 : 0.04))
            )
            .overlay(
                RoundedRectangle(cornerRadius: Proto.Radius.sm)
                    .strokeBorder(isEditing ? Proto.oceanBlue : Color.clear,
                                  lineWidth: 1.6)
            )
        }
    }
}

// MARK: - Eckdaten-Zeile

private struct EckdatenRow: View {
    let icon: String
    let tint: Color
    let label: String
    let value: String

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 15))
                .foregroundStyle(tint)
                .frame(width: 22)
            Text(label)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Spacer(minLength: 8)
            Text(value)
                .font(.subheadline)
                .fontWeight(.medium)
                .lineLimit(1)
            Image(systemName: "chevron.right")
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.tertiary)
        }
        .frame(minHeight: Proto.Layout.touchTargetMin)
    }
}

// MARK: - Stimmungs-Option

private struct MoodOption: View {
    let mood: ProtoMood
    let selected: Bool

    var body: some View {
        HStack(spacing: 7) {
            Circle()
                .fill(mood.color)
                .frame(width: 10, height: 10)
                .opacity(mood == .unset ? 0.35 : 1)
            Text(mood.label)
                .font(.subheadline)
                .lineLimit(1)
                .minimumScaleFactor(0.85)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 11)
        .frame(maxWidth: .infinity, minHeight: 40, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: Proto.Radius.sm)
                .fill(selected ? Proto.oceanBlue.opacity(0.10)
                               : Color.primary.opacity(0.04))
        )
        .overlay(
            RoundedRectangle(cornerRadius: Proto.Radius.sm)
                .strokeBorder(selected ? Proto.oceanBlue.opacity(0.60) : Color.clear,
                              lineWidth: 1.6)
        )
    }
}
