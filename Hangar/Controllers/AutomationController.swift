import Foundation
import FirebaseFirestore

@MainActor
final class AutomationController: ObservableObject {
    @Published var profiles: [ExecutionProfile] = []
    @Published var isRunning = false
    @Published var errorMessage: String?
    @Published var notice: String?

    private let repo = AutomationRepository()
    private let buttonsRepo = ButtonRepository()
    private let activityRepo = ActivityRepository()
    private let webhooks = WebhookService.shared
    private var listener: ListenerRegistration?
    private var ownerId = ""
    private var deckId = ""
    private var userId = ""

    func bind(userId: String) { self.userId = userId }

    func start(ownerId: String, deckId: String) {
        if self.ownerId == ownerId && self.deckId == deckId { return }
        listener?.remove()
        self.ownerId = ownerId
        self.deckId = deckId
        errorMessage = nil
        listener = repo.observe(ownerId: ownerId, deckId: deckId) { [weak self] profiles in
            Task { @MainActor in self?.profiles = profiles }
        } onError: { [weak self] error in
            Task { @MainActor in
                self?.errorMessage = AppErrorMapper.message(for: error)
            }
        }
    }

    func save(_ profile: ExecutionProfile) async {
        errorMessage = nil
        notice = nil
        do {
            try await repo.save(profile, ownerId: ownerId)
            notice = "Flow saved"
            HapticService.success()
        } catch {
            errorMessage = AppErrorMapper.message(for: error)
            HapticService.error()
        }
    }

    func delete(_ profile: ExecutionProfile) async {
        errorMessage = nil
        notice = nil
        do {
            try await repo.delete(profile, ownerId: ownerId)
            notice = "Flow deleted"
            HapticService.medium()
        } catch {
            errorMessage = AppErrorMapper.message(for: error)
            HapticService.error()
        }
    }

    func run(_ profile: ExecutionProfile, mode: ExecutionMode, buttons: [DeckButton], deck: Deck) async {
        isRunning = true
        errorMessage = nil
        notice = nil
        defer { isRunning = false }
        let started = Date()
        do {
            guard profile.steps.isEmpty == false else {
                errorMessage = "Add at least one step before running this flow."
                return
            }
            let total = profile.steps.count
            RunHUDStore.shared.begin(
                title: profile.name,
                detail: "Flow · \(total) steps",
                fraction: 0
            )
            for (index, step) in profile.steps.enumerated() {
                let label = buttons.first { $0.id == step.buttonId }?.label ?? "Command"
                if step.delaySeconds > 0 {
                    RunHUDStore.shared.update(
                        title: profile.name,
                        detail: "Waiting \(step.delaySeconds)s before \(label)",
                        fraction: Double(index) / Double(total)
                    )
                    try await Task.sleep(nanoseconds: UInt64(step.delaySeconds) * 1_000_000_000)
                }
                guard let button = buttons.first(where: { $0.id == step.buttonId }) else {
                    throw WebhookServiceError.function("Step \(index + 1) points at a command that no longer exists.")
                }
                // An unarmed command has no endpoint. Letting it through would
                // surface as "Webhook URL is not valid", which says nothing
                // about which step stalled or what to do about it.
                guard button.hasSecret else {
                    throw WebhookServiceError.function(
                        "Step \(index + 1) — \(button.label) — has no webhook yet. Open it on the pad and add one, then run this flow again."
                    )
                }
                RunHUDStore.shared.update(
                    title: button.label,
                    detail: "Step \(index + 1) of \(total)",
                    fraction: Double(index) / Double(total),
                    buttonId: button.id
                )
                let result = try await fire(button: button, deck: deck, mode: mode)
                await log(result, button: button, deck: deck)
                // An endpoint that refuses is no longer thrown, so the chain has
                // to stop on it deliberately. Running "notify" after a rollback
                // that returned 500 would report success for work that did not
                // happen.
                guard result.status == .succeeded else {
                    throw WebhookServiceError.function(
                        "Step \(index + 1) — \(button.label) — \(result.statusCode.map { "returned \($0)" } ?? "failed"). The rest of the flow was not run."
                    )
                }
            }
            let durationMs = Int(Date().timeIntervalSince(started) * 1000)
            notice = "Flow complete"
            RunHUDStore.shared.finish(
                title: profile.name,
                detail: "All \(total) steps landed. Logged in the Console.",
                succeeded: true,
                statusCode: nil,
                durationMs: durationMs
            )
            HapticService.success()
            SoundService.shared.play(.success)
        } catch {
            errorMessage = AppErrorMapper.message(for: error)
            RunHUDStore.shared.finish(
                title: profile.name,
                detail: AppErrorMapper.message(for: error),
                succeeded: false,
                statusCode: nil,
                durationMs: Int(Date().timeIntervalSince(started) * 1000)
            )
            HapticService.error()
            SoundService.shared.play(.fault)
        }
    }

    /// Flow steps land in the Console like any other run. Without this a
    /// premium feature was the one thing the log could not tell you about.
    private func log(_ result: TriggerResult, button: DeckButton, deck: Deck) async {
        guard !userId.isEmpty else { return }
        let event = ActivityEvent.make(
            deck: deck,
            button: button,
            status: result.status,
            statusCode: result.statusCode,
            durationMs: result.durationMs,
            message: result.message
        )
        try? await activityRepo.append(event, userId: userId)
        try? await buttonsRepo.markTriggered(
            ownerId: deck.ownerId,
            deckId: deck.id,
            buttonId: button.id,
            status: result.status,
            statusCode: result.statusCode,
            durationMs: result.durationMs
        )
    }

    private func fire(button: DeckButton, deck: Deck, mode: ExecutionMode) async throws -> TriggerResult {
        switch mode {
        case .cloudProxy:
            return try await webhooks.triggerCloud(
                ownerId: deck.ownerId,
                deckId: deck.id,
                buttonId: button.id
            )
        case .onDevice:
            let secret = try await buttonsRepo.secret(
                for: button,
                ownerId: ownerId,
                deckId: deck.id,
                mode: .onDevice
            )
            return try await webhooks.triggerOnDevice(button: button, secret: secret)
        }
    }
}
