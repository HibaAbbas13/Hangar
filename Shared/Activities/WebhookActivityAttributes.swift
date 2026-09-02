import Foundation
import ActivityKit

struct WebhookActivityAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        var buttonLabel: String
        var deckName: String
        var status: String
        var message: String
        var progress: Double
    }

    var deckId: String
    var buttonId: String
    var providerCode: String
}
