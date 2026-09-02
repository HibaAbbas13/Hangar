import Foundation
import WidgetKit

enum WidgetSyncService {
    static func publish(userId: String, decks: [Deck], buttonsByDeck: [String: [DeckButton]]) {
        let snapshots = decks.prefix(3).map { deck in
            WidgetDeckSnapshot(
                deckId: deck.id,
                ownerId: deck.ownerId.isEmpty ? userId : deck.ownerId,
                name: deck.name,
                provider: deck.provider.rawValue,
                buttons: (buttonsByDeck[deck.id] ?? []).prefix(4).map {
                    WidgetButtonSnapshot(
                        id: $0.id,
                        label: $0.label,
                        iconName: $0.iconName,
                        url: $0.webhookUrl,
                        method: $0.method.rawValue,
                        headers: $0.headers,
                        body: $0.body
                    )
                }
            )
        }
        WidgetSnapshotStore.save(Array(snapshots))
        WidgetCenter.shared.reloadAllTimelines()
    }
}
