import Foundation

enum SampleFleet {
    static let deckName = "Vercel Micro-Services"

    struct Command: Hashable {
        var label: String
        var iconName: String
        var url: String
        var method: HTTPMethod
        var headers: [String: String]
        var body: String
        var requiresConfirmation: Bool
    }

    static let commands: [Command] = [
        Command(
            label: "Redeploy production",
            iconName: ButtonIcon.rocket.rawValue,
            url: "https://httpbin.org/post",
            method: .POST,
            headers: ["Content-Type": "application/json"],
            body: #"{"source":"flightdeck","action":"redeploy","env":"production"}"#,
            requiresConfirmation: false
        ),
        Command(
            label: "Trigger production rollback",
            iconName: ButtonIcon.rollback.rawValue,
            url: "https://httpbin.org/post",
            method: .POST,
            headers: ["Content-Type": "application/json"],
            body: #"{"source":"flightdeck","action":"rollback","env":"production"}"#,
            requiresConfirmation: true
        ),
        Command(
            label: "Health ping",
            iconName: ButtonIcon.antenna.rawValue,
            url: "https://httpbin.org/status/200",
            method: .GET,
            headers: [:],
            body: "",
            requiresConfirmation: false
        )
    ]
}
