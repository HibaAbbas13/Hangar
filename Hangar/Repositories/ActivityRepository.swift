import Foundation
import FirebaseFirestore

final class ActivityRepository {
    private let db = DatabaseService.shared

    func observe(userId: String, limit: Int = 80, onChange: @escaping ([ActivityEvent]) -> Void) -> ListenerRegistration {
        db.activity(userId)
            .order(by: "createdAt", descending: true)
            .limit(to: limit)
            .addSnapshotListener { snapshot, _ in
                let events = snapshot?.documents.compactMap { Self.decode($0) } ?? []
                onChange(events)
            }
    }

    func append(_ event: ActivityEvent, userId: String) async throws {
        try db.activity(userId).document(event.id).setData(from: event, merge: true)
    }

    func clear(userId: String) async throws {
        let snapshot = try await db.activity(userId).limit(to: 200).getDocuments()
        let batch = DatabaseService.shared.db.batch()
        snapshot.documents.forEach { batch.deleteDocument($0.reference) }
        try await batch.commit()
    }

    private static func decode(_ snapshot: DocumentSnapshot) -> ActivityEvent? {
        var event = try? snapshot.data(as: ActivityEvent.self)
        event?.id = snapshot.documentID
        return event
    }
}
