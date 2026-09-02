import Foundation
import FirebaseFirestore

final class TeamRepository {
    private let db = DatabaseService.shared

    func observeMembers(
        ownerId: String,
        deckId: String,
        onChange: @escaping ([TeamMember]) -> Void,
        onError: ((Error) -> Void)? = nil
    ) -> ListenerRegistration {
        db.members(ownerId, deckId).addSnapshotListener { snapshot, error in
            if let error {
                onError?(error)
                return
            }
            let members = snapshot?.documents.compactMap { doc -> TeamMember? in
                var member = try? doc.data(as: TeamMember.self)
                member?.id = doc.documentID
                return member
            } ?? []
            onChange(members)
        }
    }

    func createInvite(deck: Deck) async throws -> DeckInvite {
        try await createInviteLocal(deck: deck)
    }

    func join(code: String, userId: String, displayName: String, email: String) async throws {
        try await joinLocal(code: code, userId: userId, displayName: displayName, email: email)
    }

    func removeMember(ownerId: String, deckId: String, memberId: String) async throws {
        try await db.members(ownerId, deckId).document(memberId).delete()
        try await db.sharedDecks(memberId).document(deckId).delete()
    }

    private func createInviteLocal(deck: Deck) async throws -> DeckInvite {
        let code = CryptoService.randomCode()
        let invite = DeckInvite(
            id: code,
            code: code,
            ownerId: deck.ownerId,
            deckId: deck.id,
            deckName: deck.name,
            status: .active,
            createdAt: Date()
        )
        try db.inviteCodes().document(code).setData(from: invite)
        try db.invites(deck.ownerId).document(code).setData(from: invite)
        return invite
    }

    private func joinLocal(code: String, userId: String, displayName: String, email: String) async throws {
        let snapshot = try await db.inviteCodes().document(code).getDocument()
        guard let invite = try? snapshot.data(as: DeckInvite.self), invite.status == .active else {
            throw WebhookServiceError.function("Invite code is invalid.")
        }
        let member = TeamMember(
            id: userId,
            email: email,
            displayName: displayName,
            role: .operatorRole,
            invitedAt: Date()
        )
        try db.members(invite.ownerId, invite.deckId).document(userId).setData(from: member)
        let pointer = SharedDeckPointer(
            id: invite.deckId,
            ownerId: invite.ownerId,
            deckId: invite.deckId,
            role: .operatorRole,
            deckName: invite.deckName
        )
        try db.sharedDecks(userId).document(invite.deckId).setData(from: pointer)
    }
}
