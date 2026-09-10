import AppIntents
import Foundation
import WidgetKit

enum WidgetSyncService {
    static func publish(userId: String, decks: [Deck], buttonsByDeck: [String: [DeckButton]]) {
        let activeDecks = decks.filter(\.isActive)
        let snapshots = activeDecks.prefix(3).compactMap { deck -> WidgetDeckSnapshot? in
            let buttons = (buttonsByDeck[deck.id] ?? []).prefix(4).map { button in
                widgetButton(from: button)
            }
            guard !buttons.isEmpty else { return nil }
            return WidgetDeckSnapshot(
                deckId: deck.id,
                ownerId: deck.ownerId.isEmpty ? userId : deck.ownerId,
                name: deck.name,
                provider: deck.provider.rawValue,
                buttons: buttons
            )
        }
        // Buttons load a beat after decks. Don't wipe an armed pad with an empty write.
        if snapshots.isEmpty, !decks.isEmpty, WidgetSnapshotStore.load().isEmpty == false {
            reloadSiriAndWidgets()
            return
        }
        WidgetSnapshotStore.save(snapshots)
        reloadSiriAndWidgets()
    }

    static func clear() {
        WidgetSnapshotStore.save([])
        reloadSiriAndWidgets()
    }

    private static func reloadSiriAndWidgets() {
        HangarShortcuts.updateAppShortcutParameters()
        WidgetCenter.shared.reloadAllTimelines()
    }

    private static func widgetButton(from button: DeckButton) -> WidgetButtonSnapshot {
        let encrypted = button.isEncrypted || button.webhookUrl.hasPrefix(Constants.Crypto.encryptedPrefix)
        let trimmedURL = button.webhookUrl.trimmingCharacters(in: .whitespacesAndNewlines)
        let firesViaCloud = encrypted || trimmedURL.isEmpty
        return WidgetButtonSnapshot(
            id: button.id,
            label: button.label,
            iconName: button.iconName,
            url: firesViaCloud ? "" : trimmedURL,
            method: button.method.rawValue,
            headers: firesViaCloud ? [:] : button.headers,
            body: firesViaCloud ? "" : button.body,
            firesViaCloud: firesViaCloud
        )
    }
}
