import Foundation
import FirebaseCore
import FirebaseFunctions

struct TriggerResult: Hashable {
    var status: TriggerStatus
    var statusCode: Int?
    var durationMs: Int
    var message: String
    var buttonLabel: String
    var deckName: String
}

enum WebhookServiceError: LocalizedError {
    case invalidURL
    case http(Int, String)
    case function(String)

    var errorDescription: String? {
        switch self {
        case .invalidURL: return "Webhook URL is not valid."
        case .http(let code, let body):
            let trimmed = body.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.isEmpty {
                return "The hook answered \(code)."
            }
            return "The hook answered \(code): \(trimmed)"
        case .function(let message): return message
        }
    }
}

final class WebhookService {
    static let shared = WebhookService()

    private var functions: Functions {
        let region = Bundle.main.object(forInfoDictionaryKey: Constants.Functions.regionInfoKey) as? String
        return Functions.functions(region: (region?.isEmpty == false ? region : Constants.Functions.defaultRegion)!)
    }

    func persistBaseURL() {
        guard let projectId = FirebaseApp.app()?.options.projectID else { return }
        let region = Bundle.main.object(forInfoDictionaryKey: Constants.Functions.regionInfoKey) as? String
            ?? Constants.Functions.defaultRegion
        let url = "https://\(region)-\(projectId).cloudfunctions.net"
        AppGroupStore.defaults.set(url, forKey: SharedConstants.DefaultsKey.functionsBaseURL)
        AppGroupStore.persist()
    }

    func upsertButton(ownerId: String, deckId: String, button: DeckButton, secret: WebhookSecret) async throws -> DeckButton {
        let payload: [String: Any] = [
            "ownerId": ownerId,
            "deckId": deckId,
            "button": [
                "id": button.id,
                "label": button.label,
                "iconName": button.iconName,
                "method": secret.method.rawValue,
                "timeoutMs": button.timeoutMs,
                "requiresConfirmation": button.requiresConfirmation,
                "sortOrder": button.sortOrder
            ],
            "secret": [
                "url": secret.url,
                "headers": secret.headers,
                "body": secret.body,
                "method": secret.method.rawValue
            ]
        ]
        let result = try await functions.httpsCallable(Constants.Functions.upsertButton).call(payload)
        if let data = result.data as? [String: Any], let encrypted = data["webhookUrl"] as? String {
            var updated = button
            updated.webhookUrl = encrypted
            updated.headers = [:]
            updated.body = ""
            updated.method = secret.method
            updated.isEncrypted = true
            return updated
        }
        throw WebhookServiceError.function("The backend did not return an encrypted hook.")
    }

    func buttonSecret(ownerId: String, deckId: String, buttonId: String) async throws -> WebhookSecret {
        let result = try await functions.httpsCallable(Constants.Functions.getButtonSecret).call([
            "ownerId": ownerId,
            "deckId": deckId,
            "buttonId": buttonId
        ])
        guard let data = result.data as? [String: Any],
              let url = data["url"] as? String else {
            throw WebhookServiceError.function("Secret unavailable.")
        }
        let method = HTTPMethod(rawValue: data["method"] as? String ?? "POST") ?? .POST
        return WebhookSecret(
            url: url,
            headers: data["headers"] as? [String: String] ?? [:],
            body: data["body"] as? String ?? "",
            method: method
        )
    }

    func triggerCloud(ownerId: String, deckId: String, buttonId: String) async throws -> TriggerResult {
        let result = try await functions.httpsCallable(Constants.Functions.triggerDeckButton).call([
            "ownerId": ownerId,
            "deckId": deckId,
            "buttonId": buttonId
        ])
        return parseTrigger(result.data)
    }

    func runProfile(ownerId: String, deckId: String, profileId: String) async throws {
        _ = try await functions.httpsCallable(Constants.Functions.runExecutionProfile).call([
            "ownerId": ownerId,
            "deckId": deckId,
            "profileId": profileId
        ])
    }

    func triggerOnDevice(button: DeckButton, secret: WebhookSecret) async throws -> TriggerResult {
        let trimmed = secret.url.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let url = URL(string: trimmed),
              let scheme = url.scheme?.lowercased(),
              ["https", "http"].contains(scheme),
              url.host != nil else {
            throw WebhookServiceError.invalidURL
        }
        var request = URLRequest(url: url)
        request.httpMethod = secret.method.rawValue
        request.timeoutInterval = TimeInterval(max(button.timeoutMs, 1000)) / 1000.0
        secret.headers.forEach { request.setValue($1, forHTTPHeaderField: $0) }
        if secret.method != .GET, !secret.body.isEmpty {
            request.httpBody = secret.body.data(using: .utf8)
            if request.value(forHTTPHeaderField: "Content-Type") == nil {
                request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            }
        }
        let started = Date()
        let (data, response) = try await URLSession.shared.data(for: request)
        let code = (response as? HTTPURLResponse)?.statusCode ?? 0
        let duration = Int(Date().timeIntervalSince(started) * 1000)
        let body = String(data: data, encoding: .utf8) ?? ""
        let ok = (200..<300).contains(code)
        // A 500 is a completed round trip that the endpoint refused, not a
        // transport failure. Throwing it discarded the code, the duration and
        // the response body — exactly the three things a developer opens the
        // Console to read — so the failure is returned as a result and only a
        // genuinely unreachable endpoint (which URLSession throws for) is an
        // error.
        return TriggerResult(
            status: ok ? .succeeded : .failed,
            statusCode: code,
            durationMs: duration,
            message: ok
                ? String(body.prefix(280))
                : WebhookServiceError.http(code, String(body.prefix(280))).localizedDescription,
            buttonLabel: button.label,
            deckName: ""
        )
    }

    private func parseTrigger(_ raw: Any) -> TriggerResult {
        let data = raw as? [String: Any] ?? [:]
        return TriggerResult(
            status: TriggerStatus(rawValue: data["status"] as? String ?? "") ?? .succeeded,
            statusCode: data["statusCode"] as? Int,
            durationMs: data["durationMs"] as? Int ?? 0,
            message: data["message"] as? String ?? "Command dispatched",
            buttonLabel: data["buttonLabel"] as? String ?? "Command",
            deckName: data["deckName"] as? String ?? "Deck"
        )
    }
}
