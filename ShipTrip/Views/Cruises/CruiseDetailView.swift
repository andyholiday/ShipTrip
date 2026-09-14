//
//  CruiseDetailView.swift
//  ShipTrip
//
//  Created by ShipTrip on 18.12.25.
//

import SwiftUI
import SwiftData

/// Detailansicht einer Kreuzfahrt
struct CruiseDetailView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    
    @Bindable var cruise: Cruise
    
    @State private var showingEditSheet = false
    @State private var showingDeleteAlert = false
    @State private var showingAddPortSheet = false
    @State private var showingAddExpenseSheet = false
    @State private var selectedPort: Port?
    @State private var selectedExpense: Expense?
    @State private var zoomedPhoto: Photo?
    @State private var alertMessage = ""
    @State private var showingAlert = false
    /// Teilen-Aktion (C7) — Dateibau, Share-Sheet und Aufräumen liegen in `CruiseShareAction`.
    @State private var shareModel = CruiseShareModel()
    /// Journal-Ziele (T8c) — Push und Sheet liegen in `CruiseJournalNavigation`.
    @State private var journalNavigation = CruiseJournalNavigation()

    private let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "dd.MM.yyyy"
        return formatter
    }()
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                // Hero Image
                heroImageSection

                // Eckdaten-Zeile
                statsSection

                // Info Section
                infoSection
                
                // Route Section
                routeSection
                
                // Expenses Section
                expensesSection
                
                // Notes Section
                if !cruise.notes.isEmpty {
                    notesSection
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 16)
            .padding(.bottom, 128)
        }
        .navigationTitle(cruise.title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Menu {
                    Button {
                        showingEditSheet = true
                    } label: {
                        Label("Bearbeiten", systemImage: "pencil")
                    }

                    // Die Beispielreise wird nicht geteilt (C1/C7) — der Eintrag fehlt dort
                    // ganz, statt deaktiviert dazustehen.
                    if !cruise.isDemo {
                        Button {
                            shareModel.share(cruise)
                        } label: {
                            Label("Reise teilen", systemImage: "square.and.arrow.up")
                        }
                        .disabled(shareModel.isPreparing)
                        .accessibilityIdentifier("cruiseDetail.shareButton")
                    }

                    Button(role: .destructive) {
                        showingDeleteAlert = true
                    } label: {
                        Label("Löschen", systemImage: "trash")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }
        }
        .sheet(isPresented: $showingEditSheet) {
            CruiseFormView(cruise: cruise)
        }
        .sheet(isPresented: $showingAddPortSheet) {
            PortFormView(cruise: cruise, port: nil)
        }
        .sheet(isPresented: $showingAddExpenseSheet) {
            ExpenseFormView(cruise: cruise, expense: nil)
        }
        .sheet(item: $selectedPort) { port in
            PortFormView(cruise: cruise, port: port)
        }
        .sheet(item: $selectedExpense) { expense in
            ExpenseFormView(cruise: cruise, expense: expense)
        }
        .fullScreenCover(item: $zoomedPhoto) { photo in
            PhotoZoomView(photos: cruise.sortedPhotos, initialPhoto: photo)
        }
        .cruiseSharePresentation(shareModel)
        .cruiseJournalNavigation(journalNavigation, cruise: cruise)
        .alert("Kreuzfahrt löschen?", isPresented: $showingDeleteAlert) {
            Button("Abbrechen", role: .cancel) { }
            Button("Löschen", role: .destructive) {
                deleteCruise()
            }
        } message: {
            Text("Diese Aktion kann nicht rückgängig gemacht werden.")
        }
        .alert("Info", isPresented: $showingAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(alertMessage)
        }
    }
    
    // MARK: - Sections
    
    /// Schiff, Dauer und Hafenzahl – Teil-Strings, damit jeder Zähler seine eigene Pluralform bekommt.
    private var heroMetaLine: String {
        let portCount = cruise.route.filter { !$0.isSeaDay }.count
        return [
            cruise.ship,
            String(localized: "\(cruise.duration) Tage"),
            String(localized: "\(portCount) Häfen")
        ].joined(separator: " · ")
    }

    /// Titeloverlay (unten-links) – wird sowohl im Foto- als auch im Platzhalter-Hero verwendet.
    private var heroTitleOverlay: some View {
        LinearGradient(
            colors: [.black.opacity(0.05), .black.opacity(0.78)],
            startPoint: .center,
            endPoint: .bottom
        )
        .overlay(alignment: .bottomLeading) {
            VStack(alignment: .leading, spacing: 8) {
                Text("\(String(localized: "Reisejournal")) · \(cruise.startDate.formatted(.dateTime.month(.wide).year()))")
                    .font(.caption)
                    .fontWeight(.bold)
                    .foregroundStyle(.white.opacity(0.88))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(.white.opacity(0.16))
                    .clipShape(Capsule())

                Text(cruise.title)
                    .font(.title.bold())
                    .foregroundStyle(.white)
                    .lineLimit(2)

                Text(heroMetaLine)
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.82))
                    .lineLimit(1)
            }
            .padding(.horizontal, 18)
            .padding(.bottom, 18)
        }
    }

    private var heroImageSection: some View {
        GeometryReader { proxy in
            ZStack(alignment: .bottomLeading) {
                if !cruise.photos.isEmpty {
                    // Detail-Pager zeigt Vorschaubilder (schnell, speicherschonend);
                    // volle Auflösung gibt es erst beim Antippen in PhotoZoomView.
                    TabView {
                        ForEach(cruise.sortedPhotos) { photo in
                            AsyncPhotoView(imageData: photo.thumbnailData ?? photo.imageData)
                                .frame(width: proxy.size.width, height: proxy.size.height)
                                .clipped()
                                .contentShape(Rectangle())
                                .onTapGesture {
                                    zoomedPhoto = photo
                                }
                        }
                    }
                    .tabViewStyle(.page)
                    .frame(width: proxy.size.width, height: proxy.size.height)
                } else if let assetImage = coverAssetImage {
                    assetImage
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: proxy.size.width, height: proxy.size.height)
                        .clipped()
                } else {
                    CruiseGeoFallbackView(ports: cruise.route)
                        .frame(width: proxy.size.width, height: proxy.size.height)
                        .clipped()
                }

                heroTitleOverlay
                    .frame(width: proxy.size.width, height: proxy.size.height)
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
        }
        .frame(height: 312)
        .clipped()
        .clipShape(RoundedRectangle(cornerRadius: DesignRadius.lg))
        .shadow(color: .black.opacity(0.12), radius: 18, y: 10)
    }

    private var coverAssetImage: Image? {
        ShippingLine.coverAssetCandidates(
            shippingLine: cruise.shippingLine,
            ship: cruise.ship,
            context: coverSelectionContext
        )
        .lazy
        .compactMap { UIImage(named: $0) }
        .first
        .map { Image(uiImage: $0) }
    }

    private var coverSelectionContext: String {
        let routeKey = cruise.route
            .sorted { $0.sortOrder < $1.sortOrder }
            .map { "\($0.name)|\($0.country)" }
            .joined(separator: "::")
        return "\(cruise.id.uuidString)|\(cruise.startDate.timeIntervalSinceReferenceDate)|\(cruise.title)|\(routeKey)"
    }

    /// Eckdaten-Zeile: Tage · Häfen · Länder · Ausgaben
    private var statsSection: some View {
        HStack(spacing: 0) {
            StatCell(
                value: "\(cruise.duration)",
                caption: String(localized: "Tage")
            )
            StatCell(
                value: "\(cruise.route.filter { !$0.isSeaDay }.count)",
                caption: String(localized: "Häfen")
            )
            StatCell(
                value: "\(cruise.countriesVisited.count)",
                caption: String(localized: "Länder")
            )
            StatCell(
                value: cruise.totalExpenses.formattedCurrencyOrNumber,
                caption: String(localized: "Ausgaben"),
                compactValue: true
            )
        }
        .padding(.vertical, 12)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: DesignRadius.lg))
        .shadow(color: .black.opacity(0.08), radius: 14, y: 8)
        .padding(.horizontal, 10)
        .padding(.top, -42)
    }
    
    private var infoSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Rating
            if cruise.rating > 0 {
                HStack {
                    ForEach(1...5, id: \.self) { star in
                        Image(systemName: star <= Int(cruise.rating) ? "star.fill" : "star")
                            .foregroundStyle(.yellow)
                    }
                    Text(String(format: "%.1f", cruise.rating))
                        .foregroundStyle(.secondary)
                }
            }
            
            // Info Cards Grid
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                InfoCard(icon: "ferry", title: "Schiff", value: cruise.ship)
                InfoCard(icon: cruise.shippingLineLogo, title: "Reederei", value: cruise.shippingLine, isEmoji: true)
                InfoCard(icon: "calendar", title: "Zeitraum", value: "\(dateFormatter.string(from: cruise.startDate)) - \(dateFormatter.string(from: cruise.endDate))")
                InfoCard(icon: "clock", title: "Dauer", value: String(localized: "\(cruise.duration) Tage"))
                
                if !cruise.cabinType.isEmpty || !cruise.cabinNumber.isEmpty {
                    let cabinValue = [cruise.cabinType, cruise.cabinNumber]
                        .filter { !$0.isEmpty }
                        .joined(separator: " · ")
                    InfoCard(icon: "bed.double", title: "Kabine", value: cabinValue)
                }
                
                if !cruise.bookingNumber.isEmpty {
                    InfoCard(icon: "number", title: "Buchung", value: cruise.bookingNumber)
                }
            }
        }
    }
    
    /// Route als Tagesfaden mit Journal-Einträgen (Contract J3neu, T8b) –
    /// Klapp-Zustand, Eintragszeilen und Sammelblock liegen in
    /// `RouteJournalSection`.
    private var routeSection: some View {
        RouteJournalSection(
            cruise: cruise,
            onAddPort: { showingAddPortSheet = true },
            onSelectPort: { selectedPort = $0 },
            onDeletePort: { deletePort($0) },
            onOpenEntry: { journalNavigation.openEntry(id: $0) },
            onAddEntry: { journalNavigation.addEntry(at: $0) }
        )
    }

    private var expensesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Ausgaben")
                    .font(.headline)
                Spacer()
                if !cruise.expenses.isEmpty {
                    Text(cruise.totalExpenses.formattedCurrencyOrNumber)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                Button {
                    showingAddExpenseSheet = true
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .foregroundStyle(Color.accentColor)
                }
            }
            
            if cruise.expenses.isEmpty {
                Text("Noch keine Ausgaben erfasst")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 20)
            } else {
                ForEach(ExpenseSorting.sorted(cruise.expenses)) { expense in
                    HStack {
                        Image(systemName: expense.category.icon)
                            .foregroundStyle(.secondary)
                            .frame(width: 24)
                        
                        VStack(alignment: .leading) {
                            Text(expense.category.displayName)
                                .font(.subheadline)
                            if !expense.descriptionText.isEmpty {
                                Text(expense.descriptionText)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        
                        Spacer()
                        
                        Text(expense.formattedAmount)
                            .font(.subheadline)
                            .fontWeight(.medium)
                    }
                    .padding(.vertical, 4)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        selectedExpense = expense
                    }
                    .contextMenu {
                        Button(role: .destructive) {
                            deleteExpense(expense)
                        } label: {
                            Label("Löschen", systemImage: "trash")
                        }
                    }
                }
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: DesignRadius.sm))
    }

    private var notesSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Notizen")
                .font(.headline)
            Text(cruise.notes)
                .font(.body)
                .foregroundStyle(.secondary)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: DesignRadius.sm))
    }
    
    // MARK: - Actions
    
    private func deleteCruise() {
        // ID synchron lesen bevor das Objekt gelöscht wird – kein @Model über Aktorgrenzen
        let cruiseID = ReminderIdentifier.key(for: cruise)
        let succeeded = CruiseDeletionSequence.run(
            delete: { modelContext.delete(cruise) },
            save: { try modelContext.save() },
            rollback: { modelContext.rollback() },
            removeReminders: {
                Task { await NotificationService.shared.removeReminders(cruiseID: cruiseID) }
            },
            onError: { error in
                alertMessage = String(localized: "Löschen fehlgeschlagen: ") + error.localizedDescription
                showingAlert = true
            }
        )
        if succeeded {
            dismiss()
        }
    }
    
    private func deletePort(_ port: Port) {
        // Journal-Lösch-Pfad (T8-Auflage, J2a): hängt die Einträge des Hafens ab
        // und bumpt jeden — SwiftData-Nullify allein täte das nicht.
        let now = Date()
        JournalDeletePaths.deletePort(port, in: modelContext, at: now)
        // Eltern-Kreuzfahrt als geändert markieren (Last-Writer-Wins unter CloudKit)
        cruise.updatedAt = now
    }

    private func deleteExpense(_ expense: Expense) {
        modelContext.delete(expense)
        // Eltern-Kreuzfahrt als geändert markieren (Last-Writer-Wins unter CloudKit)
        cruise.updatedAt = Date()
    }
}

/// Dekodiert Bilddaten abseits des Main-Threads und zeigt Lade-/Fehler-Platzhalter,
/// solange kein Bild verfügbar ist. `Data` wird synchron übergeben – nie eine
/// @Model-Instanz über eine Task-Grenze reichen (siehe ThumbnailBackfill.swift).
/// Wird auch von PortMemoryCard.swift wiederverwendet, daher nicht `private`.
struct AsyncPhotoView: View {
    let imageData: Data
    var contentMode: ContentMode = .fill
    /// Optionale Zielgröße (längste Kante) fürs Downsampling per `ImageDownsampler`
    /// (ImageIO-Thumbnail statt Vollbild-Decode) – schont Speicher bei mehreren Cards
    /// über eine lange Route. `nil` behält das bisherige Verhalten (volle Auflösung)
    /// für bestehende Call-Sites bei (Hero-Pager, PhotoZoomView).
    var maxPixelSize: CGFloat? = nil

    @State private var uiImage: UIImage?
    @State private var didFail = false

    var body: some View {
        Group {
            if let uiImage {
                Image(uiImage: uiImage)
                    .resizable()
                    .aspectRatio(contentMode: contentMode)
            } else {
                Color(.tertiarySystemBackground)
                    .overlay {
                        if didFail {
                            Image(systemName: "photo.badge.exclamationmark")
                                .font(.largeTitle)
                                .foregroundStyle(.secondary)
                        } else {
                            ProgressView()
                        }
                    }
            }
        }
        .task(id: imageData) {
            let data = imageData
            let targetSize = maxPixelSize
            let decoded = await Task.detached(priority: .userInitiated) { () -> UIImage? in
                if let targetSize,
                   let thumbnailData = ImageDownsampler.thumbnail(from: data, maxPixelSize: targetSize),
                   let thumbnail = UIImage(data: thumbnailData) {
                    return thumbnail
                }
                return UIImage(data: data)
            }.value
            if let decoded {
                uiImage = decoded
            } else {
                didFail = true
            }
        }
    }
}

/// Vollbild-Zoomansicht für Kreuzfahrt-Fotos – lädt volle Auflösung (im Gegensatz
/// zum Pager in CruiseDetailView, der nur Vorschaubilder zeigt).
private struct PhotoZoomView: View {
    @Environment(\.dismiss) private var dismiss

    let photos: [Photo]
    @State private var selection: Photo.ID

    init(photos: [Photo], initialPhoto: Photo) {
        self.photos = photos
        _selection = State(initialValue: initialPhoto.id)
    }

    var body: some View {
        ZStack(alignment: .topTrailing) {
            Color.black.ignoresSafeArea()

            TabView(selection: $selection) {
                ForEach(photos) { photo in
                    AsyncPhotoView(imageData: photo.imageData, contentMode: .fit)
                        .tag(photo.id)
                }
            }
            .tabViewStyle(.page)

            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.title2)
                    .foregroundStyle(.white, .black.opacity(0.4))
            }
            .padding()
        }
    }
}

/// Einzelne Zelle in der Eckdaten-Zeile (Tage / Häfen / Länder / Ausgaben)
private struct StatCell: View {
    let value: String
    let caption: String
    var compactValue: Bool = false

    var body: some View {
        VStack(spacing: 2) {
            Text(value)
                .font(compactValue ? .subheadline.bold() : .title3.bold())
                .minimumScaleFactor(0.6)
                .lineLimit(1)
            Text(caption)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}

/// Info-Karte für die Detailansicht
struct InfoCard: View {
    let icon: String
    /// Lokalisierbar: `String` würde `Text(title)` unübersetzt durchreichen.
    let title: LocalizedStringKey
    let value: String
    var isEmoji: Bool = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 4) {
                if isEmoji {
                    Text(icon)
                } else {
                    Image(systemName: icon)
                        .foregroundStyle(.secondary)
                }
                Text(title)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Text(value)
                .font(.subheadline)
                .fontWeight(.medium)
                .lineLimit(2)
                .minimumScaleFactor(0.8)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: DesignRadius.sm))
    }
}

#Preview {
    NavigationStack {
        CruiseDetailView(cruise: Cruise(
            title: "Mittelmeer Kreuzfahrt",
            startDate: Date(),
            endDate: Date().addingTimeInterval(7 * 24 * 60 * 60),
            shippingLine: "TUI Cruises - Mein Schiff",
            ship: "Mein Schiff 4"
        ))
    }
    .modelContainer(for: [Cruise.self, Port.self, Expense.self], inMemory: true)
}
