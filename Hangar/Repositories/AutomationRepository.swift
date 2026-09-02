import Foundation
import FirebaseFirestore

final class AutomationRepository {
    private let db = DatabaseService.shared

    func observe(
        ownerId: String,
        deckId: String,
        onChange: @escaping ([ExecutionProfile]) -> Void,
        onError: ((Error) -> Void)? = nil
    ) -> ListenerRegistration {
        db.profiles(ownerId, deckId).addSnapshotListener { snapshot, error in
            if let error {
                onError?(error)
                return
            }
            let profiles = snapshot?.documents.compactMap { Self.decode($0) } ?? []
            onChange(profiles.sorted { $0.createdAt > $1.createdAt })
        }
    }

    func save(_ profile: ExecutionProfile, ownerId: String) async throws {
        var copy = profile
        copy.updatedAt = Date()
        try db.profiles(ownerId, profile.deckId).document(profile.id).setData(from: copy, merge: true)
    }

    func delete(_ profile: ExecutionProfile, ownerId: String) async throws {
        try await db.profiles(ownerId, profile.deckId).document(profile.id).delete()
    }

    private static func decode(_ snapshot: DocumentSnapshot) -> ExecutionProfile? {
        var profile = try? snapshot.data(as: ExecutionProfile.self)
        profile?.id = snapshot.documentID
        return profile
    }
}
