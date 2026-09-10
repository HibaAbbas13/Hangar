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

    /// The log grouped by calendar day, newest day first.
    ///
    /// A flat list of times reads fine for ten minutes and becomes unusable by
    /// the next morning, when yesterday's 3:04 PM sits directly above today's.
    var sections: [(day: Date, events: [ActivityEvent])] {
        let calendar = Calendar.current
        let grouped = Dictionary(grouping: filtered) { calendar.startOfDay(for: $0.createdAt) }
        return grouped
            .sorted { $0.key > $1.key }
            .map { (day: $0.key, events: $0.value.sorted { $0.createdAt > $1.createdAt }) }
    }

    static func dayTitle(_ day: Date) -> String {
        let calendar = Calendar.current
        if calendar.isDateInToday(day) { return "Today" }
        if calendar.isDateInYesterday(day) { return "Yesterday" }
        return day.formatted(.dateTime.weekday(.wide).month(.abbreviated).day())
    }

    var isFiltering: Bool { !query.isEmpty || statusFilter != nil }

    func resetFilters() {
        query = ""
        statusFilter = nil
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
