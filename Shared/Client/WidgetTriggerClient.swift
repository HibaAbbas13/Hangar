import Foundation

enum WidgetTriggerError: LocalizedError {
    case missingCommand
    case invalidURL
    case server(String)
    case network

    var errorDescription: String? {
        switch self {
        case .missingCommand: return "Open Hangar and save this command again."
        case .invalidURL: return "This command has no webhook URL."
        case .server(let message): return message
        case .network: return "Network unavailable."
        }
    }
}

enum WidgetTriggerClient {
    static func trigger(ownerId: String, deckId: String, buttonId: String) async throws {
        let decks = WidgetSnapshotStore.load()
        guard let deck = decks.first(where: { $0.deckId == deckId && $0.ownerId == ownerId }),
              let button = deck.buttons.first(where: { $0.id == buttonId }) else {
            throw WidgetTriggerError.missingCommand
        }
        guard let hook = URL(string: button.url), !button.url.isEmpty else {
            throw WidgetTriggerError.invalidURL
        }

        var request = URLRequest(url: hook)
        request.httpMethod = button.method.isEmpty ? "POST" : button.method
        request.timeoutInterval = 20
        button.headers.forEach { request.setValue($1, forHTTPHeaderField: $0) }
        if request.httpMethod != "GET", !button.body.isEmpty {
            request.httpBody = button.body.data(using: .utf8)
            if request.value(forHTTPHeaderField: "Content-Type") == nil {
                request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            }
        }

        let (data, response) = try await URLSession.shared.data(for: request)
        let code = (response as? HTTPURLResponse)?.statusCode ?? 0
        let body = String(data: data, encoding: .utf8) ?? ""
        guard (200..<300).contains(code) else {
            throw WidgetTriggerError.server("Hook returned \(code): \(body.prefix(180))")
        }

        LastTriggerStore.save(
            LastTriggerSnapshot(
                buttonLabel: button.label,
                deckName: deck.name,
                status: "succeeded",
                at: Date()
            )
        )
    }
}
