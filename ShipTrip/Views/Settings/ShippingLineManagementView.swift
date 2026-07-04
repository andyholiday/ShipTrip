//
//  ShippingLineManagementView.swift
//  ShipTrip
//
//  Created by ShipTrip on 04.07.26.
//

import SwiftUI
import SwiftData

/// Verwaltung eigener Reedereien/Schiffe sowie Ausblenden einzelner Katalog-Einträge
/// (Welle B5, ADR-006). Baut ausschließlich gegen die in ADR-006 Abschnitt 4 fixierten
/// DTOs/Service-Funktionen – keine eigene Merge-/Kollisions-Logik.
struct ShippingLineManagementView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var customLines: [CustomShippingLine]
    @Query private var hidden: [HiddenCatalogItem]

    @State private var showingAddLineSheet = false
    @State private var editingCustomLine: CustomShippingLine?
    @State private var deletingCustomLine: CustomShippingLine?
    @State private var actionErrorMessage: String?

    var body: some View {
        List {
            Section {
                Button {
                    showingAddLineSheet = true
                } label: {
                    Label("Eigene Reederei anlegen", systemImage: "plus.circle")
                }
            }

            if !customLines.isEmpty {
                Section(String(localized: "Eigene Reedereien")) {
                    ForEach(customLines.sorted { $0.name < $1.name }) { line in
                        NavigationLink {
                            ShipManagementView(lineOptionID: "custom:\(line.id.uuidString)", lineName: line.name)
                        } label: {
                            Text("\(line.logo) \(line.name)")
                        }
                        .swipeActions {
                            Button(role: .destructive) {
                                deletingCustomLine = line
                            } label: {
                                Label("Löschen", systemImage: "trash")
                            }
                            Button {
                                editingCustomLine = line
                            } label: {
                                Label("Bearbeiten", systemImage: "pencil")
                            }
                            .tint(.blue)
                        }
                    }
                }
            }

            Section(String(localized: "Katalog-Reedereien")) {
                ForEach(ShippingLine.all.sorted { $0.name < $1.name }) { line in
                    NavigationLink {
                        ShipManagementView(lineOptionID: line.id, lineName: line.name)
                    } label: {
                        HStack {
                            Text("\(line.logo) \(line.name)")
                            Spacer()
                            if isLineHidden(line) {
                                Text("Ausgeblendet")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                    .swipeActions {
                        Button {
                            toggleLineHidden(line)
                        } label: {
                            Label(
                                isLineHidden(line) ? String(localized: "Einblenden") : String(localized: "Ausblenden"),
                                systemImage: isLineHidden(line) ? "eye" : "eye.slash"
                            )
                        }
                        .tint(isLineHidden(line) ? .blue : .orange)
                    }
                }
            }
        }
        .navigationTitle("Reedereien & Schiffe")
        .sheet(isPresented: $showingAddLineSheet) {
            CustomLineFormSheet(customLine: nil)
        }
        .sheet(item: $editingCustomLine) { line in
            CustomLineFormSheet(customLine: line)
        }
        .alert(
            "Reederei löschen?",
            isPresented: Binding(
                get: { deletingCustomLine != nil },
                set: { if !$0 { deletingCustomLine = nil } }
            )
        ) {
            Button("Abbrechen", role: .cancel) { deletingCustomLine = nil }
            Button("Löschen", role: .destructive) {
                if let line = deletingCustomLine {
                    do {
                        try ShippingLineCatalogService.deleteCustomLine(line.id, in: modelContext)
                    } catch {
                        actionErrorMessage = String(localized: "Löschen fehlgeschlagen: ") + error.localizedDescription
                    }
                }
                deletingCustomLine = nil
            }
        } message: {
            Text("Bestehende Reisen mit dieser Reederei bleiben unverändert erhalten. Zugehörige eigene Schiffe werden mitgelöscht.")
        }
        .alert(
            "Fehler",
            isPresented: Binding(
                get: { actionErrorMessage != nil },
                set: { if !$0 { actionErrorMessage = nil } }
            )
        ) {
            Button("OK", role: .cancel) { actionErrorMessage = nil }
        } message: {
            Text(actionErrorMessage ?? "")
        }
    }

    private func isLineHidden(_ line: ShippingLine) -> Bool {
        hidden.contains { $0.lineID == line.id && $0.shipKey == nil }
    }

    private func toggleLineHidden(_ line: ShippingLine) {
        do {
            if isLineHidden(line) {
                try ShippingLineCatalogService.unhideCatalogLine(lineID: line.id, in: modelContext)
            } else {
                try ShippingLineCatalogService.hideCatalogLine(lineID: line.id, in: modelContext)
            }
        } catch {
            actionErrorMessage = String(localized: "Aktion fehlgeschlagen: ") + error.localizedDescription
        }
    }
}

/// Anlegen/Bearbeiten einer eigenen Reederei.
private struct CustomLineFormSheet: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    let customLine: CustomShippingLine?

    @State private var name = ""
    @State private var logo = "🚢"
    @State private var errorMessage: String?

    private var isEditing: Bool { customLine != nil }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Name", text: $name)
                    TextField(String(localized: "Logo (Emoji)"), text: $logo)
                }

                if let errorMessage {
                    Section {
                        Text(errorMessage)
                            .foregroundStyle(.red)
                    }
                }
            }
            .navigationTitle(isEditing ? String(localized: "Reederei bearbeiten") : String(localized: "Eigene Reederei"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Abbrechen") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Speichern") { save() }
                        .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .onAppear {
                if let customLine {
                    name = customLine.name
                    logo = customLine.logo
                }
            }
        }
    }

    private func save() {
        let trimmedLogo = logo.trimmingCharacters(in: .whitespacesAndNewlines)
        let finalLogo = trimmedLogo.isEmpty ? "🚢" : trimmedLogo

        do {
            if let customLine {
                try ShippingLineCatalogService.updateCustomLine(customLine.id, name: name, logo: finalLogo, in: modelContext)
            } else {
                _ = try ShippingLineCatalogService.createCustomLine(name: name, logo: finalLogo, in: modelContext)
            }
            dismiss()
        } catch ShippingLineCatalogError.duplicateLineName {
            errorMessage = String(localized: "Diese Reederei ist bereits vorhanden — bitte den bestehenden Eintrag verwenden.")
        } catch {
            errorMessage = String(localized: "Speichern fehlgeschlagen: ") + error.localizedDescription
        }
    }
}

/// Schiffsverwaltung für eine einzelne Reederei (Katalog oder eigene): Katalog-Schiffe
/// (aktiv + historisch) können aus-/eingeblendet, eigene Schiffe angelegt/bearbeitet/
/// gelöscht werden.
struct ShipManagementView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var customShips: [CustomShip]
    @Query private var hidden: [HiddenCatalogItem]

    let lineOptionID: String
    let lineName: String

    @State private var showingAddShipSheet = false
    @State private var editingCustomShip: CustomShip?
    @State private var deletingCustomShip: CustomShip?
    @State private var actionErrorMessage: String?

    init(lineOptionID: String, lineName: String) {
        self.lineOptionID = lineOptionID
        self.lineName = lineName
        _customShips = Query(
            filter: #Predicate<CustomShip> { ship in
                ship.lineOptionID == lineOptionID
            },
            sort: \CustomShip.name
        )
    }

    private var catalogLine: ShippingLine? { ShippingLine.find(byId: lineOptionID) }

    var body: some View {
        List {
            Section {
                Button {
                    showingAddShipSheet = true
                } label: {
                    Label("Eigenes Schiff hinzufügen", systemImage: "plus.circle")
                }
            }

            if !customShips.isEmpty {
                Section(String(localized: "Eigene Schiffe")) {
                    ForEach(customShips) { ship in
                        Text(ship.name)
                            .swipeActions {
                                Button(role: .destructive) {
                                    deletingCustomShip = ship
                                } label: {
                                    Label("Löschen", systemImage: "trash")
                                }
                                Button {
                                    editingCustomShip = ship
                                } label: {
                                    Label("Bearbeiten", systemImage: "pencil")
                                }
                                .tint(.blue)
                            }
                    }
                }
            }

            if let catalogLine {
                if !catalogLine.ships.isEmpty {
                    Section(String(localized: "Aktive Schiffe (Katalog)")) {
                        ForEach(catalogLine.ships, id: \.self) { shipName in
                            catalogShipRow(shipName)
                        }
                    }
                }

                if !catalogLine.historicalShips.isEmpty {
                    Section(String(localized: "Historische Schiffe (Katalog)")) {
                        ForEach(catalogLine.historicalShips, id: \.self) { shipName in
                            catalogShipRow(shipName)
                        }
                    }
                }
            }
        }
        .navigationTitle(lineName)
        .sheet(isPresented: $showingAddShipSheet) {
            CustomShipFormSheet(customShip: nil, lineOptionID: lineOptionID)
        }
        .sheet(item: $editingCustomShip) { ship in
            CustomShipFormSheet(customShip: ship, lineOptionID: lineOptionID)
        }
        .alert(
            "Schiff löschen?",
            isPresented: Binding(
                get: { deletingCustomShip != nil },
                set: { if !$0 { deletingCustomShip = nil } }
            )
        ) {
            Button("Abbrechen", role: .cancel) { deletingCustomShip = nil }
            Button("Löschen", role: .destructive) {
                if let ship = deletingCustomShip {
                    do {
                        try ShippingLineCatalogService.deleteCustomShip(ship.id, in: modelContext)
                    } catch {
                        actionErrorMessage = String(localized: "Löschen fehlgeschlagen: ") + error.localizedDescription
                    }
                }
                deletingCustomShip = nil
            }
        } message: {
            Text("Bestehende Reisen mit diesem Schiff bleiben unverändert erhalten.")
        }
        .alert(
            "Fehler",
            isPresented: Binding(
                get: { actionErrorMessage != nil },
                set: { if !$0 { actionErrorMessage = nil } }
            )
        ) {
            Button("OK", role: .cancel) { actionErrorMessage = nil }
        } message: {
            Text(actionErrorMessage ?? "")
        }
    }

    @ViewBuilder
    private func catalogShipRow(_ shipName: String) -> some View {
        let hiddenNow = isShipHidden(shipName)
        HStack {
            Text(shipName)
            Spacer()
            if hiddenNow {
                Text("Ausgeblendet")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .swipeActions {
            Button {
                toggleShipHidden(shipName)
            } label: {
                Label(
                    hiddenNow ? String(localized: "Einblenden") : String(localized: "Ausblenden"),
                    systemImage: hiddenNow ? "eye" : "eye.slash"
                )
            }
            .tint(hiddenNow ? .blue : .orange)
        }
    }

    private func isShipHidden(_ shipName: String) -> Bool {
        let key = ShippingLine.normalizedShipKey(shipName)
        return hidden.contains { $0.lineID == lineOptionID && $0.shipKey == key }
    }

    private func toggleShipHidden(_ shipName: String) {
        do {
            if isShipHidden(shipName) {
                try ShippingLineCatalogService.unhideCatalogShip(lineID: lineOptionID, shipName: shipName, in: modelContext)
            } else {
                try ShippingLineCatalogService.hideCatalogShip(lineID: lineOptionID, shipName: shipName, in: modelContext)
            }
        } catch {
            actionErrorMessage = String(localized: "Aktion fehlgeschlagen: ") + error.localizedDescription
        }
    }
}

/// Anlegen/Bearbeiten eines eigenen Schiffs für eine Reederei (Katalog oder eigene).
private struct CustomShipFormSheet: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    let customShip: CustomShip?
    let lineOptionID: String

    @State private var name = ""
    @State private var errorMessage: String?

    private var isEditing: Bool { customShip != nil }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Schiffsname", text: $name)
                }

                if let errorMessage {
                    Section {
                        Text(errorMessage)
                            .foregroundStyle(.red)
                    }
                }
            }
            .navigationTitle(isEditing ? String(localized: "Schiff bearbeiten") : String(localized: "Eigenes Schiff"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Abbrechen") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Speichern") { save() }
                        .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .onAppear {
                if let customShip {
                    name = customShip.name
                }
            }
        }
    }

    private func save() {
        do {
            if let customShip {
                try ShippingLineCatalogService.updateCustomShip(customShip.id, name: name, in: modelContext)
            } else {
                _ = try ShippingLineCatalogService.createCustomShip(name: name, lineOptionID: lineOptionID, in: modelContext)
            }
            dismiss()
        } catch ShippingLineCatalogError.duplicateShipName {
            errorMessage = String(localized: "Dieses Schiff ist bei dieser Reederei bereits vorhanden.")
        } catch {
            errorMessage = String(localized: "Speichern fehlgeschlagen: ") + error.localizedDescription
        }
    }
}

#Preview {
    NavigationStack {
        ShippingLineManagementView()
    }
    .modelContainer(for: [CustomShippingLine.self, CustomShip.self, HiddenCatalogItem.self], inMemory: true)
}
