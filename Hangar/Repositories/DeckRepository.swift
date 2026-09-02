import Foundation
import FirebaseFirestore

final class DeckRepository {
    private let db = DatabaseService.shared

    func observeOwned(
        userId: String,
        onChange: @escaping ([Deck]) -> Void,
        onError: ((Error) -> Void)? = nil
    ) -> ListenerRegistration {
        db.decks(userId).order(by: "sortOrder").addSnapshotListener { snapshot, error in
            if let error {
                onError?(error)
                return
            }
            let decks = snapshot?.documents.compactMap { Self.decode($0, fallbackOwner: userId) } ?? []
            onChange(decks)
        }
    }

    func observeSharedPointers(
        userId: String,
        onChange: @escaping ([SharedDeckPointer]) -> Void,
        onError: ((Error) -> Void)? = nil
    ) -> ListenerRegistration {
        db.sharedDecks(userId).addSnapshotListener { snapshot, error in
            if let error {
                onError?(error)
                return
            }
            let pointers = snapshot?.documents.compactMap { doc -> SharedDeckPointer? in
                var pointer = try? doc.data(as: SharedDeckPointer.self)
                pointer?.id = doc.documentID
                return pointer
            } ?? []
            onChange(pointers)
        }
    }

    func observeDeck(ownerId: String, deckId: String, onChange: @escaping (Deck?) -> Void) -> ListenerRegistration {
        db.deck(ownerId, deckId).addSnapshotListener { snapshot, _ in
            guard let snapshot, snapshot.exists else {
                onChange(nil)
                return
            }
            onChange(Self.decode(snapshot, fallbackOwner: ownerId))
        }
    }

    func save(_ deck: Deck, ownerId: String) async throws {
        var copy = deck
        copy.updatedAt = Date()
        copy.ownerId = ownerId
        try db.deck(ownerId, deck.id).setData(from: copy, merge: true)
    }

    func delete(ownerId: String, deckId: String) async throws {
        try await db.deck(ownerId, deckId).delete()
    }

    func count(ownerId: String) async throws -> Int {
        let snapshot = try await db.decks(ownerId).getDocuments()
        return snapshot.documents.count
    }

    func updateStatus(ownerId: String, deckId: String, status: TriggerStatus) async throws {
        try await db.deck(ownerId, deckId).setData([
            "lastStatus": status.rawValue,
            "lastTriggeredAt": FieldValue.serverTimestamp(),
            "updatedAt": FieldValue.serverTimestamp()
        ], merge: true)
    }

    private static func decode(_ snapshot: DocumentSnapshot, fallbackOwner: String) -> Deck? {
        var deck = try? snapshot.data(as: Deck.self)
        deck?.id = snapshot.documentID
        if deck?.ownerId.isEmpty == true {
            deck?.ownerId = fallbackOwner
        }
        return deck
    }
}
