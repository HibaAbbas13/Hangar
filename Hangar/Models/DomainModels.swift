import Foundation

struct UserProfile: Identifiable, Codable, Hashable {
    var id: String
    var displayName: String
    var email: String
    var tier: AppTier
    var createdAt: Date
    var updatedAt: Date
    var revenueCatAppUserId: String
    var onboardingCompleted: Bool
    var themePreference: ThemePreference
    var executionMode: ExecutionMode

    var firstName: String {
        displayName.split(separator: " ").first.map(String.init) ?? displayName
    }

    var isPremium: Bool { tier == .premium }

    static func new(id: String, displayName: String, email: String) -> UserProfile {
        let now = Date()
        return UserProfile(
            id: id,
            displayName: displayName.isEmpty ? "Operator" : displayName,
            email: email,
            tier: .free,
            createdAt: now,
            updatedAt: now,
            revenueCatAppUserId: id,
            onboardingCompleted: false,
            themePreference: .night,
            executionMode: .onDevice
        )
    }
}

struct Deck: Identifiable, Codable, Hashable {
    var id: String
    var name: String
    var provider: ServiceProvider
    var isActive: Bool
    var iconName: String
    var createdAt: Date
    var updatedAt: Date
    var sortOrder: Int
    var lastStatus: TriggerStatus
    var lastTriggeredAt: Date?
    var ownerId: String
    var isShared: Bool

    static func make(
        id: String = UUID().uuidString,
        ownerId: String,
        name: String,
        provider: ServiceProvider,
        sortOrder: Int
    ) -> Deck {
        let now = Date()
        return Deck(
            id: id,
            name: name,
            provider: provider,
            isActive: true,
            iconName: provider.symbolName,
            createdAt: now,
            updatedAt: now,
            sortOrder: sortOrder,
            lastStatus: .idle,
            lastTriggeredAt: nil,
            ownerId: ownerId,
            isShared: false
        )
    }
}

struct DeckButton: Identifiable, Codable, Hashable {
    var id: String
    var label: String
    var webhookUrl: String
    var iconName: String
    var lastTriggered: Date?
    var method: HTTPMethod
    var headers: [String: String]
    var body: String
    var timeoutMs: Int
    var requiresConfirmation: Bool
    var sortOrder: Int
    var isEncrypted: Bool
    /// Host only — safe to store and show beside an encrypted command.
    var host: String
    var lastStatus: TriggerStatus
    /// The response code and round trip of the last run. The pad shows these
    /// so a press leaves durable evidence on the key itself, instead of only
    /// in History.
    var lastStatusCode: Int?
    var lastDurationMs: Int

    var lastOutcome: FDRunOutcome {
        FDRunOutcome(
            status: lastStatus,
            statusCode: lastStatusCode,
            durationMs: lastDurationMs,
            at: lastTriggered
        )
    }

    var hasSecret: Bool {
        !webhookUrl.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    /// A command that has been placed on the pad but has no endpoint yet.
    ///
    /// Redeploy and rollback need a deploy hook, which is a secret only its
    /// owner can mint. Those commands ship visible but unarmed so the pad shows
    /// what Hangar is for, and pressing one opens the editor instead of firing
    /// a request at nothing.
    var needsArming: Bool { !hasSecret }

    static func make(
        id: String = UUID().uuidString,
        label: String,
        iconName: String,
        sortOrder: Int
    ) -> DeckButton {
        DeckButton(
            id: id,
            label: label,
            webhookUrl: "",
            iconName: iconName,
            lastTriggered: nil,
            method: .POST,
            headers: [:],
            body: "",
            timeoutMs: 15000,
            requiresConfirmation: true,
            sortOrder: sortOrder,
            isEncrypted: false,
            host: "",
            lastStatus: .idle,
            lastStatusCode: nil,
            lastDurationMs: 0
        )
    }
}

struct WebhookSecret: Codable, Hashable {
    var url: String
    var headers: [String: String]
    var body: String
    var method: HTTPMethod
}

struct ActivityEvent: Identifiable, Codable, Hashable {
    var id: String
    var deckId: String
    var deckName: String
    var buttonId: String
    var buttonLabel: String
    var status: TriggerStatus
    var statusCode: Int?
    var durationMs: Int
    var message: String
    var createdAt: Date
    var provider: ServiceProvider

    static func make(
        deck: Deck,
        button: DeckButton,
        status: TriggerStatus,
        statusCode: Int?,
        durationMs: Int,
        message: String
    ) -> ActivityEvent {
        ActivityEvent(
            id: UUID().uuidString,
            deckId: deck.id,
            deckName: deck.name,
            buttonId: button.id,
            buttonLabel: button.label,
            status: status,
            statusCode: statusCode,
            durationMs: durationMs,
            message: message,
            createdAt: Date(),
            provider: deck.provider
        )
    }
}

struct ExecutionStep: Identifiable, Codable, Hashable {
    var id: String
    var buttonId: String
    var delaySeconds: Int

    static func make(buttonId: String, delaySeconds: Int = 0) -> ExecutionStep {
        ExecutionStep(id: UUID().uuidString, buttonId: buttonId, delaySeconds: delaySeconds)
    }
}

struct ExecutionProfile: Identifiable, Codable, Hashable {
    var id: String
    var name: String
    var deckId: String
    var isEnabled: Bool
    var steps: [ExecutionStep]
    var createdAt: Date
    var updatedAt: Date
    var lastRunAt: Date?

    static func make(name: String, deckId: String) -> ExecutionProfile {
        let now = Date()
        return ExecutionProfile(
            id: UUID().uuidString,
            name: name,
            deckId: deckId,
            isEnabled: true,
            steps: [],
            createdAt: now,
            updatedAt: now,
            lastRunAt: nil
        )
    }
}

struct TeamMember: Identifiable, Codable, Hashable {
    var id: String
    var email: String
    var displayName: String
    var role: MemberRole
    var invitedAt: Date
}

struct DeckInvite: Identifiable, Codable, Hashable {
    var id: String
    var code: String
    var ownerId: String
    var deckId: String
    var deckName: String
    var status: InviteStatus
    var createdAt: Date
}

struct SharedDeckPointer: Identifiable, Codable, Hashable {
    var id: String
    var ownerId: String
    var deckId: String
    var role: MemberRole
    var deckName: String
}
