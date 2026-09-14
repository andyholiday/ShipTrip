//
//  JournalDayTests.swift
//  ShipTripTests
//
//  Zeitzonen-Vertrag aus ADR-003: `entryDate` ist ein Date-only-Wert, kanonisch
//  12:00 UTC des Tag-Tripels. Getestet werden genau die Grenzfälle, an denen
//  lokales `startOfDay` den Kalendertag verschieben würde.
//

import Testing
import Foundation
@testable import ShipTrip

// MARK: - Hilfsfunktionen

private func makeCalendar(timeZoneIdentifier: String) -> Calendar {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(identifier: timeZoneIdentifier) ?? .gmt
    return calendar
}

/// Zeitstempel aus „yyyy-MM-dd HH:mm" in der angegebenen Zeitzone.
private func makeDate(_ string: String, timeZoneIdentifier: String) throws -> Date {
    let formatter = DateFormatter()
    formatter.locale = Locale(identifier: "en_US_POSIX")
    formatter.dateFormat = "yyyy-MM-dd HH:mm"
    formatter.timeZone = TimeZone(identifier: timeZoneIdentifier) ?? .gmt
    return try #require(formatter.date(from: string), "Testdatum \(string) nicht bildbar")
}

private func utcParts(_ date: Date) -> DateComponents {
    JournalDay.utcCalendar.dateComponents([.year, .month, .day, .hour, .minute], from: date)
}

// MARK: - Kanonische Kodierung

@Suite("JournalDay — kanonische 12:00-UTC-Kodierung")
struct JournalDayEncodingTests {

    @Test("Ein lokal gewählter Tag wird auf 12:00 UTC seines Tag-Tripels normalisiert")
    func normalizesLocalDayToNoonUTC() throws {
        let calendar = makeCalendar(timeZoneIdentifier: "Europe/Berlin")
        let local = try makeDate("2026-06-15 08:30", timeZoneIdentifier: "Europe/Berlin")

        let normalized = JournalDay.normalizedEntryDate(forLocalDay: local, calendar: calendar)
        let parts = utcParts(normalized)

        #expect(parts.year == 2026)
        #expect(parts.month == 6)
        #expect(parts.day == 15)
        #expect(parts.hour == 12)
        #expect(parts.minute == 0)
    }

    @Test("Später Abend in einer West-Zeitzone behält den lokalen Kalendertag")
    func lateEveningInWesternZoneKeepsLocalDay() throws {
        // 23:30 lokal in UTC-11 ist bereits der Folgetag in UTC.
        let calendar = makeCalendar(timeZoneIdentifier: "Pacific/Pago_Pago")
        let local = try makeDate("2026-06-15 23:30", timeZoneIdentifier: "Pacific/Pago_Pago")

        let parts = utcParts(
            JournalDay.normalizedEntryDate(forLocalDay: local, calendar: calendar)
        )

        #expect(
            parts.day == 15,
            "Der lokale Kalendertag ist der Vertrag, nicht der UTC-Tag des Zeitstempels"
        )
        #expect(parts.month == 6)
        #expect(parts.hour == 12)
    }

    @Test("Früher Morgen in einer Ost-Zeitzone behält den lokalen Kalendertag")
    func earlyMorningInEasternZoneKeepsLocalDay() throws {
        // 00:30 lokal in UTC+14 ist in UTC noch der Vortag.
        let calendar = makeCalendar(timeZoneIdentifier: "Pacific/Kiritimati")
        let local = try makeDate("2026-06-15 00:30", timeZoneIdentifier: "Pacific/Kiritimati")

        let parts = utcParts(
            JournalDay.normalizedEntryDate(forLocalDay: local, calendar: calendar)
        )

        #expect(parts.day == 15)
        #expect(parts.month == 6)
        #expect(parts.hour == 12)
    }

    @Test("Normalisierung ist idempotent")
    func normalizationIsIdempotent() throws {
        let calendar = makeCalendar(timeZoneIdentifier: "Europe/Berlin")
        let local = try makeDate("2026-06-15 22:45", timeZoneIdentifier: "Europe/Berlin")

        let once = JournalDay.normalizedEntryDate(forLocalDay: local, calendar: calendar)
        let twice = JournalDay.normalizedEntryDate(
            forLocalDay: once,
            calendar: JournalDay.utcCalendar
        )

        #expect(once == twice)
    }

    /// Der Mittags-Anker trägt so lange, wie der Geräte-Offset echt unter 12 h
    /// liegt: bei genau ±12 h fällt 12:00 UTC exakt auf die Tagesgrenze
    /// (Pacific/Auckland zeigt dort bereits den Folgetag). Deshalb ist die
    /// Tag-Extraktion laut Vertrag ausschliesslich der UTC-Kalender — lokale
    /// Kalender sehen `entryDate` nie als Tageswert.
    @Test("Der Mittags-Anker hält bei Geräte-Zeitzonen unter ±12 h denselben Tag")
    func noonAnchorSurvivesExtremeDeviceZones() throws {
        let calendar = makeCalendar(timeZoneIdentifier: "Europe/Berlin")
        let normalized = JournalDay.normalizedEntryDate(
            forLocalDay: try makeDate("2026-06-15 09:00", timeZoneIdentifier: "Europe/Berlin"),
            calendar: calendar
        )

        let zones = ["Pacific/Pago_Pago", "America/New_York", "Asia/Kolkata", "Asia/Tokyo"]
        for identifier in zones {
            let deviceCalendar = makeCalendar(timeZoneIdentifier: identifier)
            let localDay = deviceCalendar.dateComponents([.day], from: normalized).day
            #expect(localDay == 15, "Zeitzone \(identifier) darf den Tag nicht kippen")
        }
    }

    /// Ein nicht-gregorianischer Geräte-Kalender liefert Tag-Tripel in seiner
    /// eigenen Ära (buddhistisch: 2026 → 2569). Würde `entryDate` daraus direkt
    /// gebaut, läge der Eintrag ein halbes Jahrtausend daneben.
    @Test("Ein nicht-gregorianischer Geräte-Kalender kodiert denselben Tag")
    func nonGregorianDeviceCalendarEncodesSameDay() throws {
        var buddhist = Calendar(identifier: .buddhist)
        buddhist.timeZone = try #require(TimeZone(identifier: "Asia/Bangkok"))
        let local = try makeDate("2026-06-15 08:30", timeZoneIdentifier: "Asia/Bangkok")

        let parts = utcParts(
            JournalDay.normalizedEntryDate(forLocalDay: local, calendar: buddhist)
        )

        #expect(parts.year == 2026, "Die Ära des Geräte-Kalenders darf nicht durchschlagen")
        #expect(parts.month == 6)
        #expect(parts.day == 15)
        #expect(parts.hour == 12)
    }

    @Test("Tag-Vergleiche gelten auch mit nicht-gregorianischem Geräte-Kalender")
    func nonGregorianDeviceCalendarComparesSameDay() throws {
        var japanese = Calendar(identifier: .japanese)
        japanese.timeZone = try #require(TimeZone(identifier: "Asia/Tokyo"))
        let local = try makeDate("2026-06-15 08:30", timeZoneIdentifier: "Asia/Tokyo")

        let entry = JournalDay.normalizedEntryDate(forLocalDay: local, calendar: japanese)
        let sameDayEvening = try makeDate("2026-06-15 22:00", timeZoneIdentifier: "Asia/Tokyo")
        let nextDay = try makeDate("2026-06-16 09:00", timeZoneIdentifier: "Asia/Tokyo")

        #expect(
            JournalDay.isSameDay(entryDate: entry, asLocalDay: sameDayEvening, calendar: japanese)
        )
        #expect(
            !JournalDay.isSameDay(entryDate: entry, asLocalDay: nextDay, calendar: japanese)
        )
    }
}

// MARK: - Import-Normalisierung

@Suite("JournalDay — Import-Normalisierung")
struct JournalDayImportTests {

    @Test("Ein unnormalisierter Import-Zeitstempel landet auf 12:00 UTC seines UTC-Tag-Tripels")
    func importedTimestampIsNormalizedInUTC() throws {
        let imported = try makeDate("2026-06-15 23:59", timeZoneIdentifier: "UTC")
        let parts = utcParts(JournalDay.normalizedEntryDate(forImported: imported))

        #expect(parts.day == 15)
        #expect(parts.hour == 12)
        #expect(parts.minute == 0)
    }

    @Test("Mitternacht UTC bleibt auf demselben UTC-Tag")
    func midnightUTCStaysOnSameDay() throws {
        let imported = try makeDate("2026-06-15 00:00", timeZoneIdentifier: "UTC")
        let parts = utcParts(JournalDay.normalizedEntryDate(forImported: imported))

        #expect(parts.day == 15)
        #expect(parts.hour == 12)
    }

    @Test("Bereits normalisierte Werte bleiben unverändert")
    func alreadyNormalizedValuesAreStable() throws {
        let normalized = try makeDate("2026-06-15 12:00", timeZoneIdentifier: "UTC")
        #expect(JournalDay.normalizedEntryDate(forImported: normalized) == normalized)
    }
}

// MARK: - Tag-Tripel-Vergleiche

@Suite("JournalDay — Tag-Tripel-Vergleiche")
struct JournalDayComparisonTests {

    @Test("entryDate und lokaler Ereignis-Zeitstempel werden über Tag-Tripel verglichen")
    func comparesEntryDateAgainstLocalTimestamp() throws {
        let berlin = makeCalendar(timeZoneIdentifier: "Europe/Berlin")
        let entry = JournalDay.normalizedEntryDate(
            forLocalDay: try makeDate("2026-06-15 10:00", timeZoneIdentifier: "Europe/Berlin"),
            calendar: berlin
        )

        // Hafen-Ankunft am selben lokalen Tag, aber spät abends.
        let arrival = try makeDate("2026-06-15 23:30", timeZoneIdentifier: "Europe/Berlin")
        #expect(JournalDay.isSameDay(entryDate: entry, asLocalDay: arrival, calendar: berlin))

        let nextDayArrival = try makeDate("2026-06-16 00:10", timeZoneIdentifier: "Europe/Berlin")
        #expect(
            !JournalDay.isSameDay(entryDate: entry, asLocalDay: nextDayArrival, calendar: berlin)
        )
    }

    @Test("Zwei entryDate-Werte desselben Tages sind gleich, verschiedene Tage nicht")
    func comparesTwoEntryDates() throws {
        let berlin = makeCalendar(timeZoneIdentifier: "Europe/Berlin")
        let first = JournalDay.normalizedEntryDate(
            forLocalDay: try makeDate("2026-06-15 07:00", timeZoneIdentifier: "Europe/Berlin"),
            calendar: berlin
        )
        let second = JournalDay.normalizedEntryDate(
            forLocalDay: try makeDate("2026-06-15 21:00", timeZoneIdentifier: "Europe/Berlin"),
            calendar: berlin
        )
        let other = JournalDay.normalizedEntryDate(
            forLocalDay: try makeDate("2026-06-16 07:00", timeZoneIdentifier: "Europe/Berlin"),
            calendar: berlin
        )

        #expect(JournalDay.isSameDay(entryDate: first, otherEntryDate: second))
        #expect(!JournalDay.isSameDay(entryDate: first, otherEntryDate: other))
    }

    @Test("Tag-Extraktion aus entryDate läuft immer über den UTC-Kalender")
    func dayComponentsUseUTCCalendar() throws {
        let entry = try makeDate("2026-06-15 12:00", timeZoneIdentifier: "UTC")
        let parts = JournalDay.dayComponents(ofEntryDate: entry)

        #expect(parts.year == 2026)
        #expect(parts.month == 6)
        #expect(parts.day == 15)
        #expect(JournalDay.utcCalendar.timeZone.secondsFromGMT() == 0)
    }
}
