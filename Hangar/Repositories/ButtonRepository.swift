import Foundation
import FirebaseFirestore
import FirebaseFunctions

final class ButtonRepository {
    private let db = DatabaseService.shared

    func observe(
        ownerId: String,
        deckId: String,
        onChange: @escaping ([DeckButton]) -> Void,
        onError: ((Error) -> Void)? = nil
    ) -> ListenerRegistration {
        db.buttons(ownerId, deckId)
            .order(by: "sortOrder")
            .addSnapshotListener { snapshot, error in
                if let error {
                    onError?(error)
                    return
                }
                let buttons = snapshot?.documents.compactMap { Self.decode($0) } ?? []
                onChange(buttons)
            }
    }

    func fetch(ownerId: String, deckId: String) async throws -> [DeckButton] {
        let snapshot = try await db.buttons(ownerId, deckId).order(by: "sortOrder").getDocuments()
        return snapshot.documents.compactMap { Self.decode($0) }
    }

    func count(ownerId: String, deckId: String) async throws -> Int {
        try await fetch(ownerId: ownerId, deckId: deckId).count
    }

    /// Saves everything except the secret. Writing the whole record here would
    /// merge an emptied `webhookUrl` over the stored one, so renaming a command
    /// would silently delete its URL — only the metadata fields are written.
    func saveMetadata(_ button: DeckButton, ownerId: String, deckId: String) async throws {
        try await db.button(ownerId, deckId, button.id).setData([
            "label": button.label,
            "iconName": button.iconName,
            "method": button.method.rawValue,
            "timeoutMs": button.timeoutMs,
            "requiresConfirmation": button.requiresConfirmation,
            "sortOrder": button.sortOrder
        ], merge: true)
    }

    func saveWithSecret(
        _ button: DeckButton,
        secret: WebhookSecret,
        ownerId: String,
        deckId: String,
        mode: ExecutionMode
    ) async throws -> DeckButton {
        
        
        do {
            // The Cloud Function encrypts URL, headers and body with AES-GCM and
            // writes the document itself, so nothing plaintext leaves here.
            var saved = try await WebhookService.shared.upsertButton(
                ownerId: ownerId, deckId: deckId, button: button, secret: secret
            )
            // The host is not a secret, and without it an encrypted command is
            // an unlabelled black box on the pad.
            saved.host = Self.host(of: secret.url)
            try await db.button(ownerId, deckId, button.id)
                .setData(["host": saved.host], merge: true)
            return saved
        } catch {
            // The backend refused — quota, permission, bad input. Falling back
            // here would store the secret in the clear and silently downgrade
            // the user's security, so surface the refusal instead.
            guard Self.backendIsUnreachable(error) else { throw error }
            return try await savePlain(button, secret: secret, ownerId: ownerId, deckId: deckId)
        }
    }

    /// True only when nothing is listening — not when the server said no.
    private static func backendIsUnreachable(_ error: Error) -> Bool {
        let ns = error as NSError
        guard ns.domain == FunctionsErrorDomain,
              let code = FunctionsErrorCode(rawValue: ns.code) else { return true }
        switch code {
        case .notFound, .unavailable, .deadlineExceeded, .internal:
            return true
        default:
            return false
        }
    }

    static func host(of url: String) -> String {
        guard let host = URL(string: url)?.host else { return "" }
        return host.hasPrefix("www.") ? String(host.dropFirst(4)) : host
    }

    func markTriggered(
        ownerId: String,
        deckId: String,
        buttonId: String,
        status: TriggerStatus,
        statusCode: Int?,
        durationMs: Int
    ) async throws {
        var payload: [String: Any] = [
            "lastTriggered": FieldValue.serverTimestamp(),
            "lastStatus": status.rawValue,
            "lastDurationMs": durationMs
        ]
        // A transport failure has no code. Writing NSNull rather than skipping
        // the key clears a stale code from the previous run.
        payload["lastStatusCode"] = statusCode.map { $0 as Any } ?? NSNull()
        try await db.button(ownerId, deckId, buttonId).setData(payload, merge: true)
    }

    func delete(ownerId: String, deckId: String, buttonId: String) async throws {
        try await db.button(ownerId, deckId, buttonId).delete()
    }

    func secret(for button: DeckButton, ownerId: String, deckId: String, mode: ExecutionMode) async throws -> WebhookSecret {
        let stored = button.isEncrypted
            || button.webhookUrl.hasPrefix(Constants.Crypto.encryptedPrefix)
        guard stored else {
            return WebhookSecret(url: button.webhookUrl, headers: button.headers, body: button.body, method: button.method)
        }
        
        return try await WebhookService.shared.buttonSecret(
            ownerId: ownerId, deckId: deckId, buttonId: button.id
        )
    }

    private func savePlain(_ button: DeckButton, secret: WebhookSecret, ownerId: String, deckId: String) async throws -> DeckButton {
        var copy = button
        copy.webhookUrl = secret.url
        copy.headers = secret.headers
        copy.body = secret.body
        copy.method = secret.method
        copy.isEncrypted = false
        copy.host = Self.host(of: secret.url)
        try db.button(ownerId, deckId, button.id).setData(from: copy, merge: true)
        return copy
    }

    private static func decode(_ snapshot: DocumentSnapshot) -> DeckButton? {
        var button = try? snapshot.data(as: DeckButton.self)
        button?.id = snapshot.documentID
        return button
    }
}
