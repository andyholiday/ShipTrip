//
//  PrototypeApp.swift
//  ProtoOnboarding — Design-Prototyp, KEIN Produktivcode.
//
//  Bootstrap nach `design-phase/references/prototype-convention.md`:
//  Request-Datei lesen, Screen rendern, Receipt schreiben.
//

import SwiftUI

enum ProtoScreens {
    static let entry = "karte-1"

    @MainActor
    static let registry: [String: @MainActor () -> AnyView] = [
        "karte-1": { AnyView(OnboardingFlow(startIndex: 0)) },
        "karte-2": { AnyView(OnboardingFlow(startIndex: 1)) },
        "karte-3": { AnyView(OnboardingFlow(startIndex: 2)) },
        "karte-4": { AnyView(OnboardingFlow(startIndex: 3)) }
    ]
}

@main
struct PrototypeApp: App {
    private let request = ProtoRequest.load()

    var body: some Scene {
        WindowGroup {
            (ProtoScreens.registry[request.screen]?()
                ?? AnyView(Text("unknown screen: \(request.screen)")))
                .preferredColorScheme(request.mode == "dark" ? .dark : .light)
                .task {
                    ProtoRequest.writeReceipt(
                        request,
                        resolved: ProtoScreens.registry[request.screen] != nil
                    )
                }
        }
    }
}

struct ProtoRequest: Codable {
    var screen: String = ProtoScreens.entry
    var mode: String = "light"

    static var dir: URL { URL(fileURLWithPath: NSTemporaryDirectory()) }

    static func load() -> ProtoRequest {
        guard
            let data = try? Data(contentsOf: dir.appendingPathComponent("proto_request.json")),
            let req = try? JSONDecoder().decode(ProtoRequest.self, from: data)
        else { return ProtoRequest() }
        return req
    }

    @MainActor
    static func writeReceipt(_ req: ProtoRequest, resolved: Bool) {
        let payload: [String: Any] = [
            "screen": req.screen,
            "mode": req.mode,
            "resolved": resolved,
            "screens": Array(ProtoScreens.registry.keys)
        ]
        try? JSONSerialization.data(withJSONObject: payload)
            .write(to: dir.appendingPathComponent("proto_receipt.json"))
    }
}
