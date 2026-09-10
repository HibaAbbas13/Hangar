import Foundation

struct WidgetDeckSnapshot: Codable, Hashable {
    var deckId: String
    var ownerId: String
    var name: String
    var provider: String
    var buttons: [WidgetButtonSnapshot]
}

struct WidgetButtonSnapshot: Codable, Hashable, Identifiable {
    var id: String
    var label: String
    var iconName: String
    var url: String
    var method: String
    var headers: [String: String]
    var body: String
    var firesViaCloud: Bool

    enum CodingKeys: String, CodingKey {
        case id, label, iconName, url, method, headers, body, firesViaCloud
    }

    init(
        id: String,
        label: String,
        iconName: String,
        url: String,
        method: String,
        headers: [String: String],
        body: String,
        firesViaCloud: Bool = false
    ) {
        self.id = id
        self.label = label
        self.iconName = iconName
        self.url = url
        self.method = method
        self.headers = headers
        self.body = body
        self.firesViaCloud = firesViaCloud
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        label = try c.decode(String.self, forKey: .label)
        iconName = try c.decode(String.self, forKey: .iconName)
        url = (try? c.decode(String.self, forKey: .url)) ?? ""
        method = (try? c.decode(String.self, forKey: .method)) ?? "POST"
        headers = (try? c.decode([String: String].self, forKey: .headers)) ?? [:]
        body = (try? c.decode(String.self, forKey: .body)) ?? ""
        firesViaCloud = (try? c.decode(Bool.self, forKey: .firesViaCloud)) ?? url.isEmpty
            || url.hasPrefix(Constants.Crypto.encryptedPrefix)
    }
}

enum WidgetSnapshotStore {
    static func save(_ decks: [WidgetDeckSnapshot]) {
        guard let data = try? JSONEncoder().encode(decks) else { return }
        AppGroupStore.defaults.set(data, forKey: SharedConstants.DefaultsKey.widgetSnapshot)
        AppGroupStore.persist()
    }

    static func load() -> [WidgetDeckSnapshot] {
        guard let data = AppGroupStore.defaults.data(forKey: SharedConstants.DefaultsKey.widgetSnapshot),
              let decks = try? JSONDecoder().decode([WidgetDeckSnapshot].self, from: data) else {
            return []
        }
        return decks
    }
}

struct LastTriggerSnapshot: Codable, Hashable {
    var buttonLabel: String
    var deckName: String
    var status: String
    var at: Date
}

enum LastTriggerStore {
    static func save(_ value: LastTriggerSnapshot) {
        if let data = try? JSONEncoder().encode(value) {
            AppGroupStore.defaults.set(data, forKey: SharedConstants.DefaultsKey.lastTrigger)
            AppGroupStore.persist()
        }
    }

    static func load() -> LastTriggerSnapshot? {
        guard let data = AppGroupStore.defaults.data(forKey: SharedConstants.DefaultsKey.lastTrigger) else { return nil }
        return try? JSONDecoder().decode(LastTriggerSnapshot.self, from: data)
    }
}
