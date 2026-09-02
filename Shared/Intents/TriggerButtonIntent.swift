import AppIntents
import WidgetKit

struct TriggerButtonIntent: AppIntent {
    static var title: LocalizedStringResource = "Trigger Hangar command"
    static var description = IntentDescription("Fires a Hangar webhook command through the encrypted cloud proxy.")
    static var openAppWhenRun: Bool = false
    static var parameterSummary: some ParameterSummary {
        Summary("Trigger \(\.$label)")
    }

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

    func perform() async throws -> some IntentResult & ProvidesDialog {
        try await WidgetTriggerClient.trigger(ownerId: ownerId, deckId: deckId, buttonId: buttonId)
        WidgetCenter.shared.reloadAllTimelines()
        return .result(dialog: "Triggered \(label).")
    }
}
