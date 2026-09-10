import Foundation

enum WidgetTriggerError: LocalizedError {
    case missingCommand
    case notSignedIn
    case invalidURL
    case server(String)
    case network

    var errorDescription: String? {
        switch self {
        case .missingCommand: return "Open Hangar once so the pad can arm, then try Siri again."
        case .notSignedIn: return "Sign in to Hangar, then try again."
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

        if button.firesViaCloud || shouldUseCloud(for: button) {
            try await triggerViaCloud(
                ownerId: ownerId,
                deckId: deckId,
                buttonId: buttonId,
                buttonLabel: button.label,
                deckName: deck.name
            )
            return
        }

        try await triggerDirect(button: button, deckName: deck.name)
    }

    private static func shouldUseCloud(for button: WidgetButtonSnapshot) -> Bool {
        let url = button.url.trimmingCharacters(in: .whitespacesAndNewlines)
        return url.isEmpty || url.hasPrefix(Constants.Crypto.encryptedPrefix)
    }

    private static func triggerViaCloud(
        ownerId: String,
        deckId: String,
        buttonId: String,
        buttonLabel: String,
        deckName: String
    ) async throws {
        guard let token = AppGroupStore.defaults.string(forKey: SharedConstants.DefaultsKey.idToken),
              !token.isEmpty else {
            throw WidgetTriggerError.notSignedIn
        }
        guard let base = AppGroupStore.defaults.string(forKey: SharedConstants.DefaultsKey.functionsBaseURL),
              let endpoint = URL(string: "\(base)/\(Constants.Functions.triggerDeckButtonHttp)") else {
            throw WidgetTriggerError.server("Hangar Cloud is not configured.")
        }

        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.timeoutInterval = 25
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let payload: [String: String] = [
            "ownerId": ownerId,
            "deckId": deckId,
            "buttonId": buttonId
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: payload)

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await URLSession.shared.data(for: request)
        } catch {
            throw WidgetTriggerError.network
        }

        let code = (response as? HTTPURLResponse)?.statusCode ?? 0
        if code == 401 {
            throw WidgetTriggerError.notSignedIn
        }
        guard (200..<300).contains(code) else {
            let body = String(data: data, encoding: .utf8) ?? ""
            throw WidgetTriggerError.server(body.isEmpty ? "Hangar Cloud returned \(code)." : body)
        }

        LastTriggerStore.save(
            LastTriggerSnapshot(
                buttonLabel: buttonLabel,
                deckName: deckName,
                status: "succeeded",
                at: Date()
            )
        )
    }

    private static func triggerDirect(button: WidgetButtonSnapshot, deckName: String) async throws {
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
                deckName: deckName,
                status: "succeeded",
                at: Date()
            )
        )
    }
}
