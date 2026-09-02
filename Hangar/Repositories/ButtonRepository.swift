import Foundation
import FirebaseFirestore

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

    func saveMetadata(_ button: DeckButton, ownerId: String, deckId: String) async throws {
        var copy = button
        if copy.webhookUrl.hasPrefix(Constants.Crypto.encryptedPrefix) == false {
            copy.webhookUrl = ""
        }
        try db.button(ownerId, deckId, button.id).setData(from: copy, merge: true)
    }

    func saveWithSecret(
        _ button: DeckButton,
        secret: WebhookSecret,
        ownerId: String,
        deckId: String,
        mode: ExecutionMode
    ) async throws -> DeckButton {
        
        
        do {
            return try await WebhookService.shared.upsertButton(
                ownerId: ownerId, deckId: deckId, button: button, secret: secret
            )
        } catch {
            
            
            return try await savePlain(button, secret: secret, ownerId: ownerId, deckId: deckId)
        }
    }

    func markTriggered(ownerId: String, deckId: String, buttonId: String, status: TriggerStatus) async throws {
        try await db.button(ownerId, deckId, buttonId).setData([
            "lastTriggered": FieldValue.serverTimestamp(),
            "lastStatus": status.rawValue
        ], merge: true)
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
        try db.button(ownerId, deckId, button.id).setData(from: copy, merge: true)
        return copy
    }

    private static func decode(_ snapshot: DocumentSnapshot) -> DeckButton? {
        var button = try? snapshot.data(as: DeckButton.self)
        button?.id = snapshot.documentID
        return button
    }
}
