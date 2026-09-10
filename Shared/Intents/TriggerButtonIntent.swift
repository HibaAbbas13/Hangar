import AppIntents
import WidgetKit

struct TriggerButtonIntent: AppIntent {
    static var title: LocalizedStringResource = "Trigger Hangar command"
    static var description = IntentDescription("Fires a Hangar webhook command.")
    static var openAppWhenRun: Bool = false

    static var parameterSummary: some ParameterSummary {
        When(\.$command, .hasAnyValue) {
            Summary("Trigger \(\.$command)")
        } otherwise: {
            Summary("Trigger \(\.$label)")
        }
    }

    @Parameter(title: "Command", requestValueDialog: "Which Hangar command?")
    var command: HangarCommandEntity?

    @Parameter(title: "Owner")
    var ownerId: String

    @Parameter(title: "Deck")
    var deckId: String

    @Parameter(title: "Button")
    var buttonId: String

    @Parameter(title: "Label")
    var label: String

    init() {
        ownerId = ""
        deckId = ""
        buttonId = ""
        label = "Command"
    }

    init(ownerId: String, deckId: String, buttonId: String, label: String) {
        self.ownerId = ownerId
        self.deckId = deckId
        self.buttonId = buttonId
        self.label = label
    }

    init(command: HangarCommandEntity) {
        self.command = command
        self.ownerId = command.ownerId
        self.deckId = command.deckId
        self.buttonId = command.buttonId
        self.label = command.label
    }

    func perform() async throws -> some IntentResult & ProvidesDialog {
        let resolved = try resolveTarget()
        try await WidgetTriggerClient.trigger(
            ownerId: resolved.ownerId,
            deckId: resolved.deckId,
            buttonId: resolved.buttonId
        )
        WidgetCenter.shared.reloadAllTimelines()
        return .result(dialog: "Triggered \(resolved.label).")
    }

    private func resolveTarget() throws -> (
        ownerId: String,
        deckId: String,
        buttonId: String,
        label: String
    ) {
        if let command {
            return (command.ownerId, command.deckId, command.buttonId, command.label)
        }
        if ownerId.isEmpty == false, deckId.isEmpty == false, buttonId.isEmpty == false {
            return (ownerId, deckId, buttonId, label)
        }

        let armed = HangarCommandEntity.allCommands()
        if armed.isEmpty {
            throw WidgetTriggerError.missingCommand
        }
        if armed.count == 1, let only = armed.first {
            return (only.ownerId, only.deckId, only.buttonId, only.label)
        }
        throw $command.needsDisambiguationError(among: armed)
    }
}
