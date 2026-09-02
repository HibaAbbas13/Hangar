import Foundation
import FirebaseFirestore

final class AccountRepository {
    private let db = DatabaseService.shared

    func purge(userId: String) async throws {
        try await purgeOwnedDecks(userId: userId)
        try await purgeInvites(userId: userId)
        try await leaveSharedDecks(userId: userId)
        try await deleteAll(in: db.activity(userId))
        try await db.userDoc(userId).delete()
    }

    private func purgeOwnedDecks(userId: String) async throws {
        let decks = try await db.decks(userId).getDocuments()
        for deck in decks.documents {
            let deckId = deck.documentID
            try await deleteAll(in: db.buttons(userId, deckId))
            try await deleteAll(in: db.members(userId, deckId))
            try await deleteAll(in: db.profiles(userId, deckId))
            try await db.deck(userId, deckId).delete()
        }
    }

    private func purgeInvites(userId: String) async throws {
        let invites = try await db.invites(userId).getDocuments()
        for invite in invites.documents {
            
            try? await db.inviteCodes().document(invite.documentID).delete()
            try await invite.reference.delete()
        }
    }

    
    
    private func leaveSharedDecks(userId: String) async throws {
        let pointers = try await db.sharedDecks(userId).getDocuments()
        for pointer in pointers.documents {
            if let shared = try? pointer.data(as: SharedDeckPointer.self) {
                try? await db.members(shared.ownerId, shared.deckId).document(userId).delete()
            }
            try await pointer.reference.delete()
        }
    }

    private func deleteAll(in collection: CollectionReference) async throws {
        
        while true {
            let snapshot = try await collection.limit(to: 400).getDocuments()
            guard !snapshot.documents.isEmpty else { return }
            let batch = db.db.batch()
            snapshot.documents.forEach { batch.deleteDocument($0.reference) }
            try await batch.commit()
            if snapshot.documents.count < 400 { return }
        }
    }
}
