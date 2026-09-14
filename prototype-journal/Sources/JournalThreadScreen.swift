//
//  JournalThreadScreen.swift
//  Screen 1 — der Tagebuch-Strang, wie er in CruiseDetailView sitzt.
//
//  Aufbau: eine durchgehende Papierseite (journalSurface) statt N schwebender
//  Karten. Links die Logbuch-Rinne mit der Tagesziffer und der gepunkteten
//  Zeitachse, rechts Kopf und Einträge des Tages. Ein dichter Tag bleibt so
//  ein Block und zerfällt nicht in drei gleichwertige Kacheln.
//

import SwiftUI

struct JournalThreadScreen: View {
    /// Reisetag, an den beim Erscheinen gescrollt wird (nil = Kopf des Strangs).
    var anchorDay: Int? = nil
    /// Signatur-Bewegung: List Entrance Cascade, spielt genau einmal.
    var animate: Bool = false

    /// Ohne `animate` steht der Strang ab dem ersten Frame — kein Standbild
    /// dieser Richtung zeigt eine laufende Bewegung.
    @State private var appeared: Bool

    init(anchorDay: Int? = nil, animate: Bool = false) {
        self.anchorDay = anchorDay
        self.animate = animate
        _appeared = State(initialValue: !animate)
    }

    var body: some View {
        // Echte App-Chrome: der Strang sitzt in CruiseDetailView, also unter
        // dem Reisen-Tab und hinter einem Push aus „Meine Reisen".
        ProtoAppChrome {
            detail
        }
    }

    private var detail: some View {
        NavigationStack {
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(alignment: .leading, spacing: 12) {
                        sectionHeader
                        journalPage
                    }
                    .padding(.horizontal, Proto.Layout.screenInset)
                    .padding(.top, 10)
                    .padding(.bottom, 44)
                }
                .background(Color(.systemBackground))
                .navigationTitle(ProtoTrip.title)
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .navigationBarLeading) {
                        // Zurück nach „Meine Reisen". Nur das Chevron, ohne
                        // Titel: der runde Toolbar-Container von iOS 26 kappt
                        // längere Labels (siehe „Ab…" im Editor).
                        Image(systemName: "chevron.left")
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundStyle(Proto.oceanBlue)
                            .accessibilityLabel("Zurück zu Meine Reisen")
                    }
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Image(systemName: "ellipsis.circle")
                            .foregroundStyle(Proto.oceanBlue)
                    }
                }
                .task {
                    if let anchorDay {
                        try? await Task.sleep(nanoseconds: 150_000_000)
                        proxy.scrollTo(anchorDay, anchor: .top)
                    }
                    if animate {
                        try? await Task.sleep(nanoseconds: 120_000_000)
                        appeared = true
                    }
                }
            }
        }
    }

    // MARK: - Abschnittskopf (Idiom der übrigen Detail-Abschnitte)

    private var sectionHeader: some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Text("Tagebuch")
                .font(.headline)
            Text("\(ProtoTrip.entryCount) Erinnerungen")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Spacer()
            Image(systemName: "square.and.pencil")
                .font(.system(size: 18, weight: .medium))
                .foregroundStyle(Proto.oceanBlue)
                .frame(width: Proto.Layout.touchTargetMin,
                       height: Proto.Layout.touchTargetMin,
                       alignment: .trailing)
        }
        // Kein zusätzlicher Rand: der Abschnittskopf steht damit exakt auf der
        // linken Kante der Papierseite, und das Stift-Symbol schließt rechts
        // bündig mit ihr ab. Vorher waren es 4 pt Versatz gegen die Fläche,
        // unter der Runde-2-Überbreite zusätzlich 27 pt aus dem Display heraus.
    }

    // MARK: - Die Papierseite

    private var journalPage: some View {
        VStack(spacing: 0) {
            ForEach(Array(ProtoTrip.days.enumerated()), id: \.element.id) { index, day in
                DayBlock(day: day, showsDivider: index > 0)
                    .id(day.id)
                    .opacity(appeared ? 1 : 0)
                    .offset(y: appeared ? 0 : Proto.Motion.entranceOffset)
                    .animation(
                        .easeOut(duration: Proto.Motion.standardIn)
                            .delay(Double(min(index, Proto.Motion.staggerCap))
                                   * Proto.Motion.staggerStep),
                        value: appeared
                    )
            }
        }
        .padding(.vertical, 18)
        .padding(.horizontal, Proto.Layout.panelInset)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Proto.journalSurface)
        .clipShape(RoundedRectangle(cornerRadius: Proto.Radius.lg))
        .shadow(color: .black.opacity(0.08), radius: 14, y: 8)
    }
}

// MARK: - Ein Reisetag

private struct DayBlock: View {
    let day: ProtoDay
    /// Die Hairline sitzt am Tageswechsel, nicht mehr zwischen zwei Einträgen —
    /// die Linie markiert damit die Gruppengrenze, die sie meint (Gestalt:
    /// gemeinsame Region), und der Tagesabstand ist doppelt so gross wie der
    /// Abstand innerhalb eines Tages.
    var showsDivider: Bool = false

    var body: some View {
        VStack(spacing: 0) {
            if showsDivider {
                ProtoHairline()
                    .padding(.leading, Proto.Layout.rail + 10)
                    .padding(.bottom, Proto.Layout.dayGap)
            }
            ProtoRailRow(numeral: "\(day.id)",
                         tint: day.pin.color,
                         dimmed: day.isEmpty) {
                VStack(alignment: .leading, spacing: 12) {
                    header
                    if day.isEmpty {
                        emptyRow
                    } else {
                        ForEach(Array(day.entries.enumerated()), id: \.element.id) { index, entry in
                            if index > 0 {
                                Color.clear.frame(height: Proto.Layout.entryGap)
                            }
                            EntryBlock(entry: entry)
                        }
                    }
                }
                .padding(.bottom, Proto.Layout.dayGap)
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text("TAG \(day.id) · \(day.dateLine)")
                .font(.protoOverline)
                .tracking(0.9)
                .foregroundStyle(.secondary)
            HStack(spacing: 7) {
                ProtoDayBadge(pin: day.pin)
                Text(day.title)
                    .font(.headline)
                if let subtitle = day.subtitle {
                    Text("· \(subtitle)")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(.top, 2)
    }

    /// Empty-Zustand des Tages — gestrichelte Fläche, das bestehende
    /// Platzhalter-Idiom aus PortMemoryCard.
    /// Die Zeile ist die breiteste im Strang und muss deshalb sicher unter die
    /// 282 pt der Inhaltsspalte passen. Gemessen an der Aufnahme: Symbol 14 +
    /// „Nichts festgehalten" 130 + „Nachtragen" 80 = 224 pt Inhalt. Mit 20 pt
    /// Innenrand, drei Fugen à 7 und 6 pt Mindestluft bleibt sie bei 271 pt —
    /// vorher sprengte sie die Spalte um vier Punkte und schob den ganzen
    /// Screen aus dem Display. `fixedSize()` steht nur noch auf der Aktion:
    /// die darf nie kappen, der graue Hinweis links dürfte es notfalls.
    private var emptyRow: some View {
        HStack(spacing: 7) {
            Image(systemName: "square.and.pencil")
                .font(.system(size: 14))
                .foregroundStyle(.tertiary)
            Text("Nichts festgehalten")
                .font(.subheadline)
                .lineLimit(1)
                .foregroundStyle(.secondary)
            Spacer(minLength: 6)
            Text("Nachtragen")
                .font(.subheadline)
                .fontWeight(.medium)
                .lineLimit(1)
                .fixedSize()
                .foregroundStyle(Proto.oceanBlue)
        }
        .padding(.horizontal, 10)
        .frame(maxWidth: .infinity, minHeight: Proto.Layout.touchTargetMin)
        .background(
            RoundedRectangle(cornerRadius: Proto.Radius.sm)
                .strokeBorder(Proto.timeline,
                              style: StrokeStyle(lineWidth: 1.2, dash: [5, 4]))
        )
    }
}

// MARK: - Ein Eintrag

private struct EntryBlock: View {
    static let collapsedLines = 8

    let entry: ProtoEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            ProtoMoodChip(mood: entry.mood)
            // Eingeklappt: ein langer Eintrag darf den Strang nicht zur
            // Textwand machen, und das Foto des Eintrags bleibt so im ersten
            // Viewport. Gekürzt wird im Payload an der Wortgrenze
            // (`collapsedText`), nicht von SwiftUI — `.tail` schneidet mitten
            // im Wort und lässt einzelne Buchstaben vor der Ellipse stehen.
            // `lineLimit` bleibt als harter Deckel stehen, greift aber nicht.
            Text(entry.collapsedText)
                .font(.protoJournalBody)
                .lineSpacing(4)
                .lineLimit(Self.collapsedLines)
                .truncationMode(.tail)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
            if entry.isTruncated {
                Text("Weiterlesen")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundStyle(Proto.oceanBlue)
            }
            if !entry.photos.isEmpty {
                ProtoPhotoStrip(photos: entry.photos)
                    .padding(.top, 1)
            }
        }
    }
}
