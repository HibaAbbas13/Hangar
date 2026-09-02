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
    private let webhooks = WebhookService.shared
    private var listener: ListenerRegistration?
    private var ownerId = ""
    private var deckId = ""

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
        do {
            guard profile.steps.isEmpty == false else {
                errorMessage = "Add at least one step before running this flow."
                return
            }
            for step in profile.steps {
                if step.delaySeconds > 0 {
                    try await Task.sleep(nanoseconds: UInt64(step.delaySeconds) * 1_000_000_000)
                }
                guard let button = buttons.first(where: { $0.id == step.buttonId }) else {
                    throw WebhookServiceError.function("A step points at a command that no longer exists.")
                }
                _ = try await fire(button: button, deck: deck, mode: mode)
            }
            notice = "Flow complete"
            HapticService.success()
            SoundService.shared.play(.success)
        } catch {
            errorMessage = AppErrorMapper.message(for: error)
            HapticService.error()
            SoundService.shared.play(.fault)
        }
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
