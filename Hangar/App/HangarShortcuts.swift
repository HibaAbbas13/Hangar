import AppIntents

struct HangarShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: TriggerButtonIntent(),
            phrases: [
                "Run \(\.$command) in \(.applicationName)",
                "Trigger \(\.$command) in \(.applicationName)",
                "Fire \(\.$command) with \(.applicationName)",
                "Ping \(\.$command) in \(.applicationName)",
                "Run a command in \(.applicationName)",
                "Trigger a command in \(.applicationName)"
            ],
            shortTitle: "Trigger command",
            systemImageName: "bolt.fill"
        )
    }
}
