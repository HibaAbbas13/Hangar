import Foundation

/// Kept as the names the seeding code refers to. The commands themselves now
/// live in `SampleFleet` and `GitHubFleet`, because the default pad and the
/// "live example" pad became the same thing — every command in Hangar points at
/// a real project.
enum LiveExampleFleet {
    static let vercelDeckName = SampleFleet.deckName
    static let githubDeckName = GitHubFleet.deckName

    static let vercelCommands = SampleFleet.commands
    static let githubCommands = GitHubFleet.commands
}
