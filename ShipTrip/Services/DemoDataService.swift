//
//  DemoDataService.swift
//  ShipTrip
//
//  Nur in Debug-Builds vorhanden. In Release-Builds wird diese Datei
//  vollständig wegkompiliert.
//

#if DEBUG
import SwiftData
import Foundation

/// Verwaltet realistische Demo-Daten für manuelle Tests.
/// Alle Aktionen sind idempotent.
enum DemoDataService {

    // MARK: - Public API

    /// Legt Demo-Kreuzfahrten und -Angebote an, falls noch keine vorhanden sind.
    static func loadDemoData(into context: ModelContext) {
        guard !hasDemoData(in: context) else { return }

        insertCruises(into: context)
        insertDeals(into: context)
        try? context.save()
    }

    /// Löscht alle Objekte mit isDemo == true (Ports/Expenses/Photos via Cascade).
    static func removeDemoData(from context: ModelContext) {
        let demoCruises = fetch(Cruise.self, where: \.isDemo, in: context)
        demoCruises.forEach { context.delete($0) }

        let demoDeals = fetch(Deal.self, where: \.isDemo, in: context)
        demoDeals.forEach { context.delete($0) }

        try? context.save()
    }

    /// True wenn mindestens eine Demo-Kreuzfahrt oder ein Demo-Angebot vorhanden ist.
    static func hasDemoData(in context: ModelContext) -> Bool {
        !fetch(Cruise.self, where: \.isDemo, in: context).isEmpty ||
        !fetch(Deal.self, where: \.isDemo, in: context).isEmpty
    }

    // MARK: - Private Helpers

    private static func fetch<T: PersistentModel>(
        _ type: T.Type,
        where keyPath: KeyPath<T, Bool>,
        in context: ModelContext
    ) -> [T] {
        let descriptor = FetchDescriptor<T>()
        let all = (try? context.fetch(descriptor)) ?? []
        return all.filter { $0[keyPath: keyPath] }
    }

    // MARK: - Demo-Kreuzfahrten

    private static func insertCruises(into context: ModelContext) {
        insertMittelmeer(into: context)
        insertNorwegen(into: context)
        insertKaribik(into: context)
    }

    // Vergangene Kreuzfahrt – sorgt dafür, dass Statistiken befüllt sind
    private static func insertMittelmeer(into context: ModelContext) {
        let calendar = Calendar.current
        let start = calendar.date(from: DateComponents(year: 2025, month: 6, day: 10))!
        let end   = calendar.date(from: DateComponents(year: 2025, month: 6, day: 17))!

        let cruise = Cruise(
            title: "Westliches Mittelmeer 2025",
            startDate: start,
            endDate: end,
            shippingLine: "TUI Cruises - Mein Schiff",
            ship: "Mein Schiff 6"
        )
        cruise.cabinType = "Balkonkabine"
        cruise.cabinNumber = "8042"
        cruise.bookingNumber = "DEMO-001"
        cruise.rating = 4.5
        cruise.notes = "Fantastische Reise! Rom war ein absolutes Highlight."
        cruise.isDemo = true
        context.insert(cruise)

        // Route
        let ports: [(String, String, Int, Bool)] = [
            ("Barcelona",     "Spanien",    0, false),
            ("Marseille",     "Frankreich", 1, false),
            ("Genua",         "Italien",    2, false),
            ("Civitavecchia", "Italien",    3, false),
            ("Neapel",        "Italien",    4, false),
            ("Seetag",        "–",          5, true),
            ("Palma",         "Spanien",    6, false),
        ]
        addPorts(ports, to: cruise, startDate: start, context: context)

        // Ausgaben
        addExpense(cruise: cruise, category: .cruise, amount: 1_890.00,
                   description: "Kreuzfahrtbuchung Kabine 8042", daysOffset: -30, context: context)
        addExpense(cruise: cruise, category: .excursion, amount: 85.00,
                   description: "Kolosseum & Forum Romanum Tour", daysOffset: 3, context: context)
        addExpense(cruise: cruise, category: .onboard, amount: 124.50,
                   description: "Spa & Getränkepaket", daysOffset: 1, context: context)
    }

    // Laufende / bald startende Kreuzfahrt – zeigt „Upcoming" Logik
    private static func insertNorwegen(into context: ModelContext) {
        let calendar = Calendar.current
        // startet in 3 Wochen
        let start = calendar.date(byAdding: .day, value: 21, to: Date())!
        let end   = calendar.date(byAdding: .day, value: 29, to: Date())!

        let cruise = Cruise(
            title: "Norwegische Fjorde",
            startDate: start,
            endDate: end,
            shippingLine: "AIDA Cruises",
            ship: "AIDAnova"
        )
        cruise.cabinType = "Meerblick"
        cruise.bookingNumber = "DEMO-002"
        cruise.rating = 0 // noch nicht bewertet
        cruise.notes = "Sehr gespannt auf Geiranger!"
        cruise.isDemo = true
        context.insert(cruise)

        let ports: [(String, String, Int, Bool)] = [
            ("Kiel",       "Deutschland", 0, false),
            ("Seetag",     "–",           1, true),
            ("Bergen",     "Norwegen",    2, false),
            ("Geiranger",  "Norwegen",    3, false),
            ("Stavanger",  "Norwegen",    4, false),
            ("Kopenhagen", "Dänemark",    5, false),
            ("Seetag",     "–",           6, true),
        ]
        addPorts(ports, to: cruise, startDate: start, context: context)

        addExpense(cruise: cruise, category: .cruise, amount: 2_340.00,
                   description: "Kreuzfahrtbuchung – Fjorde Reise", daysOffset: -60, context: context)
        addExpense(cruise: cruise, category: .flight, amount: 198.00,
                   description: "Flug Hamburg → Kiel (Transfer)", daysOffset: -30, context: context)
    }

    // Vergangene Kurzkreuzfahrt Karibik – für Statistik-Vielfalt
    private static func insertKaribik(into context: ModelContext) {
        let calendar = Calendar.current
        let start = calendar.date(from: DateComponents(year: 2025, month: 2, day: 15))!
        let end   = calendar.date(from: DateComponents(year: 2025, month: 2, day: 25))!

        let cruise = Cruise(
            title: "Karibik Highlights 2025",
            startDate: start,
            endDate: end,
            shippingLine: "MSC Cruises",
            ship: "MSC Seaside"
        )
        cruise.cabinType = "Suite"
        cruise.bookingNumber = "DEMO-003"
        cruise.rating = 5.0
        cruise.notes = "Absolut traumhaft – unbedingt wiederholen!"
        cruise.isDemo = true
        context.insert(cruise)

        let ports: [(String, String, Int, Bool)] = [
            ("Miami",       "USA",            0, false),
            ("Seetag",      "–",              1, true),
            ("Cozumel",     "Mexiko",         2, false),
            ("Oranjestad",  "Aruba",          3, false),
            ("Bridgetown",  "Barbados",       4, false),
            ("Seetag",      "–",              5, true),
            ("Nassau",      "Bahamas",        6, false),
        ]
        addPorts(ports, to: cruise, startDate: start, context: context)

        addExpense(cruise: cruise, category: .cruise, amount: 3_150.00,
                   description: "Suite Buchung MSC Seaside", daysOffset: -90, context: context)
        addExpense(cruise: cruise, category: .excursion, amount: 110.00,
                   description: "Schnorcheln Cozumel", daysOffset: 2, context: context)
        addExpense(cruise: cruise, category: .hotel, amount: 220.00,
                   description: "Hotel Miami (Vorabend)", daysOffset: -1, context: context)
        addExpense(cruise: cruise, category: .onboard, amount: 345.00,
                   description: "Getränkepaket + Dinner-Upgrade", daysOffset: 0, context: context)
    }

    // MARK: - Demo-Angebote

    private static func insertDeals(into context: ModelContext) {
        let calendar = Calendar.current

        let deal1 = Deal(title: "Mittelmeer Frühbucher – Mein Schiff 5")
        deal1.shippingLine = "TUI Cruises - Mein Schiff"
        deal1.ship = "Mein Schiff 5"
        deal1.price = 1_199.00
        deal1.originalPrice = 1_699.00
        deal1.destination = "Westliches Mittelmeer"
        deal1.startDate = calendar.date(from: DateComponents(year: 2026, month: 5, day: 1))
        deal1.endDate   = calendar.date(from: DateComponents(year: 2026, month: 5, day: 8))
        deal1.notes = "Frühbucher-Rabatt gültig bis 31.01.2026"
        deal1.url = "https://www.tuicruises.com"
        deal1.isDemo = true
        context.insert(deal1)

        let deal2 = Deal(title: "Kanaren-Kreuzfahrt – AIDAcosma")
        deal2.shippingLine = "AIDA Cruises"
        deal2.ship = "AIDAcosma"
        deal2.price = 899.00
        deal2.originalPrice = 1_099.00
        deal2.destination = "Kanarische Inseln"
        deal2.startDate = calendar.date(from: DateComponents(year: 2026, month: 1, day: 10))
        deal2.endDate   = calendar.date(from: DateComponents(year: 2026, month: 1, day: 17))
        deal2.notes = "Innenkabine, All Inclusive. Verfügbarkeit begrenzt."
        deal2.url = "https://www.aida.de"
        deal2.isDemo = true
        context.insert(deal2)
    }

    // MARK: - Hilfsmethoden

    private static func addPorts(
        _ entries: [(name: String, country: String, offset: Int, isSeaDay: Bool)],
        to cruise: Cruise,
        startDate: Date,
        context: ModelContext
    ) {
        let calendar = Calendar.current
        for (name, country, offset, isSeaDay) in entries {
            let portDate = calendar.date(byAdding: .day, value: offset, to: startDate) ?? startDate
            let arrival  = portDate
            let departure = calendar.date(byAdding: .hour, value: 10, to: portDate) ?? portDate

            let match = isSeaDay
                ? nil
                : PortSuggestion.findBestMatch(name: name, country: country)

            let lat = match?.latitude  ?? 0.0
            let lon = match?.longitude ?? 0.0

            let port = Port(
                name: isSeaDay ? "Seetag" : name,
                country: isSeaDay ? "" : country,
                latitude: lat,
                longitude: lon
            )
            port.arrival    = arrival
            port.departure  = departure
            port.sortOrder  = offset
            port.isSeaDay   = isSeaDay
            port.cruise     = cruise
            context.insert(port)
            cruise.route.append(port)
        }
    }

    private static func addExpense(
        cruise: Cruise,
        category: ExpenseCategory,
        amount: Double,
        description: String,
        daysOffset: Int,
        context: ModelContext
    ) {
        let expense = Expense(category: category, amount: amount, description: description)
        expense.expenseDate = Calendar.current.date(
            byAdding: .day, value: daysOffset, to: cruise.startDate
        )
        expense.cruise = cruise
        context.insert(expense)
        cruise.expenses.append(expense)
    }
}
#endif
