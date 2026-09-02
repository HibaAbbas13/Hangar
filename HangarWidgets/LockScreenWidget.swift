import WidgetKit
import SwiftUI
import AppIntents

struct LockScreenWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: Constants.Widget.lockKind, provider: LockTimelineProvider()) { entry in
            LockScreenView(entry: entry)
                .containerBackground(for: .widget) { Color.clear }
        }
        .configurationDisplayName("Hangar lock")
        .description("Primary command on the lock screen.")
        .supportedFamilies([.accessoryCircular, .accessoryRectangular, .accessoryInline])
    }
}

struct LockTimelineProvider: TimelineProvider {
    func placeholder(in context: Context) -> LockEntry {
        LockEntry(date: Date(), deck: WidgetSnapshotStore.load().first, last: LastTriggerStore.load())
    }

    func getSnapshot(in context: Context, completion: @escaping (LockEntry) -> Void) {
        completion(placeholder(in: context))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<LockEntry>) -> Void) {
        completion(Timeline(entries: [placeholder(in: context)], policy: .after(Date().addingTimeInterval(10 * 60))))
    }
}

struct LockEntry: TimelineEntry {
    let date: Date
    let deck: WidgetDeckSnapshot?
    let last: LastTriggerSnapshot?
}

struct LockScreenView: View {
    @Environment(\.widgetFamily) private var family
    let entry: LockEntry

    var body: some View {
        switch family {
        case .accessoryCircular:
            ZStack {
                AccessoryWidgetBackground()
                VStack(spacing: 2) {
                    Image(systemName: entry.deck?.buttons.first?.iconName ?? "bolt.fill")
                    Text("FD")
                        .font(.system(size: 10, weight: .bold))
                }
            }
        case .accessoryInline:
            Text("FD · \(entry.deck?.buttons.first?.label ?? "Standby")")
        default:
            VStack(alignment: .leading, spacing: 4) {
                Text(entry.deck?.name ?? "Hangar")
                    .font(.headline)
                if let button = entry.deck?.buttons.first {
                    Button(intent: TriggerButtonIntent(
                        ownerId: entry.deck?.ownerId ?? "",
                        deckId: entry.deck?.deckId ?? "",
                        buttonId: button.id,
                        label: button.label
                    )) {
                        Label(button.label, systemImage: button.iconName)
                    }
                } else {
                    Text("No armed command")
                        .font(.caption)
                }
            }
        }
    }
}
