//
//  PortSuggestion.swift
//  ShipTrip
//
//  Created by ShipTrip on 18.12.25.
//

import Foundation
import CoreLocation

/// Hafen-Vorschlag für Autocomplete
struct PortSuggestion: Identifiable, Hashable {
    var id: String { "\(name)-\(country)" }
    
    let name: String
    let country: String
    let latitude: Double
    let longitude: Double
    
    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }
    
    /// Beliebte Kreuzfahrt-Häfen (~200 Häfen weltweit)
    static let popular: [PortSuggestion] = [
        // ═══════════════════════════════════════════════════════════════
        // EUROPA
        // ═══════════════════════════════════════════════════════════════
        
        // Deutschland
        PortSuggestion(name: "Hamburg", country: "Deutschland", latitude: 53.5511, longitude: 9.9937),
        PortSuggestion(name: "Kiel", country: "Deutschland", latitude: 54.3233, longitude: 10.1394),
        PortSuggestion(name: "Warnemünde", country: "Deutschland", latitude: 54.1781, longitude: 12.0945),
        PortSuggestion(name: "Bremerhaven", country: "Deutschland", latitude: 53.5413, longitude: 8.5813),
        
        // Spanien
        PortSuggestion(name: "Palma de Mallorca", country: "Spanien", latitude: 39.5696, longitude: 2.6502),
        PortSuggestion(name: "Barcelona", country: "Spanien", latitude: 41.3851, longitude: 2.1734),
        PortSuggestion(name: "Teneriffa", country: "Spanien", latitude: 28.4636, longitude: -16.2518),
        PortSuggestion(name: "Málaga", country: "Spanien", latitude: 36.7213, longitude: -4.4214),
        PortSuggestion(name: "Valencia", country: "Spanien", latitude: 39.4699, longitude: -0.3763),
        PortSuggestion(name: "Ibiza", country: "Spanien", latitude: 38.9067, longitude: 1.4206),
        PortSuggestion(name: "Las Palmas", country: "Spanien", latitude: 28.1235, longitude: -15.4363),
        PortSuggestion(name: "Lanzarote", country: "Spanien", latitude: 28.9638, longitude: -13.5477),
        PortSuggestion(name: "Cádiz", country: "Spanien", latitude: 36.5271, longitude: -6.2886),
        PortSuggestion(name: "Vigo", country: "Spanien", latitude: 42.2406, longitude: -8.7207),
        
        // Italien
        PortSuggestion(name: "Civitavecchia (Rom)", country: "Italien", latitude: 42.0924, longitude: 11.7958),
        PortSuggestion(name: "Venedig", country: "Italien", latitude: 45.4408, longitude: 12.3155),
        PortSuggestion(name: "Genua", country: "Italien", latitude: 44.4056, longitude: 8.9463),
        PortSuggestion(name: "Neapel", country: "Italien", latitude: 40.8518, longitude: 14.2681),
        PortSuggestion(name: "Livorno", country: "Italien", latitude: 43.5485, longitude: 10.3106),
        PortSuggestion(name: "Palermo", country: "Italien", latitude: 38.1157, longitude: 13.3615),
        PortSuggestion(name: "Messina", country: "Italien", latitude: 38.1938, longitude: 15.5540),
        PortSuggestion(name: "Catania", country: "Italien", latitude: 37.5079, longitude: 15.0830),
        PortSuggestion(name: "Bari", country: "Italien", latitude: 41.1171, longitude: 16.8719),
        PortSuggestion(name: "Cagliari", country: "Italien", latitude: 39.2238, longitude: 9.1217),
        PortSuggestion(name: "Savona", country: "Italien", latitude: 44.3091, longitude: 8.4772),
        PortSuggestion(name: "La Spezia", country: "Italien", latitude: 44.1024, longitude: 9.8241),
        PortSuggestion(name: "Triest", country: "Italien", latitude: 45.6495, longitude: 13.7768),
        PortSuggestion(name: "Amalfi", country: "Italien", latitude: 40.6340, longitude: 14.6027),
        PortSuggestion(name: "Sorrent", country: "Italien", latitude: 40.6263, longitude: 14.3758),
        PortSuggestion(name: "Capri", country: "Italien", latitude: 40.5531, longitude: 14.2222),
        
        // Frankreich
        PortSuggestion(name: "Marseille", country: "Frankreich", latitude: 43.2965, longitude: 5.3698),
        PortSuggestion(name: "Nizza", country: "Frankreich", latitude: 43.7102, longitude: 7.2620),
        PortSuggestion(name: "Cannes", country: "Frankreich", latitude: 43.5528, longitude: 7.0174),
        PortSuggestion(name: "Monaco", country: "Monaco", latitude: 43.7384, longitude: 7.4246),
        PortSuggestion(name: "Ajaccio", country: "Frankreich", latitude: 41.9192, longitude: 8.7386),
        PortSuggestion(name: "Bonifacio", country: "Frankreich", latitude: 41.3873, longitude: 9.1594),
        PortSuggestion(name: "Le Havre", country: "Frankreich", latitude: 49.4944, longitude: 0.1079),
        PortSuggestion(name: "Bordeaux", country: "Frankreich", latitude: 44.8378, longitude: -0.5792),
        
        // Griechenland
        PortSuggestion(name: "Athen (Piräus)", country: "Griechenland", latitude: 37.9425, longitude: 23.6471),
        PortSuggestion(name: "Piräus", country: "Griechenland", latitude: 37.9425, longitude: 23.6471),
        PortSuggestion(name: "Santorini", country: "Griechenland", latitude: 36.3932, longitude: 25.4615),
        PortSuggestion(name: "Mykonos", country: "Griechenland", latitude: 37.4467, longitude: 25.3289),
        PortSuggestion(name: "Mykonos Stadt", country: "Griechenland", latitude: 37.4467, longitude: 25.3289),
        PortSuggestion(name: "Korfu", country: "Griechenland", latitude: 39.6243, longitude: 19.9217),
        PortSuggestion(name: "Heraklion", country: "Griechenland", latitude: 35.3387, longitude: 25.1442),
        PortSuggestion(name: "Kreta", country: "Griechenland", latitude: 35.3387, longitude: 25.1442),
        PortSuggestion(name: "Argostóli", country: "Griechenland", latitude: 38.1744, longitude: 20.4890),
        PortSuggestion(name: "Argostoli", country: "Griechenland", latitude: 38.1744, longitude: 20.4890),
        PortSuggestion(name: "Kefalonia", country: "Griechenland", latitude: 38.1744, longitude: 20.4890),
        PortSuggestion(name: "Kos", country: "Griechenland", latitude: 36.8937, longitude: 27.0936),
        PortSuggestion(name: "Rhodos", country: "Griechenland", latitude: 36.4349, longitude: 28.2176),
        PortSuggestion(name: "Patmos", country: "Griechenland", latitude: 37.3106, longitude: 26.5456),
        PortSuggestion(name: "Zakynthos", country: "Griechenland", latitude: 37.7870, longitude: 20.8979),
        PortSuggestion(name: "Thessaloniki", country: "Griechenland", latitude: 40.6401, longitude: 22.9444),
        PortSuggestion(name: "Volos", country: "Griechenland", latitude: 39.3666, longitude: 22.9507),
        
        // Türkei
        PortSuggestion(name: "Bodrum", country: "Türkei", latitude: 37.0347, longitude: 27.4302),
        PortSuggestion(name: "Kuşadası", country: "Türkei", latitude: 37.8604, longitude: 27.2541),
        PortSuggestion(name: "Kusadasi", country: "Türkei", latitude: 37.8604, longitude: 27.2541),
        PortSuggestion(name: "Istanbul", country: "Türkei", latitude: 41.0082, longitude: 28.9784),
        PortSuggestion(name: "Antalya", country: "Türkei", latitude: 36.8969, longitude: 30.7133),
        PortSuggestion(name: "Marmaris", country: "Türkei", latitude: 36.8550, longitude: 28.2741),
        PortSuggestion(name: "Izmir", country: "Türkei", latitude: 38.4237, longitude: 27.1428),
        
        // Kroatien
        PortSuggestion(name: "Dubrovnik", country: "Kroatien", latitude: 42.6507, longitude: 18.0944),
        PortSuggestion(name: "Split", country: "Kroatien", latitude: 43.5081, longitude: 16.4402),
        PortSuggestion(name: "Zadar", country: "Kroatien", latitude: 44.1194, longitude: 15.2314),
        PortSuggestion(name: "Rijeka", country: "Kroatien", latitude: 45.3271, longitude: 14.4422),
        PortSuggestion(name: "Hvar", country: "Kroatien", latitude: 43.1729, longitude: 16.4411),
        PortSuggestion(name: "Korčula", country: "Kroatien", latitude: 42.9597, longitude: 17.1358),
        
        // Montenegro & Albanien
        PortSuggestion(name: "Kotor", country: "Montenegro", latitude: 42.4247, longitude: 18.7712),
        PortSuggestion(name: "Bar", country: "Montenegro", latitude: 42.0931, longitude: 19.1003),
        PortSuggestion(name: "Durrës", country: "Albanien", latitude: 41.3246, longitude: 19.4565),
        
        // Malta & Zypern
        PortSuggestion(name: "Valletta", country: "Malta", latitude: 35.8989, longitude: 14.5146),
        PortSuggestion(name: "La Valletta", country: "Malta", latitude: 35.8989, longitude: 14.5146),
        PortSuggestion(name: "Limassol", country: "Zypern", latitude: 34.6786, longitude: 33.0413),
        PortSuggestion(name: "Paphos", country: "Zypern", latitude: 34.7754, longitude: 32.4245),
        
        // Portugal
        PortSuggestion(name: "Lissabon", country: "Portugal", latitude: 38.7223, longitude: -9.1393),
        PortSuggestion(name: "Funchal (Madeira)", country: "Portugal", latitude: 32.6508, longitude: -16.9084),
        PortSuggestion(name: "Porto", country: "Portugal", latitude: 41.1579, longitude: -8.6291),
        PortSuggestion(name: "Ponta Delgada", country: "Portugal", latitude: 37.7394, longitude: -25.6687),
        
        // UK & Irland
        PortSuggestion(name: "Southampton", country: "UK", latitude: 50.9097, longitude: -1.4044),
        PortSuggestion(name: "Dover", country: "UK", latitude: 51.1279, longitude: 1.3134),
        PortSuggestion(name: "Liverpool", country: "UK", latitude: 53.4084, longitude: -2.9916),
        PortSuggestion(name: "Edinburgh", country: "UK", latitude: 55.9533, longitude: -3.1883),
        PortSuggestion(name: "Belfast", country: "UK", latitude: 54.5973, longitude: -5.9301),
        PortSuggestion(name: "Dublin", country: "Irland", latitude: 53.3498, longitude: -6.2603),
        PortSuggestion(name: "Cork", country: "Irland", latitude: 51.8985, longitude: -8.4756),
        
        // Skandinavien & Baltikum
        PortSuggestion(name: "Kopenhagen", country: "Dänemark", latitude: 55.6761, longitude: 12.5683),
        PortSuggestion(name: "Oslo", country: "Norwegen", latitude: 59.9139, longitude: 10.7522),
        PortSuggestion(name: "Bergen", country: "Norwegen", latitude: 60.3913, longitude: 5.3221),
        PortSuggestion(name: "Tromsø", country: "Norwegen", latitude: 69.6492, longitude: 18.9553),
        PortSuggestion(name: "Ålesund", country: "Norwegen", latitude: 62.4723, longitude: 6.1549),
        PortSuggestion(name: "Geiranger", country: "Norwegen", latitude: 62.1008, longitude: 7.2059),
        PortSuggestion(name: "Stavanger", country: "Norwegen", latitude: 58.9700, longitude: 5.7331),
        PortSuggestion(name: "Trondheim", country: "Norwegen", latitude: 63.4305, longitude: 10.3951),
        PortSuggestion(name: "Kristiansand", country: "Norwegen", latitude: 58.1599, longitude: 8.0182),
        PortSuggestion(name: "Flåm", country: "Norwegen", latitude: 60.8628, longitude: 7.1142),
        PortSuggestion(name: "Molde", country: "Norwegen", latitude: 62.7375, longitude: 7.1591),
        PortSuggestion(name: "Hammerfest", country: "Norwegen", latitude: 70.6634, longitude: 23.6821),
        PortSuggestion(name: "Honningsvåg", country: "Norwegen", latitude: 70.9827, longitude: 25.9708),
        PortSuggestion(name: "Nordkap", country: "Norwegen", latitude: 71.1685, longitude: 25.7838),
        PortSuggestion(name: "Stockholm", country: "Schweden", latitude: 59.3293, longitude: 18.0686),
        PortSuggestion(name: "Göteborg", country: "Schweden", latitude: 57.7089, longitude: 11.9746),
        PortSuggestion(name: "Visby", country: "Schweden", latitude: 57.6348, longitude: 18.2948),
        PortSuggestion(name: "Helsinki", country: "Finnland", latitude: 60.1699, longitude: 24.9384),
        PortSuggestion(name: "Tallinn", country: "Estland", latitude: 59.4370, longitude: 24.7536),
        PortSuggestion(name: "Riga", country: "Lettland", latitude: 56.9496, longitude: 24.1052),
        PortSuggestion(name: "St. Petersburg", country: "Russland", latitude: 59.9343, longitude: 30.3351),
        PortSuggestion(name: "Klaipėda", country: "Litauen", latitude: 55.7033, longitude: 21.1443),
        PortSuggestion(name: "Gdańsk", country: "Polen", latitude: 54.3520, longitude: 18.6466),
        
        // Island & Färöer
        PortSuggestion(name: "Reykjavik", country: "Island", latitude: 64.1466, longitude: -21.9426),
        PortSuggestion(name: "Akureyri", country: "Island", latitude: 65.6885, longitude: -18.0878),
        PortSuggestion(name: "Tórshavn", country: "Färöer", latitude: 62.0079, longitude: -6.7904),
        
        // ═══════════════════════════════════════════════════════════════
        // KARIBIK & AMERIKA
        // ═══════════════════════════════════════════════════════════════
        
        // USA
        PortSuggestion(name: "Miami", country: "USA", latitude: 25.7617, longitude: -80.1918),
        PortSuggestion(name: "Fort Lauderdale", country: "USA", latitude: 26.1224, longitude: -80.1373),
        PortSuggestion(name: "New York City", country: "USA", latitude: 40.7128, longitude: -74.0060),
        PortSuggestion(name: "San Juan", country: "Puerto Rico", latitude: 18.4655, longitude: -66.1057),
        PortSuggestion(name: "Key West", country: "USA", latitude: 24.5551, longitude: -81.7800),
        PortSuggestion(name: "Galveston", country: "USA", latitude: 29.3013, longitude: -94.7977),
        PortSuggestion(name: "New Orleans", country: "USA", latitude: 29.9511, longitude: -90.0715),
        PortSuggestion(name: "Tampa", country: "USA", latitude: 27.9506, longitude: -82.4572),
        PortSuggestion(name: "Seattle", country: "USA", latitude: 47.6062, longitude: -122.3321),
        PortSuggestion(name: "Los Angeles", country: "USA", latitude: 33.7405, longitude: -118.2678),
        PortSuggestion(name: "San Francisco", country: "USA", latitude: 37.7749, longitude: -122.4194),
        PortSuggestion(name: "San Diego", country: "USA", latitude: 32.7157, longitude: -117.1611),
        PortSuggestion(name: "Honolulu", country: "USA", latitude: 21.3069, longitude: -157.8583),
        PortSuggestion(name: "Juneau", country: "USA", latitude: 58.3019, longitude: -134.4197),
        PortSuggestion(name: "Ketchikan", country: "USA", latitude: 55.3422, longitude: -131.6461),
        PortSuggestion(name: "Skagway", country: "USA", latitude: 59.4583, longitude: -135.3139),
        
        // Karibik
        PortSuggestion(name: "Cozumel", country: "Mexiko", latitude: 20.5083, longitude: -86.9458),
        PortSuggestion(name: "Nassau", country: "Bahamas", latitude: 25.0478, longitude: -77.3554),
        PortSuggestion(name: "Freeport", country: "Bahamas", latitude: 26.5285, longitude: -78.6967),
        PortSuggestion(name: "St. Thomas", country: "US Virgin Islands", latitude: 18.3358, longitude: -64.8963),
        PortSuggestion(name: "St. Maarten", country: "Sint Maarten", latitude: 18.0425, longitude: -63.0548),
        PortSuggestion(name: "Philipsburg", country: "Sint Maarten", latitude: 18.0237, longitude: -63.0458),
        PortSuggestion(name: "Ocho Rios", country: "Jamaika", latitude: 18.4074, longitude: -77.1025),
        PortSuggestion(name: "Montego Bay", country: "Jamaika", latitude: 18.4762, longitude: -77.8939),
        PortSuggestion(name: "Grand Cayman", country: "Cayman Islands", latitude: 19.2869, longitude: -81.3674),
        PortSuggestion(name: "George Town", country: "Cayman Islands", latitude: 19.2869, longitude: -81.3674),
        PortSuggestion(name: "Aruba", country: "Aruba", latitude: 12.5211, longitude: -69.9683),
        PortSuggestion(name: "Oranjestad", country: "Aruba", latitude: 12.5092, longitude: -70.0086),
        PortSuggestion(name: "Curaçao", country: "Curaçao", latitude: 12.1696, longitude: -68.9900),
        PortSuggestion(name: "Willemstad", country: "Curaçao", latitude: 12.1091, longitude: -68.9316),
        PortSuggestion(name: "Bonaire", country: "Bonaire", latitude: 12.2019, longitude: -68.2624),
        PortSuggestion(name: "Barbados", country: "Barbados", latitude: 13.1132, longitude: -59.5988),
        PortSuggestion(name: "Bridgetown", country: "Barbados", latitude: 13.1132, longitude: -59.5988),
        PortSuggestion(name: "St. Lucia", country: "St. Lucia", latitude: 14.0101, longitude: -60.9875),
        PortSuggestion(name: "Castries", country: "St. Lucia", latitude: 14.0101, longitude: -60.9875),
        PortSuggestion(name: "Antigua", country: "Antigua", latitude: 17.1274, longitude: -61.8468),
        PortSuggestion(name: "St. John's", country: "Antigua", latitude: 17.1274, longitude: -61.8468),
        PortSuggestion(name: "Martinique", country: "Martinique", latitude: 14.6415, longitude: -61.0242),
        PortSuggestion(name: "Fort-de-France", country: "Martinique", latitude: 14.6037, longitude: -61.0696),
        PortSuggestion(name: "Guadeloupe", country: "Guadeloupe", latitude: 16.2650, longitude: -61.5510),
        PortSuggestion(name: "Tortola", country: "British Virgin Islands", latitude: 18.4167, longitude: -64.6167),
        PortSuggestion(name: "Grenada", country: "Grenada", latitude: 12.0561, longitude: -61.7488),
        PortSuggestion(name: "St. Kitts", country: "St. Kitts", latitude: 17.3026, longitude: -62.7177),
        PortSuggestion(name: "Basseterre", country: "St. Kitts", latitude: 17.3026, longitude: -62.7177),
        PortSuggestion(name: "Dominica", country: "Dominica", latitude: 15.3092, longitude: -61.3794),
        PortSuggestion(name: "Roatán", country: "Honduras", latitude: 16.3220, longitude: -86.5305),
        PortSuggestion(name: "Belize City", country: "Belize", latitude: 17.4985, longitude: -88.1886),
        PortSuggestion(name: "Costa Maya", country: "Mexiko", latitude: 18.7181, longitude: -87.6907),
        PortSuggestion(name: "Progreso", country: "Mexiko", latitude: 21.2814, longitude: -89.6651),
        PortSuggestion(name: "Cartagena", country: "Kolumbien", latitude: 10.3910, longitude: -75.4794),
        PortSuggestion(name: "Colón", country: "Panama", latitude: 9.3547, longitude: -79.9019),
        PortSuggestion(name: "Havanna", country: "Kuba", latitude: 23.1136, longitude: -82.3666),
        
        // Kanada
        PortSuggestion(name: "Vancouver", country: "Kanada", latitude: 49.2827, longitude: -123.1207),
        PortSuggestion(name: "Victoria", country: "Kanada", latitude: 48.4284, longitude: -123.3656),
        PortSuggestion(name: "Quebec City", country: "Kanada", latitude: 46.8139, longitude: -71.2080),
        PortSuggestion(name: "Halifax", country: "Kanada", latitude: 44.6488, longitude: -63.5752),
        PortSuggestion(name: "Sydney", country: "Kanada", latitude: 46.1368, longitude: -60.1942),
        
        // Südamerika
        PortSuggestion(name: "Rio de Janeiro", country: "Brasilien", latitude: -22.9068, longitude: -43.1729),
        PortSuggestion(name: "Buenos Aires", country: "Argentinien", latitude: -34.6037, longitude: -58.3816),
        PortSuggestion(name: "Ushuaia", country: "Argentinien", latitude: -54.8019, longitude: -68.3030),
        PortSuggestion(name: "Valparaíso", country: "Chile", latitude: -33.0472, longitude: -71.6127),
        PortSuggestion(name: "Punta Arenas", country: "Chile", latitude: -53.1638, longitude: -70.9171),
        
        // ═══════════════════════════════════════════════════════════════
        // ASIEN & NAHER OSTEN
        // ═══════════════════════════════════════════════════════════════
        
        // VAE & Naher Osten
        PortSuggestion(name: "Dubai", country: "VAE", latitude: 25.2769, longitude: 55.2963),
        PortSuggestion(name: "Abu Dhabi", country: "VAE", latitude: 24.4539, longitude: 54.3773),
        PortSuggestion(name: "Muscat", country: "Oman", latitude: 23.5880, longitude: 58.3829),
        PortSuggestion(name: "Doha", country: "Katar", latitude: 25.2854, longitude: 51.5310),
        PortSuggestion(name: "Bahrain", country: "Bahrain", latitude: 26.2235, longitude: 50.5876),
        PortSuggestion(name: "Aqaba", country: "Jordanien", latitude: 29.5267, longitude: 35.0078),
        PortSuggestion(name: "Haifa", country: "Israel", latitude: 32.7940, longitude: 34.9896),
        PortSuggestion(name: "Ashdod", country: "Israel", latitude: 31.8044, longitude: 34.6553),
        
        // Asien
        PortSuggestion(name: "Singapur", country: "Singapur", latitude: 1.3521, longitude: 103.8198),
        PortSuggestion(name: "Hong Kong", country: "China", latitude: 22.3193, longitude: 114.1694),
        PortSuggestion(name: "Shanghai", country: "China", latitude: 31.2304, longitude: 121.4737),
        PortSuggestion(name: "Peking (Tianjin)", country: "China", latitude: 39.0842, longitude: 117.2010),
        PortSuggestion(name: "Bangkok (Laem Chabang)", country: "Thailand", latitude: 13.0827, longitude: 100.8841),
        PortSuggestion(name: "Phuket", country: "Thailand", latitude: 7.8804, longitude: 98.3923),
        PortSuggestion(name: "Koh Samui", country: "Thailand", latitude: 9.5120, longitude: 100.0136),
        PortSuggestion(name: "Ho-Chi-Minh-Stadt", country: "Vietnam", latitude: 10.8231, longitude: 106.6297),
        PortSuggestion(name: "Hanoi (Ha Long)", country: "Vietnam", latitude: 20.9101, longitude: 107.1839),
        PortSuggestion(name: "Da Nang", country: "Vietnam", latitude: 16.0544, longitude: 108.2022),
        PortSuggestion(name: "Kuala Lumpur (Port Klang)", country: "Malaysia", latitude: 3.0319, longitude: 101.3682),
        PortSuggestion(name: "Penang", country: "Malaysia", latitude: 5.4141, longitude: 100.3288),
        PortSuggestion(name: "Langkawi", country: "Malaysia", latitude: 6.3500, longitude: 99.8000),
        PortSuggestion(name: "Bali (Benoa)", country: "Indonesien", latitude: -8.7467, longitude: 115.2111),
        PortSuggestion(name: "Jakarta", country: "Indonesien", latitude: -6.1075, longitude: 106.8804),
        PortSuggestion(name: "Komodo", country: "Indonesien", latitude: -8.5500, longitude: 119.4833),
        PortSuggestion(name: "Manila", country: "Philippinen", latitude: 14.5995, longitude: 120.9842),
        PortSuggestion(name: "Mumbai", country: "Indien", latitude: 18.9388, longitude: 72.8354),
        PortSuggestion(name: "Goa", country: "Indien", latitude: 15.4909, longitude: 73.8278),
        PortSuggestion(name: "Kochi", country: "Indien", latitude: 9.9312, longitude: 76.2673),
        PortSuggestion(name: "Colombo", country: "Sri Lanka", latitude: 6.9271, longitude: 79.8612),
        PortSuggestion(name: "Malé", country: "Malediven", latitude: 4.1755, longitude: 73.5093),
        
        // Japan
        PortSuggestion(name: "Tokio (Yokohama)", country: "Japan", latitude: 35.4437, longitude: 139.6380),
        PortSuggestion(name: "Osaka", country: "Japan", latitude: 34.6937, longitude: 135.5023),
        PortSuggestion(name: "Kobe", country: "Japan", latitude: 34.6901, longitude: 135.1956),
        PortSuggestion(name: "Nagasaki", country: "Japan", latitude: 32.7503, longitude: 129.8777),
        PortSuggestion(name: "Okinawa", country: "Japan", latitude: 26.2124, longitude: 127.6809),
        PortSuggestion(name: "Hakodate", country: "Japan", latitude: 41.7687, longitude: 140.7288),
        
        // Korea & Taiwan
        PortSuggestion(name: "Seoul (Incheon)", country: "Südkorea", latitude: 37.4563, longitude: 126.7052),
        PortSuggestion(name: "Busan", country: "Südkorea", latitude: 35.1796, longitude: 129.0756),
        PortSuggestion(name: "Taipei (Keelung)", country: "Taiwan", latitude: 25.1276, longitude: 121.7392),
        
        // ═══════════════════════════════════════════════════════════════
        // OZEANIEN
        // ═══════════════════════════════════════════════════════════════
        
        PortSuggestion(name: "Sydney", country: "Australien", latitude: -33.8688, longitude: 151.2093),
        PortSuggestion(name: "Melbourne", country: "Australien", latitude: -37.8136, longitude: 144.9631),
        PortSuggestion(name: "Brisbane", country: "Australien", latitude: -27.4698, longitude: 153.0251),
        PortSuggestion(name: "Cairns", country: "Australien", latitude: -16.9186, longitude: 145.7781),
        PortSuggestion(name: "Auckland", country: "Neuseeland", latitude: -36.8509, longitude: 174.7645),
        PortSuggestion(name: "Wellington", country: "Neuseeland", latitude: -41.2924, longitude: 174.7787),
        PortSuggestion(name: "Queenstown", country: "Neuseeland", latitude: -45.0312, longitude: 168.6626),
        PortSuggestion(name: "Fiji (Suva)", country: "Fiji", latitude: -18.1416, longitude: 178.4419),
        PortSuggestion(name: "Bora Bora", country: "Französisch-Polynesien", latitude: -16.5004, longitude: -151.7415),
        PortSuggestion(name: "Tahiti (Papeete)", country: "Französisch-Polynesien", latitude: -17.5516, longitude: -149.5585),
        
        // ═══════════════════════════════════════════════════════════════
        // AFRIKA
        // ═══════════════════════════════════════════════════════════════
        
        PortSuggestion(name: "Kapstadt", country: "Südafrika", latitude: -33.9249, longitude: 18.4241),
        PortSuggestion(name: "Durban", country: "Südafrika", latitude: -29.8587, longitude: 31.0218),
        PortSuggestion(name: "Casablanca", country: "Marokko", latitude: 33.5731, longitude: -7.5898),
        PortSuggestion(name: "Tanger", country: "Marokko", latitude: 35.7595, longitude: -5.8340),
        PortSuggestion(name: "Alexandria", country: "Ägypten", latitude: 31.2001, longitude: 29.9187),
        PortSuggestion(name: "Port Said", country: "Ägypten", latitude: 31.2653, longitude: 32.3019),
        PortSuggestion(name: "Sharm El Sheikh", country: "Ägypten", latitude: 27.9158, longitude: 34.3300),
        PortSuggestion(name: "Hurghada", country: "Ägypten", latitude: 27.2579, longitude: 33.8116),
        PortSuggestion(name: "Mauritius", country: "Mauritius", latitude: -20.1609, longitude: 57.5012),
        PortSuggestion(name: "Seychellen (Mahé)", country: "Seychellen", latitude: -4.6796, longitude: 55.4920),
        PortSuggestion(name: "Madagaskar (Nosy Be)", country: "Madagaskar", latitude: -13.3167, longitude: 48.2667),
        PortSuggestion(name: "La Réunion", country: "Frankreich", latitude: -20.8789, longitude: 55.4481),
    ]
    
    /// Sucht Häfen nach Name oder Land
    static func search(_ query: String) -> [PortSuggestion] {
        guard !query.isEmpty else { return popular }
        let lowercased = query.lowercased()
        return popular.filter {
            $0.name.lowercased().contains(lowercased) ||
            $0.country.lowercased().contains(lowercased)
        }
    }
}
