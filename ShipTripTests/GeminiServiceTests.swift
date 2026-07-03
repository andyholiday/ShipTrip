//
//  GeminiServiceTests.swift
//  ShipTripTests
//
//  Deckt GeminiService.extractCruiseData über eine gemockte URLSession ab (Erfolg, 401, 429,
//  kaputtes JSON) sowie den KeychainService-Roundtrip. Beide Testgruppen teilen sich denselben
//  physischen Keychain-Eintrag (.geminiApiKey), deshalb in einer gemeinsamen `.serialized`-Suite.
//

import Testing
import Foundation
import os
@testable import ShipTrip

// MARK: - Mock-URLProtocol

/// Fängt Requests ab, die über eine mit `[MockURLProtocol.self]` konfigurierte `URLSession`
/// laufen. Wird NICHT global via `URLProtocol.registerClass` registriert, sondern nur in der
/// Session-Configuration der jeweiligen Test-Session. Der Handler-State liegt hinter einem
/// `OSAllocatedUnfairLock` (kein `@unchecked Sendable`).
private final class MockURLProtocol: URLProtocol {
    private static let handlerLock = OSAllocatedUnfairLock<(@Sendable (URLRequest) throws -> (HTTPURLResponse, Data))?>(initialState: nil)

    static func setHandler(_ handler: @escaping @Sendable (URLRequest) throws -> (HTTPURLResponse, Data)) {
        handlerLock.withLock { $0 = handler }
    }

    static func reset() {
        handlerLock.withLock { $0 = nil }
    }

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        guard let handler = Self.handlerLock.withLock({ $0 }) else {
            client?.urlProtocol(self, didFailWithError: URLError(.badServerResponse))
            return
        }
        do {
            let (response, data) = try handler(request)
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: data)
            client?.urlProtocolDidFinishLoading(self)
        } catch {
            client?.urlProtocol(self, didFailWithError: error)
        }
    }

    override func stopLoading() {}
}

private func makeMockedSession() -> URLSession {
    let config = URLSessionConfiguration.ephemeral
    config.protocolClasses = [MockURLProtocol.self]
    return URLSession(configuration: config)
}

/// Sichert einen evtl. vorhandenen Simulator-`geminiApiKey` vor dem Test und stellt ihn danach
/// wieder her, damit Tests keinen echten, manuell hinterlegten Key überschreiben.
@MainActor
private func withPreservedApiKey<T>(_ body: () async throws -> T) async rethrows -> T {
    let existing = KeychainService.read(.geminiApiKey)
    defer {
        if let existing {
            KeychainService.save(existing, for: .geminiApiKey)
        } else {
            KeychainService.delete(.geminiApiKey)
        }
    }
    return try await body()
}

// MARK: - GeminiService + Keychain

@Suite("GeminiService & Keychain", .serialized)
@MainActor
struct GeminiServiceTests {

    @Test("Erfolgreiche Extraktion parst gültiges JSON aus der Gemini-Antwort")
    func extractCruiseDataSuccess() async throws {
        try await withPreservedApiKey {
            KeychainService.save("test-key", for: .geminiApiKey)
            defer { KeychainService.delete(.geminiApiKey) }

            MockURLProtocol.setHandler { request in
                let innerJSON = #"{"title": "Karibik Kreuzfahrt", "ports": []}"#
                let body = """
                {"candidates": [{"content": {"parts": [{"text": \(innerJSON.jsonEscaped)}]}}]}
                """
                let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
                return (response, Data(body.utf8))
            }
            defer { MockURLProtocol.reset() }

            let service = GeminiService(urlSession: makeMockedSession())
            let result = try await service.extractCruiseData(from: "Buchungsbestätigung Text")
            #expect(result.title == "Karibik Kreuzfahrt")
        }
    }

    @Test("401 wirft GeminiError.invalidApiKey")
    func extractCruiseData401() async throws {
        try await withPreservedApiKey {
            KeychainService.save("test-key", for: .geminiApiKey)
            defer { KeychainService.delete(.geminiApiKey) }

            MockURLProtocol.setHandler { request in
                let response = HTTPURLResponse(url: request.url!, statusCode: 401, httpVersion: nil, headerFields: nil)!
                return (response, Data())
            }
            defer { MockURLProtocol.reset() }

            let service = GeminiService(urlSession: makeMockedSession())
            do {
                _ = try await service.extractCruiseData(from: "text")
                Issue.record("Erwarteter Fehler blieb aus")
            } catch let error as GeminiError {
                guard case .invalidApiKey = error else {
                    Issue.record("Erwartete .invalidApiKey, erhalten: \(error)")
                    return
                }
            }
        }
    }

    @Test("429 wirft GeminiError.quotaExceeded")
    func extractCruiseData429() async throws {
        try await withPreservedApiKey {
            KeychainService.save("test-key", for: .geminiApiKey)
            defer { KeychainService.delete(.geminiApiKey) }

            MockURLProtocol.setHandler { request in
                let response = HTTPURLResponse(url: request.url!, statusCode: 429, httpVersion: nil, headerFields: nil)!
                return (response, Data())
            }
            defer { MockURLProtocol.reset() }

            let service = GeminiService(urlSession: makeMockedSession())
            do {
                _ = try await service.extractCruiseData(from: "text")
                Issue.record("Erwarteter Fehler blieb aus")
            } catch let error as GeminiError {
                guard case .quotaExceeded = error else {
                    Issue.record("Erwartete .quotaExceeded, erhalten: \(error)")
                    return
                }
            }
        }
    }

    @Test("Kaputtes JSON in der Gemini-Antwort wirft GeminiError.invalidResponse")
    func extractCruiseDataBrokenJSON() async throws {
        try await withPreservedApiKey {
            KeychainService.save("test-key", for: .geminiApiKey)
            defer { KeychainService.delete(.geminiApiKey) }

            MockURLProtocol.setHandler { request in
                let body = """
                {"candidates": [{"content": {"parts": [{"text": "{nicht valides JSON"}]}}]}
                """
                let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
                return (response, Data(body.utf8))
            }
            defer { MockURLProtocol.reset() }

            let service = GeminiService(urlSession: makeMockedSession())
            do {
                _ = try await service.extractCruiseData(from: "text")
                Issue.record("Erwarteter Fehler blieb aus")
            } catch let error as GeminiError {
                guard case .invalidResponse = error else {
                    Issue.record("Erwartete .invalidResponse, erhalten: \(error)")
                    return
                }
            }
        }
    }

    @Test("KeychainService: save/read/delete-Roundtrip für den Gemini-API-Key")
    func keychainRoundtrip() async {
        await withPreservedApiKey {
            #expect(KeychainService.save("roundtrip-key-123", for: .geminiApiKey))
            #expect(KeychainService.exists(.geminiApiKey))
            #expect(KeychainService.read(.geminiApiKey) == "roundtrip-key-123")

            #expect(KeychainService.delete(.geminiApiKey))
            #expect(!KeychainService.exists(.geminiApiKey))
            #expect(KeychainService.read(.geminiApiKey) == nil)
        }
    }
}

// MARK: - Hilfsmittel

private extension String {
    /// Bettet den String als JSON-Stringliteral ein (für die verschachtelte Gemini-`text`-Property).
    var jsonEscaped: String {
        let data = try! JSONEncoder().encode(self)
        return String(data: data, encoding: .utf8)!
    }
}
