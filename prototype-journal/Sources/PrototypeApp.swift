//
//  PrototypeApp.swift
//  ProtoJournal — Design-Prototyp, KEIN Produktivcode.
//
//  Bootstrap nach design-phase/references/prototype-convention.md:
//  Request kommt als Datei aus dem App-Container, Receipt geht als Datei zurück.
//

import SwiftUI

@main
struct PrototypeApp: App {
    private let request = ProtoRequest.load()

    var body: some Scene {
        WindowGroup {
            ProtoRoot(request: request)
        }
    }
}

/// Wurzel-View: löst den angeforderten Screen auf, setzt das Farbschema und
/// schreibt die Quittung, sobald der erste Frame steht.
private struct ProtoRoot: View {
    let request: ProtoRequest

    var body: some View {
        Group {
            if ProtoScreens.contains(request.screen) {
                ProtoScreens.view(for: request.screen)
            } else {
                Text("unknown screen: \(request.screen)")
            }
        }
        .preferredColorScheme(request.mode == "dark" ? .dark : .light)
        .task {
            ProtoRequest.writeReceipt(request,
                                      resolved: ProtoScreens.contains(request.screen))
        }
    }
}

// MARK: - Request / Receipt

struct ProtoRequest: Codable {
    var screen: String = ProtoScreens.entry
    var mode: String = "light"

    static var dir: URL { URL(fileURLWithPath: NSTemporaryDirectory()) }

    static func load() -> ProtoRequest {
        guard let data = try? Data(contentsOf: dir.appendingPathComponent("proto_request.json")),
              let req = try? JSONDecoder().decode(ProtoRequest.self, from: data)
        else { return ProtoRequest() }
        return req
    }

    static func writeReceipt(_ req: ProtoRequest, resolved: Bool) {
        let payload: [String: Any] = [
            "screen": req.screen,
            "mode": req.mode,
            "resolved": resolved,
            "screens": ProtoScreens.names
        ]
        try? JSONSerialization.data(withJSONObject: payload)
            .write(to: dir.appendingPathComponent("proto_receipt.json"))
    }
}
