import Foundation
import FirebaseFirestore

@MainActor
final class ConsoleController: ObservableObject {
    @Published var events: [ActivityEvent] = []
    @Published var query = ""
    @Published var statusFilter: TriggerStatus?

    private let repo = ActivityRepository()
    private var listener: ListenerRegistration?
    private var userId = ""

    var filtered: [ActivityEvent] {
        events.filter { event in
            let matchesQuery = query.isEmpty
                || event.buttonLabel.localizedCaseInsensitiveContains(query)
                || event.deckName.localizedCaseInsensitiveContains(query)
                || event.message.localizedCaseInsensitiveContains(query)
            let matchesStatus = statusFilter == nil || event.status == statusFilter
            return matchesQuery && matchesStatus
        }
    }

    func start(userId: String) {
        guard self.userId != userId else { return }
        listener?.remove()
        self.userId = userId
        listener = repo.observe(userId: userId) { [weak self] events in
            Task { @MainActor in self?.events = events }
        }
    }

    func clear() async {
        try? await repo.clear(userId: userId)
    }
}
