import Foundation
import Combine

/// On-screen progress for a command or sequence. History still logs the
/// result; this is what the operator watches while the request is in flight.
@MainActor
final class RunHUDStore: ObservableObject {
    static let shared = RunHUDStore()

    enum Phase: Equatable {
        case hidden
        case running(title: String, detail: String, startedAt: Date, fraction: Double?)
        case done(title: String, detail: String, succeeded: Bool, statusCode: Int?, durationMs: Int)
    }

    @Published private(set) var phase: Phase = .hidden
    @Published private(set) var pulsingIds: Set<String> = []

    private var hideTask: Task<Void, Never>?

    func begin(title: String, detail: String, fraction: Double? = nil, buttonId: String? = nil) {
        hideTask?.cancel()
        if let buttonId {
            pulsingIds.insert(buttonId)
        }
        phase = .running(title: title, detail: detail, startedAt: Date(), fraction: fraction)
    }

    func update(title: String? = nil, detail: String? = nil, fraction: Double? = nil, buttonId: String? = nil) {
        if let buttonId {
            pulsingIds = [buttonId]
        }
        guard case .running(let currentTitle, let currentDetail, let startedAt, let currentFraction) = phase else {
            if let title {
                begin(title: title, detail: detail ?? "", fraction: fraction, buttonId: buttonId)
            }
            return
        }
        phase = .running(
            title: title ?? currentTitle,
            detail: detail ?? currentDetail,
            startedAt: startedAt,
            fraction: fraction ?? currentFraction
        )
    }

    func finish(
        title: String,
        detail: String,
        succeeded: Bool,
        statusCode: Int?,
        durationMs: Int
    ) {
        hideTask?.cancel()
        pulsingIds = []
        phase = .done(
            title: title,
            detail: detail,
            succeeded: succeeded,
            statusCode: statusCode,
            durationMs: durationMs
        )
        hideTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 3_400_000_000)
            guard !Task.isCancelled else { return }
            self?.phase = .hidden
        }
    }

    func dismiss() {
        hideTask?.cancel()
        pulsingIds = []
        phase = .hidden
    }
}
