import Foundation

/// The pad a new operator lands on.
///
/// Every command here points at a real, live project — therango.co and its
/// Vercel alias, and the public GitHub API for the repo behind it. Nothing
/// points at httpbin or a fake endpoint: a control deck that demonstrates
/// itself against a toy URL is asking to be distrusted.
///
/// The two commands that change production — redeploy and rollback — ship
/// **unarmed**. A deploy hook is a secret that only its owner can mint, so
/// Hangar cannot ship one, and pretending to redeploy would be worse than not
/// offering it. They appear on the pad in a "needs a hook" state and open the
/// editor when pressed. Paste a Vercel Deploy Hook URL and they become real.
enum SampleFleet {
    static let deckName = "therango"

    struct Command: Hashable {
        var label: String
        var iconName: String
        var url: String
        var method: HTTPMethod
        var headers: [String: String]
        var body: String
        var requiresConfirmation: Bool
        /// An empty `url` means the command still needs a secret from its
        /// owner. It is shown, but it is never fired.
        var needsArming: Bool { url.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
    }

    static let siteURL = "https://therango.co/"
    static let vercelAliasURL = "https://ar-shop.vercel.app/"

    static let commands: [Command] = [
        // Fast, real, and safe. The first press anyone makes.
        Command(
            label: "Is the shop up?",
            iconName: ButtonIcon.antenna.rawValue,
            url: siteURL,
            method: .GET,
            headers: [:],
            body: "",
            requiresConfirmation: false
        ),
        // The Vercel alias behind the custom domain — proves the deployment
        // itself is healthy even if DNS is not.
        Command(
            label: "Ping Vercel alias",
            iconName: ButtonIcon.cloud.rawValue,
            url: vercelAliasURL,
            method: .GET,
            headers: [:],
            body: "",
            requiresConfirmation: false
        ),
        // Returns real JSON, so the Console has something worth reading and the
        // point of the log lands.
        Command(
            label: "Latest commit",
            iconName: ButtonIcon.branch.rawValue,
            url: GitHubFleet.commitsAPI,
            method: .GET,
            headers: GitHubFleet.headers,
            body: "",
            requiresConfirmation: false
        ),
        Command(
            label: "Redeploy production",
            iconName: ButtonIcon.rocket.rawValue,
            url: "",
            method: .POST,
            headers: [:],
            body: "",
            requiresConfirmation: true
        )
    ]
}

/// The repo behind the site, over the public GitHub API. No token: these are
/// read-only endpoints on a public repository.
enum GitHubFleet {
    static let deckName = "website repo"
    static let owner = "HibaAbbas13"
    static let repo = "website"

    static let repoAPI = "https://api.github.com/repos/\(owner)/\(repo)"
    static let commitsAPI = "https://api.github.com/repos/\(owner)/\(repo)/commits?per_page=1"

    static let headers: [String: String] = [
        "Accept": "application/vnd.github+json",
        "User-Agent": "Hangar/1.0"
    ]

    static let commands: [SampleFleet.Command] = [
        SampleFleet.Command(
            label: "Repo status",
            iconName: ButtonIcon.database.rawValue,
            url: repoAPI,
            method: .GET,
            headers: headers,
            body: "",
            requiresConfirmation: false
        ),
        SampleFleet.Command(
            label: "Latest commit",
            iconName: ButtonIcon.check.rawValue,
            url: commitsAPI,
            method: .GET,
            headers: headers,
            body: "",
            requiresConfirmation: false
        ),
        // Needs a GitHub token with `workflow` scope, so it ships unarmed for
        // the same reason the redeploy does.
        SampleFleet.Command(
            label: "Run deploy workflow",
            iconName: ButtonIcon.sync.rawValue,
            url: "",
            method: .POST,
            headers: [:],
            body: "",
            requiresConfirmation: true
        )
    ]
}
