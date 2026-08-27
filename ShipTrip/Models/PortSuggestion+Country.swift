//
//  PortSuggestion+Country.swift
//  ShipTrip
//
//  Created by ShipTrip on 27.08.26.
//  ISO-3166-Ländercodes für die Hafen-Referenzdaten (Audit 3.2/H-C, ADR-008).
//

import Foundation

/// Übersetzt die in den Hafen-Referenzdaten hinterlegten **deutschen** Ländernamen in
/// ISO-3166-1-Alpha-2-Codes und daraus in den Ländernamen der Gerätesprache.
///
/// Hintergrund: `PortSuggestion.popular` stammt aus einem Wikidata-Import mit deutschen
/// Landesbezeichnungen. Der Bestandsname bleibt der Schlüssel (und der persistierte Wert in
/// `Port.country`); für die Anzeige wird er über den Code auf
/// `Locale.localizedString(forRegionCode:)` gehoben. Nicht zuordenbare Einträge fallen
/// auf den Bestandsnamen zurück – siehe ADR-008.
enum PortCountryCatalog {

    // MARK: - Zugriff

    /// ISO-3166-1-Alpha-2-Code zum Bestandsnamen; `nil`, wenn der Name keinem aktuellen
    /// Staat/Territorium entspricht (historische Einträge) oder bewusst nicht gemappt ist.
    static func regionCode(for countryName: String) -> String? {
        let key = countryName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !key.isEmpty else { return nil }
        return regionCodesByLegacyName[key]
    }

    /// Ländername in der Gerätesprache. Fällt auf den Bestandsnamen zurück, wenn kein Code
    /// hinterlegt ist oder die Locale keinen Namen für den Code kennt.
    static func localizedName(for countryName: String) -> String {
        guard let code = regionCode(for: countryName),
              let localized = Locale.current.localizedString(forRegionCode: code) else {
            return countryName
        }
        return localized
    }

    // MARK: - Referenzdaten

    /// Bestandsname → ISO-3166-1-Alpha-2. Deterministisch aus den vorhandenen Ländernamen
    /// abgeleitet (Abgleich gegen die deutschen ICU-Regionsnamen), Sonderfälle per Alias
    /// ergänzt. Nicht enthalten und damit bewusst im Fallback:
    ///
    /// - `Antikes Athen`, `Byzantinisches Reich`, `Britisch-Hongkong`: historische Entitäten
    ///   ohne aktuellen ISO-Code.
    /// - `China` (CN) und `Bonaire` (BQ): Code existiert, aber der ICU-Anzeigename
    ///   („China, Festland“ bzw. „Karibische Niederlande“) ist für eine Kreuzfahrt-App
    ///   schlechter als der Bestandsname. Bewusste Ausnahme, Owner: ShipTrip, Review mit dem
    ///   nächsten Referenzdaten-Update.
    static let regionCodesByLegacyName: [String: String] = [
        "Albanien": "AL",
        "Algerien": "DZ",
        "Angola": "AO",
        "Antigua und Barbuda": "AG",
        "Argentinien": "AR",
        "Aruba": "AW",
        "Aserbaidschan": "AZ",
        "Australien": "AU",
        "Bahamas": "BS",
        "Bahrain": "BH",
        "Bangladesch": "BD",
        "Barbados": "BB",
        "Belgien": "BE",
        "Belize": "BZ",
        "Benin": "BJ",
        "Bosnien und Herzegowina": "BA",
        "Brasilien": "BR",
        "Britische Jungferninseln": "VG",
        "Brunei": "BN",
        "Bulgarien": "BG",
        "Chile": "CL",
        "Costa Rica": "CR",
        "Curaçao": "CW",
        "Dänemark": "DK",
        "Demokratische Republik Kongo": "CD",
        "Deutschland": "DE",
        "Dominica": "DM",
        "Dominikanische Republik": "DO",
        "Dschibuti": "DJ",
        "Ecuador": "EC",
        "El Salvador": "SV",
        "Elfenbeinküste": "CI",
        "Eritrea": "ER",
        "Estland": "EE",
        "Falklandinseln": "FK",
        "Färöer": "FO",
        "Fidschi": "FJ",
        "Finnland": "FI",
        "Föderierte Staaten von Mikronesien": "FM",
        "Frankreich": "FR",
        "Gabun": "GA",
        "Georgien": "GE",
        "Ghana": "GH",
        "Grenada": "GD",
        "Griechenland": "GR",
        "Grönland": "GL",
        "Großbritannien": "GB",
        "Guadeloupe": "GP",
        "Guatemala": "GT",
        "Guernsey": "GG",
        "Guinea": "GN",
        "Guinea-Bissau": "GW",
        "Haiti": "HT",
        "Honduras": "HN",
        "Hongkong": "HK",
        "Indien": "IN",
        "Indonesien": "ID",
        "Irak": "IQ",
        "Iran": "IR",
        "Irland": "IE",
        "Island": "IS",
        "Isle of Man": "IM",
        "Israel": "IL",
        "Italien": "IT",
        "Jamaika": "JM",
        "Japan": "JP",
        "Kaimaninseln": "KY",
        "Kanada": "CA",
        "Kap Verde": "CV",
        "Katar": "QA",
        "Kenia": "KE",
        "Kolumbien": "CO",
        "Kroatien": "HR",
        "Madagaskar": "MG",
        "Malaysia": "MY",
        "Malediven": "MV",
        "Malta": "MT",
        "Marokko": "MA",
        "Martinique": "MQ",
        "Mauritius": "MU",
        "Mexiko": "MX",
        "Monaco": "MC",
        "Montenegro": "ME",
        "Namibia": "NA",
        "Neuseeland": "NZ",
        "Niederlande": "NL",
        "Norwegen": "NO",
        "Oman": "OM",
        "Panama": "PA",
        "Philippinen": "PH",
        "Portugal": "PT",
        "Puerto Rico": "PR",
        "Russland": "RU",
        "Schweden": "SE",
        "Seychellen": "SC",
        "Singapur": "SG",
        "Sint Maarten": "SX",
        "Spanien": "ES",
        "Sri Lanka": "LK",
        "St. Kitts und Nevis": "KN",
        "St. Lucia": "LC",
        "Südafrika": "ZA",
        "Südkorea": "KR",
        "Taiwan": "TW",
        "Tansania": "TZ",
        "Thailand": "TH",
        "Türkei": "TR",
        "Uruguay": "UY",
        "US-Jungferninseln": "VI",
        "USA": "US",
        "VAE": "AE",
        "Vietnam": "VN"
    ]
}

// MARK: - PortSuggestion

extension PortSuggestion {
    /// ISO-3166-1-Alpha-2-Code des Hafenlandes; `nil` für nicht zuordenbare Bestandsnamen.
    var regionCode: String? { PortCountryCatalog.regionCode(for: country) }

    /// Ländername in der Gerätesprache; Fallback auf den Bestandsnamen.
    var localizedCountry: String { PortCountryCatalog.localizedName(for: country) }
}
