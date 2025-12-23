//
//  GeminiService.swift
//  ShipTrip
//
//  Created by ShipTrip on 18.12.25.
//

import Foundation

/// Service für Gemini AI Integration
@Observable
class GeminiService {
    
    static let shared = GeminiService()
    
    private let baseURL = "https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent"
    
    var isConfigured: Bool {
        KeychainService.exists(.geminiApiKey)
    }
    
    // MARK: - API Key Management
    
    func setApiKey(_ key: String) {
        KeychainService.save(key, for: .geminiApiKey)
    }
    
    func clearApiKey() {
        KeychainService.delete(.geminiApiKey)
    }
    
    // MARK: - Validation
    
    /// Validiert den API-Key mit einem Test-Request
    func validateApiKey() async throws -> Bool {
        guard let apiKey = KeychainService.read(.geminiApiKey) else {
            throw GeminiError.noApiKey
        }
        
        let prompt = "Sage nur 'OK'."
        let _ = try await generateContent(prompt: prompt, apiKey: apiKey)
        return true
    }
    
    // MARK: - Cruise Data Extraction
    
    /// Extrahiert Kreuzfahrt-Daten aus einem Text (z.B. Buchungsbestätigung)
    func extractCruiseData(from text: String) async throws -> ExtractedCruiseData {
        guard let apiKey = KeychainService.read(.geminiApiKey) else {
            throw GeminiError.noApiKey
        }
        
        let prompt = """
        Analysiere den folgenden Text einer Kreuzfahrt-Buchung und extrahiere die Daten.
        Antworte NUR im JSON-Format ohne Markdown-Formatierung:
        
        {
            "title": "Titel der Reise",
            "shippingLine": "Name der Reederei",
            "ship": "Name des Schiffs",
            "startDate": "YYYY-MM-DD",
            "endDate": "YYYY-MM-DD",
            "cabinType": "Art der Kabine",
            "cabinNumber": "Kabinennummer",
            "bookingNumber": "Buchungsnummer",
            "ports": [
                {
                    "name": "Hafenname oder Seetag",
                    "country": "Land (leer bei Seetag)",
                    "arrivalDate": "YYYY-MM-DD",
                    "arrivalTime": "HH:MM",
                    "departureDate": "YYYY-MM-DD",
                    "departureTime": "HH:MM",
                    "isSeaDay": false
                }
            ]
        }
        
        WICHTIG:
        - Falls ein Feld nicht gefunden wird, setze null
        - Bei "Seetag", "Tag auf See", "Sea Day" etc.: setze isSeaDay auf true, name auf "Seetag"
        - arrivalDate/departureDate im Format YYYY-MM-DD, Zeiten im Format HH:MM (24h)
        
        Text zur Analyse:
        \(text)
        """
        
        let response = try await generateContent(prompt: prompt, apiKey: apiKey)
        
        // Clean up response - extract JSON from markdown if present
        var jsonString = response.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Remove markdown code blocks if present
        if jsonString.contains("```json") {
            if let startRange = jsonString.range(of: "```json"),
               let endRange = jsonString.range(of: "```", range: startRange.upperBound..<jsonString.endIndex) {
                jsonString = String(jsonString[startRange.upperBound..<endRange.lowerBound])
            }
        } else if jsonString.contains("```") {
            // Generic code block
            if let startRange = jsonString.range(of: "```"),
               let endRange = jsonString.range(of: "```", range: startRange.upperBound..<jsonString.endIndex) {
                jsonString = String(jsonString[startRange.upperBound..<endRange.lowerBound])
            }
        }
        
        // Try to find JSON object in response
        if let jsonStart = jsonString.firstIndex(of: "{"),
           let jsonEnd = jsonString.lastIndex(of: "}") {
            jsonString = String(jsonString[jsonStart...jsonEnd])
        }
        
        jsonString = jsonString.trimmingCharacters(in: .whitespacesAndNewlines)
        
        print("DEBUG: Extracted JSON: \(jsonString)")
        
        // Parse JSON response
        guard let jsonData = jsonString.data(using: .utf8),
              let extracted = try? JSONDecoder().decode(ExtractedCruiseData.self, from: jsonData) else {
            print("DEBUG: Failed to parse JSON")
            throw GeminiError.invalidResponse
        }
        
        return extracted
    }
    
    // MARK: - Private
    
    private func generateContent(prompt: String, apiKey: String) async throws -> String {
        guard let url = URL(string: "\(baseURL)?key=\(apiKey)") else {
            throw GeminiError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let body: [String: Any] = [
            "contents": [
                [
                    "parts": [
                        ["text": prompt]
                    ]
                ]
            ]
        ]
        
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw GeminiError.networkError
        }
        
        // Check for error response
        if httpResponse.statusCode != 200 {
            // Try to parse error message from response
            if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let error = json["error"] as? [String: Any],
               let message = error["message"] as? String {
                throw GeminiError.apiError(message)
            }
            
            // Fallback to status code based errors
            switch httpResponse.statusCode {
            case 400:
                throw GeminiError.invalidRequest
            case 401, 403:
                throw GeminiError.invalidApiKey
            case 429:
                throw GeminiError.quotaExceeded
            default:
                throw GeminiError.serverError(httpResponse.statusCode)
            }
        }
        
        // Parse successful response
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let candidates = json["candidates"] as? [[String: Any]],
              let firstCandidate = candidates.first,
              let content = firstCandidate["content"] as? [String: Any],
              let parts = content["parts"] as? [[String: Any]],
              let firstPart = parts.first,
              let text = firstPart["text"] as? String else {
            throw GeminiError.invalidResponse
        }
        
        return text
    }
}

// MARK: - Error Types

enum GeminiError: LocalizedError {
    case noApiKey
    case invalidURL
    case invalidRequest
    case invalidApiKey
    case quotaExceeded
    case networkError
    case serverError(Int)
    case invalidResponse
    case apiError(String)
    
    var errorDescription: String? {
        switch self {
        case .noApiKey:
            return "Kein API-Key konfiguriert"
        case .invalidURL:
            return "Ungültige URL"
        case .invalidRequest:
            return "Ungültige Anfrage"
        case .invalidApiKey:
            return "Ungültiger API-Key"
        case .quotaExceeded:
            return "API-Kontingent überschritten"
        case .networkError:
            return "Netzwerkfehler"
        case .serverError(let code):
            return "Serverfehler (\(code))"
        case .invalidResponse:
            return "Ungültige Antwort"
        case .apiError(let message):
            return message
        }
    }
}

// MARK: - Data Models

struct ExtractedCruiseData: Codable {
    let title: String?
    let shippingLine: String?
    let ship: String?
    let startDate: String?
    let endDate: String?
    let cabinType: String?
    let cabinNumber: String?
    let bookingNumber: String?
    let ports: [ExtractedPort]?
}

struct ExtractedPort: Codable {
    let name: String
    let country: String?
    let arrivalDate: String?
    let arrivalTime: String?
    let departureDate: String?
    let departureTime: String?
    let isSeaDay: Bool?
}
