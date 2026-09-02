import WidgetKit
import SwiftUI
import AppIntents

struct DeckControlWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: Constants.Widget.controlKind, provider: DeckTimelineProvider()) { entry in
            DeckControlView(entry: entry)
                .containerBackground(for: .widget) {
                    Color(red: 0.055, green: 0.051, blue: 0.043)
                }
        }
        .configurationDisplayName("Hangar pad")
        .description("Fire the active deck without unlocking a terminal.")
        .supportedFamilies([.systemMedium, .systemLarge])
    }
}

struct DeckTimelineProvider: TimelineProvider {
    func placeholder(in context: Context) -> DeckEntry {
        DeckEntry(date: Date(), deck: WidgetSnapshotStore.load().first)
    }

    func getSnapshot(in context: Context, completion: @escaping (DeckEntry) -> Void) {
        completion(DeckEntry(date: Date(), deck: WidgetSnapshotStore.load().first))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<DeckEntry>) -> Void) {
        let entry = DeckEntry(date: Date(), deck: WidgetSnapshotStore.load().first)
        completion(Timeline(entries: [entry], policy: .after(Date().addingTimeInterval(15 * 60))))
    }
}

struct DeckEntry: TimelineEntry {
    let date: Date
    let deck: WidgetDeckSnapshot?
}

struct DeckControlView: View {
    let entry: DeckEntry

    var body: some View {
        if let deck = entry.deck {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text(deck.name.uppercased())
                        .font(.system(size: 11, weight: .semibold, design: .default))
                        .tracking(1.4)
                        .foregroundStyle(Color(red: 0.745, green: 0.588, blue: 0.357))
                    Spacer()
                    Text("FD")
                        .font(.system(size: 11, weight: .bold, design: .serif))
                        .foregroundStyle(Color(red: 0.945, green: 0.922, blue: 0.878).opacity(0.7))
                }
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                    ForEach(deck.buttons.prefix(4)) { button in
                        Button(intent: TriggerButtonIntent(
                            ownerId: deck.ownerId,
                            deckId: deck.deckId,
                            buttonId: button.id,
                            label: button.label
                        )) {
                            VStack(spacing: 6) {
                                Image(systemName: button.iconName)
                                    .font(.system(size: 14, weight: .light))
                                Text(button.label)
                                    .font(.system(size: 11, weight: .medium))
                                    .lineLimit(2)
                                    .multilineTextAlignment(.center)
                            }
                            .foregroundStyle(Color(red: 0.945, green: 0.922, blue: 0.878))
                            .frame(maxWidth: .infinity, minHeight: 52)
                            .padding(.vertical, 8)
                            .background(
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .fill(Color(red: 0.145, green: 0.133, blue: 0.114))
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        } else {
            VStack(alignment: .leading, spacing: 8) {
                Text("HANGAR")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(Color(red: 0.745, green: 0.588, blue: 0.357))
                Text("Open the app and commission a deck to arm this pad.")
                    .font(.system(size: 13))
                    .foregroundStyle(Color(red: 0.565, green: 0.537, blue: 0.486))
            }
        }
    }
}
