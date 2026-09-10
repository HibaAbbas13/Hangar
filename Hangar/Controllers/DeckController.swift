import Foundation
import Combine
import FirebaseFirestore

struct PendingTrigger: Identifiable, Equatable {
    var id: String { button.id }
    var deck: Deck
    var button: DeckButton
}

@MainActor
final class DeckController: ObservableObject {
    @Published var decks: [Deck] = []
    @Published var sharedPointers: [SharedDeckPointer] = []
    @Published var selectedDeckId: String?
    @Published var buttons: [DeckButton] = []
    @Published var isLoading = false
    @Published var triggeringIds: Set<String> = []
    @Published var pendingTrigger: PendingTrigger?
    /// Set when an unarmed command is pressed, so the pad can open its editor.
    @Published var buttonNeedingSecret: DeckButton?
    @Published var lastError: String?
    @Published var toast: String?
    @Published var isSeeding = false

    private let decksRepo = DeckRepository()
    private let buttonsRepo = ButtonRepository()
    private let activityRepo = ActivityRepository()
    private let webhooks = WebhookService.shared

    private var deckListener: ListenerRegistration?
    private var sharedListener: ListenerRegistration?
    private var sharedDeckListeners: [ListenerRegistration] = []
    private var buttonListener: ListenerRegistration?
    private var ownedDecks: [Deck] = []
    private var sharedDecks: [Deck] = []
    private var buttonsCache: [String: [DeckButton]] = [:]
    private var userId: String = ""
    private var isSeedLocked = false
    private var localSampleActive = false

    var selectedDeck: Deck? {
        decks.first { $0.id == selectedDeckId } ?? decks.first
    }

    func start(userId: String) {
        guard self.userId != userId else { return }
        stop()
        self.userId = userId
        deckListener = decksRepo.observeOwned(userId: userId) { [weak self] owned in
            Task { @MainActor in
                guard let self else { return }
                if owned.isEmpty && self.localSampleActive {
                    return
                }
                self.localSampleActive = false
                self.ownedDecks = owned
                self.mergeDecks()
                if owned.isEmpty {
                    await self.installSampleFleetIfNeeded()
                }
            }
        } onError: { [weak self] error in
            Task { @MainActor in
                self?.lastError = AppErrorMapper.message(for: error)
            }
        }
        sharedListener = decksRepo.observeSharedPointers(userId: userId) { [weak self] pointers in
            Task { @MainActor in
                self?.sharedPointers = pointers
                self?.listenToShared(pointers)
            }
        } onError: { [weak self] error in
            Task { @MainActor in
                self?.lastError = AppErrorMapper.message(for: error)
            }
        }
    }

    func stop() {
        deckListener?.remove()
        sharedListener?.remove()
        sharedDeckListeners.forEach { $0.remove() }
        buttonListener?.remove()
        deckListener = nil
        sharedListener = nil
        localSampleActive = false
        isSeeding = false
        isSeedLocked = false
    }

    func select(_ deck: Deck) {
        selectedDeckId = deck.id
        listenButtons(for: deck)
    }

    func requestTrigger(button: DeckButton, premium: Bool, executionMode: ExecutionMode) {
        guard let deck = selectedDeck else { return }
        if button.needsArming {
            buttonNeedingSecret = button
            HapticService.warning()
            return
        }
        if button.requiresConfirmation {
            pendingTrigger = PendingTrigger(deck: deck, button: button)
            HapticService.warning()
            return
        }
        Task { await execute(button: button, deck: deck, premium: premium, mode: executionMode) }
    }

    func confirmPending(premium: Bool, executionMode: ExecutionMode) {
        guard let pending = pendingTrigger else { return }
        pendingTrigger = nil
        Task { await execute(button: pending.button, deck: pending.deck, premium: premium, mode: executionMode) }
    }

    func createDeck(name: String, provider: ServiceProvider, isPremium: Bool) async throws {
        let ownedCount = ownedDecks.count
        if ownedCount >= Constants.Limits.freeDeckCount && !isPremium {
            throw WebhookServiceError.function("Premium is required for additional decks.")
        }
        let deck = Deck.make(ownerId: userId, name: name, provider: provider, sortOrder: ownedCount)
        try await decksRepo.save(deck, ownerId: userId)
        selectedDeckId = deck.id
        lastError = nil
        HapticService.success()
    }

    func saveDeck(_ deck: Deck) async throws {
        try await decksRepo.save(deck, ownerId: deck.ownerId.isEmpty ? userId : deck.ownerId)
        lastError = nil
    }

    func deleteDeck(_ deck: Deck) async throws {
        try await decksRepo.delete(ownerId: deck.ownerId, deckId: deck.id)
        if selectedDeckId == deck.id {
            selectedDeckId = decks.first(where: { $0.id != deck.id })?.id
        }
        lastError = nil
        toast = "Deck decommissioned"
    }

    func saveButton(_ button: DeckButton, secret: WebhookSecret?, isPremium: Bool, mode: ExecutionMode) async throws {
        guard let deck = selectedDeck else { return }
        if buttons.count >= Constants.Limits.freeButtonCount &&
            !buttons.contains(where: { $0.id == button.id }) &&
            !isPremium {
            throw WebhookServiceError.function("Free decks hold 3 commands. Upgrade for unlimited pads.")
        }
        if let secret {
            _ = try await buttonsRepo.saveWithSecret(button, secret: secret, ownerId: deck.ownerId, deckId: deck.id, mode: mode)
        } else {
            try await buttonsRepo.saveMetadata(button, ownerId: deck.ownerId, deckId: deck.id)
        }
        lastError = nil
        HapticService.medium()
    }

    func deleteButton(_ button: DeckButton) async {
        guard let deck = selectedDeck else { return }
        do {
            try await buttonsRepo.delete(ownerId: deck.ownerId, deckId: deck.id, buttonId: button.id)
            lastError = nil
            toast = "Command removed"
            HapticService.medium()
        } catch {
            presentFailure(error)
        }
    }

    func canCreateDeck(isPremium: Bool) -> Bool {
        isPremium || ownedDecks.count < Constants.Limits.freeDeckCount
    }

    func canCreateButton(isPremium: Bool) -> Bool {
        isPremium || buttons.count < Constants.Limits.freeButtonCount
    }

    func syncWidgetsToExtension() {
        guard !userId.isEmpty else { return }
        if let selected = selectedDeck, buttons.isEmpty == false {
            buttonsCache[selected.id] = buttons
        }
        WidgetSyncService.publish(userId: userId, decks: decks, buttonsByDeck: buttonsCache)
        Task { await prefetchButtonsForWidgets() }
    }

    private func prefetchButtonsForWidgets() async {
        var changed = false
        for deck in decks.filter(\.isActive).prefix(3) {
            if let cached = buttonsCache[deck.id], cached.isEmpty == false { continue }
            let owner = deck.ownerId.isEmpty ? userId : deck.ownerId
            guard let fetched = try? await buttonsRepo.fetch(ownerId: owner, deckId: deck.id),
                  fetched.isEmpty == false else { continue }
            buttonsCache[deck.id] = fetched
            changed = true
        }
        guard changed else { return }
        WidgetSyncService.publish(userId: userId, decks: decks, buttonsByDeck: buttonsCache)
    }

    func installSampleFleetIfNeeded() async {
        await installSampleFleet()
    }

    /// True once the GitHub starter pad is installed.
    ///
    /// This used to return true if *either* starter deck existed. Now that the
    /// Vercel deck is what every account is seeded with, that made it always
    /// true and hid the option to add the GitHub one.
    var hasLiveExample: Bool {
        decks.contains { $0.name == GitHubFleet.deckName }
    }

    func installLiveExample(isPremium: Bool) async {
        guard !userId.isEmpty, !isSeedLocked else { return }
        isSeedLocked = true
        defer { isSeedLocked = false }
        do {
            let vercel = try await upsertNamedDeck(
                name: LiveExampleFleet.vercelDeckName,
                provider: .vercel,
                isPremium: isPremium
            )
            _ = try await seedNamedCommands(LiveExampleFleet.vercelCommands, onto: vercel)
            let github = try await upsertNamedDeck(
                name: LiveExampleFleet.githubDeckName,
                provider: .github,
                isPremium: isPremium
            )
            _ = try await seedNamedCommands(LiveExampleFleet.githubCommands, onto: github)
            selectedDeckId = vercel.id
            toast = "\(GitHubFleet.deckName) added"
            lastError = nil
            HapticService.success()
            syncWidgetsToExtension()
        } catch {
            lastError = AppErrorMapper.message(for: error)
            HapticService.error()
        }
    }

    func installSampleFleet() async {
        guard !userId.isEmpty, !isSeedLocked else { return }
        isSeedLocked = true
        let showFullScreenSeed = ownedDecks.isEmpty && decks.isEmpty
        isSeeding = showFullScreenSeed
        defer {
            isSeedLocked = false
            isSeeding = false
        }
        do {
            let deck = try await resolveSampleDeck()
            let seeded = try await seedCommands(onto: deck)
            if seeded {
                selectedDeckId = deck.id
                toast = "\(SampleFleet.deckName) pad ready"
            }
            syncWidgetsToExtension()
        } catch {
            lastError = AppErrorMapper.message(for: error)
            if let existing = selectedDeck ?? ownedDecks.first {
                applyLocalButtons(makeSampleButtons(), onto: existing)
            } else {
                applyLocalSample(makeSampleDeck())
            }
            toast = "Pad ready on device"
            syncWidgetsToExtension()
        }
    }

    private struct PreparedSample {
        var deck: Deck
        var buttons: [DeckButton]
    }

    private func resolveSampleDeck() async throws -> Deck {
        if let existing = selectedDeck ?? ownedDecks.first {
            return existing
        }
        let prepared = makeSampleDeck()
        try await decksRepo.save(prepared.deck, ownerId: userId)
        return prepared.deck
    }

    @discardableResult
    private func seedCommands(onto deck: Deck) async throws -> Bool {
        let existing = try await buttonsRepo.count(ownerId: deck.ownerId, deckId: deck.id)
        guard existing == 0 else { return false }
        let buttons = makeSampleButtons()
        for button in buttons {
            try await seed(button, onto: deck)
        }
        return true
    }

    private func upsertNamedDeck(
        name: String,
        provider: ServiceProvider,
        isPremium: Bool
    ) async throws -> Deck {
        if let existing = ownedDecks.first(where: { $0.name == name }) {
            return existing
        }
        let ownedCount = ownedDecks.count
        if ownedCount >= Constants.Limits.freeDeckCount && !isPremium {
            throw WebhookServiceError.function("Premium is required for additional services.")
        }
        let deck = Deck.make(
            ownerId: userId,
            name: name,
            provider: provider,
            sortOrder: ownedCount
        )
        try await decksRepo.save(deck, ownerId: userId)
        return deck
    }

    @discardableResult
    private func seedNamedCommands(_ commands: [SampleFleet.Command], onto deck: Deck) async throws -> Bool {
        let existing = try await buttonsRepo.count(ownerId: deck.ownerId, deckId: deck.id)
        guard existing == 0 else { return false }
        for (index, command) in commands.enumerated() {
            try await seed(makeButton(command, sortOrder: index), onto: deck)
        }
        return true
    }

    private func makeButton(_ command: SampleFleet.Command, sortOrder: Int) -> DeckButton {
        var button = DeckButton.make(label: command.label, iconName: command.iconName, sortOrder: sortOrder)
        button.requiresConfirmation = command.requiresConfirmation
        button.method = command.method
        button.webhookUrl = command.url
        button.headers = command.headers
        button.body = command.body
        return button
    }

    /// Writes one seeded command.
    ///
    /// A command that ships unarmed has no URL to encrypt, so it is written as
    /// metadata only. Sending an empty secret through the encrypt-and-store path
    /// would either fail or store an endpoint of "".
    private func seed(_ button: DeckButton, onto deck: Deck) async throws {
        guard button.hasSecret else {
            try await buttonsRepo.saveMetadata(button, ownerId: deck.ownerId, deckId: deck.id)
            return
        }
        let secret = WebhookSecret(
            url: button.webhookUrl,
            headers: button.headers,
            body: button.body,
            method: button.method
        )
        _ = try await buttonsRepo.saveWithSecret(
            button,
            secret: secret,
            ownerId: deck.ownerId,
            deckId: deck.id,
            mode: .onDevice
        )
    }

    private func makeSampleButtons() -> [DeckButton] {
        SampleFleet.commands.enumerated().map { index, command in
            makeButton(command, sortOrder: index)
        }
    }

    private func makeSampleDeck() -> PreparedSample {
        let deck = Deck.make(
            ownerId: userId,
            name: SampleFleet.deckName,
            provider: .vercel,
            sortOrder: 0
        )
        return PreparedSample(deck: deck, buttons: makeSampleButtons())
    }

    private func applyLocalSample(_ prepared: PreparedSample) {
        localSampleActive = true
        ownedDecks = [prepared.deck]
        applyLocalButtons(prepared.buttons, onto: prepared.deck)
        mergeDecks()
        syncWidgetsToExtension()
    }

    private func applyLocalButtons(_ sampleButtons: [DeckButton], onto deck: Deck) {
        localSampleActive = true
        buttons = sampleButtons
        buttonsCache[deck.id] = sampleButtons
        selectedDeckId = deck.id
        syncWidgetsToExtension()
    }

    private func execute(button: DeckButton, deck: Deck, premium: Bool, mode: ExecutionMode) async {
        triggeringIds.insert(button.id)
        lastError = nil
        RunHUDStore.shared.begin(
            title: button.label,
            detail: "Sending to \(deck.name)",
            buttonId: button.id
        )
        HapticService.heavy()
        SoundService.shared.play(.press)
        if LiveActivityService.shared.start(deck: deck, button: button) == false {
            PermissionService.shared.flag(.liveActivities)
        }
        let started = Date()
        do {
            var result = try await fire(button: button, deck: deck, mode: mode)
            if result.deckName.isEmpty { result.deckName = deck.name }
            if result.buttonLabel.isEmpty { result.buttonLabel = button.label }
            await persistTriggerOutcome(
                button: button,
                deck: deck,
                result: result,
                premium: premium
            )
            presentRunResult(result)
        } catch {
            let message = AppErrorMapper.message(for: error)
            presentFailure(message)
            RunHUDStore.shared.finish(
                title: button.label,
                detail: message,
                succeeded: false,
                statusCode: nil,
                durationMs: Int(Date().timeIntervalSince(started) * 1000)
            )
            if premium {
                LiveActivityService.shared.finish(buttonId: button.id, status: .failed, message: message)
            }
            let event = ActivityEvent.make(
                deck: deck,
                button: button,
                status: .failed,
                statusCode: nil,
                durationMs: Int(Date().timeIntervalSince(started) * 1000),
                message: message
            )
            await appendActivity(event)
        }
        triggeringIds.remove(button.id)
        syncWidgetsToExtension()
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
                ownerId: deck.ownerId,
                deckId: deck.id,
                mode: .onDevice
            )
            return try await webhooks.triggerOnDevice(button: button, secret: secret)
        }
    }

    private func persistTriggerOutcome(
        button: DeckButton,
        deck: Deck,
        result: TriggerResult,
        premium: Bool
    ) async {
        let event = ActivityEvent.make(
            deck: deck,
            button: button,
            status: result.status,
            statusCode: result.statusCode,
            durationMs: result.durationMs,
            message: result.message
        )
        await appendActivity(event)
        do {
            try await decksRepo.updateStatus(ownerId: deck.ownerId, deckId: deck.id, status: result.status)
            try await buttonsRepo.markTriggered(
                ownerId: deck.ownerId,
                deckId: deck.id,
                buttonId: button.id,
                status: result.status,
                statusCode: result.statusCode,
                durationMs: result.durationMs
            )
        } catch {
            
            lastError = "Command fired, but the hangar log could not sync."
        }
        LastTriggerStore.save(
            LastTriggerSnapshot(
                buttonLabel: result.buttonLabel,
                deckName: result.deckName,
                status: result.status.rawValue,
                at: Date()
            )
        )
        let ok = result.status == .succeeded
        if ok {
            HapticService.success()
            SoundService.shared.play(.success)
            ReviewService.registerSuccess()
        } else {
            HapticService.error()
            SoundService.shared.play(.fault)
        }
        if premium {
            LiveActivityService.shared.finish(buttonId: button.id, status: result.status, message: result.message)
        }
    }

    private func appendActivity(_ event: ActivityEvent) async {
        do {
            try await activityRepo.append(event, userId: userId)
        } catch {
            
        }
    }

    private func presentRunResult(_ result: TriggerResult) {
        let ok = result.status == .succeeded
        let detail: String
        if ok {
            detail = result.message.isEmpty ? "Landed. Logged in History." : result.message
        } else {
            detail = result.message.isEmpty ? "The hook answered with a fault." : result.message
        }
        RunHUDStore.shared.finish(
            title: result.buttonLabel,
            detail: detail,
            succeeded: ok,
            statusCode: result.statusCode,
            durationMs: result.durationMs
        )
    }

    private func presentFailure(_ error: Error) {
        presentFailure(AppErrorMapper.message(for: error))
    }

    private func presentFailure(_ message: String) {
        lastError = message
        HapticService.error()
        SoundService.shared.play(.fault)
    }

    private func listenButtons(for deck: Deck) {
        buttonListener?.remove()
        buttonListener = buttonsRepo.observe(ownerId: deck.ownerId, deckId: deck.id) { [weak self] buttons in
            Task { @MainActor in
                if self?.localSampleActive == true && buttons.isEmpty {
                    self?.syncWidgetsToExtension()
                    return
                }
                self?.buttons = buttons
                self?.buttonsCache[deck.id] = buttons
                if let self {
                    self.syncWidgetsToExtension()
                    if buttons.isEmpty {
                        await self.installSampleFleet()
                    }
                }
            }
        } onError: { [weak self] error in
            Task { @MainActor in
                self?.lastError = AppErrorMapper.message(for: error)
            }
        }
    }

    private func listenToShared(_ pointers: [SharedDeckPointer]) {
        sharedDeckListeners.forEach { $0.remove() }
        sharedDeckListeners = pointers.map { pointer in
            decksRepo.observeDeck(ownerId: pointer.ownerId, deckId: pointer.deckId) { [weak self] deck in
                Task { @MainActor in
                    var next = self?.sharedDecks ?? []
                    next.removeAll { $0.id == pointer.deckId }
                    if var deck {
                        deck.isShared = true
                        deck.ownerId = pointer.ownerId
                        next.append(deck)
                    }
                    self?.sharedDecks = next
                    self?.mergeDecks()
                }
            }
        }
    }

    private func mergeDecks() {
        var combined = ownedDecks + sharedDecks
        combined.sort { $0.sortOrder < $1.sortOrder }
        decks = combined
        if selectedDeckId == nil || combined.contains(where: { $0.id == selectedDeckId }) == false {
            if let first = combined.first {
                select(first)
            } else {
                selectedDeckId = nil
                buttons = []
            }
        } else if let selected = selectedDeck {
            listenButtons(for: selected)
        }
        syncWidgetsToExtension()
    }
}
