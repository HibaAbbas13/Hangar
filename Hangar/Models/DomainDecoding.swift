import Foundation

extension KeyedDecodingContainer {
    func fd<T: Decodable>(_ key: Key, _ fallback: T) -> T {
        (try? decodeIfPresent(T.self, forKey: key)) ?? fallback
    }

    func fdDate(_ key: Key) -> Date {
        (try? decodeIfPresent(Date.self, forKey: key)) ?? Date()
    }
}

extension UserProfile {
    enum CodingKeys: String, CodingKey {
        case id, displayName, email, tier, createdAt, updatedAt
        case revenueCatAppUserId, onboardingCompleted, themePreference, executionMode
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = c.fd(.id, "")
        displayName = c.fd(.displayName, "Operator")
        email = c.fd(.email, "")
        tier = c.fd(.tier, .free)
        createdAt = c.fdDate(.createdAt)
        updatedAt = c.fdDate(.updatedAt)
        revenueCatAppUserId = c.fd(.revenueCatAppUserId, id)
        onboardingCompleted = c.fd(.onboardingCompleted, true)
        themePreference = c.fd(.themePreference, .night)
        executionMode = c.fd(.executionMode, .onDevice)
    }
}

extension Deck {
    enum CodingKeys: String, CodingKey {
        case id, name, provider, isActive, iconName, createdAt, updatedAt
        case sortOrder, lastStatus, lastTriggeredAt, ownerId, isShared
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = c.fd(.id, "")
        name = c.fd(.name, "Untitled deck")
        provider = c.fd(.provider, .custom)
        isActive = c.fd(.isActive, true)
        iconName = c.fd(.iconName, ServiceProvider.custom.symbolName)
        createdAt = c.fdDate(.createdAt)
        updatedAt = c.fdDate(.updatedAt)
        sortOrder = c.fd(.sortOrder, 0)
        lastStatus = c.fd(.lastStatus, .idle)
        lastTriggeredAt = try c.decodeIfPresent(Date.self, forKey: .lastTriggeredAt)
        ownerId = c.fd(.ownerId, "")
        isShared = c.fd(.isShared, false)
    }
}

extension DeckButton {
    enum CodingKeys: String, CodingKey {
        case id, label, webhookUrl, iconName, lastTriggered, method, headers, body
        case timeoutMs, requiresConfirmation, sortOrder, isEncrypted, lastStatus
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = c.fd(.id, "")
        label = c.fd(.label, "Command")
        webhookUrl = c.fd(.webhookUrl, "")
        iconName = c.fd(.iconName, ButtonIcon.bolt.rawValue)
        lastTriggered = try c.decodeIfPresent(Date.self, forKey: .lastTriggered)
        method = c.fd(.method, .POST)
        headers = c.fd(.headers, [:])
        body = c.fd(.body, "")
        timeoutMs = c.fd(.timeoutMs, 15000)
        requiresConfirmation = c.fd(.requiresConfirmation, true)
        sortOrder = c.fd(.sortOrder, 0)
        isEncrypted = c.fd(.isEncrypted, webhookUrl.hasPrefix(Constants.Crypto.encryptedPrefix))
        lastStatus = c.fd(.lastStatus, .idle)
    }
}

extension ActivityEvent {
    enum CodingKeys: String, CodingKey {
        case id, deckId, deckName, buttonId, buttonLabel, status, statusCode
        case durationMs, message, createdAt, provider
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = c.fd(.id, "")
        deckId = c.fd(.deckId, "")
        deckName = c.fd(.deckName, "Deck")
        buttonId = c.fd(.buttonId, "")
        buttonLabel = c.fd(.buttonLabel, "Command")
        status = c.fd(.status, .idle)
        statusCode = try c.decodeIfPresent(Int.self, forKey: .statusCode)
        durationMs = c.fd(.durationMs, 0)
        message = c.fd(.message, "")
        createdAt = c.fdDate(.createdAt)
        provider = c.fd(.provider, .custom)
    }
}

extension ExecutionProfile {
    enum CodingKeys: String, CodingKey {
        case id, name, deckId, isEnabled, steps, createdAt, updatedAt, lastRunAt
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = c.fd(.id, "")
        name = c.fd(.name, "Flow")
        deckId = c.fd(.deckId, "")
        isEnabled = c.fd(.isEnabled, true)
        steps = c.fd(.steps, [])
        createdAt = c.fdDate(.createdAt)
        updatedAt = c.fdDate(.updatedAt)
        lastRunAt = try c.decodeIfPresent(Date.self, forKey: .lastRunAt)
    }
}

extension TeamMember {
    enum CodingKeys: String, CodingKey {
        case id, email, displayName, role, invitedAt
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = c.fd(.id, "")
        email = c.fd(.email, "")
        displayName = c.fd(.displayName, "Operator")
        role = c.fd(.role, .operatorRole)
        invitedAt = c.fdDate(.invitedAt)
    }
}

extension SharedDeckPointer {
    enum CodingKeys: String, CodingKey {
        case id, ownerId, deckId, role, deckName
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = c.fd(.id, "")
        ownerId = c.fd(.ownerId, "")
        deckId = c.fd(.deckId, "")
        role = c.fd(.role, .operatorRole)
        deckName = c.fd(.deckName, "Deck")
    }
}
