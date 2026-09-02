import Foundation
import FirebaseFirestore

final class UserRepository {
    private let db = DatabaseService.shared

    func observe(userId: String, onChange: @escaping (UserProfile?) -> Void) -> ListenerRegistration {
        db.userDoc(userId).addSnapshotListener { snapshot, _ in
            guard let snapshot, snapshot.exists else {
                onChange(nil)
                return
            }
            onChange(Self.decode(snapshot))
        }
    }

    func fetch(userId: String) async throws -> UserProfile? {
        let snapshot = try await db.userDoc(userId).getDocument()
        guard snapshot.exists else { return nil }
        return Self.decode(snapshot)
    }

    func ensureProfile(userId: String, displayName: String, email: String) async throws -> UserProfile {
        do {
            if let existing = try await fetch(userId: userId) {
                return existing
            }
            let profile = UserProfile.new(id: userId, displayName: displayName, email: email)
            try db.userDoc(userId).setData(from: profile, merge: true)
            return profile
        } catch {
            return UserProfile.new(id: userId, displayName: displayName, email: email)
        }
    }

    func save(_ profile: UserProfile) async throws {
        var copy = profile
        copy.updatedAt = Date()
        try db.userDoc(profile.id).setData(from: copy, merge: true)
    }

    func setTier(userId: String, tier: AppTier) async throws {
        try await db.userDoc(userId).setData([
            "tier": tier.rawValue,
            "updatedAt": FieldValue.serverTimestamp()
        ], merge: true)
    }

    private static func decode(_ snapshot: DocumentSnapshot) -> UserProfile? {
        var profile = try? snapshot.data(as: UserProfile.self)
        profile?.id = snapshot.documentID
        return profile
    }
}
