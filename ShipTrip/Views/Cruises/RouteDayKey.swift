//
//  RouteDayKey.swift
//  ShipTrip
//
//  Vergleichbares Tag-Tripel fuer den Route-Journal-Faden (ADR-003, Contract J3neu).
//

import Foundation

/// Ein Kalendertag als vergleichbares Tag-Tripel (Jahr/Monat/Tag).
///
/// Der Zeitzonen-Vertrag (ADR-003) verbietet `Date ==` und lokales `startOfDay`
/// fuer `entryDate`. `DateComponents` ist zwar `Equatable`, aber nicht
/// `Comparable` — fuer die Phasen-Bestimmung (heute vs. Start-/Endtag) wird
/// beides gebraucht. Dieser Typ kapselt daher beide Fassungen des Vertrags:
///
/// - `entryDay(_:)` liest ein `entryDate` **immer** ueber `JournalDay.utcCalendar`
///   (kanonisch 12:00 UTC des Tages).
/// - `localDay(_:calendar:)` liest lokale Ereignis-Zeitstempel
///   (`port.arrival`, `cruise.startDate`, „heute") ueber den Geraete-Kalender,
///   dabei aber immer im gregorianischen Kalendersystem
///   (`JournalDay.gregorianCalendar(zonedLike:)`) — sonst verschoebe ein
///   nicht-gregorianischer Geraete-Kalender das Tripel um Jahrhunderte.
///
/// Beide Fabriken liefern damit Tripel derselben Aera und sind untereinander
/// vergleichbar — genau das, was J3neu fuer Zuordnung und Klapp-Defaults verlangt.
struct RouteDayKey: Hashable, Comparable, Sendable {
    let year: Int
    let month: Int
    let day: Int

    /// Tag-Tripel eines gespeicherten `entryDate` (UTC-Kalender).
    static func entryDay(_ entryDate: Date) -> RouteDayKey {
        RouteDayKey(components: JournalDay.dayComponents(ofEntryDate: entryDate))
    }

    /// Tag-Tripel eines lokalen Ereignis-Zeitstempels (Geraete-Zeitzone,
    /// gregorianisches Kalendersystem).
    static func localDay(_ date: Date, calendar: Calendar = .current) -> RouteDayKey {
        RouteDayKey(components: JournalDay.localDayComponents(of: date, calendar: calendar))
    }

    /// `Calendar.dateComponents` befuellt fuer ein echtes `Date` immer alle drei
    /// angeforderten Felder; `?? 0` ist der im Projekt uebliche Total-Fallback
    /// (vgl. `Cruise.durationInDays`, `Port.stayDuration`) und praktisch
    /// unerreichbar.
    private init(components: DateComponents) {
        self.year = components.year ?? 0
        self.month = components.month ?? 0
        self.day = components.day ?? 0
    }

    static func < (lhs: RouteDayKey, rhs: RouteDayKey) -> Bool {
        (lhs.year, lhs.month, lhs.day) < (rhs.year, rhs.month, rhs.day)
    }
}
