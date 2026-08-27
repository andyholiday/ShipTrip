//
//  JournalEntryEditorView.swift
//  ShipTrip
//
//  Eintrag-Editor „Erinnerung zuerst, Eckdaten als Zweitschritt"
//  (ADR-003, Contract J2/J2a, Einstiegspunkte J3neu (d)).
//

import SwiftUI
import SwiftData
import PhotosUI

/// Erfassen und Bearbeiten eines Journal-Eintrags.
///
/// **Reihenfolge ist der Vertrag (J2):** Schritt 1 „Erinnerung" (Text + Fotos
/// mit Bildunterschrift) steht oben und ohne Pflicht-Metadaten davor, Schritt 2
/// „Eckdaten" (Tag, Hafen, Stimmung) folgt vorbelegt darunter. Umgesetzt als
/// **ein Scroll-Flow** — die vom Contract ausdruecklich erlaubte einfachste der
/// drei Darstellungsformen.
///
/// **Save-Semantik (J2):** kein Zwischenspeichern. Alle Mutationen — auch
/// Abhaengen und Bildunterschriften bestehender Fotos — passieren erst beim
/// Speichern, mit **einem** gemeinsamen `now`, damit die Bumps der Matrix J2a
/// exakt zusammenpassen. Abbrechen verwirft alles; es wurde nichts angefasst.
///
/// **Einstieg (T8d-Vertrag):** als Sheet praesentieren — die View bringt ihren
/// eigenen `NavigationStack` mit (Muster `ExpenseFormView`).
struct JournalEntryEditorView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    private let cruise: Cruise
    /// `nil` = neuer Eintrag.
    private let entry: JournalEntry?

    // Schritt 1 „Erinnerung"
    @State private var text: String
    @State private var pendingPhotos: [PendingPhoto] = []
    @State private var detachedPhotoIDs: Set<UUID> = []
    @State private var captionDrafts: [UUID: String] = [:]
    @State private var pickerItems: [PhotosPickerItem] = []

    // Schritt 2 „Eckdaten"
    @State private var localDay: Date
    @State private var selectedPortID: UUID?
    @State private var didChoosePortManually: Bool
    @State private var moodRaw: String

    // MARK: - Einstiege

    /// Neuer Eintrag, vorbelegt nach J2 Schritt 2 bzw. J3neu (d).
    ///
    /// - Parameter prefill: `.stop(portID:arrival:)` beim Einstieg an einem
    ///   aufgeklappten Stopp, `.noStop` im Sammelblock „Weitere Einträge".
    init(cruise: Cruise, prefill: JournalEntryPrefill = .noStop, today: Date = Date()) {
        let day = JournalEditorDefaults.localDay(
            prefill: prefill.localDay,
            today: today,
            cruiseStart: cruise.startDate,
            cruiseEnd: cruise.endDate
        )
        let stops = Self.stopInputs(of: cruise)

        self.cruise = cruise
        self.entry = nil
        _text = State(initialValue: "")
        _localDay = State(initialValue: day)
        _selectedPortID = State(
            initialValue: prefill.portID
                ?? JournalEditorDefaults.portID(forLocalDay: day, stops: stops)
        )
        // Vorbelegung ist noch keine Wahl des Users: aendert er den Tag, wird der
        // Hafen nach J2 neu berechnet.
        _didChoosePortManually = State(initialValue: false)
        _moodRaw = State(initialValue: "")
    }

    /// Bearbeiten: gleicher Editor, alle Felder vorbelegt, gleiche Reihenfolge (J2).
    init(cruise: Cruise, entry: JournalEntry) {
        self.cruise = cruise
        self.entry = entry
        _text = State(initialValue: entry.text)
        _localDay = State(
            initialValue: JournalEditorDefaults.localDay(ofEntryDate: entry.entryDate)
        )
        _selectedPortID = State(initialValue: entry.port?.id)
        // Ein gespeicherter Hafen-Bezug ist eine Tatsache, kein Default — ein
        // Datumswechsel darf ihn nicht still ueberschreiben.
        _didChoosePortManually = State(initialValue: true)
        _moodRaw = State(initialValue: entry.moodRaw)
    }

    // MARK: - Body

    var body: some View {
        NavigationStack {
            Form {
                memorySection
                factsSection
            }
            .navigationTitle(
                entry == nil
                    ? String(localized: "Eintrag hinzufügen")
                    : String(localized: "Eintrag bearbeiten")
            )
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(String(localized: "Abbrechen")) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(String(localized: "Speichern")) { save() }
                        .disabled(!canSave)
                }
            }
            .onChange(of: pickerItems) { _, items in loadPickedPhotos(items) }
            .onChange(of: localDay) { _, newDay in updateDefaultPort(for: newDay) }
        }
    }

    // MARK: - Schritt 1 „Erinnerung"

    private var memorySection: some View {
        Section {
            textEditor
            ForEach(attachedPhotos) { photo in
                photoRow(
                    data: photo.thumbnailData ?? photo.imageData,
                    caption: captionBinding(for: photo),
                    remove: { detachedPhotoIDs.insert(photo.id) }
                )
            }
            ForEach($pendingPhotos) { $pending in
                photoRow(
                    data: pending.data,
                    caption: $pending.caption,
                    remove: { pendingPhotos.removeAll { $0.id == pending.id } }
                )
            }
            PhotosPicker(selection: $pickerItems, matching: .images) {
                Label(String(localized: "Fotos hinzufügen"), systemImage: "photo.badge.plus")
            }
        } header: {
            Text(String(localized: "Erinnerung"))
        } footer: {
            if !canSave {
                Text(String(localized: "Schreib etwas oder wähl mindestens ein Foto."))
            }
        }
    }

    private var textEditor: some View {
        TextEditor(text: $text)
            .frame(minHeight: 140)
            .overlay(alignment: .topLeading) {
                if text.isEmpty {
                    // `.secondary` statt `.tertiary`: der Platzhalter muss lesbar
                    // bleiben (Kontrast-Auflage der Abnahme-Checkliste).
                    Text(String(localized: "Woran willst du dich erinnern?"))
                        .foregroundStyle(.secondary)
                        .padding(.top, 8)
                        .padding(.leading, 5)
                        .allowsHitTesting(false)
                }
            }
            .accessibilityLabel(String(localized: "Erinnerung"))
    }

    private func photoRow(
        data: Data,
        caption: Binding<String>,
        remove: @escaping () -> Void
    ) -> some View {
        HStack(spacing: 12) {
            // `.fit` statt `.fill`: ein quadratischer Ausschnitt wuerde Koepfe
            // beschneiden (Aspect-Regel der Abnahme-Checkliste).
            AsyncPhotoView(imageData: data, contentMode: .fit, maxPixelSize: 200)
                .frame(width: 56, height: 56)
                .background(Color(.tertiarySystemFill))
                .clipShape(RoundedRectangle(cornerRadius: DesignRadius.sm))
                .accessibilityHidden(true)

            TextField(String(localized: "Bildunterschrift"), text: caption)

            Button(role: .destructive, action: remove) {
                Image(systemName: "minus.circle.fill")
                    .foregroundStyle(.red)
            }
            .buttonStyle(.plain)
            .frame(width: 44, height: 44)
            .contentShape(Rectangle())
            .accessibilityLabel(String(localized: "Foto entfernen"))
        }
    }

    // MARK: - Schritt 2 „Eckdaten"

    private var factsSection: some View {
        Section(String(localized: "Eckdaten")) {
            DatePicker(
                String(localized: "Tag"),
                selection: $localDay,
                in: JournalEditorDefaults.dayRange(
                    cruiseStart: cruise.startDate,
                    cruiseEnd: cruise.endDate
                ),
                displayedComponents: .date
            )

            Picker(String(localized: "Hafen"), selection: portBinding) {
                Text(String(localized: "Kein Hafen")).tag(UUID?.none)
                ForEach(sortedRoute) { port in
                    Text(Self.portLabel(port)).tag(Optional(port.id))
                }
            }
            .pickerStyle(.navigationLink)

            JournalMoodPicker(moodRaw: $moodRaw)
        }
    }

    /// Schreibt die Auswahl **und** merkt sich, dass sie vom User kam — danach
    /// rechnet ein Datumswechsel den Hafen nicht mehr neu (J2 Schritt 2).
    private var portBinding: Binding<UUID?> {
        Binding(
            get: { selectedPortID },
            set: { newValue in
                selectedPortID = newValue
                didChoosePortManually = true
            }
        )
    }

    // MARK: - Abgeleiteter Zustand

    private var trimmedText: String {
        text.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Pflichtregel J2 Schritt 1: Speichern erst, wenn Text nicht leer **oder**
    /// mindestens ein Foto am Eintrag haengt.
    private var canSave: Bool {
        !trimmedText.isEmpty || !pendingPhotos.isEmpty || !attachedPhotos.isEmpty
    }

    /// Bereits angehaengte Fotos ohne die im Editor abgehaengten.
    private var attachedPhotos: [Photo] {
        (entry?.photos ?? [])
            .filter { !detachedPhotoIDs.contains($0.id) }
            .sorted { $0.sortOrder < $1.sortOrder }
    }

    private var sortedRoute: [Port] {
        cruise.route.sorted { $0.sortOrder < $1.sortOrder }
    }

    private func captionBinding(for photo: Photo) -> Binding<String> {
        Binding(
            get: { captionDrafts[photo.id] ?? photo.caption },
            set: { captionDrafts[photo.id] = $0 }
        )
    }

    /// Seetage sind Route-Stopps und damit waehlbar (J3neu (a)); das Datum
    /// unterscheidet gleichnamige Stopps.
    private static func portLabel(_ port: Port) -> String {
        "\(port.name) · \(port.arrival.formatted(date: .abbreviated, time: .omitted))"
    }

    private static func stopInputs(of cruise: Cruise) -> [RouteStopInput] {
        cruise.route.map {
            RouteStopInput(id: $0.id, sortOrder: $0.sortOrder, arrival: $0.arrival)
        }
    }

    // MARK: - Aktionen

    private func updateDefaultPort(for newDay: Date) {
        guard !didChoosePortManually else { return }
        selectedPortID = JournalEditorDefaults.portID(
            forLocalDay: newDay,
            stops: Self.stopInputs(of: cruise)
        )
    }

    private func loadPickedPhotos(_ items: [PhotosPickerItem]) {
        guard !items.isEmpty else { return }
        Task {
            var loaded: [PendingPhoto] = []
            for item in items {
                if let data = try? await item.loadTransferable(type: Data.self) {
                    loaded.append(PendingPhoto(data: data))
                }
            }
            pendingPhotos.append(contentsOf: loaded)
            pickerItems = []
        }
    }

    /// Ein Speicher-Zeitpunkt fuer alle Bumps der Matrix J2a.
    private func save() {
        guard canSave else { return }
        let now = Date()
        let target = entry ?? insertNewEntry(at: now)

        if entry != nil { applyFieldChanges(to: target, at: now) }
        applyPortChange(to: target, at: now)
        applyPhotoChanges(to: target, at: now)

        cruise.updatedAt = now
        dismiss()
    }

    /// Anlegen (J2a Zeile 1): `updatedAt == createdAt`, weil alle folgenden Bumps
    /// dasselbe `now` tragen.
    private func insertNewEntry(at now: Date) -> JournalEntry {
        let newEntry = JournalEntry(
            text: trimmedText, localDay: localDay, moodRaw: moodRaw, now: now
        )
        newEntry.cruise = cruise
        modelContext.insert(newEntry)
        return newEntry
    }

    /// Nur tatsaechliche Aenderungen bumpen — ein „Durchwinken" ohne Aenderung
    /// darf `updatedAt` nicht anfassen.
    private func applyFieldChanges(to target: JournalEntry, at now: Date) {
        if target.text != trimmedText { target.setText(trimmedText, at: now) }
        if RouteDayKey.entryDay(target.entryDate) != RouteDayKey.localDay(localDay) {
            target.setEntryDate(localDay: localDay, at: now)
        }
        if target.moodRaw != moodRaw { target.setMoodRaw(moodRaw, at: now) }
    }

    private func applyPortChange(to target: JournalEntry, at now: Date) {
        let newPort = selectedPortID.flatMap { id in cruise.route.first { $0.id == id } }
        guard target.port?.id != newPort?.id else { return }
        target.setPort(newPort, at: now)
    }

    private func applyPhotoChanges(to target: JournalEntry, at now: Date) {
        // Schnappschuss vor dem Abhaengen: die Beziehung aendert sich waehrend
        // der Schleife, und eine Bildunterschrift gehoert zum Foto — sie gilt
        // auch dann, wenn das Foto den Eintrag verlaesst (J2a: nur `photo` bumpt).
        let existingPhotos = entry?.photos ?? []
        for photo in existingPhotos where detachedPhotoIDs.contains(photo.id) {
            target.detach(photo, at: now)
        }
        for photo in existingPhotos {
            guard let draft = captionDrafts[photo.id], draft != photo.caption else { continue }
            photo.setCaption(draft, at: now)
        }
        // Neue Fotos: Kind der Reise **und** am Eintrag (J2 Schritt 1),
        // `sortOrder` ans Ende der bestehenden Galerie.
        var nextOrder = (cruise.photos.map(\.sortOrder).max() ?? -1) + 1
        for pending in pendingPhotos {
            let photo = Photo(imageData: pending.data, sortOrder: nextOrder)
            // Thumbnail synchron (Muster `CruiseFormView`): schnell und ohne
            // Lost-Write-Risiko eines Fire-and-forget-Tasks.
            photo.thumbnailData = ImageDownsampler.thumbnail(from: pending.data)
            photo.cruise = cruise
            modelContext.insert(photo)
            photo.setCaption(pending.caption, at: now)
            target.attach(photo, at: now)
            nextOrder += 1
        }
    }

    /// Ein noch nicht gespeichertes Foto — existiert nur bis zum Save bzw. bis
    /// zum Abbrechen.
    private struct PendingPhoto: Identifiable {
        let id = UUID()
        let data: Data
        var caption: String = ""
    }
}
