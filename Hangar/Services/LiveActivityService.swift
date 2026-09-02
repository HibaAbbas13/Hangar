import Foundation
import ActivityKit

@MainActor
final class LiveActivityService {
    static let shared = LiveActivityService()

    
    
    @discardableResult
    func start(deck: Deck, button: DeckButton) -> Bool {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return false }
        let attributes = WebhookActivityAttributes(
            deckId: deck.id,
            buttonId: button.id,
            providerCode: deck.provider.shortCallsign
        )
        let state = WebhookActivityAttributes.ContentState(
            buttonLabel: button.label,
            deckName: deck.name,
            status: TriggerStatus.running.rawValue,
            message: "Dispatching command",
            progress: 0.15
        )
        let content = ActivityContent(state: state, staleDate: Date().addingTimeInterval(120))
        _ = try? Activity<WebhookActivityAttributes>.request(attributes: attributes, content: content)
        return true
    }

    func finish(buttonId: String, status: TriggerStatus, message: String) {
        Task {
            for activity in Activity<WebhookActivityAttributes>.activities where activity.attributes.buttonId == buttonId {
                let state = WebhookActivityAttributes.ContentState(
                    buttonLabel: activity.content.state.buttonLabel,
                    deckName: activity.content.state.deckName,
                    status: status.rawValue,
                    message: message,
                    progress: 1
                )
                await activity.end(ActivityContent(state: state, staleDate: nil), dismissalPolicy: .after(.now + 8))
            }
        }
    }
}
