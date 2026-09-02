import AppIntents

struct HangarShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: TriggerButtonIntent(),
            phrases: [
                "Trigger a command in \(.applicationName)",
                "Run a webhook in \(.applicationName)"
            ],
            shortTitle: "Trigger command",
            systemImageName: "bolt.fill"
        )
    }
}
