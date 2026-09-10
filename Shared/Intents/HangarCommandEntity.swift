import AppIntents

struct HangarCommandEntity: AppEntity {
    static var typeDisplayRepresentation = TypeDisplayRepresentation(name: "Hangar Command")
    static var defaultQuery = HangarCommandQuery()

    var id: String
    var ownerId: String
    var deckId: String
    var buttonId: String
    var label: String
    var deckName: String

    init(ownerId: String, deckId: String, buttonId: String, label: String, deckName: String) {
        self.ownerId = ownerId
        self.deckId = deckId
        self.buttonId = buttonId
        self.label = label
        self.deckName = deckName
        self.id = "\(ownerId)|\(deckId)|\(buttonId)"
    }

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(
            title: "\(label)",
            subtitle: "\(deckName)"
        )
    }

    static func allCommands() -> [HangarCommandEntity] {
        WidgetSnapshotStore.load().flatMap { deck in
            deck.buttons.map { button in
                HangarCommandEntity(
                    ownerId: deck.ownerId,
                    deckId: deck.deckId,
                    buttonId: button.id,
                    label: button.label,
                    deckName: deck.name
                )
            }
        }
    }
}

struct HangarCommandQuery: EntityStringQuery {
    /// Siri hands us the words it heard; we match them against command labels.
    /// Without this, a spoken phrase never resolves to a command.
    func entities(matching string: String) async throws -> [HangarCommandEntity] {
        let needle = string.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !needle.isEmpty else { return HangarCommandEntity.allCommands() }
        return HangarCommandEntity.allCommands().filter { entity in
            let label = entity.label.lowercased()
            return label.contains(needle)
                || needle.contains(label)
                || entity.deckName.lowercased().contains(needle)
        }
    }

    func entities(for identifiers: [HangarCommandEntity.ID]) async throws -> [HangarCommandEntity] {
        HangarCommandEntity.allCommands().filter { identifiers.contains($0.id) }
    }

    func suggestedEntities() async throws -> [HangarCommandEntity] {
        HangarCommandEntity.allCommands()
    }

    func defaultResult() async -> HangarCommandEntity? {
        HangarCommandEntity.allCommands().first
    }
}
