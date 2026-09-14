//
//  CalendarSyncSettingsView.swift
//  ShipTrip
//
//  Created by ShipTrip on 02.09.26.
//

import SwiftUI
import SwiftData
import EventKit
import UIKit

@MainActor
struct CalendarSyncOperationState {
    enum Phase: Equatable {
        case idle
        case running
    }

    private(set) var phase: Phase = .idle

    var isWorking: Bool {
        phase == .running
    }

    mutating func begin() -> Bool {
        guard phase == .idle else { return false }
        phase = .running
        return true
    }

    mutating func finish() {
        phase = .idle
    }
}

/// Ob die beiden Umfangs-Schalter bedienbar sind.
///
/// Ein Tipp schreibt `calendarSyncMode`; `CalendarSyncModeMigration` wertet
/// einen gesetzten Schlüssel danach als bewusste Wahl. Vor der entschiedenen
/// Bestands-Migration gäbe ein Tipp deshalb den Ganzreise-Termin eines
/// Bestandsnutzers stillschweigend zur Löschung frei.
@MainActor
struct CalendarScopeAvailability: Equatable {
    /// Ob die Bestands-Migration entschieden hat.
    var isMigrationSettled: Bool
    /// Ohne vollen Kalenderzugriff lässt sich der Bestand nicht prüfen, die
    /// Migration bleibt offen.
    var hasCalendarAccess: Bool
    /// Ein laufender Sync sperrt die Schalter wie bisher.
    var isWorking: Bool

    var isEditable: Bool {
        isMigrationSettled && !isWorking
    }

    /// Warum gesperrt wird, solange die Migration offen ist: Ohne
    /// Kalenderzugriff bleibt der Bestand ungeprüft, und der Umfang darf
    /// nicht blind festgeschrieben werden.
    var lockedHint: String? {
        guard !isMigrationSettled, !hasCalendarAccess else { return nil }
        return String(
            localized: "Der Umfang lässt sich ändern, sobald der Kalenderzugriff erteilt ist."
        )
    }
}

/// Optionale Spiegelung aller Reisen in einen auswählbaren Systemkalender.
struct CalendarSyncSettingsView: View {
    @Query(sort: \Cruise.startDate) private var cruises: [Cruise]
    @AppStorage(CalendarSyncPreferences.enabledKey) private var isEnabled = false
    @AppStorage(CalendarSyncPreferences.calendarIdentifierKey) private var calendarIdentifier = ""
    /// Nur Auslöser für die Neuberechnung, kein Leseort des Defaults: Der
    /// Default steht ausschließlich in `CalendarSyncPreferences.mode(in:)`,
    /// hier bedeutet der leere Wert schlicht „noch nichts gespeichert".
    @AppStorage(CalendarSyncPreferences.modeKey) private var modeRawValue = ""

    @State private var calendars: [WritableCalendar] = []
    @State private var operationState = CalendarSyncOperationState()
    @State private var statusMessage = ""
    @State private var showingAccessAlert = false
    @State private var showingRollbackAlert = false
    @State private var pendingCalendarIdentifier: String?
    @State private var isScopeMigrationSettled = CalendarSyncModeMigration.isSettled(in: .standard)
    @State private var hasCalendarAccess = false

    private var isWorking: Bool {
        operationState.isWorking
    }

    private var scopeAvailability: CalendarScopeAvailability {
        CalendarScopeAvailability(
            isMigrationSettled: isScopeMigrationSettled,
            hasCalendarAccess: hasCalendarAccess,
            isWorking: isWorking
        )
    }

    /// Der Picker schreibt die Auswahl erst nach einer eventuell nötigen
    /// Bestätigung fort. Bis dahin bleibt der bisherige Kalender aktiv, damit
    /// vor dem Umzug nichts in einen Kalender geschrieben wird.
    private var calendarSelection: Binding<String> {
        Binding(
            get: { calendarIdentifier },
            set: { requestCalendarChange(to: $0) }
        )
    }

    private var isConfirmingMigration: Binding<Bool> {
        Binding(
            get: { pendingCalendarIdentifier != nil },
            set: { if !$0 { pendingCalendarIdentifier = nil } }
        )
    }

    /// Der wirksame Umfang. Fällt der gespeicherte Wert aus, entscheidet
    /// `CalendarSyncPreferences` — der einzige Ort des Defaults.
    private var mode: CalendarSyncMode {
        CalendarSyncMode(rawValue: modeRawValue) ?? CalendarSyncPreferences.mode
    }

    private var itineraryScope: Binding<Bool> {
        Binding(
            get: { mode.includesItinerary },
            set: { apply(itinerary: $0, trip: mode.includesTrip) }
        )
    }

    private var tripScope: Binding<Bool> {
        Binding(
            get: { mode.includesTrip },
            set: { apply(itinerary: mode.includesItinerary, trip: $0) }
        )
    }

    /// Die beiden Schalter bilden zusammen die vier Umfangs-Fälle ab.
    private func apply(itinerary: Bool, trip: Bool) {
        let newMode: CalendarSyncMode = switch (itinerary, trip) {
        case (true, true): .tripAndItinerary
        case (true, false): .itineraryOnly
        case (false, true): .tripOnly
        case (false, false): .none
        }
        modeRawValue = newMode.rawValue
        synchronizeIfEnabled()
    }

    var body: some View {
        Form {
            Section {
                Toggle(
                    "Reisen mit Kalender synchronisieren",
                    isOn: Binding(
                        get: { isEnabled },
                        set: { newValue in
                            startUpdatingEnabled(newValue)
                        }
                    )
                )
                .disabled(isWorking)

                if isWorking {
                    HStack {
                        ProgressView()
                        Text("Kalender wird aktualisiert …")
                            .foregroundStyle(.secondary)
                    }
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel(Text("Kalender wird aktualisiert …"))
                    .accessibilityIdentifier("calendarSyncProgress")
                } else if !statusMessage.isEmpty {
                    Text(statusMessage)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            } footer: {
                Text("ShipTrip aktualisiert angelegte Termine automatisch und entfernt sie wieder, wenn eine Reise gelöscht oder die Synchronisation deaktiviert wird.")
            }

            Section("Zielkalender") {
                if calendars.isEmpty {
                    Text("Kein beschreibbarer Kalender verfügbar")
                        .foregroundStyle(.secondary)
                } else {
                    Picker("Kalender", selection: calendarSelection) {
                        ForEach(calendars) { calendar in
                            Text(calendar.displayName).tag(calendar.id)
                        }
                    }
                    .disabled(!isEnabled || isWorking)
                }
            }

            Section {
                Toggle("Stopps eintragen", isOn: itineraryScope)
                    .accessibilityIdentifier("calendarSync.itineraryToggle")
                    .disabled(!scopeAvailability.isEditable)

                Toggle("Gesamte Reise als Eintrag", isOn: tripScope)
                    .accessibilityIdentifier("calendarSync.tripToggle")
                    .disabled(!scopeAvailability.isEditable)

                if mode == .none {
                    Text("Es werden keine Einträge angelegt.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            } header: {
                Text("Umfang")
            } footer: {
                if let hint = scopeAvailability.lockedHint {
                    Text(hint)
                } else {
                    Text("Standardmäßig werden nur die einzelnen Stopps eingetragen. Die gesamte Reise als ganztägiger Eintrag ist optional.")
                }
            }

            if isEnabled {
                Section {
                    Button("Jetzt synchronisieren") {
                        synchronizeIfEnabled()
                    }
                    .disabled(isWorking)
                }
            }
        }
        .navigationTitle("Kalender")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await refreshCalendars()
        }
        .alert("Kalenderzugriff erforderlich", isPresented: $showingAccessAlert) {
            Button("Abbrechen", role: .cancel) { }
            Button("Einstellungen öffnen") {
                guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
                UIApplication.shared.open(url)
            }
        } message: {
            Text("Erlaube ShipTrip den vollständigen Kalenderzugriff, damit du einen Zielkalender auswählen und bestehende ShipTrip-Termine aktualisieren kannst.")
        }
        .alert(
            "Termine in den neuen Kalender übertragen?",
            isPresented: isConfirmingMigration,
            presenting: pendingCalendarIdentifier
        ) { identifier in
            Button("Abbrechen", role: .cancel) {
                pendingCalendarIdentifier = nil
            }
            Button("Übertragen") {
                startMigration(to: identifier)
            }
        } message: { _ in
            Text("Alle bestehenden ShipTrip-Termine werden im neuen Kalender angelegt und im bisherigen Kalender gelöscht.")
        }
        .alert(
            String(localized: "Termine nicht wiederhergestellt"),
            isPresented: $showingRollbackAlert
        ) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(String(localized: "Der Umzug ist fehlgeschlagen und die Termine im bisherigen Kalender ließen sich nicht wiederherstellen. Prüfe deinen Kalender und synchronisiere danach erneut."))
        }
    }

    // MARK: - Zielkalender wechseln

    private func requestCalendarChange(to identifier: String) {
        switch CalendarTargetChangePlanner.decide(
            current: calendarIdentifier,
            selected: identifier,
            isSyncEnabled: isEnabled,
            hasManagedEvents: CalendarSyncService.shared.hasManagedEvents
        ) {
        case .ignore:
            break
        case .apply:
            calendarIdentifier = identifier
            synchronizeIfEnabled()
        case .confirmMigration:
            pendingCalendarIdentifier = identifier
        }
    }

    private func startMigration(to identifier: String) {
        pendingCalendarIdentifier = nil
        guard operationState.begin() else { return }
        Task { @MainActor in
            await Task.yield()
            migrateNow(to: identifier)
        }
    }

    private func migrateNow(to identifier: String) {
        defer { operationState.finish() }

        switch CalendarMigrationCoordinator().migrate(to: identifier, cruises: cruises) {
        case .migrated(let count):
            statusMessage = String(localized: "\(count) Kalendereinträge in den neuen Kalender übertragen.")
        case .accessDenied:
            isEnabled = false
            showingAccessAlert = true
        case .rolledBack(let error):
            statusMessage = error.localizedDescription
        case .rollbackFailed(let migrationError, _):
            statusMessage = migrationError.localizedDescription
            showingRollbackAlert = true
        }
    }

    private func refreshCalendars() async {
        hasCalendarAccess = CalendarSyncService.shared.authorizationStatus == .fullAccess
        guard hasCalendarAccess else {
            calendars = []
            return
        }
        // Bis die Bestands-Migration entschieden hat, sperrt
        // `scopeAvailability` die Umfangs-Schalter — sonst schriebe ein Tipp
        // den Mode-Key, den die Migration danach als bewusste Wahl liest.
        // `hasManagedEvents` ist der vorhandene Auslöser; die Vorabfrage
        // spart den Termin-Scan, sobald die Entscheidung gefallen ist.
        if !isScopeMigrationSettled {
            _ = CalendarSyncService.shared.hasManagedEvents
            isScopeMigrationSettled = CalendarSyncModeMigration.isSettled(in: .standard)
        }
        calendars = CalendarSyncService.shared.writableCalendars()
        calendarIdentifier = CalendarSyncService.shared.selectDefaultCalendarIfNeeded() ?? ""
        if isEnabled {
            synchronizeIfEnabled()
        }
    }

    private func startUpdatingEnabled(_ newValue: Bool) {
        guard operationState.begin() else { return }
        Task { @MainActor in
            await Task.yield()
            await updateEnabled(newValue)
        }
    }

    private func updateEnabled(_ newValue: Bool) async {
        defer { operationState.finish() }

        guard newValue else {
            isEnabled = false
            do {
                try CalendarSyncService.shared.removeAllManagedEvents()
                statusMessage = String(localized: "ShipTrip-Termine wurden entfernt.")
            } catch CalendarSyncError.accessDenied {
                isEnabled = false
                statusMessage = String(localized: "Die Synchronisation ist aus. Erlaube Kalenderzugriff erneut, um vorhandene ShipTrip-Termine zu entfernen.")
                showingAccessAlert = true
            } catch {
                isEnabled = true
                statusMessage = error.localizedDescription
            }
            return
        }

        guard await CalendarSyncService.shared.requestAccess() else {
            isEnabled = false
            showingAccessAlert = true
            return
        }

        calendars = CalendarSyncService.shared.writableCalendars()
        guard let selectedIdentifier = CalendarSyncService.shared.selectDefaultCalendarIfNeeded() else {
            isEnabled = false
            statusMessage = String(localized: "Kein beschreibbarer Kalender verfügbar.")
            return
        }

        calendarIdentifier = selectedIdentifier
        isEnabled = true
        performSynchronization()
        // Der Zugriff kann erst hier erteilt worden sein — `.task` laeuft nur
        // einmal beim Erscheinen. Der Sync hat die Bestands-Migration
        // mitgenommen, also beide Sperr-Gruende neu einlesen; sonst blieben
        // die Umfangs-Schalter fuer den Rest der Sitzung grau.
        hasCalendarAccess = CalendarSyncService.shared.authorizationStatus == .fullAccess
        isScopeMigrationSettled = CalendarSyncModeMigration.isSettled(in: .standard)
    }

    private func synchronizeIfEnabled() {
        guard isEnabled, operationState.begin() else { return }
        Task { @MainActor in
            await Task.yield()
            synchronizeNow()
        }
    }

    private func synchronizeNow() {
        defer { operationState.finish() }
        performSynchronization()
    }

    private func performSynchronization() {
        do {
            let count = try CalendarSyncService.shared.synchronize(cruises: cruises)
            statusMessage = String(localized: "\(count) Kalendereinträge synchronisiert.")
        } catch CalendarSyncError.accessDenied {
            isEnabled = false
            showingAccessAlert = true
        } catch {
            statusMessage = error.localizedDescription
        }
    }
}
